---
title: "Get Started Live Streaming in the Cloud with Amazon IVS"
slug: "get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg"
author: "Todd Sharp"
date: 2022-08-19T11:49:00Z
summary: "It’s becoming impossible to ignore live streaming. There are tons of studies that illustrate its..."
tags: ["aws", "cloud", "livestream", "amazonivs"]
canonical_url: "https://dev.to/aws/get-started-live-streaming-in-the-cloud-with-amazon-ivs-2pdg"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-fhvftvtn3kfs6783c2n6.jpeg"
---

It’s becoming impossible to ignore live streaming. There are tons of studies that illustrate its popularity and continued growth, but forget the numbers for just a second and consider how many of us consume news media, entertainment, and even how some of us workout. We’re becoming more dependent on the internet to deliver us what we want and need, and we want it fast, reliably and on-demand. 

I won’t spend a bunch of time trying to convince you that live streaming solves all of your problems. If you’re reading this, then you probably already have a good idea that live streaming is a great fit for your application. If not, you should still keep reading - trust me, even the smallest use cases can benefit from what we’re going to explore.

But - and I can tell you this from experience - it’s **really hard** to build a quality live streaming experience from the ground up. It sounds easy enough. If you wanted to, you could spin up a compute instance, update the OS, install some open source media server software, open the firewall and virtual network ports and get a stream up and running in a day. But what happens when someone connects to your stream from the other side of the world? What about when your stream gets really popular and a few thousand people want to view it? Are you prepared to manage auto scalers, and load balancers, and OS updates/patching/maintenance? Yeah, me neither. 

Really smart people have already solved this problem. Right now, there are about 2.5 million people watching a live stream on [Twitch](https://twitch.tv). By the end of the day, 31 million people will have tuned in at some point. In 2021, over [1.3 trillion (with a T) minutes](https://www.twitch.tv/p/press-center/) have been streamed on Twitch. That’s a **lot** of live streaming traffic. Twitch didn’t build [its product overnight](https://aws.amazon.com/blogs/media/how-twitch-built-the-global-live-streaming-network-that-powers-amazon-ivs/). Enter Amazon Interactive Video Service (or Amazon IVS). Amazon IVS is **the service** that powers Twitch. And you can use it to power your own interactive live video streaming applications. So, how does it work? There are several different options for broadcasting and playback, but at its core, Amazon IVS allows you to:

- Create a channel
- Create a playback interface
- Broadcast (stream)

There are different ways to create channels (console, CLI, SDK) and create playback interfaces (web, native). There are also different ways to broadcast (or “stream”) to your channels (desktop software, mobile apps, web broadcast). I’ll show you how all of these work in future posts, but today let’s get the basics out of the way by just creating a channel and streaming to it. If you’ve never live streamed before, the quickest way to get started from your laptop/desktop is to install something like [Streamlabs Desktop](https://streamlabs.com/) or [OBS](https://obsproject.com/). Another quick and easy way to stream is to do it directly from the command line with [FFMPEG](https://ffmpeg.org), but this method will not include some of the nicer features of other options (like easily streaming a desktop window or application and adding fun transitions to your scenes). Still, it’s an easy way to test your channel. We’ll look at how to use FFMPEG in a future post.

## Creating an AWS Account

First things first - you’ll need an AWS account to get started. Don’t have one yet? [Sign up](https://aws.amazon.com/free) is easy, and new accounts can take advantage of the [AWS Free Tier for Amazon IVS](https://aws.amazon.com/ivs/pricing/) (5 hours of basic input and 100 hours of SD video output each month - plus more). Trying Amazon IVS can cost you nothing, so sign up and follow along with this post to create your own channel (and stay tuned for future posts where we dig into much more)! 

> Wondering what it’ll cost to run Amazon IVS in your production application? Check out the [Amazon IVS Cost Estimator](https://ivs.rocks/calculator)!

## Creating a Channel

Got that new account created? Great, let’s create a channel! Head over to the [Amazon IVS Management Console](https://console.aws.amazon.com/ivs). The first thing to do here is select a region for control and creation of your streams:

![Selecting an Amazon IVS control plane region](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ze0n3kabxptmnyby5615.png)

Don’t worry – video ingestion and delivery are available around the globe over a separate managed network of infrastructure that is optimized for live video. Now that we’ve selected a region on the Amazon IVS Management Console home page, click on **Create Channel**.

![Create channel button in the Amazon IVS Management Console](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-h2gkterqvus2pgia17cg.png) 

On the Create Channel page, the first thing we’ll need to do is give our channel a name:

![Entering a channel name in the Amazon IVS Management Console](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-vj4jwjo1lm4mi16zdldt.png)

Next, under **Channel configuration**, select **Custom configuration**. If you created a new account, the AWS Free Tier applies to **Basic** channel types, so we'll select that. Leave **Ultra-low latency** selected.

![Amazon IVS Channel configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-buco1lt06o7mpt5o3t1i.png)

Amazon IVS supports playback authorization with authentication tokens. We won’t dig into this today, so leave **Playback authorization** disabled.

![Playback authorization option](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-u8882uzrrldc3pbz61e2.png) 

If you want to capture all of your live streams for future playback, select **Auto record to S3**. This can be super handy if you are streaming something like a webinar or conference session and would like to offer on-demand playback later on. For now, let’s leave this disabled.

![Record and store streams options](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-v8t14hs3nis1no9olvb5.png)

If you’d like to tag your channel, you can enter them in the next section. Once you’re done, click **Create channel**.

![Tag input and create channel button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-u8wpjl2odwymax061us9.png)

## Channel Details

After we create our channel, we’re redirected to the Channel details page. At the top of this page, there is some helpful text and links to the Amazon IVS docs.

![Get started text](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rw1td5a2ba07rsm37xnq.png)

Scroll down a bit to view a summary of the options that we selected for our channel.

![Channel summary](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-qsxrqpd767hqg89gbfm7.png)

If we plan to do any work with this channel via an SDK or CLI, we’ll need to take note of the channel ARN.

Below the channel summary, we can see a panel titled **Live stream**.

![Live stream panel initially collapsed](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jz0qbuo35jw8mfu14cuw.png)

Expanding this panel (by clicking on the panel header) will reveal a built-in video player that we can use to view the current video on our stream. Since we’re not broadcasting yet, the player will be initially offline.

![Live stream player - initially offline](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nhmpchql6avjh0i7lfrd.png)

Below the live stream player is a panel dedicated to **Timed metadata**. 

![Timed metadata panel collapsed](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-negt2etoyiwp88fx83v1.png)

Timed metadata is an exceptional feature that lets us inject data payloads into our video stream that we can retrieve on the client side at the exact point in time that we broadcast it to the stream. This is super handy and can enable some pretty interactive content. Again, we’ll save this topic for a future post!

Below the timed metadata panel is the **Stream configuration** panel, which contains our **Stream key** and **Ingest server**.

![Stream configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dfghv7yztq1ie4vnjssu.png)

Note both values, as we’ll use them in just a bit to stream to our channel via `rtmps` with OBS and FFMPEG. We can also stream via the Web Broadcast SDK (using the endpoint specified under **Other ingest options**). Yeah, that’s also another post...

Scrolling down more will reveal our custom **Playback URL** in the **Playback configuration** panel.

![Playback configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-oe2aakh6x853vedw43ql.png)

We’ll use this in a future post when we take a look at the various options for stream playback. We won’t need this value today, since we’re just going to test our stream in the Amazon IVS console.

## Creating a Channel via the AWS CLI

If you prefer to use the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) to manage your AWS resources, you can create a channel with the same configuration that we used above via the following command:

```bash
$ aws \
    ivs \
    create-channel \
    --name my-first-ivs-channel \
    --type BASIC \
    --latency-mode LOW \
    --no-authorized
```

When creating your channel via the CLI, all the information that is displayed in the stream detail information (the channel ARN, stream key, etc.) get returned in a JSON object.

```json
{
    “channel”: {
        “arn”: “arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]”,
        “authorized”: false,
        “ingestEndpoint”: “[redacted].global-contribute.live-video.net”,
        “latencyMode”: “LOW”,
        “name”: “my-first-ivs-channel”,
        “playbackUrl”: “https://[redacted].us-east-1.playback.live-video.net/api/video/v1/us-east-[redacted].channel.[redacted].m3u8”,
        “recordingConfigurationArn”: “”,
        “tags”: {},
        “type”: “BASIC”
    },
    “streamKey”: {
        “arn”: “arn:aws:ivs:us-east-1:[redacted]:stream-key/[redacted]”,
        “channelArn”: “arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]”,
        “tags”: {},
        “value”: “sk_us-east-[redacted]”
    }
}
```

## We’re Live in 3, 2, 1...

We’re ready to go live! Make sure that you have your stream key and ingest endpoint handy and fire up OBS. In OBS, select **Profile**, then **New** and name your profile **my-first-ivs-channel**. In the **Auto-Configuration Wizard**, choose **Optimize for streaming, recording is secondary** and click **Next**.

![OBS auto configuration wizard step 1](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8n4wgxxf9d7uk2run1gy.png)

In the next step, accept the default values.

![OBS video settings](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ygsz4qmll2nu3hxyll2w.png)

Next, choose **Custom** in the **Service** input dropdown, and enter your Amazon IVS ingest endpoint as the **Server** and paste our **Stream Key** in the input box. Leave **Estimate bitrate and bandwidth** checked and click **Next**.

![OBS Stream information](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-uzk1w1do9s7cnkmxyt4w.png)

OBS will now run some tests to estimate the ideal settings for this channel.

![OBS stream test](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-cz0qtbibsimy9jnatwbv.png)
 
Once the test is complete, OBS will output the results. We’ll accept the recommendations here (note that since this is a **Basic** channel, OBS properly detected the output resolution of 480p).

![OBS stream test results](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wt1e9e0ixk58gqfbhmd1.png) 

Click **Apply Settings** and in the main OBS window, select the first **Scene** under **Scenes**. In **Sources**, click on the plus icon and select **Video Capture Device**. Choose your webcam and add it as a **Source**. You should now see a preview of your stream in OBS:

![OBS configured to stream to Amazon IVS](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-703eqyxyrhwruo1zjfjj.png)

The only thing standing between us and our live stream is clicking on the **Start Streaming** button (shown in the screenshot above). So, what are we waiting for, let’s click it! Once we’ve started streaming, we can head back to the Amazon IVS Management Console and reload our stream details page and expand the live viewer to see our live stream.

![Testing the live stream in the Amazon IVS Management Console](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jm5o13wg4ap9obf7vgve.png)

And that’s it! We’re live streaming to the internet! 

## Summary 

In this post, we created our very first channel with Amazon IVS and started our very first live stream. As I mentioned several times, there is so much more to IVS. Stay tuned here for more posts soon where we will look at the various options for broadcasting, playback, and adding interactive features (like live chat, and more)! If you have questions, leave a comment below or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by [Greg Peatfield](https://pixabay.com/users/mazecreatormarketing-22291869/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=6375274) from [Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=6375274)