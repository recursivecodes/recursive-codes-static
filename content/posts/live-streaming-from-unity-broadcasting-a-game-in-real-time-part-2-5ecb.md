---
title: "Live Streaming from Unity - Broadcasting a Game in Real-Time (Part 2)"
slug: "live-streaming-from-unity-broadcasting-a-game-in-real-time-part-2-5ecb"
author: "Todd Sharp"
date: 2024-02-12T15:32:31Z
summary: "In this post, we'll see how to broadcast a game created in Unity directly to a real-time live stream..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-broadcasting-a-game-in-real-time-part-2-5ecb"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-22rurhkxfyi48yvji941.png"
imagecontain: true
---

In this post, we'll see how to broadcast a game created in Unity directly to a real-time live stream powered by Amazon Interactive Video Service (Amazon IVS). This post will be a little longer than the rest in this series, since we'll cover some topics that will be reused in future posts like creating an Amazon IVS stage, and generating the tokens necessary to broadcast to that stage.

## Getting Started

For this post, we're going to utilize the 'Karting Microgame' that is available as a learning template in Unity Hub.

From Unity Hub, click on 'New project'.

![New project](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ivab63ghinefymhqgd9t.png)

Click on 'Learning' in the left sidebar, choose 'Karting Microgame', name your project `ivs-rtx-broadcast-demo` and click 'Create project'

![Create project](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-s7qr3gzcflhbiq1ik51d.png)

## Adding WebRTC Support

Broadcasting to (and playback from) an Amazon IVS stage utilizes WebRTC. Luckily, there's an excellent [Unity WebRTC package](https://docs.unity3d.com/Packages/com.unity.webrtc@3.0/manual/index.html) that we can use for this and since Amazon IVS [now supports the WHIP protocol](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html), we can take advantage of that support to broadcast directly from our game.

To install the WebRTC package for our Karting demo, go to Window -> Package Manager.

![Unity Package Manager](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jqzwvwpjja5ek5xrgce9.png)

Within the Package Manager dialog, select 'Add package from git URL'.

![Add package from git URL](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-kz4hec3uonc72w19os5a.png)

Enter `com.unity.webrtc@3.0.0-pre.7` as the Git URL, and click 'Add'.

![Add the Git URL](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jnb4lgjmny5xuomx1vv4.png)

> ⚠️ This demo has been tested and is known to work with the package version listed above. This may not be the latest version by the time you read this post.

Once installed, you should see the WebRTC package details in the Package Manager dialog.

![WebRTC package details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bk9z3p7xxeazjrp1etcq.png)

Before we add a camera and the script required to publish gameplay, we'll need to create an Amazon IVS stage and establish a way to generate the required participant tokens necessary to publish to the stage.

## Create Stage

An Amazon IVS stage is allows up to 12 broadcasters to publish a real-time live stream to up to 10,000 viewers. We'll re-use this stage for all of our demos, so we'll just manually create one via the AWS management console. When you decide to integrate this feature for all players, you'll create the stage programmatically via the AWS SDK and retrieve the ARN (Amazon Resource Name) for the current player from a backend service. Since we're just learning how things work, there is no harm in creating it manually and hardcoding the ARN into our demo game.

From the AWS Management Console, search for 'Amazon Interactive Video Service'. Once you're on the Amazon IVS console landing page, select 'Amazon IVS Stage' and click 'Get Started'.

![Get started](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5xz9yjlq1bpysos8ume0.png)

Enter a stage name, and click 'Create stage'.

![Create stage details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rm3r7jgkkvntyflgpmgi.png)

That's it, our stage is ready to go! On the stage details page, grab the stage's ARN.

![Stage details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-t0odqqmmlvpqfds1fka3.png)

We'll need this token to generate our tokens.

## Participant Tokens

Each participant in an Amazon IVS stage - including broadcasters and viewers - need a participant token to connect. This is a JWT that is used to authorize the user and contains information such as the `userid`, and any capabilities that have been granted to the participant (such as `PUBLISH` and `SUBSCRIBE`). It would be time consuming to manually create these tokens and paste them into our Unity code repeatedly, so it's better to create a standalone service that uses the AWS SDK to generate these tokens. Since I create a lot of demos like this, I've deployed an AWS Lambda to handle token generation. If you're not quite ready to do that, create a service locally that uses the AWS SDK for [Your Favorite Language] and utilize `CreateParticipantToken` ([docs](https://docs.aws.amazon.com/ivs/latest/RealTimeAPIReference/API_CreateParticipantToken.html)). I prefer JavaScript, so my function uses the AWS SDK for JavaScript (v3) and issues a `CreateParticipantTokenCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/ivs-realtime/command/CreateParticipantTokenCommand/)).

The most basic, bare bones way to do this would be to create a directory, and install the following dependencies:

```bash
npm i @aws-sdk/client-ivs-realtime@latest @aws-sdk/credential-providers
```

Then, create a file called `index.js`. In this file, we'll run a super basic web server with Node.js that responds to one route: `/token`. This path will generate the token and return it as JSON. Note, you'll have to enter your stage ARN in place of `[YOUR STAGE ARN]`.

```js
import * as http from "http";
import * as url from "url";
import { fromIni } from "@aws-sdk/credential-providers";
import { CreateParticipantTokenCommand, IVSRealTimeClient } from "@aws-sdk/client-ivs-realtime";

const ivsRealtimeClient = new IVSRealTimeClient({ credentials: fromIni({ profile: "recursivecodes" }) });

export const createStageToken = async (stageArn, attributes, capabilities, userId, duration) => {
  const createStageTokenRequest = new CreateParticipantTokenCommand({
    attributes,
    capabilities,
    userId,
    stageArn,
    duration,
  });
  const createStageTokenResponse = await ivsRealtimeClient.send(createStageTokenRequest);
  return createStageTokenResponse;
};

async function handler(req, res) {
  const parsedUrl = url.parse(req.url, true);
  if (parsedUrl.pathname === "/token") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk.toString();
    });
    req.on("end", async () => {
      const params = JSON.parse(body);
      res.writeHead(200, { "Content-type": "application/json" });
      const tokenResponse = await createStageToken(params.stageArn, params.attributes, params.capabilities, params.userId, params.duration);
      res.write(JSON.stringify(tokenResponse));
      res.end();
    });
  } else {
    res.writeHead(404, { "Content-type": "text/plain" });
    res.write("404 Not Found");
    res.end();
  }
}

const server = http.createServer(handler);
server.listen(3000);
```

Run it with `node index.js`, and hit `http://localhost:3000/token` to generate a token. We'll use this endpoint in Unity any time we need a token. Here's an example of how this should look:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"stageArn": "[YOUR STAGE ARN]", "userId": "123456", "capabilities": ["PUBLISH", "SUBSCRIBE"], "attributes": {"username": "todd"}}' \
  http://localhost:3000/token | jq
```

Which produces:

```json
{
  "$metadata": {
    "httpStatusCode": 200,
    "requestId": "...",
    "cfId": "...",
    "attempts": 1,
    "totalRetryDelay": 0
  },
  "participantToken": {
    "attributes": {
      "username": "todd"
    },
    "capabilities": ["PUBLISH", "SUBSCRIBE"],
    "duration": 1200,
    "expirationTime": "2024-01-19T15:11:32.000Z",
    "participantId": "bWO1wUhGopye",
    "token": "eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ....[truncated]",
    "userId": "1705605092467"
  }
}
```

## Adding a Camera

Now that we've got a stage and a way to generate tokens, we can add a new camera that we'll use to broadcast the gameplay to the stage. Expand the 'Main Scene' in Unity and find the `CinemachineVirtualCamera`. This camera is used in the Karting Microgame project to follow the player's kart around the track as they drive through the course. Right click on the `CinemachineVirtualCamera` and add a child `Camera`. I named mine `WebRTCPublishCamera`.

![Add camera](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6a7obnedx0vqft7ue2o4.png)

Next, select the newly created camera and scroll to the bottom of the 'Inspector' tab. Deselect the 'Audio Listener' otherwise you'll get errors in the console about having multiple audio listeners in a scene. After you deselect that, click 'Add Component'.

![Camera inspector](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-52qij16nhve5y71uumvs.png)

In the 'Add Component' menu, choose 'New Script' and name the script `WebRTCPublish`. Click 'Create and Add'.

![Add camera script](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bp3xzu3aaaal0nd0tjro.png)

Once the script is added, double click on it to open it up in VS Code (or your configured editor).

![Edit script](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-d25rh4iprb7a9vsgpvoj.png)

We can now edit the script that will be used to broadcast this camera to the stage.

## Broadcasting the Camera to an Amazon IVS Stage

At this point we can modify the `WebRTCPublish.cs` script to include the necessary logic to get a stage token and establish the WebRTC connection to publish the camera to our stage.

We'll create a few classes that will help us handle the request and response from our token generation service. We could use separate files for these, but for now, I just define them within the same file to keep things all in one place.

```cs
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
```

Next we need to annotate the class to require an `AudioListener` so that we can publish the game audio. We'll also declare some variables that will be used in the script.

```cs
[RequireComponent(typeof(AudioListener))]
public class WebRTCPublish : MonoBehaviour
{
  RTCPeerConnection peerConnection;
  MediaStreamTrack videoTrack;
  AudioStreamTrack audioTrack;
  Camera cam;
  ParticipantToken participantToken;
}
```

Now let's create an async function that will hit our token generation service and request the token. We'll define this inside the `WebRTCPublish` class.

```cs
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
```

Within the `Start()` method, we'l start the `WebRTC.Update()` coroutine, establish a new `RTCPeerConnection`, get the camera and add its output to the `peerConnection`, and add the game audio as well. Then we'll start a coroutine called `DoWhip()` that we'll define in just a bit.

```cs
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
```

Let's define `DoWhip()` which will get a token, create a local SDP, and pass that along to retrieve a remote SDP (finally setting that on the `peerConnection` to complete the WebRTC connection process). Note that we're using the Amazon IVS global WHIP endpoint of `https://global.whip.live-video.net/` to retrieve the SDP, passing our token as the `Bearer` value in the `Authorization` header.

```cs
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
```

At this point, we're ready to launch the game and observe the console in Unity to see our tokens and make sure the connection is established. Launch the game via the 'play' button in Unity and check the console.

![Unity console](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7clnema487nibglxps1n.png)

This output looks promising! We've generated a token and the Peer Connection is `Connected`. Let's see if our gameplay is being streamed to the stage.

## Testing Playback

To test playback, we could use the [Amazon IVS Web Broadcast SDK](https://aws.github.io/amazon-ivs-web-broadcast/docs/real-time-sdk-guides/introduction) to connect to the stage and render the participants when they connect. We'll leave that as an offline exercise and test things out from [this CodePen](https://codepen.io/amazon-ivs/project/editor/ZzWobn). Generate another token, copy it to your clipboard, and paste it into the CodePen and click 'Join Stage' while the game is running and broadcasting to the stage. If everything went well, you should be able to see your real-time stream!

{{< youtube W9IDb_4xRCk >}}

> 🔊 **Note:** You'll notice duplicate audio in the video above - that's because both the local game audio and the stream audio were captured.

## Clean Up

In `Destroy()`, we can close and dispose of our `peerConnection` and clean up our audio and video tracks.

```cs
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
```

## How Can We Improve This?

As it stands, I'd say this is pretty impressive! Beyond some of the things I mentioned in the previous post in this series, there is one area of improvement that we'll address in the next post in this series. You may have already noticed it in the video above. If you missed it, check the real-time playback in the video above and you'll notice that there is something missing from the stream - the HUD elements like the match timer and overlays such as the instructions are not displayed. This has to do with the fact that canvas elements in Unity are usually configured to use 'Screen Space - Overlay' which means they render on top of everything that the camera renders to the game screen. This isn't necessarily a bad thing, as you might not need every HUD and UI element to be rendered to the live stream (especially in the case of screens that may show user specific data). This can be handled on a case-by-case basis in your game, but if you absolutely have the need to render the full UI, we'll look at one approach that solves this issue in our next post in this series.

Another improvement here could certainly be the addition of a UI button that can be used to start/stop the stream instead of launching it automatically when the game begins.

## Summary

In this (rather long) post, we learned how to broadcast from a game built with Unity directly to an Amazon IVS real-time stage. We covered some intro topics like creating the stage and generating tokens that we won't repeat in the coming posts in this series, so be sure to refer back to this post if you need a refresher.

If you'd like to see the entire script that I use for this demo, check out [this Gist](https://gist.github.com/recursivecodes/e948b81e53bf9259b981c88e9fc216fa) on GitHub. Note that my production token endpoint uses the `POST` method and allows me to send in the stage ARN, user ID, etc so this script contains some additional classes to model that post request. You'll probably need to modify this to work with your own endpoint, but this script should get you started.
