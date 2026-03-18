---
title: "Live Streaming With Multiple Hosts via a Browser With Amazon IVS"
slug: "live-streaming-with-multiple-hosts-via-a-browser-with-amazon-ivs-c8l"
author: "Todd Sharp"
date: 2023-05-08T13:10:57Z
summary: "In our last post, we learned how to create a virtual \"stage\" to create a real-time video chat..."
tags: ["aws", "amazonivs", "livestreaming", "javascript"]
canonical_url: "https://dev.to/aws/live-streaming-with-multiple-hosts-via-a-browser-with-amazon-ivs-c8l"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-a499oozzcyc4la12kkuz.jpeg"
---

In our [last post](https://dev.to/aws/creating-a-real-time-multi-host-video-chat-in-a-browser-with-amazon-ivs-m44), we learned how to create a virtual "stage" to create a real-time video chat experience for up to 12 participants with Amazon Interactive Video Service (Amazon IVS). As a standalone feature, that's pretty powerful and enables us to add real-time collaboration to our applications. However, this feature was created to empower developers to easily create collaborative live streaming experiences similar to the "Guest Star" feature on Twitch. In this post, we'll build on the previous demo to combine the audio and video feeds from all participants into a single feed and broadcast that feed to an Amazon IVS channel.

If you haven't yet read the previous post, you should do that before moving forward with this post. To recap, in that post we learned how to:

* Create a stage resource with the AWS SDK for JavaScript (v3)
* Create a stage participant tokens with the AWS SDK for JavaScript (v3)
* Use the Web Broadcast SDK to connect to the virtual stage for real-time video chat between participants

The next step to creating a collaborative live streaming experience is to combine (or "composite") both the local and remote participants into a single stream that can be published to an Amazon IVS channel. For this we can also use the Web Broadcast SDK, so let's see how it's done.

## Creating a Broadcast Client

If you recall, in the last post we had several functions called inside of a `DOMContentLoaded` handler that enabled permissions, obtained devices, configured the `Stage` instance, and handled joining the stage. We'll add one more method to this flow called `initBroadcastClient()` which we can use to create an instance of the `IVSBroadcastClient`. We'll need a `<canvas>` element in our markup for the combined stream so that our participants can preview what will ultimately be broadcast to the Amazon IVS channel.

```js
const initBroadcastClient = async () => {
  broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.STANDARD_LANDSCAPE,
    ingestEndpoint: '[YOUR INGEST ENDPOINT]',
  });

  const previewEl = document.getElementById('broadcast-preview');
  broadcastClient.attachPreview(previewEl);

  const bgImage = new Image();
  bgImage.src = '/images/stage_bg.png';
  broadcastClient.addImageSource(bgImage, 'bg-image', { index: 0 });
};
```

To make things a little more visually appealing, I've used `addImageSource()` to add a background image to the stream. The `addImageSource()` method receives three arguments: the image, a unique name for the source, and a `VideoComposition` object that is used to define the `index` (or 'layer') for the source. If you check the [docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/interfaces/VideoComposition) for `VideoComposition`, you'll also note that it can contain values for the `height`, `width`, `x`, and `y` position for the source. We'll take advantage of those properties in just a bit when we add our video layers for each participant.

### Adding Participant Audio and Video to the Broadcast Client

Next, we're going to add the audio and video for each participant to the broadcast client. We'll do this inside of the `StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED` handler that we defined in the previous post. Modify that function to add calls to two new functions.

```js
stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED, (participant, streams) => {
  renderParticipant(participant, streams);
  renderVideosToClient(participant, streams.find(s => s.streamType === StreamType.VIDEO));
  renderAudioToClient(participant, streams.find(s => s.streamType === StreamType.AUDIO));
});
```

Now let's create the `renderVideosToClient()` function. Here, I'm hardcoding the `VideoComposition` to values appropriate for a single participant. In your application, you'll want to dynamically calculate the `height`, `width`, `x`, and `y` values depending on the amount of users currently participating in the conversation.

```js
const renderVideosToClient = async (participant, stream) => {
  const participantId = participant.id;
  const videoId = `video-${participantId}`;
  const composition = { 
    index: 1,
    height: 984, 
    width: 1750, 
    x: 85, 
    y: 48 
  };
  const mediaStream = new MediaStream();
  mediaStream.addTrack(stream.mediaStreamTrack);
  broadcastClient.addVideoInputDevice(mediaStream, videoId, composition);
};
```

The `renderAudioToClient()` function looks similar, but uses the `addAudioInputDevice()` method of the SDK to add the audio track.

```js
const renderAudioToClient = async (participant, stream) => {
  const participantId = participant.id;
  const audioTrackId = `audio-${participantId}`;
  const mediaStream = new MediaStream();
  mediaStream.addTrack(stream.mediaStreamTrack);
  broadcastClient.addAudioInputDevice(mediaStream, audioTrackId)
};
```

At this point, the stage is ready to be broadcast to a channel by calling `broadcastClient.startBroadcast('[YOUR STREAM KEY]')`. We'll also need to handle removing participants from the `broadcastClient` when they leave a stage. For this, update the handler for `StageEvents.STAGE_PARTICIPANT_STREAMS_REMOVED`.

```js
stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_REMOVED, (participant, streams) => {
  const videoTrackId = `video-${participant.id}`;
  const audioTrackId = `audio-${participant.id}`;
  if (broadcastClient.getVideoInputDevice(videoTrackId)) broadcastClient.removeVideoInputDevice(videoTrackId);
  if (broadcastClient.getAudioInputDevice(audioTrackId)) broadcastClient.removeAudioInputDevice(audioTrackId);
  const videoId = `${participant.id}-video`
  document.getElementById(videoId).closest('.participant-col').remove();
  updateVideoCompositions(); // function not defined in demo, implementation will vary
});
```

Here's how an implementation might look with a single participant. Note that each stage participant would be shown on the bottom screen, and the composite view to be broadcast is shown above.

![Broadcast Stage with Single Participant](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-vr7a1pvocyydxcak3x6c.png)

And when multiple participants have joined the virtual stage, the application adjusts the layout to accommodate each participant.

![Broadcast Stage with Multiple Participants](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-k7fbdi0of1ysro1t1zev.png)

When the 'host' participant clicks the 'Broadcast' button, the combined conversation will be broadcast to the Amazon IVS channel as a composite view with all participants audio and video combined into a single stream.


![Composite stream broadcast to Amazon IVS](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4gpm2qil0xhu8s9wdjja.png)

## Summary

In this post, we learned how to create a live stream broadcast with the audio and video from multiple remote participants. In a future post, we'll examine alternative options for creating the composite stream and broadcasting it to an Amazon IVS channel.