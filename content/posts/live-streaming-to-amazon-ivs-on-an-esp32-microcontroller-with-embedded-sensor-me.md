---
title: "Live Streaming to Amazon IVS on an ESP32 Microcontroller with Embedded Sensor Metadata"
slug: "live-streaming-to-amazon-ivs-on-an-esp32-microcontroller-with-embedded-sensor-metadata-17mj"
author: "Todd Sharp"
date: 2025-09-19T12:32:53Z
summary: "Until recently, quality live streaming from embedded devices like an ESP32 was severely limited...."
tags: ["livestreaming", "esp32", "aws", "amazonivs"]
canonical_url: "https://dev.to/recursivecodes/live-streaming-to-amazon-ivs-on-an-esp32-microcontroller-with-embedded-sensor-metadata-17mj"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-su3rqs1yogk64at9s2ze.png"
---

Until recently, quality live streaming from embedded devices like an ESP32 was severely limited. ESP32-CAM boards can only produce low-quality, low frame rate (5-15 FPS) streams of MJPEG images via RTSP at resolutions like 320x240. These microcontrollers simply didn't have enough CPU and RAM for real video processing with modern codecs. Then Espressif changed everything by releasing the [ESP32-P4-Function-EV-Board](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32p4/esp32-p4-function-ev-board/index.html), which features a dual-core 400MHz RISC-V processor, 32MB PSRAM, and most importantly, a hardware H.264 encoder capable of 1080P@30fps streaming. It's a game changer to be sure, but all of that hardware is nothing without a software library to push those beautifully encoded H264 streams to a valid destination. Thankfully Espressif came through *again* with the `esp-webrtc-solution` [library](https://github.com/espressif/esp-webrtc-solution/). So does it live up to they hype? More importantly, can we integrate it with a managed live streaming service like Amazon IVS? Let's find out!

⚠️ **Disclaimer**: This is a personal project!

## 📟 The Board

🛑 Before we go any further - just look at this thing!

![ESP32-P4-Function-EV](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ih9et015u6g8mn0j0ee9.jpg)

> ⛔️ **Note**: Ignore that connected sensor for a moment. We'll get to that!

It's beautiful! The form factor is reminiscent of a Raspberry Pi - a huge step up from the tiny ESP32 boards we're used to seeing. Granted, sometimes a smaller board is better when we're integrating it into a larger project that we want to be compact, but with all the horsepower 🐎 this thing has, it was bound to be a little larger than usual. The kit I bought even comes with a full display, but I'm not using it for now. Side note: I'd love a nice project case for this kit, but I haven't found any available yet. To give you the full picture, here are the specs:

- **Dual-core 400MHz RISC-V processor** with 32MB PSRAM
- **Hardware H.264 video encoder** for real-time streaming
- **1920x1080 Full HD video** at 25fps
- **MIPI-CSI camera interface** (2MP camera included)
- **MIPI-DSI display output** (7" 1024x600 touchscreen included)
- **Wi-Fi 6 & Bluetooth 5 LE** via ESP32-C6 module
- **10/100 Ethernet port** for wired networking
- **Dual USB 2.0 ports** (Type-A host + Type-C device)
- **Professional audio system** with codec, microphone, and 3W amplifier (bring your own speaker)
- **40-pin GPIO header** for sensor/peripheral expansion
- **MicroSD card slot** for storage expansion
- **Built-in USB Serial/JTAG** debugging

Bottom Line: The ESP32-P4-Function-EV isn't just another microcontroller - it's a complete multimedia development platform that brings professional-grade video, audio, and connectivity features that would require multiple separate boards and components with traditional ESP32 setups. If I had one complaint, it's that the video color from the included 2MP SC2336 camera seems a bit off (see screenshot below). It's not terrible, but we're used to much higher quality cameras these days. I may try to find a way to upgrade that in the future.

## 🤝 Integrating with Amazon IVS

About a month ago, me and my friend [Kiro](https://kiro.dev) started trying to get the ESP32-P4 working with Amazon IVS real-time stages. Since stages [support WHIP ingest](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html), I started with the [`whip_demo`](https://github.com/espressif/esp-webrtc-solution/tree/main/solutions/whip_demo) sample solution. I quickly ran into a few issues with the core library - one major blocker in particular was that it didn't properly support redirects during SDP negotiation. This meant that when requesting an SDP for the IVS stage, the participant token was stripped from the request resulting in a `400` error. I worked on a fix for this (and a few other feature requests) and submitted a few PRs that have all been integrated into the core library (thank you [&#x40;TempoTian](https://github.com/TempoTian)!).

![Published live stream](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-vquiw01iypdbr3istdm8.png)

Yeah, the color is a bit off. But the resolution and latency is amazing! 

## 🏷️ SEI Support

Once I got the board broadcasting to Amazon IVS, the next step was pretty obvious (to me at least). This is a microcontroller with 55 programmable GPIO pins. It was *made* to read sensors, why not come up with a way to publish all that potential data? And since real-time stages have support for [Supplemental Enhancement Information (SEI)](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/web-publish-subscribe.html#web-publish-subscribe-sei-attributes), why not add support for publishing sensor (or really any data) as SEI? This required another PR to add a hook into the core lib to expose the video frames so that we can manipulate it to insert the SEI NAL units. Once this hook was implemented, Kiro and I were able to implement an SEI publishing system. This is why my image of the board above has a DHT-11 sensor attached.  If you're interested in how this works, check the DHT-11 markdown doc in the repo (link below).

![SEI Sensor Data](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rmp94bvtsw8iwiyz8le4.png)

## 🎉 Try it Out!

To try it out for yourself, check out the [`ivs-esp-whip-demo`](https://github.com/recursivecodes/ivs-esp-whip-demo) on GitHub. 

The documentation is pretty solid in the repo and should help you get it up and running. If you have any questions, post them below. For problems getting it running or enhancement ideas, please file an issue on the repo! 

Happy streaming!