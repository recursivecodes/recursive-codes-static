---
title: "Auto Recording Amazon IVS Live Streams to S3"
slug: "auto-recording-amazon-ivs-live-streams-to-s3-m64"
author: "Todd Sharp"
date: 2023-01-13T12:48:02Z
summary: "Lately on this blog we've been spending a lot of time focusing on features that help us build user..."
tags: ["aws", "amazonivs", "s3", "livestreaming"]
canonical_url: "https://dev.to/aws/auto-recording-amazon-ivs-live-streams-to-s3-m64"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-emthtdq4vxei6tiy0fli.jpeg"
---

Lately on this blog we've been spending a lot of time focusing on features that help us build user generated content (UGC) platforms with Amazon Interactive Video Service (Amazon IVS). Features like chat moderation (both [automated](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p) and [manual](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646)), and giving creators a way to [notify channel subscribers when their live stream is online](https://dev.to/aws/notifying-subscribers-when-an-amazon-ivs-stream-is-online-f1c). These types of features go a long way in differentiating between a simple streaming site and an engaging platform that promotes and encourages interaction between creators and viewers. But there's another feature that we can add to our UGC application to keep viewers entertained and engaged, and that's giving them the ability to replay past live streams. In this post, we'll look at how to auto-record live streams to an Amazon Simple Storage Service (Amazon S3) bucket and play them back at a later time.

## Recording Configurations

The Amazon IVS docs provide a full overview on [auto-record to Amazon S3](https://docs.aws.amazon.com/ivs/latest/userguide/record-to-s3.html). In this post, we'll focus on creating a recording configuration, associating it with an Amazon IVS channel, and using the Amazon CloudWatch SDK to retrieve recording events in order to obtain the master playlist for playback. To get started, we'll need to create a recording configuration.

### Using the Amazon IVS Console To Create a Recording Configuration

To get started, select **Recording configuration** from the left sidebar in the Amazon IVS Console.

![Left sidebar menu](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-j6oelousj85fk399yyy8.png)

On the **Recording configuration** list page, select **Create recording configuration**.

![Recording configuration list page](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-kvfomz16htzdatpsicfr.png)

Enter a **Recording configuration name**, and choose whether or not you'd like thumbnails generated from your recording. If you would like thumbnails generated (which is a very useful feature to provide viewers a glimpse of the recorded content), enter the thumbnail generation frequency. If you'd like to merge interrupted streams (IE: continue recordings when a broadcaster goes offline for a short period of time due to network or other glitches), enable **Reconnect window** and specify the maximum gap between streams to consider them a single recording.

![Recording configuration details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-h7cmbtsfn698jpi3pus7.png)

Next, enter a name for the S3 bucket in which the recording data will be stored (or choose an existing bucket) and then click **Create recording configuration**.

![Recording configuration details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-yagjr7j221tvb16pjkbb.png)

You can also create a new recording configuration directly from the **Edit channel** page, or when creating a brand new channel by clicking **Create recording configuration**.

![Create recording configuration button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rq4co2qcu9n8yxjdw8rl.png)

### Using the AWS SDK To Create a Recording Configuration

As always, the AWS SDK (Node.js [docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivs/classes/createrecordingconfigurationcommand.html)) can be used to create a recording configuration. Since the SDK is likely the preferred way to create such resources in production applications, let's take a quick look at how that is done.

```js
import { IvsClient, CreateRecordingConfigurationCommand, RecordingMode } from "@aws-sdk/client-ivs";

const ivsClient = new IvsClient();
const createRecordingConfigInput = {
  name: 'ivs-demo-recording-config-sdk',
  thumbnailConfiguration: {
    recordingMode: RecordingMode.Interval,
    targetIntervalSeconds: 60,
  },
  recordingReconnectWindowSeconds: 30,
  destinationConfiguration: {
    s3: {
      bucketName: 'ivs-demo-channel-stream-archive'
    }
  }
};
const createRecordingConfigRequest = new CreateRecordingConfigurationCommand(createRecordingConfigInput);
const createRecordingConfigResponse = await ivsClient.send(createRecordingConfigRequest);
console.log(createRecordingConfigResponse);
```
The SDK code above will produce a result similar to the following.

```json
{
  "$metadata": {
    "httpStatusCode": 200,
    "requestId": "[redacted]",
    "cfId": "[redacted]",
    "attempts": 1,
    "totalRetryDelay": 0
  },
  "recordingConfiguration": {
    "arn": "arn:aws:ivs:us-east-1:[redacted]:recording-configuration/[redacted]",
    "destinationConfiguration": {
      "s3": {
          bucketName: 'ivs-demo-channel-stream-archive'
      }
    },
    "name": "ivs-demo-recording-config-sdk",
    "recordingReconnectWindowSeconds": 30,
    "state": "CREATING",
    "tags": {},
    "thumbnailConfiguration": {
      "recordingMode": "INTERVAL",
      "targetIntervalSeconds": 60
    }
  }
}
```

> **Note:** The Amazon S3 bucket used in the SDK example above must already exist before the recording configuration is created. If necessary, use the AWS SDK for Amazon S3 to [create the bucket](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-s3/classes/createbucketcommand.html) first. Also note - Amazon S3 buckets can be associated with multiple recording configurations, and one configuration might be sufficient to associate with every channel that you create. There is no need to have a unique recording configuration for every single Amazon IVS channel!

### Associating a Recording Configuration With an Existing Amazon IVS Channel 

Now that we have created the recording configuration, we'll have to associate it with a channel. Select a channel from the Amazon IVS channel list page, click **Edit**, enable **Auto-record to S3**, and select the applicable recording configuration.

![Associate recording configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ig9rrh1zg25uxhbjpa6r.png)

To associate the recording configuration with an existing channel via the AWS SDK for JavaScript, use the `UpdateChannelCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivs/classes/updatechannelcommand.html)) and pass the channel's `arn` along with the newly created `recordingConfigurationArn`.

```js
import { IvsClient, UpdateChannelCommand } from "@aws-sdk/client-ivs";

const ivsClient = new IvsClient();
const updateChannelInput = {
  arn: 'arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]',
  recordingConfigurationArn: 'arn:aws:ivs:us-east-1:[redacted]:recording-configuration/[redacted]',
};
const updateChannelRequest = new UpdateChannelCommand(updateChannelInput);
const updateChannelResponse = await ivsClient.send(updateChannelRequest);
console.log(updateChannelResponse);
```

Once your recording configuration is associated with a channel, all new streams on that channel will be recorded to S3 at a path that follows this format:

```
/ivs/v1/<aws_account_id>/<channel_id>/<year>/<month>/<day>/<hours>/<minutes>/<recording_id>
```

When a recording starts, video segments and metadata files are written to the Amazon S3 bucket that is configured for the channel. Within the unique path for each recording, there will be an `/events` folder which contains the metadata files corresponding to the recording event. JSON metadata files are generated when recording starts, ends successfully, or ends with failures:

* events/recording-started.json
* events/recording-ended.json
* events/recording-failed.json

There will also be a `/media` folder that contains all of the relevant media contents within two subfolders. The `/hls` folder contains all media and manifest files generated during the live session and is playable with the Amazon IVS player. The `/thumbnails` folder will contain any thumbnail images generated during the live session. 

## Accessing Recorded Streams for Playback

For security purposes, all auto-recorded live streams are stored in a **private** bucket. Because of this, these objects can not be played back using a direct S3 URL. To expose these objects for playback, we'll need to create an Amazon CloudFront distribution. Head over the the Amazon CloudFront console, and click **Create distribution**.

![CloudFront distribution lists](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tv183dizb5leyfqdbmhd.png)

In the **Origin domain**, select the S3 bucket associated with the recording configuration. Leave the **Origin path** blank, and accept the default **Name**. Choose **Origin access control settings (recommended)**.

![Create distribution](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-we7pzttmhh1g6v10a3pl.png)

Click **Create control setting**, enter a **Name** and **Description**, then click **Create**.

![Origin access control settings](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-78cmx1b18kttswelae73.png)

Per the warning message, we'll need to modify the bucket policy after the distribution is created.

![Distribution confirmation](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ebyhqc5uybiwc1k1fjen.png)

Modify any additional settings for your distribution as necessary.

Once the distribution is created, copy the policy by clicking **Copy policy**.

![Distribution confirmation](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ykd9zo5isg03cfcrhv3y.png)

Click **Go to S3 bucket permissions to update policy** and paste the new policy.

![Bucket policy](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nxm5h0nsuo5hfjvd2yrh.png)

At this point, all of the objects stored in the S3 bucket will be available via the CloudFront distribution. To access them, we'll just use the base URL from our distribution in place of the standard S3 base URL.

![Distribution list](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4l7rmo94qjri05q6s3uh.png)

## Listening for Recording Events

We've previously looked at using EventBridge [rules](https://dev.to/aws/notifying-subscribers-when-an-amazon-ivs-stream-is-online-f1c) to notify users when an Amazon IVS stream goes live. We can also create rules to listen for Recording Start/Stop events. Let's create a rule to listen for recording end, and log those events to CloudWatch so that we can easily retrieve this information later on when we want to playback a stream.

![EventBridge rule name](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-qj1jo5m24l6veq4ramvk.png)

Select **AWS Events or EventBridge partner events**.

![Event source](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ilbo37rqgzhd2drhecbh.png)

Under **Creation method**, select **Custom pattern (JSON editor)** and paste the following pattern. Note that you'll have to substitute `YOUR_CHANNEL_NAME` with your existing channel name. If you don't have an existing Amazon IVS channel created, refer to [this blog post](https://dev.to/aws/get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg) to get started.

```json
{
  "source": ["aws.ivs"],
  "detail-type": ["IVS Recording State Change"],
  "detail": {
    "channel_name": ["YOUR_CHANNEL_NAME"],
    "recording_status": ["Recording End"]
  }
}
```

> **Note:** Your event bridge rule can listen for events for all channels, or utilize the channel’s ARN instead of the channel name. Refer to the [docs](https://docs.aws.amazon.com/ivs/latest/userguide/eventbridge.html) for more information on creating your EventBridge rules.

Which should look like this:

![Custom JSON pattern](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-k093cg1mt9ad39mf6eol.png)

On the **Target** page, select a **Target type** of **AWS service**, select **CloudWatch log group**, and enter a name for the log group.

![EventBridge CloudWatch target](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zlb44fvxc397kyu1m2zp.png)

Enter desired tags, confirm selections, and create the rule.

## Viewing CloudWatch Events

Once you have applied the configuration and configured the event bridge rule, all events will be logged to CloudWatch. After you have completed a broadcast, head over to CloudWatch and look for the log group that was created above. Your channel’s recording events will be visible once a live stream is completed, but keep in mind that there may be a slight delay between the end of a broadcast and the publishing of the recording events.

```json
{
  "version": "0",
  "id": "3c86196e-624f-9ccd-b89b-434414bd93b5",
  "detail-type": "IVS Recording State Change",
  "source": "aws.ivs",
  "account": "[redacted]",
  "time": "2022-12-12T20:07:16Z",
  "region": "us-east-1",
  "resources": [
      "arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]"
  ],
  "detail": {
    "recording_status": "Recording End",
    "recording_status_reason": "",
    "recording_s3_bucket_name": "ivs-demo-channel-stream-archive",
    "recording_s3_key_prefix": "ivs/v1/[redacted]/x4aGUUxIp5Vw/2022/12/12/19/59/[redacted]",
    "recording_duration_ms": 87000,
    "channel_name": "demo-channel",
    "stream_id": "st-[redacted]",
    "recording_session_id": "[redacted]",
    "recording_session_stream_ids": [
        "st-[redacted]"
    ]
  }
}
```

## Retrieving CloudWatch Logged Events

We can use the AWS SDK for JavaScript v3 to retrieve these events based on a given start/end time.

```js
import { CloudWatchLogsClient, FilterLogEventsCommand } from "@aws-sdk/client-cloudwatch-logs";
import util from 'node:util';

const cloudwatchClient = new CloudWatchLogsClient();

const filterLogEventsInput = {
  logGroupName: '/aws/events/ivs-stream-recording-end-log-group',
  startTime: 1670875080000,
  endTime: 1670875200000,
};
const filterLogEventsRequest = new FilterLogEventsCommand(filterLogEventsInput);
const filterLogEventsResponse = await cloudwatchClient.send(filterLogEventsRequest);
const events = filterLogEventsResponse.events.map(e => JSON.parse(e.message));
```

Which gives an array of events matching the criteria:

```json
[
  {
    "version": "0",
    "id": "8d2da908-bf44-f491-8b6e-784bdba37a1d",
    "detail-type": "IVS Recording State Change",
    "source": "aws.ivs",
    "account": "[redacted]",
    "time": "2022-12-12T19:58:27Z",
    "region": "us-east-1",
    "resources": [
      "arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]"
    ],
    "detail": {
      "recording_status": "Recording End",
      "recording_status_reason": "",
      "recording_s3_bucket_name": "ivs-demo-channel-stream-archive",
      "recording_s3_key_prefix": "ivs/v1/[redacted]/[redacted]/2022/12/12/19/52/[redacted]",
      "recording_duration_ms": 0,
      "channel_name": "demo-channel",
      "stream_id": "st-[redacted]",
      "recording_session_id": "[redacted]",
      "recording_session_stream_ids": [
        "st-[redacted]"
      ]
    }
  },
  {
    "version": "0",
    "id": "281586b5-f680-2ca6-f60a-cf5b327b15d3",
    "detail-type": "IVS Recording State Change",
    "source": "aws.ivs",
    "account": "[redacted]",
    "time": "2022-12-12T19:58:43Z",
    "region": "us-east-1",
    "resources": [
      "arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]"
    ],
    "detail": {
      "recording_status": "Recording End",
      "recording_status_reason": "",
      "recording_s3_bucket_name": "ivs-demo-channel-stream-archive",
      "recording_s3_key_prefix": "ivs/v1/[redacted]/[redacted]/2022/12/12/19/52/[redacted]",
      "recording_duration_ms": 10000,
      "channel_name": "demo-channel",
      "stream_id": "st-[redacted]",
      "recording_session_id": "[redacted]",
      "recording_session_stream_ids": [
        "st-[redacted]"
      ]
    }
  }
]
```

We can loop over the parsed `events` and retrieve the master playlist for each recording, using our CloudWatch base URL:

```js
events.forEach(async event => {
  const playlistUrl = `https://[redacted].cloudfront.net/${event.detail.recording_s3_key_prefix}/media/hls/master.m3u8`;
  console.log(playlistUrl);
});
```

At this point, we can plug the URL into the IVS player to [playback the stream](https://dev.to/aws/creating-your-first-live-stream-playback-experience-with-amazon-ivs-56kl)!

## Summary

In this post, we learned how to create a recording configuration to auto-record Amazon IVS live streams to Amazon S3. We also learned how to expose the Amazon S3 bucket via a CloudFront distribution, and construct a URL for on-demand playback of the recorded streams. In our next post, we're going to learn about chat logging, which is a new feature that allows you to log all chat messages from an Amazon IVS chat room. In a future post, we'll combine auto-recorded streams with chat logs to complete the full on-demand playback experience. 