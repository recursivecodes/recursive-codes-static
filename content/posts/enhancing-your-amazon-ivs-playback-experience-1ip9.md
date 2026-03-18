---
title: "Enhancing Your Amazon IVS Playback Experience"
slug: "enhancing-your-amazon-ivs-playback-experience-1ip9"
author: "Todd Sharp"
date: 2022-09-02T15:55:51Z
summary: "In our last post, we created our first instance of the Amazon Interactive Video Service (Amazon IVS)..."
tags: ["aws", "livestreaming", "cloud", "amazonivs"]
canonical_url: "https://dev.to/aws/enhancing-your-amazon-ivs-playback-experience-1ip9"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tpawxy4psv6lagf785rh.jpeg"
---

In our last post, we created our first instance of the Amazon Interactive Video Service (Amazon IVS) player to playback our live stream that we previously created. Today, we'll look at the various methods and events that are available in the Amazon IVS Player that we can use to enhance the user experience when playing back a live stream.

## Recap

Let's quickly revisit the Amazon IVS player that we created in our last post, just to give us a starting point to build on in this post. To recap, in order to playback an Amazon IVS live stream, we included the Amazon IVS player `<script>`, added a `<video>` element, and then used a bit of JavaScript to create the player instance, attach it to the `<video>` element, loaded the stream, and finally started playback. The code and rendered player looked like this:

{% codepen https://codepen.io/recursivecodes/pen/mdxXpWp %}

## Enhancing the Player Experience

If basic playback is all that you need for your application, then we’re already there! But sometimes we want to add a bit more to the experience! For that, the Amazon IVS player SDK gives us additional methods and events that we can use to make things shinier. For example, wouldn’t it be cool to add an ‘online/offline’ indicator to the page so that users can quickly see the status of the current stream? What about displaying the latency or resolution of the current stream? What about accessibility? Let’s dig into the player SDK and check out some things that we can do. We won’t look extensively at every single method and event of the SDK, so check out the [full player documentation](https://aws.github.io/amazon-ivs-player-docs/1.11.0/web/index.html) when you get started with your own application.

## Player Event Listeners

![I'm listening](https://media.giphy.com/media/eM7ItgdRlSA5lyY7V0/giphy.gif)

We can attach listeners to several events and player states. To do this, we use the `addEventListener` method on the instance of the player that we created. For example, to add an ‘online/offline’ indicator, we can add the following HTML (styled with a bit of Bootstrap):

```html
<span class="badge bg-danger text-white mb-3" id="online-indicator">Offline</span>
```

And attach a listener that calls the `playerOnline()` method when the player entering a `PLAYING` state. 

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerState.PLAYING, playerOnline);
```

The `playerOnline()` method updates the status indicator to show our users that the stream is online.

```js
const playerOnline = () => {
  const indicator = document.getElementById('online-indicator');
  indicator.classList.remove('bg-danger');
  indicator.classList.add('bg-success');
  indicator.innerHTML = 'Online';
}
```

We can also listen for the `IDLE` (paused) and `ENDED` states, and update the indicator to show that the stream is offline.

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerState.ENDED, playerOffline);
ivsPlayer.addEventListener(IVSPlayer.PlayerState.IDLE, playerOffline);
```

And toggle the status indicator accordingly.

```js
const playerOffline = () => {
  const indicator = document.getElementById('online-indicator');
  indicator.classList.add('bg-danger');
  indicator.classList.remove('bg-success');
  indicator.innerHTML = 'Offline';
}
```
 
> **Here Be Dragons:** It's undocumented, but sometimes I "cheat" and listen for the `STATE_CHANGED` event which receives a string indicating the destination state. Use at your own risk!

```html
<span class="badge bg-info ms-1" id="status">Current State: <i id="current-state"></i></span>
```

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerEventType.STATE_CHANGED, (state) => {
    document.getElementById('current-state').innerHTML = state;
});
```

Let’s see how this looks in action! Try to toggle playback with the pause button a few times to see the status indicators update in response to the event handlers that we just added.

{% codepen https://codepen.io/recursivecodes/pen/BarYrqw %}

## Closed Captions

There are additional [PlayerEventType](https://aws.github.io/amazon-ivs-player-docs/1.11.0/web/index.html#playereventtype) and [PlayerState](https://aws.github.io/amazon-ivs-player-docs/1.11.0/web/index.html#playerstate) values that we can attach listeners to. Another **really helpful** player event is the `TEXT_CUE` event. If our live stream contains closed caption data, this event will contain the relevant caption text. Let's update our player to listen for this event and render the caption text from another one of our [test streams](https://github.com/aws-samples/amazon-ivs-player-web-sample#test-streams) that contains closed captions. 

First, update the HTML to create a container to display the captions. We'll use a little Bootstrap magic to place the caption text on top of the player and style it a bit.

```html
<div class="position-relative">
    <video id="video-player" controls autoplay playsinline></video>
    <div 
        class="position-relative mx-auto bg-dark bg-opacity-50 rounded text-white text-center fs-3 d-none" 
        style="width: 90%; bottom: 100px;" 
        id="captions">
    </div>
</div>
```
In our handler for the `TEXT_CUE` event, we'll hide the container if there is no text to display, and show it and populate the text if there is something to display.

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerEventType.TEXT_CUE, (e) => {
    const caption = e.text;
    const captionsEl = document.getElementById('captions');
    if(caption.length) {
        captionsEl.innerHTML = caption;
        captionsEl.classList.remove('d-none');
    }
    else {
        captionsEl.classList.add('d-none');
        captionsEl.innerHTML = '';
    }
});
```

Let's see this one in action! If you're not hearing impaired, ignore the fact that the video contains no actual audio that matches the caption text. This is indeed an actual feed with properly embedded captions, but the text is used to illustrate the concept of closed captions at certain points in the video feed.

{% codepen https://codepen.io/recursivecodes/pen/BarroJW %}

> What about real-time captions for live streams with auto translate? It's possible with AWS Transcribe and Amazon Translate. Check out the [demo on GitHub](https://github.com/aws-samples/amazon-ivs-auto-captions-web-demo).

## Player Methods

Besides the various events and states that we looked at above, there are several methods that the [player](https://aws.github.io/amazon-ivs-player-docs/1.11.0/web/interfaces/player.html) exposes several methods that give us visibility into various settings and automate playback state. Let’s look at how we can use some of these to display information about the current stream.

### Stream Latency and Quality

Sometimes we want to display the current latency and resolution of the stream being played. This can enhance user experience, or take action based on a business need. Let’s add some UI elements to display the current stream latency, quality, and frame rate. For the latency value, we’ll use `setInterval` to update the value every 1.5 seconds, and for quality and frame rate, we’ll update the UI in a `PLAYING` event handler.

```js
setInterval(() => {
    document.getElementById('latency').innerHTML = ivsPlayer.getLiveLatency().toFixed(2);
  }, 1500);

ivsPlayer.addEventListener(IVSPlayer.PlayerState.PLAYING, () => {
    const quality = ivsPlayer.getQuality();
    document.getElementById('quality').innerHTML = quality.name;
    document.getElementById('framerate').innerHTML = quality.framerate;
});
```
However, the Amazon IVS player can adapt the playback quality based on current network conditions, so the quality can change as the stream is being played! To accommodate, we can listen for the `QUALITY_CHANGED` event and update the UI to display the proper value as the stream continues to play.

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerEventType.QUALITY_CHANGED, (quality) => {
    document.getElementById('quality').innerHTML = quality.name;
});
```
### Manually Setting Quality

Even though the player intelligently decides the best quality (for `STANDARD` streams), we can also let our viewers manually choose a different quality. Let’s add a button to toggle through the available qualities.

```html
<button class="btn btn-primary" id="toggle-quality">Toggle Quality</button>
```

A few globals to store the available and current quality values (we'll update these in the `PLAYING` and `QUALITY_CHANGED` handlers as you'll see in the final demo).

```js
let qualities, currentQuality;
```

And a handler for the button click event that will toggle the quality to the next available quality. 

> **Important Note:** There is a [known issue with the player](https://docs.aws.amazon.com/ivs/latest/userguide/player-web.html#web-issues) that ignores calls to `setQuality()` when native HTML5 controls are enabled. We'll work around this by temporarily disabling them before we set the quality, and then re-enabling them.

```js
document.getElementById('toggle-quality').addEventListener('click', () => {
    const qualIdx = qualities.findIndex((e) => e.name == currentQuality.name);
    const nextIdx = qualIdx < qualities.length - 1 ? qualIdx + 1 : 0;
    const playerEl = document.getElementById('video-player');
    playerEl.removeAttribute('controls');
    ivsPlayer.setQuality(qualities[nextIdx]);
    playerEl.setAttribute('controls', 'controls');
});
```

If we wanted to disable the native HTML controls - or just add an external button to control playback - we can add a button:

```html
<button class="btn btn-primary" id="toggle-playback">Toggle Playback</button>
```

And use the `play()` and `pause()` methods of the player.

```js
document.getElementById('toggle-playback').addEventListener('click', () => {
    ivsPlayer.isPaused() ? ivsPlayer.play() : ivsPlayer.pause();
});
```

That’s a lot of features for this demo, so let’s see it running! Notice how the latency, quality, and frame rate updates. Also try manually changing the quality by clicking on the button below the video player and toggling playback with the external button.

{% codepen https://codepen.io/recursivecodes/pen/dymmGwV %}

## Summary

We’ve covered a **ton** of great stuff in the Amazon IVS player SDK that can help us enhance the playback experience for our users, but we’ve barely scratched the surface of what the player can do. Check out the [full player documentation](https://aws.github.io/amazon-ivs-player-docs/1.11.0/web/index.html) for all the events, states, and methods that you can use for your production application. In our next post, we’re going to see how to add some interactivity into our stream via custom timed metadata.

If you have questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Photo by [Hannes Wolf](https://unsplash.com/@hannes_wolf?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/video-player?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText).
  