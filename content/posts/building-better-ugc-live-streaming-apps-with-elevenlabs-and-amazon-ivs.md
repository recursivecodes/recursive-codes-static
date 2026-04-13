---
title: "Building Better UGC Live Streaming Apps with ElevenLabs and Amazon IVS"
slug: "building-better-ugc-live-streaming-apps-with-elevenlabs-and-amazon-ivs"
author: "Todd Sharp"
date: 2026-04-13T00:00:00Z
summary: "Learn how to integrate ElevenLabs voice AI with Amazon IVS to add real-time transcription, content moderation, meeting transcription, and virtual assistants to your live streams."
tags: ["elevenlabs", "amazonivs", "voice-ai"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-095527.png"
_build:
  list: never
  render: always
---

Getting machines to understand and speak our language _isn't_ new - people have been working on this since the mid 1900s, which is kind of wild when you think about it. But what _is_ new is how good it's gotten. The latest generation of speech models combined with hardware that can actually keep up means we can do things today that just weren't possible a couple of years ago. I've been building live streaming demos with Amazon IVS for the past 4 years. Recently I started exploring what happens when you bring voice AI into the mix. And honestly? It's a cheat code for building safe and engaging communities.

## Why Integrate Voice AI?

IVS is a managed live streaming service used for all kinds of things - live auctions, e-learning, and of course social user-generated content. But the UGC space is really competitive. If you're building a new platform, you need to find ways to stand out. Content discovery is hard. You're basically relying on creators to properly tag and categorize their own streams, and let's be honest - that's a gamble.

What if you could actually analyze what's being said on a stream? Now you can automatically tag and summarize content so viewers find exactly what they're looking for. As an added bonus - now you've got transcriptions - which make your app accessible. From there, reaching new geographic regions is just a matter of translation.

There's also the moderation angle. When you know what your streamers are talking about, you can build much smarter content moderation. That's a real advantage when you're trying to build a safe community. But it's not just content discovery and moderation - sentiment analysis, highlight generation, virtual assistants, real-time fact checking are all possible now.

## Solution

I've put together some demo scripts to show what's possible when you combine ElevenLabs with Amazon IVS. If you want to try these out yourself, check out the [IVS Python Demo repository on GitHub](https://github.com/aws-samples/sample-amazon-ivs-python-demos).

### Low-Latency Live Stream Transcription

The first demo uses ElevenLabs Scribe - their real-time speech recognition API - to pipe the audio from an IVS channel directly to ElevenLabs. Channels have about 2-5 seconds of latency, so it's not quite real-time, but the result is a solid transcription that you can use for any of the use cases I just talked about.

There are four basic steps to obtain a transcription from an IVS low-latency channel. You can check out the [entire demo script](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/channels-subscribe/ivs-channel-subscribe-transcribe-elevenlabs.py) on GitHub, but let's look at the basic premise here to give you an idea just how simple it is.

Step one is to get the audio from the IVS channel:

```python
import av
import asyncio

# Open the HLS stream and find the audio track
container = av.open("https://example.com/channel/playlist.m3u8")
audio_stream = next(s for s in container.streams if s.type == "audio")

# Resample to 16kHz mono PCM (ElevenLabs default format)
resampler = av.AudioResampler(format="s16", layout="mono", rate=16000)

for packet in container.demux(audio_stream):
    for frame in packet.decode():
        for resampled in resampler.resample(frame):
            audio_bytes = resampled.to_ndarray().tobytes()
            await send_to_elevenlabs(audio_bytes)
```

Next, we'll establish a WebSocket connection to the ElevenLabs Scribe endpoint ([docs](https://elevenlabs.io/docs/api-reference/speech-to-text/v-1-speech-to-text-realtime)):

```python
import websockets

ws_url = (
    "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
    "?model_id=scribe_v2_realtime"
    "&audio_format=pcm_16000"
    "&commit_strategy=vad"
    "&language_code=en"
)

ws = await websockets.connect(
    ws_url,
    additional_headers={"xi-api-key": ELEVENLABS_API_KEY},
)

# Wait for session confirmation
session = json.loads(await ws.recv())
print(f"Session started: {session['session_id']}")
```

Once the connection is established, we send the audio chunks from IVS via the WebSocket.

```python
import base64, json

async def send_to_elevenlabs(audio_bytes):
    await ws.send(json.dumps({
        "message_type": "input_audio_chunk",
        "audio_base_64": base64.b64encode(audio_bytes).decode(),
        "commit": False,
        "sample_rate": 16000,
    }))
```

As transcriptions are ready, they'll be received on the WebSocket.

```python
async for message in ws:
    data = json.loads(message)

    if data["message_type"] == "partial_transcript":
        # Interim result — updates as the speaker talks
        print(f"[interim] {data['text']}", end="\r")

    elif data["message_type"] == "committed_transcript":
        # Final result — locked in after a pause in speech
        print(f"[final]   {data['text']}")
```

From here, you can do whatever you need with the transcript. For example, you could send it to your database, or create a VTT file for VOD captions. For content discovery, you might store a running transcript in memory and occasionally send it to your favorite LLM for summarization and tagging and then pass that metadata to your application. The possibilities are endless. Or you could simply publish it as timed metadata to the IVS channel.

```python
import boto3, json

ivs = boto3.client("ivs")
channel_arn = "arn:aws:ivs:us-east-1:123456789012:channel/abcdefgh"

def publish_transcript(text):
    ivs.put_metadata(
        channelArn=channel_arn,
        metadata=json.dumps({"transcript": text}),
    )
```

On the IVS player side, these transcripts are received via the `PlayerEventType.TEXT_METADATA_CUE` event and can be used on the client side as necessary. Timed metadata is embedded directly into the video stream, so no additional messaging channel is necessary and the metadata is available in the recorded VOD as well.

### Real-Time Live Stream Transcription

The next demo is similar, but it works with IVS WebRTC-based stages which have less than 300ms of latency. With this approach, we get near-instant results. This transcript can be fed into an LLM to get further insight into what's being said - sentiment, topics, intent - all can be determined automatically.

Since IVS stages are WebRTC based, we need to subscribe to the participant with `aiortc` (or another suitable library) to get their audio. Let's look at a simplified example (again, refer to the [repo](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-subscribe/ivs-stage-subscribe-transcribe-elevenlabs.py) for the full example).

First, we establish a peer connection.

```python
from aiortc import RTCPeerConnection, RTCSessionDescription
import requests, base64, json

# Parse the WHIP URL from the IVS participant token
token_payload = json.loads(base64.urlsafe_b64decode(token.split(".")[1] + "=="))
whip_url = token_payload["whip_url"]

# Create a receive-only WebRTC connection
pc = RTCPeerConnection()
pc.addTransceiver("audio", direction="recvonly")
await pc.setLocalDescription(await pc.createOffer())

# Exchange SDP with IVS
response = requests.post(
    f"{whip_url}/subscribe/{participant_id}",
    data=pc.localDescription.sdp,
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/sdp"},
)
await pc.setRemoteDescription(RTCSessionDescription(sdp=response.text, type="answer"))
```

Now we just grab the audio bytes and send it to ElevenLabs.

```python
import av, base64, json

resampler = av.AudioResampler(format="s16", layout="mono", rate=16000)

@pc.on("track")
async def on_track(track):
    if track.kind == "audio":
        while True:
            frame = await track.recv()
            for resampled in resampler.resample(frame):
                audio_bytes = resampled.to_ndarray().tobytes()
                await ws.send(json.dumps({
                    "message_type": "input_audio_chunk",
                    "audio_base_64": base64.b64encode(audio_bytes).decode(),
                    "commit": False,
                    "sample_rate": 16000,
                }))
```

The only difference between the low-latency and real-time demos is how we get the audio. Sending and receiving to ElevenLabs uses the same process of establishing a WebSocket connection and sending and receiving the data.

### IVS Stage Meeting Transcriber

Getting insight into a single participant is great, but what about meetings or conferences with multiple speakers? The [meeting transcriber](https://github.com/aws-samples/sample-amazon-ivs-python-demos/tree/mainline/stages-elevenlabs-meeting-transcriber) automatically subscribes to each participant in a real-time stage and provides a transcript for each one. Like before, we can pipe these transcripts into an LLM for insight and summarization - but this time for the entire conversation. Since the meeting transcriber is also a publisher on the stage, it can push all of the transcripts as SEI metadata - so you can render captions or meeting notes in real-time on the viewer side.

To try it out, create an Amazon IVS real-time stage in the AWS console.

![ivs-elevenlabs-create-stage](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-092117.png)

On the new stage's detail page, publish to the stage.

![ivs-elevenlabs-publish-to-stage](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-092209.png)

Next, create a stage token for the meeting transcriber:

![ivs-elevenlabs-create-token-button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-092242.png)

![ivs-elevenlabs-create-token](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-092313.png)

Now launch the Python script, passing the transcribe agent's token:

![ivs-elevenlabs-start-script](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-092334.png)

Subscribe to the stage in the AWS console and you'll see that the transcribe agent has joined as a publisher.

![ivs-elevenlabs-stage-subscribe](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-092421.png)

When you speak, the transcription will be logged to the console. You won't be able to see the published SEI metadata within the AWS console. To view it, you'll need to create your own simple application using the [AWS Web Broadcast SDK](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/web-publish-subscribe.html#web-publish-subscribe-sei-attributes) which will allow you to view the published SEI metadata. Viewing the script's log output will show the transcription and allows you to confirm that the metadata is being published. For easier readability, I've removed the timestamps and logger data from the output below.

```bash
📝 Starting IVS Stage Meeting Scribe (ElevenLabs)
🧊 ICE timeout: 1s
🎤 Model: scribe_v2_realtime
🌍 Language: en
📋 Commit strategy: vad
   VAD silence: 1.5s, threshold: 0.4
📹 Publishing scribe video track...
✅ Loaded scribe icon from ./robot-icon.png
📹 ScribeVideoTrack initialized: 640x360 @ 5fps
✅ Scribe video published to stage
🔌 Connecting to stage events: wss://global.events.live-video.net/[redacted]
✅ Connected to stage events WebSocket
👤 New participant publishing: o5gUP8G6AYKH (userId: [redacted])
✅ ElevenLabs connected for [redacted] (session: [redacted])
✅ Subscribed to [redacted] (o5gUP8G6AYKH)
🎤 First audio from [redacted]
[redacted] good morning this is a demo of using the ElevenLabs scribe API to transcribe an IVS real-time stage
📡 Queued SEI message: 252 bytes, queue: 0→1, delay: 0.3ms
📡 Message queued: - repeat_count: 3
```

### IVS Virtual Assistant

The [virtual assistant](https://github.com/aws-samples/sample-amazon-ivs-python-demos/tree/mainline/stages-elevenlabs-agent) is my favorite. It uses ElevenLabs Conversational AI - which converts your speech-to-text, passes it to whatever LLM you want, and returns the response using any of the thousands of voices in ElevenLabs's library. And honestly - most of the voices are genuinely good - warm and natural sounding. If you want, you can even clone your own voice or generate a voice completely from scratch.

You can also add function calls to make the virtual assistant even more useful. For example, since the agent has access to the participant's audio **AND** video, you can capture a single frame of the user's video and analyze it with an LLM. This gives the agent the ability to "see" what's happening so it can interact based on that additional context.

You can try out the virtual assistant with the same stage and token that we created for the meeting transcriber. Once launched, ask the agent what it can see. The script will capture the current frame and send it to Amazon Bedrock. Once the image analysis is complete, it will pass the context back to the assistant who can intelligently respond with this contextual information.

![ivs-elevenlabs-virtual-assistant](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260413-094236.png)

```bash
🎬 Starting IVS Stage + ElevenLabs Conversational AI Agent
🧊 ICE timeout: 1s
🗣️ Voice: JBFqnCBsd6RMkjVDRZzb
🧠 LLM: gemini-2.0-flash
🌍 Language: en
🔍 Frame analysis: enabled
🧠 Analysis model: us.anthropic.claude-sonnet-4-6
🌍 Analysis region: us-east-1
🔵 AgentVideoTrack initialized: 640x360 @ 20fps
🔊 AgentAudioTrack initialized - chunk_size: 960 bytes (~20.0ms)
Found credentials in environment variables.
🔍 Frame analysis enabled (model: us.anthropic.claude-sonnet-4-6, region: us-east-1)
📡 SEI Publisher initialized for H.264 metadata transmission
🤖 Initializing ElevenLabs Conversational AI Agent...
🤖 Creating ElevenLabs Conversational AI agent...
✅ Created ElevenLabs agent: agent_090...
🔌 Connecting to ElevenLabs WebSocket (agent: agent_090...)...
✅ ElevenLabs WebSocket connected
✅ ElevenLabs Conversational AI Agent initialized
🎧 Subscribing to participant: o5gUP8G6AYKH
🤝 ElevenLabs conversation started (id=conv_7201...)
🧊 Subscribe ICE state: checking
🔗 Subscribe connection state: connecting
📺 Received audio track from o5gUP8G6AYKH
🔊 Audio track received - processing through ElevenLabs Agent
📺 Received video track from o5gUP8G6AYKH
✅ Subscribed to o5gUP8G6AYKH
🚀 Joining stage as publisher...
🎵 Starting audio processing task (track state: live)
Waiting for WebRTC connection to be established...
✅ Connection established: connected
🎤 First audio frame sent to ElevenLabs (608 bytes)
🎙️  ElevenLabs Conversational AI Agent is live! Press Ctrl+C to stop.
[🤖 AGENT] Hello! How can I help you today?
📡 Queued SEI message: 163 bytes, queue: 0→1, delay: 0.0ms
📡 Message queued: agent - repeat_count: 3
📡 Published SEI: agent - 'Hello! How can I help you toda...'
[🗣️ USER] Hey, can you tell me what you see?
📡 Published SEI: user - 'Hey, can you tell me what you see...'
[🤖 AGENT] In the background, I see what looks like a really striking tropical or botanical wallpaper or tapestry. It has a bold black and white palm leaf and foliage print.
📡 Queued SEI message: 293 bytes, queue: 0→1, delay: 0.0ms
📡 Message queued: agent - repeat_count: 3
📡 Published SEI: agent - 'In the background, I see what ...'
```

There's also a [variant](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-elevenlabs-agent/ivs-stage-elevenlabs-group-agent.py) that merges the virtual assistant with the meeting transcriber to create a passive assistant. It sits in a multi-participant conversation, transcribes everything, and responds to a wake word when you need it.

## Summary

Voice AI has gone from "nice to have" to something that developers are building into their products from day one. I've been really impressed with ElevenLabs - the accuracy is there, the latency is low, and the voice synthesis actually sounds like a real person. If you're building anything with live audio or video, I'd genuinely encourage you to check out what ElevenLabs can do. The demos I showed today are all on GitHub, so clone the [repo](https://github.com/aws-samples/sample-amazon-ivs-python-demos), try them out, and let me know what you think.
