---
title: "4 Ways to Supercharge Your HLS Live Streaming App with AI-Powered Analysis"
slug: "4-ways-to-supercharge-your-hls-live-streaming-app-with-ai-powered-analysis-4mob"
author: "Todd Sharp"
date: 2025-09-17T13:52:36Z
summary: "Amazon IVS customers building live streaming platforms want to focus on creating engaging..."
tags: ["aws", "amazonivs", "ai", "livestreaming"]
canonical_url: "https://dev.to/aws/4-ways-to-supercharge-your-hls-live-streaming-app-with-ai-powered-analysis-4mob"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-chzbmzevqx5117csa4l6.png"
---

Amazon IVS customers building live streaming platforms want to focus on creating engaging experiences, not wrestling with complex video analysis pipelines. While we handle the heavy lifting of low-latency HLS delivery, they get to focus on the things they are great at - content discovery 🔍, moderation 🛡️, and user engagement 💫. In our [last post](https://dev.to/aws/5-ways-to-improve-your-ugc-live-streaming-app-with-ai-1ib9), we looked at how to solve some of these problems in real-time WebRTC based streams. Since that post, I've gotten many questions from developers keep asking us about AI solutions for low-latency (RTMP+HLS) channel analysis 🤖, so in this post we're going to dig into four powerful ways to use AI and open-source tools to transform your live streaming app's capabilities!

## 1️⃣ Real-Time Frame Analysis for Content Discovery

Want to know what's actually happening in your streams beyond just titles and tags? Frame-by-frame analysis using Claude via Amazon Bedrock can provide incredibly detailed descriptions of live content, perfect for content discovery, accessibility, and moderation.

Check out the [ivs-channel-subscribe-analyze-frames.py](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/channels-subscribe/ivs-channel-subscribe-
analyze-frames.py) script in [this repo](https://github.com/aws-samples/sample-amazon-ivs-python-demos/). Once configured, run it with:

```bash
python channels-subscribe/ivs-channel-subscribe-analyze-frames.py \
  --playlist-url "https://example.com/playlist.m3u8" \
  --highest-quality \
  --analysis-interval 30
```

This gives you detailed frame analysis output like:

```md
2025-09-15 15:48:35,507 - INFO - 🤖 VideoFrameAnalyzer initialized with 3.0s interval
2025-09-15 15:48:35,507 - INFO - 🌍 Using Bedrock region: us-east-1
2025-09-15 15:48:35,507 - INFO - 🧠 Using model: us.anthropic.claude-sonnet-4-20250514-v1:0
2025-09-15 15:48:35,507 - INFO - 🤖 Video frame analysis enabled (every 3.0s)
2025-09-15 15:48:36,073 - INFO - 📊 Stream FPS: 30.0
2025-09-15 15:48:36,074 - INFO - 🚫 Video display disabled - press Ctrl+C to quit
2025-09-15 15:48:36,254 - INFO - 🔍 Analyzing frame...
2025-09-15 15:48:47,551 - INFO - ✅ Frame analysis completed
2025-09-15 15:48:47,551 - INFO - 📝 Analysis: 
```

>This video frame shows a professional kitchen environment with a chef actively cooking. Here's what I observe:
>
>**Person:**
> - A chef wearing traditional white chef's attire (white chef's coat and white apron)
> - The chef appears to be middle-aged and is focused on cooking at the stovetop
>
>**Kitchen Environment:**
> - Commercial-grade stainless steel kitchen with professional equipment
> - Multiple cooking stations visible with gas burners
> - Industrial ventilation hood system overhead with exhaust fans
> - Stainless steel prep surfaces and countertops throughout
>
>**Cooking Activity:**
> - The chef is working at a stovetop with what appears to be a pan containing yellow/golden colored food (possibly eggs, butter, or a sauce)
> - Active cooking in progress, suggesting this is during meal preparation
>
>**Equipment & Features:**
> - Professional-grade gas range with multiple burners
> - Overhead heat lamps/warming lights visible
> - Industrial kitchen ventilation system
> - Red rubber anti-fatigue floor mats for safety and comfort
> - Various kitchen tools and equipment visible in the background
>
>**Setting:**
> - This appears to be a high-end restaurant or commercial kitchen
> - The lighting suggests this could be during active service hours
> - The setup indicates this is likely a live cooking demonstration or behind-the-scenes view of restaurant operations
>
>The overall scene captures the fast-paced, professional environment of commercial food preparation.
>
>
This analysis is perfect for automatically categorizing streams, generating accessibility descriptions, or powering content-based recommendations! 👨‍🍳🍝

## 2️⃣ Live Transcription with Timed Metadata Publishing

Real-time transcription isn't just great for accessibility - it's a goldmine for content discovery and moderation. The [ivs-channel-subscribe-transcribe.py](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/channels-subscribe/ivs-channel-subscribe-transcribe.py) script uses OpenAI Whisper for multi-language transcription and can even publish results back to your IVS channel as timed metadata.

```bash
python channels-subscribe/ivs-channel-subscribe-transcribe.py \
  --playlist-url "https://example.com/playlist.m3u8" \
  --language en \
  --whisper-model base \
  --publish-transcript-as-timed-metadata
```

Which will produce output that looks similar to this:

```md
2025-09-15 15:52:46,480 - INFO - 🎤 Starting audio chunk recording
2025-09-15 15:52:53,317 - INFO - ⏹️  Stopping recording after 6.84s with 346 frames
2025-09-15 15:52:53,338 - INFO - Processing audio chunk 6 in memory (shape: (118101,))
[TRANSCRIPT] A little bit of salt, a little bit of cracked pepper. We're gonna let that sweat a little bit. I have a big pot of pasta water here.
2025-09-15 15:52:54,167 - INFO - ✅ Published transcript metadata chunk 1/1 (150 bytes)
...
[TRANSCRIPT] right before I don't want to go into brown brown brown so we're going to put some Italian parsley in there.
...
[TRANSCRIPT] And it's not just for color, it's fragrant, it's earthy balances, the dish. I'm gonna go in with our spaghetti.
2025-09-15 15:53:07,786 - INFO - ✅ Published transcript metadata chunk 1/1 (129 bytes)
2025-09-15 15:53:07,786 - INFO - 🎉 Successfully published 1/1 transcript chunks
```

On the player side, we can [consume the metadata](https://docs.aws.amazon.com/ivs/latest/LowLatencyUserGuide/metadata.html#metadata-consuming) and render it as a caption or translate it as necessary.

![Metadata transcript](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-yckzcg0js2860h1kw0ak.png)

Of course this data can also be persisted to your app's database and subsequently queried by your app. Which means your viewers can search for streams by actual spoken content in addition to using the transcripts for captions and automated content moderation! 🗣️📝

## 3️⃣ Comprehensive Video Segment Analysis

Another options is to analyze the video content itself (not just a single frame). The [ivs-channel-subscribe-analyze-video.py](https://github.com/aws-samples/sample-amazon-ivs-
python-demos/blob/mainline/channels-subscribe/ivs-channel-subscribe-analyze-video.py) script records video segments and analyzes them using TwelveLabs Pegasus for holistic content understanding.

```bash
python channels-subscribe/ivs-channel-subscribe-analyze-video.py \
  --playlist-url "https://example.com/playlist.m3u8" \
  --analysis-duration 15 \
  --highest-quality
```

This provides incredibly rich analysis:

```md
2025-09-15 15:57:14,710 - INFO - 🤖 VideoAnalyzer initialized with 15.0s recording duration
2025-09-15 15:57:14,710 - INFO - 🌍 Using Bedrock region: us-west-2
2025-09-15 15:57:14,710 - INFO - 🧠 Using model: us.twelvelabs.pegasus-1-2-v1:0
2025-09-15 15:57:14,710 - INFO - 🤖 Video analysis enabled (recording duration: 15.0s)
2025-09-15 15:57:15,220 - INFO - 📊 Stream FPS: 30.0
2025-09-15 15:57:15,221 - INFO - 🚫 Video display disabled - press Ctrl+C to quit
2025-09-15 15:57:15,226 - INFO - 🎥 Starting audio and video chunk recording
2025-09-15 15:57:30,238 - INFO - ⏹️  Stopping recording after 15.01s
2025-09-15 15:57:30,238 - INFO - ✅ Recorded 349 video frames
2025-09-15 15:57:30,238 - INFO - ✅ Recorded 0 audio frames
2025-09-15 15:57:32,890 - INFO - ✅ Successfully encoded video: 3428047 bytes, 4570732 base64 chars
2025-09-15 15:57:32,891 - INFO - 🔍 Analyzing video...
2025-09-15 15:57:52,693 - INFO - ✅ Video analysis completed
2025-09-15 15:57:52,693 - INFO - 📝 Analysis:
```

>In the video from a live stream, a chef dressed in a white uniform is seen in a kitchen setting. He is initially holding a small piece of red chili pepper, which he brings to his mouth to taste. The text overlay on the video reads "ONE PASTAS" and "PASTA AGIO OLIO WITH PEPPERONCINO." After tasting the chili pepper, the chef puts it down and picks up a knife to chop the chili pepper on a white cutting board. The text overlay changes to indicate that he likes very spicy food and is going to use two chili peppers without removing the seeds, suggesting the dish will be quite hot. The chef continues to chop the chili pepper while the camera focuses on his actions. The background of the kitchen includes various equipment and ingredients, but the primary focus remains on the chef and his task of preparing the spicy pasta dish.
>
This analysis is perfect for content categorization, highlight generation, and creating searchable content libraries!

## 4️⃣ Advanced Audio-Video Synchronization

For the most sophisticated analysis, [ivs-channel-subscribe-analyze-audio-video.py](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/channels-subscribe/ivs-channel-subscribe-analyze-audio-video.py) uses PyAV for proper audio-video stream handling with perfect synchronization.

```bash
python channels-subscribe/ivs-channel-subscribe-analyze-audio-video.py \
  --playlist-url "https://example.com/playlist.m3u8" \
  --analysis-duration 20 \
  --highest-quality
```

This approach ensures your AI analysis captures the complete context of both audio and video streams, making it ideal for complex content like educational streams, gaming commentary, or multi-person discussions where timing matters! 🎯⚡ Here's the output for this script:

```bash
2025-09-15 16:00:06,306 - INFO - 🤖 VideoAnalyzer initialized with 15.0s recording duration
2025-09-15 16:00:06,306 - INFO - 🌍 Using Bedrock region: us-west-2
2025-09-15 16:00:06,306 - INFO - 🧠 Using model: us.twelvelabs.pegasus-1-2-v1:0
2025-09-15 16:00:06,306 - INFO - 🤖 Video analysis enabled (recording duration: 15.0s)
2025-09-15 16:00:06,306 - INFO - 🚫 Video display disabled - press Ctrl+C to quit
2025-09-15 16:00:06,306 - INFO - 🔗 Opening stream with PyAV...
2025-09-15 16:00:07,096 - INFO - 🔊 Found audio stream: aac, 48000Hz, 2 channels
2025-09-15 16:00:07,096 - INFO - 📺 Found video stream: h264, 360x640
2025-09-15 16:00:07,100 - INFO - 🎥 Starting audio and video chunk recording
2025-09-15 16:00:24,348 - INFO - ⏹️  Stopping recording after 17.25s
2025-09-15 16:00:24,348 - INFO - ✅ Recorded 615 video frames
2025-09-15 16:00:24,348 - INFO - ✅ Recorded 963 audio frames
2025-09-15 16:00:29,360 - INFO - ✅ Successfully encoded video: 6016865 bytes, 8022488 base64 chars
2025-09-15 16:00:29,367 - INFO - 🔍 Analyzing video...
2025-09-15 16:01:06,321 - INFO - ✅ Video analysis completed (finish reason: unknown)
2025-09-15 16:01:06,321 - INFO - 📝 Analysis:
```

>In the video, a chef is preparing a dish of pasta with pesto. Early on, the chef uses tongs to transfer the pasta from a pan to a plate, where the pasta is coated in a green pesto sauce with visible red pepper flakes. The chef then grates some fresh pecorino cheese over the pasta using a metal grater, as mentioned in the dialogue. The chef carefully distributes the pasta and cheese, ensuring a well-presented dish. The camera captures these actions in detail, focusing on the chef's hand movements and the final presentation of the pasta.
>
>Throughout the video, there are clear and readable captions overlaid on the screen, providing additional information about the dish and the chef's actions. The captions mention the type of pasta, the sauce used, and the chef's name. The overall presentation is professional and visually appealing, making it suitable for content discovery, moderation, or accessibility purposes. The chef holds up the plate towards the end, giving a clear view of the vibrant colors and textures of the pasta dish.
>
## 🏁 Summary

AI-powered channel analysis opens up incredible possibilities for live streaming platforms:

- **Content Discovery**: Let users find streams by actual content, not just titles 🔍
- **Accessibility**: Automatic captions and descriptions for all users ♿
- **Moderation**: Real-time content analysis for safety and compliance 🛡️
- **Monetization**: Target ads based on actual stream content 💰
- **Engagement**: Generate highlights and clips automatically ✨

The [sample repository](https://github.com/aws-samples/sample-amazon-ivs-python-demos/) provides everything you need to get started. What creative ways will you use AI to enhance your streaming platform? Drop your ideas in the comments! 