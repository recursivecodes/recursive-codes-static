---
title: "Broadcasting to Your Amazon IVS Live Stream From a Browser"
slug: "broadcasting-to-your-amazon-ivs-live-stream-from-a-browser-2343"
author: "Todd Sharp"
date: 2022-09-23T13:00:12Z
summary: "Welcome back to this series where we're learning how to get started with live streaming in the cloud..."
tags: ["aws", "cloud", "livestreaming", "amazonivs"]
canonical_url: "https://dev.to/aws/broadcasting-to-your-amazon-ivs-live-stream-from-a-browser-2343"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ro3vlbjyc1kr4mwdv11p.jpg"
---

Welcome back to this series where we're learning how to get started with live streaming in the cloud with Amazon Interactive Video Service (Amazon IVS). If it's your first time joining us, I encourage you to catch up by checking out the rest of the posts in the series!

Previously in this series we looked at how to broadcast to our live stream from third-party desktop software (https://dev.to/aws/get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg). In today's post, we're going to switch gears and look at a different option - broadcasting to our live stream directly from a browser! 

## Why?

Good question! There are tons of desktop options for live streaming, and many of them offer features like custom scenes, backgrounds, animated transitions, and more. But sometimes the business rules of our applications don't require all of those features. Sometimes you just need to live stream a camera and microphone - and maybe share your desktop display with your viewers. Desktop streaming solutions require the installation and knowledge of third-party software. That's not always desired (or even an option). For these reasons (among others), the Amazon IVS web broadcast SDK gives us the ability to stream to our channel directly from web browsers. 

>Broadcasting from a browser doesn't mean that you can't have the fancy backgrounds, overlays, animations and transitions that are available in many desktop offerings. There are tons of things possible with modern HTML and JavaScript, and we'll look at some of those in a future post. Today, we'll focus on basic camera and microphone streaming. 


##  Collecting Our Stream Information

Like many of the previous posts in this series, we're going to build a demo using CodePen. 

We'll need a few bits of information in order to use the web broadcast SDK. 

### Using the Amazon IVS Management Console

One way we can grab these bits is by logging into the Amazon IVS Management Console (https://console.aws.amazon.com/ivs) and selecting the channel that we are working with. In the channel details, scroll down to the **Stream configuration** section and copy the **Ingest endpoint** and **Stream key**.

![Amazon IVS channel stream configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jqwe0t85jrt18s09rbt0.png)

### Using the AWS CLI

If you’d rather collect your **Ingest endpoint** and **Stream key** via the CLI, you can do so with a few separate calls. First, we’ll need the channel **ARN**. We can get this via a call to `list-channels` ([docs] (https://docs.aws.amazon.com/cli/latest/reference/ivs/list-channels.html)) and using the channel **Name** as a filter. In this example, `demo-channel` is my channel **Name**.

```bash
$ CHANNEL_ARN=$(aws ivs list-channels --filter-by-name "demo-channel" --query "channels[0].arn" --output text)
```
Now we can obtain the **Ingest endpoint** via a call to `get-channel` ([docs](https://docs.aws.amazon.com/cli/latest/reference/ivs/get-channel.html)).

```bash
$ aws ivs get-channel --arn=$CHANNEL_ARN --query "channel.ingestEndpoint" --output text
```

To get the **Stream key**, we first need to obtain its **ARN**. We can get this via `list-stream-keys` ([docs](https://docs.aws.amazon.com/cli/latest/reference/ivs/list-stream-keys.html)).

```bash
$ STREAM_KEY_ARN=$(aws ivs list-stream-keys --channel-arn=$CHANNEL_ARN --query "streamKeys[0].arn" --output text)
```

Finally, we retrieve the **Stream key** value with `get-stream-key` ([docs](https://docs.aws.amazon.com/cli/latest/reference/ivs/get-stream-key.html)).

```bash
$ aws ivs get-stream-key --arn=$STREAM_KEY_ARN --query "streamKey.value" --output text
```
### Using an AWS SDK

If you want to use an SDK to retrieve your **Ingest endpoint** and **Stream key**, refer to the [SDK documentation](https://aws.amazon.com/developer/tools/) for your favorite language. Here's an example of how you could accomplish this with the Node.JS SDK:

```js
import {
    IvsClient,
    GetChannelCommand,
    GetStreamKeyCommand,
    ListChannelsCommand,
    ListStreamKeysCommand
} from "@aws-sdk/client-ivs";

const client = new IvsClient();
const channelName = 'demo-channel';

// list channels, filtering by name, to get the ARN
const listChannelsRequest = new ListChannelsCommand({ filterByName: channelName });
const listChannelsResponse = await client.send(listChannelsRequest);

if (!listChannelsResponse.channels.length) {
    console.warn(`No channels matching '${channelName}' were found!`);
    const process = await import('node:process')
    process.exit(1);
}

const channelArn = listChannelsResponse.channels[0].arn;
console.log(`Channel ARN: ${channelArn}`);

// get the channel (by ARN) to get ingestEndpoint
const getChannelRequest = new GetChannelCommand({ arn: channelArn });
const getChannelResponse = await client.send(getChannelRequest);
const ingestEndpoint = getChannelResponse.channel.ingestEndpoint;
console.log(`Ingest Endpoint: ${ingestEndpoint}`);

// list stream keys to get the stream key ARN
const listStreamKeysRequest = new ListStreamKeysCommand({ channelArn: channelArn });
const listStreamKeysResponse = await client.send(listStreamKeysRequest);
const streamKeyArn = listStreamKeysResponse.streamKeys[0].arn;

// get stream key
const getStreamKeyRequest = new GetStreamKeyCommand({ arn: streamKeyArn });
const getStreamKeyResponse = await client.send(getStreamKeyRequest);
const streamKey = getStreamKeyResponse.streamKey.value;
console.log(`Stream Key: ${streamKey}`);
```

Running the code above with a valid `channelName` would produce output similar to the following.

```bash
Channel ARN: arn:aws:ivs:us-east-1:<redacted>:channel/<redacted>
Ingest Endpoint: <redacted>.global-contribute.live-video.net
Stream Key: sk_us-east-1_<redacted>
```

##  Building the Web Broadcast Demo

To get started, we need to include the web broadcast SDK in our page. 

```html
<script src="https://web-broadcast.live-video.net/1.1.0/amazon-ivs-web-broadcast.js"></script>
```

Before we look at using the web broadcast SDK, let's add some HTML markup to the page. We'll start with a `<canvas>` element  that we can use for a live preview of will be broadcasted to our viewers. We'll add two `<select>` elements to let the broadcaster select the camera and microphone used to capture audio and video. Since this demo is running in CodePen, we'll also add a few text inputs to capture the **Ingest endpoint** and **Stream key** that are required to configure the broadcast client. We'll need a button to start the broadcast, so we'll add that below the text inputs. To handle layout and styling, I've included Bootstrap in the CodePen and applied some relevant classes to the layout and inputs.

```html
<div class="row">
  <div class="col-sm-6 offset-sm-3">
    <span class="badge bg-info fs-3 d-none mb-3 w-100" id="online-indicator">Online</span>
    <canvas id="broadcast-preview" class="rounded-4 shadow w-100"></canvas>
  </div>
</div>

<div class="d-flex flex-column col-sm-6 offset-sm-3 p-1">
  <select name="cam-select" id="cam-select" class="form-select w-100 mb-3"></select>
  <select name="mic-select" id="mic-select" class="form-select w-100 mb-3"></select>
  <input type="text" name="endpoint" id="endpoint" class="form-control w-100 mb-3" placeholder="Ingest Endpoint" />
  <input type="password" name="stream-key" id="stream-key" class="form-control w-100 mb-3" placeholder="Stream Key" />
  <button class="btn btn-primary w-100 shadow" id="stream-btn">Stream</button>
</div>
```

If we run the demo, we can see the layout of the demo. Obviously there won't be anything in the canvas preview or the select elements, because we haven't populated them yet.

![Web broadcast layout](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-md2ralfa8vbp3tnjrdpv.png)
 
### Wiring Up the Broadcast Preview, Cam and Mic

Let's wire up the demo with some JavaScript so that we can populate the camera and microphone dropdowns and preview the broadcaster's camera. Add an `init()` function and a handler to call this function when the DOM is ready.

```js
const init = async () => {

};
document.addEventListener('DOMContentLoaded', init);
```
 
For security, browsers won't let us access a user's cam and mic until we've asked for (and received) permission. 

![Get permission first](https://media.giphy.com/media/chzGeSOXUUT8cFdJIe/giphy.gif)

Let's add a `handlePermissions()` function to take care of this.

```js
const handlePermissions = async () => {
  let permissions = { video: true, audio: true };
  try {
    await navigator.mediaDevices.getUserMedia(permissions);
  }
  catch (err) {
    console.error(err.message);
    permissions = { video: false, audio: false };
  }
  if (!permissions.video) console.error('Failed to get video permissions.');
  if (!permissions.audio) console.error('Failed to get audio permissions.');
};
```

The `handlePermissions()` function uses `navigator.mediaDevices.getUserMedia()` to obtain both `video` and `audio` permissions via the `permissions` object. We'll call this function as the very first action inside of our `init()` function.


```js
const init = async () => {
  await handlePermissions();
};
```

Next, we'll grab a list of video and audio (cam and mic) devices via `navigator.mediaDevices.enumerateDevices()` and populate the `<select>` elements. We'll set the first device that we find as the 'selected' device by default.

```js
const getDevices = async () => {
  const cameraSelect = document.getElementById('cam-select');
  const micSelect = document.getElementById('mic-select');
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((d) => d.kind === 'videoinput');
  const audioDevices = devices.filter((d) => d.kind === 'audioinput');
  videoDevices.forEach((device, idx) => {
    const opt = document.createElement('option');
    opt.value = device.deviceId;
    opt.innerHTML = device.label;
    if (idx === 0) {
      window.selectedVideoDeviceId = device.deviceId;
      opt.selected = true;
    }
    cameraSelect.appendChild(opt);
  });
  audioDevices.forEach((device, idx) => {
    const opt = document.createElement('option');
    opt.value = device.deviceId;
    opt.innerHTML = device.label;
    if (idx === 0) {
      window.selectedAudioDeviceId = device.deviceId;
      opt.selected = true;
    }
    micSelect.appendChild(opt);
  });
};
```

And update our `init()` function to call `getDevices()`.

```js
const init = async () => {
  await handlePermissions();
  await getDevices();
};
```

### Creating the Broadcast Client

Now that we have permissions and have populated our available devices, we can [create an instance of the broadcast client](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-guides/introduction#how-to-create-an-instance-of-the-amazonivsbroadcastclient). 

```js
const init = async () => {
  await handlePermissions();
  await getDevices();

  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.STANDARD_LANDSCAPE,
  });
};
```

Depending on the type of channel that you are broadcasting to, you may have to update the `streamConfig` value to one of the available presets:

```js
IVSBroadcastClient.BASIC_LANDSCAPE;
IVSBroadcastClient.STANDARD_LANDSCAPE;
IVSBroadcastClient.BASIC_PORTRAIT;
IVSBroadcastClient.STANDARD_PORTRAIT;
```

### Creating the Video and Audio Streams

Now that we have a broadcast client, we can [add our video and audio input devices to the client](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-guides/introduction#add-device-to-stream) via `addVideoInputDevice()` and `addAudioInputDevice()` respectively. We will reuse these functions to allow the broadcaster to switch their cam and mic mid-stream if they want to, so we'll add some logic to first remove any existing devices before we add the device.
 
```js
const createVideoStream = async () => {
  if (window.broadcastClient && window.broadcastClient.getVideoInputDevice('camera1')) window.broadcastClient.removeVideoInputDevice('camera1');
  const streamConfig = IVSBroadcastClient.STANDARD_LANDSCAPE;
  window.videoStream = await navigator.mediaDevices.getUserMedia({
    video: {
      deviceId: { exact: window.selectedVideoDeviceId },
      width: {
        ideal: streamConfig.maxResolution.width,
        max: streamConfig.maxResolution.width,
      },
      height: {
        ideal: streamConfig.maxResolution.height,
        max: streamConfig.maxResolution.height,
      },
    },
  });
  if (window.broadcastClient) window.broadcastClient.addVideoInputDevice(window.videoStream, 'camera1', { index: 0 });
};
```

The `captureAudioStream()` function is similar to the `captureVideoStream()` function:

```js
const createAudioStream = async () => {
  if (window.broadcastClient && window.broadcastClient.getAudioInputDevice('mic1')) window.broadcastClient.removeAudioInputDevice('mic1');
  window.audioStream = await navigator.mediaDevices.getUserMedia({
    audio: {
      deviceId: window.selectedAudioDeviceId
    },
  });
  if (window.broadcastClient) window.broadcastClient.addAudioInputDevice(window.audioStream, 'mic1');
};
```

Let's change the `init()` function to call these.

```js
const init = async () => {
  await handlePermissions();
  await getDevices();

  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.STANDARD_LANDSCAPE,
  });

  await createVideoStream();
  await createAudioStream();
};
```

Next, we'll add two functions to update the selected `deviceId` when the `<select>` value changes. We'll add event listeners for these later on, so just add the functions for now.

```js
const selectCamera = async (e) => {
  window.selectedVideoDeviceId = e.target.value;
  await createVideoStream();
};

const selectMic = async (e) => {
  window.selectedAudioDeviceId = e.target.value;
  await createAudioStream();
};

```

### Previewing the Video Stream

Now that we've added our video input device to the stream, we can [preview it](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-guides/introduction#set-up-a-stream-preview) in the `<canvas>` element via a `previewVideo()` function.

```js
const previewVideo = () => {
  const previewEl = document.getElementById('broadcast-preview');
  window.broadcastClient.attachPreview(previewEl);
};
```

And add a call to `previewVideo()` to `init()`.

```js
const init = async () => {
  await handlePermissions();
  await getDevices();

  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.STANDARD_LANDSCAPE,
  });

  await createVideoStream();
  await createAudioStream();
  
  previewVideo();
};
```

### Getting Ready to Broadcast

We're just about ready to broadcast to our channel. Let's add a `toggleBroadcast()` function to handle clicks on the 'Stream' button.

```js
const toggleBroadcast = () => {
  if(!window.isBroadcasting) {
    startBroadcast();
  }
  else {
    stopBroadcast();
  }
};
```
Here we check to see if the stream is currently broadcasting and call `startBroadcast()` or `stopBroadcast()`.

The `startBroadcast()` function will check for the **Ingest endpoint** and **Stream key**, update the UI and then call `startBroadcast()` on the `broadcastClient` to [begin the broadcast](https://aws.github.io/amazon-ivs-web-broadcast/docs/sdk-guides/introduction#start-a-broadcast).

```js
const startBroadcast = () => {
  const key = document.getElementById('stream-key').value;
  const endpoint = document.getElementById('endpoint').value;
  const streamBtn = document.getElementById('stream-btn');
  const onlineIndicator = document.getElementById('online-indicator');
  
  if(!key && !endpoint) {
    alert('Please enter a Stream Key and Ingest Endpoint!');
  }
  else {
    window.broadcastClient
      .startBroadcast(key, endpoint)
      .then(() => {
        streamBtn.innerHTML = 'Stop';
        onlineIndicator.classList.remove('d-none');
        window.isBroadcasting = true;
      })
      .catch((error) => {
        streamBtn.innerHTML = 'Stream';
        onlineIndicator.classList.add('d-none');
        window.isBroadcasting = false;
        console.error(error);
      });  
  }
};
```

The `stopBroadcast()` function, as you might guess, will call `stopBroadcast()` on the `broadcastClient` and update the UI.

```js
const stopBroadcast = () => {
  window.broadcastClient.stopBroadcast();
  window.isBroadcasting = false;
  document.getElementById('online-indicator').classList.add('d-none');
}
```

Finally, we'll finish the `init()` function by adding event listeners to update the cam and mic devices, and call `toggleBroadcast()` when the user clicks the 'Stream' button.

```js
const init = async () => {
  await handlePermissions();
  await getDevices();

  window.broadcastClient = IVSBroadcastClient.create({
    streamConfig: IVSBroadcastClient.STANDARD_LANDSCAPE,
  });

  await createVideoStream();
  await createAudioStream();
  
  previewVideo();
  
  document.getElementById('cam-select').addEventListener('change', selectCamera);
  document.getElementById('mic-select').addEventListener('change', selectMic);
  document.getElementById('stream-btn').addEventListener('click', toggleBroadcast);
};
```

##  Broadcasting to an Amazon IVS Channel from the Web

We're ready for broadcast! [Open the demo](https://codepen.io/recursivecodes/pen/YzaLpdJ) in a separate browser tab to get started. 

> **Heads Up!** Because CodePen runs embeds in an `<iframe>`, we can't embed this demo directly into this blog post because of the sandboxed nature of the `<iframe>` tag on dev.to. Please [view the CodePen directly in a separate browser tab](https://codepen.io/recursivecodes/pen/YzaLpdJ).

Plug in your **Ingest endpoint** and **Stream key** and click 'Stream' to try it out. You can verify that your stream is broadcasting via the 'Live Preview' in the [Amazon IVS Management Console](https://console.aws.amazon.com/ivs) after the UI updates to confirm that your stream is online. 

> **Note:** If your stream doesn't start broadcasting, verify your ingest endpoint and stream key are input exactly as shown in the Amazon IVS Management Console. If you're still having issues, check to see if a VPN connection is blocking the required port. If so, re-try the demo when disconnected from your VPN.

##  Summary 

In this post, we learned how to broadcast to our Amazon IVS channel via the Amazon IVS Web Broadcast SDK. For further reading, please refer to the [SDK docs](https://aws.github.io/amazon-ivs-web-broadcast/). If you have questions, leave a comment below or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by [Michi S](https://pixabay.com/users/moinzon-2433302/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=4901461) from [Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=4901461)