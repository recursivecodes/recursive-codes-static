---
title: "Amazon IVS Live Stream Playback with Chat Replay"
slug: "amazon-ivs-live-stream-playback-with-chat-replay-13d5"
author: "Todd Sharp"
date: 2023-01-27T08:00:00Z
summary: "🚨Note: As of version 1.26.0 of the Amazon IVS Player SDK, there is a documented method that..."
tags: ["javascript", "tailwindcss", "discuss"]
canonical_url: "https://dev.to/aws/amazon-ivs-live-stream-playback-with-chat-replay-13d5"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gms76167h6z2lw2u3547.jpeg"
---

> **🚨Note:** As of version 1.26.0 of the Amazon IVS Player SDK, there is a documented method that eliminates the need to use the undocumented method outlined in this post. Please update your player version and refer to [this blog post](https://dev.to/aws/amazon-ivs-live-stream-playback-with-chat-replay-using-the-sync-time-api-1d6a) to learn about the `getSyncTime` API.

In our last few posts, we've looked at how to [auto-record Amazon Interactive Video Service (Amazon IVS) live streams to Amazon S3](https://dev.to/aws/auto-recording-amazon-ivs-live-streams-to-s3-m64), and how to [log messages sent to an Amazon IVS chat room](https://dev.to/aws/archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j). In this post, we'll bring these two concepts together to complete the user experience and create on-demand playback of past live streams with full chat replay.

As seen in our last post, chat messages that are logged to the logging destination include a GMT based timestamp representing the date and time that the event was posted by the Amazon IVS chat room. To accomplish a true on-demand replay of a live stream complete with interactive chat replay of a message at the closest moment in time possible, we need to obtain a regular stream of GMT based timestamps from the recorded stream that we can use to determine what chat messages should be visible at any given point in time in the stream playback. There's not currently a documented source that provides this information, but let's poke around with the Amazon IVS [player SDK](https://aws.github.io/amazon-ivs-player-docs/1.14.0/web/index.html) and see if we can find something that will help us out with this task.

## Amazon IVS Stream Metadata

When trying to solve this problem, my first thought was to take a look at the metadata associated with a live stream to see if there is any valuable information hidden within it. Thankfully, there does appear to be a value in the regular stream of metadata that can be used for our chat playback purposes. In my testing, each stream contains ID3 metadata that appears to be injected by the Amazon IVS transcoding process. These ID3 tags contain a helpful timestamp that we can use to help with chat replay. To listen for these events, we can attach a handler that listens for the `IVSPlayer.MetadataEventType.ID3` event type. This event type **is** documented, but the [docs](https://aws.github.io/amazon-ivs-player-docs/1.16.0/web/index.html#metadataeventtype) don't say much about it or make any guarantees about what it may contain.

> **Want to Avoid Undocumented Features**? If you're concerned about using an undocumented feature, you could [inject your own timed metadata into your live stream](https://dev.to/aws/creating-interactive-live-streaming-experiences-using-timed-metadata-with-amazon-ivs-2kp6) with the proper timestamp when new messages are posted into your Amazon IVS chat rooms. Keep in mind that there are [limits to the size and frequency of posting `PutMetadata` events via the API](https://docs.aws.amazon.com/ivs/latest/userguide/service-quotas.html).

## Listening for Metadata Events

Let's set up an Amazon IVS player to playback a recorded stream using the Player SDK. First, we'll include the latest Amazon IVS player SDK via a `<script>` tag. 

> **New to Amazon IVS?** Check out the blog series [Getting Started with Amazon Interactive Video Service](https://dev.to/recursivecodes/series/19342). If you have questions on getting started, post a comment on any post in that series (or below)!

```html
<script src="https://player.live-video.net/1.16.0/amazon-ivs-player.min.js"></script>
```

As usual, we'll need to include a `<video>` element in our HTML markup that will be used for playback.

```html
<video id="video-player" muted controls autoplay playsinline></video>
```

Now we can create an instance of the IVS player. I'm hardcoding the URL below, but you can obtain this URL via the method described in [this post](https://dev.to/aws/auto-recording-amazon-ivs-live-streams-to-s3-m64). 

```js
const streamUrl = 'https://[redacted].cloudfront.net/ivs/v1/[redacted]/[redacted]/2022/11/17/18/6/[redacted]/media/hls/master.m3u8';
const videoEl = document.getElementById('video-player');
const ivsPlayer = IVSPlayer.create();
ivsPlayer.attachHTMLVideoElement(videoEl);
ivsPlayer.load(streamUrl);
ivsPlayer.play();
```

As mentioned above, to be useful for this purpose, we need a regular stream of timestamps. To figure out how often the ID3 metadata is received, let's add some timing. First, let's capture a timestamp as soon as the stream starts playing.

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerState.PLAYING, (evt) => {
  window.time = Date.now();
});
``` 

Next, we'll add the ID3 event listener, log the timing, and reset the timer.

```js
ivsPlayer.addEventListener(IVSPlayer.MetadataEventType.ID3, (evt) => {
  const now = Date.now();
  console.log(`${(now - window.time) / 1000} seconds since last event`);
  window.time = now;
});
```

Now we can start playback and observe the console to see how often the events are fired.

![ID3 event frequency](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-kqjhue26zygj4gv45b0i.png)

In my testing, the events are fired every 1-2 seconds. It's not realtime, but it's probably good enough for most scenarios. Now let's take a look at the event to see what data it contains.

```js
window.ivsPlayer.addEventListener(IVSPlayer.MetadataEventType.ID3, (evt) => {
  console.log(evt);
});
```

When we start playback with the listener above attached, we can see the following information logged to the browser console.

![ID3 event contents](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-vbb2kzrhnwpor3pwp1t1.png)

This is very interesting info, but a bit cryptic. Based on my testing, `transc_s` seems to be timestamp that we're after.  Let's modify the event handler to grab that timestamp and log it.

```js
window.ivsPlayer.addEventListener(IVSPlayer.MetadataEventType.ID3, (evt) => {
  const segmentMetadata = evt.find((tag) => tag.desc === 'segmentmetadata');
  const segmentMetadataInfo = JSON.parse(segmentMetadata.info[0]);
  const timestamp = segmentMetadataInfo['transc_s'];
  const timestampWithMs = timestamp * 1000;
  console.log(timestampWithMs);
  console.log(new Date(timestamp));
});
```

This produces the following output for my test.

![Parsed ID3 output](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zuyopc7svbr3v7ezshzj.png)

If I seek to a random moment in the video, the proper timestamp is always correct. This means that every 1-2 seconds we know a valid GMT timestamp of the moment in time that the event was capture in the stream. This means that we can assume that all chat messages that were sent prior to this timestamp have been posted to the chat and should be visible in the chat container.

## Retrieving the Chat Logs

When my page loads, I can utilize the method outlined in the [previous post](https://dev.to/aws/archiving-web-chat-messages-with-amazon-ivs-chat-logging-3o4j) in this series to retrieve the entire chat log for the stream and render it in the chat container `<div>`. Since no messages should be visible at the very start of the stream, I'll make sure that they call contain a class that hides them from the user and store a data attribute with the proper timestamp so that I can know which messages should be visible given any timestamp in the stream.

```js
window.chatLog = await getChatLogs(logGroupName, chatArn, startTime, endTime);
renderChat();
```

My `renderChat()` function handles posting each message to the chat container.

```js
const renderChat = () => {
  const chatContainer = document.getElementById('chat');
  window.chatLog.forEach(msg => {
    const msgTemplate = document.getElementById('chatMsgTemplate');
    const msgEl = msgTemplate.content.cloneNode(true);
    const ts = new Date(msg.event_timestamp).getTime() * 1000;
    msgEl.querySelector('.msg-container').setAttribute('data-timestamp', ts);
    msgEl.querySelector('.chat-username').innerHTML = msg.payload.Attributes.username;
    msgEl.querySelector('.msg').innerHTML = msg.payload.Content;
    chatContainer.appendChild(msgEl);
  });
};
```

Now I can modify the ID3 listener to call a `replayChat()` function and pass it the current timestamp.

```js
window.ivsPlayer.addEventListener(IVSPlayer.MetadataEventType.ID3, (evt) => {
  const segmentMetadata = evt.find((tag) => tag.desc === 'segmentmetadata');
  const segmentMetadataInfo = JSON.parse(segmentMetadata.info[0]);
  const timestamp = segmentMetadataInfo['transc_s'];
  const timestampWithMs = timestamp * 1000;
  replayChat(timestampWithMs);
});
```

In `replayChat()`, I can find all of the chat nodes that contain a timestamp less than or equal to the current timestamp from the recorded stream and show/hide any chat message based on that timestamp.

```js
const replayChat = (currentTimestamp) => {
  Array.from(document.querySelectorAll('[data-timestamp]')).forEach(node => {
    const chatMsgTs = Number(node.getAttribute('data-timestamp'));
    const isVisible = chatMsgTs <= currentTimestamp;
    if (isVisible) {
      node.classList.remove('d-none');
    }
    else {
      node.classList.add('d-none');
    }
  });
  const chatContainer = document.getElementById('chat');
  chatContainer.scrollTop = chatContainer.scrollHeight;
}
```

At this point, we have achieved the goal of playing back a recorded Amazon IVS live stream with full chat replay.

![Video playback with chat replay](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6n7y68rql7c9cohuqyrm.gif)

## Summary

In this post, we looked at how to combine recorded Amazon IVS live streams with logged chat messages to create an on-demand replay of a stream with properly timed chat messages. 