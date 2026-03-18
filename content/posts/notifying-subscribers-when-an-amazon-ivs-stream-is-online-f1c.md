---
title: "Notifying Subscribers when an Amazon IVS Stream Is Online"
slug: "notifying-subscribers-when-an-amazon-ivs-stream-is-online-f1c"
author: "Todd Sharp"
date: 2022-12-14T13:03:59Z
summary: "Creators are the life blood of any user generated content (UGC) platform. One of the challenges of..."
tags: ["javascript", "react", "discuss"]
canonical_url: "https://dev.to/aws/notifying-subscribers-when-an-amazon-ivs-stream-is-online-f1c"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zn0fjq1km8riqzwarndo.jpeg"
---

Creators are the life blood of any user generated content (UGC) platform. One of the challenges of building out a live streaming UGC application is giving content creators the tools they need to grow their audience. Without viewers, creators will not be motivated to create content (and without motivated creators, we won't have a platform). Once viewers find a creator that they love interacting with, they'll subscribe to that channel and look forward to tuning in whenever that creator is online. This is where things get tricky - because most viewers won't stay logged into our application open 24/7 to check to see if their favorite creator is online. To encourage them to return to our platform, we need to build a notification system to alert viewers when their favorite streams are online. Thankfully, this is something that is quite easy to build with Amazon Interactive Video Service (Amazon IVS). In this post, we'll look at how to notify viewers when an Amazon IVS stream is online.

## EventBridge Over Troubled Streams

To build this feature, we'll take advantage of the fact that Amazon IVS sends change events about the status of our streams to Amazon EventBridge. This integration can be used for many different purposes, as there are a ton of events that get published for every stream. Here's a list of just a few of the events that get published:

- Session Create / End
- Stream Start / End / Failed
- Recording Start / End

> For the full list of events, see the [documentation](https://docs.aws.amazon.com/ivs/latest/userguide/eventbridge.html).

As you might guess, the event that we'll take advantage of is the **Stream Start** event. Let's create a rule that will be triggered each time our stream starts.

## Creating the AWS Lambda Handler Function

Before we create an EventBridge Rule, we need to create an AWS Lambda Function that will be called from the rule (it must exist before the rule can be created). We'll use the newly available Node 18.x for our function.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-te8567s32se1beo00u8d.png)

This function will be how we send notifications to subscribers when the stream goes live. In your application, you can utilize whatever method works best to send the notification. If you have a mobile app or PWA, you might want to send a push notification. Maybe your subscribers prefer email notifications? Or maybe you want to post a message to a social media feed or Discord/Slack channel. Perhaps you want to use Amazon SNS to send an SMS message to subscribers? There are tons of different options here and there are no limitations. In my case, I am using [Pushover](https://pushover.net) to send a push notification to my mobile device. Pushover has a nice REST based API that is easy to use.

```js
export const handler = async(event) => {

    // push notification using Pushover.net
    const formData = new FormData();
    formData.append('token', process.env.PUSHOVER_APP_TOKEN);
    formData.append('user', process.env.PUSHOVER_USER_TOKEN);
    formData.append('title', `${event.detail.channel_name} is Live!!!`);
    formData.append('message', 'Watch now!');
    formData.append('url', 'https://recursive.codes');
    
    const pushoverResponse = await fetch('https://api.pushover.net/1/messages.json', {
       method: 'POST',
       body: formData
    });
    
};
```

## Creating the EventBridge Rule

This rule can be created with the AWS CLI ([docs](https://docs.aws.amazon.com/cli/latest/reference/events/put-rule.html)), any of the AWS SDKs, or the AWS Console. For this post, we'll focus on the console. Login to the Amazon EventBridge console, select **EventBridge Rule**, and click **Create rule**.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nhm668by2z7xcbrqiwv2.png)

On the next page, give the rule a **Name**, an optional **Description**, choose an **Event bus**, select **Rule with an event pattern**, and click **Next**.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-0h1b85uv6tslw1dfoehy.png)

Select **AWS events or EventBridge partner events**.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6ym9gvkv1dsm9vo5ml8s.png)

If you want to create a sample event for testing purposes, select **Enter my own**, and paste in the following pattern.

```json
{
  "version": "0",
  "id": "01234567-0123-0123-0123-012345678901",
  "detail-type": "IVS Stream State Change",
  "source": "aws.ivs",
  "account": "123456789012",
  "time": "2017-06-12T10:23:43Z",
  "region": "us-east-1",
  "resources": ["arn:aws:ivs:us-east-1:123456789012:channel/12345678-1a23-4567-a1bc-1a2b34567890"],
  "detail": {
    "event_name": "Stream Start"
  }
}
```

Under **Creation method**, select **Use pattern form**, then an **Event source** of **AWS services**. For the **AWS service**, choose **Interactive Video Service (IVS)**. Finally, under **Event type**, choose **IVS Stream Stage Change**.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7t4gojwwr6ct47ok1l09.png)

We can leave the **Event pattern** as is, or we can limit this rule to only the **Stream Start** event by clicking **Edit pattern** and modifying it to look like the following:

```json
{
  "source": ["aws.ivs"],
  "detail-type": ["IVS Stream State Change"],
  "detail": {
    "event_name": ["Stream Start"]
  }
}
```

Click **Test pattern** to make sure that the **Event pattern** matches the sample event from above and then click **Next**.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-qrbiykjrxe7ne8x8f8o7.png)

In the next step, under **Target 1**, select **AWS service**. Under **Selet a target**, choose **Lambda function**, then find and select the Lambda function that we created earlier.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-c27k37ocvup4oql3dwco.png)

Click **Next**, enter any desired tags, then review and create the rule.

## Going Live

We're all set to test out our rule. To do so, we just need to start broadcasting to an Amazon IVS channel. Once we do, our rule will trigger and our Lambda function will be invoked. In my case, that results in a nice push notification on my mobile device.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-xoc8wnujpitlp4y2vay8.png)

## Summary

In this post, we created an AWS Lambda function to send push notifications and created an Amazon EventBridge rule to invoke that function when our Amazon IVS live stream begins. Your function will probably involve some additional logic to lookup the subscribers based on the channel that is currently broadcasting which you can do based on the ARN contained in the `resources` key in the event details. To learn more, refer to the [documentation](https://docs.aws.amazon.com/ivs/latest/userguide/eventbridge.html).