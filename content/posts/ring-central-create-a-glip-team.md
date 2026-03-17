---
title: "Ring Central - Create A Glip Team"
slug: "ring-central-create-a-glip-team"
author: "Todd Sharp"
date: 2020-02-21
summary: ""
tags: ["APIs", "Java"]
keywords: "api, java, chat"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1306/banner_52e3d5474e53b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

In [my last post](https://recursive.codes/blog/post/1302), I showed you how to make a voice call with Java and Ring Central. In this post, I'll show you how to create your first Glip team. If you get stuck, [refer to the developer portal docs](https://developers.ringcentral.com/guide/team-messaging/quick-start/java), but it's pretty simple.

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



Now you're ready to create the team:
```java
var parameters = new GlipPostTeamBody();
parameters._public = true;
parameters.name = "Fun team";
parameters.description = "Let chit chat here";

HashMap<String, String> members = new HashMap<String, String>();
members.put("email", "member.1@gmail.com");
members.put("email", "member.2@gmail.com");

parameters.members = new HashMap[] { members };

var response = restClient.restapi().glip().teams().post(parameters);
String jsonStr = JSON.toJSONString(response);
System.out.println(jsonStr);
```

 
```java
MakeRingOutRequest requestBody = new MakeRingOutRequest();
requestBody.from(new MakeRingOutCallerInfoRequestFrom().phoneNumber(RINGCENTRAL_USERNAME));
requestBody.to(new MakeRingOutCallerInfoRequestTo().phoneNumber(RECIPIENT_NUMBER));
requestBody.playPrompt = false;

var response = restClient.restapi().account().extension().ringout().post(requestBody);
System.out.println("Call Placed. Call status: " + response.status.callStatus);
```



And that's all it takes to create a Glip team with Ring Central and Java. You can [learn more about Glip](https://developers.ringcentral.com/guide/team-messaging) here.

Image by [SoapWitch](https://pixabay.com/users/SoapWitch-387310) from [Pixabay](https://pixabay.com)
