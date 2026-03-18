---
title: "Live Stream Viewer Analytics with Amazon IVS"
slug: "live-stream-viewer-analytics-with-amazon-ivs-41ih"
author: "Todd Sharp"
date: 2023-02-24T14:47:21Z
summary: "In my last post, we looked at monitoring Amazon Interactive Video Service (Amazon IVS) live stream..."
tags: ["productivity", "discuss"]
canonical_url: "https://dev.to/aws/live-stream-viewer-analytics-with-amazon-ivs-41ih"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-n01soz6dlbbo8zov7p0o.jpeg"
---

In my last post, we looked at [monitoring Amazon Interactive Video Service (Amazon IVS) live stream health](https://dev.to/aws/monitoring-amazon-ivs-live-stream-health-4bpb) metrics via the Amazon CloudWatch SDK. Health monitoring is a super important topic that is crucial to keeping your live streaming applications performant. Another crucial element is viewer analytics. In this post, we'll look at a few ways to provide insight into stream viewers.

Much of this post will look similar to my last post. That's because viewer data is also stored in CloudWatch and can be retrieved via the SDK. There is one additional method, as we'll see <a href="#getStream">below</a>, to get a count of the current viewers of a live stream which is a handy way to get a count that can be displayed on your front end. 

> **Note:** While this post focuses on live stream channel viewers, you can also retrieve metrics about your Amazon IVS chat rooms like `ConcurrentChatConnections` and messages `Delivered`. We won't cover that in this post, but you can check out the [docs](https://docs.aws.amazon.com/ivs/latest/userguide/cloudwatch.html#metrics-ivs-chat) to learn more.

## Retrieving Concurrent Views via the CloudWatch Console

If you're just looking for a glance at viewer data without retrieving the raw data, you can view your `ConcurrentViews` via the CloudWatch console. First, select **All metrics**, then choose **IVS**.

![CloudWatch console](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4ff1cxep5z6iuul8fnfh.png)

Next, select **By channel**.

![CloudWatch dimensions](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-53mazb4nditb7w5rncfp.png)

Then select the checkbox in the row that contains `ConcurrentViews` for any of your Amazon IVS channels.

![CloudWatch chart](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nwd1ag5x53v8fr771z9a.png)

Another way to find concurrent views for a stream session is via the Amazon IVS console. Select your channel, then choose a **Stream id** from the channel details page.

![Stream sessions](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-w9nrwyglo54y5z0f6ukf.png)

The details for a stream session will contain several charts, one of which contains the **Concurrent views** for the session.

![Concurrent view chart](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ghhm7vdwkrcbwvxwnew0.png)

## Retrieving Concurrent Views via the CloudWatch SDK

To integrate this data into your own application, you can retrieve the data via the CloudWatch SDK. Similarly to health metrics, you'll need a the channel's `ARN`, a `StartTime`, and an `EndTime` to retrieve `ConcurrentViews`. 

Instead of randomly choosing the start and end times, it probably makes sense to dynamically obtain these times by choosing the start and end times from a live stream session. You can retrieve a list of stream sessions via the Amazon IVS SDK (as we saw in the [previous post](https://dev.to/aws/monitoring-amazon-ivs-live-stream-health-4bpb#sessions)).

> **Reminder:** You'll always need an `EndTime`, even for streams that are currently live. For live streams, you can always use the current time as the `EndTime` when using the SDK to retrieve metrics.

To retrieve this data via the AWS SDK for JavaScript (v3), you will need to install the `@aws-sdk/client-cloudwatch` package and create an instance of the client (`new CloudWatchClient()`). After the client instance is created, set a few variables for the required inputs.

```js
const startTime = new Date('2023-02-10T14:00:00.000Z');
const endTime = new Date('2023-02-10T14:30:00.000Z');
const arn = process.env.DEMO_CHANNEL_ARN;
```

Next, create an input object. The input object will contain the `StartTime`, `EndTime`, and an array of `MetricDataQueries`. The queries array will contain a single object that specifies the `MetricName` (`ConcurrentViews`), the `Namespace` (`AWS/IVS`), and the `Dimensions` to filter by (channel name, in this case).

```js
const getMetricDataInput = {
  StartTime: startTime,
  EndTime: endTime,
  MetricDataQueries: [{
    Id: "concurrentviews",
    MetricStat: {
      Metric: {
        MetricName: "ConcurrentViews",
        Namespace: "AWS/IVS",
        Dimensions: [{ Name: "Channel", Value: arn.split("/")[1] }]
      },
      Period: 5,
      Stat: "Average",
    }
  }],
  MaxDatapoints: 100
};
```

Now send the request and log the result.

```js
const getMetricDataRequest = new GetMetricDataCommand(getMetricDataInput);
let metrics = await cloudWatchClient.send(getMetricDataRequest);
console.log(metrics);
```

Which produces output that looks like the following (extraneous SDK metadata removed for brevity):

```json
{
  "MetricDataResults": [
    {
      "Id": "concurrentviews",
      "Label": "ConcurrentViews",
      "Timestamps": [
        "2023-02-10T14:29:00.000Z",
        "2023-02-10T14:28:00.000Z",
        "2023-02-10T14:27:00.000Z",
        "2023-02-10T14:26:00.000Z",
        "2023-02-10T14:22:00.000Z"
      ],
      "Values": [
        3,
        3,
        3,
        3,
        10
      ],
      "StatusCode": "PartialData"
    }
  ]
}
```

You can filter, sort, and output this data to produce a format useful for generating charts.

```js
const viewMetrics = metrics
  .MetricDataResults
  .find((metric) => metric.Id === 'concurrentviews');

const viewValues = viewMetrics.Values.reverse();

const viewData = [];

viewMetrics
  .Timestamps
  .reverse()
  .forEach((t, i) => {
    viewData.push({
      timestamp: t,
      concurrentviews: viewValues[i],
    })
  });

console.log(JSON.stringify(viewData));
```

Which produces an array of objects.

```json
[
  {
    "timestamp": "2023-02-10T14:22:00.000Z",
    "concurrentviews": "10.00"
  },
  {
    "timestamp": "2023-02-10T14:26:00.000Z",
    "concurrentviews": "3.00"
  },
  ...
]
```

You can use this data with our favorite charting library (or a generic online chart generator like I did).

![Concurrent View Chart](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-f28wktxyqlb20dcn7tip.png)

## Generating Chart Images with the CloudWatch SDK

In the last post, we looked at generating the image directly via the CloudWatch SDK. This approach also applies to your view metrics.

```js
const startTime = new Date('2023-02-10T14:00:00.000Z');
const endTime = new Date('2023-02-10T14:25:00.000Z');
const arn = process.env.DEMO_CHANNEL_ARN;

const cloudWatchClient = new CloudWatchClient();
const getMetricWidgetImageInput = {
  MetricWidget: JSON.stringify({
    metrics: [
      [
        "AWS/IVS",
        "ConcurrentViews",
        "Channel",
        arn.split("/")[1]
      ]
    ],
    start: startTime,
    end: endTime,
    period: 5,
    stat: "Average"
  })
};
const getMetricWidgetImageRequest = new GetMetricWidgetImageCommand(getMetricWidgetImageInput);
const metricImage = await cloudWatchClient.send(getMetricWidgetImageRequest);
```
Which returns an object with the key `MetricWidgetImage` that contains an array buffer (`Uint8Array`) containing the chart image.

```json
{
  "MetricWidgetImage": {
    "0": 137,
    "1": 80,
    "2": 78,
    ...
  }
}
```

To convert this array buffer to a base64 string:

```js
const buffer = Buffer.from(metricImage.MetricWidgetImage);
console.log(buffer.toString('base64'));

```

Which gives us:

```js
iVBORw0KGgoAAAANSUhEUgAAAlgAAAGQCAIAAAD9V4nPAAAACXBIWXMA...
```

That can be converted to an image that looks like so:

![CloudWatch generated chart](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-i2ovlydipjvra8mz4q9w.png)


<h2 id="getStream">Retrieving Current Live View Sessions for a Channel</h2>

As mentioned above, you can easily get a count of the current view sessions for the active live stream on a channel via the Amazon IVS client module in the AWS SDK. For this, use the `GetStream` method. 

```js
import { GetStreamCommand, IvsClient } from "@aws-sdk/client-ivs";

const client = new IvsClient();

const getStreamCommandInput = {
  channelArn: process.env.DEMO_CHANNEL_ARN,
};
const getStreamRequest = new GetStreamCommand(getStreamCommandInput);
const getStreamResponse = await client.send(getStreamRequest);
console.log(getStreamResponse);
```

Which produces output like the following.

```json
{
  "stream": {
    "channelArn": "arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]",
    "health": "HEALTHY",
    "playbackUrl": "https://[redacted].us-east-1.playback.live-video.net/api/video/v1/us-east-1.[redacted].channel.x4aGUUxIp5Vw.m3u8",
    "startTime": "2023-02-10T15:46:36.000Z",
    "state": "LIVE",
    "streamId": "st-[redacted]",
    "viewerCount": 5
  }
}
```

Note the property `viewerCount` which is a live count of view sessions for the current live stream.

## Summary

In this post, we learned how to retrieve view data for our Amazon IVS live streams via the CloudWatch and Amazon IVS SDKs. To learn more, check out the [documentation](https://docs.aws.amazon.com/ivs/latest/userguide/cloudwatch.html).

