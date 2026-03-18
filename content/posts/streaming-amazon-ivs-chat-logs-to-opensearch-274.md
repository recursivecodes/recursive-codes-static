---
title: "Streaming Amazon IVS Chat Logs to OpenSearch"
slug: "streaming-amazon-ivs-chat-logs-to-opensearch-274"
author: "Todd Sharp"
date: 2023-03-17T13:12:58Z
summary: "One of the easiest ways to make a live stream interactive is to add live chat along side of the..."
tags: ["gratitude"]
canonical_url: "https://dev.to/aws/streaming-amazon-ivs-chat-logs-to-opensearch-274"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nrvg9vu9qd1jh7wpboai.jpeg"
---

One of the easiest ways to make a live stream interactive is to add live chat along side of the stream. With Amazon Interactive Video Service it's easy to [create a chat room](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) and add moderation (both [manual](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646) and [automated](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p)). It's also simple to [add chat logging](https://dev.to/aws/archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j) to your chat rooms to archive chat sessions to Amazon CloudWatch, an Amazon Kinesis Data Firehose, or Amazon S3. 

Depending on your logging configuration, there are different approaches to retrieving logged chat sessions (for example, using the CloudWatch SDK as we saw in my [last post](https://dev.to/aws/archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j)). But sometimes our application needs to do more than just retrieve a chat session for a given time period. Sometimes we need the ability to search for a specific message, or group of messages based on a specific keyword, or see a list of messages posted by a certain user. 

For this, we can integrate our CloudWatch log group with Amazon OpenSearch Service to provide fine-grained search for chat messages and events based on any property that we might need. 

## Prerequisites

This post will assume that you have already set up chat logging for your Amazon IVS chat room, and that you already have an existing OpenSearch Service domain. If not, check out the following links to get everything setup.

* [Getting started with Amazon OpenSearch Service](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/gsg.html)
* [Archiving Web Chat Messages with Amazon IVS Chat Logging](https://dev.to/aws/archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j)

## Sending CloudWatch Logs to OpenSearch Service

Integrating a CloudWatch log groups with OpenSearch Service is natively supported, so there's no need for manual steps in this process. We'll cover the whole process below, but if you get stuck at any point, refer to the [documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_OpenSearch_Stream.html).

### Add Subscription Filter

Navigate to the CloudWatch log group that you created and associated with your Amazon IVS chat logging configuration and view the log group details. Click on the **Actions** menu from this page.

![CloudWatch log group details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gpf7fprtvo38a7hw4ovs.png)

Select the **Subscription filters** menu item, and in the submenu select **Create Amazon OpenSearch Service subscription filter**.

![Actions menu](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-auyldqtge9yh2f2xrpd6.png)

On the next page, find and select the OpenSearch Service cluster where you would like to send the log data.

![OpenSearch Service cluster name](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-njz4z1rg29khidpbyv96.png)

Under **Configure log format and filters**, select `JSON`. If you want to only index a subset of your chat logs, you can enter a filter. If you would like all logged chat events, leave the filter **blank**. Either way, you must enter a **Subscription filter name**.

![Configure log format and filters](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-frsxl874zpaflvn44zuy.png)

If you do choose to enter a filter, it must follow the syntax outlined in the [documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html). For example, to filter the indexing of messages only sent by a particular user, the following filter can be applied and tested.

```
{ $.payload.Attributes.username = "Admin" }
```

![Filtering events](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-fowlw41p60lfff8o6ejd.png)

When you're satisfied with the configuration, click **Start streaming**. The subscription filter will create an AWS Lambda function behind the scenes that will handle indexing each new log entry/chat message in the OpenSearch Service console. We'll have to create an IAM role to enable that function to access the OpenSearch Service console, so in the **Subscription filters** list of your CloudWatch log group, grab the **Destination ARN** of the newly created function.

![Subscription filters](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-v7ahci5zpenqiajhi2l9.png)

### Creating an IAM Role

Head over to the IAM console, and select **Roles**, **Create role**. Select **AWS Service** as the **Trusted entity type**, and **Lambda** under **Use case**.

![IAM Service and use case](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-un1ne11pda7ozjp2ks3u.png)

Add the **AmazonOpenSearchServiceFullAccess** policy to the IAM role.

![AmazonOpenSearchServiceFullAccess](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wr5ligd14qyx6g9bwsxc.png)

Give the role a name, then click **Create role**.


![Role name](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tgbjcxyhkb7tj1b5m3ed.png)

If your OpenSearch Service domain uses fine-grained access control, we'll need to do one more step to make sure that our chat logs can stream to the search cluster. In your OpenSearch dashboard, select **Security**.

![OpenSearch dashboard](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-d35jbct5vtg8j5md4mbd.png)

Next, select **Roles**, then choose the **all_access** role.

![OpenSearch roles](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-03m2rvwta3n7ugafcnvn.png)

Choose the **Mapped users** tab, then click **Manage mapping**.

![Mapped users](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-e1wleb0m9ej3setw5x20.png)

In the **Backend roles** section, add the ARN of the AWS Lambda execution role that we created above and click **Map**.

![Mapping](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-01oy240kaud9zmp55env.png)


## Querying OpenSearch For Chat Messages

At this point, all new chat messages that are logged to CloudWatch will be streamed directly to the OpenSearch Service cluster. There will be a unique index created for each day's worth of CloudWatch logs, and the index name will follow the format `cwl-YYYY-MM-DD`.

To get a list of all indices in your cluster, issue the following query:

```
GET /_cat/indices
```
This will return a list of the indices, one of which should be named with the prefix `cwl` (for CloudWatch log). This index will contain your chat messages.

```
yellow open cwl-2023.03.06       -Je9wXJLSWWxLy3Jj6vSkA 5 1  9 0 104.6kb 104.6kb
yellow open cwl-2023.03.03       wabX_QhPTfmMuI53Xv61rg 5 1  9 0 115.5kb 115.5kb
green  open .opendistro_security SXnVYG-MQLanddjHyJUJXQ 1 0 10 3    65kb    65kb
green  open .kibana_1            TW-4N5cQRQObaXMKA3hBYA 1 0  1 0   5.1kb   5.1kb
```

We can issue standard OpenSearch queries against a index to search for chat messages.

```json
POST /cwl-2023.03.03/_search
{
  "query": {
    "wildcard": {
       "payload.Content": {
          "value": "*weather*"
       }
    }
  }
}
```

This query will return a standard JSON result containing metadata about the index, query execution, and the query results.

```json
{
  "took" : 120,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 1,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "cwl-2023.03.03",
        "_id" : "[redacted]",
        "_score" : 1.0,
        "_source" : {
          "event_timestamp" : "2023-03-03T16:01:33.875Z",
          "type" : "MESSAGE",
          "payload" : {
            "Type" : "MESSAGE",
            "Id" : "Ll4kxDgNaW7f",
            "RequestId" : "",
            "Attributes" : {
              "username" : "Admin"
            },
            "Content" : "the weather is cold",
            "SendTime" : "2023-03-03T16:01:33.87564497Z",
            "Sender" : {
              "UserId" : "8e9a91d3-3ab7-4b89-b2a8-da1326beb055",
              "Attributes" : {
                "username" : "Admin"
              }
            }
          },
          "version" : "1.0",
          ...
        }
      }
    ]
  }
}

```

Since the chat messages are JSON, we can even search directly for chat messages posted by a specific user:

```json
POST /cwl-2023.03.03/_search 
{
  "query": {
    "match": {
      "payload.Attributes.username": "Admin"
    }
  }
}
```

If multiple chat rooms are sharing the logging configuration, we can search for messages related to a specific room.

```json
POST /cwl-2023.03.06/_search 
{
  "query": {
    "match": {
      "@log_stream": "aws/IVSChatLogs/1.0/room_0wgOPVl4ZRdu"
    }
  }
}
```

We can also search for messages within a given timeframe.

```json
POST /cwl-2023.03.06/_search 
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-10m",
        "lt": "now"
      }
    }
  }
}
```

Refer to the OpenSearch [documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-your-data.html) for more information on querying your index.

## Summary

In this post, we looked at how to stream a Amazon IVS chat log messages into an OpenSearch Service cluster via a CloudWatch log group subscription filter. This allows us to perform powerful queries against our chat log history and find messages by specific criteria.