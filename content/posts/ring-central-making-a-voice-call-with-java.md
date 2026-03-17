---
title: "Ring Central - Making A Voice Call With Java"
slug: "ring-central-making-a-voice-call-with-java"
author: "Todd Sharp"
date: 2020-02-21
summary: ""
tags: ["APIs", "Java"]
keywords: "java, api, voice"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1302/banner_55e3d7464a5aac14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

In [my last post](https://recursive.codes/blog/post/1300), I showed you how to send an SMS message with Java and Ring Central. In this post, I'll show you how to make a voice call. If you get stuck, [refer to the developer portal docs](https://developers.ringcentral.com/guide/voice/quick-start/java), but it's pretty simple.

As always, first include the dependency:
```groovy
compile 'com.ringcentral:ringcentral:1.0.0-beta10'
```



Next, in your class, set some variables:
```java
static String RECIPIENT_NUMBER = "<ENTER PHONE NUMBER>";

static String RINGCENTRAL_CLIENTID = "<ENTER CLIENT ID>";
static String RINGCENTRAL_CLIENTSECRET = "<ENTER CLIENT SECRET>";
static String RINGCENTRAL_SERVER = "https://platform.devtest.ringcentral.com";

static String RINGCENTRAL_USERNAME = "<YOUR ACCOUNT PHONE NUMBER>";
static String RINGCENTRAL_PASSWORD = "<YOUR ACCOUNT PASSWORD>";
static String RINGCENTRAL_EXTENSION = "<YOUR EXTENSION, PROBABLY '101'>";

static RestClient restClient;
```



Create an instance of the client:
```java
try {
  restClient = new RestClient(RINGCENTRAL_CLIENTID, RINGCENTRAL_CLIENTSECRET, RINGCENTRAL_SERVER);
  restClient.authorize(RINGCENTRAL_USERNAME, RINGCENTRAL_EXTENSION, RINGCENTRAL_PASSWORD);
} 
catch (RestException | IOException e) {
  e.printStackTrace();
}
```



Now you're ready to make a call:
```java
MakeRingOutRequest requestBody = new MakeRingOutRequest();
requestBody.from(new MakeRingOutCallerInfoRequestFrom().phoneNumber(RINGCENTRAL_USERNAME));
requestBody.to(new MakeRingOutCallerInfoRequestTo().phoneNumber(RECIPIENT_NUMBER));
requestBody.playPrompt = false;

var response = restClient.restapi().account().extension().ringout().post(requestBody);
System.out.println("Call Placed. Call status: " + response.status.callStatus);
```



And that's all it takes to make a voice call with Ring Central and Java.

Image by [kareni](https://pixabay.com/users/kareni-5357143) from [Pixabay](https://pixabay.com)
