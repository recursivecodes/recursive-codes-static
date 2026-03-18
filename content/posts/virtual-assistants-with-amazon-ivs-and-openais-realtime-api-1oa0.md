---
title: "Virtual Assistants with Amazon IVS and OpenAI's Realtime API"
slug: "virtual-assistants-with-amazon-ivs-and-openais-realtime-api-1oa0"
author: "Todd Sharp"
date: 2025-10-01T12:52:35Z
summary: "We recently explored building a virtual agent that seamlessly joins your Amazon Interactive Video..."
tags: ["aws", "amazonivs", "ai", "openai"]
canonical_url: "https://dev.to/aws/virtual-assistants-with-amazon-ivs-and-openais-realtime-api-1oa0"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-29mpy06w3l2mqhou7c0i.png"
---

We recently [explored building a virtual agent](https://dev.to/aws/building-virtual-agents-with-amazon-nova-sonic-s2s-23m7) that seamlessly joins your Amazon Interactive Video Service (Amazon IVS) real-time streams as a conversational assistant with vision capabilities. While Amazon Nova Sonic S2S delivers solid performance and integrates beautifully with the AWS ecosystem, you might be curious about harnessing OpenAI's cutting-edge real-time model for your agents. This post walks you through a demo integration that makes this possible.

Before we dive into the technical details, here's a glimpse of what a conversation looks like with OpenAI's real-time model working behind the scenes.

{{< youtube ku3in2Lzdiw >}}

The results speak for themselves: crisp, natural voice quality, lightning-fast response times, and remarkably accurate visual analysis that nails what it's looking at. It's genuinely impressive how well everything comes together.

## ❓ How Is This Different?

This integration leverages the Python `aiortc` library to tap into the remote participant's stream, channeling their audio directly into the `gpt-realtime` model. Meanwhile, the agent establishes itself as a publisher on the Amazon IVS stage. When `gpt-realtime` generates its response, that audio flows right back into the agent's published feed. Need vision? The agent captures the current frame from the remote participant and instantly analyzes what's happening. It's elegantly straightforward - the `gpt-realtime` model essentially becomes another participant that both publishes and subscribes to the stage.

![gpt-realtime virtual agent arch](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-9wsdlymwc123lqpf2iyc.png)

## 🤖 Try It Out!

Ready to get your hands dirty? Start by spinning up a new Amazon IVS stage and generating a remote participant token for your agent (refer to the [user guide](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/what-is.html) for more info if you're new to IVS). 

```bash
aws ivs-realtime create-stage \
  --name "my-stage" \
  --region us-east-1 \
  --participant-token-configurations '[
    {
      "duration": 720,
      "attributes": {
        "username": "gpt-realtime-agent"
      }
    },
    {
      "duration": 720,
      "attributes": {
        "username": "local-participant"
      }
    }
  ]' \
  --query '{stageArn: stage.arn, gptParticipant: {participantId: participantTokens[0].participantId, token: participantTokens[0].token}, localParticipant: {participantId: participantTokens[1].participantId, token: participantTokens[1].token}}' \
  --no-cli-pager
```

This will produce output similar to the following:

```json
{
    "stageArn": "arn:aws:ivs:us-east-1:639934345351:stage/abcdef123456",
    "gptParticipant": {
        "participantId": "6APQqRu2XnqK",
        "token": "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ...."
    },
    "localParticipant": {
        "participantId": "m243ru5A2idL",
        "token": "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ...."
    }
}

```

No client app yet? No problem - you can publish directly from the AWS Management Console. If you are using the AWS Console, make sure to grab your participant ID from the 'Stage sessions' section by clicking the active session ID. 

You can also try things out with [this CodePen](https://codepen.io/amazon-ivs/full/ZEqgrpo). Paste the `token` from the `localParticipant` into the **Token** input box and click 'Join' to publish to your new stage.

Next, clone the [sample repo](https://github.com/aws-samples/sample-amazon-ivs-python-demos/) and navigate to the `stages-gpt-realtime` directory. The [README](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-gpt-realtime/README.md) there walks you through the setup process. There's even a [simple management script](https://github.com/aws-samples/sample-amazon-ivs-python-demos/blob/mainline/stages-gpt-realtime/MANAGING_OPENAI_ASSISTANT_DEMO.md) that you can use to launch agent instances via WebSocket messages from the frontend. When you're ready to roll, fire up the script with your credentials:

```py
python ivs-stage-gpt-realtime.py \
  --token <GPT_PARTICIPANT_TOKEN> \
  --subscribe-to <LOCAL_PARTICIPANT_ID> \
  --openai-key <OPENAI_API_KEY>
```

Your agent will hop onto the stage, subscribe to your local participant, and you're off to the races with real-time AI conversations!

![Real-time virtual assistant](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-9lxc2w06ec0zslzv08jx.png)

The script provides a simplified video track with an audio visualization which can be overridden for your use case. I personally like to create a client side visualization which tends to be a bit cleaner and more responsive (as you can see in the video above).

## 👏 Extending The Solution

This sample gives you the foundation to start building something amazing. Dig into the repo code and OpenAI's documentation to discover how you can supercharge the solution - add custom tools for function calling, or transform the `gpt-realtime` model into a smart transcription service for your stages. Drop a comment and let me know what creative solutions you'll build with Amazon IVS and `gpt-realtime`!
