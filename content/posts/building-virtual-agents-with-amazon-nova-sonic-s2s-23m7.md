---
title: "Building Virtual Agents with Amazon Nova Sonic S2S"
slug: "building-virtual-agents-with-amazon-nova-sonic-s2s-23m7"
author: "Todd Sharp"
date: 2025-08-13T16:59:04Z
summary: "One of the more intriguing and helpful use cases of generative AI is voice agents. Advancements in..."
tags: ["aws", "ai", "amazonivs", "livestreaming"]
canonical_url: "https://dev.to/aws/building-virtual-agents-with-amazon-nova-sonic-s2s-23m7"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-g5cm8zjuo6vholihl4sk.png"
---

One of the more intriguing and helpful use cases of generative AI is voice agents. Advancements in speech recognition and synthesis have blurred the lines between human and machine to the point where it no longer feels like you're speaking to a terrible robot from a 1980's sci-fi flick. There's something strangely soothing to me about speaking to a virtual agent these days. There's no need to worry that the person on the other end of the line has had an awful day, or just spilled their coffee on their lap. Just a friendly, no-nonsense bot who is happy to help you. Of course there are exceptions to this - but I'd rather talk to a bot than a human for most customer service interactions these days. So what does it take to create your own virtual agent that understands your speech and responds to you with a friendly demeanor and a human-like voice? Let's take a look! 

## Agent Demo

Before we dig into things, here's a quick video showing the agent in action. There's room for a bit of improvement here since the Nova S2S agent is not optimized for WebRTC communication. We've got to buffer the audio a bit to make things sound clear and smooth when streaming over WebRTC. Using tools (as we'll talk about in a bit) will also incur a bit of delay, since the agent needs to first invoke the tool before it can parse and summarize the data and respond. But overall, it's an amazing experience and opens up the door to many possibilities.

{{< youtube pH_GrzPjzX0 >}}


## Introducing Amazon Nova Sonic 

[Amazon Nova Sonic](https://docs.aws.amazon.com/ai/responsible-ai/nova-sonic/overview.html) is a foundation model created by [Amazon AGI Labs](https://labs.amazon.science/) with a bidirectional streaming API. This means you can speak to it, and it can respond by speaking to you. No need to convert speech-to-text, or text-to-speech  - the model supports direct audio input and output. Right off the top, this is a huge win. TTS and STS are not terribly difficult to implement these days, but removing the need to concern yourself with these tasks lets you focus on building the experience of your application and enhancing your agent with custom tools that can provide it with deep contextual knowledge. Want to build a reservation system for your customers? No problem - just wire up your agent with the tools that it needs to access the user's data and it'll be able to retrieve and modify reservations through simple conversations. Practically any use case that you can think of is possible. [Try it out](https://nova.amazon.com/sonic) for yourself without writing a single line of code. When you're ready to implement your own agent, check out the [user guide](https://docs.aws.amazon.com/nova/latest/userguide/speech.html) - or read on in this post to learn how I created a demo that shows you how to integrate your Nova Sonic agent into an Amazon IVS real-time stream.

## Building A Live-Stream Agent

Running in the browser or on the command line is an excellent use-case for a voice agent. But wouldn't it be super cool if the agent could actually join as a virtual participant in a WebRTC based video call? Yeah, I thought so too - so about a month ago I started playing around with the Python library [`aiortc`](https://github.com/aiortc/aiortc/) to provide an integration between  Amazon IVS and a Nova Sonic agent. Here's how it works:

* User joins an Amazon IVS real-time stage with camera and microphone in the browser
* Agent script launched
* Agent subscribes to a single user's audio and video
  * Pipe user's audio into Nova Sonic
  * Captures video frames 
* Agent joins as a publisher, with dynamically generated speech visualization video track
* Agent listens for user audio, and responds (invoking 'tools' as necessary)
* Agent audio is published as an audio track to the stage

## Tools ⚒️

The demo agent has a few tools to demonstrate Nova Sonic's ability to augment the agent's contextual and domain-specific knowledge. The simplest example is asking the agent for the current time. Because the agent is trained on a static dataset, it has no way to determine the current date or time. But if we expose a tool for this, it's really easy to add this potentially import context to the agent. The tool can use simple Python (`datetime.now()`) or can be more complex, like calling third-party APIs or using SDKs to retrieve dynamic data. For example, the demo in the repo linked in this post has a weather tool that can get the current weather via a remote API.

## Giving the Agent Vision 🤖👀

Because the agent script is subscribed to the user's video feed, it seemed logical to give the agent the ability to "see" the user. You can literally ask it to describe what you look like or what it sees in the environment around you. You can even ask it to tell you what you're holding in your hand. When it determines that it needs to use its "vision" tool, it grabs the latest video frame and passes it to a multi-modal LLM for image analysis. The analysis is returned to the agent which summarizes it and tells you what it saw.

## Try It Out!

If you'd like to try it out for yourself, clone the [demo repo](https://github.com/aws-samples/sample-amazon-ivs-aiortc-demos) to your machine and refer to the [README](https://github.com/aws-samples/sample-amazon-ivs-aiortc-demos/blob/mainline/README.md). There are several different use cases in that repo, so refer to the `stages-nova-s2s` directory for this demo (but check out the other demos too!). There's also a [Nova Sonic specific README](https://github.com/aws-samples/sample-amazon-ivs-aiortc-demos/blob/mainline/stages-nova-s2s/README.md) in that directory that goes into a bit more detail.

Once you've cloned the repo, create an Amazon IVS real-time stage and publish to it. You can do this right from the Amazon IVS Console. Once you're publishing to the stage, you'll need to find your participant ID. On the stage details page (the page that you're using to publish your camera), scroll down to **Stage sessions** and select the **ACTIVE** session.

![Stage sessions](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-i5s81zk2hy3wy0uyrd8k.png)

On the session details page, scroll down to **Stage participants** and find the **CONNECTED** participant and copy the **Participant Id**.

![Stage participants](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-36na4bn715wxcajkg0sa.png)

Head back to the stage details page and generate a participant token.

![Create token](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-t0yf845xl3h1kymbdhff.png)

![Token dialog](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-r7lcq29q2bz4kfr3s9ub.png)

Then, copy the newly generated token.

![Copy token](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-onjpee7u60iyuxuokw3k.png)

Launch the new agent with the agent's generated token and the original participant's id:

```bash
python ivs-stage-nova-s2s.py \
  --token  eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ... \
  --subscribe-to 43QZqauB2sFz
```
After a few seconds, you'll see your agent join the stage and you'll be able to chat with it.

![Stage with agent](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5jww9hfd7buwdg3917zt.png)

## Summary

Feel free to check out the source code in the [demo repo](https://github.com/aws-samples/sample-amazon-ivs-aiortc-demos) to learn how to enhance and customize the agent in your own applications. Try to add your own custom tools and give the agent domain specific superpowers! This demo should give you a great start towards building your own voice agents powered by Amazon IVS and Amazon Nova Sonic. 

For more information, refer to the user guides and documentation for Amazon IVS and Amazon Nova Sonic:

- [Amazon IVS Real-Time User Guide](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/what-is.html)
- [Amazon Nova Sonic](https://docs.aws.amazon.com/ai/responsible-ai/nova-sonic/overview.html)
- [Try Nova Sonic](https://nova.amazon.com/sonic)
- [IVS Rocks](https://ivs.rocks/real-time)

So what will you build with Amazon Nova Sonic and Amazon IVS?