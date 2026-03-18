---
title: "Live Streaming from Unity - Broadcasting from a Meta Quest (Part 8)"
slug: "live-streaming-from-unity-broadcasting-from-a-meta-quest-part-8-3e3f"
author: "Todd Sharp"
date: 2024-03-13T11:54:51Z
summary: "We've already seen how to broadcast from a game built in Unity directly to a real-time live stream..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-broadcasting-from-a-meta-quest-part-8-3e3f"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6qesfbv4qmzqt3f8hbwv.png"
imagecontain: true
---

We've already seen how to broadcast from a game built in Unity directly to a real-time live stream with Amazon Interactive Video Service (Amazon IVS). If you need a refresher, or you missed any of the previous posts, be sure to check them out to learn how to create an Amazon IVS stage, generate participant tokens, and broadcast from a Unity camera. In this post, we'll see that broadcasting from a VR game built for the Meta Quest is just as straightforward as it is from a non-VR game.

## Adding a Streaming Camera

For this demo, we'll use the [Unity First Hand](https://github.com/oculus-samples/Unity-FirstHand) demo app. Follow the instructions in that repo to get the game downloaded and setup in Unity, and once you've got the project open we'll add a new camera that will be used for the live stream. In the project explorer (Hierarchy view) add a camera as a child to `CenterEyeAnchor` called `WebRTCPublishCamera`.

![WebRTCPublishCamera](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-vev0b2chk07xgcjaqspy.png)

Next, add a script to `WebRTCPublishCamera` called `WebRTCPublish`. This script is exactly the same as we have previously used, so I'll post it in its entirety below.

```cs
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using Unity.WebRTC;
using UnityEngine.Networking;

[System.Serializable]
public class ParticipantToken
{
  public string token;
  public string participantId;
  public System.DateTime expirationTime;
  public static ParticipantToken CreateFromJSON(string jsonString)
  {
    return JsonUtility.FromJson<ParticipantToken>(jsonString);
  }
}

[System.Serializable]
public class StageToken
{
  public ParticipantToken participantToken;
  public static StageToken CreateFromJSON(string jsonString)
  {
    return JsonUtility.FromJson<StageToken>(jsonString);
  }
}

[System.Serializable]
public class StageTokenRequestAttributes
{
  public string username;
  public StageTokenRequestAttributes(string username)
  {
    this.username = username;
  }
}

[System.Serializable]
public class StageTokenRequest
{
  public string stageArn;
  public string userId;
  public int duration;
  public StageTokenRequestAttributes attributes;
  public string[] capabilities;
  public StageTokenRequest(string stageArn, string userId, int duration, string[] capabilities, StageTokenRequestAttributes attributes)
  {
    this.stageArn = stageArn;
    this.userId = userId;
    this.duration = duration;
    this.capabilities = capabilities;
    this.attributes = attributes;
  }
}

[RequireComponent(typeof(AudioListener))]
public class WebRTCPublish : MonoBehaviour
{
  RTCPeerConnection peerConnection;
  MediaStreamTrack videoTrack;
  public AudioStreamTrack audioTrack;
  Camera cam;
  ParticipantToken participantToken;

  async Task<StageToken> GetStageToken()
  {
    using UnityWebRequest www = new UnityWebRequest("http://localhost:3000/token");
    StageTokenRequest tokenRequest = new StageTokenRequest(
        "[YOUR STAGE ARN]",
        System.Guid.NewGuid().ToString(),
        1440,
        new string[] { "PUBLISH", "SUBSCRIBE" },
        new StageTokenRequestAttributes("ivs-rtx-meta-quest-demo-user")
      );
    www.uploadHandler = new UploadHandlerRaw(System.Text.Encoding.ASCII.GetBytes(JsonUtility.ToJson(tokenRequest)));
    www.downloadHandler = new DownloadHandlerBuffer();
    www.method = UnityWebRequest.kHttpVerbPOST;
    www.SetRequestHeader("Content-Type", "application/json");
    var request = www.SendWebRequest();
    while (!request.isDone)
    {
      await Task.Yield();
    };
    var response = www.downloadHandler.text;
    Debug.Log(response);
    if (www.result != UnityWebRequest.Result.Success)
    {
      Debug.Log(www.error);
      return default;
    }
    else
    {
      StageToken stageToken = StageToken.CreateFromJSON(www.downloadHandler.text);
      Debug.Log(stageToken);
      participantToken = stageToken.participantToken;
      return stageToken;
    }
  }

  async void Start()
  {
    StartCoroutine(WebRTC.Update());
    peerConnection = new RTCPeerConnection
    {
      OnIceConnectionChange = state => { Debug.Log("Peer Connection: " + state); }
    };
    cam = GetComponent<Camera>();
    videoTrack = cam.CaptureStreamTrack(1280, 720);
    peerConnection.AddTrack(videoTrack);
    AudioListener audioListener = cam.GetComponent<AudioListener>();
    audioTrack = new AudioStreamTrack(audioListener) { Loopback = true };
    peerConnection.AddTrack(audioTrack);
    StartCoroutine(DoWHIP());
  }

  void Update()
  {

  }

  IEnumerator DoWHIP()
  {
    Debug.Log("DoWhip");

    Task getStageTokenTask = GetStageToken();
    yield return new WaitUntil(() => getStageTokenTask.IsCompleted);
    Debug.Log(participantToken.token);
    Debug.Log(participantToken.participantId);

    var offer = peerConnection.CreateOffer();
    yield return offer;

    var offerDesc = offer.Desc;
    var opLocal = peerConnection.SetLocalDescription(ref offerDesc);
    yield return opLocal;

    var filteredSdp = "";
    foreach (string sdpLine in offer.Desc.sdp.Split("\r\n"))
    {
      if (!sdpLine.StartsWith("a=extmap"))
      {
        filteredSdp += sdpLine + "\r\n";
      }
    }
    using (UnityWebRequest www = new UnityWebRequest("https://global.whip.live-video.net/"))
    {
      www.uploadHandler = new UploadHandlerRaw(System.Text.Encoding.ASCII.GetBytes(filteredSdp));
      www.downloadHandler = new DownloadHandlerBuffer();
      www.method = UnityWebRequest.kHttpVerbPOST;
      www.SetRequestHeader("Content-Type", "application/sdp");
      www.SetRequestHeader("Authorization", "Bearer " + participantToken.token);
      yield return www.SendWebRequest();
      if (www.result != UnityWebRequest.Result.Success)
      {
        Debug.Log(www.error);
      }
      else
      {
        var answer = new RTCSessionDescription { type = RTCSdpType.Answer, sdp = www.downloadHandler.text };
        var opRemote = peerConnection.SetRemoteDescription(ref answer);
        yield return opRemote;
        if (opRemote.IsError)
        {
          Debug.Log(opRemote.Error);
        }
      }
    }
  }

  async void OnDestroy()
  {
    Debug.Log("OnDestroy");
    peerConnection.Close();
    Debug.Log(peerConnection.IceConnectionState);
    peerConnection.Dispose();
    if (videoTrack != null) videoTrack.Dispose();
    if (audioTrack != null) audioTrack.Dispose();
  }
}
```

We've got a few classes to model stage token requests. Those requests are posted to a service which returns a stage token (see the `simple-ivs-token-service` [script](https://gist.github.com/recursivecodes/8b7ad5fff4e9acf96692b67356dbd2c2) for an example implementation). We establish a `peerConnection`, get a remote SDP, and wire the camera up to the `peerConnection` as a `MediaTrack`. That's it!

## Streaming VR Gameplay

At this point we're ready to test it out. Launch the First Hand demo on a Meta Quest device, and check the output via your own custom web based interface (or the [CodePen](https://codepen.io/amazon-ivs/project/editor/ZzWobn) that we used before).

{{< youtube 5Jqs7i1jH4o >}}

## Summary

In this post, we used the techniques that we've learned in this series to broadcast a real-time stream to Amazon IVS from a Meta Quest VR headset. We could add a button that the player has to press to start the stream, integrate viewer chat (see part 4), spawn dynamic game elements (part 5) and much more - the possibilities are exciting and endless. In the next post, we'll wrap up this series with a look at using the techniques we've learned so far to broadcast a game directly to Twitch instead of an Amazon IVS stage.
