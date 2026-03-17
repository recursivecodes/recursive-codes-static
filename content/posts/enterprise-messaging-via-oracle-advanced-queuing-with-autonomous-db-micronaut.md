---
title: "Enterprise Messaging via Oracle Advanced Queuing with Autonomous DB & Micronaut"
slug: "enterprise-messaging-via-oracle-advanced-queuing-with-autonomous-db-micronaut"
author: "Todd Sharp"
date: 2021-06-07
summary: "In this post, we'll see how to use Oracle Advanced Queuing to publish and consume messages with Autonomous DB. We'll also look at how to integrate a Java application with the messaging queue via JMS with Micronaut."
tags: ["Cloud", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/48421478-b27c-4cef-bd33-0dce0337b299/banner_liao_je_wei_j0qoyiywiye_unsplash.jpeg"
---

I've written about messaging many, many times on this blog. And for good reason, too. It's a popular subject that developers can't seem to get enough of. In this world of distributed architectures, it's critical that services communicate with each other to ensure the application's business logic is implemented properly. It's well established that messaging is crucial for modern applications, so let's look at a messaging solution that exists in the Oracle Cloud that you may not be aware of. In fact, if you're already using Autonomous DB, then this solution is available to you at no additional charge! Allow me to introduce you to Oracle Advanced Queuing (AQ). 

What's AQ? It's exactly what it sounds like - a full-featured messaging solution right inside the database. Point-to-point, pub/sub, persistent and non-persistent messaging - all supported. There are tons of ways to interact - including via PL/SQL, JMS, JDBC, .NET, Python, Node.JS - pretty much any popular language can interface with AQ. Demos tend to be the best way to understand concepts like this, so in this post we're going to look at how to enable AQ in your Autonomous DB instance, create a queue, and enqueue and dequeue messages with PL/SQL. To complete the demo, we'll look at publishing and consuming messages from AQ from a very simple Java application written with Micronaut.

## Set Up Advance Queuing  

To set up AQ, we need to create a few users: an admin and a queue user. In the admin schema, we'll create a queue table, create and start a queue and grant the queue user permission to access it. Then we'll test out enqueuing and dequeuing a message with the queue user. All of this work will be done with PL/SQL. I like to use the old school SQL Developer desktop client for this, but you can use whichever tool you prefer for querying against your DB instance. It may be a bit older, but I found Tim Hall's [article](https://oracle-base.com/articles/9i/advanced-queuing-9i) helpful for getting started with AQ.

### Create AQ Users

Connect to your Autonomous instance as `admin` to create two users. One will be an AQ "admin" and the other will be a "user". 
```sql
CREATE USER aqdemoadmin IDENTIFIED BY "Str0ngPassword!";
GRANT connect TO aqdemoadmin;
GRANT create type TO aqdemoadmin;
GRANT aq_administrator_role TO aqdemoadmin;
GRANT UNLIMITED TABLESPACE TO aqdemoadmin;

CREATE USER aqdemouser IDENTIFIED BY "Str0ngPassword!";
GRANT connect TO aqdemouser;
GRANT aq_user_role TO aqdemouser;
GRANT UNLIMITED TABLESPACE TO aqdemouser;
```



### Create Queue Table and Queue

Now connect up as the `aqdemoadmin` user that we just created. The first step here is to create a queue table. If we wanted to, we could create a custom type for our queue payload, but since my intention for this demo is to pass JSON messages, we'll set the `queue_payload_type` to `SYS.AQ$_JMS_TEXT_MESSAGE` ([docs](https://docs.oracle.com/cd/B28359_01/appdev.111/b28419/t_jms.htm#i996967)) which will support a simple JSON string.
```sql
BEGIN
    DBMS_AQADM.create_queue_table ( 
       queue_table            =>  'aqdemoadmin.event_queue_tab', 
       queue_payload_type     =>  'sys.aq$_jms_text_message');
END;
/
```



{{< callout >}}
**Heads Up!** Native [JSON support for AQ](https://docs.oracle.com/en/database/oracle/oracle-database/21/adque/rel-changes.html#GUID-60EC22A2-48C5-4430-9032-42037FEEB09F) is available in 21c. Since 21c is not yet available on Autonomous DB, we'll use a simple text data type and pass our own JSON string in our messages.
{{< /callout >}}
Now, let's create the queue and start it.
```sql
BEGIN
    DBMS_AQADM.create_queue ( 
       queue_name            =>  'aqdemoadmin.event_queue', 
       queue_table           =>  'aqdemoadmin.event_queue_tab');
    DBMS_AQADM.start_queue ( 
       queue_name         => 'aqdemoadmin.event_queue', 
       enqueue            => TRUE);
END;
/
```



Don't forget to grant `aqdemouser` permissions to use the queue!
```sql
BEGIN
    DBMS_AQADM.grant_queue_privilege ( 
       privilege     =>     'ALL', 
       queue_name    =>     'aqdemoadmin.event_queue', 
       grantee       =>     'aqdemouser', 
       grant_option  =>      FALSE);
END;
/
```



That's it. That's all the set up that we need to do before we can start sending messages. Let's do that now!

### Enqueue and Dequeue Messages with PL/SQL

Next, connect up via your query tool of choice as the `aqdemouser` user. Using PL/SQL, enqueue (or produce) a message containing a bit of information as a JSON string.
```sql
DECLARE
    l_enqueue_options     dbms_aq.enqueue_options_t;
    l_message_properties  dbms_aq.message_properties_t;
    l_message_handle      raw(16);
    l_event_msg           sys.aq$_jms_text_message;
BEGIN
    l_event_msg := sys.aq$_jms_text_message.construct();
    l_event_msg.set_text('{"name": "Todd", "id": 9}');
    dbms_aq.enqueue(queue_name => 'aqdemoadmin.event_queue',
                   enqueue_options => l_enqueue_options,
                   message_properties => l_message_properties,
                   payload => l_event_msg,
                   msgid => l_message_handle);

    COMMIT;
END;
/
```



Now we can dequeue (or consume) the message, parse the string as a JSON object and print one of the keys from that JSON object.
```sql
SET SERVEROUTPUT ON

DECLARE
    l_dequeue_options     dbms_aq.dequeue_options_t;
    l_message_properties  dbms_aq.message_properties_t;
    l_message_handle      raw(16);
    l_event_msg           sys.aq$_jms_text_message;
    msg_text              varchar2(32767);
    obj                   json_object_t;
BEGIN
    dbms_aq.dequeue(queue_name => 'aqdemoadmin.event_queue',
                   dequeue_options => l_dequeue_options,
                   message_properties => l_message_properties,
                   payload => l_event_msg,
                   msgid => l_message_handle);

    l_event_msg.get_text(msg_text);
    /* print the raw message */
    dbms_output.put_line(msg_text);
    /* parse the JSON object */
    obj := json_object_t.parse(msg_text);
    /* print an element from the JSON object */
    dbms_output.put_line(obj.get_String('name'));
    COMMIT;
END;
/
```



## Interact with AQ with Java & Micronaut 

So far, we've created a simple queue and tested producing and consuming messages via PL/SQL. While that's useful, many developers will need to take the next step and integrate the queue into their applications. That's why it's handy to have interfaces to AQ via Python, Node, etc. If you read many of my posts, you'll know that I often use the Micronaut framework with Java because it tends to make difficult tasks quite easy to accomplish. It's no different when it comes to connecting and interacting with AQ thanks to AQ's JMS support and Micronaut's JMS module. Let's create a demo app that works with the queue we just created.

### Create a Micronaut App

If you don't have an existing Micronaut application that you'd like to work with for this demo, create a new one. It's easy to create a new app via the Micronaut CLI, like so:
```bash
$ mn create-app --build=gradle --jdk=11 --lang=java --test=spock codes.recursive.mn-aq-demo
```



### Add Dependencies

Open the new application in your favorite editor and open `build.gradle` to add a few dependencies. I prefer Gradle, but if you're more comfortable with Maven, then by all means use Maven. We're going to add some dependencies to our application. The first one that we need to add is `micronaut-jms-core` which is a module that provides integration between Micronaut and JMS. Micronaut has several dependencies for various JMS implementations (ActiveMQ Classic/Artemis, etc) but we just need the core dependency so we can create a generic broker, producer and consumer. We'll also need the Java Transaction API.
```groovy
implementation("io.micronaut.jms:micronaut-jms-core")
implementation("javax.transaction:jta:1.1")
```



We'll need the AQ api to be able to create connections to AQ via JMS.
```groovy
implementation("com.oracle.database.messaging:aqapi:19.3.0.0")
```



To create a connection to AQ via JMS, we'll eventually use an instance of [AQjmsFactory](https://docs.oracle.com/cd/B19306_01/server.102/b14291/oracle/jms/AQjmsFactory.html). The easiest way to create a connection via `AQjmsFactory` is to use a `java.sql.DataSource` that points to our Autonomous DB instance, so let's include some dependencies that will create that `DataSource` for us based on a bit of configuration that we'll look at in just a bit.
```groovy
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-sdk")
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-atp:1.2.1")
implementation(enforcedPlatform("com.oracle.database.jdbc:ojdbc-bom:21.1.0.0"))
implementation("com.oracle.database.jdbc:ojdbc8")
implementation("io.micronaut.sql:micronaut-jdbc-ucp")
```



### Modify Configuration

We're going to use Micronaut's [support for automatic Autonomous DB wallet download](/posts/automatic-autonomous-wallet-download-configuration-with-micronaut) to configure our `DataSource`, so we need to configure the OCI SDK in our `application.yml` file. This isn't mandatory, and if you'd like to manually configure your datasource it will work just the same, but I find this method the easiest since I don't have to mess with wallet downloads and distributing that wallet to test/QA/prod environments. Using this method means Micronaut will take care of the wallet download and JDBC URL creation and store the wallet in memory - nice!
```yaml
oci:
  config:
    profile: DEFAULT
```



Next, create the very basic datasource configuration. This config tells Micronaut the OCID of the Autonomous DB instance that we want to connect to so it knows which wallet to download. Also, since we're using UCP for connection pooling, we need to specify the connection factory class name. Finally, we need to configure a `walletPassword`, `username`, and `password`. Note that I'm not specifying the credentials in my YAML file - rather, I like to include them as environment properties in my run configuration so that I don't mistakenly check them in to source control!
```yaml
datasources:
  default:
    ocid: ocid1.autonomousdatabase.oc1.phx...
    connectionFactoryClassName: oracle.jdbc.pool.OracleDataSource
    walletPassword:
    username:
    password:
```



I use Intelli-J IDEA, so I set my credentials into a run configuration that passes them to the application at runtime.

### ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/48421478-b27c-4cef-bd33-0dce0337b299/file_1622851385957.png) 

### Confirm DataSource 

Now we can fire up the app and make sure Datasource is configured. You should see output similar to this in your console at this point:
```log
09:15:27.868 [main] INFO  com.oracle.bmc.Services - Registering new service: Services.BasicService(serviceName=DATABASE, serviceEndpointPrefix=database, serviceEndpointTemplate=https://database.{region}.{secondLevelDomain})
09:15:28.571 [main] INFO  c.o.b.h.s.i.BouncyCastleHelper - Instantiated provider: org.bouncycastle.jce.provider.BouncyCastleProvider
09:15:28.678 [main] INFO  com.oracle.bmc.util.JavaRuntimeUtils - Determined JRE version as Unknown
09:15:28.678 [main] WARN  c.o.bmc.http.DefaultConfigurator - Using an unknown runtime, calls may not work
09:15:28.679 [main] INFO  c.o.bmc.http.DefaultConfigurator - Setting connector provider to HttpUrlConnectorProvider
09:15:28.751 [main] INFO  com.oracle.bmc.Region - Loaded service 'DATABASE' endpoint mappings: {US_PHOENIX_1=https://database.us-phoenix-1.oraclecloud.com}
09:15:28.752 [main] INFO  c.oracle.bmc.database.DatabaseClient - Setting endpoint to https://database.us-phoenix-1.oraclecloud.com
09:15:29.679 [main] INFO  com.oracle.bmc.ClientRuntime - Using SDK: Oracle-JavaSDK/1.34.0
09:15:29.679 [main] INFO  com.oracle.bmc.ClientRuntime - User agent set to: Oracle-JavaSDK/1.34.0 (Mac OS X/10.15.7; Java/11.0.5; OpenJDK 64-Bit Server VM/11.0.5+10)
09:15:34.071 [main] INFO  i.m.o.a.j.OracleWalletArchiveProvider - Using default serviceAlias: demodb_high
09:15:34.896 [main] INFO  io.micronaut.runtime.Micronaut - Startup completed in 8497ms. Server Running: http://localhost:8080
```



Excellent! Looks like our wallet was downloaded and a connection was properly established. We'll use the newly configured `DataSource` in the next step.

### Configure JMS

Now that our app is created and configured, let's configure the JMS broker. The AQ broker is considered "unsupported" by Micronaut, but that's quite OK since we just need to call `getConnectionFactory()` on `AQjmsFactory` to get a broker. To use this, we just need to create a configuration class with a `connectionFactory()` method that is annotated with `@JMSConnectionFactory`. We'll create this class and inject our `DataSource` into it so that we can pass that to the `getConnectionFactory()` method. Sounds tricky, but it's not:
```java
package codes.recursive.aq;

import io.micronaut.context.annotation.Factory;
import io.micronaut.jms.annotations.JMSConnectionFactory;
import oracle.jms.AQjmsFactory;

import javax.jms.ConnectionFactory;
import javax.jms.JMSException;
import javax.sql.DataSource;

@Factory
public class AqJmsConfig {

    private final DataSource dataSource;

    public AqJmsConfig(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @JMSConnectionFactory("aqConnectionFactory")
    public ConnectionFactory connectionFactory() throws JMSException {
        return AQjmsFactory.getConnectionFactory(dataSource);
    }
}
```



{{< callout >}}
**Note:** We're passing an arbitrary string containing the name that we want to use to `@JMSConnectionFactory`. We'll use this string to refer back to the factory later on.
{{< /callout >}}
### Create JMS Consumer

Now we can specify a consumer which will have a `receive()` method. This method will be called every time a new message is published to AQ, kind of like our `dequeue` example in PL/SQL above, but in this case we don't have to manually invoke the consumer - it will be called automatically! Things worthy of note: the class is annotated with `@JMSListener` which uses the name that we assigned in the previous step. Also, the `receive()` method is annotated with `@Queue` to tell it which specific queue to use in AQ. Here we pass the name of the queue (`AQDEMOADMIN.EVENT_QUEUE`) that we created above. Each time a message is received, we deserialize the JSON string into a simple POJO gives us some structure to the message instead of working with an arbitrary object.
```java
package codes.recursive.aq;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micronaut.jms.annotations.JMSListener;
import io.micronaut.jms.annotations.Queue;
import io.micronaut.messaging.annotation.MessageBody;

@JMSListener("aqConnectionFactory")
public class AqConsumer {
    private static final Logger LOG = LoggerFactory.getLogger(AqConsumer.class);
    
    @Queue(value = "AQDEMOADMIN.EVENT_QUEUE", concurrency = "1-5")
    public void receive(@MessageBody String body) throws JsonProcessingException {
        ObjectMapper mapper = new ObjectMapper();
        DemoType test = mapper.readValue(body, DemoType.class);
        LOG.info(body);
    }
}
```



Here's the simple POJO that we can use to represent the incoming message. Take note that we're going to need to publish an Object with two keys: a `name` and a `num`.
```java
package codes.recursive.aq;

import io.micronaut.core.annotation.Introspected;

@Introspected
public class DemoType {
    private String name;
    private int num;

    public DemoType() {
    }

    public DemoType(String name, int num) {
        this.name = name;
        this.num = num;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getNum() {
        return num;
    }

    public void setNum(int num) {
        this.num = num;
    }
}
```



### Create JMS Producer

Finally, we can create a producer interface. This class is annotated with `@JMSProducer`, and has a `send()` method signature. This interface will be implemented at compile time and available to be injected where we need it in our application.
```java
package codes.recursive.aq;

import io.micronaut.jms.annotations.JMSProducer;
import io.micronaut.jms.annotations.Queue;
import io.micronaut.messaging.annotation.MessageBody;

@JMSProducer("aqConnectionFactory")
public interface AqProducer {
    @Queue("AQDEMOADMIN.EVENT_QUEUE")
    void send(@MessageBody String body);
}
```



### Create a Controller to Expose a Publish Message Endpoint

Let's create an endpoint that we can use to publish some test messages.
```bash
$ mn create-controller codes.recursive.controller.AqDemo
```



Here we can inject our `AqProducer`, and create an endpoint that receives a `DemoType` (which we can represent as a JSON string) and produces that message.
```java
package codes.recursive.controller;

import codes.recursive.aq.AqProducer;
import codes.recursive.aq.DemoType;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.MediaType;
import io.micronaut.http.annotation.*;

@Controller("/aqDemo")
public class AqDemoController {

    private final AqProducer aqProducer;

    public AqDemoController(AqProducer aqProducer) {
        this.aqProducer = aqProducer;
    }

    @Post(value = "/", produces = MediaType.APPLICATION_JSON)
    public HttpResponse send(@Body DemoType message) throws JsonProcessingException {
        aqProducer.send(new ObjectMapper().writeValueAsString(message));
        return HttpResponse.ok();
    }
}
```



Before we launch the app, open up `logback.xml` and configure logging to gain insight into the JMS module.
```xml
<logger name="io.micronaut.jms" level="trace" />
```



Now we can startup the application! This time, notice that the JMS module creates the necessary bean, registers the binders and queue listeners.
```log
13:30:03.158 [main] DEBUG i.m.j.c.JMSConnectionFactoryBeanProcessor - created JMSConnectionPool bean 'aqConnectionFactory' for ConnectionFactory oracle.jms.AQjmsConnectionFactory
13:30:03.239 [main] DEBUG i.m.j.bind.JMSArgumentBinderRegistry - registered binder io.micronaut.jms.bind.DefaultBodyArgumentBinder@539c4830
13:30:03.240 [main] DEBUG i.m.j.bind.JMSArgumentBinderRegistry - registered binder io.micronaut.jms.bind.DefaultHeaderArgumentBinder@6f1fa1d0
13:30:03.241 [main] DEBUG i.m.j.bind.JMSArgumentBinderRegistry - registered binder io.micronaut.jms.bind.MessageHeaderArgumentBinder@52ba685a
13:30:03.241 [main] DEBUG i.m.j.bind.JMSArgumentBinderRegistry - registered binder io.micronaut.jms.bind.DefaultMessageArgumentBinder@71d55b7e
13:30:07.516 [main] DEBUG i.m.j.listener.JMSListenerContainer - registered queue listener io.micronaut.jms.configuration.AbstractJMSListenerMethodProcessor$$Lambda$659/0x00000008009efc40@684ce74c for destination 'AQDEMOADMIN.EVENT_QUEUE'; transacted: false, ack mode: 1
13:30:07.516 [main] DEBUG i.m.j.l.JMSListenerContainerFactory - registered queue listener for 'AQDEMOADMIN.EVENT_QUEUE' io.micronaut.jms.configuration.AbstractJMSListenerMethodProcessor$$Lambda$659/0x00000008009efc40@684ce74c for type 'io.micronaut.core.type.DefaultArgument' and pool JMSConnectionPool{initialSize=1, maxSize=50, connectionFactory=oracle.jms.AQjmsConnectionFactory@65593327}; transacted: false, ack mode 1
13:30:07.993 [main] INFO  io.micronaut.runtime.Micronaut - Startup completed in 13621ms. Server Running: http://localhost:8080
```



We can produce a message using cURL to send a POST to the endpoint we just created.
```bash
$ curl -X POST -H "Content-Type: application/json" http://localhost:8080/aqDemo -d '{"name": "Todd", "num": 9}'
```



And observe that the `AqConsumer` receives and logs the message!
```log
13:32:39.601 [pool-2-thread-1] INFO  codes.recursive.aq.AqConsumer - {"name":"Todd","num":9}
```



### Enhanced Debugging for AQ

If things happen to go wrong, we can enable verbose logging for the AQ JMS API. The "proper" way to enable debugging is to set the `oracle.jms.traceLevel` system property, but that didn't seem to work for me. Instead, to enable debugging I added the following to `Application.java`:
```java
public class Application {
    public static void main(String[] args) {
        AQjmsOracleDebug.setDebug(true);
        AQjmsOracleDebug.setTraceLevel(6);
        Micronaut.run(Application.class, args);
    }
}
```



{{< callout >}}
**Beware!** The debugging output can be rather noisy at trace level 6! Try a lower trace level for less noise, or only enable when you are troubleshooting issues!
{{< /callout >}}
Here's an example of the rather verbose output when debugging is enabled and a message is received:
```log
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsListenerWorker.dispatchOneMsg:  Received the message: ID:C368B981C1861B77E0539414000A4A06
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsSimpleScheduler.feedData:  Got a non null message, the sleep time is reset to 0
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsListenerWorker.dispatchOneMsg:  Before calling onMessage method
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsListenerWorker.dispatchOneMsg:  After calling onMessage method
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsSession.inGlobalTransRechecked:  entry
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsSession.inGlobalTransRechecked:  oracle.jms.useEmulatedXA is on
Thread-2 [Fri May 28 14:05:50 EDT 2021] EmulatedXAHandler.inGlobalTrans:  entry, reCheck=true
Thread-2 [Fri May 28 14:05:50 EDT 2021] EmulatedXAHandler.checkForGlobalTxn:  entry
Thread-2 [Fri May 28 14:05:50 EDT 2021] EmulatedXAHandler.inGlobalTrans:  exit
Thread-2 [Fri May 28 14:05:50 EDT 2021] AQjmsSession.inGlobalTransRechecked:  exit
Thread-2 [Fri May 28 14:05:50 EDT 2021] [Thread-2] getLock (OJMS.Session.ora-recursivecodes-mb.20641d3f:179b421692e:-8000.3) :  after sync, timeout=0
Thread-2 [Fri May 28 14:05:50 EDT 2021] [Thread-2] getLock (OJMS.Session.ora-recursivecodes-mb.20641d3f:179b421692e:-8000.3) :  Thread Thread-2 try to require lock mulitple times, grant it again.
Thread-2 [Fri May 28 14:05:50 EDT 2021] [Thread-2] getLock (OJMS.Session.ora-recursivecodes-mb.20641d3f:179b421692e:-8000.3) :  acquired session lock, usecount=2
14:05:50.624 [pool-2-thread-1] INFO  codes.recursive.aq.AqConsumer - {"name":"Todd","num":9}
```



{{< callout >}}
**Heads Up!**  The JMS listener will go to "sleep" if there are no incoming messages - and the sleep interval will double each time it goes to sleep up to 15000ms (15 seconds). You can set a max sleep time by setting a system property as shown below.
{{< /callout >}}
```java
public class Application {
    public static void main(String[] args) {
        AQjmsOracleDebug.setDebug(true);
        AQjmsOracleDebug.setTraceLevel(6);
        System.setProperty("oracle.jms.maxSleepTime", "5000");
        Micronaut.run(Application.class, args);
    }
}
```



## Summary

In this post, we looked at how to get started with Oracle Advanced Queueing for messaging. We saw how to configure AQ, which is included at no charge with our Autonomous DB instances in the Oracle Cloud. We also saw how to create a simple Java application with Micronaut that uses JMS to publish/subscribe to and from our AQ. If you'd like to see the full code used in this example, feel free to check it out on [GitHub](https://github.com/recursivecodes/mn-aq-demo).

Photo by [Liao Je Wei](https://unsplash.com/@alexliao?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

