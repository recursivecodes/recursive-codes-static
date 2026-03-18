---
title: "Archiving Web Chat Messages with Amazon IVS Chat Logging"
slug: "archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j"
author: "Todd Sharp"
date: 2023-01-20T13:37:06Z
summary: "In our last post, we looked at how to auto-record Amazon Interactive Video Service (Amazon IVS) live..."
tags: ["aws", "amazonivs", "chat", "logging"]
canonical_url: "https://dev.to/aws/archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ke0qnb2wo48m95cgxsw2.jpeg"
---

In our [last post](https://dev.to/aws/auto-recording-amazon-ivs-live-streams-to-s3-m64), we looked at how to auto-record Amazon Interactive Video Service (Amazon IVS) live streams to an Amazon Simple Storage Service (Amazon S3) bucket. That feature is a powerful tool for user generated content (UGC) platforms as it is the first step in providing on-demand viewing of previous live streams in an application. But a replay of a live stream is incomplete without the full context of the interactive chats that occur alongside of the stream. In this post, we'll take the next step to providing a full on-demand experience by learning how to log Amazon IVS chat messages. 

## Logging Configurations

Similar to how auto-recording to Amazon S3 required a recording configuration, chat logging also requires a configuration that defines the necessary details for a chat room. Keep in mind that you might also need additional [IAM permissions](https://go.aws/3GVHBQC) depending on your choice of logging destinations. 

### Using the Amazon IVS Console To Create a Logging Configuration

To create a logging configuration with the Amazon IVS Console, click on **Logging Configurations** in the left sidebar.

![logging configurations in sidebar menu](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-mkz0i8216nmv7j4u06fj.png)

On the **Logging configurations** list page, click **Create logging configuration**.

![Create logging configuration button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-agezwcvjr5yqgnujlvzw.png)

Amazon IVS chat logging offers several destinations for storage of the logged chat messages. We can choose from Amazon CloudWatch, an Amazon Kinesis Data Firehose, or Amazon S3 as a storage destination for your chat logs. I personally find CloudWatch to be the most convenient destination since I can easily retrieve the chat messages via the CloudWatch SDK, so let's use that for this demo. Refer to the [documentation](https://docs.aws.amazon.com/ivs/latest/userguide/chat-logging.html) if you'd like to utilize an Amazon Kinesis Data Firehose or Amazon S3 as a destination in your application.

> **Note**: There can be a slight delay between when a chat message is posted and when it appears at your logging destination. For Amazon S3, the delay can be up to 5 minutes, and for Amazon CloudWatch and Amazon Kinesis Data Firehose it can be up to 10 seconds.

To create the configuration for this demo, enter a **Logging configuration name** (#1), select CloudWatch as the **Destination** (#2), select **Create a new CloudWatch log group** (#3), and enter a **Log group name** (#4).

![Logging configuration details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-xlnhpqhh0wjrds94545f.png)

Enter any optional **Tags** and then click **Create logging configuration**.

![Create logging config button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wnw4g488l76g1ky0zqox.png)

### Using the AWS SDK To Create a Logging Configuration

Just like with recording configurations, we can take advantage of the AWS SDK to create our logging configurations. Since we're logging to CloudWatch in this post, we'll need to use the CloudWatch Logs SDK to [create a log group](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-cloudwatch-logs/classes/createloggroupcommand.html).

```js
import { CloudWatchLogsClient, CreateLogGroupCommand } from "@aws-sdk/client-cloudwatch-logs";

const cloudWatchLogsClient = new CloudWatchLogsClient();
const createLogGroupInput = {
  logGroupName: 'ivs-demo-chat-logging-group',
};
const createLogGroupRequest = new CreateLogGroupCommand(createLogGroupInput);
const createLogGroupResponse = await cloudWatchLogsClient.send(createLogGroupRequest);
console.log(createLogGroupResponse);
```

Now we can use the Amazon IVS chat client to create a logging configuration ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/createloggingconfigurationcommand.html)).

```js
import { IvschatClient, CreateLoggingConfigurationCommand } from "@aws-sdk/client-ivschat";

const ivsChatClient = new IvschatClient();
const createLoggingConfigInput = {
  name: 'ivs-demo-chat-logging-config-sdk',
  destinationConfiguration: {
    cloudWatchLogs: {
      logGroupName: 'ivs-demo-chat-logging-group'
    }
  }
};
const createLoggingConfigRequest = new CreateLoggingConfigurationCommand(createLoggingConfigInput);
const createLoggingConfigResponse = await ivsChatClient.send(createLoggingConfigRequest);
console.log(createLoggingConfigResponse);
```

This will produce output similar to the following:

```json
{
  "$metadata": {
    "httpStatusCode": 200,
    "requestId": "[redacted]",
    "cfId": "[redacted]",
    "attempts": 1,
    "totalRetryDelay": 0
  },
  "arn": "arn:aws:ivschat:us-east-1:[redacted]:logging-configuration/[redacted]",
  "createTime": "2023-01-09T14:48:35.358Z",
  "destinationConfiguration": {
    "cloudWatchLogs": {
      "logGroupName": "ivs-demo-chat-logging-group"
    }
  },
  "id": "[redacted]",
  "name": "ivs-demo-chat-logging-config-sdk",
  "state": "ACTIVE",
  "tags": {},
  "updateTime": "2023-01-09T14:48:35.485Z"
}
```

### Creating a Logging Configuration with the AWS CLI

We can also optionally create a logging configuration via the AWS CLI. Again, we'll have to create the CloudWatch log group, then pass the name of the new log group into the chat logging configuration.

```bash
$ aws logs \
  create-log-group \
  --log-group-name ivs-demo-logging-config-log-group

$ aws ivschat \
  create-logging-configuration \
  --name ivs-demo-logging-config \
  --destination-configuration cloudWatchLogs={logGroupName=ivs-demo-logging-config-log-group}
```

## Associating a Logging Configuration With an Existing Amazon IVS Chat Room via the Amazon IVS Console

We can now associate the logging configuration with an existing Amazon IVS chat room. Select **Rooms** under **Chat** in the left sidebar, choose the room that you'd like to associate the configuration with, and then click **Edit**.

![Edit chat room](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-9jzitehpifl3bc8zayql.png)

On the room edit page, scroll down and select **Automatically log messages and events** (#1). In the **Logging configurations** dropdown (#2), search for and associate the configuration that we created above. Note that you can associate multiple configurations with a room, so if you'd also like to log to an Amazon Kinesis Data Firehose or Amazon S3, you can create separate configurations and associate them with your room. Also note that you can create a brand new configuration directly from the edit room page by clicking on the **Create logging configuration** button (#3). 

![Message logging for chat room](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5m2hwuc8tj0x6vi0xj1r.png)

## Associating a Logging Configuration With an Existing Amazon IVS Chat Room via the AWS SDK

In production, you'll likely use the SDK to associate your logging configuration with a new or existing chat room. To do that, use `CreateRoomCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/createroomcommand.html)) or `UpdateRoomCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/updateroomcommand.html)). Here's an example of updating an existing chat room with a chat logging configuration. As expected, we'll need to pass the ARN as the `identifier` of the chat room, and any/all chat logging configuration ARNs in an array to `loggingConfigurationIdentifiers`. 

```js
import { IvschatClient, UpdateRoomCommand } from "@aws-sdk/client-ivschat";

const ivsChatClient = new IvschatClient();
const updateChatRoomInput = {
  identifier: 'arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]',
  loggingConfigurationIdentifiers: [
    'arn:aws:ivschat:us-east-1:v:logging-configuration/[redacted]',
  ]
};
const updateChatRoomRequest = new UpdateRoomCommand(updateChatRoomInput);
const updateChatRoomResponse = await ivsChatClient.send(updateChatRoomRequest);
console.log(updateChatRoomResponse);
```

> **Note:** You can specify multiple logging configurations for a chat room. This lets you use multiple destinations, if desired. The array of chat logging identifiers that you pass via the SDK to `UpdateRoomCommand` will overwrite any existing identifiers, so if you are adding an additional configuration, make sure to include any existing configuration ARNs to avoid removing them.

## Retrieving Chat Logs

At this point, all new messages posted to an Amazon IVS chat room will be logged to the destination(s) specified by the attached logging configuration(s). As mentioned above, in the case of CloudWatch as a logging destionation, we can use the CloudWatch SDK to retrieve our chat logs for a given time period. To do this, we need the **logGroupName**, the start and end timestamp (in Unix timestamp format), and the **logStreamNames**. The **logStreamName** will be in the format: `aws/IVSChatLogs/1.0/room_[suffix of chat room ARN]`. So, for a chat room with an ARN of `arn:aws:ivschat:us-east-1:[redacted]:room/0wgOPVl4ZRdu`, the **logStreamName** will be `aws/IVSChatLogs/1.0/room_0wgOPVl4ZRdu`.

## Retrieving CloudWatch Logged Chat Messages

Here's how to use the `CloudWatchLogsClient` to construct a `FilterLogEventsCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-cloudwatch-logs/classes/filterlogeventscommand.html)) that is used to retrieve chat logs. 

```js
import { CloudWatchLogsClient, FilterLogEventsCommand } from "@aws-sdk/client-cloudwatch-logs";

const cloudwatchClient = new CloudWatchLogsClient();

const filterLogEventsInput = {
  logGroupName: 'demo-chat-log-cw-group',
  logStreamNames: ['aws/IVSChatLogs/1.0/room_0wgOPVl4ZRdu'],
  startTime: 1672929210000,
  endTime: 1672929330000,
};
const filterLogEventsRequest = new FilterLogEventsCommand(filterLogEventsInput);
const filterLogEventsResponse = await cloudwatchClient.send(filterLogEventsRequest);
const events = filterLogEventsResponse.events.map(e => JSON.parse(e.message));
```

> **How do I know which start and end time to use?** Remember that [Amazon IVS sends events to EventBridge](https://dev.to/aws/notifying-subscribers-when-an-amazon-ivs-stream-is-online-f1c) when streaming to a channel. You might use a stream start and end time if you're trying to retrieve chat logs for a specific Amazon IVS live stream.

Keep in mind, that the `FilterLogEventsCommand` can not return an infinite number of events. You may have to check the `FilterLogEventsCommandOutput` for the existence of a `nextToken` and handle pagination if your time period has more events than can fit in a single response from the SDK. Refer to the SDK [docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-cloudwatch-logs/classes/filterlogeventscommand.html) for more information.

>By default, this operation returns as many log events as can fit in 1 MB (up to 10,000 log events) or all the events found within the specified time range. If the results include a token, that means there are more log events available. You can get additional results by specifying the token in a subsequent call. This operation can return empty results while there are more log events available through the token.

At this point we can do whatever we need with the chat log. Remember, chat logging will log **all events** posted to an Amazon IVS chat room, including custom events and events related to chat moderation. If we wanted to replay a chat stream, we'll probably need to parse the events a bit to clean up moderated messages and construct a "replayable" stream of messages.

> **More About Moderating Chat**: If you haven't read them yet, check out my blog posts on [automated](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p) and [manual](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646) chat moderation with Amazon IVS chat.

A function to parse the logged events might look similar to this. Your mileage may vary!

```js
const parseEvents = (events) => {
  let parsedEvents = [];
  events.forEach(e => {
    switch (e.type) {
      case 'MESSAGE':
        parsedEvents.push(e);
        break;
      case 'EVENT':
        if (e.payload.EventName === 'aws:DELETE_MESSAGE') {
          const existingEventIdx = parsedEvents.findIndex(parsedEvent => {
            return parsedEvent.payload.Id === e.payload.Attributes.MessageID
          });
          if (existingEventIdx > -1) {
            parsedEvents.splice(existingEventIdx, 1);
          }
        }
        break;
    }
  });
  return parsedEvents;
};
```
This function will return an array that is suitable for chat replay purposes with moderated messages removed from the chat log. Here's a small example of how the event stream might look.

```json
[
  {
    "event_timestamp": "2023-01-05T14:33:32.894Z",
    "type": "MESSAGE",
    "payload": {
      "Type": "MESSAGE",
      "Id": "WhO6MW6iRdS5",
      "RequestId": "",
      "Attributes": {
        "username": "gleningp"
      },
      "Content": "bbiab!",
      "SendTime": "2023-01-05T14:33:32.894089757Z",
      "Sender": {
        "UserId": "75758272-f3f2-4f65-83c5-9b8f144116b8",
        "Attributes": {}
      }
    },
    "version": "1.0"
  },
  {
    "event_timestamp": "2023-01-05T14:33:39.896Z",
    "type": "MESSAGE",
    "payload": {
      "Type": "MESSAGE",
      "Id": "VwEPwPV74GN3",
      "RequestId": "",
      "Attributes": {
        "username": "rpeirazzia"
      },
      "Content": "perfect",
      "SendTime": "2023-01-05T14:33:39.896519733Z",
      "Sender": {
        "UserId": "704D6BF8-22D2-4A52-B6A7-BDEFB115ECE5",
        "Attributes": {}
      }
    },
    "version": "1.0"
  },
  {
    "event_timestamp": "2023-01-05T14:33:47.330Z",
    "type": "MESSAGE",
    "payload": {
      "Type": "MESSAGE",
      "Id": "00kqu1sPa6dF",
      "RequestId": "",
      "Attributes": {
        "username": "jmycroft2"
      },
      "Content": "🔥🔥🔥",
      "SendTime": "2023-01-05T14:33:47.330983449Z",
      "Sender": {
        "UserId": "2F12AA2D-DF65-42CF-AE99-133A5A06F7B4",
        "Attributes": {}
      }
    },
    "version": "1.0"
  }
]
```

## Summary

In this post, we learned how to log messages posted to an Amazon IVS chat room. In our next post, we'll look at bringing together auto-recorded live streams and logged chat messages in an application to create a suitable "on-demand" replay user experience.
