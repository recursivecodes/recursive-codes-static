---
title: "Live Streaming from Unity with Amazon IVS - Part 1"
slug: "live-streaming-from-unity-with-amazon-ivs-part-1-52nc"
author: "Todd Sharp"
date: 2024-02-12T15:32:19Z
summary: "Welcome to 'Live Streaming from Unity with Amazon IVS' - a series created to guide you through the..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-with-amazon-ivs-part-1-52nc"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-h0zsn2nwi7b0lk829tz6.png"
imagecontain: true
---

Welcome to 'Live Streaming from Unity with Amazon IVS' - a series created to guide you through the various ways that game developers can integrate live, interactive real-time streaming with Amazon Interactive Video Service (Amazon IVS) directly into a game created with Unity. In this introductory post, we'll introduce you to Amazon IVS, discuss **why** you might want to create an integrated streaming experience in your game, and provide an outline for the upcoming posts in this series. Let's get started!

{% embed https://www.youtube.com/watch?v=FXpQa86y_bs %}

## What is Amazon IVS

If you're new to Amazon IVS, allow me to give you a brief overview of what it is. Amazon IVS is an AWS service that empowers developers to use the same live streaming technology and global infrastructure that powers Twitch to build their own applications. Amazon IVS provides three major capabilities: low-latency (2-5 seconds) RTMPS based streaming, real-time (sub 300ms) WebRTC based streaming, and highly performant and scalable WebSocket based chat.

In the context of this blog series, Amazon IVS enables game developers to build deeply customized and tightly integrated live streaming applications for their playerbase which allow for more engagement and greater control over the total experience. This will lead to dynamic, interactive gameplay never seen before. Things like monetization, moderation, playback quality, viewer interaction, chat integration and much more are all in the developer's control.

> 💡 Learn all about Amazon IVS at [https://ivs.rocks/](https://ivs.rocks/)

## Why Live Stream Directly from a Game?

Game streaming is **hugely popular**. But, you already know this! Your playerbase may already be live streaming via third-party software like OBS, and with the announcement of things like [enhanced broadcasting](https://blog.twitch.tv/en/2024/01/08/introducing-the-enhanced-broadcasting-beta) on Twitch, that will always be a viable (and sometimes preferred) way to stream for some of your players. But let's be honest: configuring OBS isn't the easiest thing to do for some players. Things like bitrate, b-frames, codecs, keyframe intervals, and more can be daunting to someone who just wants to stream their gameplay to an audience.

By allowing your players to stream directly from the game, you remove that barrier to entry for some players, while giving all players the ability to have enhanced gameplay through feedback from viewers. What about multiple camera angles for viewers (boss cam)? What about user controlled cameras (yes, really!) that allows viewers to pan/tilt/zoom/spin a camera and watch at whatever angle they want without affecting the player's cam? How about modifying the environment or NPC behavior based on chat or polls? Yep, all of this (and much more) is possible when you integrate the streaming experience directly into your game.x

## Series Overview

I'm sure you're ⚙️ are already spinning with the potential of live streaming directly from a game created with Unity. In this series, we're going to cover the following topics:

1. Intro (this post)
2. Unity to Amazon IVS Real-Time Broadcasting
3. Enhanced Real-Time Broadcasting from a Game (including HUD)
4. Integrating Amazon IVS Chat into a Unity Game
5. Dynamic & Interactive Streams (User-Controlled cameras and dynamic environments & objectives)
6. Broadcasting Multiple Camera in Real-Time (viewers can view both, or toggle between them)
7. Real-Time Stream Playback in Unity (opens the possibility of squad chat with video)
8. Real-Time Broadcasting from a Meta Quest VR headset
9. Broadcasting a Game **Directly to Twitch** (Low Latency)

## Disclaimer

I should mention that whilst I've got 20 years of experience as a full-stack developer, I'm not a game developer. All of the things that we'll be building will be based on existing demo games that are available via [Unity Hub](https://unity.com/download). I've spent a lot of time building these demos, but there may be some concepts related to building a game with Unity that I'm less familiar with. I'll do my best to explain things, but remember - I'm not a game dev 🎮 expert!

## Pre-Requisites

You'll need to have Unity Hub installed to follow along with this series and build along with me. You'll also need an AWS account to create and a real-time stage, generate the tokens needed for broadcasting to that stage and any other resource that we may use in this series.

## Summary

We've got a lot of ground to cover in this series, and it's all super exciting stuff. By the end of the series you'll be ready to create your own engaging, highly interactive and dynamic live streaming platform and integrate it into your game created with Unity. Head on over to the next post to learn how to get started broadcasting a game in less than 15 minutes!
