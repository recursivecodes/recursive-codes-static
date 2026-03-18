---
title: "Adding Closed Captions to an Amazon IVS Live Stream"
slug: "adding-closed-captions-to-an-amazon-ivs-live-stream-3480"
author: "Todd Sharp"
date: 2023-04-14T12:11:18Z
summary: "There are two types of people in this world: those who watch TV shows with captions on, and those who..."
tags: ["aws", "amazonivs", "a11y", "livestreaming"]
canonical_url: "https://dev.to/aws/adding-closed-captions-to-an-amazon-ivs-live-stream-3480"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nfuqhfbj3f2tnm12m5hx.jpeg"
---

There are two types of people in this world: those who watch TV shows with captions on, and those who are weird. All joking aside, the importance of closed captions for video cannot be understated. In addition to being crucial for the deaf and hard-of-hearing, captions also are important when audio is unavailable or not clearly audible. Maybe you're watching a video in a public place and the audio is drowned out by ambient noise. Or maybe the person speaking in the video is using a microphone that isn't the best quality, or speaks with an accent or dialect that is unfamiliar to the viewer. Captions are **always** a good thing. Unfortunately, captioning audio in a live stream is tricky. 

Before we dig into the problem of captioning live streams, let's talk about semantics a bit. Did you know that there is a difference between the terms **closed caption** and **subtitle**? The [HTML spec](https://html.spec.whatwg.org/multipage/media.html#attr-track-kind-keyword-subtitles) describes **subtitles** as:

>transcription or translation of the dialogue, suitable for when the sound is available but not understood (e.g. because the user does not understand the language of the media resource's audio track). Overlaid on the video. 

The spec describes **captions** as: 

>Transcription or translation of the dialogue, sound effects, relevant musical cues, and other relevant audio information, suitable for when sound is unavailable or not clearly audible (e.g. because it is muted, drowned-out by ambient noise, or because the user is deaf). Overlaid on the video; labeled as appropriate for the hard-of-hearing.

This means that when we talk about "closed captions" for live videos, we're usually referring to **subtitles** since **captions** usually include descriptive information. Think about a scene in a TV show where an actor gets in the car to leave home and says goodbye to their spouse. The caption for this scene might read "Goodbye, dear. [car engine starts]." We're not close to having AI systems describe contextual information like this for us, so we're limited to adding pure "speech-to-text" subtitles captions to our live stream; we can do that using the method below.

> **Note:** You’ll notice that the title and body of this blog post uses the terms ‘captions’ or ‘closed captions’ even though what we’re really talking about here are subtitles based on the definitions above. Unfortunately, since the term ‘closed captions’ is so commonly misused, it makes the most sense to use this term improperly to help developers find this blog post and learn how to add this feature to their live streams. Just know that what we’re really talking about here are subtitles!

## Adding Captions to Amazon IVS Live Streams

The solution that we look at in this post focuses on broadcasting to an Amazon Interactive Video Service (Amazon IVS) live stream from [OBS Studio](https://obsproject.com/). OBS doesn't offer native support for captioning, but there are several plugins that can perform the necessary speech-to-text conversion and publish the captions to an RTMP stream in the [CEA-708/EIA-608 format supported by Amazon IVS](https://docs.aws.amazon.com/ivs/latest/userguide/streaming-config.html#streaming-config-captioning). For this demo, I've chosen to use the `OBS-captions-plugin` by ratwithacompiler ([GitHub](https://github.com/ratwithacompiler/OBS-captions-plugin) and [plugin page](https://obsproject.com/forum/resources/closed-captioning-via-google-speech-recognition.833/)). To get started with this plugin, [download it](https://github.com/ratwithacompiler/OBS-captions-plugin/releases) and [install it](https://obsproject.com/kb/plugins-guide). Once you've got it installed in OBS, select **Docks** and make sure the **Captions** dock is enabled.

![OBS docks menu](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-kyye4r8r5ptqle0sui50.png)

Next, select the 'gear' icon in the **Captions** dock to modify the settings.

![captions dock](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-1k465l5bqrprtq72lkf1.png)

Make sure that a **Caption Source** is selected, and modify the plugin configuration to suit your needs. For example, the default **Caption Timeout** for me was set to `15.0` seconds, but I found `5.0` seconds to be a better value.

![caption plugin configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-lid05ve9kl0x59rwqjqr.png)

Once you've saved your configuration and started a new live stream, the plugin handles converting your speech to text and produce the required caption information to the live stream.

To play back the caption data with the Amazon IVS player, we can add an event listener to listen for the `TextCue` event ([docs](https://aws.github.io/amazon-ivs-player-docs/1.17.0/web/interfaces/textcue.html)).

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerEventType.TEXT_CUE, (evt) => {
  console.log(evt);
}
```

The handler as configured above logs all incoming `TextCue` events to the console.

![text cue events logged to console](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-qdxj7bg4nw5rhej8ap9e.png)

The `text` property of the `TextCue` event contains the caption data.

![text cue event details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-j7ie2otreyx9925y3vw3.png)

With some HTML and CSS, we can render the caption data as an overlay on the `<video>` element. This implementation is highly dependent on your needs, but you should take into account auto-hiding the overlay after a specified period of no caption data.

{{< youtube spFpCIqGSm8 >}}

## Summary

In this post, we looked at how to use an OBS plugin to convert speech to text and publish that text as caption data on an Amazon IVS live stream. 
