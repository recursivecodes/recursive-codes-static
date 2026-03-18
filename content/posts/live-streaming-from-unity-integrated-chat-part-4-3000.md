---
title: "Live Streaming from Unity - Integrated Chat (Part 4)"
slug: "live-streaming-from-unity-integrated-chat-part-4-3000"
author: "Todd Sharp"
date: 2024-02-21T15:07:41Z
summary: "So far in this series, we've focused on how to broadcast from a game created in Unity to an Amazon..."
tags: ["aws", "amazonivs", "gamedev", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-integrated-chat-part-4-3000"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6ndelpumg8qccbfp8eth.png"
imagecontain: true
---

So far in this series, we've focused on how to broadcast from a game created in Unity to an Amazon Interactive Video Service (Amazon IVS) real-time stage. In this post, we'll focus on integrating Amazon IVS chat directly into our game. With integrated chat, a player/streamer can view and respond directly to their stream viewers without having to leave the game at all. This brings a new level of interactivity to gameplay, and lays the foundation for enhancing both the player's experience (via dynamic environment changes based on viewer polls, comments and feedback) and the viewer's experience (by potentially letting the viewer modify what they're seeing without affecting gameplay). This is **game changing** stuff (pun intended).

## Creating an Amazon IVS Chat Room

We'll need an Amazon IVS chat room, so head to the Amazon IVS console, select 'Amazon IVS Chat Room' and click 'Get Started'.

![Create chat room](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7c7affekcl7masrk2aj2.png)

Give the chat room a name and accept the default configuration.

![Create chat room form](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ezqncu949usmmk92lqmv.png)

We won't get into moderation and logging in this post, but it's good to point out that it is possible to create an AWS Lambda chat handler for moderation. You can also set up chat logging if you have a need to persist, analyze, or replay chat later on.

![Chat options](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5ik9d7lz7ajp41hpvn3d.png)

Click 'Create room' and copy the chat room's ARN as we'll need this to generate chat tokens later on. Also make a note of the 'Messaging Endpoint'.

![Chat room details](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-p3mcdjktra0bhh7jgsvr.png)

### Create Chat Token Endpoint

We'll need an endpoint to generate chat tokens for users. For this, we can modify the super basic endpoint that we created in part 2 of this series to create a route for `/chat-token` which will utilize the `@aws-sdk/client-ivschat` module to get the tokens.

If you're using that service we created in part 2, add the module:

```bash
npm i @aws-sdk/client-ivschat
```

Add a function to use the SDK to generate the token:

```js
import { CreateChatTokenCommand, IvschatClient } from "@aws-sdk/client-ivschat";

const ivsChatClient = new IvschatClient();

const createChatToken = async (chatArn, userId, username) => {
  const chatTokenInput = {
    roomIdentifier: chatArn,
    userId: userId,
    attributes: { username },
    capabilities: ["SEND_MESSAGE"],
    sessionDurationInMinutes: 180,
  };
  const createChatTokenRequest = new CreateChatTokenCommand(chatTokenInput);
  return await ivsChatClient.send(createChatTokenRequest);
};
```

And add a listener for that endpoint:

```js
else if (parsedUrl.pathname === '/chat-token') {
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });
  req.on('end', async () => {
    const params = JSON.parse(body);
    res.writeHead(200, { 'Content-type': 'application/json' });
    const tokenResponse = await createChatToken(
      params.chatArn,
      params.username,
      params.userId,
    );
    res.write(JSON.stringify(tokenResponse));
    res.end();
  });
}
```

Of course, an AWS Lambda or a proper backend service would be more likely in production. For testing, [this script](https://gist.github.com/recursivecodes/8b7ad5fff4e9acf96692b67356dbd2c2) works just fine and means that we don't have to manually generate the tokens and paste them into our Unity script every time we want to test it.

To test out this new endpoint:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"chatArn": "[YOUR CHAT ARN]", "username": "todd", "userId": "123"}' \
  http://localhost:3000/chat-token | jq
```

Which should return a response with the chat token.

```json
{
  "$metadata": {
    "httpStatusCode": 200,
    "requestId": "...",
    "cfId": "...",
    "attempts": 1,
    "totalRetryDelay": 0
  },
  "sessionExpirationTime": "2024-01-19T18:22:35.000Z",
  "token": "AQICAHgm5DC1V25pBVEhXdu--...",
  "tokenExpirationTime": "2024-01-19T16:22:35.000Z"
}
```

## Create a New Game

To demonstrate chat integration, let's create a new game. From Unity Hub, click on 'New Project'.

![New project in Unity Hub](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zjw662l1cp9jiadbh72n.png)

We're going to use the 'FPS Microgame' this time.

![Create project dialog](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-nfp5yvwyqnixhjqvmb2n.png)

### Add NativeWebSocket Package

We'll need WebSocket support, and once again there's a Unity package that we can use to help us out. Go to Window -> Package Manager to bring up the dialog and 'Add from git URL' using the `NativeWebSocket` ([repo](https://github.com/endel/NativeWebSocket)) GitHub URL `https://github.com/endel/NativeWebSocket.git#upm`.

![Add NativeWebSocket package](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zo26sol8qeddarmeqozb.png)

## Add Chat UI

Where you decide to render your chat is completely up to you and what makes sense for your game. I decided to place a scrollable text component in the HUD, so I settled on this set of components.

![Chat content components](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-hnp86y05sjni4mf480kd.png)

We'll need to add a script that will handle establishing the chat connection and responding to incoming messages.

## Add Chat Script

Create a new script called `IVSChat` in your project.

![Add chat script](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-t6krwb56k6klzrbt8prg.gif)

Open up the new `IVSChat` script in your editor. Add some imports to the top of the script.

```cs
using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Networking;
using NativeWebSocket;
using TMPro;
```

Next, we'll create some classes to model our token requests and responses. Again, you could externalize these if necessary.

```cs
[System.Serializable]
public class ChatAttributes
{
  public string username;
  public static ChatAttributes CreateFromJSON(string jsonString)
  {
    return JsonUtility.FromJson<ChatAttributes>(jsonString);
  }
}

[System.Serializable]
public class ChatSender
{
  public string UserId;
  public ChatAttributes Attributes;
  public static ChatSender CreateFromJSON(string jsonString)
  {
    return JsonUtility.FromJson<ChatSender>(jsonString);
  }
}

[System.Serializable]
public class ChatMessage
{
  public string Type;
  public string Id;
  public string RequestId;
  public string Content;
  public ChatSender Sender;
  public static ChatMessage CreateFromJSON(string jsonString)
  {
    return JsonUtility.FromJson<ChatMessage>(jsonString);
  }
}

[System.Serializable]
public class ChatToken
{
  public System.DateTime sessionExpirationTime;
  public string token;
  public System.DateTime tokenExpirationTime;
  public static ChatToken CreateFromJSON(string jsonString)
  {
    return JsonUtility.FromJson<ChatToken>(jsonString);
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
```

Declare a few variables for our `IVSChat` class.

```cs
public class IVSChat : MonoBehaviour
{
  TMP_Text chatContainer;
  ScrollRect scrollRect;
  WebSocket websocket;
}
```

Next, add a `GetChatToken()` to make a request to our chat token service and retrieve a token. Make sure to pass your chat ARN that we collected above.

```cs
async Task<ChatToken> GetChatToken()
{
  using UnityWebRequest www = new UnityWebRequest("http://localhost:3000/chat-token");
  ChatTokenRequest tokenRequest = new ChatTokenRequest(
    "[YOUR CHAT ARN]",
    "IVS HUD Chat Demo User",
    System.Guid.NewGuid().ToString()
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
  if (www.result != UnityWebRequest.Result.Success)
  {
    Debug.Log(www.error);
    return default;
  }
  else
  {
    return ChatToken.CreateFromJSON(www.downloadHandler.text);
  }
}
```

Now a `ConnectChat()` function that will handle establishing the WebSocket, and set up some connection listeners that will handle parsing and rendering the incoming chat messages. Update `[YOUR CHAT ENDPOINT]` with the value we saved above.

```cs
async Task<WebSocket> ConnectChat()
{
  var chatToken = await GetChatToken();
  websocket = new WebSocket("[YOUR CHAT ENDPOINT]", chatToken.token);
  websocket.OnOpen += () =>
  {
    Debug.Log("Chat Connection: Open");
  };
  websocket.OnError += (e) =>
  {
    Debug.Log("Chat Connection: Error " + e);
  };
  websocket.OnClose += (e) =>
  {
    Debug.Log("Chat Connection: Closed");
  };
  websocket.OnMessage += (bytes) =>
  {
    var msgString = System.Text.Encoding.UTF8.GetString(bytes);
    Debug.Log("Chat Message Received! " + msgString);
    ChatMessage chatMsg = ChatMessage.CreateFromJSON(msgString);
    Debug.Log(chatMsg);
    if (chatMsg.Type == "MESSAGE")
    {
      chatContainer.text += "<b>" + chatMsg.Sender.Attributes?.username + "</b>: " + chatMsg.Content + "\n";
      scrollRect.verticalNormalizedPosition = 0;
    }
  };
  return websocket;
}
```

The only thing left to do is update the `Start()` method to call the `ConnectChat()` function and the `Update()` method to dispatch the message queue. Also, some clean-up is added to `Destroy()`.

```cs
async void Start()
{
  chatContainer = GetComponent<TMP_Text>();
  scrollRect = chatContainer.transform.parent.parent.parent.GetComponent<ScrollRect>();
  await ConnectChat();
  await websocket.Connect();
}

void Update()
{
#if !UNITY_WEBGL || UNITY_EDITOR
  websocket?.DispatchMessageQueue();
#endif
}

async void OnDestroy()
{
  Debug.Log("OnDestroy");
  if (websocket != null) await websocket.Close();
}
```

Note that we're not adding functionality to reply, but the `NativeWebSocket` has full support if you want to add that.

```cs
async void SendWebSocketMessage()
{
  if (websocket.State == WebSocketState.Open)
  {
    // Sending bytes
    await websocket.Send(new byte[] { 10, 20, 30 });

    // Sending plain text
    await websocket.SendText("plain text message");
  }
}
```

## Testing Chat

At this point, we can play our game and connect up to the chat room to test things out. You can build your own testing page ([read more](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6)) or use this [CodePen](https://codepen.io/recursivecodes/pen/MWVVZvR) with a token and your chat endpoint.

{{< youtube febCZdqMSwI >}}

## Summary

In this post, we learned how to connect to an Amazon IVS chat room and handle incoming messages in our game created with Unity. As mentioned before, this feature will enable further dynamic interactions. In the next post, we'll look at using this feature to create a dynamic camera view that viewers can control by sending chat messages to the chat room.
Here is the [full script](https://gist.github.com/recursivecodes/15cee808a55970ba5bedb247d3de72c1) for this post if you need to refer to it.
