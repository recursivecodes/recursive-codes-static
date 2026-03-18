---
title: "Broadcasting to an Amazon IVS Real-Time Stream with WHIP from OBS"
slug: "broadcasting-to-an-amazon-ivs-real-time-stream-with-whip-from-obs-p67"
author: "Todd Sharp"
date: 2024-02-22T16:44:27Z
summary: "Until recently, broadcasting to an Amazon Interactive Video Service (Amazon IVS) real-time stage..."
tags: ["aws", "amazonivs", "webrtc", "livestreaming"]
canonical_url: "https://dev.to/aws/broadcasting-to-an-amazon-ivs-real-time-stream-with-whip-from-obs-p67"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-d3bio2mm9mjd8cfc9uhy.png"
imagecontain: true
---

Until recently, broadcasting to an Amazon Interactive Video Service (Amazon IVS) real-time stage required developers to utilize one of our Broadcast SDKs (web and mobile). Behind the scenes, the SDKs abstract all of the logic required to initialize a peer connection and broadcast the user's video to the stage. This makes it easier for developers who want to integrate real-time streaming in their applications, but also limits the options for the end users who will ultimately be broadcasting to that stage to only web and mobile based client software. The addition of support for any WHIP-compatible encoder opens the door for additional options for media publish to a real-time stage.

## WHIP??

Bit of a weird name for a protocol, I'll admit 🤷🏻‍♂️. But, I'm not in charge of naming things (which is probably a good thing). WHIP stands for WebRTC-HTTP Ingest Protocol which is an IETF protocol that standardizes the process of the one-time exchange of Session Description Protocol (SDP) offers and answers using HTTP `POST` requests.

> 💡 **Not Down With SDP?** Check out 'What is the Session Description Protocol (SDP)?' on [WebRTC for the Curious](https://webrtcforthecurious.com/docs/02-signaling/#what-is-the-session-description-protocol-sdp).

As you may have guessed from the name, the WHIP protocol refers to **ingest** (AKA 'broadcasting' or 'publishing') only. There's a separate protocol called WHEP that deals with egress (AKA 'viewing' or 'subscribing'). If you're struggling with insomnia 🥱, feel free to read the entire IETF draft for [WHIP](https://datatracker.ietf.org/doc/draft-ietf-wish-whip/) or [WHEP](https://datatracker.ietf.org/doc/draft-ietf-wish-whep/).

## Broadcasting to an Amazon IVS Stage with OBS

OBS is widely-used because of it's advanced production features like scene transitions, overlays, easy screen sharing, audio mixing and more. To broadcast to an Amazon IVS stage from OBS, the user will need at least OBS version 30 and a stage participant token. These tokens usually have an expiration time of 12 hours (the default), but this can be extended up to 14 days.

To try it out, generate a stage participant token via an AWS SDK, the AWS CLI, or the Amazon IVS management console and head into the 'Settings' dialog in OBS.

In the 'Stream' tab, choose 'WHIP' as the 'Service', enter `https://global.whip.live-video.net` as the 'Server' and paste a valid stage participant token as the 'Bearer Token'.

![OBS Stream tab](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3uxyu4hwknhgxx57s1io.png)

Note: OBS will warn you that WHIP broadcasting requires Opus audio encoding. This is expected, so select 'Yes' to continue.

![Opus warning](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3jgjs3tz6owevw6z38ia.png)

Next, head to the 'Output' tab and make sure that the 'Output Mode' is 'Advanced'.

![Advanced output mode](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-37oh5uiyhfxx0ul9p06k.png)

For the best performance, make sure your 'Bitrate' is at or below `2500 Kbps`, use a 'Keyframe Interval' of `1s` or `2s`, set 'CPU Usage Preset' to `ultrafast` and 'Tune' to `zerolatency`.

![Output streaming settings](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4xtn0z4pvhpo8ali3qhk.png)

Now exit from the 'Settings' dialog and click 'Start Streaming' and you'll be broadcasting to the stage.

![Streaming with OBS](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-4dydq4khkd9vr2ictb1k.png)

Refer to the docs on [OBS and WHIP Support](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html) for more info.

## Broadcasting to an Amazon IVS Stage with GStreamer

If you're a fan of the open source multimedia framework [GStreamer](https://gstreamer.freedesktop.org/), you can take advantage of WHIP support as well. Here's a simple pipeline that could be used to publish a webcam and microphone to a stage. This pipeline is specific to MacOS, but can be adapted to any supported OS. Make sure to obtain and set a participant token into `IVS_STAGE_TOKEN` (or include a raw token instead).

```bash
gst-launch-1.0 \
  avfvideosrc device-index=0 \
  ! videoconvert \
  ! x264enc tune=zerolatency bitrate=2500 speed-preset=ultrafast \
  ! rtph264pay \
  ! 'application/x-rtp,media=video,encoding-name=H264,payload=97,clock-rate=90000,width=1280,height=720,framerate=30/1' \
  ! whip.sink_0 autoaudiosrc wave=4 \
  ! audioconvert \
  ! opusenc \
  ! rtpopuspay \
  ! 'application/x-rtp,media=audio,encoding-name=OPUS,payload=96,clock-rate=48000,encoding-params=(string)2' \
  ! whip.sink_1 \
  whipsink \
  name=whip \
  auth-token=$IVS_STAGE_TOKEN \
  whip-endpoint=https://global.whip.live-video.net/
```

## Summary

In this post, we learned how to publish to an Amazon IVS real-time stage via WHIP-compatible encoders. This support opens up many possibilities for real-time streaming with Amazon IVS. Refer to the Amazon IVS Real-Time User Guide page on [OBS and WHIP Support](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html) for further details. If you have any questions or ideas for possible use-cases drop a comment below!
