---
title: "Creating and Broadcasting a \"LoFi Radio\" Station with Amazon IVS"
slug: "creating-and-broadcasting-a-lofi-radio-station-with-amazon-ivs-4nk1"
author: "Todd Sharp"
date: 2023-02-03T13:27:46Z
summary: "This post might not fall into the \"normal\" ways that you'd use live streaming with Amazon Interactive..."
tags: ["aws", "amazonivs", "streaming", "javascript"]
canonical_url: "https://dev.to/aws/creating-and-broadcasting-a-lofi-radio-station-with-amazon-ivs-4nk1"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zeu4rkebm7cjavlv5pdo.png"
---

This post might not fall into the "normal" ways that you'd use live streaming with Amazon Interactive Video Service (Amazon IVS), but it's a fun project to play around and learn with and it illustrates some unique features of the Web Broadcast SDK (notably the ability to stream from a source other than a traditional camera and microphone). 

You may be familiar with the concept of "lofi radio" channels, but if not, they usually consist of some sort of animated character in a mostly static scene with a looped audio track containing lofi music. These live streams are popular among people looking for a non-distracting soundtrack to relax, study, or chat and make new friends. It doesn't fit the "traditional" user generated content (UGC) model of a broadcaster streaming a game or their webcam, but there is no arguing that these streams are hugely popular. For example, as of the time of publishing this article, the [Lofi Girl](https://www.youtube.com/@LofiGirl/about) channel on YouTube currently has 11.7 million subscribers and boasts nearly 1.5 **billion** total views. 

Maybe it's time that someone built an entire live streaming UGC platform that gives users the ability to create their own custom lofi channels and broadcast them to their friends? That's a free idea - run with it!

I'm going to assume that you're new to Amazon IVS, so we'll walk through the process of creating your own lofi live stream from the beginning. If you're already familiar with Amazon IVS, feel free to jump past the parts that you're already comfortable with.

## Sign Up for a Free AWS Account

Step one is to [sign up for a free AWS account](https://aws.amazon.com/ivs/pricing/). New accounts will be eligible for 5 hours of basic input, 100 hours of SD output, and a generous amount of monthly chat messages for the first 12 months. This should be plenty of time to play around with Amazon IVS and learn all about how it works.

## Creating an Amazon IVS Channel

I've blogged about how to [get started creating an Amazon IVS channel](https://dev.to/aws/get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg), but the quickest way to create a one-off channel is via the AWS CLI ([install docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)). The command to create a channel is:

```bash
$ aws ivs create-channel --name lofi-demo --latency-mode LOW --type BASIC
```

This will return some important information about your stream:

```json
{
  "channel": {
    "arn": "arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]",
    "authorized": false,
    "ingestEndpoint": "f99084460c35.global-contribute.live-video.net",
    "latencyMode": "LOW",
    "name": "lofi-demo",
    "playbackUrl": "https://f99084460c35.us-east-1.playback.live-video.net/api/video/v1/us-east-1.[redacted].channel.[redacted].m3u8",
    "recordingConfigurationArn": "",
    "tags": {},
    "type": "BASIC"
  },
  "streamKey": {
    "arn": "arn:aws:ivs:us-east-1:[redacted]:stream-key/[redacted]",
    "channelArn": "arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]",
    "tags": {},
    "value": "sk_us-east-1[redacted]"
  }
}
```

Keep this info handy, as we'll need the **ingestEndpoint**, **playbackUrl**, and **streamKey** in just a bit.

## Broadcasting to the Lofi Channel with the Web Broadcast SDK

Now that we have a channel created, we can immediately start broadcasting to it. If you've done any live streaming, you're probably familiar with desktop streaming software (like OBS, Streamlabs Desktop, etc). Instead of using third-party software, we're going to write some code to broadcast our lofi stream directly from a browser. 

> **Before We Code**: You should have your own animation handy and an MP3 track. **Copyright is a thing** - please only utilize assets that you have obtained the proper licensing to use. If your animation is a GIF, you'll want to convert it to an MP4 file (there are plenty of tools available online for this). 

The first step is to create an HTML page that includes the Web Broadcast SDK script, and contains a `<canvas>` element for the broadcast preview, a `<video>` element for the source animation, and a button to start the broadcast. The `src` of the `<video>` tag should point to your animation source and should have a width and height of `1px` (we're going to preview the video on the `<canvas>` in just a bit, so no need for the source video to be visible).

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lofi Radio</title>
  <script src="https://web-broadcast.live-video.net/1.2.0/amazon-ivs-web-broadcast.js"></script>
</head>
<body>

  <canvas id="broadcast-preview"></canvas>

  <video id="src-video" 
    src="/video/lofi.mp4" 
    style="width: 1px; height: 1px;"
    muted loop></video>

  <button id="broadcast-btn">Broadcast</button>

</body>
</html>
```

Next, create an external JS file called `lofi.js` (don't forget to include it in your HTML above). Start off this file with a `DOMContentLoaded` listener and define an `init()` function to get things set up. In the `init()` function, we'll create an instance of the `IVSBroadcastClient` from the Web Broadcast SDK. We'll need to pass it the `ingestEndpoint` from our channel. We'll also create a click handler for the broadcast button that will call a `toggleBroadcast()` function that we'll define in just a bit.

```js
const init = () => {
  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.BASIC_FULL_HD_LANDSCAPE,
    ingestEndpoint: [Your ingestEndpoint],
  });
  document.getElementById('broadcast-btn').addEventListener('click', toggleBroadcast);
};
document.addEventListener('DOMContentLoaded', init);
```

> **Note:** To keep things simple, we're setting the `broadcastClient` into the window scope. In reality, you'll probably be using a framework so you'll usually avoid using the global `window` scope like this.

Next, we need to create our video stream and attach it to the `broadcastClient`. Modify the `init()` function as follows:

```js
const init = () => {
  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.BASIC_FULL_HD_LANDSCAPE,
    ingestEndpoint: [Your ingestEndpoint],
  });

  window.video = document.getElementById('src-video');
  window.broadcastClient.addImageSource(window.video, 'video-track', { index: 0 });
  const preview = document.getElementById('broadcast-preview');
  window.broadcastClient.attachPreview(preview);

  document.getElementById('broadcast-btn').addEventListener('click', toggleBroadcast);
};
```
At this point, we've got our animation source created and added to the client. Next, let's add a `createAudioStream()` function that will attach the MP3 audio source to the stream.

```js
const createAudioStream = async () => {
  /* Music from Uppbeat (free for Creators!): https://uppbeat.io/t/vens-adams/alone-in-kyoto */
  const audioContext = new AudioContext();
  const mp3 = await fetch('/audio/alone-in-kyoto.mp3');
  const mp3Buffer = await mp3.arrayBuffer();
  const audioBuffer = await audioContext.decodeAudioData(mp3Buffer);
  const streamDestination = audioContext.createMediaStreamDestination();
  const bufferSource = audioContext.createBufferSource();
  bufferSource.buffer = audioBuffer;
  bufferSource.start(0);
  bufferSource.connect(streamDestination);
  bufferSource.loop = true; 
  window.broadcastClient.addAudioInputDevice(streamDestination.stream, 'audio-track');
};
```
And modify the `init()` function to add `async` and call `await createAudioStream()`.

```js
const init = async () => {
  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.BASIC_FULL_HD_LANDSCAPE,
    ingestEndpoint: [Your ingestEndpoint],
  });

  window.video = document.getElementById('src-video');
  window.broadcastClient.addImageSource(window.video, 'video-track', { index: 0 });
  const preview = document.getElementById('broadcast-preview');
  window.broadcastClient.attachPreview(preview);

  await createAudioStream();

  document.getElementById('broadcast-btn').addEventListener('click', toggleBroadcast);
};
```

Finally, we can define the `toggleBroadcast()` function to start/stop the stream when the button is clicked. 

> **Note**: you'll need to plug in your **streamKey** at this point. Treat this like any other sensitive credential and protect it from being committed to source control or included in a file that can be accessed by others.

```js
const toggleBroadcast = () => {
  if (!window.isBroadcasting) {
    window.video.play();
    window.broadcastClient
      .startBroadcast([your streamKey])
      .then(() => {
        window.isBroadcasting = true;
      })
      .catch((error) => {
        window.isBroadcasting = false;
        console.error(error);
      });
  }
  else {
    window.broadcastClient.stopBroadcast();
    window.video.pause();
    window.isBroadcasting = false;
  }
};
```
Now we can save and run the application. Here's how my page looks (with a bit of CSS applied for styling and layout).

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-czgt44v6ack5hnw6wmb6.png)

When I click the **Broadcast** button, the animation begins to play and our live stream is broadcast to our channel. 

> **Note**: You will not be able to hear the channel audio from the broadcast tool. We'll look at playback in just a bit.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wxv2wiwapbac215m9mc4.gif)

## Playing Back the Lofi Channel

I've blogged about [live stream playback](https://dev.to/aws/creating-your-first-live-stream-playback-experience-with-amazon-ivs-56kl) with Amazon IVS before, but we'll create a quick and simple player here to complete the demo. Create an HTML file, include the Amazon IVS player SDK, add a `<video>` element, create an instance of the player (plug in your **playbackUrl**), and initialize playback.

```html
<!doctype html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lofi Radio Playback</title>
  <script src="https://player.live-video.net/1.14.0/amazon-ivs-player.min.js"></script>
  <script>
    document.addEventListener('DOMContentLoaded', () => {
      const ivsPlayer = IVSPlayer.create();
      ivsPlayer.attachHTMLVideoElement(document.getElementById('video-player'));
      ivsPlayer.load([your playbackUrl]);
      ivsPlayer.play();
    })
  </script>
</head>

<body>
  <video id="video-player" controls autoplay playsinline></video>
</body>

</html>
```
And now we can playback our lofi radio stream in it's own page!

{{< youtube 8FyM7K24jDQ >}}
The nice thing about our code is that both the audio and animation will continue on a loop until your channel stops broadcasting.

## Bonus: Broadcasting Without a Browser

Another option for broadcasting your own lofi stream is to avoid having any user interface and broadcast in headless mode with FFMPEG (more about that [here](https://dev.to/aws/broadcasting-to-an-amazon-ivs-live-stream-in-headless-mode-with-ffmpeg-2i73)). Here's an example command that would work for this channel.

```bash
$ ffmpeg \
    -re \
    -stream_loop -1 \
    -i ./public/video/lofi.mp4 \
    -stream_loop -1 \
    -i ./public/audio/alone-in-kyoto.mp3 \
    -map 0:v:0 \
    -map 1:a:0 \
    -c:v libx264 \
    -b:v 6000K \
    -maxrate 6000K \
    -pix_fmt yuv420p \
    -s 1920x1080 \
    -profile:v main \
    -preset veryfast \
    -force_key_frames "expr:gte(t,n_forced*2)" \
    -x264opts "nal-hrd=cbr:no-scenecut" \
    -acodec aac \
    -ab 160k \
    -ar 44100 \
    -f flv \
    $DEMO_STREAM_INGEST_ENDPOINT/$DEMO_STREAM_KEY
```

## Summary

In this post, we learned how to create our own lofi radio live stream with Amazon IVS. To make your own lofi stream even more interactive, add [live chat](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) with both [automated](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p) and [manual](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646) chat moderation. If you have any questions about this demo, please leave a comment below.

## Shameless Plug

To learn more about Amazon IVS, tune in to Streaming on Streaming on the [AWS Twitch](https://twitch.tv/aws) channel every Wednesday at 4pm ET.


