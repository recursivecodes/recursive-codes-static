---
title: "Ring Central - Sending SMS Messages With Java"
slug: "ring-central-sending-sms-messages-with-java"
author: "Todd Sharp"
date: 2020-02-21
summary: ""
tags: ["APIs", "Java"]
keywords: "java, sms, api"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1300/banner_52e4d2444a53b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

Yesterday I [blogged about Ring Central](https://recursive.codes/blog/post/1280http://) and their APIs for sending SMS, making voice calls and much more. In that post I showed an example of how easy it is to send an SMS with Node.JS. In this post, I'll show you a similar example, but this time using Java. It's just as easy to do with Java, but will look much more familiar if you're a Java user which I know many of my readers are.

The full process is well [documented on their developer portal](https://developers.ringcentral.com/guide/messaging/quick-start/java). After you've created your application in the portal, grab the necessary credentials and plug them in below. You'll first need to add the dependency. If you're using Gradle, that looks like this:
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



Then send the message:
```java
CreateSMSMessage postParameters = new CreateSMSMessage();
postParameters.from = new MessageStoreCallerInfoRequest().phoneNumber(RINGCENTRAL_USERNAME);
postParameters.to = new MessageStoreCallerInfoRequest[]{
    new MessageStoreCallerInfoRequest().phoneNumber(RECIPIENT_NUMBER)
};
postParameters.text = "Hello World from Java";

var response = restClient.restapi().account().extension().sms().post(postParameters);
System.out.println("SMS sent. Message status: " + response.messageStatus);
```



And that's all it takes to send an SMS with Java and Ring Central!

Image by [Greyerbaby](https://pixabay.com/users/Greyerbaby-2323) from [Pixabay](https://pixabay.com)
