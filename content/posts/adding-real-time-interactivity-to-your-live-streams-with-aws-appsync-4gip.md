---
title: "Adding Real-Time Interactivity to Your Live Streams With AWS AppSync"
slug: "adding-real-time-interactivity-to-your-live-streams-with-aws-appsync-4gip"
author: "Todd Sharp"
date: 2024-11-13T19:10:14Z
summary: "Real-Time live streaming applications need ultra-low latency to give their streamers the ability to..."
tags: ["aws", "amazonivs", "appsync", "livestreaming"]
canonical_url: "https://dev.to/aws/adding-real-time-interactivity-to-your-live-streams-with-aws-appsync-4gip"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-b5z86pp8mnirpuys4pka.png"
---

Real-Time live streaming applications need ultra-low latency to give their streamers the ability to reach their audience in engaging, collaborative ways. Many apps use PK mode (aka VS mode) to give streamers a platform to compete with each other in singing competitions, dance-offs, or any other competition that might be entertaining to their viewers. Guest spots are another huge feature in user-generated content (UGC) style social streaming apps. This allows a streamer to have a real-time conversation with another person. In all of these cases, Amazon Interactive Video Service (Amazon IVS) gives developers the ability to easily create these types of experiences with latency around 300ms. 

![PK & Guest Spot Mode](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4phssfy8x6h0nrf13c11.png)

>💡**Tip**: If you'd like to try these modes out yourself, head over to our new real-time demos at [https://rt.ivs.rocks/demos](https://rt.ivs.rocks/demos)!

The streamers engaging and interacting with each other is a huge part of what makes these streams entertaining, but without giving viewers the ability to interact with the creators, the audience would be left as simply observers instead of feeling like they are part of the experience. Take PK mode for example - the viewers in this mode determine the winner of the competition by voting for their favorite performer. They can also chat with the streamers and each other and emote reactions in real-time. The experience wouldn't be engaging without the viewers participating in the competition and awarding the best streamer with a win! In this post, we'll look at a new option for adding this kind of interactive real-time messaging to an Amazon IVS real-time live streaming application.

## Real-Time Pub/Sub Options

There are many ways we can add real-time messaging to our live-streaming applications. In fact, Amazon IVS even offers a WebSocket based [chat](https://ivs.rocks/chat) solution that we could even use for publishing viewer interactions, but since that solution is built with a focus on viewer chat, it might not be the proper or most cost-effective solution for the volume of messages that your application might process in one of the use-cases outlined above. 

You could decide to use a third-party solution - maybe something like Momento Topics, which [we've covered before](https://dev.to/aws/live-streaming-from-unity-adding-real-time-interactions-with-momento-topics-41h). If that works for your application, that's great! 

Another option, and the one we'll cover today, is to use AWS AppSync for highly-scalable and performant app messaging. Until recently, adding pub/sub [messaging with AppSync](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-data.html) required familiarity with GraphQL. If your application is already using GraphQL and you were comfortable with it, then this solution worked out great for you. But if not, there can be a bit of a learning curve to integrate that solution into your application. This changed a few weeks ago with the [launch of AWS AppSync Events](https://aws.amazon.com/blogs/mobile/announcing-aws-appsync-events-serverless-websocket-apis/) which simplifies the messaging experience. From the launch blog post:

>Today, AWS AppSync announced AWS AppSync Events, a feature that lets developers easily broadcast real-time event data to a few or millions of subscribers using secure and performant serverless WebSocket APIs. With AWS AppSync Events, developers no longer have to worry about building WebSocket infrastructure, managing connection state, and implementing fan-out. Developers simply create their API, and publish events that are broadcast to clients subscribed over a WebSocket connection. AWS AppSync Event APIs are serverless, so you can get started quickly, your APIs automatically scale, and you only pay for what you use.

## Creating the Real-Time Stream

I've covered Amazon IVS stages in the past, so I won't go too deep into the topic here in this post. But for the sake of this demo, I'll quickly show you the code related to the UI that we'll be enhancing with AppSync Events. I've already created an Amazon IVS stage for this and I have an AWS Lambda endpoint in place that issues my participant tokens.

Here's the HTML for the front-end with CSS classes removed for brevity. Here we have two `<video>` tags, one for the 'local' participant, and one for the 'remote' participant.

```html
<div id="participants">
  <div>
    <video id="local-participant" controls autoplay muted></video>
  </div>
  <div>
    <video id="remote-participant" controls autoplay muted></video>
  </div>
  </div>
</div>
```
Of course, we must include the Amazon IVS Web Broadcast SDK (always make sure to use the latest version)!

```html
<script src="https://web-broadcast.live-video.net/1.18.0/amazon-ivs-web-broadcast.js"></script>
```

And here is the JavaScript to establish the stage instance and handle when participants join the stage.

```js
const { Stage, SubscribeType, LocalStageStream, StageEvents, StreamType } = IVSBroadcastClient;
const stageArn = 'arn:aws:ivs:us-east-1:[redcacted]:stage/[redacted]';

const getStageToken = async (stageArn) => {
  const stageTokenRequest = await fetch('https://[redacted]/Prod/create-stage-token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ stageArn }),
  });
  return (await stageTokenRequest.json()).participantToken.token;
};

// get a token
const token = await getStageToken(stageArn);

// get mic/cam permissions
await navigator.mediaDevices.getUserMedia({ video: true, audio: true });

// list devices
const devices = await navigator.mediaDevices.enumerateDevices();
const videoDevices = devices.filter((d) => d.kind === 'videoinput');
const audioDevices = devices.filter((d) => d.kind === 'audioinput');

// get media stream from devices
const cameraStream = await navigator.mediaDevices.getUserMedia({
  video: { deviceId: videoDevices[0].deviceId, aspectRatio: 16 / 9 },
});
const microphoneStream = await navigator.mediaDevices.getUserMedia({
  audio: { deviceId: audioDevices[0].deviceId },
});

const localVideoStream = new LocalStageStream(cameraStream.getVideoTracks()[0]);
const localAudioStream = new LocalStageStream(microphoneStream.getAudioTracks()[0]);

const strategy = {
  audioTrack: localAudioStream,
  videoTrack: localVideoStream,
  stageStreamsToPublish() { return [this.audioTrack, this.videoTrack]; },
  shouldPublishParticipant(participant) { return true; },
  shouldSubscribeToParticipant(participant) { return SubscribeType.AUDIO_VIDEO; }
};

const stage = new Stage(token, strategy);

stage.on(StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED, (participant, streams) => {
  let streamsToDisplay = streams;
  const videoEl = 
    participant.isLocal ? 
      document.getElementById('local-participant') : 
      document.getElementById('remote-participant');
  if (participant.isLocal) {
    streamsToDisplay = streams.filter(stream => stream.streamType === StreamType.VIDEO);
  }
  videoEl.srcObject = new MediaStream();
  streamsToDisplay.forEach(stream => videoEl.srcObject.addTrack(stream.mediaStreamTrack));
});
```

Next, we'll create an AppSync API that will be used to broadcast and receive emotes from stream viewers that we'll ultimately render to the UI.

## Creating an AppSync Event API

For this demo, we'll use the AWS Management Console to create the AppSync API. In production you could use the AWS SDK to create a unique API for each streamer, or take advantage of channels and namespaces to re-use a single API for multiple streamers.

In the AppSync console, select 'Create API' and choose 'Event API'.

![Create API](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-he6nt56ntmuplc8ml046.png)

Give it a name, and click 'Create'.

![API details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ekngleh77uprpbs6362z.png)

We'll need both the 'HTTP' and 'Realtime' DNS endpoints from the API details 'Settings' tab.

![API Settings Endpoints](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-27trc9is6qwnfcawixud.png)

We'll also need to choose an Authorization mode. For this demo, we'll use the generated API key. API keys expire and the default API key is only good for 7 days, so in production you'll want to consider this. If desired, a new API key can be generated with an expiration of up to 365 days. For this demo, we'll use the API key that was generated for us.

![API Key](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-b2b0htss736zqnzjyvgd.png)

There are other options besides using an API key for authorization. Choose the one that works best for your application.

![Event API authorization options](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-qfrm55isfctmoc8g5hs7.png)

At this point, our Event API is ready to use. 

## Connecting The App to the Event API

Let's modify our JavaScript to declare some variables that will be needed to subscribe to the Event API and publish messages to it.

```js
const APP_SYNC_API_KEY = '[YOUR API KEY]';
const HTTP_DOMAIN = '[YOUR HTTP DOMAIN]';
const REALTIME_DOMAIN = '[YOUR REALTIME DOMAIN]';
const authorization = { 'x-api-key': APP_SYNC_API_KEY, 'host': HTTP_DOMAIN };
```
Next, create a function that will be used to help us construct the authorization protocol string that we'll need to subscribe to the `WebSocket`.

```js
const getAuthProtocol = () => {
  const header = btoa(JSON.stringify(authorization))
    .replace(/\+/g, '-') // Convert '+' to '-'
    .replace(/\//g, '_') // Convert '/' to '_'
    .replace(/=+$/, ''); // Remove padding `=`
  return `header-${header}`;
};
```

Now we can establish the `WebSocket` connection.

```js
const authProtocol = getAuthProtocol();
const connection = new WebSocket(
  `wss://${REALTIME_DOMAIN}/event/realtime`,
  ['aws-appsync-event-ws', authProtocol]
);
```

And add a listener for when the socket is established. When the `WebSocket` is opened, we'll send a message to initialize the connection, and then subscribe to a specific channel (`/default/ivs/demo` in this case).

```js
connection.onopen = () => {
  connection.send(JSON.stringify({ type: 'connection_init' }));
  connection.send(JSON.stringify({
    type: 'subscribe',
    id: Date.now().toString(),
    channel: '/default/ivs/demo',
    authorization
  }));
};
```

Now we can add a listener for incoming messages. Here we parse the message and look for a message with a `type` of `emote`. When that's received, we'll call the `renderEmote()` function which will handle creating the emote and animating it on the front-end.

```js
connection.onmessage = (event) => {
  const payload = JSON.parse(event.data);
  if (payload.event) {
    const message = JSON.parse(payload.event);
    if (message.type === 'emote') {
      renderEmote(message.emote);
    }
  }
};
```

To publish messages, we need to `POST` the message body to our `HTTP` endpoint. We'll create a function to help out with this.

```js
const publishMessage = async (message) => {
  const appSyncHttpUrl = `https://${HTTP_DOMAIN}/event`;
  const headers = {
    'content-type': 'application/json',
    'x-api-key': APP_SYNC_API_KEY,
  };
  const body = JSON.stringify(
    {
      'channel': '/default/ivs/demo',
      'events': [
        JSON.stringify(message)
      ]
    }
  );
  await fetch(appSyncHttpUrl, {
    method: 'POST',
    headers,
    body,
  });
};
```

## Invoking the Event API 

Now we can add a few buttons to our front-end that viewers can use to emote during the live stream!

```html
<div>
  <button data-emote="💖">💖</button>
  <button data-emote="👍">👍</button>
  <button data-emote="😂">😂</button>
  <button data-emote="🎉">🎉</button>
  <button data-emote="👀">👀</button>
  <button data-emote="👏">👏</button>
  <button data-emote="🙏">🙏</button>
</div>
```

And a click handler to publish the emote when the buttons are clicked.

```js
document.getElementById('emote-btns')
  .addEventListener('click', (event) => {
    publishMessage({ 
      type: 'emote', 
      emote: event.target.dataset.emote 
    });
  });
```

Since we set up our message handler above to call the `renderEmote()` function, we're all set!  Here's a very simple implementation of that function that adds the emote to the DOM and animates it floating up and off screen.

```js
const renderEmote = (emote) => {
  const emotes = document.getElementById('emotes');
  const emoteDivPosition = emotes.getBoundingClientRect();
  const left = emoteDivPosition.x;
  const right = left + emoteDivPosition.width;
  const emotePos = getRandomRange(left, right);
  const emoteEl = document.createElement('div');
  emoteEl.style.left = `${emotePos}px`;
  emoteEl.style.position = 'fixed';
  emoteEl.style.userSelect = 'none';
  emoteEl.innerText = emote;
  emotes.appendChild(emoteEl);
  const speed = getRandomRange(20, 30);
  let newPos = 0;
  let moveInterval = setInterval(() => {
    newPos = newPos + -10;
    if (newPos < -1000) {
      clearInterval(moveInterval);
      emoteEl.remove();
    }
    else {
      emoteEl.style.transform = `translateY(${newPos}px)`;
    }
  }, speed);
};
```

Here's how our demo looks once we've got it up and running.

{{< youtube _1sG3QCXfYM >}}

## Summary

In this post, we created a real-time live stream user interface and connected that up to an Amazon IVS real-time stage. We created an Event API with AppSync to handle publishing and subscribing emotes from viewers and rendered the emotes to the UI when the event message is received. Of course this method could be extended for votes during a PK mode stream, or any other live interactivity like polls, notifications, etc as needed. What will you use AppSync Event APIs for in your live streaming application?