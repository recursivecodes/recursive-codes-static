---
title: "5 Ways to Improve Your UGC Live Streaming App with AI"
slug: "5-ways-to-improve-your-ugc-live-streaming-app-with-ai-1ib9"
author: "Todd Sharp"
date: 2025-09-03T14:45:51Z
summary: "Most of the customers that depend on Amazon IVS for managed live streaming would rather focus on what..."
tags: ["aws", "amazonivs", "livestreaming", "ai"]
canonical_url: "https://dev.to/aws/5-ways-to-improve-your-ugc-live-streaming-app-with-ai-1ib9"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-yv9snx1o6rkw39uvqzxz.png"
---

Most of the customers that depend on Amazon IVS for managed live streaming would rather focus on what they do best - creating safe and engaging communities - instead of worrying about the challenges related to delivering low-latency live video to a global audience at scale. Which makes total sense - if they can depend on us to handle the complexities related to video, they can focus on creating the best possible user experience. There are enough challenges that they have to worry about. Things like monetization, moderation, content discovery, analytics (and much more) are tricky enough to manage without having to worry about transcoding, packaging and delivery of video bits around the world. As I talk to developers around the world, many are starting to ask about how they might use AI to help solve some of these problems. So in this post, we'll take a look at three possible ways to use AI and various open-source tools to make it easier to create a better UX for a social UGC live streaming application. 

> 🐉 **Here Be Dragons!** Some of the methods that we'll look at below all utilize the WebRTC-HTTP Egress Protocol - or WHEP - to subscribe to an Amazon IVS real-time stage. Technically this is an *unsupported* protocol on Amazon IVS. This means that the usage of WHEP and the endpoints related to subscribing to a real-time stream are not documented, and you'll be unable to receive support related to WHEP if you have any issues. That said, all of the scripts below have been tested to work as of the initial publish date of this blog post. Keep this in mind before implementing any of these solutions and consider this post experimental and educational!
>
## 1️⃣ Transcribing a Real-Time Stream

Providing captions (and even translations) for a live stream is great for viewer engagement and helps to make your app accessible for all users, but it's not the only reason why you might want to transcribe a real-time stream. Once you've got a running transcript you can now use AI to summarize the content of that stream and use it for moderation discovery purposes. Now your viewers can find the perfect live stream based on the actual content of the stream, not just based on what the streamer decided to use for a title, description and tags. 

To transcribe a real-time live stream, check out the [`ivs-stage-subscribe-transcribe.py`](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-subscribe/ivs-stage-subscribe-transcribe.py) script in [this repo](https://github.com/aws-samples/sample-amazon-ivs-python-demos/). Once you've configured the script, you can run it with:

```py
python ivs-stage-subscribe-transcribe.py \
  --participant-id "participant123" \
  --token "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzM4NCJ9..."
```

Which will give you output that looks similar to the following:

```md
2025-09-02 15:10:21,022 - INFO - Processing audio chunk 1 in memory (shape: (80000,))
[TRANSCRIPT] or a correction? I mean, that's kind of, you kind of glance over the...
2025-09-02 15:10:26,037 - INFO - Processing audio chunk 2 in memory (shape: (80000,))
[TRANSCRIPT] important part there. that's a mighty big that ellipsis in that reply.
2025-09-02 15:10:31,037 - INFO - Processing audio chunk 3 in memory (shape: (80000,))
[TRANSCRIPT] it is doing a whole heck of a lot of work right there. She kind of went
2025-09-02 15:10:36,020 - INFO - Processing audio chunk 4 in memory (shape: (80000,))
[TRANSCRIPT] from zero to a billion in one giant step.
```

This script is a great starting point. You can modify it for your needs by persisting each transcript to a database, or publishing it over a WebSocket. 

## 2️⃣ Analyzing Individual Frames of a Real-Time Stream

As we just saw, transcribing can provide a huge amount of context for discover, moderation and more. But it's only part of the story - sometimes what is unspoken can provide the rest. For this, we can grab individual frames from the live stream and analyze them with Amazon Bedrock. The repo that we looked at earlier has an example of frame analysis in the [`ivs-stage-subscribe-analyze-frames.py`](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-subscribe/ivs-stage-subscribe-analyze-frames.py) demo. Once this script is ready to run (check out the https://github.com/aws-samples/sample-amazon-ivs-python-demos/README.md for setup instructions) you can run it with:

```py
python ivs-stage-subscribe-analyze-frames.py \
  --subscribe-to "participant123" \
  --token "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzM4NCJ9..." \
  --analysis-interval 5
```

Which will provide output like this:

```md
2025-09-02 15:18:38,449 - INFO - 🤖 Frame analysis enabled (interval: 5.0s)
2025-09-02 15:18:38,552 - INFO - 🧊 ICE connection state changed to: completed
2025-09-02 15:18:38,598 - INFO - 🔗 Connection state changed to: connected
2025-09-02 15:18:44,140 - INFO - 🔍 Analyzing frame for participant y1rhVboBJgQb...
2025-09-02 15:18:51,417 - INFO - ✅ Frame analysis completed for participant y1rhVboBJgQb
2025-09-02 15:18:51,417 - INFO - 📝 Analysis: 
```
Here's the analysis broken out for readability:

>This is a screenshot from a Twitch live stream showing:
>
>**Main Subject**: A middle-aged man with a gray beard wearing a black baseball cap and what appears to be a white hoodie or jacket with orange/red accents. He's speaking into a black microphone and appears to be seated in a dark gaming chair.
>
>**Setting**: The background shows a dimly lit room with purple/blue ambient lighting. There's a framed picture or artwork visible on the wall behind him, and the Twitch logo is prominently displayed in purple neon-style lighting on the left side of the frame.
>
>**UI Elements**:
> - A chat message is visible at the bottom from user "raymondcamden" asking "hey betty - can you explain the entirety of all existence, starting from the big bang to the current time?"
> - There's an anime-style avatar/VTuber character visible in the bottom right corner - appears to be a figure with green hair
> - An orange circular logo/symbol is visible in the upper right
> - The typical Twitch streaming interface elements are present
>
>**Activity**: This appears to be an interactive streaming session where the streamer is responding to viewer questions or comments, likely in a talk show or Q&A format rather than gaming content.
>
>The overall aesthetic suggests this is a professional streaming setup with deliberate lighting and branding elements.
>
This kind of overview is so much more helpful than anything even the streamer themselves could provide.

## 3️⃣ Analyzing Audio/Video Chunks in a Real-Time Stream

We can take #2 one step further, and instead of analyzing a single video frame we can use TwelveLabs Pegasus to analyze a chunk of actual video (including audio). This combines the effectiveness of transcription (audio context) and frame analysis into a single, holistic analysis.

Try [`ivs-stage-subscribe-analyze-video.py`](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-subscribe/ivs-stage-subscribe-analyze-video.py):

```py
python ivs-stage-subscribe-analyze-video.py \
  --subscribe-to "participant123" \
  --token "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzM4NCJ9..." \
  --analysis-duration 10
```

Which will provide output like:

```md
2025-09-02 15:22:37,494 - INFO - 🔍 Video analysis active - recording 10.0 second videos
2025-09-02 15:22:37,494 - INFO - 🔄 1 connection(s) active. Press Ctrl+C to exit.
2025-09-02 15:22:37,494 - INFO - 🎵 Starting audio processing task
2025-09-02 15:22:37,494 - INFO - 🧐 Starting audio and video processing task
2025-09-02 15:22:37,494 - INFO - 🤖 Video analysis enabled (duration: 10.0s)
2025-09-02 15:22:37,596 - INFO - 🧊 ICE connection state changed to: completed
2025-09-02 15:22:37,647 - INFO - 🔗 Connection state changed to: connected
2025-09-02 15:22:37,745 - INFO - 🎥 Starting audio and video chunk recording
2025-09-02 15:22:47,776 - INFO - ⏹️  Stopping recording after 10.03s
2025-09-02 15:22:47,776 - INFO - ✅ Recorded 301 video frames
2025-09-02 15:22:47,776 - INFO - ✅ Recorded 501 audio frames
2025-09-02 15:22:56,227 - INFO - ✅ Successfully encoded video: 1001838 bytes, 1335784 base64 chars
2025-09-02 15:22:56,233 - INFO - 🔍 Analyzing video for participant eBJWcH5N8zSk...
2025-09-02 15:23:02,471 - INFO - ✅ Video analysis completed for participant eBJWcH5N8zSk (finish reason: unknown)
2025-09-02 15:23:02,471 - INFO - 📝 Analysis: 
```
Again, breaking out the analysis for readability:

>In the video, a man is seated in a chair, speaking into a microphone. 
>
>He is wearing a black cap and a gray hoodie. The background includes a Twitch logo on the left side and a world map on the right side, with a cartoon image of a girl with green hair also visible on the right. 
>
>The man appears to be engaging in a conversation with an audience or a specific person named Betty, as indicated by the text overlay that reads, "Ask a question in chat with Betty!" and "Hey Betty! Can you explain the entirety of the universe starting from the big bang to the current time?" 
>
>The dialogue suggests that the man is asking about the origins of the universe. The overall setting is that of a live stream or video call, where the man is addressing viewers and possibly discussing topics related to gaming or history.
>
This is *super helpful* for content discovery, moderation and analysis. Imagine being able to monetize a stream based on the exact content within it!

## 4️⃣ Indexing VODs with TwelveLabs Marengo

Analyzing live video is amazing and powerful, but VODs are just as important to any social UGC video platform. TwelveLabs Marengo can be used via Amazon Bedrock to generate embeddings from video, text, audio, or image inputs. These embeddings can be used for similarity search, clustering, and other machine learning tasks which means your users can easily search for and discover VODs based on the actual video content itself! Check out [the docs](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-marengo.html?trk=769a1a2b-8c19-4976-9c45-b6b1226c7d20&sc_channel=el) to learn more.

## 5️⃣ Curating VOD Highlights

The key to growth for any social UGC video application is social clip sharing. I've previously blogged about a simple way you can curate clips for social sharing which can help your users easily create their next viral highlight. Check out [this post](https://dev.to/aws/auto-generating-clips-for-social-media-from-live-streams-with-the-strands-agents-sdk-1kkj) to learn how!

## 🏁 Summary

There are tons of ways to improve the UX of your social UGC live streaming application, and AI is only making it easier for developers. What is your favorite way to use AI with video? Post it in the comments below!