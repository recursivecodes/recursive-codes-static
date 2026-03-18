---
title: "What Would a Live Stream Look Like on a Commodore 64?"
slug: "what-would-a-live-stream-look-like-on-a-commodore-64-42p4"
author: "Todd Sharp"
date: 2025-05-02T15:56:43Z
summary: "This morning my buddy Raymond Camden shared a fun little experiment. He has been playing around with..."
tags: ["aws", "amazonivs", "retrocomputing", "commodore64"]
canonical_url: "https://dev.to/aws/what-would-a-live-stream-look-like-on-a-commodore-64-42p4"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tpetzdbhrk7uwkn3dpkx.png"
---

This morning my buddy [Raymond Camden](https://raymondcamden.com) shared a fun little experiment. He has been playing around with a bit of "vibe coding", and decided to ask Claude to create a simple HTML file to take an image from the DOM and generate a "pixel art" version of that image. I was immediately curious if I could get [Amazon Q Developer](https://aws.amazon.com/q/developer) to create a similar demo to pixelate a webcam in real-time. This led me down quite a fun path that ended up with an absolutely amazing solution. Let me tell you about it...

## The Inspiration

Here's Raymond's solution. A fun, but rather basic pixel art demo.

{% codepen https://codepen.io/cfjedimaster/pen/OPPQedp %}

I loved the effect, but thought it would be even better if applied to a webcam stream in real-time!

## First Iteration - Pixelate a Webcam

My first prompt simply asked Amazon Q to create an HTML file that uses the [Insertable Streams for MediaStreamTrack API](https://developer.mozilla.org/en-US/docs/Web/API/Insertable_Streams_for_MediaStreamTrack_API) to pixelate a webcam. The result was pretty good!

![Pixelated Video](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-sd5myo36tzilkf2mwk79.png)

It even added a parameter to specify the pixel size, so you could modify how much pixelization to add to the resulting video.

Here's an 8 pixel version:

![Light Pixels](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zhysqj15oj67edg1du16.png)

And a 16 pixel version:

![Heavy Pixels](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gteoh27admwlvk4tlwtm.png)
</div>

## Second Iteration - Commodore 64 Style

The pixel effect was great, and it immediately made me think of the "old days" and the low-level graphics that I grew up with. I shared it with my buddy and well-known retro computing enthusiast [Darko Mesaroš](https://rup12.net) and told him that it reminded me of what a live stream would look like on a Commodore 64. Being the expert that he was, he mentioned that the C64 pixels were double-wide, so I went back to Amazon Q and asked it to create a version that would reflect what a live stream would look like on a C64. It knew the proper pixel ratio, and even took the initiative to modify the pixel colors to the authenticate 16-color C64 palette! Glorious!!

![C64 Pixels!](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-erdcapnomomvbru0i2wh.png)

## Final Iteration - The Full C64 Webcam Simulator

Feeling quite happy with the results, I decided to prompt Amazon Q to  update the UI to a full C64 experience. My prompt was rather vague as I decided to see what it could come up with. The final result was so much more than I could have expected. Amazon Q even decided to include a full terminal with a C64 style blinking cursor. You can try it out for yourself below. Choose a camera, click 'START CAMERA', and then type `RUN` at the C64 prompt!

> ⚠️ **Note**: CodePen can't get webcam permissions when running in embedded mode here on dev.to. Visit the pen in a new browser tab to[ try it out](https://codepen.io/Todd-Sharp/full/KwwoPNw)!

{% codepen https://codepen.io/Todd-Sharp/pen/KwwoPNw %}

## Summary

This was a fun experiment to see what I could create with the Amazon Q Developer CLI, and it helped me learn more about using the Insertable Streams API to modify a video track at the frame level. Sometimes learning new things can be fun just by vibing with an assistant to build a silly, throwaway app like this. 

Did this post inspire you to create something similar? Post your ideas and screenshots in the comments below!
