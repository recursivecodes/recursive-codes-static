---
title: "Project GreenThumb Part 5 - The Front-End, Build Pipeline, Push Notifications and Overall Progress"
slug: "project-greenthumb-part-5-the-front-end,-build-pipeline,-push-notifications-and-overall-progress"
author: "Todd Sharp"
date: 2021-03-31
summary: "We wrap up this short series on Project GreenThumb by looking at the front end views, the build pipeline, how I added push notifications to the app and an overall progress update."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/banner_file_1616175527956.jpeg"
---

In this short blog series, I introduced you to Project GreenThumb, a project that I created to automate and monitor the process of growing seedlings with hardware, software and the cloud. If you haven't read the other posts in this series, I encourage you to do so.

- [Project GreenThumb Part 1 - Automating & Monitoring Seedling Growth With Microcontrollers & The Cloud](/posts/project-greenthumb-part-1-automating-monitoring-seedling-growth-with-microcontrollers-the-cloud)

- [Project GreenThumb Part 2 - The Data Collection](/posts/project-greenthumb-part-2-the-data-collection)

- [Project GreenThumb Part 3 - Consuming and Persisting the Sensor Data in the Cloud](/posts/project-greenthumb-part-3-consuming-and-persisting-the-sensor-data-in-the-cloud)

- [Project GreenThumb Part 4 - Reporting Queries and WebSockets](/posts/project-greenthumb-part-4-reporting-queries-and-websockets)

In this post, we'll wrap things up by looking at the front-end, how I automated the application build to deploy things to the cloud, how I added support for push notifications and finally we'll look at the current progress of the project against the stated goals. 

## Adding Simple Views to the Micronaut Application

Micronaut clearly shines as a "data first" cloud-native microservice platform, but what you may not know is that it also includes [support and integrations for server-side view rendering](https://micronaut-projects.github.io/micronaut-views/latest/guide/). To avoid blocking the Netty event loop, Micronaut handles server-side view rendering on the I/O thread pool. A number of view rendering engines are supported (Handlebars, Velocity, Freemarker, etc) but I chose [Thymeleaf](https://thymeleaf.org/) because of my slight familiarity with it over the other choices. To render a view, your controller must return a `ModelAndView` object which contains the name of the view template to render and the object to use as the model.
```java
@Get()
ModelAndView home() {
    return new ModelAndView("home", CollectionUtils.mapOf("currentView", "home"));
}
```



The view can access any model variable with the familiar `$` syntax. 

### The Front-End

There was no need to complicate the front-end. I just needed to present the data in a way that would give me a quick, full overview of the current sensor data and I feel like I accomplished that with a simplified, yet responsive layout.

The `home` view connects to the WebSocket server endpoint that I previously established and updates a list of reading values in memory (limiting it to the 50 most recent readings) when a new message is received. 
```javascript
const connect = () => {
    console.log('Connecting to WebSocket...')
    const ws = new WebSocket("ws://" + location.hostname + ":" + location.port + "/data/greenthumb");
    ws.onopen = (msg) => {
        console.log('Connected!')
    };
    ws.onmessage = (msg) => {
        const reading = new Reading(JSON.parse(msg.data));
        soilTempReadings.push({y: reading.soilTemp, x: reading.readAt});
        // keep the latest <code class="code-inline">maxPoints</code>
        if( soilTempReadings.length > maxPoints ) soilTempReadings.shift();
        if (chartsInit)  soilTempChart.update();
        
        // update the table that displays the latest values
        document.querySelector('#currentOutletState').innerHTML = reading.outletState;
        document.querySelector('#currentAirTemp').innerHTML = reading.airTemp;
        document.querySelector('#currentSoilTemp').innerHTML = reading.soilTemp;
        document.querySelector('#currentHumidity').innerHTML = reading.humidity;
        document.querySelector('#currentMoisture').innerHTML = reading.moisture;
        document.querySelector('#currentLight').innerHTML = reading.light;
    };
    ws.onclose = (e) => {
        console.log('Socket is closed. Reconnect will be attempted in 1 second.', e.reason);
        setTimeout(function() {
            connect();
        }, 1000);
    };
    ws.onerror = function(err) {
        console.error('Socket encountered error: ', err.message, 'Closing socket');
        ws.close();
    };
};
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/output_onlinegiftools__1_.gif)

For reports, a single page outputs a number of various views of the aggregated sensor data. For example, I can see the average readings by hour of day for the current day which lets me make necessary adjustments if things look out of the ordinary.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616178269894.png)

I can also gauge the long-term success of the project by seeing the averages by hour of day for all time.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616178269901.png)

Or by looking at the daily average by day:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616178269907.png)

Of course, since I have different goals for "day" vs. "night", I need a report that shows the progress against those metrics:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616178269911.png)

And finally, an overall total average for the sensor data.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616178269914.png)

## The Build (GitHub Actions)

Of course, no project would be complete without automating the build process. For that, I added a GitHub Actions workflow. The workflow checks out the code, then builds the JAR file:
```yaml
steps:
- uses: actions/checkout@v2

- name: Set up JDK 11
  uses: actions/setup-java@v1
  with:  
    java-version: '11.0.3'

- name: Grant execute permission for gradlew
  run: chmod +x gradlew
  
- name: Build with Gradle
  run: ./gradlew assemble
```



Then logs in to the Oracle Cloud Infrastructure Registry builds a Docker image (using the out-of-the-box `Dockerfile` provided by Micronaut) and pushes the Docker image to OCIR.
```yaml
- name: 'Login To OCIR'
  uses: actions-hub/docker/login@master
  env:
    DOCKER_USERNAME: ${{ secrets.OCIR_USERNAME }}
    DOCKER_PASSWORD: ${{ secrets.OCIR_PASSWORD }}
    DOCKER_REGISTRY_URL: phx.ocir.io
  
- name: 'Docker Build'
  run: docker build -t phx.ocir.io/[redacted]/[redacted]/greenthumb-client:latest .

- name: 'Docker Push'
  uses: actions-hub/docker@master
  with:
    args: push phx.ocir.io/[redacted]/[redacted]/greenthumb-client:latest
```



Finally, I log in to my VM, stop the existing Docker image, and pull and run the latest image on the VM:
```yaml
- name: 'Deploy Container'
  uses: appleboy/ssh-action@master
  with:
    host: [redacted]
    username: opc
    key: ${{ secrets.VM_PRIV_KEY }}
    script: |
      echo ${{ secrets.OCIR_PASSWORD }} | docker login phx.ocir.io --username [redacted] --password-stdin
      docker stop project-greenthumb
      docker rm project-greenthumb
      docker pull phx.ocir.io/[redacted]/[redacted]/greenthumb-client:latest
      docker run -d --name project-greenthumb --restart=always --env MICRONAUT_ENVIRONMENTS=oraclecloud --env MQTT_CLIENT_USER_NAME=${{ secrets.MQTT_CLIENT_USER_NAME }} --env DATASOURCES_DEFAULT_USERNAME=${{ secrets.DATASOURCES_DEFAULT_USERNAME }} --env MQTT_CLIENT_PASSWORD=${{ secrets.MQTT_CLIENT_PASSWORD }} --env DATASOURCES_DEFAULT_OCID=${{ secrets.DATASOURCES_DEFAULT_OCID }} --env MQTT_CLIENT_CLIENT_ID=${{ secrets.MQTT_CLIENT_CLIENT_ID }} --env DATASOURCES_DEFAULT_PASSWORD=${{ secrets.DATASOURCES_DEFAULT_PASSWORD }} --env MQTT_CLIENT_SERVER_URI=${{ secrets.MQTT_CLIENT_SERVER_URI }} --env DATASOURCES_DEFAULT_WALLET_PASSWORD=${{ secrets.DATASOURCES_DEFAULT_WALLET_PASSWORD }} -p 8080:8080 -p 80:80 phx.ocir.io/[redacted]/[redacted]/greenthumb-client:latest
```



## Push Notification Alerts

What good is collecting a bunch of data if there is no automated call to action when the data indicates it is necessary? I could have easily added some automated watering to the project, but since I'm new to growing things like this, I wanted to maintain some granulated (manual) control over that process until I was more comfortable with it. I figured it would be super handy to add push notifications using [Pushover](https://pushover.net/) so that I would get a notification when the soil moisture indicated that I should take a look at things and water the seedlings. To integrate with my Pushover account I could have dropped in the `pushover4j` [library](https://github.com/sps/pushover4j/) (side note: enough with the "4j" projects already!) but since it's just a `POST` request to the API, I decided to avoid adding another dependency and just use a [declarative http client](https://guides.micronaut.io/micronaut-http-client-groovy/guide/index.html) with Micronaut.  First, I set up my Pushover config.
```yaml
codes:
  recursive:
    pushover:
      userKey: ${CODES_RECURSIVE_PUSHOVER_USER_KEY}
      apiKey: ${CODES_RECURSIVE_PUSHOVER_API_KEY}
```



Next, I created a POJO to contain the API response:
```java
@Introspected
public class PushNotificationResponse {
    private int status;
    private String request;

    public PushNotificationResponse(int status, String request) {
        this.status = status;
        this.request = request;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public String getRequest() {
        return request;
    }

    public void setRequest(String request) {
        this.request = request;
    }
}
```



Finally, I created the client interface. Micronaut will handle all the necessary plumbing at compile-time and the client is ready to use in the application.
```java
@Client("https://api.pushover.net")
public interface PushoverClient {
    @Post(value = "/1/messages.json", produces = MediaType.APPLICATION_FORM_URLENCODED, consumes = MediaType.APPLICATION_JSON)
    Flowable<PushNotificationResponse> pushMessage(String token, String user, String message, String url);
}
```



Then I injected the client into my MQTT consumer, checked the readings when a message is received, and send a push notification (throttled to once every 20 minutes) if the soil moisture level dropped below 50%. Of course, this could be extended to other metrics and thresholds as necessary just by modifying the message argument as appropriate.
```java
int soilMoisture = (int) reading.getReadingAsMap().get("moisture");
if( (System.currentTimeMillis() - lastAlert > interval) && soilMoisture < 50) {
    PushNotificationResponse response = pushoverClient.pushMessage(
            apiKey,
            userKey,
            "Soil Moisture Alert! Current moisture: " + soilMoisture,
            "http://[redacted url]:8080/page"
    ).blockingFirst();
    lastAlert = System.currentTimeMillis();
}
```



Here's what the notification looks like on my Pixel3 XL device.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616175527935.png)

When I click on the notification I get a link to follow directly to the dashboard.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616175527939.png)

## The Progress (Results)

As of publishing, it's been 3 weeks since the seedlings were planted. There have been some minor adjustments to both hardware and software as I learn what works best for the system, but so far the results are mostly in range (or certainly extremely close to the targets). 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616175527943.png)

If we look at it from an "overall" standpoint (disregarding night/day or daily/hourly breakdown):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616175527946.png)

Data, however, only tells half the story. The results that really matter are whether or not the seedlings have sprouted and are looking healthy. To that end:

 ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616175527956.jpeg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6665618f-799f-4b46-923e-da8e14ea66ff/file_1616175527968.jpeg)

## Summary

This story doesn't conclude today and when it does conclude later on this year it will be much more difficult to quantify the achievement. You see, to me the success of this project relies on the flavor and heat of the hot sauce that it will ultimately result in, and flavor is truly subjective and depends on the tastes of the person who is judging the product. But I guess there's another way to gauge the success of this project and that is to look at the value of the experience itself. In that light, I feel like the project has already been a huge success because it gave me something to plan, build, learn from, and share with the developer communities that I work with every day. 

If you'd like to check out any of the code used in this blog series, please refer to the appropriate repos on GitHub:

- <https://github.com/recursivecodes/project-greenthumb>
- <https://github.com/recursivecodes/project-greenthumb-microcontroller>

