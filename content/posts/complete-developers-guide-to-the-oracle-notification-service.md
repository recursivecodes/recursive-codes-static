---
title: "Complete Developers Guide To The Oracle Notification Service"
slug: "complete-developers-guide-to-the-oracle-notification-service"
author: "Todd Sharp"
date: 2020-03-15
summary: "In this post we'll look at how to configure a notification topic that can be used to broadcast data to various potential endpoints like email, PagerDuty and Slack. "
tags: ["Cloud", "Containers, Microservices, APIs", "Java"]
keywords: "Java, Cloud, Integration, notification"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/banner_absolutvision_82tpeld0_e4_unsplash.jpg"
---

When you compile a list of your favorite features in the cloud, I'd be willing to bet that notifications aren't typically cracking the "top 10" of many developers lists. It's more of a "utility" feature. Kind of like the tires on your car - you need to have them, and when they aren't working you probably get grumpy. But when they are working fine you hardly think about them. That's how I used to think about notifications, until I recently started digging in to our offering: [Oracle Notification Service](https://www.oracle.com/cloud/systems-management/notifications/) (ONS). It's odd - I found myself actually getting excited to learn about the service and play around with it. It's implemented, like so many other things in the Oracle Cloud, in a really easy to use and straightforward way. It also integrates **very well **with many other services in our cloud as well as external tools and services. Let's take a really deep dive into ONS.

Notifications is a broad term, so let me clarify. Your application might send emails to your users when something happens. For example: a file or order has been processed. That's a potential notification. As a developer or DevOps Engineer you might also want to know when something has changed in your infrastructure. For example, a DB backup has begun or completed. This is also a potential notification. Notifications sometimes don't even involve users or developers. Maybe you have a serverless function that needs to run when an object is uploaded to Object Storage. This can be handled via notifications. There are many different activities that fall under the umbrella term "notification" and ONS can handle just about every scenario you can think of.

In this post we'll cover:

- [Creating Notification Topics](#create-topics)
- [Subscribing To Topics](#subscribe-topics)
- [Creating A Slack App To Receive Notifications](#create-slack)
- [Sending Notifications Via The OCI Java SDK](#oci-send)
- [Automatically Sending Notifications Via Cloud Events](#event-send)
- [Automatically Sending Notifications Via Service Alarms](#alarm-send)
- [Automatically Create GitHub Issues From Notifications With Zapier](#custom-https)

There's a lot to cover, so let's jump right in!

## Creating Notification Topics 

To get started with notifications, we'll have to first create a topic. From the Oracle Cloud console, select 'Application Integration' -\> 'Notifications'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_31_13.jpg)

Next, click 'Create Topic'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_31_45.jpg)

Enter a topic name and description and click 'Create Topic':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_32_36.jpg)

Your topic is now ready for subscriptions!

## Subscribing To Topics 

There are several protocols available for [notification subscriptions](https://docs.cloud.oracle.com/iaas/Content/Notification/Tasks/managingtopicsandsubscriptions.htm):

- Email
- PagerDuty
- HTTPS (Custom URL)
- Slack

**Fun Hack**: We won't cover email as a subscription in this post, but you can use an email subscription to get an SMS notification by using [your mobile phones "built-in, secret" email address](https://avtech.com/articles/138/list-of-email-to-sms-addresses/).  Most carriers support this. Give it a try - it totally works!

We will look at several of these in this blog post, starting with Slack. To get started, choose the newly created topic from the topic list:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_33_00.jpg)

Click 'Create Subscription':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_33_25.jpg)

Choose 'Slack' for the protocol. We'll need a webhook URL for the Slack subscription, so keep this window open and head to the next section of this blog post to create a new Slack application and obtain the webhook URL.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_34_40.jpg)

## Creating A Slack App To Receive Notifications 

You'll need to create a Slack application in order for your notifications to be published to your Slack channel.  To get started, [head over to Slack and click 'Create an App'](https://api.slack.com/apps) and then give the app a name, choose the workspace in which you'd like to create the app and click 'Create App'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_19_44.jpg)

Next, click on 'Incoming Webhooks':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_20_32.jpg)

Note that webhooks are disabled by default, so enable them:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_21_22.jpg)

Click 'Add New Webhook to Workspace':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_22_04.jpg)

Confirm the permission to access the workspace, choose a channel to post to and click 'Allow'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_22_54.jpg)

Now grab the newly created webhook URL, we'll need it in just a few steps:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_23_39.jpg)

Head to the Slack channel that you'd like to post notifications to and click 'Add an app' from the Gear Icon menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_26_30.jpg)

Or click 'Add an app' directly within the channel:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_29_45.jpg)

Search for your new app and select it:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_27_28.jpg)

You'll get a confirmation message in the channel:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_28_02.jpg)

Now head back to the console and complete the subscription dialog pasting the Slack Webhook URL:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_34_40.jpg)

At this point a subscription confirmation message will be posted to the Slack channel:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_38_27.jpg)

Click on the link in this message to confirm the subscription:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_43_48.jpg)

Now we can test out the Slack subscription. Back in the topic details page in the Oracle Cloud console, click on 'Publish Message'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_46_03.jpg)

Enter a simple message and click 'Publish'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_46_36.jpg)

Head to your Slack channel and confirm that the message was posted:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_09_46_59.jpg)

You've successfully created a Slack app that can subscribe to your ONS topic!

## Sending Notifications Via The OCI Java SDK 

We've covered quite a bit so far in this post. We've set up a notification topic, subscribed to the topic and created a custom Slack app to receive notifications from our topic and published a simple test message. But as I mentioned earlier in this post, your application will often need to send notifications to your topics and subscribers, so let's take a look at a small Java application that publishes a message to our topic. We'll need to grab our topic OCID from the topic details page, so copy that and keep it handy.

All of the code that is required to run this [demo is available in GitHub](https://github.com/recursivecodes/ons-demo), so feel free to check out that repo later on.  I like to use Gradle, so my first step is to create a `build.gradle` file and include the OCI Java SDK as a dependency.
```groovy
plugins {
    id 'java'
    id 'application'
}

group 'codes.recursive'
version '0.1-SNAPSHOT'

sourceCompatibility = 1.8

repositories {
    mavenCentral()
}

application {
    mainClassName = 'codes.recursive.OnsSendExample'
}

dependencies {
    compile group: 'com.oracle.oci.sdk', name: 'oci-java-sdk-full', version: '1.9.0'
    testCompile group: 'junit', name: 'junit', version: '4.12'
}

tasks.withType(JavaExec) {
    systemProperties System.properties
}
```



Create a Run/Debug profile in your IDE and set the ONS topic OCID as an environment variable:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_08_33.jpg)

Create a class called Ons.java that we'll use to invoke the SDK client to publish a message. Here we have a single method called `sendNotfication()` that receives a `title` and `message` argument. We create an auth provider, passing it the name of the profile to use (the default OCI config file location \[`/.oci/config`\] is used for the config file itself since we did not specify a path). Next, we create a `NotificationDataPlaneClient` and a `MessageDetails` object which contains our title and message. Then a `PublishMessageRequest` is constructed that contains our `MessageDetails` instance and finally we use the client to publish the message by passing it the `PublishMessageRequest`.  That might sound tricky or complicated, but I can assure you it's not as you can see from the code below:
```java
package codes.recursive;

import com.oracle.bmc.auth.ConfigFileAuthenticationDetailsProvider;
import com.oracle.bmc.ons.NotificationDataPlaneClient;
import com.oracle.bmc.ons.model.MessageDetails;
import com.oracle.bmc.ons.requests.PublishMessageRequest;

public class Ons {

    public void sendNotification(String title, String message) throws Exception {

        String topicId = System.getenv("TOPIC_ID");

        if( topicId == null ) {
            throw new Exception("Please set a TOPIC_ID environment variable!");
        }

        ConfigFileAuthenticationDetailsProvider provider =  new ConfigFileAuthenticationDetailsProvider("DEFAULT");
        NotificationDataPlaneClient client = NotificationDataPlaneClient.builder().region("us-phoenix-1")
                .build(provider);

        MessageDetails messageDetails = MessageDetails.builder().title(title).body(message).build();

        PublishMessageRequest publishMessageRequest = PublishMessageRequest.builder()
                .messageDetails( messageDetails )
                .topicId(topicId)
                .build();

        client.publishMessage( publishMessageRequest );
    }

}
```



Now create a barebones main class called `OnsSendExample.java` that constructs an instance of our `Ons` class and sends a notification:
```java
package codes.recursive;

import java.util.Date;

public class OnsSendExample {

    public static void main(String... args) throws Exception {
        Ons ons = new Ons();
        ons.sendNotification(
                "Test from Java",
                "This is a test notification sent by the Java SDK at " + new Date().toString()
        );
    }

}
```



Now we can confirm delivery by checking our Slack channel!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_17_40.jpg)

## Automatically Sending Notifications Via Cloud Events 

I've covered [Cloud Events before on this blog](/posts/oracle-functions-invoking-functions-automatically-with-cloud-events), but the context was different and it's always good to get a refresher, so let's dig into sending notifications via cloud events.

First of all, what are they?  Many services is the Oracle Cloud emit *events *which are structured messages that follow the [CNCF Cloud Event](https://github.com/cloudevents/spec) spec. An event could be a create, read, update, or delete (CRUD) operation, a resource lifecycle state change, or a system event impacting a resource. For example, an event can be emitted when a backup completes or fails, or a file in an Object Storage bucket is added, updated, or deleted.

There are [many different OCI services that produce cloud events](https://docs.cloud.oracle.com/iaas/Content/Events/Reference/eventsproducers.htm#ServicesthatProduceEvents):

- Block Volume
- Compute
- Database
- Networking
- Notifications
- Object Storage

This gives you a tremendous amount of power to monitor your infrastructure as there are a number of helpful event types per service. For example, here's a look at the Autonomous Database Event Types:

- Create Backup Begin
- Create Backup End
- Create Instance Begin
- Create Instance End
- Restore Begin
- Restore End

And it's not just Autonomous DB that has a collection of event types that it broadcasts. Each and every different DB offering on the Oracle Cloud has it's own set of event types:

- Autonomous Databases
- Autonomous Container Databases
- Autonomous Exadata Infrastructure instances
- Exadata Infrastructure
- VM cluster networks
- VM clusters
- Backup destinations
- Database nodes
- Database Homes
- Databases

To work with Cloud Events you create **rules** which can contain filters to specify certain resources or attributes on which the rule should be triggered and **actions **to take when the rule is satisfied. There are currently three types of actions you can choose from: Functions (which call an Oracle Function serverless function), Streaming (which produce messages to a stream in Oracle Streaming Service) and Notifications which publish the event to an ONS topic. The final action is the one we'll focus on in this post, so let's get started creating a rule.

Choose 'Application Integration' then 'Events Service' in the Oracle Cloud console sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_22_17.jpg)

Next, from the rules list page, click 'Create Rule'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_23_27.jpg)

Give it a name and a description:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_24_39.jpg)

Next we'll add a filter to this rule for events from the Object Storage service - specifically Object Create events. We'll further filter this to a specific bucket:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_59_45.jpg)

Now we'll define the actions to take when the rule is triggered. In this case, we'll call our ONS topic:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_29_54.jpg)

At this point we can save the rule and test it out by uploading an object to our Object Storage bucket. We'll be rewarded with a shiny new message in our Slack channel. This message is a bit different from what we've seen before as it's the entire Cloud Event in stringified JSON format, but it contains a ton of useful information that we can use if we needed to take action from this notification.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_10_46_22.jpg)

## Automatically Sending Notifications Via Service Alarms 

Alarms are a really nice way to keep an eye on your resources and infrastructure in the Oracle Cloud. [Creating alarms is really easy to do](https://docs.cloud.oracle.com/iaas/Content/Monitoring/Tasks/managingalarms.htm) and alarms can publish notifications to ONS when they meet the your specified threshold. Let's create an alarm that will publish a notification for us when our Object Storage bucket receives more than 10 get requests in a minute. This is obviously a contrived example - there are [very useful metrics available in many services](https://docs.cloud.oracle.com/iaas/Content/Monitoring/Concepts/monitoringoverview.htm#supported) that you can choose to keep an eye on with the Monitoring service. Let's create our demo alarm and test it out. Select 'Monitoring' and then 'Alarm Definitions' in the console sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_11_17_33.jpg)

Next, click 'Create Alarm':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_11_17_59.jpg)

Name it, choose a severity and define a body for the alarm message.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_11_29_37.jpg)

Now define the metric that will be evaluated for this alarm. We'll choose the namespace '`oci_objectstorage`' ([there are many other options](https://docs.cloud.oracle.com/iaas/Content/Monitoring/Concepts/monitoringoverview.htm#supported)), choose '`GetRequests`' for the metric, 1 minute for the interval and 'count' as the statistic. Add 'resourceDisplayName' as a dimension name and choose a specific bucket as the dimension value to filter the metric to a specific Object Storage bucket. Finally, a trigger rule of 'greater than', a value of 1 and a trigger delay of 1 minute.  This means that if there are more than 1 get requests over a period of 1 minute than the alarm will be triggered.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_11_30_09.jpg)

Finally, scroll down and specify the notification details and click 'Save Alarm':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_11_21_19.jpg)

We can test this by making a few 'GET' requests on an image that is stored in the given bucket. The alarm will trigger after the 1st request and post a message to the Slack channel as before:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_11_35_04.jpg)

## Automatically Create GitHub Issues From Notifications With Zapier 

I wanted to finish up this blog post with a final example of an external integration, but this time with something that may have a little more "real world" application than some of the above examples. In this example we'll add a subscription to our topic using an HTTPS (Custom URL) endpoint that we will create using [Zapier](https://zapier.com) which is a platform for creating "Zaps" that perform given actions based on given triggers (a similar concept to [IFTTT](https://ifttt.com) or "if this then that"). We'll create a Zapier webhook as the trigger (or the "when this happens" action) and use GitHub as the destination (or the "do this" action). Make sense? Great. Let's create a "Zap" by choosing 'Webhooks by Zapier' as the 'App' and 'Catch Raw Hook' as the trigger event:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_07_48.jpg)

This gives us a custom webhook URL - we'll need this later on.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_08_55.jpg)

Next, choose GitHub as the 'App' and 'Create Issue' as the action event in step 2 of the Zap:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_09_32.jpg)

Provide details - the project repo, issue title and issue body (the raw message body from ONS in this case):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_10_03.jpg)

Save, and create a subscription for the new webhook:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_05_17.jpg)

Confirm the subscription by viewing the new GitHub issue that was created:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_10_19.jpg)

Enable and test by publishing a message from the Oracle Cloud console:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_13_17_06.jpg)

You can even parse out Cloud Event JSON by [using JavaScript code in your Zaps](https://zapier.com/help/create/code-webhooks/use-javascript-code-in-zaps) as an interim step before creating the GitHub issue to end up with nicely formatted tickets (and even add filters for specific types of events, etc!):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_16_24_52.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_16_25_32.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/87cec46b-805e-496a-8590-f7d159133b70/2019_10_10_16_22_47.jpg)

There are a number of additional integrations available on Zapier - you can create Jira Issues, send SMS alerts, integrate with Twitter and much more. 

## Summary

I started out this journey feeling like notifications were kinda boring but I quickly learned that there is a ton of potential here to make a developers life easier and make your applications more intelligent. I know that there's a lot of information in this post. It probably could have been 2 or 3 separate posts, but it felt right to keep it all together in this format. Feel free to bookmark it and use it as a future reference. Drop a comment below if you have any questions!

**Yo**!  Check out the code used in this post on GitHub!  <https://github.com/recursivecodes/ons-demo>

Photo by [AbsolutVision](https://unsplash.com/@freegraphictoday?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/note?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
