---
title: "Adding a Remote Participant View for Real-Time Streams in OBS"
slug: "adding-a-remote-participant-view-for-real-time-streams-in-obs-23a7"
author: "Todd Sharp"
date: 2024-08-12T12:40:50Z
summary: "In the last post in this series, we saw that utilizing custom docks in OBS is a great way to improve..."
tags: ["aws", "amazonivs", "obs", "livestream"]
canonical_url: "https://dev.to/aws/adding-a-remote-participant-view-for-real-time-streams-in-obs-23a7"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-es5r0savh4o5gr2vw796.png"
imagecontain: true
---

In the last post in this series, we saw that utilizing custom docks in OBS is a great way to improve the user experience when broadcasting to an Amazon Interactive Video Service (Amazon IVS) real-time stage. In that post, we used a custom dock to generate participant tokens (and even set them directly into the user's OBS configuration) which makes it easier for broadcasters to stream without having to use your web application to create a new token via the browser. In this post, we'll address another tricky use case - how to see and hear other participants in a real-time stream directly in OBS. This makes it much easier for your broadcasters to use OBS - again - without having to rely on an open browser tab to talk to remote participants.

## Creating a Remote Participant View

It's actually rather simple to create a dedicated view that can be used as a custom dock in OBS to allow broadcasters to see and hear other participants. With the [Amazon IVS Web Broadcast SDK](https://aws.github.io/amazon-ivs-web-broadcast/docs/real-time-sdk-guides/introduction), create an instance of the Amazon IVS stage client with a valid participant token and render the participants to the page in a single column view. This view can be customized as necessary, but I like to keep it clean and just present the participant audio and video. The only addition is a simple toggle to show/hide individual participants. Since the broadcaster themselves will also be listed, this allows them to hide themselves from the view to prevent audio echo. If desired, you could also implement additional logic to prevent rendering the broadcaster by passing in the broadcaster's `userId`.

Once you've created a view to render the stage participants, add it as a custom dock in OBS.

![Add dock](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-oljul43hr587fr3n859n.png)

![Add dock link](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bjw2z6u2u30mk33jpqwr.png)

As participants join and leave the stage, they will be shown in the custom dock in OBS.

![Participant view](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-11daspswb74yexh0onzr.png)

![Participant view full](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rht22sr33v09iqgy58oe.png)

Which means that your user can broadcast to the Amazon IVS real-time stage in OBS without needing to keep a browser tab open to see and hear the other stage participants! Of course, with a web based view, the other participants can still see and hear everyone on the stage - including the person broadcasting from OBS.

![Web based view](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8vvpavnk8p61bngc4lsi.png)

## Summary

In this post, we saw how it is possible to allow your broadcasters to see and hear other Amazon IVS real-time stage participants directly in OBS. In the next post, we'll look at creating browser sources in OBS to allow your users to broadcast a real-time stage to their Amazon IVS low-latency channels to reach millions of viewers!
