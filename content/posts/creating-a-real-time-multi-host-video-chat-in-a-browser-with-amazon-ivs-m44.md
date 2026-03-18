---
title: "Creating a Real Time Multi Host Video Chat in a Browser with Amazon IVS"
slug: "creating-a-real-time-multi-host-video-chat-in-a-browser-with-amazon-ivs-m44"
author: "Todd Sharp"
date: 2023-04-28T12:15:39Z
summary: "We recently announced support for collaborative live streams via a new virtual resource called a..."
tags: ["aws", "amazonivs", "livestreaming", "javascript"]
canonical_url: "https://dev.to/aws/creating-a-real-time-multi-host-video-chat-in-a-browser-with-amazon-ivs-m44"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-be67x0k0xno0x9xmzav1.jpeg"
---

We recently [announced](https://aws.amazon.com/blogs/media/add-multiple-hosts-to-live-streams-with-amazon-ivs/) support for collaborative live streams via a new virtual resource called a stage with Amazon Interactive Video Service (Amazon IVS). This feature opens up a multitude of possibilities that were not easy (or even possible) to implement in the past. This feature gives live streamers the ability to invite guests into their stream, collaborate with other content creators, or even create a "call-in" style show with audio only participants. In this post, we'll look at how to get started creating a web application with multiple hosts with the Web Broadcast SDK. As always, the [docs](https://docs.aws.amazon.com/ivs/latest/userguide/broadcast-web.html#broadcast-web-multiple-hosts) are a great starting point, but it always helps to walk through a demo application so that's what we'll focus on in this post. 

For this demo, we'll build a web application that allows multiple participants to view and talk to one another. In a future post we'll add the ability to broadcast the conversation to an Amazon IVS channel where others can view the conversation.

At a high level, here are the steps that we'll take to create virtual "stage" application for real-time collaboration between multiple hosts.

* Create a `stage` via the SDK
* Issue token(s) for stage participants
* Connect to the `stage` on the client
* Render participant's audio and video when they join a stage

## The Server Side

We will utilize the new `@aws-sdk/client-ivs-realtime` module ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivs-realtime/modules.html)) of the AWS SDK for JavaScript (v3) to create the stage resource and participant tokens. Here is an [example of a serverless application](https://github.com/aws-samples/amazon-ivs-multi-host-serverless-demo) that you can use to handle these steps, but for my demo I decided to simplify things a bit and created an Express application that can be used to host the API and my front-end.

### Creating a Stage Resource via the AWS SDK for JavaScript (v3)

In my Express app, I created a service called `IvsRealtimeService`. This service caches existing `stages` and `stageParticipants` in memory to avoid the need for a database to persist them. 

>In production, you'd want to store these values in a persistent data store to avoid the volatility and limitations of caching the values in memory (again, refer to the [serverless demo](https://github.com/aws-samples/amazon-ivs-multi-host-serverless-demo) to learn more about using Amazon DynamoDB to persist stages and tokens).

My app has one route called `/ivs-stage` that can be used to `POST` a stage `name`. This route uses my `IvsRealtimeService` to check for an existing stage by that name, and either returns the existing stage or creates a new stage.

```js
router.post('/ivs-stage', async function (req, res, next) {
  const body = req.body;
  const stageName = body.name;
  let stage = 
    ivsRealtimeService.stageExists(stageName) ? 
      ivsRealtimeService.getStage(stageName) : 
      await ivsRealtimeService.createStage(stageName);
  res.json(stage);
});
```

The `stageExists()` and `getStage()` methods look like so:

```js
import { CreateParticipantTokenCommand, CreateStageCommand, IVSRealTimeClient } from "@aws-sdk/client-ivs-realtime";

const config = {
  credentials: {
    accessKeyId: process.env.ACCESS_KEY,
    secretAccessKey: process.env.SECRET_KEY,
  }
};

export default class IvsRealtimeService {
  ivsRealtimeClient = new IVSRealTimeClient(config);
  stages = {};
  stageParticipants = {};

  getStage(name) {
    return this.stages[name];
  }

  stageExists(name) {
    return this.stages.hasOwnProperty(name);
  }
}
```

And the `createStage()` method sends a `CreateStageCommand` via the `ivsRealtimeClient`.

```js
async createStage(name) {
  const createStageRequest = new CreateStageCommand({ name });
  const createStageResponse = await this.ivsRealtimeClient.send(createStageRequest);
  this.stages[name] = createStageResponse.stage;
  this.stageParticipants[name] = [];
  return this.stages[name];
};
```

### Generating Stage Participant Tokens

I created another route in my application to handle generating participant tokens called `/ivs-stage-token`.

```js
router.post('/ivs-stage-token', async function (req, res, next) {
  const body = req.body;
  const username = body.username;
  const stageName = body.stageName;
  const userId = uuid4();
  let token = await ivsRealtimeService.createStageParticipantToken(stageName, userId, username);
  res.json(token);
});
```
Note that this endpoint requires a `username`, `stageName`, and a `userId` and invokes `ivsRealtimeService.createStageParticipantToken()`.

```js
async createStageParticipantToken(stageName, userId, username, duration = 60) {
  let stage;
  if (!this.stageExists(stageName)) {
    stage = await this.createStage(stageName)
  }
  else {
    stage = this.getStage(stageName);
  }
  const stageArn = stage.arn;

  const createStageTokenRequest = new CreateParticipantTokenCommand({
    attributes: {
      username,
    },
    userId,
    stageArn,
    duration,
  });
  const createStageTokenResponse = await this.ivsRealtimeClient.send(createStageTokenRequest);
  const participantToken = createStageTokenResponse.participantToken;
  this.stageParticipants[stageName].push(participantToken);
  return participantToken;
};
```

In this method, we're creating a `CreateParticipantTokenCommand` which expects an input object containing the `userId`, the `stageArn`, the token duration (default: 60 minutes), and an `attributes` object which can be used to store arbitrary application-specific values (in my case, the `username`). The `attributes` will be available later on when we create our front-end, so it's a nice way to include participant specific information. But, like our docs say: 

>This field is exposed to all stage participants and should not be used for personally identifying, confidential, or sensitive information.

Now that we've created a few endpoints to help us create stage resources and participant tokens, let's look at creating the web app.

## Building the Web Application

The front-end will be a straightforward, vanilla JavaScript and HTML application to keep things simple and focus on learning the Web Broadcast SDK. For this demo, we can add a   route that returns an HTML file. In that file, include the Web Broadcast SDK (version `1.3.2`).

### The Includes and Markup

```html
<script src="https://web-broadcast.live-video.net/1.3.2/amazon-ivs-web-broadcast.js"></script>
```

Because the number of participants in this virtual stage is dynamic (up to 12), it makes sense to create a `<template>` that contains a `<video>` tag and any other buttons, labels or markup that we need. Here's how that might look. 

```html
<template id="stages-guest-template">
  <video class="participant-video" autoplay></video>
  <div>
    <small class="participant-name"></small>
  </div>
  <div>
    <button type="button" class="settings-btn">Cam/Mic Settings</button>
  </div>
</template>
```

I also have an empty `<div>` that will be used to render the participants as they join the virtual stage.

```html
<div id="participants"></div>
```

### The JavaScript 

Now that we have the Web Broadcast SDK dependency and the markup ready to go, we can look at the JavaScript required to join a virtual "stage" and render the participants. This involves several steps, but we can break them out into manageable functions to keep things simple. When the DOM is ready, we can call the following functions (we'll look at each below).

```js
let
  audioDevices,
  videoDevices,
  selectedAudioDeviceId,
  selectedVideoDeviceId,
  videoStream,
  audioStream,
  username,
  stageConfig,
  username = '[USERNAME]',
  stageName = '[STAGE NAME]',
  stageParticipantToken,
  stage;

document.addEventListener('DOMContentLoaded', async () => {
  await handlePermissions();
  await getDevices();
  await createVideoStream();
  await createAudioStream();
  stage = await getStageConfig(stageName);
  stageParticipantToken = await getStageParticipantToken(stage.name, username);
  await initStage();
});
```

#### Devices and Permissions

The first 4 method calls (`handlePermissions()`, `getDevices()`, `createVideoStream()`, `createAudioStream()`) should look familiar if you've worked with the Amazon IVS Web Broadcast SDK in the past. We'll quickly look at each function below, but you can always refer to the [docs](https://docs.aws.amazon.com/ivs/latest/userguide/broadcast-web.html#broadcast-web-getting-started) for more information.

First, `handlePermissions()` lets us prompt the user for permission to access their webcam and microphone.

```js
const handlePermissions = async () => {
  let permissions;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    for (const track of stream.getTracks()) {
      track.stop();
    }
    permissions = { video: true, audio: true };
  }
  catch (err) {
    permissions = { video: false, audio: false };
    console.error(err.message);
  }
  if (!permissions.video) {
    console.error('Failed to get video permissions.');
  } else if (!permissions.audio) {
    console.error('Failed to get audio permissions.');
  }
};
```

Next, `getDevices()` retrieves a list of webcams and microphones and stores them. In this demo, I'm defaulting the selected video and audio device to the first available device, but in your application you'd likely be presenting these in a `<select>` to let the user pick which broadcast device they'd like to use.

```js
const getDevices = async () => {
  const devices = await navigator.mediaDevices.enumerateDevices();
  videoDevices = devices.filter((d) => d.kind === 'videoinput');
  audioDevices = devices.filter((d) => d.kind === 'audioinput');
  selectedVideoDeviceId = videoDevices[0].deviceId;
  selectedAudioDeviceId = audioDevices[0].deviceId;
};
```

Now that we have the devices listed, we can create a video and audio stream from them.  For multi-host video, we should make sure that we keep in mind the [recommended limits](https://docs.aws.amazon.com/ivs/latest/userguide/broadcast-web.html#broadcast-web-multiple-hosts#web-multiple-hosts-optimizing-media) for framerate and video size.

```js
const createVideoStream = async () => {
  videoStream = await navigator.mediaDevices.getUserMedia({
    video: {
      deviceId: {
        exact: selectedVideoDeviceId
      },
      width: {
        ideal: 1280,
        max: 1280,
      },
      height: {
        ideal: 720,
        max: 720,
      },
      frameRate: {
        max: 30,
      },
    },
  });
};

const createAudioStream = async () => {
  audioStream = await navigator.mediaDevices.getUserMedia({
    audio: {
      deviceId: selectedAudioDeviceId
    },
  });
};
```

#### Configuring and Joining The Stage

Now that we have permissions, devices, and streams sorted we can focus on the virtual stage. First, declare some necessary variables.

```js
const { Stage, SubscribeType, LocalStageStream, StageEvents, StreamType } = IVSBroadcastClient;
```

Now we can call the `getStageConfig()` method which calls the API endpoint that we created above to create (or retrieve) the stage resource. The value of the stage `name` here is how our application will allow multiple participants to join the same virtual stage, so we'd probably want to pass this in somehow (maybe via URL variables or retrieved from a backend).

```js
const getStageConfig = async (name) => {
  const stageRequest = await fetch('/ivs-stage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name })
  });
  const stage = await stageRequest.json();
  return stage;
};
```

Next, `getStageParticipantToken()` retrieves a token from the other API endpoint that we created above. The `stageName` variable is a property of the `stage` object returned from `getStageConfig()` immediately above, and the `username` depends on your application logic (maybe you have access to a current logged in user property).

```js
const getStageParticipantToken = async (stageName, username) => {
  const stageTokenRequest = await fetch('/ivs-stage-token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, stageName }),
  });
  const token = await stageTokenRequest.json();
  return token;
};
```

Now we're ready to configure and join the stage. The `initStage()` method will create an instance of the `Stage` object, which expects the stage participant token and a `strategy` object. The `strategy` object contains three functions which express the desired state of the stage (refer to the [docs](https://docs.aws.amazon.com/ivs/latest/userguide/broadcast-web.html#web-multiple-hosts-concepts-strategy) for all of the different possibilities for strategy). Within the `initStage()` method, we can define it like so.

```js
const initStage = async () => {
  const strategy = {
    shouldSubscribeToParticipant: (participant) => {
      return SubscribeType.AUDIO_VIDEO;
    },
    shouldPublishParticipant: (participant) => {
      return true;
    },
    stageStreamsToPublish: () => {
      const videoTrack = videoStream.getVideoTracks()[0]
      const audioTrack = audioStream.getAudioTracks()[0]
      const streamsToPublish = [
        new LocalStageStream(videoTrack),
        new LocalStageStream(audioTrack)
      ];
      return streamsToPublish;
    },
  };
}
```

Before we move forward with the rest of the `initStage()` method, let's break down the strategy object. The first function (`shouldSubscribeToParticipant()`) expresses how to handle each participant that joins the application. This gives us the freedom to add participants who may act as moderators (`NONE`), audio-only participants (`AUDIO`) or participants with full video and audio (`AUDIO_VIDEO`) as shown above.

Next, `shouldPublishParticipant()` expresses whether or not the participant should be published. You might want to check the state of a participant based on a button click or a check box to give participants the ability to remain unpublished until they are ready.

Finally, `stageStreamsToPublish()` expresses an array of `LocalStageStream` objects containing the `MediaStream` elements that should be published. In this demo, we'll use both the `videoStream` and `audioStream` that we created above to generate these. 

Next, inside of the `initStage()` method, we create an instance of the `Stage` class, passing it the participant token and the strategy.

```js
stage = new Stage(stageParticipantToken.token, strategy);
```

Now that we have a `Stage` instance, we can attach listeners to the various events that are broadcast on the stage. See the [docs for all of the possible events](https://docs.aws.amazon.com/ivs/latest/userguide/broadcast-web.html#web-multiple-hosts-concepts-events). In this demo, we'll listen for when participants are added or removed.

When participants are added, we will render the participant. 

```js
stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED, (participant, streams) => {
  renderParticipant(participant, streams);
});
```

The `renderParticipant()` method, defined outside of the `initStage()` method, clones the `<template>` that we defined above and customizes it for the given participant. Note that the `participant` object contains a boolean value `isLocal`; we can use this to only add the video stream for the current local participant to avoid echoing their own voice back to them. 

```js
const renderParticipant = (participant, streams) => {
  // clone the <template>
  const guestTemplate = document.getElementById('stagesGuestTemplate');
  const newGuestEl = guestTemplate.content.cloneNode(true);

  // populate the template values
  newGuestEl.querySelector('.participant-col').setAttribute('data-participant-id', participant.id);
  newGuestEl.querySelector('.participant-name').textContent = participant.attributes.username;

  // get a list of streams to add
  let streamsToDisplay = streams;
  if (participant.isLocal) {
    streamsToDisplay = streams.filter(stream => stream.streamType === StreamType.VIDEO)
  }

  // add all audio/video streams to the <video>
  const videoEl = newGuestEl.querySelector('.participant-video');
  videoEl.setAttribute('id', `${participant.id}-video`);
  const mediaStream = new MediaStream();
  streamsToDisplay.forEach(stream => {
    mediaStream.addTrack(stream.mediaStreamTrack);
  });
  videoEl.srcObject = mediaStream;
 
  // add the cloned template to the list of participants
  document.getElementById('participants').appendChild(newGuestEl);
};
```

Back in the `initStage()`, we can listen for when a participant leaves the stage so that we can remove their video from the DOM.

```js
stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_REMOVED, (participant, streams) => {
  const videoId = `${participant.id}-video`
  document.getElementById(videoId).closest('.participant-col').remove();
});
```

For this demo, we won't add any additional listeners. Your business needs will dictate additional listeners and your application can respond to those as necessary. For example, if we wanted to update an indicator on the client side with the current connection state, we could listen for `StageEvents.STAGE_CONNECTION_STATE_CHANGED` and set the state indicator each time the handler is invoked.

The final step inside `initStage()` is to join the stage.

```js
try {
   await stage.join();
} 
catch (error) {
   // handle join exception
}
```

## Leaving the Stage

It's not completely necessary, but we can improve the user experience by explicitly leaving a stage when the participant exits the application. This will ensure that the remaining participants UI will be updated sooner than later. For this, we can use a `beforeunload` handler to invoke `stage.leave()` to ensure a clean disconnection.

```js
const cleanUp = () => {
  if (stage) stage.leave();
};

document.addEventListener("beforeunload", cleanUp);
```

Now our application is ready to test. Running the application gives us a real-time video chat experience between up to 12 participants.


![Multi-host video chat](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gq4lo4lpg45uuz327jrk.png)


## Summary

In this post, we learned how to create a real-time video chat experience for up to 12 participants. In our next post, we'll learn how to take the next step and broadcast a real-time chat to an Amazon IVS channel so that end viewers can watch the conversation with high quality and low latency.
