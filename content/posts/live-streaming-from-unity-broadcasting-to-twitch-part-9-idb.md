---
title: "Live Streaming from Unity - Broadcasting to Twitch (Part 9)"
slug: "live-streaming-from-unity-broadcasting-to-twitch-part-9-idb"
author: "Todd Sharp"
date: 2024-03-20T14:15:45Z
summary: "In this series, we've seen various approaches to live stream directly to and from an Amazon..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-broadcasting-to-twitch-part-9-idb"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bdrajww75o0asff1he92.png"
imagecontain: true
---

In this series, we've seen various approaches to live stream directly to and from an Amazon Interactive Video Service (Amazon IVS) real-time stage from a game built in Unity. As we've discussed throughout this series, the various approaches give developers the ability to build a unique, dynamic and interactive game streaming community around their game with numerous benefits to both the player and the stream viewers. But sometimes your playerbase has an established community that they'd like to broadcast to.

In our final post, we'll switch gears and modify our game to broadcast directly to a user's Twitch channel. This of course means that we'll lose some of the interactivity and benefits of building, moderating, and monetizing our own community, but it's still a nice feature to add for your users and provides an easy integration for users who might not need the power and flexibility that third-party streaming software like OBS provides.

## Build UI for Stream Key

We're going to use the 'Karting Microgame' demo app for this demo, and since we will need the player's Twitch stream key to broadcast, we can enhance the game's menu to provide a text input and a button to allow them to start the broadcast.

![Karting menu changes](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-11ei9p2304q3sjqfc7nb.png)

## Add Broadcasting Script

Create a new script called `TwitchPublish` and attach it to the `MainCamera`. We're going to broadcast the entire UI to Twitch, including the HUD and all UI elements, so we'll use the approach outlined in part 2 of this series. First, declare a `renderTexture` and `screenshotTexture`, a string that will contain the `streamKey`, and a `Button` that we can use to enable and disable the 'Broadcast' button depending on the stream's state.

```cs
RenderTexture renderTexture;
Texture2D screenshotTexture
string twitchStreamKey = "";
public Button broadcastButton;
```

Next we'll add `SetStreamKey()` and `Broadcast()` functions.

```cs
public void SetStreamKey(string s)
{
  twitchStreamKey = s;
  broadcastButton.interactable = s.Length > 0;
}

public void Broadcast()
{
  StartCoroutine(DoWHIP());
}
```

Bind the `On End Edit` event of the stream key text input to the `SetStreamKey()` function.

![Stream key input bind](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-crven3hhii6blizbk1y0.png)

And the `On Click` event of the 'Broadcast to Twitch' button to the `Broadcast()` function.

![Broadcast button bind](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-mze20zmpilqaojuefh6w.png)

The `RecordFrame()` and `LateUpdate()` functions are the same as they were in part 2.

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

void LateUpdate()
{
  StartCoroutine(RecordFrame());
}
```

Instead of an Amazon IVS participant token, we'll pass the Twitch `streamKey` as the `Bearer` token in the `Authorization` header. The only other change to `DoWhip()` is the use of a new endpoint for SDP generation - this one now utilizes a URL specific to Twitch for WebRTC ingest: `https://g.webrtc.live-video.net:4443/v2/offer`.

```cs
IEnumerator DoWHIP()
{
  peerConnection.AddTransceiver(TrackKind.Audio);
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

  using (UnityWebRequest www =
    new UnityWebRequest(
      "https://g.webrtc.live-video.net:4443/v2/offer"
    )
  )
  {
    www.uploadHandler = new UploadHandlerRaw(System.Text.Encoding.ASCII.GetBytes(filteredSdp));
    www.downloadHandler = new DownloadHandlerBuffer();
    www.method = UnityWebRequest.kHttpVerbPOST;
    www.SetRequestHeader("Content-Type", "application/sdp");
    www.SetRequestHeader("Authorization", "Bearer " + twitchStreamKey);
    yield return www.SendWebRequest();
    if (www.result != UnityWebRequest.Result.Success)
    {
      Debug.Log(JsonUtility.ToJson(www.result, true));
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
```

If we wanted to also include local webcam capture, we can add a `RawImage` to the HUD overlay and use the following script to access the user's camera and set the `texture` of the `RawImage` to a `WebCamTexture`.

```cs
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class WebCamCapture : MonoBehaviour
{
  void Start()
  {
    WebCamDevice[] devices = WebCamTexture.devices;
    WebCamDevice device = devices[0];
    for (int i = 0; i < devices.Length; i++)
    {
      Debug.Log("Webcam available: " + devices[i].name);
      // can also populate a dropdown for available cameras
      if (devices[i].name.ToLower().Contains("facetime"))
      {
        device = devices[i];
      }
    }
    WebCamTexture webcamTexture = new WebCamTexture(device.name);
    RawImage rawImage = GetComponent<RawImage>();
    rawImage.texture = webcamTexture;
    webcamTexture.Play();
  }

  void Update()
  {

  }
}

```

## Testing It Out

At this point, we can play the game and see that it's broadcasted to Twitch as soon as we click the 'Broadcast to Twitch' button. Note that this broadcast is **not** in real-time, but has about 2 seconds of latency. Note: I've edited out a small section of a few seconds while the Twitch player resolves the best resolution to use on the player side.

{{< youtube OVDa0ih0DT0 >}}

## Summary

We've come to the end of this series where we've taken a look at various approaches to integrating live streaming directly into Unity projects. I'd love to hear your ideas on how you'll be integrating any of the approaches that we've looked at in this post. Feel free to reach out on [LinkedIn](https://www.linkedin.com/in/toddrsharp/) or [Twitter](https://twitter.com/recursivecodes) and let me know what you're working on!

For reference, the full script for this post can be accessed [here](https://gist.github.com/recursivecodes/fbb04212aca22910bb4a95622f7da91b).
