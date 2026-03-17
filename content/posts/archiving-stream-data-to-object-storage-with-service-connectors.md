---
title: "Archiving Stream Data To Object Storage With Service Connectors"
slug: "archiving-stream-data-to-object-storage-with-service-connectors"
author: "Todd Sharp"
date: 2021-04-16
summary: "In this post, we'll look at using service connectors to archive data from Oracle Streaming Service to Object Storage. We'll also look at adding an intermediate task that can be used to filter the data to be archived."
tags: ["Cloud"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/banner_bunker_622515_1280.jpeg"
---

Last year, we launched the Service Connector Hub for Oracle Cloud Infrastructure. If I'm being honest, I really didn't pay much attention when the service originally launched because it didn't seem like something developers would use very often. However, the service got much more interesting this week with a [few enhancements that were just announced](https://blogs.oracle.com/cloud-infrastructure/announcing-stream-and-log-processing-in-service-connector-hub). 

Before we get into the cool stuff, let's first define what the service is. Essentially it's a way to take data, in a serverless manner, from a **source** to a **destination** with an optional **task** in between. Simple in definition, but infinitely powerful and necessary. The following illustration describes which services can act as sources, destinations, and tasks (as of the date this blog post was published).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589504.png)

So what is possible here? In addition to moving large volumes of data from OCI to third-party services like Splunk and Datadog, you can now do things like archive stream data for compliance or archival purposes by creating a service connector to move Streaming data to Object Storage. You can even reformat or modify the data by adding a task in between the operations. Since you can use a stream as both a source and a target service, you could potentially use a service connector to filter or consolidate streams. 

This opens up many possibilities for moving data around within Oracle Cloud, but it also enables the movement of data between cloud providers (or your datacenter).  I've been playing with the service a bit, and I thought it would be a good idea to show you a simple use-case to illustrate what I mean. Here's a quick table of contents if you'd like to skip around.

- [Archiving Stream Data to Object Storage](#archiving-stream-data-to-object-storage)
  - [Using an Existing Stream](#existing-stream)
  - [Create Object Storage Bucket](#create-object-storage-bucket)
  - [Create Service Connector](#create-service-connector)
  - [Publish Messages](#publish-messages)
  - [Confirm Archive Operation](#confirm-archive-operation)
- [Add a Functions Task to Filter Stream Data](#add-a-functions-task-to-filter-stream-data)
  - [Create App](#create-app)
  - [Create Function](#create-function)
  - [Edit Function](#edit-function)
  - [Modify Service Connector to Add Functions Task](#modify-service-connector-to-add-functions-task)
- [Summary](#summary)

## Archiving Stream Data to Object Storage

In this example, we're going to use Service Connector Hub to read an existing stream of data and archive that data to Object Storage. Then we'll enhance the example by adding a task in between the source read and target write operations. Let's dig in and see how to configure things.

### Using an Existing Stream 

There are tons of resources and [documentation](https://docs.oracle.com/en-us/iaas/Content/Streaming/Concepts/streamingoverview.htm#Streaming_Service_Overview) online to get started with Oracle Streaming Service. I've [blogged about the service many times](https://recursive.codes/search?searchString=streaming), so I won't cover how to create a stream in this post. I'll assume that you've already got a stream created and you'd like to archive data from that stream to Object Storage. For this demo, I'll be using a stream named `demo-stream` that resides in a stream pool called `oss-demo-stream-pool` as shown below.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589516.png)

### Create Object Storage Bucket

I could use an existing Object Storage bucket to archive the stream data, but for this demo, I'll create a new bucket called `streaming-archive-demo-0` that will contain all of the archived data. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589528.png)

### Create Service Connector

For simple archiving operations, we don't need to write a single line of code. Instead, we just create a service connector and point it at the source (stream) and destination (bucket). Navigate to the Service Connector Hub via the burger menu (or by searching for it).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589532.png)

Click on 'Create Service Connector'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589539.png)

Name the connector, provide a description, and choose the compartment to store the connector.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589546.png)

Choose 'Streaming' as the source, and 'Object Storage' as the target. Chose the compartment where the stream pool resides, choose the stream pool, and the stream. You can choose to read from either the 'Latest' offset or 'Trim Horizon' (the oldest non-committed offset).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589552.png)

Choose the compartment where your bucket resides and the bucket. Click on 'Show Additional Options' and enter a batch size and batch time. 

{{< callout >}}
**Batch Options:** The service connector will only write to the target when either of the batch thresholds (size or time) is exceeded. The example below will write to the bucket when 100MB are queued in the stream or every 60 seconds.
{{< /callout >}}
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589557.png)

Click 'Create' and the service connector is ready to archive your streams.

### Publish Messages

To test this out, we can write some messages to our stream using the OCI CLI. When writing messages to a stream, we must pass the message as a JSON object with two keys: `key` and `value`. Both the key and the value must be Base64 encoded. I'll publish two separate messages, one with `key1` and another with `key2`. Both will contain a simple JSON message payload. Here's how I encoded the values.
```bash
$ echo -n "key1" | base64
a2V5MQ==
$ echo -n "key2" | base64
a2V5Mg==
$ echo -n '{"id":"0", "test": "message from CLI"}' | base64
eyJpZCI6IjAiLCAidGVzdCI6ICJtZXNzYWdlIGZyb20gQ0xJIn0=
```



I plugged these encoded values into my CLI commands and published both messages.
```bash
// key1
oci streaming stream message put \
  --stream-id ocid1.stream.oc1.phx… \
  --endpoint https://cell-1.streaming.us-phoenix-1.oci.oraclecloud.com \
  --messages "[{"key": "a2V5MQ==", "value": "eyJpZCI6IjAiLCAidGVzdCI6ICJtZXNzYWdlIGZyb20gQ0xJIn0="}]"

// key2
oci streaming stream message put \
  --stream-id ocid1.stream.oc1.phx… \
  --endpoint https://cell-1.streaming.us-phoenix-1.oci.oraclecloud.com \
  --messages "[{"key": "a2V5Mg==", "value": "eyJpZCI6IjAiLCAidGVzdCI6ICJtZXNzYWdlIGZyb20gQ0xJIn0="}]"
```



Now I simply wait the 60000 milliseconds (60 seconds) for the archive operation.

### Confirm Archive Operation

After the 60 second wait period, we can check that the stream data was written to our Object Storage bucket.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589562.png)

As shown above, the stream data was written to a compressed file in my bucket and labeled with the timestamp at which it was written. We can now download, extract, and view this file (I opened it in Excel).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589566.png)

As you can see, both of the messages that I published via the CLI were archived into the bucket. Without writing a single line of code or deploying any infrastructure we have a reliable archive of our stream data in OCI!

## Add a Functions Task to Filter Stream Data

Archiving stream data is easy and useful, but sometimes we may want to filter the data that is being archived into Object Storage based on some criteria. We also might want to create a new stream of data based on some subset of the original stream data. Using a functions **task**, we can do just that! To do this, we need to create an application, a function and deploy the function to the cloud. Let's do that.

### Create App

First, create an application that the function will belong to. You can do this via the OCI CLI or console, but I like to use the `Fn` CLI.
```bash
fn create app service-connector-demo-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1..."]'
```



### Create Function

Next, create a function with the CLI and navigate to the function directory. I'm using Node.JS for simplicity here, but any supported language would work.
```bash
fn init --runtime node fn-service-connector-demo
cd fn-service-connector-demo/
```



### Edit Function

We'll edit the function to filter the incoming stream data. 

{{< callout >}}
**Note: **The stream data will be passed to the function in an array of objects. Each object will have the same structure as the archive output above. You must return an array of objects from the function containing either a subset of the input data or the entire input data (if nothing needs to be filtered).
{{< /callout >}}
As mentioned above, the `key` and `value` of the message are Base64 encoded, so we'll use the [atob](https://www.npmjs.com/package/atob) module to decode it. Make sure to include the dependency in your `package.json` file:
```json
"dependencies": {
    "@fnproject/fdk": ">=0.0.20",
    "atob": "^2.1.2"
}
```



Finally, I implemented the function to filter the incoming array and only return the items whose `key` match `key2`.
```javascript
const fdk = require('@fnproject/fdk');
const atob = require('atob');

fdk.handle(function(input){
    return input.filter((msg) => {
        return atob(msg.key) === "key2"
    });
});
```



Then deploy the function to the application.
```bash
fn deploy --app service-connector-demo-app
```



### Modify Service Connector to Add Functions Task

Back in the Service Connector Hub, edit the service connector to add a task that will invoke the function that we just created.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589571.png)

Like earlier, we can adjust the batch size and time limit to meet our needs. In this example, the function task will be invoked when either 5120KB of data is queued or every 60 seconds.

Next, I published a batch of new messages for both `key1` and `key2` via the CLI. After waiting the requisite amount of time, I checked the Object Storage bucket and noticed a new archive.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589579.png)

I downloaded, uncompressed, and read this archive:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/86e47ba2-b242-436f-b2d8-26f29fc3fada/file_1618500589583.png)

And it worked! Only the messages with `key2` are archived in the Object Storage bucket

## Summary

In this post, we looked at using Service Connector Hub in OCI to move data from a **source** to a **destination** with an optional **task** in between. We looked at a specific example of archiving stream data that uses Oracle Streaming Service as a source to an Object Storage bucket as a destination and then modified that example to filter the stream data into a subset via an Oracle Functions task. As mentioned earlier, any combination of source, destination (with an optional task) can be used to move data in the Oracle Cloud. Stay tuned for more enhancements to Service Connector Hub in the near future!

For more information and examples, check out the [Service Connector Hub documentation](https://docs.oracle.com/en-us/iaas/Content/service-connector-hub/overview.htm).

Image by [Даниил Некрасов](https://pixabay.com/users/547877-547877/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=622515) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=622515) 

