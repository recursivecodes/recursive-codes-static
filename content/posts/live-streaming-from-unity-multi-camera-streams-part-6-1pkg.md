---
title: "Live Streaming from Unity - Multi-Camera Streams (Part 6)"
slug: "live-streaming-from-unity-multi-camera-streams-part-6-1pkg"
author: "Todd Sharp"
date: 2024-02-26T07:13:11Z
summary: "So far in this series, we've looked at broadcasting from a game built in Unity to an Amazon..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-multi-camera-streams-part-6-1pkg"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-p8jghhuya7p7yka3as8v.png"
imagecontain: true
---

So far in this series, we've looked at broadcasting from a game built in Unity to an Amazon Interactive Video Service (Amazon IVS) real-time stage, integrated chat, and enhanced the experience with viewer-controlled cameras, and dynamic objectives and environments. In this post, we'll talk about another possible use-case: multi-camera streams.

In addition to viewer-controlled camera views, wouldn't it be super cool to see the action from multiple POVs as a stream viewer? Building on the same concepts that we've established in this series, this is totally possible.

## Create a Reusable Class

Because we have some functionality that will be shared across several scripts, we'll encapsulate some of the logic that we've been using in this series into a reusable `WebRTCUtils` class. This will allow us to establish multiple streams from our game.

```cs
namespace WebRTCUtil
{
  using UnityEngine;
  using System.Threading.Tasks;
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

  [System.Serializable]
  public class ChatTokenRequest
  {
    public string chatArn;
    public string username;
    public string userId;
    public ChatTokenRequest(string chatArn, string username, string userId)
    {
      this.chatArn = chatArn;
      this.username = username;
      this.userId = userId;
    }
  }

  public class WebRTCUtils
  {
    public async Task<StageToken> GetStageToken(string username)
    {
      using UnityWebRequest www = new UnityWebRequest("http://localhost:3000/token");
      StageTokenRequest tokenRequest = new StageTokenRequest(
        "[YOUR STAGE ARN]",
        System.Guid.NewGuid().ToString(),
        1440,
        new string[] { "PUBLISH", "SUBSCRIBE" },
        new StageTokenRequestAttributes(username)
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
        return stageToken;
      }
    }

  }
}
```

## Player Stream

We'll use the 'FPS' demo game for this demo, and create a player camera to broadcast the player's POV just as we did before.

![Player cam](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-su08p875vlkybemu1fo2.png)

Next, create and associate a `WebRTCPlayerPublish` script.

```cs
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using Unity.WebRTC;
using UnityEngine.Networking;
using WebRTCUtil;

[RequireComponent(typeof(AudioListener))]
public class WebRTCPlayerPublish : MonoBehaviour
{
  WebRTCUtils util = new WebRTCUtils();
  RTCPeerConnection peerConnection;
  MediaStreamTrack videoTrack;
  public AudioStreamTrack audioTrack;
  Camera cam;
  ParticipantToken participantToken;
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
    Task<StageToken> stageTokenRequest = util.GetStageToken("ivs-rtx-broadcast-multicam-player");
    yield return new WaitUntil(() => stageTokenRequest.IsCompleted);
    StageToken stageToken = stageTokenRequest.Result;
    participantToken = stageToken.participantToken;
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
    peerConnection.Dispose();
    if (videoTrack != null) videoTrack.Dispose();
    if (audioTrack != null) audioTrack.Dispose();
  }
}
```

## Boss Stream

To add another camera for the main turret's POV, create an empty game object on the turret called `TurretCameraThing`.

![Turret camera thing](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-npy3nvj18n0il8d41u7v.png)

Because we want this camera to always look at whatever the turret is looking at, we'll need to create a `TurretCameraThing` script that is bound to the turret's health bar and update the turret camera's transform in `Update()`.

```cs
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TurretCameraThing : MonoBehaviour
{
  [SerializeField]
  private Transform turretTransform;

  void Update()
  {
    this.transform.rotation = turretTransform.rotation;
  }
}
```

![Bind health bar to turretTransform](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-q3sofquibbb4xx95ku39.png)

Now we can add a camera as a child of `TurretCameraThing` and attach a new `WebRTCBossPublish` script that will broadcast this camera's view as a separate stream to the same Amazon IVS stage.

```cs
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using Unity.WebRTC;
using UnityEngine.Networking;
using WebRTCUtil;

[RequireComponent(typeof(AudioListener))]
public class WebRTCBossPublish : MonoBehaviour
{
  WebRTCUtils util = new WebRTCUtils();
  RTCPeerConnection peerConnection;
  MediaStreamTrack videoTrack;
  public AudioStreamTrack audioTrack;
  Camera cam;
  ParticipantToken participantToken;
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
    Task<StageToken> stageTokenRequest = util.GetStageToken("ivs-rtx-broadcast-multicam-boss");
    yield return new WaitUntil(() => stageTokenRequest.IsCompleted);
    StageToken stageToken = stageTokenRequest.Result;
    participantToken = stageToken.participantToken;
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
    peerConnection.Dispose();
    if (videoTrack != null) videoTrack.Dispose();
    if (audioTrack != null) audioTrack.Dispose();
  }
}
```

## Testing Multi-Cam Streams

Once we launch the game, we can see that both cameras are broadcasting their own view to the Amazon IVS stage!

{{< youtube lDfu6B-Rndc >}}

## Summary

In this post, we learned how to broadcast multiple cameras from a game built in Unity to an Amazon IVS real-time stage. In the next post, we'll switch gears and look at real-time stream playback in a Unity game.
