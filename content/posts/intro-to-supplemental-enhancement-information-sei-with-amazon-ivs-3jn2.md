---
title: "Intro to Supplemental Enhancement Information (SEI) with Amazon IVS"
slug: "intro-to-supplemental-enhancement-information-sei-with-amazon-ivs-3jn2"
author: "Todd Sharp"
date: 2025-03-12T12:31:03Z
summary: "In my last post, we explored how to use AWS AppSync to add interactivity like emotes and reactions to..."
tags: ["aws", "amazonivs", "livestreaming"]
canonical_url: "https://dev.to/aws/intro-to-supplemental-enhancement-information-sei-with-amazon-ivs-3jn2"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4loowphs8mgtxdq0ynxt.png"
imagecontain: true
---

In my [last post](https://dev.to/aws/adding-real-time-interactivity-to-your-live-streams-with-aws-appsync-4gip), we explored how to use AWS AppSync to add interactivity like emotes and reactions to a real-time live streaming application built with Amazon Interactive Video Service (Amazon IVS). The method we looked at in that post worked great for the use case (and many others), but in this post we'll look at an alternative approach that uses a built-in - and more importantly, **free** - feature of Amazon IVS called Supplemental Enhancement Information (SEI).

## A Gentle Introduction to Supplemental Enhancement Information (SEI)

The Amazon IVS [docs](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/web-publish-subscribe.html#web-publish-subscribe-sei-attributes) tells us:

> The Supplemental Enhancement Information (SEI) NAL unit is used to store frame-aligned metadata alongside the video. It can be used when publishing and subscribing to H.264 video streams. SEI payloads are not guaranteed to arrive to subscribers, especially in bad network conditions.

## Putting Little Envelopes Into Boxes

The explanation from the docs might be a little intimidating if you're not a video expert. What this basically means is that we can take a little envelope of arbitrary data and put it inside the larger box of video data that we're already sending (✉️ ➡ 📦). Since we've already paid to send the box, we don't need to put a stamp on the little envelope (in other words – it's **_free_**).

But since UDP transport is a bit like certain postal services (which shall remain nameless), our little envelope may or may not make it to the intended recipient (🤷🏻‍♂️🫠). We can take out a little insurance policy against the loss of our little envelopes, by duplicating the little envelope and throwing it in the next several boxes that we send. Once we open the envelope for the first time, we can just throw away any duplicate envelopes we receive until we get a new, different envelope. More on that later.

## Sending Emotes with SEI

This isn't the best use case for SEI, but since we used it in the last blog post, let's take a look at how to use SEI to send emotes between real-time video chat participants.

> 🫨 **Why isn't this the best use case?** As we'll see in just a minute, SEI is published on a participant's `LocalStageStream` which only exists for participants who are actively publishing to the Amazon IVS stage. Since view-only participants don't publish to the stage, they'd be unable to emote. This approach pretty much only works in a web conference type application where **all participants** are actively publishing to the stage.

I'm going to assume that you're already familiar with how to [get started with Amazon IVS real-time stages](https://aws.github.io/amazon-ivs-web-broadcast/docs/real-time-sdk-guides/introduction), and just show the code neccessary to [enable publishing and subscribing SEI](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/web-publish-subscribe.html#web-publish-subscribe-sei-attributes).

### Subscribing

The first step here is to enable `inBandMessaging` on the stage's strategy object. This is done inside of the `subscribeConfiguration` method of the stage's `strategy` object.

```js
subscribeConfiguration: (participant) => {
  return {
    inBandMessaging: {
      enabled: true,
    },
  };
};
```

To listen for incoming messages, we listen for a special event on the stage.

```js
stage.on(StageEvents.STAGE_STREAM_SEI_MESSAGE_RECEIVED, (participant, seiMessage) => {
  console.log(seiMessage.payload, seiMessage.uuid);
});
```

### Publishing

We need to grant each participant the ability to publish by passing a `config` object as the second parameter when creating a `LocalStageStream`.

```js
const config = {
  inBandMessaging: {
    enabled: true,
  },
};
const vidStream = new LocalStageStream(videoTrack, config);
```

Now we can publish! Our little envelope of data has to be an [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer) between 0KB and 1KB and we can only send up to 10KB per second.

```js
const lilEnvelope = new TextEncoder().encode("💌").buffer;
vidStream.insertSeiMessage(lilEnvelope);
```

To repeat it, pass a config object as the second argument.

```js
vidStream.insertSeiMessage(lilEnvelope, { repeatCount: 5 });
```

But the SDK won't de-dupe for us, so add some logic to your little envelope so that you can identify dupes on the other side. I find a timestamp to be a good way to do this.

## Modifying the Emote App Demo

Here's the same emote demo from the last blog post, modified to use SEI to publish and subcribe to the emotes.

First, we get a stage token, devices and media streams.

```js
// get a token
const token = await getStageToken(stageArn);

// get mic/cam permissions
await navigator.mediaDevices.getUserMedia({ video: true, audio: true });

// list devices
const devices = await navigator.mediaDevices.enumerateDevices();
const videoDevices = devices.filter((d) => d.kind === "videoinput");
const audioDevices = devices.filter((d) => d.kind === "audioinput");

// get media stream from devices
const cameraStream = await navigator.mediaDevices.getUserMedia({
  video: { deviceId: videoDevices[0].deviceId, aspectRatio: 16 / 9 },
});
const microphoneStream = await navigator.mediaDevices.getUserMedia({
  audio: { deviceId: audioDevices[0].deviceId },
});
```

Next, we create a local audio and video stream, enabling SEI publishing for the participant.

```js
// localStageStream config
const config = {
  inBandMessaging: { enabled: true },
};

const localVideoStream = new LocalStageStream(cameraStream.getVideoTracks()[0], config);
const localAudioStream = new LocalStageStream(microphoneStream.getAudioTracks()[0]);
```

Create our strategy, enabling SEI subscriptions.

```js
const strategy = {
  // other functions removed for brevity
  subscribeConfiguration: (participant) => {
    return { inBandMessaging: { enabled: true } };
  },
};
const stage = new Stage(token, strategy);
```

Now we can listen for SEI messages, and render the proper emote when it's received. We store the processed message ID in an array to de-duplicate and only process the incoming message if we have not done so already.

```js
const msgsProcessed = [];

stage.on(StageEvents.STAGE_STREAM_SEI_MESSAGE_RECEIVED, (participant, seiMessage) => {
  const msgString = new TextDecoder().decode(seiMessage.payload);
  const message = JSON.parse(msgString);
  if (message.type === "emote" && msgsProcessed.indexOf(message.id) === -1) {
    console.log(msgString);
    renderEmote(message.emote);
    msgsProcessed.push(message.id);
  } else {
    console.log("skipping message, not an emote or already processed!");
  }
});
```

When the users click on the emote button in the front-end, we construct the message object and publish it. Note that we also render the emote on the publisher side, since participants do not receive their own published messages.

```js
const publishMessage = (message) => {
  const msgString = JSON.stringify(message);
  const payload = new TextEncoder().encode(msgString).buffer;
  localVideoStream.insertSeiMessage(payload, {
    repeatCount: 5, // can be between 0 and 30
  });
};

document.getElementById("emote-btns").addEventListener("click", (event) => {
  publishMessage({
    id: Date.now().toString(),
    type: "emote",
    emote: event.target.innerText,
  });
  renderEmote(event.target.innerText); // publisher doesn't recieve own messages
});
```

Here's what the new SEI modified emote app looks like when it's running:

{{< youtube _1sG3QCXfYM >}}

## Summary

In this post, we learned how to publish and subscribe to SEI messages with Amazon IVS real-time stages. In the next post, we'll see a more practical use case of SEI messages.
