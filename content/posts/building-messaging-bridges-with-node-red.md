---
title: "Building Messaging Bridges with Node-RED"
slug: "building-messaging-bridges-with-node-red"
author: "Todd Sharp"
date: 2021-12-17
summary: "In this post, we'll take one more look at messaging bridges. This time, we'll build them with Node-RED."
tags: ["Messaging", "Node"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/bridge-g0e5a7e1c4_1280.jpeg"
---

Over the last few posts, we've looked in detail at Oracle Advanced Queuing. Most recently we looked at "bridges" - or applications that helped us broker messages between normally incompatible protocols like MQTT, AQ, and Oracle Streaming Service (OSS). We built a few bridges, and they worked out great! In this post, I thought I'd present an alternate, possibly more "fun" look at bridges. How might we make it more fun, you say? Well, one way might be to use a solution that doesn't require us to write much code at all. And to do that, we'll use [Node-RED](https://nodered.org)! We've talked about Node-RED in the past on this blog (how about [installing it in an "always free" VM](https://recursive.codes/blog/post/112)?) and since it is often used in conjunction with IoT solutions, I thought it would be a perfect tool for building some bridges. 

Before we go on, I should mention that the blog post I linked to in the paragraph above is slightly outdated. I haven't had the chance to update it, but I recently gave a presentation at Node-RED Con Japan about installing Node-RED on an "always free" Arm instance. Here's that session, if you need to get up to speed!

## Building an MQTT to AQ Bridge 

First, let's look at recreating the MQTT-AQ bridge from this blog post. In that post, we used the following architecture drawing to explain at a high-level the concept of what we were trying to accomplish. In a nutshell, we were connecting the unrelated protocols and passing the messages. A message produced in MQTT is consumed by AQ.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1516bc01-0080-49ed-83be-b62f015fc738/upload_00d433ded118f16b43bb6889c3261b49.png)

When we look at the "flow" (below) in Node-RED, you can see that it looks similar to the "bridge" portion of the architecture diagram (above).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/23550a5b-8437-4f45-b1b2-eee78b94387e/upload_18825c59fe03322aa40b60e278eafcbd.png)

So how do you build this? Well, since there's no "native" module for AQ in Node-RED yet, we'll have to use the [`node-red-contrib-oracledb-mod`] module ([blogged here](https://recursive.codes/blog/post/1806)) and enqueue the message directly via PL/SQL. Scary? Nah, no big deal! Make sure you've got the module installed and configured before we proceed. Let's build this flow! Start by dragging an MQTT node in to the flow, double-click it, and enter the topic to listen to.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d75490fc-ac7a-4237-ae9e-cd3505dbdbf3/upload_ac32b4167d92b40821fb50e44ce0e535.gif)

Now drag in a function node. The function node will let us generate the query and inject the incoming message payload into the query. We'll set the query into the `query` key of the message object since that's what the Oracle node will be looking for. Don't worry if you can't read the query in the gif below, I'll share it in just a second.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/998f617f-b2e8-4a62-abf7-5b3420f9021b/upload_b9ee5fa3cdc1347308dd41a4de4a75f8.gif)

In the function node, we'll use the following to construct the proper query. Of course, you'll need to enter your own queue name!
```javascript
const qry = `
DECLARE
    l_enqueue_options     dbms_aq.enqueue_options_t;
    l_message_properties  dbms_aq.message_properties_t;
    l_message_handle      raw(16);
    l_event_msg           sys.aq$_jms_text_message;
BEGIN
    l_event_msg := sys.aq$_jms_text_message.construct();
    l_event_msg.set_text('${msg.payload}');
    dbms_aq.enqueue(queue_name => 'AQDEMOUSER.MQTT_BRIDGE_QUEUE',
                   enqueue_options => l_enqueue_options,
                   message_properties => l_message_properties,
                   payload => l_event_msg,
                   msgid => l_message_handle);

    COMMIT;
END;
`;
msg.query = qry;
return msg;
```



Finally, add an Oracle node and set it to "ignore the query results" (since the query doesn't generate any output). Since we generated the query in the previous function node, we don't need to do anything else here!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4819858d-65f0-417d-a1a8-d94491930865/upload_7d4a2888381998459c0d3eef8f6a6845.gif)

Click deploy.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3d4b971c-6d78-4f26-b4f2-1cceb88e5228/upload_239abc0965f1be9495adb92a175838f8.png)

Once the flow is running, we can connect up in our terminal window to the AQ queue and then publish a message to the AQ topic. If we configured it correctly, the AQ queue should receive the message that was published to MQTT.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/12cd9499-b240-4397-9e49-51d597b98678/upload_f6fe077651d3a24e66f43efff9fcd198.gif)

## Building an MQTT to OSS Bridge 

The concept here is identical to the MQTT-AQ bridge. Again, we'll refer to the architecture drawing from earlier in this series. This time we're bridging MQTT with Oracle Streaming Service (OSS). 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/58498c6c-cbde-404a-a070-912cd28e90cb/upload_5a530261030450799297f558e03ecc78.png)

Since OSS is compatible with Kafka, we can use the `node-red-contrib-rdkafka-secure` [module](https://flows.nodered.org/node/node-red-contrib-rdkafka-secure) to build this bridge. Take note - if you're on MacOS, you'll want to pay attention to the install instructions for that module that refer you to the `node-rdkafka` instructions so that everything gets installed properly.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7382651b-0cdb-4a55-b261-2658db633d54/upload_6d8e0deb26f92d9306b431a0aa31b973.png)

Again, the architecture looks almost exactly like the flow.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/662fdcbb-c364-47a1-bafc-dfde911a754f/upload_6a1ca3aa20ad393d3a77c445cc657edd.png)

Like the last flow, this one begins by configuring an MQTT node for the topic we want to listen to.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d75490fc-ac7a-4237-ae9e-cd3505dbdbf3/upload_ac32b4167d92b40821fb50e44ce0e535.gif)

Next, we drag a secure Kafka out node (configured to point at OSS) to the flow, and connect the two nodes.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/73ca831a-4c90-4cc4-b4ea-2d47e5b1351e/upload_aa1a4fd35ee3a0d74a797c8dbe10668e.gif)

We'll also need to configure our Kafka Broker. Refer to the last post if you do not remember how to get this information.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f09b237c-15c6-4f03-a628-43ca3f323fb7/upload_41558d8b564acd9e45e61b36176f3742.png)

And that's the MQTT-OSS bridge in Node-RED. Deploy it, then test by producing a message to the MQTT topic and observing the OSS stream. Since OSS is Kafka compatible, we can use the `kafka-console-consumer.sh` script from Kafka to consume our OSS stream.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/490f11e9-2404-4308-8056-2c090e95e6b4/upload_fa1cc9e3e86df6cc6877585710fea9d1.gif)

## Summary 

We used Node-RED to build our MQTT-AQ and MQTT-OSS bridges. It's a simple, but practical solution to a complex problem. 

That wraps up this short series on messaging and Oracle AQ. I hope you've enjoyed it and learned something along the way. As always, I welcome your feedback on how I can improve future content and thank you for your support.

Image by [Mikes-Photography](https://pixabay.com/users/mikes-photography-1860391/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=1866135) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=1866135)
