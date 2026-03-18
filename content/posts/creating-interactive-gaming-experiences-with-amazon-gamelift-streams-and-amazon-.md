---
title: "Creating Interactive Gaming Experiences with Amazon GameLift Streams and Amazon Interactive Video Service"
slug: "creating-interactive-gaming-experiences-with-amazon-gamelift-streams-and-amazon-interactive-video-2l9j"
author: "Todd Sharp"
date: 2026-02-11T00:32:08Z
summary: "If you're in the business of creating video games, you know that creating and marketing a game is not..."
tags: ["aws", "gamedev", "amazonivs", "amazongameliftstreams"]
canonical_url: "https://dev.to/aws/creating-interactive-gaming-experiences-with-amazon-gamelift-streams-and-amazon-interactive-video-2l9j"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-aywg2a031eo8z9tnruo5.png"
---

If you're in the business of creating video games, you know that creating and marketing a game is not easy. Game studios face numerous challenges related to sales and marketing, gamer experience, and of course testing & development. For example, studios might struggle with choosing a distribution and monetization strategy as well as think about player acquisition and retention, piracy and cheating, platform and hardware support, and much more. Not to mention the actual development related issues like choosing an engine, language, framework and how to conduct play testing and validation. 

{{< youtube 4Fa_B3LxEVM >}}

There's no easy road to making a profitable game that is fun to play and stands out from the crowd. You're swimming in a large pool that is full of talented sharks for a small piece of every gamer's time, money and attention. One of the best paths to success is creating a unique, engaging experience with endless playability and high potential for viral moments. This requires a solution that creates shared community experiences around your gameplay. In this post, we'll look at a solution that we've been working on called "Project Engage" that can help you to create dynamic, engaging gaming experiences with AWS.

## Enabling Your Game’s Success with AWS

Everyone knows that viral moments on social media are the cheat code that can skyrocket your game into the hearts and minds of players around the world. User-generated content live streaming platforms like Twitch have launched many games from small, indie studios into viral community superstardom. The combination of Amazon GameLift Streams, Amazon Interactive Video Service (Amazon IVS) and AWS AppSync is one approach that you can utilize to create a unique, interactive gaming experiences that delight both your players and your community.

So what are these services and how can you use them?

## Level 1: Boost Your Game with the Cloud

Amazon GameLift Streams is cloud gaming on AWS. It's an AWS service that gives anyone with an internet connection the ability to play fun and exciting games without needing high-end hardware. Amazon GameLift Streams is an AWS service that enables publishers to spawn on-demand, low latency games to players, globally at up to 1080p at 60 FPS. Players don't need a $3000 rig with a specialized GPU - just a stable connection and a controller or keyboard and mouse. Amazon GameLift Streams is easy to get started with and it directly addresses some of the challenges related to distribution that traditionally plague game studios. As we'll see below, when you combine it with Amazon IVS, you'll also be equipped to address some of the challenges around player acquisition and retention that keep you up at night.

![Amazon GameLift Streams](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-oa4i3tqh7lim1d5cjfb0.png)

## Level 2: User-Generated Content Is the New Meta

Amazon IVS is managed live streaming at scale on AWS. Like Amazon GameLift Streams, it has a proud lineage as it was born from the popular live-streaming platform Twitch. Since it was built by video experts and is powered by a global network of purpose-built, video optimized infrastructure, it enables you to focus on what matters: your community and your gamer’s experience. It’s not some watered-down, knock-off version. It’s the same servers and pipes that deliver Twitch’s traffic fully available for your live streaming workloads. This means that you can build high-quality, globally scalable, ultra-low latency interactive live streaming applications. 

We’ll dig deeper into the different ways that you can broadcast your Amazon GameLift Streams to Amazon IVS below, but there are two main approaches for this solution. The first (and most performant) option is to stream directly from the Amazon GameLift Streams instance via a small "sidecar" binary, like so:

![GameLift Streams Sidecar Broadcast](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5egrqbil7nkj9digeul7.png)

The second option is to utilize the Amazon IVS Web Broadcast SDK to re-stream the gameplay from the player’s browser.

![GameLift Streams Web Broadcast](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-hewfbcqtcl6mkwsqcjx4.png)

Want recordings for AI-based analysis or VOD playback later? Amazon IVS can record your live streams directly to Amazon Simple Storage Service (Amazon S3), so with some simple configuration your streams are automatically stored for future use.

![GameLift Streams Recorded to S3](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8dcsve5t7l5v878t4oly.png)

## Level 3: Chat, Is This Real?

AWS AppSync is the "glue" that binds these experiences by empowering you to send low-latency, high throughput chat and messages between your viewers and players. This messaging channel enables you to create dynamic gameplay that changes based on live-stream viewer feedback. Want to spawn a health pickup when viewers send their love to the player? Done. Want to modify the environment, or spawn enemies based on community interactions? No problem! What about giving your players new monetization options based on the popularity of their streams or their connection with the community? Easy! 

![Adding Interactivity with AppSync](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-mvfilqosxnhx6x08dwfl.png)

## Level 4: Opening the Loot Box

This combination of AWS services helps game developers solve some of their biggest problems. Betting and regulated gaming studios can give players real-time interaction from stream viewers which means that the viewers can also place wagers directly on the action which provides another level of excitement and entertainment. Instead of "leaning back" and consuming, they're "leaning forward" and participating. In this video, the game player is on the **left**, and the live stream viewer is on the **right**.

{{< youtube Q82XVKCzCf4 >}}

## Cheat Code for Viral Success

Depending on your use case and requirements, there are several ways to approach this solution. GameLift Streams are delivered to the player via an ultra-low latency WebRTC connection. 

### Direct Broadcasting From the GameLift Streams Instance (Sidecar)

For use cases that demand less network and resource utilization on the client side, the Amazon IVS broadcast can be sent directly from the Amazon GameLift Streams instance via the sidecar approach that was mentioned earlier in this post. In this approach, a small binary is packaged along with the game binary and deployed alongside the application. When the Amazon GameLift Session is launched, necessary configuration environment variables are passed via the Amazon GameLift Streams API. These variables contain an Amazon IVS participant token, as well as several video configuration arguments (for resolution, FPS, bitrate, etc.).

![Full Arch (Direct Broadcast)](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gq34unrvojulag2y6hmt.png)

As you can see in the following video, the latency with the sidecar approach is nearly imperceptible. Because the viewer interactions are handled via AWS AppSync, there is no need to sacrifice any user interactivity and engagement. Again, the player is on the **left**, and the viewer is on the **right**. If you’re interested in viewing the measured latency between the player and viewer, try to pause the video at different points and check the timer in the upper left corner.

{{< youtube FQeGqvR4OR8 >}}

### Rebroadcasting From the Player's Client (Amazon IVS Web Broadcast SDK)

Another option is to rebroadcast the gameplay. Once the GameLift Stream is received on the player side, you can capture that stream in the player’s browser and re-stream it to Amazon IVS via the Amazon IVS Web Broadcast SDK. This requires a bit more bandwidth on the player’s side, but it’s usually not enough to be noticeable or have much impact on the experience. 

![Full Arch (Web Broadcast)](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-pt22cokpeb7etys9f2ih.png)

The architecture shown above is demonstrated in the following video. On the **left** side of the screen, the player is playing in fullscreen mode, and the live stream view is shown on the **right** hand of the screen. There’s a barely perceivable amount of latency at times, but it’s not enough to impact the viewer interactivity. Notice how the viewer interactions (chat messages and emotes) are integrated into the game, so the player can feel the community support and engagement. Near the end of the video, you can see another advantage of using Amazon IVS real-time stages for the broadcast when you see the viewer’s view exit fullscreen. Since Amazon IVS real-time stages support multiple participants publishing, the player’s webcam and microphone are published as a separate stream so that viewers can see and hear the player without blocking the gameplay with a webcam overlay.

{{< youtube svwXRzBABcI >}}

## Easter Egg: Passing Control Between Multiple Participants

Play testing should happen early and often, but approaches vary. Some studios have dedicated testers, while others contract out and request recorded sessions for analysis. Imagine a system where:

- Play testers play directly from their browser without downloading the game (+1XP)
- You could join interactive sessions and provide real-time feedback (+10XP)
- Sessions automatically record to Amazon S3 for analysis (+100XP)
- Participants could pass gameplay control between each other (+10000XP)

Since Amazon GameLift Streams supports reconnecting to recently disconnected streams, this is achievable. Implement a control request system via AppSync messages—when a request is approved, the current session disconnects and passes the reconnect ID to the new player, who reconnects and broadcasts gameplay to other participants 

{{< youtube 3WTIY871ddw >}}

## Will You Accept the Quest?

To try this solution, we have created a couple of sample repos on GitHub that can be used with your AWS account. First, you will need to build the [sidecar client application](https://github.com/aws-samples/sample-gamelift-streams-ivs-broadcast-client) and place it in the same directory as your game binary. Then upload the sidecar and game binary to an S3 bucket and create a GameLift Streams Application and Stream Group in your AWS account. Once you have the Stream Group and Application IDs, you can deploy the [sample multi-view React web app](https://github.com/aws-samples/sample-amazon-gamelift-streams-multiview-amazon-ivs-react-app) to your AWS account using to the deployment instructions in the repo. 

Amazon GameLift Streams, Amazon IVS, and AWS AppSync offer numerous opportunities to improve your game development lifecycle and differentiate your games in a competitive market. Together, these services help create unique, interactive gaming experiences. It's time to level up your games on AWS.
