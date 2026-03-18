---
title: "Live Streaming from Unity - Broadcasting a Game With Full UI (Part 3)"
slug: "live-streaming-from-unity-broadcasting-a-game-with-full-ui-part-3-4e7o"
author: "Todd Sharp"
date: 2024-02-16T18:03:03Z
summary: "In the last post in this series, we walked through the process of configuring a Unity game to..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-broadcasting-a-game-with-full-ui-part-3-4e7o"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-im3u9zplvm6epn9m49e4.png"
imagecontain: true
---

In the last post in this series, we walked through the process of configuring a Unity game to broadcast a real-time stream directly to an Amazon Interactive Video Service (Amazon IVS) stage.

You may have noticed a few things missing from the resulting stream - notably the heads-up display (HUD) and UI overlays. This is because the HUD in the demo game that we were using is rendered inside of a canvas element that is configured to use 'Screen Space - Overlay' which means it renders on top of everything that the camera renders to the game screen, but not on top of the camera that we used to stream the gameplay. That's not necessarily a bad thing since UI screens can sometimes contain personally identifiable information (PII) like a player's IP address, physical location, name, etc. But we may want things like the match timer and on-screen notifications visible to the stream viewers. The exact approach here will depend on your game. For example, some games implement a feature to mask usernames.

![COD Streamer Mode](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-s5nwmihcgjfuj1idd68t.png)

In this post, we'll look at one approach to stream the entire screen including HUD and UI elements. I'll assume that you've read the previous post in this series (part 2), and we'll modify the `WebRTCPublish` script from that post to stream the entire UI. For reference, here's the entire final script:

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
  AudioStreamTrack audioTrack;
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
      new StageTokenRequestAttributes("ivs-rtx-broadcast-demo")
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

  IEnumerator DoWHIP()
  {
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
    if (peerConnection != null)
    {
      peerConnection.Close();
      peerConnection.Dispose();
    }
    if (videoTrack != null) videoTrack.Dispose();
    if (audioTrack != null) audioTrack.Dispose();
  }
}
```

## Modify Publish Script to Stream Entire UI

Before we modify the script, let's delete the `WebRTCPublishCamera` that we added last time. We won't need it anymore. Don't worry, deleting the game object will not delete the script itself.

![Delete camera](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ue30d9z68xdgwgmlkf4x.png)

Next, select the `CinemachineVirtualCamera` and scroll down in the 'Inspector' until you see the 'Add Component' button. Click 'Add Component', scroll down to 'Scripts', and find and select our `Web RTC Publish` script.

![Add WebRTCPublish Script](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tqr9kpqyfv88qwzmn3n4.gif)

Open the `WebRTCPublish` script in your editor. Replace the declaration for `cam` with two variables:

```cs
RenderTexture renderTexture;
Texture2D screenshotTexture;
```

Next, inside `Start()`, replace the following lines:

```cs
cam = GetComponent<Camera>();
videoTrack = cam.CaptureStreamTrack(1280, 720);
```

We can't use this camera, because `CaptureStreamTrack` would make the camera output inaccessible within the game (which would probably make it difficult to play 😵). Instead, we'll use a `RenderTexture` as the source of the `VideoTrack`.

```cs
screenshotTexture = new Texture2D(1280, 720, TextureFormat.RGB24, false);
renderTexture = new RenderTexture(1280, 720, 24);
videoTrack = new VideoStreamTrack(renderTexture);
```

Next we'll need to update the `renderTexture` at the end of every frame in order to construct a video feed. Add a `LateUpdate()` function and start a coroutine called `RecordFrame()` that we'll define in just a second.

```cs
void LateUpdate()
{
  StartCoroutine(RecordFrame());
}
```

In `RecordFrame()`, we'll begin by waiting for the end of the frame, then capture a screen shot, flip it and ensure the image resolution matches the current max resolution for our Amazon IVS stage (720p), and update the global `renderTexture` which is already associated with our `videoTrack`.

```cs
IEnumerator RecordFrame()
{
  yield return new WaitForEndOfFrame();
  RenderTexture tempTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Default, 1);
  ScreenCapture.CaptureScreenshotIntoRenderTexture(tempTexture);
  RenderTexture transformedTexture = RenderTexture.GetTemporary(1280, 720, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Default, 1);
  Graphics.Blit(tempTexture, transformedTexture, new Vector2(1, -1), new Vector2(0, 1));
  Graphics.Blit(transformedTexture, renderTexture);
  RenderTexture.ReleaseTemporary(tempTexture);
  screenshotTexture.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0);
  RenderTexture.ReleaseTemporary(transformedTexture);
  screenshotTexture.Apply();
}
```

## Test Playback

At this point, we're ready to test playback again. Again, you can generate a token via your local service that we created in the last post and paste it into this [CodePen](https://codepen.io/amazon-ivs/project/editor/ZzWobn), or create a local playback page with the [Amazon IVS Web Broadcast SDK](https://aws.github.io/amazon-ivs-web-broadcast/docs/real-time-sdk-guides/introduction). Fire up the game and give it a play, and you'll now notice the HUD

{{< youtube 6uge_h8wHcY >}}

## Final Script

Here's the entire script after our modifications from the last post.

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
  AudioStreamTrack audioTrack;
  RenderTexture renderTexture;
  Texture2D screenshotTexture;
  ParticipantToken participantToken;
  async Task<StageToken> GetStageToken()
  {
    using UnityWebRequest www = new UnityWebRequest("http://localhost:3000/token");
    StageTokenRequest tokenRequest = new StageTokenRequest(
      "[YOUR STAGE ARN]",
      System.Guid.NewGuid().ToString(),
      1440,
      new string[] { "PUBLISH", "SUBSCRIBE" },
      new StageTokenRequestAttributes("ivs-rtx-broadcast-demo")
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
    screenshotTexture = new Texture2D(1280, 720, TextureFormat.RGB24, false);
    renderTexture = new RenderTexture(1280, 720, 24);
    videoTrack = new VideoStreamTrack(renderTexture);
    peerConnection.AddTrack(videoTrack);
    AudioListener audioListener = GetComponent<AudioListener>();
    audioTrack = new AudioStreamTrack(audioListener) { Loopback = true };
    peerConnection.AddTrack(audioTrack);
    StartCoroutine(DoWHIP());
  }

  IEnumerator RecordFrame()
  {
    yield return new WaitForEndOfFrame();
    RenderTexture tempTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Default, 1);
    ScreenCapture.CaptureScreenshotIntoRenderTexture(tempTexture);
    RenderTexture transformedTexture = RenderTexture.GetTemporary(1280, 720, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Default, 1);
    Graphics.Blit(tempTexture, transformedTexture, new Vector2(1, -1), new Vector2(0, 1));
    Graphics.Blit(transformedTexture, renderTexture);
    RenderTexture.ReleaseTemporary(tempTexture);
    screenshotTexture.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0);
    RenderTexture.ReleaseTemporary(transformedTexture);
    screenshotTexture.Apply();
  }

  void LateUpdate()
  {
    StartCoroutine(RecordFrame());
  }

  IEnumerator DoWHIP()
  {
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
    if (peerConnection != null)
    {
      peerConnection.Close();
      peerConnection.Dispose();
    }
    if (videoTrack != null) videoTrack.Dispose();
    if (audioTrack != null) audioTrack.Dispose();
  }
}
```

## Summary

In this post, we modified our script to broadcast from our game to an Amazon IVS stage in real-time to include the HUD and UI overlays. In our next post, we'll introduce integrating Amazon IVS chat directly into our game. This can be used to let the streamer keep an eye on their stream chat, and even directly respond from within the game itself. But it also lays the foundation to use the Amazon IVS chat connection as a message bus for future dynamic interactions as we'll see in another future post.
