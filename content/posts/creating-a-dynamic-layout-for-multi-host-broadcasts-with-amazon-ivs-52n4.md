---
title: "Creating a Dynamic Layout for Multi Host Broadcasts with Amazon IVS"
slug: "creating-a-dynamic-layout-for-multi-host-broadcasts-with-amazon-ivs-52n4"
author: "Todd Sharp"
date: 2023-05-19T14:27:50Z
summary: "I've written a few posts lately about multi host live streams with Amazon Interactive Video Service..."
tags: ["aws", "amazonivs", "javascript", "livestreaming"]
canonical_url: "https://dev.to/aws/creating-a-dynamic-layout-for-multi-host-broadcasts-with-amazon-ivs-52n4"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dhn42kf99a4ugbh3jmcu.jpeg"
---

I've written a few posts lately about multi host live streams with Amazon Interactive Video Service (Amazon IVS). It's an exciting feature that opens up worlds of possibilities that simply weren't available until recently. We first looked at how to [create a multi host live chat application](https://dev.to/aws/creating-a-real-time-multi-host-video-chat-in-a-browser-with-amazon-ivs-m44). Next, we saw how to [broadcast that live chat session](todo:link) to an Amazon IVS channel. 

When we looked at adding chat participants to the broadcast client in that last post, you probably noticed that I cheated a bit and hardcoded the `VideoComposition` values that tell the broadcast client the size and position of the participant's video on the client. Well - cheated is a strong word - let's say that I intentionally simplified the code to focus on the process of broadcasting a live chat session. Essentially what we're looking for here is modifying the size and position of the participant's video in the broadcast so that when there is one video, the layout will look something like this:

![stage stream with 1 video](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-62lbd2dfim1rompnc2f6.png)

But when there are two videos, the layout will change to something like this:

![stage stream with 2 videos](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3xoht0qajbqalt9wbvqj.png)

And when there are five:

![stage stream with 5 videos](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-haesplsameagingvposh.png)

You get the idea - a dynamic layout that changes based on the amount of participants. 

In this post, we'll take a look at one approach you could utilize to make creating a dynamic layout a bit easier. We'll build off of the solution in the last post, so if you haven't read that post yet, it's probably a good idea to do that now.

In the last post, we listened for an event called `STAGE_PARTICIPANT_STREAMS_ADDED`. In the event handler for that event, we added our participants to the DOM, and rendered the audio and video to the `IVSBroadcastClient` instance. In order to render a dynamic layout, we'll need to track how many participants are currently in the session, so we'll add an array called `participantIds` as a global variable. Let's modify the event handler to push the current participant id to that array.

```js
stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED, (participant, streams) => {
  
  //add participant id to array
  participantIds.push(participant.id);

  renderParticipant(participant, streams);
  renderVideosToClient(participant, streams.find(s => s.streamType === StreamType.VIDEO));
  renderAudioToClient(participant, streams.find(s => s.streamType === StreamType.AUDIO));
  updateVideoCompositions();
});
```

In the last post, I mentioned that the `updateVideoCompositions()` method was not shown because the implementation would vary. We'll talk about one possible implementation in just a bit. For now let's take a look at how we can get a dynamic layout config instead of hardcoding it as we did in the last post. 

One way to obtain a dynamic size and position is to loop over the participant array and calculate them based on the number of participants, the size of the `<canvas>`, and the desired amount of rows, columns, and padding. But, **why**? That sounds like a lot of difficult code and unnecessary work when you realize that these values never change. If you have one participant, the video will be a fixed size and centered in the `<canvas>`. It doesn't matter how many participants get added - the layout for each video will always be the same for a given number of participants. So why waste time and CPU cycles when we could pre-calculate these values and store them in an array of arrays. 

For my demo, I spent some time determining the best values with an intensive 30 minutes with a pen, paper and calculator to determine the composition values for each possible layout. Please note: I was **not** a maths or art major as evidenced by the following sketch. 

![calculating the layout size and position for up to 6 different layouts](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-cc67xcgp79biy11irr3d.png)

For this demo, I capped my live stream at only showing videos for the first 6 participants. Your use case may dictate something different, but having more than 6 participant videos in one live stream becomes a bit too busy in my experience. 

Here is the result of my calculations:

```js
const layouts = [
  [{ height: 720, width: 1280, x: 320, y: 180 }],
  [{ height: 450, width: 800, x: 80, y: 315 }, { height: 450, width: 800, x: 1040, y: 315 }],
  [{ height: 450, width: 800, x: 80, y: 45 }, { height: 450, width: 800, x: 1040, y: 45 }, { height: 450, width: 800, x: 560, y: 585 }],
  [{ height: 450, width: 800, x: 80, y: 45 }, { height: 450, width: 800, x: 1040, y: 45 }, { height: 450, width: 800, x: 80, y: 585 }, { height: 450, width: 800, x: 1040, y: 585 }],
  [{ height: 337, width: 600, x: 20, y: 100 }, { height: 337, width: 600, x: 650, y: 100 }, { height: 337, width: 600, x: 1280, y: 100 }, { height: 337, width: 600, x: 340, y: 640 }, { height: 337, width: 600, x: 980, y: 640 }],
  [{ height: 337, width: 600, x: 20, y: 100 }, { height: 337, width: 600, x: 650, y: 100 }, { height: 337, width: 600, x: 1280, y: 100 }, { height: 337, width: 600, x: 20, y: 640 }, { height: 337, width: 600, x: 650, y: 640 }, { height: 337, width: 600, x: 1280, y: 640 }]
];
```

That might look overwhelming, but consider that each element in the outer array element contains an array of compositions for each video. If there are 3 participants, we can reference the third element in the outer array, and the position of the participant id in the `participantIds` array will determine which composition will apply to that video. We can modify our `renderVideosToClient()` function to grab the proper composition and use those values when we add the video to the broadcast client.

```js
const renderVideosToClient = async (participant, stream) => {
  const participantId = participant.id;
  const videoId = `video-${participantId}`;
  
  // get the index of this participantId
  const pIdx = participantIds.indexOf(participantId);

  let composition = layouts[participantIds.length - 1][pIdx];
  config.index = 2;
  
  const mediaStream = new MediaStream();
  mediaStream.addTrack(stream.mediaStreamTrack);
  broadcastClient.addVideoInputDevice(mediaStream, videoId, composition);
};
```
But remember - if we only do this when a participant is added, the previous video compositions will still reflect the composition that was applied when they were added. That is where the `updateVideoCompositions()` function comes into the picture. Here we loop over the `participantIds` array, grab the proper composition from `layouts`, and use the `updateVideoDeviceComposition()` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient#updatevideodevicecomposition)) method of the `broadcastClient`.

```js
const updateVideoCompositions = async () => {
  let idx = 0;
  for (const p of participantIds) {
    const videoId = `video-${p}`;
    let config = layouts[filteredParticipantIds.length - 1][idx];
    config.index = 2;
    broadcastClient.updateVideoDeviceComposition(videoId, config);
    idx = idx + 1;
  }
};
``` 

We should also make sure that when a participant leaves the stage that we remove the participant id from the array and again update the composition for all videos.

```js
stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_REMOVED, (participant, streams) => {
  const participantId = participant.id;

  // remove participant id from array
  const pIdx = participantIds.findIndex(id => id === participantId);
  participantIds.splice(pIdx, 1);

  const videoTrackId = `video-${participantId}`;
  const audioTrackId = `audio-${participantId}`;
  if (broadcastClient.getVideoInputDevice(videoTrackId)) broadcastClient.removeVideoInputDevice(videoTrackId);
  if (broadcastClient.getAudioInputDevice(audioTrackId)) broadcastClient.removeAudioInputDevice(audioTrackId);
  const videoId = `${participantId}-video`;
  document.getElementById(videoId).closest('.participant-col').remove();
  updateVideoCompositions(); 
}); 
```

As mentioned above, you'll most likely want to limit the amount of videos that are added to the live stream via the broadcast client. You might want to add a static image instead of the final video to show that there are more participants than what are shown:

![live stream with 7 participants](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gqfhqk6gszdcn49qmjod.png)

## Summary

In this post, we learned one approach for dynamic layouts when broadcasting a multi host stage with Amazon IVS. In a future post, we'll look at additional options for broadcasting with multiple hosts. As always, if you have any questions or comments, please leave them below.