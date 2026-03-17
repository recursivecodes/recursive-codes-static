---
title: "Sending Push Notifications from Oracle Notification Service with Oracle Functions and Pushover"
slug: "sending-push-notifications-from-oracle-notification-service-with-oracle-functions-and-pushover"
author: "Todd Sharp"
date: 2021-04-06
summary: "In this post, we'll look at how to send a push notification to your mobile device from Oracle Notification Service with Oracle Functions and Pushover."
tags: ["Cloud", "JavaScript"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/banner_alert_3673338_1280.jpg"
---

The Oracle Notification Service is an extraordinary service. I've blogged about it in the past (see the [Complete Guide to the Oracle Notification Service](/posts/complete-developers-guide-to-the-oracle-notification-service)), but there's one piece of the puzzle missing today: push notifications. I'm sure some day this will be rectified, but until then I decided to tackle the issue with a third-party solution. In this post, I'll show you how to send push notifications to a mobile device from Oracle Notification Service via Oracle Functions and [Pushover](https://pushover.net).

Before you get started, head over to Pushover and sign up for a free account. All set? Great, let's get started!

Here's a quick table of contents for easy navigation:

- [Create Pushover App](#create-pushover-app)
- [Create A Serverless Application](#create-a-serverless-application)
  - [Create Application](#create-application)
  - [Create Function](#create-function)
  - [Set Application Config Vars](#set-application-config-vars)
  - [Populate Function](#populate-function)
  - [Deploy the Function](#deploy-the-function)
- [Testing the Function](#testing-the-function)
- [Create a Subscription in ONS](#create-a-subscription-in-ons)
- [Summary](#summary)

## Create Pushover App

The first step is to create an application on Pushover. When you're logged in, scroll down to 'Your Applications' and click on 'Create an Applciation/API Token'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281167.png)

Give it a name and description (and an icon, if you want) and click 'Create Application'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117312039.png)

Icon: Push Notification by Federica Sala from the Noun Project

Next, copy the new application's API key and save it locally.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281193.png)

Now you'll need to download and install the Pushover app on mobile.  You can find it in your favorite App Store. When you've installed it, you'll receive a "user key". Copy  this key to your local machine as well.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281200.png)

## Create A Serverless Application

Now we'll create a simple serverless application with Oracle Functions that will handle sending the push notification. Using the `fn` CLI, create a new application.

Before you get started, it's a good idea to always make sure you're running the latest version of the `fn` CLI. Check what the latest release is on [GitHub](https://github.com/fnproject/cli/releases), then check your version with:
```bash
$ fn --version
```



If you're not running the latest, you can update with:
```bash
# Linux or MacOS
$ curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh
#MacOS with Homebrew
$ brew install fn
```



Or, [download and install the latest binary](https://github.com/fnproject/cli/releases) from GitHub.

### Create Application
```bash
$ fn create app pushover-notification-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx.aaaaaaaaxi5jl3qf7weahirffrn6ttv2qjnagomwjvm367fcqocfmu6de5qa"]'
```



### Create Function

Right. Next, create a serverless function. I'm using Node.JS here for simplicity, but this code easily be a Java or Python app - whatever you're comfortable with!
```bash
$ fn init --runtime node fn-node-pushover-notification
```



### Set Application Config Vars

We need to set our Application and User keys into the serverless config so that we can access them from our function later on.
```bash
$ fn config app pushover-notification-app APP_KEY [Your APP Key]
pushover-notification-app updated APP_KEY with [Your APP Key]
$ fn config app pushover-notification-app USER_KEY [Your User Key]

pushover-notification-app updated USER_KEY with [Your User Key]
```



### Populate Function

Before we edit the function, modify package.json to include the dependency on the pushover library.
```json
"dependencies": {
  "@fnproject/fdk": ">=0.0.19",
  "node-pushover": "^1.0.0"
}
```



Now edit `func.js` to send the notification.
```javascript
const fdk = require('@fnproject/fdk');
const Pushover = require('node-pushover');
fdk.handle(async function(input){
  const appKey = process.env.APP_KEY;
  const userKey = process.env.USER_KEY;
 
  const pushover = new Pushover({ token: appKey, user: userKey });
  return new Promise((resolve, reject) => {
      pushover.send("Push Notification from ONS via Oracle Functions", input, (err, res) => {
        if(err) {
          console.log(err);
          reject(err);
        }
        else {
          console.log(res);
          resolve(res);
        }
      })
  });
})
```



### Deploy the Function

Deploy the function with:
```bash
$ fn deploy --app pushover-notification-app
```



## Testing the Function

Before we integrate with ONS, let's test out the function invocation and make sure it sends the notification.
```bash
$ echo -n “test” | fn invoke pushover-notification-app fn-node-pushover-notification
```



As you can see, I received a push notification on my mobile device.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281219.png)

Clicking on the notification takes me to a detailed view.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281222.png)

 

**Heads Up!** Pushover has a ton of support for various languages. Checkout the [list of libraries available](https://support.pushover.net/i44-example-code-and-pushover-libraries) and use the one that matches your favorite language!

## Create a Subscription in ONS

Now it's just a matter of creating a subscription in ONS that will invoke the function when a message is received.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281226.png)

Click on 'Publish Message' to test it out.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281229.png)

The push notification will be received just as it was when we manually invoked the function!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc6a4670-0a34-49b4-a532-f9d5c556e639/file_1617117281238.png)

## Summary

In this post, we looked at how to send push notifications from Oracle Notification Service via Oracle Functions with Pushover. If you have any questions or would like to see something else covered here on the developer blog, leave a comment below!

If you'd like to learn more about notifications, check out the following links.

- Overview: <https://docs.cloud.oracle.com/en-us/iaas/Content/Notification/Concepts/notificationoverview.htm>
- Use cases: <https://www.oracle.com/devops/notifications/>
- Developers Guide: [https://blogs.oracle.com/developers/complete-developers-guide-to-the-oracle-notification-service](/posts/complete-developers-guide-to-the-oracle-notification-service)
- Java Example: <https://github.com/oracle/oci-java-sdk/blob/master/bmc-examples/src/main/java/NotificationExample.java>

Image by [mohamed Hassan](https://pixabay.com/users/mohamed_hassan-5229782/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3673338) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3673338) 

