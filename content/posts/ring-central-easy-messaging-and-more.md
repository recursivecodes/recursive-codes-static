---
title: "Ring Central - Easy Messaging And More"
slug: "ring-central-easy-messaging-and-more"
author: "Todd Sharp"
date: 2020-02-20
summary: "In this post, I'll tell you about Ring Central."
tags: ["APIs"]
keywords: "sms, voicemail, virtual assistants"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1280/banner_51e4d6464e5bb108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

I've blogged in the past about Twilio which has a ton of APIs for calls, chat and messaging, but today at DevNexus I learned about Ring Central which offers many similar products and services. Ring Central has a ton of different options, but, for myself I was mostly interested in the potential for sending SMS since I spend a lot of time tinkering with Arduino and Raspberry Pi and have been looking for a solution to help me send SMS notifications quickly and easily. I'll tell you more about that in a minute, but, before I do that let me tell you about something really cool - their "[Game Changer](https://gamechanging.dev)" program. In a nutshell, you sign up to learn more about the platform by completing various fun challenges. Some are simple - like reading a blog post or watching a video. Others are more involved, like creating your first application to send an SMS or make a phone call. When you complete these challenges, you earn points (different amounts depending on the complexity of the challenge). Gamification is nothing new - and it's an effective, but typically it comes in the form of "digital" awards like badges and leaderboards. Ring Central takes it a step further and lets you redeem the points for actual, tangible, real world rewards. Seriously - they give you real life prizes for learning and spreading the word about the platform. Obviously you'll have to work to earn the good stuff like iPads, MacBooks, etc - but, there's literally no catch. Work as hard as you want, learn as much as you want and cash in your points. Check out [the rewards](https://hub.gamechanging.dev/rewards) they offer - it's no joke.

The best way to learn, to me, is to look at some code so let me show you an example of how to send an SMS with Node.JS. The first step is to sign up and create an application to get your phone number and credentials that you'll need to plugin below, but this is how to send an SMS with their APIs:
```javascript
const SDK = require('@ringcentral/sdk').SDK

RECIPIENT = '<ENTER PHONE NUMBER>'

RINGCENTRAL_CLIENTID = '<ENTER CLIENT ID>'
RINGCENTRAL_CLIENTSECRET = '<ENTER CLIENT SECRET>'
RINGCENTRAL_SERVER = 'https://platform.devtest.ringcentral.com'

RINGCENTRAL_USERNAME = '<YOUR ACCOUNT PHONE NUMBER>'
RINGCENTRAL_PASSWORD = '<YOUR ACCOUNT PASSWORD>'
RINGCENTRAL_EXTENSION = '<YOUR EXTENSION, PROBABLY "101">'

var rcsdk = new SDK({
    server: RINGCENTRAL_SERVER,
    clientId: RINGCENTRAL_CLIENTID,
    clientSecret: RINGCENTRAL_CLIENTSECRET
});
var platform = rcsdk.platform();
platform.login({
    username: RINGCENTRAL_USERNAME,
    password: RINGCENTRAL_PASSWORD,
    extension: RINGCENTRAL_EXTENSION
    })
    .then(function(resp) {
        send_sms()
    });

function send_sms(){
  platform.post('/restapi/v1.0/account/~/extension/~/sms', {
       from: {'phoneNumber': RINGCENTRAL_USERNAME},
       to: [{'phoneNumber': RECIPIENT}],
       text: 'Hello World from JavaScript'
     })
     .then(function (resp) {
        console.log("SMS sent. Message status: " + resp.json().messageStatus)
     });
}
```



I plan on digging in deeper in the coming weeks. As I said, I'd ultimately love to integrate this into an Arduino project that I've had in mind - so stay tuned for more on that. If you want to learn more, sign up and make sure to check out their [developer portal](https://developers.ringcentral.com) for more examples.

\

Image by [ElinaElena](https://pixabay.com/users/ElinaElena-970541) from [Pixabay](https://pixabay.com)
