---
title: "Hype or Hope - Is MCP The Missing Piece of the Puzzle?"
slug: "hype-or-hope-is-mcp-the-missing-piece-of-the-llm-puzzle-c88"
author: "Todd Sharp"
date: 2025-04-09T13:44:57Z
summary: "By now you've heard about the Model Context Protocol - or MCP. The Generative AI hype train 🚂 is..."
tags: ["aws", "amazonivs", "mcp", "genai"]
canonical_url: "https://dev.to/aws/hype-or-hope-is-mcp-the-missing-piece-of-the-llm-puzzle-c88"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8q3e3c85qcmm6fztaa5g.png"
imagecontain: true
---

By now you've heard about the Model Context Protocol - or MCP. The Generative AI hype train 🚂 is full-steam ahead, and MCP is claimed to be the missing piece of the puzzle 🧩 to help us create solutions that can actually fill in the gaps of pre-trained models and give them additional tools and resources (literally) to solve complex problems. So is it all hype, or is MCP legit?

I've spent two weeks digging into MCP - which is like 8 years in the Generative AI world - so I must be an expert at this point 😉. Jokes aside, I've found MCP to be nothing short of amazing. As a Developer Advocate for Amazon Interactive Video Service (Amazon IVS), I spend much of my time working with the Amazon IVS docs and building demos to help developers learn how to implement live streaming in their applications. By creating an MCP Server and Client (and incorporating a RAG knowledgebase), I've created a solution that has domain specific knowledge about your Amazon IVS resources and can generate and explain prototypes in a short period of time - and most importantly - with "out-of-the-box" accuracy.

## Before MCP

When compared to AWS Lambda, EC2, S3 or EKS, Amazon IVS is more of a niche service. Everyone needs compute and storage, but not everyone has a live streaming use case. This means that asking an LLM (Claude 3.7 Sonnet in this case) for help in generating a prototype or sample implementation typically gets rather close, but not quite perfect. And in my experience, this is often more frustrating than not getting any direction at all. I'd rather go to the docs and work through the steps necessary to learn about something instead of trying to troubleshoot the output of an LLM.

To illustrate this point, we'll look at the output of sending the following prompt to Claude 3.7 (via Amazon Bedrock):

> help me create an html file to broadcast to an amazon ivs low-latency channel using the latest version of the amazon ivs web broadcast sdk

While it's certainly not of the utmost importance for a simple prototype, here's how Claude's file looked when running it in the browser locally.

![Claude Web Broadcast](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-i6c6iwdnfad14sgq4vhq.png)

Now let's look at the part that really matters - the code itself. Claude tried its best, but Claude is not an expert on Amazon IVS so the file was far from working out-of-the-box. The entire output of the prompt is [here](https://gist.github.com/recursivecodes/6f894ce2e18061dda49216a612ef48e4). I won't paste the whole output here, I will highlight a few issues with it.

⚠️ Imported a seriously outdated version of the SDK. No surprise, Claude is **limited to the data it was trained on**. Here it wants us to use version `1.4.0` which is pretty old compared to the latest (at the time of this blog post) version of `1.22.0`.

```html
<script src="https://web-broadcast.live-video.net/1.4.0/amazon-ivs-web-broadcast.js"></script>
```

⚠️ This one is a sneaky issue that actually causes a silent issue that you wouldn't normally catch until it was too late.

```js
if (!IVSBroadcastClient.isSupported) {
  updateStatus("Browser is not supported for IVS broadcasting", true);
}
```

This code "works" - but it doesn't. It won't throw an error, but it will always return `true`. Why? Because `isSupported` is a function, not a property. So JavaScript coerces it to true, because the function exists on the library. The fix is simple, call it as a function: `IVSBroadcastClient.isSupported()`.

⚠️ The `startCameraButton` listener starts off ok, properly creating an instance of the `IVSBroadcastClient`, but then calls a function that flat out doesn't exist:

```js
const devices = await client.getDevices();
```

The proper approach is to use `navigator.mediaDevices.enumerateDevices()` to list out the cameras and microphones on the user's browser. But it doesn't really matter, because it never does anything with the `devices` variable. Instead, it attaches the `cameraStream` as a video - **AND AUDIO** 🤨 - input device.

```js
// Add the video device
await client.addVideoInputDevice(cameraStream, "camera", { index: 0 });

// Add the audio device
await client.addAudioInputDevice(cameraStream, "microphone");
```

We could go on, but I think you get the point. Claude doesn't have the data necessary to properly solve this problem. But we can give Claude more tools and abilities and insight into our Amazon IVS resources via an MCP server which will enable it to use those tools to become a domain expert with direct insight into our actual channels and stages.

## After MCP

In my next few posts I'll show you the actual code behind this solution. For now let's use my custom MCP client to solve the same problem from aboveand check the results. Here's my prompt. I'm being a little more specific here, because I know the client can handle this level of specificity.

> lets create an html file to broadcast to an amazon ivs low-latency channel using the latest version amazon ivs web broadcast sdk. check the documentation for low-latency streaming with the web broadcast sdk and use my existing channel called demo-channel. to retrieve the channel's stream key from the application, create a function that uses this endpoint: https://[redacted]. use tools at your disposal to find the ingest endpoint for this channel. save the file to /path/to/ivs-web-broadcast-demo.html

Again, it's less important - but notice how much better this example looks visually compared to the previous attempt.

![IVS MCP Web Broadcast](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-2pnpdpo20qbl00job15m.png)

Most importantly - it works out-of-the-box. Here's the [output](https://gist.github.com/recursivecodes/8f4b580ba5a0f6270bb8f1a8de560c66) from my prompt. As you can see, with a custom MCP server at its disposal, Claude was able to search a knowledgebase and retrieve the very latest docs to generate a working prototype. And since the MCP Server exposes my IVS channel information, Claude was even able to properly retrieve the necessary `ingestEndpoint` and include that in the code to save me time and effort.

## Summary

There's a lot more to MCP than we've covered in this post, but after working with this protocol, it's clear to me that it has the potential to give LLMs tools to solve even the most domain specific issues with a higher degree of success. In my next post, we'll take an in-depth look at the Amazon IVS MCP server that I've created.
