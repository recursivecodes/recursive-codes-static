---
title: "Broadcasting to an Amazon IVS Live Stream in Headless Mode with FFMPEG"
slug: "broadcasting-to-an-amazon-ivs-live-stream-in-headless-mode-with-ffmpeg-2i73"
author: "Todd Sharp"
date: 2022-12-06T14:08:51Z
summary: "When broadcasting to a live stream, you're probably going to use some sort of desktop streaming..."
tags: ["scala"]
canonical_url: "https://dev.to/aws/broadcasting-to-an-amazon-ivs-live-stream-in-headless-mode-with-ffmpeg-2i73"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wo69ht7iiqzs2hrb5p0s.png"
---

When broadcasting to a live stream, you're probably going to use some sort of desktop streaming software like OBS, Streamlabs, or any of the other great programs available for the task as we've looked at [previously on this blog](https://dev.to/aws/get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg). Another option we've looked at here is [broadcasting from a browser](https://dev.to/aws/broadcasting-to-your-amazon-ivs-live-stream-from-a-browser-2343) with the Amazon Interactive Video Service (Amazon IVS) Web Broadcast SDK. These two options for broadcasting cover the majority of use cases, but they aren't the only options available to us. In this post, we'll discuss another option - broadcasting headless (IE: without a user interface) via the command line with FFMPEG.

This topic is well [covered in the Amazon IVS user guide](https://docs.aws.amazon.com/ivs/latest/userguide/streaming-config.html#streaming-config-stream-ffmpeg), but wanted to go a bit deeper and discuss how we might extend the solution for specific use cases. There may be times that you'll want to live stream something without the immediate visual feedback provided by a user interface. For example maybe you need to broadcast a pre-recorded video on our channel? Or, how about re-streaming from an IP camera on your network that utilizes a protocol like [RTSP](https://en.wikipedia.org/wiki/Real_Time_Streaming_Protocol) or some other format that may not be the RTMP format required by Amazon IVS? There are a handful of use cases, so let's dig into a few of them.

> **Note:** To avoid breaking each statement down and discussing what each argument does, the embedded snippets below are commented. This will probably be bad for copy/paste usage, so each snippet has a link to a uncommented version of the command on GitHub. 

To play along at home, make sure you've got [FFMPEG](https://www.ffmpeg.org/download.html) installed. All of the commands below were tested on MacOS, so some modification may be required if you're using a different OS. Finally, I should mention that I'm **far** from an FFMPEG expert, but have fully tested every command as of original publishing date of this post on version `5.1.2`.

> **One More Thing:** I know it's tempting to just copy and paste commands, but please take the time to read the comments and refer to the FFMPEG docs to ensure compatibility with your environment. For example, many of the commands below are using `6000k` for a target bitrate, but this may not work for your channel if you're using a `BASIC` channel type.

## Gathering Your Channel Info

You'll need the **Ingest endpoint** and **Stream key** so collect those from your channel via the Amazon IVS Console.

![Ingest endpoint and stream key](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-v7ayhzfhkpzjcctp3f9l.png)

For my demo channel, I've set these values into the environment variables `DEMO_STREAM_INGEST_ENDPOINT` and `DEMO_STREAM_KEY`.

## Listing Your Audio and Video Devices

Next, list your audio and video devices with FFMPEG:

```bash
$ ffmpeg -list_devices true -f avfoundation -i dummy
```

> If you're on Windows, you will need to use `-f dshow` instead. 

On my machine, this command produced the following output. 

```
[AVFoundation indev @ 0x11d605c80] AVFoundation video devices:
[AVFoundation indev @ 0x11d605c80] [0] OBS Virtual Camera
[AVFoundation indev @ 0x11d605c80] [1] ManyCam Virtual Webcam
[AVFoundation indev @ 0x11d605c80] [2] FaceTime HD Camera
[AVFoundation indev @ 0x11d605c80] [3] Capture screen 0
[AVFoundation indev @ 0x11d605c80] AVFoundation audio devices:
[AVFoundation indev @ 0x11d605c80] [0] ManyCam Virtual Microphone
[AVFoundation indev @ 0x11d605c80] [1] BlackHole 2ch
[AVFoundation indev @ 0x11d605c80] [2] External Microphone
```

In our commands below, we'll reference the device by index (for example: `2` for the "FaceTime HD Camera").

## Streaming Your Webcam and Microphone

The simplest use case is a straightforward camera and microphone stream. 

```bash
$ ffmpeg \
    -f avfoundation \ # force the format
    -video_size 1920x1080 \ # video size
    -framerate 30 \ # FPS
    -i "2:2" \ # input device (video:audio)
    -c:v libx264 \ # codec - libx264 is an advanced encoding library for creating H. 264 (MPEG-4 AVC) video streams
    -b:v 6000K \ # target bitrate 
    -maxrate 6000K \ # max bitrate
    -pix_fmt yuv420p \ # pixel format
    -s 1920x1080 \ # video size
    -profile:v main \ # the H.264 profile (https://trac.ffmpeg.org/wiki/Encode/H.264#Profile)
    -preset veryfast \ # encoder quality setting
    -g 120 \ # group of picture (GOP) size
    -x264opts "nal-hrd=cbr:no-scenecut" \
    -acodec aac \ # audio codec
    -ab 160k \ # audio bitrate
    -ar 44100 \ # audio sample rate
    -f flv \ # output video format
    $DEMO_STREAM_INGEST_ENDPOINT/$DEMO_STREAM_KEY
```

[Uncommented Command](https://gist.github.com/recursivecodes/289160e06aa1cd4c9d976436f1bca4e4#file-ivs-ffmpeg-webcam-mic-sh)

Using the command above produces the following live stream.

![Webcam and mic](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-9ganx427d0k9ufb20nwg.png)

## Streaming a Screenshare with Video Overlay and Microphone

Another common use case is to stream a screenshare with video overlaid at a certain position. This command is a bit trickier, but the comments should explain what's going on.

```bash
$ ffmpeg \
    -f avfoundation \ # force format for input 0
    -framerate 30 \ # input 0 framerate
    -video_size 1920x1080 \ # input 0 size
    -i "3:" \ # first (index 0) input (screenshare)
    -f avfoundation \ # force format for input 1
    -framerate 30 \ # input 1 framerate
    -video_size 640x480 \ # input 1 size
    -i "2:" \ # second (index 1) input (camera)
    -f avfoundation \ # force format for input 2
    -i ":2" \ # third (index 2) input (mic)
    -filter_complex "[0:v][1:v] overlay=main_w-overlay_w-5:main_h-overlay_h-5" \ # overlay video on screenshare in the bottom right
    -map 0:v:0 \ # use the video from input 0
    -map 1:v:0 \ # use the video from input 1
    -map 2:a:0 \ # use the video from input 2
    -c:v libx264 \ # codec - libx264 is an advanced encoding library for creating H. 264 (MPEG-4 AVC) video streams
    -b:v 6000K \ # target bitrate 
    -maxrate 6000K \ # max bitrate
    -pix_fmt yuv420p \ # pixel format
    -s 1920x1080 \ # video size
    -profile:v main \ # the H.264 profile (https://trac.ffmpeg.org/wiki/Encode/H.264#Profile)
    -preset veryfast \ # encoder quality setting
    -g 120 \ # group of picture (GOP) size
    -x264opts "nal-hrd=cbr:no-scenecut" \
    -acodec aac \ # audio codec
    -ab 160k \ # audio bitrate
    -ar 44100 \ # audio sample rate
    -f flv \ # output video format
    $DEMO_STREAM_INGEST_ENDPOINT/$DEMO_STREAM_KEY
```

[Uncommented Command](https://gist.github.com/recursivecodes/541990abb205f1b689740bcb7627df4a#file-ivs-ffmpeg-screenshare-video-audio-loop-sh)

This command produces output that looks like this:

![Screenshare with video](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zlzpng71cgym41subhhc.png)


## Streaming a Pre-Recorded Video 

For pre-recorded assets, we can swap out the camera input for the path to an existing video file on our local file system.

```bash
$ ffmpeg \
    -re \
    -i /path/to/video.mp4 \ #input video
    -c:v libx264 \ # codec - libx264 is an advanced encoding library for creating H. 264 (MPEG-4 AVC) video streams
    -b:v 6000K \ # target (average) bitrate for the encoder
    -maxrate 6000K \ # max bitrate
    -pix_fmt yuv420p \ # pixel format 
    -s 1920x1080 \ # size
    -profile:v main \ # the H.264 profile (https://trac.ffmpeg.org/wiki/Encode/H.264#Profile)
    -preset veryfast \ # encoder quality setting
    -force_key_frames "expr:gte(t,n_forced*2)" \ # keyframe interval
    -x264opts "nal-hrd=cbr:no-scenecut" \
    -acodec aac \ # audio codec
    -ab 160k \ # audio bitrate
    -ar 44100 \ # audio sample rate
    -f flv \ # output video format
    $DEMO_STREAM_INGEST_ENDPOINT/$DEMO_STREAM_KEY
```

[Uncommented Command](https://gist.github.com/recursivecodes/baa03af178fedf5a3388c50afcc42f1c#file-ivs-ffmpeg-pre-recorded-sh)

The output here is similar to the webcam output, but contains the pre-recorded video contents with embedded audio.

![Precorded video](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-23ulgm5k0llvvnkj1c7h.png)

## Streaming Pre-Recorded Video With Separate Audio Track

Sometimes our pre-recorded video doesn't contain audio, but maybe we want to include a separate audio track. This is useful to create an experience like a "lofi radio" stream that uses animated video and a separate audio track. Note that this stream will infinitely loop the video and audio, so you'll want to be mindful that live stream duration is capped to 48 consecutive hours. 

```bash
$ ffmpeg \
    -re \
    -stream_loop -1 \ # loop video infinitely
    -i /path/to/video.mp4 \ # input (video)
    -stream_loop -1 \ # loop audio infinitely
    -i /path/to/audio.mp3 \ # input (audio) 
    -map 0:v:0 \ # map the first video stream from the first video file
    -map 1:a:0 \ # map the first audio stream from the second file
    -c:v libx264 \ # codec - libx264 is an advanced encoding library for creating H. 264 (MPEG-4 AVC) video streams
    -b:v 6000K \ # target (average) bitrate for the encoder
    -maxrate 6000K \ # max bitrate
    -pix_fmt yuv420p \ # pixel format 
    -s 1920x1080 \ # size
    -profile:v main \ # the H.264 profile (https://trac.ffmpeg.org/wiki/Encode/H.264#Profile)
    -preset veryfast \ # encoder quality setting
    -force_key_frames "expr:gte(t,n_forced*2)" \ # keyframe interval
    -x264opts "nal-hrd=cbr:no-scenecut" \
    -acodec aac \ # audio codec
    -ab 160k \ # audio bitrate
    -ar 44100 \ # audio sample rate
    -f flv \ # output video format
    $DEMO_STREAM_INGEST_ENDPOINT/$DEMO_STREAM_KEY
```

[Uncommented Command](https://gist.github.com/recursivecodes/1732dc4ebda559f923f6004a6f534b3d#file-ivs-ffmpeg-pre-recorded-separate-audio-loop-sh
)

## Re-streaming an IP Camera

The final example that we'll cover is a re-stream use case. It can be handy to use an input source that doesn't produce RTMP output. Certain IP cameras and other devices produce output in RTSP, and with FFMPEG we can redirect an input from these devices to our Amazon IVS live stream. 

```bash
$ ffmpeg \
    -rtsp_transport \
    tcp \
    -i rtsp://user:pass@192.168.86.34:554 \ # IP camera URI
    -preset ultrafast \ # encoder quality setting
    -vcodec libx264 \ # codec
    -ar 44100 \ # audio bitrate
    -f flv \ # output video format
    $DEMO_STREAM_INGEST_ENDPOINT/$DEMO_STREAM_KEY
```

[Uncommented Command](https://gist.github.com/recursivecodes/0f6661be04e43062f4f6d6034a6582fb#file-ivs-ffmpeg-restream-rtsp-sh)

This command produces output like the following.

![IP Camera streamed to Amazon IVS](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-pm41kv4nc61cufq64v8t.png)



## Summary

In this post we looked at how to stream to an Amazon IVS live stream in a headless manner with FFMPEG. If you have a use case that wasn't covered in this post, drop it in the comments below or reach out to me on [Twitter](https://twitter.com/recursivecodes).