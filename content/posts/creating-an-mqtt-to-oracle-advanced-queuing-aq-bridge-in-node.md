---
title: "Creating an MQTT to Oracle Advanced Queuing (AQ) Bridge in Node"
slug: "creating-an-mqtt-to-oracle-advanced-queuing-aq-bridge-in-node"
author: "Todd Sharp"
date: 2021-12-03
summary: "In this post, we'll look at how it's possible to communicate between incompatible messaging protocols by creating a messaging bridge."
tags: ["Messaging", "Node"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/tower-bridge-gdb7444262_1280.jpeg"
---

In my last post, we looked at how to use the Node `oracledb` module to produce (`enqueue`) and consume (`dequeue`) messages from an Oracle Advanced Queuing (AQ) queue. This approach works well when we've got control over the messaging infrastructure and can set up both the producer and consumer. But sometimes reality is a bit different and the reality of our environments dictates that we need to consume from (or produce to) a messaging platform that we didn't necessarily choose or implement ourselves. For example, maybe the service that your team is working to implement needs to consume messages from an MQTT topic and do "something" with those messages. Your business needs will dictate what that "something" is - maybe filter the incoming messages based on some criteria. Maybe trigger some workflow, or persist all/some of the data. After you've worked with the incoming message, maybe your service needs to publish another message indicating that the processing is complete. Or, maybe you just need to pass the message on without any processing, but to an endpoint that speaks a different protocol? I know this sounds contrived, but the reality is that it's quite common to need to "bridge" different messaging protocols together. In this post, we'll enhance the application that we built in the last post to add an MQTT to AQ bridge. You just might be surprised at how little code is required to build this bridge.

There's not much to this. Simple pub/sub style messaging involves a message "source" (or the "producer"), possibly an intermediate filter, and a message "sink" (or the "consumer"). This requires some sort of messaging platform. There are several to choose from (some utilizing different protocols among them) and each has its different strengths and weaknesses. We won't go deep into messaging protocols in this post (that's a topic for another day). To help visualize this so that we can fully understand why a bridge is necessary, let's take a look at a basic architecture that uses [MQTT](https://mqtt.org/) (a very lightweight protocol commonly used in IoT applications).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/fe59ce84-41a0-41f6-863c-a8c02cb30bcf/upload_1bc9ae4ad41646f31e0fa8b8c09008dd.png)

In a "perfect" world, this architecture works well. But as stated earlier, sometimes we don't have full control over the architecture. For whatever reason, sometimes it is necessary to "bridge" between messaging protocols.

## Assumptions 

We'll assume that you've already got an MQTT server setup and ready for incoming messages, but if you've not done that yet, consider my post on running [RabbitMQ in an "always free" instance in the Oracle Cloud](https://blogs.oracle.com/developers/post/getting-started-with-rabbitmq-in-the-oracle-cloud), or feel free to get your own MQTT server running (there are [tons of options](https://mqtt.org/software/) that you can choose from).

## Update Environment Config 

If you recall, in the last post we set up a `.env` file to store our application credentials. Before we can create a bridge, let's add some configuration to the .env file that we'll need in order to connect to the MQTT topic.
```text
RABBIT_USER=rabbit
RABBIT_PASSWORD=bunny
RABBIT_HOST=yourhost.rabbit.com
RABBIT_PORT=1883
MQTT_TOPIC=demo/one
MQTT_PROTOCOL=MQIsdp
MQTT_VERSION=3
```



I'm connecting to an older MQTT topic that uses version 3, so my MQTT_PROTOCOL and MQTT_VERSION might be different than yours. Refer to the [documentation for the MQTT node module](https://www.npmjs.com/package/mqtt) to determine the values necessary for your server.

## Create the Bridge Service 

Essentially we need to consume an MQTT topic, and for each incoming message, we need to produce a new message in our AQ queue. Basically, this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1516bc01-0080-49ed-83be-b62f015fc738/upload_00d433ded118f16b43bb6889c3261b49.png)

Remember, we're building upon the application that we started in the last post. Let's start by adding the `mqtt` module to the application.
```bash
npm install mqtt
```



We'll create our bridge as a service called `MqttAqBridge`. To get started, we'll inject the `QueueService` that we built in the last post. Side note: we can see here the advantage of encapsulating functionality into services since we can easily use the `QueueService` from multiple places within the application. We'll need the queue service to produce the incoming MQTT messages that the bridge is consuming to AQ. In the bridge class, we add an init method that we'll use to pass in credentials and meta info necessary for the bridge to communicate with the MQTT topic. Also, we initialize a few counters (`incomingProcessed`, `outgoingSent`, and `sendErrors`) to enable us to provide stats later on.
```javascript
const mqtt = require('mqtt');
const queueService = require('./QueueService');
const debug = require('debug')('mqtt-aq-bridge'); //optional
debug.log = console.log.bind(console);

class MqttAqBridge {

    init(topic, host, username, password, port, protocolId, protocolVersion, config) {
        this.incomingProcessed = 0; // count of incoming mqtt messages 
        this.outgoingSent = 0; // count of messages sent to AQ
        this.sendErrors = 0; // count of errors sending to AQ
        this.mqttClient = null;
        this.topic = topic;
        this.host = host;
        this.username = username;
        this.password = password;
        this.port = port;
        this.protocolId = protocolId;
        this.protocolVersion = protocolVersion;
        this.config = config;
    }

}

module.exports = new MqttAqBridge();
```



Next, we will add a `connect()` method. The MQTT client has [configurable options](https://github.com/mqttjs/mqtt-packet#connect), so let's be flexible and accept an object of options. We'll merge the options object with our credentials and pass that into the `mqtt.connect()` method to create a client.
```javascript
const options = Object.assign({}, this.config, {
    protocolId: this.protocolId,
    protocolVersion: +this.protocolVersion,
    username: this.username,
    password: this.password,
    port: this.port,
    host: this.host,
});
this.mqttClient = mqtt.connect(null, options);
```



Next, let's add a callback for errors. We'll print errors to the console, but in your application, you can do whatever you need to.
```javascript
this.mqttClient.on('error', (err) => {
    debug(err);
    this.mqttClient.end();
});
```



Now we'll subscribe to the 'connect' event. Again, just printing a message to the console here. Do whatever you need in your application!
```javascript
this.mqttClient.on('connect', () => {
    debug(`MQTT client connected!`);
});<br>
```



Next, we'll subscribe to the topic:
```javascript
this.mqttClient.subscribe(this.topic, {
    qos: 0
});
```



Subscribe to the 'close' event.
```javascript
this.mqttClient.on('close', () => {
    debug(`MQTT client disconnected!`);
});
```



Finally, we'll listen for incoming messages. Here's where the real "magic" happens, and there's not much to it. If you refer to the diagram above, you'll know that the only thing we need to do here is publish the incoming message to the outgoing AQ queue. And we do that with our `QueueService`. 
```javascript
this.mqttClient.on('message', (incomingTopic, message) => {
    this.incomingProcessed++;
    debug(`Received message '${message.toString()}' from topic: '${incomingTopic}.'`);
    try {
        /* 
             do something with the message:
             process it, filter it, persist it... whatever.
             then pass it along with AQ
        */
        debug(`Sending message to AQ queue: '${queueService.queueName}'.`);
        queueService.enqueueOne(JSON.parse(message.toString()))
        this.outgoingSent++;
    } catch (e) {
        debug(e);
        this.sendErrors++;
    }
});
```



Since we broke it up into several bits above, here is the entire `connect()` method so you can see it in full.
```javascript
connect() {
    const options = Object.assign({}, this.config, {
        protocolId: this.protocolId,
        protocolVersion: +this.protocolVersion,
        username: this.username,
        password: this.password,
        port: this.port,
        host: this.host,
    });
    this.mqttClient = mqtt.connect(null, options);

    this.mqttClient.on('error', (err) => {
        debug(err);
        this.mqttClient.end();
    });

    this.mqttClient.on('connect', () => {
        debug(`MQTT client connected!`);
    });

    this.mqttClient.subscribe(this.topic, {
        qos: 0
    });

    this.mqttClient.on('message', (incomingTopic, message) => {
        this.incomingProcessed++;
        debug(`Received message '${message.toString()}' from topic: '${incomingTopic}.'`);

        try {
            /* 
                do something with the message:
                process it, filter it, persist it... whatever.
                then pass it along with AQ
            */
            debug(`Sending message to AQ queue: '${queueService.queueName}'.`);
            queueService.enqueueOne(JSON.parse(message.toString()))
            this.outgoingSent++;
        } catch (e) {
            debug(e);
            this.sendErrors++;
        }
    });

    this.mqttClient.on('close', () => {
        debug(`MQTT client disconnected!`);
    });
}
```



## Initialize the Bridge 

Now we just need to initialize the bridge, pass in our credentials, and call `connect()`. Open up `app.js`, and add the following:
```javascript
const mqttAqBridge = require('./services/MqttAqBridge.js');
mqttAqBridge.init(
	process.env.MQTT_TOPIC,
	process.env.RABBIT_HOST,
	process.env.RABBIT_USER,
	process.env.RABBIT_PASSWORD,
	process.env.RABBIT_PORT,
	process.env.MQTT_PROTOCOL,
	process.env.MQTT_VERSION,
);
mqttAqBridge.connect();
```



## Test Bridge 

Let's start up the app and test it out. I use a command-line tool called mosquitto_pub to easily publish messages to MQTT.
```bash
$ mosquitto_pub -t demo/one -h rabbitmq.toddrsharp.com -u $RABBIT_USER -P $RABBIT_PASSWORD -p 1883 -m '{"message": 1}'
$ mosquitto_pub -t demo/one -h rabbitmq.toddrsharp.com -u $RABBIT_USER -P $RABBIT_PASSWORD -p 1883 -m '{"message": 2}'
```



In theory, those MQTT messages should now be available on our AQ queue. If you remember in the last post, we created an endpoint to dequeue from our AQ topic. Let's make a call to the `/dequeueMany` endpoint and see if the messages are there:
```bash
$ curl -s localhost:3000/dequeueMany | jq
[
  {
    "message": 1
  },
  {
    "message": 2
  }
]
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b7f4b7e9-e726-4696-9b61-d625b452d817/upload_364a41b15f6c8f9d9429bbc7696bfff2.gif)

Fantastic!! Our bridge works!

## Summary 

What can I say? We created a bridge between MQTT and AQ. It didn't take a lot of code. It opened up tons of possibilities for messaging in our applications. But wait, there's more! We'll look at a different kind of bridge in the next post.

Image by [E. Dichtl](https://pixabay.com/users/fotofan1-320502/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=441853) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=441853)

<div>

\

</div>
