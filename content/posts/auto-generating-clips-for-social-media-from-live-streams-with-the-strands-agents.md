---
title: "Auto-Generating Clips for Social Media from Live Streams with the Strands Agents SDK"
slug: "auto-generating-clips-for-social-media-from-live-streams-with-the-strands-agents-sdk-1kkj"
author: "Todd Sharp"
date: 2025-06-06T17:12:34Z
summary: "Generative AI is excellent at analyzing large amounts of data and identifying and summarizing a..."
tags: ["aws", "amazonivs", "livestreaming", "strandsagents"]
canonical_url: "https://dev.to/aws/auto-generating-clips-for-social-media-from-live-streams-with-the-strands-agents-sdk-1kkj"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nvw08bt3g55pxvz6vr06.png"
---

Generative AI is excellent at analyzing large amounts of data and identifying and summarizing a meaningful subset of the data based on a guided set of instructions. The source of the data could be anything - your email inbox, a large text file on your machine or a webpage on the internet. It's not perfect, but it can give you a head start on large tasks that involve a lot of data. One of the things I get asked about a lot by developers is how they can use AI to analyze video content. Multimodal LLMs have come a long way, but they're not quite at the point where they could ingest an hour's worth of video from a live stream and provide a summary or identify potential clips for sharing on social media. But there's another approach that we can take to solve this problem.

## Solution Overview

In order to create a tool to analyze a video-on-demand (VOD) from a live stream, I settled on the following approach.

1. Download/convert the HLS media to a local MP4
2. Transcribe the MP4 
3. Ask an AI agent to identify start/end timestamps for potential clips based on the transcript
4. Create MP4 'clips' based on the identified timestamps
5. Summarize the work

## Solution Architecture

To accomplish this task, I decided to try out the new [Strands Agents SDK](https://strandsagents.com/). It's a fairly new framework for building agents that has a simple way to define tools that the agent can use to assist in responding to prompts. For this solution, we'll need [FFMPEG](https://ffmpeg.org) and [Whisper](https://github.com/openai/whisper) installed on the machine where the agent runs. I'll be working locally, but this could easily be converted to a server-based solution using FastAPI or another web framework and deployed to the cloud in a Docker/Podman container. 

![Strands Clipping Solution](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-m1dfsddm8sdf1t9swb45.png)

## Defining Tools

I won't cover how to get started with Strands Agents since the docs do a great job of that. Instead, we'll walk through this demo and see how it works. 

Of course we start with a fresh virtual environment.

```bash
python -m venv .venv
source .venv/bin/activate
```

Next we'll need to install our dependencies. Place the following in `requirements.txt`:

```txt
ffmpeg-python
git+https://github.com/openai/whisper.git
strands-agents
strands-agents-tools 
click
```

And install the dependencies with:

```bash
pip install -r requirements.txt
```

Next, in `agent.py`, we'll define our imports.

```py
import os
import ffmpeg
import tempfile
import uuid
import shutil
import whisper
import click
from whisper.utils import get_writer
from strands import Agent, tool
from strands_tools import (
    file_read,
    file_write,
    use_aws,
)
```

Create a temp working directory and some variables for our temp files.

```py
temp_dir = tempfile.mkdtemp()
mp4_file = f"{uuid.uuid4()}.mp4"
mp4_path = os.path.join(temp_dir, mp4_file)
transcript_file = f"{uuid.uuid4()}.vtt"
transcript_path = os.path.join(temp_dir, transcript_file)
```

Now we can start defining the tools that our agent will need to complete the task. For this we use the `@tool` decorator. The first tool will take the `m3u8` URL for the HLS playlist and download it as an `mp4` with FFMPEG.

```py
@tool
def convert_m3u8_to_mp4(path_to_m3u8: str):
    stream = ffmpeg.input(path_to_m3u8)
    stream = ffmpeg.output(
        stream,
        mp4_path,
        acodec="copy",
        vcodec="copy",
        crf=50,
        **{"bsf:a": "aac_adtstoasc"},
        loglevel=("verbose" if verbose else "quiet"),
    )
    ffmpeg.run(stream, overwrite_output=True)
    print(f"Saved stream to {mp4_path}")
```

The next tool will transcribe the MP4 with Whisper.

```py
@tool
def transcribe_mp4():
    print(f"Transcribing {mp4_path} to {transcript_file}")
    model = whisper.load_model("base")
    result = model.transcribe(mp4_path, verbose=verbose)
    vtt_writer = get_writer("vtt", temp_dir)
    vtt_writer(result, transcript_file)
    print(f"Transcribe complete")
```

And finally, a tool that will take the start/end timestamps that the agent identifies and generate a new clip from the original `mp4` at the given start/end time.

```py
@tool
def create_mp4_clip(
    input_file: str,
    start_time: str,
    end_time: str,
    output_file: str,
):
    """clip an mp4 using ffmpeg"""
    stream = ffmpeg.input(input_file, ss=start_time, to=end_time)
    stream = ffmpeg.output(
        stream,
        output_file,
        c="copy",
        loglevel=("verbose" if verbose else "quiet"),
    )
    ffmpeg.run(stream, overwrite_output=True)
```

## Prompting the Agent

Now that our tools are defined, we can create an instance of the agent. Here we are passing our custom tools, as well as some built-in tools like `file_read`, `file_write` and `use_aws` that the agent can use as necessary.

```py
agent = Agent(
    tools=[
        create_mp4_clip,
        convert_m3u8_to_mp4,
        transcribe_mp4,
        file_read,
        file_write,
        use_aws,
    ],
)
```

We'll prompt the user to ask if they'd like to run in `verbose` mode (which will provide STDIO output from FFMPEG and Whisper) and ask them to provide the `m3u8` (HLS playlist) URL.

```py
verbose = click.confirm("Enable verbose output?", default=False)
m3u8_url = click.prompt("Enter M3U8 URL", type=str)
```

And now we can pass a prompt to the agent. 

```py
agent(
    f"""
      your purpose is to generate small clips from a larger live stream 
      so that they can be shared on social media.
      your task involves the following steps:
      
      1. download the HLS segments and convert them to an MP4 file
      2. transcribe the downloaded MP4 using whisper
      3. analyze the transcript to identify potential clips
      4. create the clips
      5. provide a summary of your work
      
      here are some details:
      
      Step 1: using the tool `convert_m3u8_to_mp4`:
      given the HLS manifest file located at {m3u8_url},
      convert the live stream to an MP4 and save it to {mp4_path}.
      
      Step 2: using the tool `transcribe_mp4`:
      transcribe the MP4 and save the transcript to {transcript_path}.
      this will produce a timestamped transcript from the live stream. 
      
      Step 3: take a look at the transcript and identify a list of suggested 
      timestamps (start and end) for clips that might be good to share 
      on social media. provide a suggested title, the start and end 
      timestamp, the transcript in that section, a summary/description 
      and several tags.
      
      Step 4: using the tool `create_mp4_clip`:
      after you have identified them, create an mp4 for each based on 
      the timestamp identified. use the original mp4 that was created 
      in the first step that is located at {mp4_path}.
      each output file should use a kebab case mp4 filename
      generated from your suggested title. 
      save the new clips in {temp_dir}.
      
      do not cleanup the temp directory at this time, even though 
      you have a tool that can perform this step. 
      
      Step 5: provide a summary of your work, 
      in the summary, output the following information for each clip:
        - Title
        - Start Time
        - End Time 
        - Transcript
        - Summary
        - Tags
        - File Location of Clip
    """
)
```

## Running the Application

When we run the application using `python agent.py` we'll be prompted  to toggle verbose mode and provide the URL.

```bash
Enable verbose output? [y/N]: 
Enter M3U8 URL:
```

I decided to test the agent out with a [recent live stream](https://www.twitch.tv/videos/2427797850) from my friend [Darko Mesaroš](https://rup12.net/). 

```md
I'll help you generate small clips from the larger live stream following the steps you've outlined. Let's begin:

## Step 1: Download the HLS segments and convert them to an MP4 file

First, I'll convert the HLS manifest file to an MP4.
Tool #1: convert_m3u8_to_mp4
Saved stream to /[redacted]/0a464c96-e071-4300-83d7-a74eeee82e28.mp4
```

Looks good - the MP4 file was generated as expected based on our prompt.

```md
## Step 2: Transcribe the MP4 file

Now, I'll transcribe the downloaded MP4 file:
Tool #3: transcribe_mp4
Transcribing /[redacted]/0a464c96-e071-4300-83d7-a74eeee82e28.mp4 to 55c5f5f6-85ed-46d4-80f9-d455f6c51fcb.vtt
/[redacted]/transcribe.py:132: UserWarning: FP16 is not supported on CPU; using FP32 instead
  warnings.warn("FP16 is not supported on CPU; using FP32 instead")
Detected language: English
Transcribe complete
```

And the transcript was generated! Now it should analyze the transcript to identify some clips.

```md
## Step 3: Analyze the transcript to identify potential clips

Based on the transcript, I'll identify several potential clips that could be good to share on social media. These will be moments that are engaging, informative, or entertaining.

### Clip 1: Stream Introduction and Technical Difficulties

**Title:** "Starting a Creative Coding Stream with Rust"

**Start Time:** 01:26.580
**End Time:** 02:12.220

**Transcript:**
"NOW! We're live. Yes. Okay. Now there's audio. There's audio. Okay. I was like, ah, um, so last moment I had to cut off my, um, what is it called? My, uh, my audio. Not only my whole Thunderbolt docked here because it just froze. So lost all my audio and everything else as I went along. So how do you, how do we, Jay? How are you doing my friend? It has been way too long. So I hope you're doing good. Um, welcome to the show. Welcome. Welcome. It has been actually, um, actually even a good old while for myself in the terms of live streaming. I think I have a stream for like 20 days. So incredibly happy to be back. So yeah, let's do some live streaming."

**Summary:** The streamer begins their first live stream in 20 days, explaining how they had technical difficulties with their audio setup when trying to start the stream. Despite the challenges, they're enthusiastic about being back and connecting with viewers.

**Tags:** #RustDevelopment #LiveCoding #StreamingTech #CreativeCoding #TechnicalDifficulties

### Clip 2: Introducing GGEZ - A Rust Game Engine

**Title:** "What is GGEZ? A Rust Game Engine for Creative Coding"

**Start Time:** 02:30.860
**End Time:** 03:29.820

**Transcript:**
"Um, okay. So the plan for today, my friends, is to do some stuff with, well, as always, Rust. So I'm going to do some creative coding today. Something with, um, um, Rust and a, and a framework I was using over the last few days called, GGE. It is a, I think they call themselves like a rust game engine thing. Like not terribly serious. It's not a full blown game engine. Um, it's a, it's a thing and it kind of does graphics. It is very similar to like P5JS, which is a very much, uh, an artistic type of coding framework, which I used in the past stream a long time ago. And, and of course, P5JS comes from processing. If anybody knows what processing is, um, so processing is an old framework. I think it uses its own bespoke language to do like graphics and like stuff. So, um, that's the whole plan today to do a little bit of that. Um, and have some fun."

**Summary:** The streamer introduces GGEZ, a Rust game engine framework they'll be using for creative coding. They explain how it's similar to P5JS and Processing, highlighting that it's not a full game engine but a tool for making graphics and creative coding projects.

**Tags:** #RustProgramming #GGEZ #GameDevelopment #CreativeCoding #GraphicsProgramming

### Clip 3: Drawing Fire - Creative Coding Goal

**Title:** "Let's Draw Fire with Rust: My Creative Coding Challenge"

**Start Time:** 06:03.980
**End Time:** 07:09.740

**Transcript:**
"So what, why would I like to do is I would love to do some creative coding, but in Rust. So, so that's the plan for today. Do a little bit of that. Um, there's no certain point to today. Like, in a sense, like we're not building up to, we're going to share. We're going to try to draw some pixels on the screen. We're not going to go too crazy and be like S.D.L type of approach. And I'm like, just super complicated. We're going to just do, um, squares and circles and whatnot. So, um, I want to try to draw flames. This is one of my, one of my tests when I draw this, these kinds of, when I work with these, a kind of artistic tools is like, can I draw fire, right? A C doughnut. Is, is a C doughnut, so. I know a C, oh, oh, wow. This would be a, I mean, probably at one point, I'm not as good as, as being able to do something like this. I know this whole thing code that actually is shaped like doughnut and it's just math. I'm not as good as math in this, but, um, yeah, yeah, yeah. We're going to try to draw some flames just simple as that. And I've done that in the past in Lua, but I want to try to do a Darwin rust. And I want to use this GGZ to set it up."

**Summary:** The streamer explains their goal for the creative coding session: to draw flames using Rust and GGEZ. They mention this as their go-to test when trying out new creative coding frameworks, comparing it to the famous "donut" code visualization but clarifying they'll stick to something simpler that they've previously implemented in Lua.

**Tags:** #RustCreativeCoding #DigitalArt #FlameSimulation #CreativeTech #VisualProgramming

### Clip 4: Setting Up GGEZ Fundamentals

**Title:** "How GGEZ Works: The Core Architecture of a Rust Game Engine"

**Start Time:** 12:46.140
**End Time:** 13:21.340

**Transcript:**
"So the way this works is that, um, your application has, um, basically a state, a main state where it kind of keeps stuff between frames. And, um, it has specific events on that state. That means as your application runs, there is a draw event, and there's an update event. And within those two events, you can do certain things. Now, of course, in the draw event, you draw on the screen, and the update event, you update whatever you're doing. And those are the two, two main important things we're going to be creating. And GGZ requires you to do it in a specific way."

**Summary:** The streamer explains the fundamental architecture of GGEZ, detailing how the game loop works with a main state that maintains data between frames, and the two key events - draw and update - that form the backbone of any GGEZ application.

**Tags:** #GameDevelopment #RustProgramming #GameLoop #GGEZ #GraphicsProgramming
```

That's a lot of output, but it's done exactly what we wanted. It analyzed the 20 minute stream that I provided and identified 4 clips that would be "engaging, informative, or entertaining". Based on the summary, I think it does a really good job at finding small clips of the larger stream that would be good for sharing on social media.

The next step is to generate the `mp4` files.

```md
Now I'll create MP4 clips for each of the identified segments:
Tool #6: create_mp4_clip
Tool #7: create_mp4_clip
Tool #8: create_mp4_clip
Tool #9: create_mp4_clip
```

Finally, the agent summarizes all of the work

```md
## Step 5: Summary of Work

### Clip 1: Starting a Creative Coding Stream with Rust
- **Title:** Starting a Creative Coding Stream with Rust
- **Start Time:** 00:01:26.580
- **End Time:** 00:02:12.220
- **Transcript:** "NOW! We're live. Yes. Okay. Now there's audio. There's audio. Okay. I was like, ah, um, so last moment I had to cut off my, um, what is it called? My, uh, my audio. Not only my whole Thunderbolt docked here because it just froze. So lost all my audio and everything else as I went along. So how do you, how do we, Jay? How are you doing my friend? It has been way too long. So I hope you're doing good. Um, welcome to the show. Welcome. Welcome. It has been actually, um, actually even a good old while for myself in the terms of live streaming. I think I have a stream for like 20 days. So incredibly happy to be back. So yeah, let's do some live streaming."
- **Summary:** The streamer begins their first live stream in 20 days, explaining how they had technical difficulties with their audio setup when trying to start the stream. Despite the challenges, they're enthusiastic about being back and connecting with viewers.
- **Tags:** #RustDevelopment #LiveCoding #StreamingTech #CreativeCoding #TechnicalDifficulties
- **File Location:** /[redacted]/starting-a-creative-coding-stream-with-rust.mp4

[trimmed for brevity]
```

Here's an example of one of the clips that our agent generated for us from the longer live stream.

{{< youtube h_rND7go2nU >}}

## Enhancing the Agent

If we wanted to, we could prompt the agent to upload the resulting `mp4` files to an S3 bucket. If we did that, we might want to also create a tool that cleans up the temp files that were generated during the process. There's no limit to the amount of tools we can create to enhance the agent.

What kind of enhancements would you want to see with this social clip generating agent? How are you using the Strands Agents framework? Let me know in the comments.

Photo by <a href="https://unsplash.com/@sangharsh_l?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash">Sangharsh Lohakare</a> on <a href="https://unsplash.com/photos/a-close-up-of-a-blue-and-purple-structure-8o_LkMpo8ug?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash">Unsplash</a>
      