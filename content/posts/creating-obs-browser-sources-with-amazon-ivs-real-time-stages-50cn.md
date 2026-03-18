---
title: "Creating OBS Browser Sources with Amazon IVS Real-Time Stages"
slug: "creating-obs-browser-sources-with-amazon-ivs-real-time-stages-50cn"
author: "Todd Sharp"
date: 2024-08-26T15:27:05Z
summary: "In this short series, we've looked at enhancing the broadcasting experience with Amazon Interactive..."
tags: ["aws", "amazonivs", "obs", "livestream"]
canonical_url: "https://dev.to/aws/creating-obs-browser-sources-with-amazon-ivs-real-time-stages-50cn"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-2hl8vt108jvfuout7fgd.png"
imagecontain: true
---

In this short series, we've looked at enhancing the broadcasting experience with Amazon Interactive Video Service (Amazon IVS) real-time stages and OBS. To wrap up the series, I wanted to share another quick tip that I use for broadcasting real-time participant streams that can help increase the reach of the stream. Sometimes, real-time latency is necessary for the participants who are broadcasting to a stage, but less important for the viewers of the stream. In these situations, [server-side composition](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/server-side-composition.html) is a fantastic option to automatically composite and broadcast to a low-latency channel. But what about those times where you want a little more control over the layout and scenes? As many streamers know, that's where OBS comes in and helps make life easier. So how can we combine an Amazon IVS real-time stream with OBS? For this we can use browser sources!

## Creating a Browser Source For Each Participant

Normally we use the [Amazon IVS Web Broadcast SDK](https://aws.github.io/amazon-ivs-web-broadcast/docs/real-time-sdk-guides/introduction) to subscribe to **every** participant in an Amazon IVS stage. With a little logic, we can subscribe to only a single participant by passing in the `participantId` to the view. To do this, I create a view in my application that accepts the `stageArn` and `participantId` via URL params. This looks like this:

```bash
http:://127.0.0.1:3333/browser-source?participantId=ab47e2d45999&stageArn=arn:aws:ivs:us-east-1:1234537890:stage/xxxxxxxxxxxx
```

Now, in my handler for the `StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED` event, I check the `id` on the incoming `participant`. If it's not the given `id`, I ignore it - otherwise, it gets rendered to the DOM.

```js
this.stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED, async (participant, streams) => {
  // we're only subscribing to a single participant
  if (participant.id !== this.participantId) return;
  // render to DOM...
});
```

In the web based participant view for the real-time stage, I overlay a button on each participant which lets me copy the individual participant's distinct browser source URL.

![Participant Browser Source URL button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-566uhkyfex8prilxrofq.png)

Next, in OBS, add a source of type `Browser`.

![Add browser source menu](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tvg996jzw83sm0qczmsl.png)

Paste in the browser source URL and click 'OK'.

![Add browser source dialog](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ti1ql3peyvq8vjab00uq.png)

We can use individual participant browser sources for each participant (including screen shares) and add background images or scene transitions to customize the streaming experience in OBS.

![OBS Layout](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nu88lesr0u1pzraglhp6.png)

While the web based real-time stage layout remains unique for all participants.

![Web based layout](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4lut755r7k3rjqo2gy9n.png)

Now we can broadcast the real-time stage to a low-latency channel to reach millions of viewers!

![Low latency playback](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gcztg00ptk5zl2xtke3i.png)

## Single Browser Source

The method discussed above works amazingly, but sometimes you'd rather not manage the individual participant layout in OBS. In those cases, I typically create a view that renders all participants, but without any of my application UI (like headers, menus, etc). This means that as participants come and go, the browser source will be automatically updated in the OBS scene. It also means I can provide backgrounds and scene transitions as necessary which isn't possible with server-side composition.

![Browser source all](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3ubv4n6preg8vcced0mm.png)

## Summary

In this post, we looked at creating OBS browser sources for Amazon IVS real-time streams to provide us some flexibility and improve the viewer experience. This wraps up this short series about working with OBS and Amazon IVS stages. I hope you've learned some new tricks, and if you have any tips of your own to share, please leave them in the comments below!
