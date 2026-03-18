---
title: "Live Streaming from Unity - Dynamic & Interactive Streams (Part 5)"
slug: "live-streaming-from-unity-dynamic-interactive-streams-part-5-41lj"
author: "Todd Sharp"
date: 2024-02-23T15:52:00Z
summary: "So far in this series, we've learned how to broadcast from a game created in Unity to an Amazon..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-dynamic-interactive-streams-part-5-41lj"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-g68tpawls82vujszv0eu.png"
imagecontain: true
---

So far in this series, we've learned how to broadcast from a game created in Unity to an Amazon Interactive Video Service (Amazon IVS) real-time stage, and how to integrate Amazon IVS chat directly into a game. In this post, we'll build on these concepts to create a dynamic experience by creating interactive user-controlled streams that allow viewers to change the camera angle on-demand and directly impact the gameplay.

These capabilities game developers the ability to create a **truly unique experience** for stream viewers. Have you ever wanted to see what's going on from a top-down view? What about checking to see what's behind the player, or around the next corner? What about game objectives and environments that can change based on viewer feedback? This is all possible, and we'll see how it's done in this post!

## Dynamic User-Controlled Camera

Since we're building on the previous posts in this series, we won't cover everything about broadcasting to a real-time stage or connecting to an Amazon IVS chat room. If you're not familiar with that process, check out parts 2, 3 & 4.

To build a dynamic, user-controlled camera view, we're going to again use the 'Karting Microgame' learning demo game in Unity. Feel free to reuse the game that we created in part 2, but make sure to add the `NativeWebSocket` package and configure chat as shown in part 4 of this series.

Because we want the viewers to have their own view, we'll need to duplicate the existing `CinemachineVirtualCamera`.

![Duplicate CinemachineVirtualCamera](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-yr04kjku1kevulc00tbz.png)

After duplicating, rename it to `WebRTCCinemachineVirtualCamera` and add a child camera to it called `WebRTCPublishCamera`. This is the camera that we'll attach our `WebRTCPublish` script to. As mentioned above, we'll need to add chat to this script. Refer to part 4 for the code necessary to do this, or see the full script in the summary below. Once we've added chat support, in the `OnMessage` handler, we can manipulate the camera view by getting a reference to the camera's follow offset and adjusting it as necessary.

```cs
var body = virtualCamera.GetCinemachineComponent<CinemachineTransposer>();
float currentX = body.m_FollowOffset[0];
float currentY = body.m_FollowOffset[1];
float currentZ = body.m_FollowOffset[2];
```

To keep things simple for this demo, we'll listen for incoming messages that contain the words `up`, `down`, `left`, `right`, `in`, or `out`. If the message contains these commands, we'll adjust the follow offset.

```cs
if (chatMsg.Content.ToLower() == "up")
{
  body.m_FollowOffset = new Vector3(currentX, currentY + 0.5f, currentZ);
}
if (chatMsg.Content.ToLower() == "down")
{
  body.m_FollowOffset = new Vector3(currentX, currentY - 0.5f, currentZ);
}
if (chatMsg.Content.ToLower() == "left")
{
  body.m_FollowOffset = new Vector3(currentX - 0.5f, currentY, currentZ);
}
if (chatMsg.Content.ToLower() == "right")
{
  body.m_FollowOffset = new Vector3(currentX + 0.5f, currentY, currentZ);
}
if (chatMsg.Content.ToLower() == "out")
{
  body.m_FollowOffset = new Vector3(currentX, currentY, currentZ - 0.5f);
}
if (chatMsg.Content.ToLower() == "in")
{
  body.m_FollowOffset = new Vector3(currentX, currentY, currentZ + 0.5f);
}
```

In this video, I've added some buttons in the chat UI to make it easier for viewers to send the necessary commands.

{{< youtube OheONuM6tuo >}}

As you can see, the viewers have their own view of the gameplay, and can manipulate that camera view without impacting the gameplay camera. You could even have pre-configured view settings (IE: 'top down') instead of directly manipulating the camera position. There are tons of possibilities here for dynamic experiences that can make viewing the live stream an experience that isn't available on any live streaming platform today!

## Dynamic Environment and Objectives

Adding a viewer-controlled camera view that does not affect gameplay is exciting, but I think it is even more exciting to be able to actually modify the player's environment and the game objectives based on viewer feedback. In this way, a player can have a new experience every time they play the game. It also gives viewers a new level of interactivity that has never been seen before. Amazingly, with the configuration that we have done already - there's not much to this.

### Dynamic Objectives

Let's modify the objective. In this demo, there's not much to the game. The Karting game asks the player to complete all checkpoints in a specified time period. But what if the viewers could add or subtract to the objective time? Here we'll just accept a chat command to modify the objective, but it could certainly be based on the results of a poll given to all viewers in chat to keep things democratic 😄.

We can modify the `WebRTCPublish` script to get a reference to the `TimeManager` script in the Karting demo, and make the `AdjustTime()` function `public` instead of `private`.

In `WebRTCPublish`, we can declare a `timeManager` variable of type `TimeManager` and in `Start()` set that value.

```cs
timeManager = GameObject.FindObjectOfType(typeof(TimeManager)) as TimeManager;
```

Now in the `OnMessage` handler, we listen for a few new commands, and modify the objective as necessary!

```cs
if (chatMsg.Content.ToLower() == "+10")
{
  timeManager.AdjustTime(10f);
}
if (chatMsg.Content.ToLower() == "-10")
{
  timeManager.AdjustTime(-10f);
}
```

See the video below to see this in action.

### Dynamic Environments

To spawn dynamic environment elements, we declare a `jump` and `kart` variable in our `WebRTCPublish` script and bind the `KartClassic_Player` and `JumpRamp` game objects to these variables.

```cs
public GameObject jump;
public GameObject kart;
```

![Bind jump and kart](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-chdut1yhgt705j6d5ygo.png)

If a message `jump` is received in the `OnMessage` chat handler, we'll get the kart's current position, direction and rotation and clone and spawn the jump ramp directly in front of the kart.

```cs
if (chatMsg.Content.ToLower() == "jump")
{
  Vector3 kartPos = kart.transform.position;
  Vector3 kartDirection = kart.transform.forward;
  Quaternion kartRotation = kart.transform.rotation;
  float spawnDistance = 10;
  Vector3 spawnPos = kartPos + kartDirection * spawnDistance;
  Instantiate(jump, spawnPos, kartRotation);
}
```

Here's how our experience looks with dynamic environments and viewer controlled objectives.

{{< youtube 28Ai8WMR8pY >}}

## Summary

I hope this post excites you as much as it excites me! Yes, we've used a very simple proof of concept here, but there are endless possibilities for the techniques used in this post to create a fun community around your game and bring the players and viewers closer than ever before. We've scratched the surface on modifying the viewer's experience without impacting gameplay via dynamic camera angles, and created a way to modify the game environment and objectives via viewer input. In the next post, we'll look at another fun approach - multiple camera live streams! Here is the [full script](https://gist.github.com/recursivecodes/0c48d1d114a5396ed305cc525a399576) that was used in this post as a reference.
