---
title: "Live Streaming Pre-Recorded Videos with the Amazon IVS Web Broadcast SDK"
slug: "live-streaming-pre-recorded-videos-with-the-amazon-ivs-web-broadcast-sdk-1j7m"
author: "Todd Sharp"
date: 2023-03-03T12:43:55Z
summary: "There are several options for broadcasting a live stream to an Amazon Interactive Video Service..."
tags: ["aws", "amazonivs", "livestreaming", "vod"]
canonical_url: "https://dev.to/aws/live-streaming-pre-recorded-videos-with-the-amazon-ivs-web-broadcast-sdk-1j7m"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-htvvellu6avq2ebb95tl.jpeg"
---

There are several options for broadcasting a live stream to an Amazon Interactive Video Service (Amazon IVS) channel. You (and your users) can choose one of the many third-party software options like OBS, Streamlabs Desktop, Lightstream, etc. You can also create a mobile experience with one of our [native broadcast SDKs for iOS or Android](https://docs.aws.amazon.com/ivs/latest/userguide/broadcast.html). Another option for broadcasting is the [Web Broadcast SDK](https://aws.github.io/amazon-ivs-web-broadcast/) which enables developers to create a dynamic, high-quality live stream broadcast experience directly in the browser. With the Web Broadcast SDK, you can provide streamers a custom interface to broadcast their webcam, microphone, and even share their desktop to an Amazon IVS channel. 

Sometimes streamers want the ability to include pre-recorded content in a live stream. Maybe they want to remind viewers of a highlight from a previous stream. Or, maybe they want to include their live reactions to a clip while it plays. Whatever the reason, it's easy to add pre-recorded video on demand (VOD) content to a live stream with the Web Broadcast SDK. Let's take a look.

## Adding VOD Content to a Live Stream

I won't go over the basics of creating a broadcast with the Web Broadcast SDK in this post since I've already covered it in a [previous post](https://dev.to/aws/broadcasting-to-your-amazon-ivs-live-stream-from-a-browser-2343) on this blog. Instead, we'll focus on adding a pre-recorded video. To get started, we'll add a `<video>` tag on the page that our broadcaster can use to play the VOD. 

```html
<video id="vod-0" src="/video/vod-0.mp4" controls></video>
```

In my demo app, I have included a few pieces of VOD content and an icon to allow the broadcaster to toggle back to 'camera only' mode.

![Broadcast interface with layout toggle icons](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-n87za6vkdgo7ynxij06a.png)

Your application might even include an upload feature to allow users to upload their own videos. Now that the `<video>` assets are included in the front end, let's configure the page to broadcast this VOD to the live stream when it is played.

One approach is to automatically stream the VOD when the video is played by listening for the `play` event.

```js
const vod0 = document.getElementById('vod-0');
vod0.addEventListener('play', async (evt) => { 

};
```

Within the `play` listener, we'll remove the user's webcam and microphone, and add the VOD (and the VOD audio) to the broadcast. The VOD is added via the `addImageSource` method on the `AmazonIVSBroadcastClient ` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient#addimagesource)) by passing the `evt.target` received in the event handler (the `<video>` element). The method name (`addImageSource`) might lead you to believe that only images can be added, but the docs clarify that the acceptable type for the source can be one of: `HTMLImageElement`, `HTMLVideoElement`, `HTMLCanvasElement`, or `ImageBitmap`. 

```js
vod0.addEventListener('play', async (evt) => { 
  /// remove webcam
  const cameraExists = client.getVideoInputDevice('camera-0');
  if (cameraExists) await client.removeVideoInputDevice('camera-0');

  // remove user microphone
  const micExists = window.broadcastClient.getAudioInputDevice('mic-0');
  if (micExists) await window.broadcastClient.removeAudioInputDevice('mic-0');

  // add VOD to broadcast
  window.broadcastClient.addImageSource(
    evt.target, 
    'vod-0', 
    { index: 0 }
  );

  // add audio from VOD
  window.broadcastClient.addAudioInputDevice(
    vod0.captureStream(), 
    'vod-0-audio'
  );
};
```

Now, when the video is played, it will be exclusively streamed to the viewers on that channel without webcam or microphone inputs.

![VOD live streaming](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-pin8i3l15wak5ocubg8b.png)

We can listen for the `paused` event on the video to reset the webcam and microphone view so that broadcasters can pause to discuss a portion of the VOD. We can also listen for the `ended` event to reset the view when the VOD is finished playing.

## Adding a VOD with WebCam Overlay

Adding an inline VOD that plays exclusively is a great feature, but sometimes broadcasters want to "react" during VOD content and include their webcam as an overlay to the pre-recorded content. Here we add the VOD as we did above, but also add a webcam stream on top of it by passing additional configuration properties (`height`, `width`, `x`, `y`) in the third argument to `addVideoInputDevice()`.

```js
vod1.addEventListener('play', async (evt) => {
  // remove webcams, VODs, desktop, etc...
  // [custom code here]

  // add VOD to broadcast (layer 0)
  window.broadcastClient.addImageSource(
    evt.target, 
    'vod-1', 
    { index: 0 }
  );

  // add camera as PIP
  const streamConfig = IVSBroadcastClient.STANDARD_LANDSCAPE;
  // get a webcam stream (getUserMedia())
  const videoStream = await getVideoStream(); 
  // add the webcam (layer 1 - on top of VOD)
  const preview = document.getElementById('broadcast-preview');
  window.broadcastClient.addVideoInputDevice(
    videoStream, 
    'pip-camera-0', 
    {
      index: 1,
      height: streamConfig.maxResolution.height * .25,
      width: streamConfig.maxResolution.width * .25,
      x: preview.width - preview.width / 4 - 20,
      y: preview.height - preview.height / 4 - 20
    }
  );

  // add audio from VOD
  window.broadcastClient.addAudioInputDevice(
    vod1.captureStream(), 
    'vod-0-audio'
  );
});
```

This gives us a nice picture-in-picture style interface.

![Picture in picture VOD](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gs6teuwm7gpg73xm8m5k.png)

The broadcaster audio can be included so they can react/discuss the video. Again, you can utilize the `pause` and `ended` events as appropriate to handle state changes in your application.

## Summary 

In this post, we learned how to include pre-recorded VOD content in our Amazon IVS live streams with the Web Broadcast SDK. If you'd like to see the complete code behind this example, you can check it out [here](https://gist.github.com/recursivecodes/85e7073dd1438e572d82bc1b44d5f331). If you have any questions or suggestions for future posts that you'd like to see about Amazon IVS, please leave a comment below.


