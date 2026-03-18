---
title: "Enhancing Your Amazon IVS Web Broadcast with Screen Sharing and Canvas Overlays"
slug: "enhancing-your-amazon-ivs-web-broadcast-with-screen-sharing-and-canvas-overlays-4dnd"
author: "Todd Sharp"
date: 2022-10-07T12:32:31Z
summary: "In our last post, we looked at how to broadcast to an Amazon Interactive Video Service (Amazon IVS)..."
tags: ["aws", "livestreaming", "cloud", "amazonivs"]
canonical_url: "https://dev.to/aws/enhancing-your-amazon-ivs-web-broadcast-with-screen-sharing-and-canvas-overlays-4dnd"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4zd1z4msswsvq9w6ycg4.jpg"
---

In our [last post](https://dev.to/aws/broadcasting-to-your-amazon-ivs-live-stream-from-a-browser-2343), we looked at how to broadcast to an Amazon Interactive Video Service (Amazon IVS) live stream directly from a web browser instead of relying on third-party streaming software. Web Broadcast is a versatile tool for creating all-in-one solutions for your live streaming applications, and today we’ll look at enhancing your application with screen sharing and canvas overlays.

## But Why?

Many times our cameras and microphones are “good enough”, but sometimes broadcasters need additional options. For example, think of an online conference or webinar. Isn’t it better to see the presenter’s slide deck or watch them demo an application instead of just watching them talk about their content? What about the most popular application for live streaming - gaming? Would you watch a stream of someone playing Fortnite if the video was _only_ their webcam? Of course not! As you can see, being able to share a screen is a critical piece of the interactive, live streaming puzzle.

But there’s another piece missing. Since the creation of television, graphic overlays have been used to enhance the viewer's experience. News broadcasts have scrolling tickers and branding graphics. Gaming streams overlay chat and game stats. Sports broadcasts incorporate player and team information, current score, and play clock, and much more. Overlay graphics are a part of engaging video, and your live stream is no doubt improved by including them.

## But How?

We’ve established the necessity for screen sharing and graphic overlays, but certainly this kind of advanced functionality must be complex to implement with the Amazon IVS Web Broadcast SDK, right? Of course not - it’s straightforward and doesn’t take much code at all. Let’s build on the web broadcast demo from the last post and add features to that example.

### Adding Screen Sharing

We’ll start with screen sharing. First, we’ll need to add a button to the UI that the broadcaster can click when they are ready to share their screen. We’ll add this below the ‘Stream’ button that we added in the last post. If you haven’t read that post yet, I encourage you to do that now. You can also check out the full source for this demo on [CodePen](https://codepen.io/recursivecodes/pen/KKoEOxE).

```html
<button id="screenshare-btn" class="btn btn-outline-primary mb-3">Share Screen</button>
```

Next, let’s add an event handler to capture button clicks.

```js
document.getElementById('screenshare-btn').addEventListener('click', toggleScreenshare);
```

And define the `toggleScreenshare()` function that will be called on button click.

```js

const toggleScreenshare = async (e) => {
  const screenshareBtn = e.currentTarget;
  if(!broadcastReady()) return;
  if (!window.isSharingScreen) {
    await shareScreen();
    if (!window.isBroadcasting) startBroadcast();
    screenshareBtn.innerHTML = 'Stop Screen Share';
    screenshareBtn.classList.remove('btn-outline-primary');
    screenshareBtn.classList.add('btn-danger');
    window.isSharingScreen = true;
  }
  else {
    screenshareBtn.innerHTML = 'Share Screen';
    screenshareBtn.classList.add('btn-outline-primary');
    screenshareBtn.classList.remove('btn-danger');
    window.isSharingScreen = false;
    await createVideoStream();
  }
};
```

In the `toggleScreenshare()` function above, we make sure that our application is ready to broadcast, and if so, we call the `shareScreen()` function and update the UI to reflect the current application state. If the user is already sharing the screen, we instead call `createVideoStream()` which switches the video source for the stream back to the user’s web camera. Let’s look at `shareScreen()`:

```js
const shareScreen = async () => {
  if (window.broadcastClient && window.broadcastClient.getVideoInputDevice('camera1')) {
    window.broadcastClient.removeVideoInputDevice('camera1');
  }
  window.videoStream = await navigator.mediaDevices.getDisplayMedia();
  if (window.broadcastClient) {
    window.broadcastClient.addVideoInputDevice(window.videoStream, 'camera1', { index: 0 });
  }
};
```

This function looks very similar to the `createVideoStream()` function that we created in the last post. The `shareScreen()` function first removes any existing video input device on the broadcast client, gets a new media source, and then adds it to the broadcast client. But instead of calling `getUserMedia()` like we did with `createVideoStream()`, this time we use `navigator.mediaDevices.getDisplayMedia()` which uses the [Screen Capture API](https://developer.mozilla.org/en-US/docs/Web/API/Screen_Capture_API/Using_Screen_Capture) and allows the user to select either their entire desktop, a specific window, or a single browser tab to use as a media source. The media source returned by `getDisplayMedia()` implements the `MediaStream` ([docs](https://developer.mozilla.org/en-US/docs/Web/API/MediaStream)) interface which means we can use it anywhere a `MediaStream` is expected. If we check the Amazon IVS Web Broadcast [SDK docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient#addvideoinputdevice), we see that `addVideoInputDevice()` expects a `MediaStream`, so we’re good to use this as a source for our broadcast!

> The broadcast client supports multiple video sources! If we wanted to, we could add a camera source by giving each source a unique name and specifying a different `index` for each source. Using this approach, we could include the user’s web cam on top of the screen share - perhaps in a lower corner of the screen - to create a more engaging experience.

If we ran our application at this point and clicked the ‘Share Screen’ button, we would get prompted to select the display device:

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3ct69xrdpfx1l9p9upms.png)

After we select a display device, we can see the chosen display in the local preview.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6ih0auhxpj3138t5hymr.png)

And we can confirm that our screen is being broadcast to our live stream.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-f6ddg1zx70f7kup22tcn.png)

### Adding Text and Graphic Overlays

The Web Broadcast SDK also gives us the ability to add text or images as overlays to our live stream. Let’s add another button:

```html
<button id="overlay-btn" class="btn btn-secondary">Overlay</button>
```

And another event listener.

```js
document.getElementById('overlay-btn').addEventListener('click', showOverlay);

```

And define the `showOverlay()` function.

```js
const showOverlay = () => {
  const preview = document.getElementById('broadcast-preview');
  const overlay = document.createElement('canvas');
  overlay.width = preview.width;
  overlay.height = preview.height;
  overlay.style.display = 'none';

  let ctx = overlay.getContext('2d');
  ctx.fillStyle = 'black';
  ctx.globalAlpha = 0.5;

  ctx.fillRect(0, overlay.height - 220, overlay.width, 220);

  ctx.globalAlpha = 1;
  ctx.strokeStyle = 'black';
  ctx.lineWidth = 3;
  ctx.font = 'bold 120px Arial';
  ctx.fillStyle = 'white';
  ctx.fillText('Amazon IVS Web Broadcast', 30, overlay.height - 100);

  ctx.font = 'bold 40px Arial';
  ctx.fillStyle = 'white';
  ctx.fillText('Canvas Overlay Demo', 40, overlay.height - 40);
  document.querySelector('body').appendChild(overlay);

  window.broadcastClient.addImageSource(overlay, 'overlay1', { index: 1 });

  setTimeout(() => {
    window.broadcastClient.removeImage('overlay1');
    overlay.remove();
  }, 10000);
};

```

In this function, we’re creating a new `<canvas>` element, adding some styles and text to it, appending it to the DOM, and finally adding it to our broadcast client via `addImageSource()` ([docs](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-reference/classes/AmazonIVSBroadcastClient#addimagesource)). Finally, we create a timer to remove the canvas overlay after 10 seconds. This effect is a nice way to add a ‘lower third’ to your stream that includes information about the broadcaster or any other relevant information. Now if we click the ‘Overlay’ button, we can see our lower third displayed in the preview.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-y2f8liczll8abvj988dz.png)

And in our live stream.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bzm2rcwjkvywu7tleo1x.png)

Hopefully, you can see just how powerful this functionality is for your live streams. It’s certainly possible to add graphic overlays on top of the player on the client side, but by adding them at the broadcast source, they become a permanent part of the broadcast and will exist in any recorded versions of the live stream. 

## Try it out!

You can try out this [demo on CodePen](https://codepen.io/recursivecodes/pen/KKoEOxE) by opening it in a new tab and plugging in your own stream endpoint and stream key. 

## Summary 

In this post, we learned how to enhance our live streams with screen sharing and canvas overlays. For further reading, please refer to the [SDK docs](https://aws.github.io/amazon-ivs-web-broadcast/). If you have questions, leave a comment  or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by [heinzremyschindler](https://pixabay.com/users/heinzremyschindler-5840905/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=2482016) from [Pixabay](https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=2482016)
