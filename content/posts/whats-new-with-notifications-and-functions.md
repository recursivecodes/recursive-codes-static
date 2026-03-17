---
title: "What's New With Notifications And Functions?"
slug: "whats-new-with-notifications-and-functions"
author: "Todd Sharp"
date: 2020-02-25
summary: "In this post I&#x27;ll show you how to invoke functions when a new notification is received in your Oracle Cloud tenancy."
tags: ["Cloud"]
keywords: "[&amp;quot;2e499432-91de-42b0-b02b-5eb82dacb4fc&amp;quot;,&amp;quot;05a261fb-8123-49f3-9d01-98d076327ca3&amp;quot;,&amp;quot;21edd1c1-32b9-4372-8626-b1e8d151f2c1&amp;quot;,&amp;quot;dfd52501-37c4-4bd8-aad3-4058ca79cd4b&amp;quot;]"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/banner_glenn_carstens_peters_rlw_uc03gwc_unsplash.jpg"
---

I've blogged about our awesome Oracle Notification Service (**ONS**) and Oracle Functions in the past, and the teams have been hard at work with some new improvements to make your life a little easier. Previously you could set up subscriptions for a Custom URL, PagerDuty, or Email, and could trigger an Oracle Function from services like Cloud Events, API Gateway and Oracle Integration Cloud. But today [you can combine these two awesome services and add your serverless function as a subscription to your notification topic](https://blogs.oracle.com/cloud-infrastructure/announcing-oracle-notifications-triggers-for-serverless-functions). This opens up many possible integrations and adds another reason why you should take advantage of all the different products and services available on Oracle Cloud.

Let's take a deeper look at this integration. Here are a few [diagrams from the documentation](https://docs.cloud.oracle.com/en-us/iaas/Content/Notification/Concepts/notificationoverview.htm) that I've updated to show the new feature.  The first diagram shows how **ONS** Notifications can be triggered as a result of a monitoring metric rule moving into an alarm state.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_17_03.png)

Previously you could receive a notification about this which probably meant that your on-call engineer rolled out of bed at 4AM and logged on to see that one of your sites made it to the front page of *Hacker News* and were getting hammered with traffic. While that's great news - congrats! - it still meant that she had to wake up and take some action instead of getting some much needed rest. Wouldn't it be nice to be able to automatically take some action instead? That's what a function subscription could do for you. Your function could determine that additional servers were necessary and could utilize the [OCI SDK](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/sdks.htm) to perform some automated and scripted action.

The next diagram illustrates how your custom services and applications can use the notification service directly to perform certain actions. Maybe your gigantic e-commerce application sends an email confirmation of a customer's order and you use notifications to send that confirmation to the customer, but you've also recently created the world's first fully autonomous factory and you need to initiate the order fulfillment robots launch sequence via a serverless function. In that case, we've got you covered!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_13_37.png)

**Disclaimer: **Perhaps fully autonomous warehouses with bots launched by serverless functions is a bit far fetched, but the use case has certainly been illustrated i think. 

Let me show you how to set up a function subscription to a notification topic.

## Create A "Hello World" Serverless Function

If you're new to Oracle Functions, check out this video to learn how to set up your tenancy (or [use the quick start guide](https://www.oracle.com/webfolder/technetwork/tutorials/infographics/oci_faas_gettingstarted_quickview/functions_quickview_top/functions_quickview/index.html#)):

Once your tenancy has been configured, create a "hello world" function and deploy it.  Here's another video that shows you how to create, deploy and invoke your first Oracle Function:

Now that you have created your first function, let's move on.

If you're new to Oracle Functions, be sure to check out the [Quick Start Guide](http://www.oracle.com/webfolder/technetwork/tutorials/infographics/oci_faas_gettingstarted_quickview/functions_quickview_top/functions_quickview/index.html#) to get your tenancy ready for serverless deployments!

## Add Subscription To Trigger The Serverless Function

The first step is to create a new notification topic, or choose an existing topic. Go into the topic details page and click 'Create Subscription'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_18_48.png)

Under 'Protocol', select 'Function'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_19_34.png)

When you choose the 'Function' protocol, additional inputs appear. Choose the function compartment, application and function ID that you would like invoked.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_20_41.png)

After your subscription is created, test it out by clicking 'Publish Message'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_21_35.png)

Enter some details and click 'Publish'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_10_57_53.png)

Now head over to your function's detail page and view the metrics to confirm the function was invoked.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_09_23_53.png)

If you've enabled logging to Object Storage on your function:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_10_58_57.png)

Then you'll be able to see any logged output in the given bucket:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_10_59_21.png)

Which you can download and view:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b3492d13-32a2-4d81-8251-3bfad72e71f9/2020_02_07_11_20_47.png)

And that's what it takes to have your **ONS **notifications trigger a serverless function in the Oracle Cloud. Make sure to [check the product announcement](https://blogs.oracle.com/cloud-infrastructure/announcing-oracle-notifications-triggers-for-serverless-functions) for more example scenarios, documentation links for the API and CLI.

Photo by [Glenn Carstens-Peters](https://unsplash.com/@glenncarstenspeters?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/note?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
