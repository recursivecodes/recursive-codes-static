---
title: "Project GreenThumb Part 4 - Reporting Queries and WebSockets"
slug: "project-greenthumb-part-4-reporting-queries-and-websockets"
author: "Todd Sharp"
date: 2021-03-29
summary: "In this post, we'll look at the reporting queries behind the scenes in my Project GreenThumb app as well as how I added WebSocket support to push the sensor data in real time to the front-end."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f27d8abd-9d14-47f9-ac5e-928a6366cf9b/banner_christopher_robin_ebbinghaus_pgskeh0yl8o_unsplash.jpeg"
---

In the [last post in this series](/posts/project-greenthumb-part-3-consuming-and-persisting-the-sensor-data-in-the-cloud), we looked at the database schema behind the scenes, how I created the Micronaut application and consumed the sensor readings and set up the application for sensor reading persistence with Micronaut Data. In this post, we'll look at reporting and how that's accomplished as well as how I added WebSocket support to the application to push the sensor readings to the front-end in real-time. We'll wrap things up in the next post with the front-end and a look at the current progress for Project GreenThumb.

## Reporting Queries

In addition to the interface based repository for basic CRUD operations that we looked at in the last post, I created an abstract class for `Reading` that gives me the ability to inject an `EntityManager` so that I can create and run native SQL queries against my `GREENTHUMB_READINGS` table for use in some of the advanced reports that I wanted to include in the application.

I mentioned above that storing the reading JSON in a column would still allow us to query against the JSON data using familiar SQL. This was especially important as I really wanted the ability to view the aggregate data from different viewpoints. For example, I wanted to view the aggregate data by hour of the day, or day of the month. Also, I wanted to be able to compare periods like night vs. day to see if I was meeting the stated goals of the project. 

Viewing all of the data was easy:
```sql
select id, json_serialize(reading), created_on
from greenthumb_readings;
```



Which gives me:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f27d8abd-9d14-47f9-ac5e-928a6366cf9b/file_1616175276479.png)

If I need to pull elements out of the JSON, I can do that:
```sql
select
    id,
    gr.reading.airTemp,
    created_on
from greenthumb_readings gr
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f27d8abd-9d14-47f9-ac5e-928a6366cf9b/file_1616175276481.png)

Which means I can start aggregating and grouping the output:
```sql
select
    to_char(gr.created_on, 'HH24') as hour,
    round(avg(gr.reading.airTemp), 2) as airTemp    
from greenthumb_readings gr
group by to_char(gr.created_on, 'HH24')
order by to_char(created_on, 'HH24');
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f27d8abd-9d14-47f9-ac5e-928a6366cf9b/file_1616175324574.png)

For performance, I turned this into a materialized view that refreshes itself every 5 minutes (there's no real need for "live" data for these reports).
```sql
create materialized view vw_avg_by_hour
refresh complete
start with sysdate
next sysdate + interval ‘5’ minute
as    
select
    to_char(gr.created_on, 'HH24') as hour,
    round(avg(gr.reading.airTemp), 2) as airTemp    
from greenthumb_readings gr
group by to_char(gr.created_on, 'HH24’);
```



As you can see, this gives me the ability to construct all of the queries that I need to view the sensor data from multiple dimensions. Plugging these queries into the Micronaut application is a matter of creating an `AbstractReadingRepository`, injecting an `EntityManager`, and running native queries that are mapped to DTOs.  Essentially, like this:
```java
@Repository
public abstract class AbstractReadingRepository implements PageableRepository<Reading, Long> {
    private final EntityManager entityManager;

    public AbstractReadingRepository(EntityManager entityManager) {
        this.entityManager = entityManager;
    }

    @Transactional
    public List getAvgReadingsByHour() {
        String sql = "select...";
        return entityManager.createNativeQuery(sql)
                .unwrap(org.hibernate.query.NativeQuery.class)
                .addScalar("hour", IntegerType.INSTANCE)
                .addScalar("avgAirTemp", FloatType.INSTANCE)
                .setResultTransformer(Transformers.aliasToBean(ReadingByHourDTO.class))
                .getResultList();
    }
}
```



## WebSockets

Right out-of-the-box, Micronaut includes [full support for WebSocket clients and servers](https://docs.micronaut.io/latest/guide/index.html#websocket). Adding a WebSocket server is a matter of creating a class annotated with `@ServerWebSocket` which accepts a URI argument that will represent the server endpoint. Methods of the server class are then annotated with `@OnOpen`, `@OnMessage`, or `@OnClose` to represent the handlers called for the appropriate server action. A `WebSocketBroadcaster` is injected (and available to be injected elsewhere in the application) that is used to broadcast messages to connected clients. The broadcaster has methods for both blocking (`broadcastSync`) and non-blocking (`broadcastAsync`).

For this project, I wanted a way to be able to push the sensor data to the front-end in real-time, so I added a WebSocket server endpoint.
```java
@ServerWebSocket("/data/{topic}")
public class GreenThumbWebSocket {

    private static final Logger LOG = LoggerFactory.getLogger(GreenThumbWebSocket.class);

    private final WebSocketBroadcaster broadcaster;

    public GreenThumbWebSocket(WebSocketBroadcaster broadcaster) {
        this.broadcaster = broadcaster;
    }

    @OnOpen
    public void onOpen(String topic, WebSocketSession session) {
        broadcaster.broadcastSync("Joined channel", isValid(topic, session));
    }

    @OnMessage
    public void onMessage(String topic, String message, WebSocketSession session) {
        broadcaster.broadcastSync(message, isValid(topic, session));
    }

    @OnClose
    public void onClose(String topic, WebSocketSession session) {
        broadcaster.broadcastSync("Disconnected", isValid(topic, session));
    }

    private Predicate<WebSocketSession> isValid(String topic, WebSocketSession session) {
        return s -> s != session &&
                topic.equalsIgnoreCase(s.getUriVariables().get("topic", String.class, null));
    }
}
```



 

With the WebSocket server and persistence tier now in place, I could finally modify the MQTT consumer to persist the message to the DB and broadcast it to any WebSocket clients. For this, I edited the `GreenThumbConsumer`.
```java
@Topic("greenthumb/readings")
public void receive(Map<String, Object> data) throws JsonProcessingException {
    Reading reading = new Reading(data);
    // persist to the DB
    readingRepository.saveAsync(reading);
    // broadcast to websocket clients
    broadcaster.broadcastAsync(data, MediaType.APPLICATION_JSON_TYPE);
}
```



At this point, the application was ready for a front-end that would consume the real-time data, chart it, and present a few reports.

## Summary

In this post, we looked at the SQL queries used for reporting on the collected sensor data and pushed it in real-time to clients connected to the WebSocket endpoint that I established. In the next post, we'll look at the front-end, the automated build process, push notifications, and talk about the current progress of Project GreenThumb!

Photo by [Christopher Robin Ebbinghaus](https://unsplash.com/@cebbbinghaus?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](/s/photos/websocket?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

