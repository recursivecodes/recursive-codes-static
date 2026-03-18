---
title: "Creating Your First Live Stream Playback Experience with Amazon IVS"
slug: "creating-your-first-live-stream-playback-experience-with-amazon-ivs-56kl"
author: "Todd Sharp"
date: 2022-08-26T11:54:14Z
summary: "In our last post, we looked at how to get started with live streaming in the cloud with Amazon..."
tags: ["aws", "livestreaming", "cloud", "amazonivs"]
canonical_url: "https://dev.to/aws/creating-your-first-live-stream-playback-experience-with-amazon-ivs-56kl"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6eozv6u4w3791vreltbz.jpeg"
---

In our last post, we looked at how to get started with live streaming in the cloud with Amazon Interactive Video Service (Amazon IVS). It would be a good idea to read that post before continuing here if you're not yet familiar with creating a live streaming channel with Amazon IVS. Unless you already know how to create a channel. Either way, let's dig into how to get started with creating a live stream playback experience.

In this post, we’re going to focus on web playback for Amazon IVS. If you’re creating a mobile app, there are also SDKs available for both [Android](https://docs.aws.amazon.com/ivs/latest/userguide/player-android.html) and [iOS](https://docs.aws.amazon.com/ivs/latest/userguide/player-ios.html), but we’ll stick to the web in this post. If you get stuck, bookmark the “official” [docs for web playback], but we’ll walk through the entire process here in this post. Ready? Then let’s get at it!

## Before We Begin

We're going to need the **Playback URL** for our Amazon IVS Channel. There are a few ways to get this if you don't have it handy already. The first method is to login to the [Amazon IVS Management Console](https://console.aws.amazon.com/ivs) and navigate to the channel that you want to create a playback experience for. On the channel details page, scroll down to the **Playback configuration** panel and copy the **Playback URL**.

![Playback configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-oe2aakh6x853vedw43ql.png)

For this post, I’m going to use one of our [test streams](https://github.com/aws-samples/amazon-ivs-player-web-sample#test-streams) since that will let me demo live playback right here in the blog post. When you create your own playback experience, use the **Playback URL** for the channel that you create. The URL that I’ll use for playback in this post is:

`https://3d26876b73d7.us-west-2.playback.live-video.net/api/video/v1/us-west-2.913157848533.channel.rkCBS9iD1eyd.m3u8`

If we paste that URL (or your own playback URL) into our browser and navigate to it, our browser will probably download a file to our desktop. We should probably take a quick detour to explain what this file is all about!

## ELI5: HLS

If we open the `.m3u8` file in a text editor, it will look something like this (truncated for brevity):

```bash
#EXTM3U
#EXT-X-SESSION-DATA:DATA-ID="NODE",VALUE="video-edge-82bfe8.ord02"
#EXT-X-SESSION-DATA:DATA-ID="MANIFEST-NODE-TYPE",VALUE="weaver_cluster"
#EXT-X-SESSION-DATA:DATA-ID="MANIFEST-NODE",VALUE="video-weaver.ord02"
#EXT-X-SESSION-DATA:DATA-ID="SUPPRESS",VALUE="true"
#EXT-X-SESSION-DATA:DATA-ID="SERVER-TIME",VALUE="1659448883.23"
#EXT-X-SESSION-DATA:DATA-ID="TRANSCODESTACK",VALUE="2017TranscodeQS_V2"
#EXT-X-SESSION-DATA:DATA-ID="USER-IP",VALUE="[redcated]"
#EXT-X-SESSION-DATA:DATA-ID="SERVING-ID",VALUE="21f1214cd2604a4cb3b47701256d515a"
#EXT-X-SESSION-DATA:DATA-ID="CLUSTER",VALUE="ord02"
#EXT-X-SESSION-DATA:DATA-ID="ABS",VALUE="false"
#EXT-X-SESSION-DATA:DATA-ID="VIDEO-SESSION-ID",VALUE="5506365207855764860"
#EXT-X-SESSION-DATA:DATA-ID="BROADCAST-ID",VALUE="46909101677"
#EXT-X-SESSION-DATA:DATA-ID="STREAM-TIME",VALUE="81635.231166"
#EXT-X-SESSION-DATA:DATA-ID="FUTURE",VALUE="true"
#EXT-X-SESSION-DATA:DATA-ID="MANIFEST-CLUSTER",VALUE="ord02"
#EXT-X-SESSION-DATA:DATA-ID="ORIGIN",VALUE="cmh01"
...
```

Seems kinda weird, right? The reason for this is that the `.m3u8` file is actually a **playlist** (or “**manifest**”) file. Amazon IVS uses the [HTTP Live Streaming](https://en.wikipedia.org/wiki/HTTP_Live_Streaming) (HLS) protocol to deliver your live streams, and this file contains all the information that the player needs to locate and play your stream. With a **Standard** Amazon IVS channel, the HLS manifest will contain the location of 5 different versions of the stream:

- 1080p
- 720p
- 480p
- 360p
- 160p

This allows the player to choose the best stream based on the viewer’s current network status (or, depending on the player, allows the viewer to choose a different resolution to save on bandwidth). Since we’ve got the manifest downloaded, let’s try opening it with a video player on our desktop. I’ve opened this manifest with VLC, and the first thing I’m presented with is a playlist that VLC identified via the manifest.

![VLC playlist for HLS manifest](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3ctkbruzzirb7c49hqee.png)
 
If we select the first item in the playlist, VLC will begin playback on the live stream. 

![VLC playing a live stream](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-eqe55r97h5ttltg26yzx.png)
 
If we view the codec details in VLC (via CTRL+i or CMD+i), we'll see that the stream that we chose has a resolution of `1920x1080`, so this is the 1080p stream for this channel.

![Stream codec details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-p6qfric0bmvm4bk4nrza.png)

We can check the resolution via the same process for all the other items in the playlist. 

>Note that the video file location that is contained in the HLS manifest only represents a short portion of the live stream. In reality, the player will download and regularly update the manifest with the latest files in the stream. It's a pretty cool system for delivering live video!
 
## Using the Amazon IVS Player

So now that we understand what HLS is and how it works, let's create a web player and playback a stream! We'll use the "official" Amazon IVS player in this example, but it's useful to know that there are additional options for web playback (such as integrations for [Video.js](https://docs.aws.amazon.com/ivs/latest/userguide/player-videojs.html) and [JW Player](https://docs.aws.amazon.com/ivs/latest/userguide/player-jwplayer.html)). 

### The Amazon IVS Player Script

The first step here is to include the web player script. The recommended way to include this script is to use the Amazon IVS CDN. We’ll use the latest version of the player as of the published date for this blog post (version `1.11.0`).

```html
<script src="https://player.live-video.net/1.11.0/amazon-ivs-player.min.js">
``` 

>You don't **have** to use the CDN. There are options to import the SDK from NPM, but since the player uses WebAssembly, there are some [considerations that you should know](https://github.com/aws-samples/amazon-ivs-player-web-sample#how-to-import-the-sdk-from-npm).

### The HTML Markup

The Amazon IVS player works directly with the native HTML `<video>` tag, so we'll need to include one.  We can use any of the standard attributes for the tag as shown below.

```html
<video id="video-player" controls autoplay playsinline />
```

### Styling with CSS

Since we're using the native `<video>` tag, we can style it via CSS. Let's have our demo player fill the entire body via the following CSS:

```css
video {
    height: 100%;
    width: 100%;
    left: 0;
    top: 0;
    position: fixed;
}
```

### Initialize the Player and Start the Stream

The only thing left is to create an instance of the player, attach it to our HTML `<video>` element, load the stream, and play it. We'll handle all of those tasks in an `init()` function, triggered when the `DOMContentLoaded` event is fired.

```js
const init = () => {
  if(!IVSPlayer.isPlayerSupported) {
    alert('Your browser does not support the IVS video player. Please try a different browser.')
  }
  const videoEl = document.getElementById('video-player');
  const streamUrl = 'https://3d26876b73d7.us-west-2.playback.live-video.net/api/video/v1/us-west-2.913157848533.channel.rkCBS9iD1eyd.m3u8';

  const ivsPlayer = IVSPlayer.create();
  ivsPlayer.attachHTMLVideoElement(videoEl);
  ivsPlayer.load(streamUrl);
  ivsPlayer.play();
}

document.addEventListener('DOMContentLoaded', init);
```

## Live Playback!

Our stream is ready for playback! 

{% codepen https://codepen.io/recursivecodes/pen/mdxXpWp %}

>If your player isn't working, check out the code in the CodePen above, or leave a comment below!

## Summary

In this post, we learned about the HTTP Live Streaming (HLS) protocol, and created our first instance of the Amazon IVS player for playback of our Amazon IVS live stream. In our next post, we'll look at some of the various methods and events that the Amazon IVS player exposes and how we can use those to enhance the user experience. If you have questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by [Antonio Cansino](https://pixabay.com/users/antonio_cansino-6477209/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=5069314) from [Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=5069314)