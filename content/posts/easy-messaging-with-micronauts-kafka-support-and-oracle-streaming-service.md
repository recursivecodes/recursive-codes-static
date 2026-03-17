---
title: "Easy Messaging With Micronaut's Kafka Support And Oracle Streaming Service "
slug: "easy-messaging-with-micronauts-kafka-support-and-oracle-streaming-service"
author: "Todd Sharp"
date: 2019-11-15
summary: "In this post we'll look at using Micronaut's built in support for Kafka to easily produce and consume messages from Oracle Streaming Service."
tags: ["Cloud", "Java", "Open Source"]
keywords: "Cloud, Kafka, message, Streams, microservices, Java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/banner_cam_adams_jz4gnqznxtu_unsplash.jpg"
---

Last month [I wrote about an upcoming feature enhancement](/posts/migrate-your-kafka-workloads-to-oracle-cloud-streaming) to make it very easy to use the Kafka SDKs to produce and consume messages from Oracle Streaming Service. In today's post, I want to show you an even easier way to work with Oracle Streaming Service by using [Micronaut](https://micronaut.io)'s built-in support for Kafka. It only takes a bit of set up and configuration and once that is complete you'll be pleasantly surprised at how few lines of code it takes to send and receive messages from your stream.

I'm going to repurpose some content from my last post for those who may not be familiar with Oracle Streaming Service. If you've already read that post then you can [skip ahead to getting the Micronaut app up and running](#micronaut).

**Note**!  The Kafka compatibility feature is currently in ***Limited Availability***, but will soon be available for all projects (leave a comment here if you are interested in participating in the Limited Availability testing period). 

First up, we'll set up a stream and create a user and token and collect some other info to be used to configure our Micronaut application later on.

## Setting Up A Stream

First things first, let's quickly set up a Stream topic for this demo. From the Oracle Cloud dashboard console, select 'Analytics' -\> 'Streaming'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_08_56_52.jpg)

On the Stream List page, click 'Create Stream' (choose the proper compartment to contain this stream in the left sidebar if necessary):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_08_57_32.jpg)

In the 'Create Stream' dialog, name the stream and enter a value for Retention (how long a message is kept on a topic before it is discarded):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_08_58_58.jpg)

Enter the desired number of partitions and then click 'Create Stream'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_08_59_17.jpg)

You'll be taken directly to the details view for the new stream, and in about 30 seconds your stream will be shown in 'Active' state.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_08_14.jpg)

Now we'll need to grab the stream pool ID that our stream has been placed into. If you haven't specified a pool, your stream will be placed in a "Default Pool". Click on the pool name on the stream details page:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_12_18_12_21_52.png)

On the stream pool details page, copy the stream pool OCID and keep it handy for later:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_12_18_12_24_12.png)

## Create A Streams User

Next up, let's create a dedicated user for the streaming service. Click on 'Users' under 'Identity' in the console sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_12_18.jpg)

Click 'Create User' and populate the dialog:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_15_36.jpg)

After the new user is created, go to the user details page and generate an auth token:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_20_07.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_20_32.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_20_46.jpg)

Copy the token and keep it handy - you can not retrieve it after you leave the 'Generate Token' dialog. Now, we'll need to create a group, add the new user to that group, and create a group policy:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_16_40.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_17_03.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_10_08_09_18_10.jpg) 

Great, now we have a user with an auth token, in a group that can work with streams. We also have our stream pool OCID, so we're ready to dig into some code.

## Creating The Micronaut App 

Now let's create our Micronaut application. By default, if we create an application using the Kakfa profile with the Micronaut CLI, we will **not** get an HTTP server. That's OK for this demo, but keep that in mind when you're building your applications as that may not be ideal for your particular requirements. You can certainly add the `http-server-netty` dependency (or add Kafka to an existing microservice) if that's what you need. So, let's create a simple app via the CLI by running:
```bash
mn create-app mn-oss-kafka --profile kafka
Resolving dependencies..
| Generating Java project...
| Application created at /Users/trsharp/Projects/scratch/micronaut/mn-oss-kafka
```



Next, create an environment variable (I like to set up a 'Run/Debug Configuration' in my IDE that sets the ENV var for me) named `KAFKA_SASL_JAAS_CONFIG` and set the value by using the following format by substituting the proper values from above:
```bash
org.apache.kafka.common.security.plain.PlainLoginModule required username="[tenancyName]/[username]/[stream pool OCID]" password="[auth token]";
```



The rest of our configuration will take place in our `application.yml` file, so open it up (it's located at `/src/main/resources`) and modify it like so:
```yaml
---
micronaut:
  application:
    name: mn-oss-kafka
---
kafka:
  bootstrap:
    servers: streaming.us-phoenix-1.oci.oraclecloud.com:9092
  security:
    protocol: SASL_SSL
  sasl:
    mechanism: PLAIN
  key:
    serializer: org.apache.kafka.common.serialization.StringSerializer
    deserializer: org.apache.kafka.common.serialization.StringDeserializer
  value:
    serializer: org.apache.kafka.common.serialization.StringSerializer
    deserializer: org.apache.kafka.common.serialization.StringDeserializer
  retries: 5
  max:
    request:
      size: 1048576
    partition:
      fetch:
        bytes: 1048576
  group:
    id: group-0
```



**Note**: You may need to change the region value in "`kafka.bootstrap.servers`" to the region in which your streaming topic was created.

Now, let's create our Producer and Consumer by running a few more CLI commands:
```bash
mn create-kafka-producer Message
mn create-kafka-listener Message
```



These CLI commands will create two new files in the `mn.oss.kafka` package: `MessageProducer.java` and `MessageListener.java`. Let's first open up `MessageProducer.java` which you'll notice is an interface. Micronaut will take this annotated interface at compile time and implement the proper concrete implementation that will be used at runtime based on the information we provide.  We can simply add a method signature for `sendMessage()` that takes a key and a message like so:
```java
@KafkaClient
@Requires(property = "kafka.sasl.jaas.config")
public interface MessageProducer {
    @Topic("kafka-compatible-test")
    void sendMessage(@KafkaKey String key, String value);
}
```



And we'll be able to inject and utilize the producer in our application. To use the producer, open up `Application.java` and add a constructor and inject the `MessageProducer`. Then add an `EventListener` for the `StartupEvent` that we can use to produce some test messages. Once complete, your Application class should look like so:
```java
public class Application {

    MessageProducer messageProducer;

    public Application(MessageProducer messageProducer) {
        this.messageProducer = messageProducer;
    }

    public static void main(String[] args) {
        ApplicationContext applicationContext = Micronaut.run(Application.class);
    }

    @EventListener
    @Async
    public void onStartup(StartupEvent event) {
        for(int i=0; i<10; i++) {
            String key = UUID.randomUUID().toString();
            String val = "Message " + i + " from Micronaut!";
            messageProducer.sendMessage(key, val);
            System.out.println("Sent message #" + i + " to topic.");
        }
        System.out.println("All messages sent to consumer");

    }
}
```



At this point you can run the application with `./gradlew run`:
```bash
Sent message #0 to topic.
Sent message #1 to topic.
Sent message #2 to topic.
Sent message #3 to topic.
Sent message #4 to topic.
Sent message #5 to topic.
Sent message #6 to topic.
Sent message #7 to topic.
Sent message #8 to topic.
Sent message #9 to topic.
All messages sent to consumer
```



Now head over to the Oracle Cloud console and refresh your topic to see the test messages:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4fe88de1-8ddf-4038-a749-755592c5e1a9/2019_11_14_13_43_25.png)

Awesome! We've very easily produced some messages to our Oracle Stream. But what about consuming?  That's just as easy. Open up `MessagerListener.java` and add a method to be called when the topic has an incoming message. It'll receive several arguments including the key, message and more:
```java
@KafkaListener(offsetReset = OffsetReset.EARLIEST)
public class MessageListener {

    @Topic("kafka-compatible-test")
    public void receive( @KafkaKey String key, String message, long offset, int partition, String topic, long timestamp) {
        System.out.println("********************** Message Incoming **********************");
        System.out.println("Key: " + key);
        System.out.println("Message: " + message);
        System.out.println("Offset: " + offset);
        System.out.println("Partition: " + partition);
        System.out.println("Topic: " + topic);
        System.out.println("Timestamp: " + timestamp);
    }

}
```



If you want, you can instead receive a `ConsumerRecord` object or even use Reactive types in your listener. Read the Micronaut docs for more info on that. Run the app again, and you'll see the listener in action:
```bash
********************** Message Incoming **********************
Key: 5f0940f8-7395-42a4-abb2-9ed09b7129b6
Message: Message 0 from Micronaut!
Offset: 138
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757267944
********************** Message Incoming **********************
Key: 774c8099-17d3-4843-9924-00291e95c427
Message: Message 1 from Micronaut!
Offset: 139
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268409
********************** Message Incoming **********************
Key: 331c1e74-b766-4192-aa06-c57a8c9b5255
Message: Message 2 from Micronaut!
Offset: 140
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268467
********************** Message Incoming **********************
Key: 2766226e-4689-4f28-824a-6cdb5ed675ac
Message: Message 3 from Micronaut!
Offset: 141
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268526
********************** Message Incoming **********************
Key: 858163b7-5606-4856-88cc-692ecc421dd8
Message: Message 4 from Micronaut!
Offset: 142
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268585
********************** Message Incoming **********************
Key: 2de64a0d-16b6-4b1a-96e6-f24788603025
Message: Message 5 from Micronaut!
Offset: 143
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268643
********************** Message Incoming **********************
Key: d022fc09-f9c2-477a-86f2-5afd111751c3
Message: Message 6 from Micronaut!
Offset: 144
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268700
********************** Message Incoming **********************
Key: 7f4e9498-481a-479b-bb4d-1e1cf6441e90
Message: Message 7 from Micronaut!
Offset: 145
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268759
********************** Message Incoming **********************
Key: 2b685ffc-bbbb-4e41-9ada-7d295d3fd812
Message: Message 8 from Micronaut!
Offset: 146
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268818
********************** Message Incoming **********************
Key: 337d7cbc-46d0-4fde-9b07-81ca96fce729
Message: Message 9 from Micronaut!
Offset: 147
Partition: 0
Topic: kafka-compatible-test
Timestamp: 1573757268876
```



And that's it! Full support for Oracle Streaming Service via Micronaut's Kafka annotations. I've barely scratched the surface of Micronaut's Kafka support. Please [read the full documentation](https://micronaut-projects.github.io/micronaut-kafka/latest/guide/) to learn what else is possible.

You can check out all of the code from this post on GitHub: <https://github.com/recursivecodes/mn-oss-kafka>

Photo by [Cam Adams](https://unsplash.com/@camadams?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/stream?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
