---
title: "Publishing Real-Time Video via WHIP to Amazon IVS"
slug: "publishing-real-time-video-via-whip-to-amazon-ivs-p7f"
author: "Todd Sharp"
date: 2025-08-29T15:19:12Z
summary: "Traditionally, Amazon IVS real-time stages are used in mobile or web applications. For these types of..."
tags: ["aws", "amazonivs", "webrtc", "whip"]
canonical_url: "https://dev.to/aws/publishing-real-time-video-via-whip-to-amazon-ivs-p7f"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6ktpdz6r4cnh8l8r5dzh.png"
imagecontain: true
---

Traditionally, Amazon IVS real-time stages are used in mobile or web applications. For these types of applications, we offer great SDKs for [web](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/broadcast-web.html), [iOS](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/broadcast-ios.html) and [Android](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/broadcast-android.html). But sometimes your application _isn't_ a web or mobile application. Or, sometimes your _viewers_ are on web or mobile but your _publisher_ isn't. There are several use cases that could fall into the "need to publish from something other than a browser or mobile application" bucket, and in this post I'd like to highlight a few various options. All of the options that we'll look at below are possible because Amazon IVS stages supports the WebRTC-HTTP Ingest Protocol ([WHIP](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/rt-stream-ingest.html)). So if you're looking to broadcast from a desktop app, headless server, or any other platform that supports WHIP, read on to learn more!

## Create a Stage

Before we can test out any of the following methods, we'll need to first create an Amazon IVS real-time stage. We can create a stage and a single participant token for testing out all of the methods below with the following command via the AWS CLI.

```bash
aws ivs-realtime create-stage \
  --name "whip-demo-stage" \
  --participant-token-configurations \
    userId=demo-whip-broadcaster,capabilities=PUBLISH,SUBSCRIBE,duration=720
```

This will give us output similar to the following:

```json
{
    "stage": {
        "arn": "arn:aws:ivs:us-east-1:[redacted]:stage/[redacted]",
        "name": "whip-demo-stage",
        "tags": {},
        "autoParticipantRecordingConfiguration": {
            ...
        },
        "endpoints": {
            "whip": "https://f99084460c35.global-bm.whip.live-video.net",
            ...
        }
    },
    "participantTokens": [
        {
            "participantId": "[redacted]",
            "token": "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.[redacted]",
            "userId": "demo-whip-broadcaster",
            "duration": 720,
            "capabilities": [
                "PUBLISH",
                "SUBSCRIBE"
            ]
        }
    ]
}
```

I've removed some bits for brevity, but the important part going forward is the `token` value. Take note of these and let's dig into the various options.

> ⚠️ **Note:** You'll notice that the WHIP endpoint returned is not the WHIP endpoint that we'll use below. The one we'll use is a _global_ endpoint (`https://global.whip.live-video.net`) which is load-balanced and will ultimately redirect to the most appropriate endpoint for each session. For more information, refer to the [docs](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html).

## 1️⃣ Broadcasting with OBS

Broadcasting via WHIP with OBS is quite easy! In _Settings_ -> _Stream_, choose `WHIP` under _Service_. Then enter the `https://global.whip.live-video.net` as the endpoint for your stage and your participant `token` as the _Bearer Token_. For best performance, make sure your stream matches the [recommended settings](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html) in the IVS docs.

![OBS Settings](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-hmc820sf51zy9rz2nrzp.png)

We're ready to start streaming! Click _Start Streaming_, then go to the stage details in the AWS console to view your stream.

![OBS Console Subscribe](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jikv0wikqxdup8p9prnx.png)

For the next few options, we'll be using the command line. To simplify the inputs, set your stage token as an environment variable.

```bash
$ export STAGE_TOKEN=eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.[redacted]
```

## 2️⃣ Broadcasting with Python's `aiortc`

Another option for broadcasting to a stage with WHIP is `aiortc` which is a library for Web Real-Time Communication (WebRTC) and Object Real-Time Communication (ORTC) in Python. With `aiortc`, we can publish from a user's webcam and microphone, or by using a pre-recorded video. I recently published a full [repo](https://github.com/aws-samples/sample-amazon-ivs-python-demos) of demos showing various use cases of `aiortc` with Amazon IVS, and to test out publishing an MP4, refer to the [`ivs-stage-publish.py`](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-publish/ivs-stage-publish.py) script in that repo. Once you've checked out the project and configured it as necessary, you can publish an MP4 like this:

```py
python ivs-stage-publish.py \
  --token $STAGE_TOKEN \
  --path-to-mp4 /path/to/an.mp4
```

The script output is pretty detailed, but once you see the following message, your video is ready to view.

```bash
2025-08-29 10:44:16,786 - INFO - 🎉 WebRTC publishing established!
```

![aiortc console view](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8aabuxoaa1aniccno7is.png)

## 3️⃣ Broadcasting with FFMPEG

Another option, which is relatively new, is to broadcast to an Amazon IVS stage via FFMPEG. Back in June FFMPEG [merged the long-outstanding WHIP muxer](https://www.phoronix.com/news/FFmpeg-Lands-WHIP-Muxer) into the mainline repo. You'll need to [compile it from source](https://trac.ffmpeg.org/wiki/CompilationGuide/macOS#CompilingFFmpegyourself) to enable WHIP (make sure to include the `--enable-muxer=whip` and `--enable-libharfbuzz` options). Once it's compiled you can use the same `endpoint` and `token` from earlier to publish an MP4.

```bash
ffmpeg -re -stream_loop -1 \
  -i /path/to/an.mp4 \
  -c:v libx264 -profile:v baseline -c:a copy \
  -f whip -authorization "$STAGE_TOKEN" \
  "https://global.whip.live-video.net"
```

Again, take a look at the AWS console to view your stream. (Yes, I'm using the same picture from earlier - it's literally the same result 😆).

![ffmpeg console view](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8aabuxoaa1aniccno7is.png)

## 4️⃣ Broadcasting with `srtc`

The final option that we'll look at in this post is an open-source library called `srtc` ([repo](https://github.com/kmansoft/srtc/)). This is a "simple" WebRTC implementation written in C++ as a side project by Kostya Vasilyev, one of the brilliant Amazon IVS engineers. You can use the library to create your own WebRTC application, but for simple testing you can download the [latest release](https://github.com/kmansoft/srtc/releases) for your OS and the `sintel.h264` file from the release page. Then, you can publish a test stream with the `srtc_publish` binary.

```bash
$ ./srtc_publish --url https://global.whip.live-video.net --token $STAGE_TOKEN --file ./sintel.h264 --loop
*** Using source file: ./sintel.h264
*** Using WHIP URL:    https://global.whip.live-video.net
*** Loading ./sintel.h264
*** PeerConnection state: connecting
*** PeerConnection state: connected
Played    25 video frames
```

> 🔇 **Note:** The command line demo publishes **video only**. The project is intended to be used as a dependency for building your own applications, so audio is not included in the command line demo utility.

Again, preview the stream in the AWS console.

![srtc preview](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-lvxf7ut99uanoyvw17k6.png)

## Summary

In this post, we've looked at several ways to publish to an Amazon IVS real-time stage using the WebRTC HTTP Ingest Protocol (WHIP). I hope this post helped you to realize the possibilites of WebRTC and real-time streaming outside of traditional web and mobile applications and maybe inspired you to think beyond the "usual" approach to publishing real-time video. If you have questions, or ideas about how you might use WHIP with Amazon IVS, please share them below!
