---
title: "Bridging MQTT and Oracle Streaming Service (OSS) with Node.js"
slug: "bridging-mqtt-and-oracle-streaming-service-oss-with-node-js"
author: "Todd Sharp"
date: 2021-12-10
summary: "In this post, we'll look at bridging messaging protocols again, but this time we'll look at connecting MQTT to Oracle Streaming Service (OSS)."
tags: ["APIs", "Messaging", "Node"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/umer-sayyam-SHP1t8EduMY-unsplash.jpeg"
---

Recently, we've been taking a dive into messaging. In the last post, we talked about creating a messaging "bridge" so that we could consume an incoming MQTT topic and produce an outgoing stream of messages to an Oracle Advanced Queuing (AQ) queue. It worked, and it adequately addressed the challenge of communicating between messaging protocols within our application architecture. In this post, let's take a similar approach, but instead of producing messages to AQ, we'll publish to an Oracle Streaming Service (OSS) topic. I've certainly talked about OSS before on this blog, so you are hopefully already familiar with it, but if not you can think of it as a real-time, serverless event streaming platform that just happens to be compatible with Apache Kafka. When it comes to messaging, I've personally found that managed options are quite often the best option. As a developer, I don't have a whole lot of time to deploy and maintain a messaging platform, so having a service that takes care of that and allows me to interact with topics/streams via an open-source API (such as the Kafka SDK) is a win in my book.

To help you visualize things, here's a high-level overview of the bridge architecture. It'll look pretty similar to the MQTT-AQ bridge we talked about in the last post.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/58498c6c-cbde-404a-a070-912cd28e90cb/upload_5a530261030450799297f558e03ecc78.png)

The cool part about this particular bridge is that it takes even less work to implement than the MQTT-AQ bridge. In fact, other than configuration (via a JSON file), it's only 7 lines of code. This time, we'll rely on an existing Node module instead of writing the low-level code ourselves to broker the message between protocols. But we'll look at the internals of that module to see how it does what it does so that we can do it ourselves if we need to.  

## Assumptions 

Like the last post, we'll assume that we already have an MQTT server setup to handle incoming messages.  Again, if you need to set up your own you can refer to my post about running [RabbitMQ in an "always free" instance in the Oracle Cloud](https://blogs.oracle.com/developers/post/getting-started-with-rabbitmq-in-the-oracle-cloud), my post about running Mosquitto in the Oracle Cloud, or [choose your favorite](https://mqtt.org/software/) and get it up and running.

## Create Project 

For this bridge, we'll take advantage of the [MQTT-Kafka bridge](https://github.com/nodefluent/mqtt-to-kafka-bridge) project by [nodefluent](https://github.com/nodefluent).
```bash
npm init
```



### Install Dependencies 

Before I could install the `mqtt-to-kafka-bridge` module, I had to first tell the linker where to find OpenSSL on my machine (since I'm using a Mac).  To do this, I set the following two variables in my shell:
```bash
export CPPFLAGS=-I/usr/local/opt/openssl/include
export LDFLAGS=-L/usr/local/opt/openssl/lib
```
```bash
npm install mqtt-to-kafka-bridge
```



See install notes if on Mac: <https://www.npmjs.com/package/node-rdkafka>

## Create Stream (If Needed) 

Create a stream. Search for 'Streaming' in the search bar and click on the result in 'Services'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b69a1375-1e77-4af6-8cfc-5b5896b66186/upload_ba0b2ca179949a9928e2df934bab8798.png)

On the stream list page, click on 'Create Stream'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5f66ef35-80cf-4bb8-9d01-6992b40b0eba/upload_c5c0f6133cb604623d7148890702ae18.png)

Name the stream (#1), choose 'Select Existing Stream Pool' (#2), choose 'Default Pool' (#3), and specify the message retention period (#4) and number of partitions (#5).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b9c41637-12f5-4d08-aa2b-3c78bf68db5a/upload_f5c843c8b32c3581ed100a95ccaae9cc.png)

Once the stream is created, copy the stream pool OCID from the stream details page. We will need this, later on, to connect with the Kafka SDK.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3970fd10-6a69-44af-89cd-c7ecd2dadfa7/upload_ac9569ad6def8daf1992a0ea4373f31f.png)

## Create Config 

In order to create our configuration for our bridge, we will need to create a dedicated service user and generate an auth token for that user.

### Create Auth Token (If Needed) 

Create a dedicated user for the streaming service. Search for 'Users' in the search bar and click on the result in 'Services'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/117f6e2e-2f88-460f-94c1-16c27e5e5be9/upload_b217fd19e918710f1d32094523099650.png)

Click 'Create User' and populate the dialog to create an IAM user for the streaming service.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/80416304-a832-450b-8ba8-f386cdb43a16/upload_06f76c7bd3f05b513bed6038399d9594.png)

After the new user is created, go to the user details page and generate an auth token:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c84c6016-1c31-4da3-9383-0540a5147c85/upload_ec75e0a471896317866dd02686414720.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/398965fc-cb9f-4a9d-a4a9-681ccc1be766/upload_07cd95b5a339071255b0ddde442c2b1a.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/335c82bc-8b91-45a9-bbac-3ad2d21ea641/upload_2896bafd663659e2739a12cb0c9162ad.png)

Copy the token and keep it handy - you can not retrieve it after you leave the 'Generate Token' dialog. Now, we'll need to create a group, add the new user to that group, and create a group policy:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1fc58791-ec1b-4dba-abff-c3228e7141c8/upload_2a58366fd4566fa8994ada656cb0b50b.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6e5af180-e6c5-4df8-b4ef-07a9c87137ef/upload_02fff8b1d1525bd4f0f6d12935266a4b.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c1b7edcd-1f18-4004-b7de-b831b5972086/upload_e4716591d7800908b461ebf7ca9e7b06.png)

Now we have a user with an auth token, in a group that can work with streams!

## Create Script 

At this point we can get down to the business of creating the bridge. The MQTT-Kafka bridge module requires us to create a config file to define our connection information. Create a file called `config.js` and populate it as such. We'll add more config in just a second.
```javascript
"use strict";

module.exports = {
}
```



Now we add a block to configure our credentials for MQTT. Substitute your credentials here, obviously! 
```javascript
// mqtt connection options
mqtt: { // # see https://github.com/mqttjs/MQTT.js#mqttclientstreambuilder-options
    url: null,
    options: {
        clientId: "mqtt-oss-demo-client",
        username: "mqtt_user",
        password: "passw3rdzrule!",
        host: "your.mqtt.com",
        port: 1883,
        protocolId: "MQIsdp", //MQTT
        protocolVersion: 3,
    }
}
```



Next, we'll define our OSS configuration in the `kafka` block. When we're using the Kafka compatible endpoint for OSS, we need to define our username in the following format:`[tenancyName]/[username]/[stream pool OCID]`. Your endpoint might also be different, depending on your region. See [the docs](https://docs.oracle.com/en-us/iaas/Content/Streaming/Tasks/kafkacompatibility_topic-Configuration.htm) if you get stuck at any point! 
```javascript
kafka: { // # see https://github.com/nodefluent/node-sinek/blob/master/lib/librdkafka/README.md
    logger: undefined,
    noptions: {
        "debug": "all",
        "metadata.broker.list": "streaming.us-phoenix-1.oci.oraclecloud.com:9092",
        "security.protocol": "SASL_SSL",
        "sasl.mechanisms": "PLAIN",
        "sasl.username": "[tenancyName]/[username]/ocid1.streampool.oc1.phx...", //[tenancyName]/[username]/[stream pool OCID]
        "sasl.password": "[your auth token]", // auth token
        "client.id": "mqtt-oss-demo-client",
        "event_cb": true,
        "compression.codec": "none",
        "retry.backoff.ms": 200,
        "message.send.max.retries": 10,
        "socket.keepalive.enable": true,
        "queue.buffering.max.messages": 100000,
        "queue.buffering.max.ms": 1000,
        "batch.num.messages": 1000000,
        "api.version.request": true,
    },
    tconf: {
        "request.required.acks": 1,
    }
}
```



Add a routing block to define which MQTT queue(s) get routed to which OSS topics.
```javascript
routing: {
    //"*": "*", // from all to all (indiviudally 1:1)
    //"*": "kafka-test", // from all to single kafka-test topic
    //"mqtt-topic": "kafka-topic", // from mqtt-topic to kafka-topic only
    "demo/one": "demo-stream"
}
```



That's the credentials portion of the config. There are more configuration options to set which you can [find in the sample on GitHub](https://github.com/nodefluent/mqtt-to-kafka-bridge/blob/master/example/config.js). Now we can create the server. If you remember from above, that's a whole 7 lines of code. Create `index.js` and populate:
```javascript
const Bridge = require("mqtt-to-kafka-bridge");
const config = require("./config.js");
const bridge = new Bridge(config);
bridge.on("error", console.error);
bridge
    .run()
    .catch(console.error);
```



That's it. That's the whole bridge.

### Run Script 

Let's test it out! Run the server with `npm start`, and observe the console.
```log
[nodemon] 1.19.0
[nodemon] to restart at any time, enter `rs`
[nodemon] watching: *.*
[nodemon] starting `node index.js`
  mqtttokafka:bridge Routing configuration { 'demo/one': 'demo-stream' } +0ms
  mqtttokafka:bridge Starting.. +3ms
  mqtttokafka:http Starting.. +0ms
  mqtttokafka:http Listening @ http://localhost:3967 +5ms
  mqtttokafka:bridge Started. +940ms
```



## Produce MQTT Message 

We're ready to produce a message to MQTT and see if it gets published to our topic in OSS! Using your favorite CLI tool, publish a new message to the topic that you configured the bridge to listen on.
```bash
mosquitto_pub -t demo/one -h rabbitmq.toddrsharp.com -u $RABBIT_USER -P $RABBIT_PASSWORD -p 1883 -m test
```



You'll notice the bridge processing the incoming message from MQTT.
```log
mqtttokafka:bridge routing for topic demo/one test +15s
```



Now check your stream in the Oracle Cloud Console:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d3c62fd4-076f-4e77-bce1-20ce1c480fc2/upload_1fe755d4b89500db348d1a8fe8f4fcaa.png)

Success! We have implemented an MQTT-OSS bridge!

## Summary 

We took a fun journey across a bridge between MQTT and Oracle Streaming Service (OSS). This helps our applications communicate between incompatible profiles which makes them flexible and easy to work with from our favorite languages and frameworks.

Photo by [Umer Sayyam](https://unsplash.com/@sayyam197?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/bridge?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
