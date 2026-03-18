---
title: "Broadcasting Interactive Web Based Gaming Live Streams with Amazon IVS"
slug: "broadcasting-interactive-web-based-gaming-live-streams-with-amazon-ivs-20ek"
author: "Todd Sharp"
date: 2023-04-07T11:31:44Z
summary: "I've blogged quite a bit about the Amazon Interactive Video Service (Amazon IVS) Web Broadcast SDK...."
tags: ["aws", "amazonivs", "gamedev", "livestreaming"]
canonical_url: "https://dev.to/aws/broadcasting-interactive-web-based-gaming-live-streams-with-amazon-ivs-20ek"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nuyw5ipy07a0ghdvhdqx.jpeg"
---

I've blogged quite a bit about the Amazon Interactive Video Service (Amazon IVS) Web Broadcast SDK. We've learned about [the basics](https://dev.to/aws/broadcasting-to-your-amazon-ivs-live-stream-from-a-browser-2343), how to use the SDK to [stream pre-recorded videos](https://dev.to/aws/live-streaming-pre-recorded-videos-with-the-amazon-ivs-web-broadcast-sdk-1j7m), how to [add screen sharing and overlays](https://dev.to/aws/enhancing-your-amazon-ivs-web-broadcast-with-screen-sharing-and-canvas-overlays-4dnd), and even looked at using it to [create a Lofi radio station](https://dev.to/aws/creating-and-broadcasting-a-lofi-radio-station-with-amazon-ivs-4nk1). 

The Web Broadcaster SDK is a game changer that gives developers the ability to integrate the broadcast experience directly into their streaming applications instead of directing their users to use third-party desktop streaming software. In this post, we'll look at another exciting possible use case of the Web Broadcast SDK: streaming browser based games directly to an Amazon IVS channel. It's really quite easy to do, and we'll take it a step further by creating an interactive experience that allows live stream viewers to control the gameplay (akin to [TwitchPlaysPokemon](https://www.twitch.tv/twitchplayspokemon)). 

## Streaming a Browser Based Game Directly From the Browser

For this post, I'll assume that you're already familiar with Amazon IVS and have already configured a live streaming channel. If you're new to Amazon IVS, check out the blog series [Getting Started with Amazon IVS](https://dev.to/recursivecodes/series/19342), specifically the very [first post](https://dev.to/aws/get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg). Optionally, you could also refer to the [user guide](https://docs.aws.amazon.com/ivs/latest/userguide/getting-started-create-channel.html) which is a great resource for learning how to develop live streaming applications with Amazon IVS.

Since I'm not a game developer, I decided to add live streaming to a few existing open source, browser-based games: [pacman-canvas](https://github.com/platzhersh/pacman-canvas) and [Astray](https://github.com/wwwtyro/Astray). Since both of these games utilize `<canvas>` for gameplay, it will be easy to obtain a `MediaStream` from them will be the source for our live stream video input.

## pacman-canvas

For the first demo, I cloned the `pacman-canvas` repo to my local machine and took a look at the code.

### Initializing the Broadcast Client

The `pacman-canvas` game uses jQuery, so I added a call to an `initBroadcast()` method to the end of the existing DOM ready handler:

```js
let broadcastClient;
let isBroadcasting = false;

$(document).ready(function () {
  // game logic...
  initBroadcast();
})
```

In my `initBroadcast()` method, I create an instance of the `AmazonIVSBroadcastClient ` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient)), passing it the **Ingest endpoint** from my Amazon IVS channel.

```js
broadcastClient = IVSBroadcastClient.create({
  streamConfig: IVSBroadcastClient.STANDARD_LANDSCAPE,
  ingestEndpoint: config.ingestEndpoint,
});
```

Next, to add the gameplay to the client, I grabbed a reference to the `<canvas>` element used by the game and called `addVideoInputDevice()` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient#addvideoinputdevice)) on the `broadcastClient`:

```js
const game = document.getElementById('myCanvas');
broadcastClient.addVideoInputDevice(game.captureStream(), 'game-track', { index: 0 });
```

Finally, to start the broadcast, I call `startBroadcast()` and pass it the **Stream key** from my channel.

```js
broadcastClient
  .startBroadcast(config.streamKey)
  .then(() => {
    isBroadcasting = true;
    console.log('online')
  })
  .catch((error) => {
    isBroadcasting = false;
    console.error(error);
  });
```

The game uses a few `<audio>` tags for sound effects and calls the following function as necessary.

```js
var Sound = {};
Sound.play = function (sound) {
  if (game.soundfx == 1) {
    var audio = document.getElementById(sound);
    (audio !== null) ? audio.play() : console.log(sound + " not found");
  }
};
```

To add the game audio to my stream, I modified it to call `addAudioInputDevice()` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient#addaudioinputdevice)).

```js
var Sound = {};
Sound.play = function (sound) {
  if (game.soundfx == 1) {
    var audio = document.getElementById(sound);
    (audio !== null) ? audio.play() : console.log(sound + " not found");
    var trackLabel = `${sound}-audio-track-${new Date().getTime()}`;
    audio.addEventListener('playing', (evt) => {
      if (!broadcastClient.getAudioInputDevice(trackLabel)) {
        broadcastClient.addAudioInputDevice(audio.captureStream(), trackLabel);
      }
    });
  }
};
```

And that's it! The gameplay stream will be broadcast whenever the `startBroadcast()` method is called, so we could attach that to a button click handler or call it from the `newGame` method of the existing game. If we wanted to, we could also [add a webcam to the stream](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-guides/getting-started#add-device-to-a-stream) and even size and position the webcam as an overlay (see `VideoComposition` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/interfaces/VideoComposition)) for more info).

## Playing Back the Live Stream in a Browser

For playback, I added a simple HTML page that includes and utilizes the [Amazon IVS Player SDK](https://docs.aws.amazon.com/ivs/latest/userguide/player.html).

```html
<script src="https://player.live-video.net/1.17.0/amazon-ivs-player.min.js"></script>
<script>
document.addEventListener('DOMContentLoaded', () => {
  const videoPlayer = document.getElementById('video-player');
  const streamUrl = '[CHANNEL PLAYBACK URL]';
  const ivsPlayer = IVSPlayer.create(); 
  ivsPlayer.attachHTMLVideoElement(videoPlayer);
  ivsPlayer.load(streamUrl);
  ivsPlayer.play();
});
</script>
<body>
  <video id="video-player" />
</body>
```

Here's how everything looks at this point. On the left side is the broadcast/gamer view, and on the right is the playback/viewer view.

![Streaming pacman to IVS](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wi0qbw5ykabxogkxrb7q.gif)

## Adding Timed Metadata

As you can see in the Gif above, the score, level, and lives data is not included in the live stream. This is because the game developer did not include those elements in the gameplay `<canvas>`. If we wanted to, we could render these as overlays in the playback view by [publishing them with timed metadata](https://dev.to/aws/creating-interactive-live-streaming-experiences-using-timed-metadata-with-amazon-ivs-2kp6). In my demo, I modified the `Score` function of `pacman-canvas` to publish the score as timed metadata on my live stream by calling an AWS Lambda function that I've previously created for this channel.

```js
const publishMetadata = async (meta) => {
  await fetch('[lambda url]/send-metadata', {
    method: 'POST',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(meta),
  });
};

function Score() {
  this.score = 0;
  this.set = function (i) {
    this.score = i;
  };
  this.add = function (i) {
    this.score += i;
    publishMetadata({
      metadata: JSON.stringify({ score: this.score }),
    });
  };
  this.refresh = function (h) {
    $(h).html("Score: " + this.score);
  };

}

```

![publishing score with timed metadata](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-hp7droodlybsl6ifuxso.gif)

>**Note:** Be careful publishing metadata too frequently to avoid exceeding the Amazon IVS [service quotas](https://docs.aws.amazon.com/ivs/latest/userguide/service-quotas.html). You may need to throttle or batch metadata publishing to avoid exceeding the quota.

## Adding Interactivity to a Browser Based Game Live Stream

Now let's take a look at how we might create an interactive browser based game that can be controlled by live stream viewers. For this, I chose `Astray` - a simple game that requires the player to navigate a ball through a maze. I added the Web Broadcast client just as i did with `pacman-canvas` above, and decided to use Amazon IVS chat to receive the gameplay control commands from the viewer.

### Adding Chat

We've previously looked at how to [add chat to your live streaming application with Amazon IVS chat](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6). To use chat for game interactivity, we'll configure a chat experience just like we usually do, but in the chat connection's message handler, we'll check the message content for the terms `left`, `right`, `up` and `down` to control the ball movement on the broadcaster side. 

```js
const chatConnection = new WebSocket('wss://edge.ivschat.us-east-1.amazonaws.com', token);
      
chatConnection.onmessage = (event) => {
  const data = JSON.parse(event.data);
  const chatEl = document.getElementById('chat');
  if (data.Type === 'MESSAGE') {
    const direction = data.Content.toLowerCase();
    if (['left', 'up', 'right', 'down'].indexOf(direction) > -1) moveBall(direction);
    // render message to chat div
  }
}
```

If I find one of the directional commands in the incoming message, I call `moveBall()` which will simulate a key press on the broadcaster side to move the ball in the game.

```js
const moveBall = (direction) => {
  let keyCode;
  let keyCodes = {
    left: 37,
    up: 38,
    right: 39,
    down: 40,
  }
  const keyDown = new KeyboardEvent('keydown', { keyCode: keyCodes[direction] });
  const keyUp = new KeyboardEvent('keyup', { keyCode: keyCodes[direction] });
  document.dispatchEvent(keyDown);
  setTimeout(() => {
    document.dispatchEvent(keyUp);
  }, 200);
};
```

>**Note:** There's a minor catch to this approach. Because `Astray` uses `requestAnimationFrame()`, the broadcaster's game tab must be active/visible tab at all times since `requestAnimationFrame()` [pauses when the tab is not visible](https://developer.mozilla.org/en-US/docs/Web/API/window/requestAnimationFrame) to improve performance and battery life.

Here's how `Astray` looks when controlled by the viewer. 

![stream viewer controlling game play](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-f0usknmucd7cu31iburp.gif)

There's a slight delay due to the stream latency, but the potential to give viewers control of the live stream gameplay is intriguing and filled with potential. 

## Summary

In this post, we learned how to integrate the Amazon IVS Web Broadcast SDK into a browser based game to give players the ability to live stream gameplay directly to an Amazon IVS live streaming channel. We also learned how to add interactivity to the experience to give stream viewers the ability to directly affect the gameplay. If you'd like to learn more about Amazon IVS, check out the [Getting Started with Amazon IVS](https://dev.to/recursivecodes/series/19342) blog post series here on dev.to.