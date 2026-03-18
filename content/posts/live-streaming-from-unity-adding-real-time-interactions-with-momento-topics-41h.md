---
title: "Live Streaming from Unity - Adding Real-Time Interactions with Momento Topics"
slug: "live-streaming-from-unity-adding-real-time-interactions-with-momento-topics-41h"
author: "Todd Sharp"
date: 2024-08-19T15:08:24Z
summary: "In a previous series, we looked at creating interactive real-time live streaming experiences with..."
tags: ["aws", "amazonivs", "momento", "unity3d"]
canonical_url: "https://dev.to/aws/live-streaming-from-unity-adding-real-time-interactions-with-momento-topics-41h"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-p36vv5xrpm1de7ut8o9p.png"
imagecontain: true
---

In a previous [series](https://dev.to/recursivecodes/series/26107), we looked at creating interactive real-time live streaming experiences with Amazon Interactive Video Service (Amazon IVS) and Unity. If you recall from part 5 of that series, we looked at how to [create dynamic experiences by modifying the game's objectives and environment](https://dev.to/aws/live-streaming-from-unity-dynamic-interactive-streams-part-5-41lj). In that post, we used Amazon IVS chat to establish a WebSocket connection and pass the commands from the viewer to the game. This works great, and since you're probably already using chat it is an easy integration. But there are times when you'd like to take advantage of third-party solutions for things like this. In this post, we'll take a look at using [Momento Topics](https://www.gomomento.com/platform/topics/) to post messages from the viewer to the game for low-latency, highly scalable messaging.

> 👀 **How Performant?** Read about how Momento Topics built a chat system capable of [handling 3.75 million subscribers](https://www.gomomento.com/blog/i-built-a-3-75-million-subscriber-chat-system-in-an-afternoon/)!

## What We're Building

Before we look at the code involved in this solution, here's a quick video demonstration of what we're building. In this video, the game play is shown on the right hand of the screen and the live stream playback is shown on the left. Notice that the stream viewers can interact in real-time and spawn various obstacles directly within the game by clicking on the buttons that are shown on the screen. The player must avoid the obstacles or use them to their advantage to reach otherwise unreachable areas within the course.

{{< youtube -6Uc5eXRGAA >}}

Now that we've seen the final result, let's talk about how to create this experience with Amazon IVS and Momento Topics.

## Overview

As before, the gameplay is broadcast directly from Unity to the Amazon IVS real-time stage. Up to 25,000 concurrent viewers can view the stream and interact with the player by spawning new obstacles, modifying the game environment and objectives. The only difference here is that we're introducing Momento Topics to handle the messaging between the browser and Unity.

![Overview](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dqmq4rrx7oo6oye3jsd6.png)

## Publishing Messages

Instead of publishing the command/control messages from the browser with Amazon IVS chat, we'll use a Momento Topic to handle this. Check out the '[Getting Started](https://docs.momentohq.com/sdks/nodejs/topics)' if you need a quick intro, but we'll cover the messaging publishing process in just a second. First, sign up for a free account (with a **generous 5 million operations free** each month).

Next, head over to the Momento Console and create a [Momento Cache](https://docs.momentohq.com/cache). I called mine 'demo-cache'.

![Create Cache](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-h4vx8zjyomzcm575kwfb.png)

Now we can install Momento with:

```bash
npm install @gomomento/sdk-web
```

And import the following classes.

```js
import { TopicClient, TopicConfigurations, CredentialProvider } from "@gomomento/sdk-web";
```

Or, if you're not bundling assets you can import the SDK directly:

```js
import { TopicClient, TopicConfigurations, CredentialProvider } from "https://esm.run/@gomomento/sdk-web@1.93.0";
```

To create the `TopicClient`, we'll need an API key. We could manually create one, but it's a better to create a Token Vending Machine for short-lived tokens. You can check out [this repo](https://github.com/momentohq/client-sdk-javascript/tree/main/examples/nodejs/token-vending-machine) for a simple example of a Token Vending Machine deployed as an AWS Lambda function.

If you decide to use the example Token Vending Machine, you must either name your cache `default-cache` or change the file located at `lambda/token-vending-machine/config.ts` to modify the `tokenPermissions` to use `AllCaches` like so:

```ts
export const tokenPermissions: DisposableTokenScope = {
  permissions: [
    {
      role: CacheRole.ReadWrite,
      cache: AllCaches,
    },
    {
      role: TopicRole.PublishSubscribe,
      cache: AllCaches,
      topic: AllTopics,
    },
  ],
};
```

Once the Token Vending Machine is deployed, we can invoke the function to get a fresh token on every request which we'll use to create a new `TopicClient`.

```js
const tokenReq = await fetch("https://[redacted].execute-api.us-east-1.amazonaws.com/prod/", { headers: { "content-type": "application/json" } });
const tokenResponse = await tokenReq.json();
const token = tokenResponse.authToken;

this.momentoTopicClient = new TopicClient({
  configuration: TopicConfigurations.Default.latest(),
  credentialProvider: CredentialProvider.fromString({ apiKey: token }),
});
```

With the client created, we can now call `publish()` to send messages!

```js
async publishCommand(command) {
  await this.momentoTopicClient.publish(
    this.momentoCacheName,
    this.momentoTopicName,
    JSON.stringify({ commandType: 'environment', command })
  );
},
```

For our Unity game, the specific command will be passed in the body of the message that we publish. On the front-end, a `<button>` is used to send various commands.

```html
<button x-on:click="publishCommand('jump')">Jump</button>
<button x-on:click="publishCommand('wall')">Wall</button>
<button x-on:click="publishCommand('stone')">Stone</button>
<button x-on:click="publishCommand('alt-track')">Alt Track</button>
<button x-on:click="publishCommand('default-track')">Default Track</button>
```

## Subscribing to the Topic

Now that the front-end is happily publishing topics, it's time to subscribe to the topic and make sure the messages are being published. To quickly test, we can open up the Momento Console and subscribe to the topic.

![Momento topic console sub](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-88vqghtovuph0xi792j0.png)

Click 'Subscribe' and publish a few messages to confirm everything is working.

![Incoming messages!](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-77mcp2lzcrihr7zk24lm.png)

Now that we've confirmed the subscription works, let's head over to Unity and set up a subscription so that we can modify the environment when a new message is received.

We'll use a class called `ViewerInteractionManager` to subscribe to the Momento Topic and handle the incoming messages. In this class, we'll set up some variables to track our client, subscription and assign our cache, client, and topic names.

```cs
private const string TopicName = "ivs-rtx-unity-topic";
private const string cacheName = "demo-cache";
private string clientName = "ivs-rtx-unity-client";
private CancellationTokenSource cts = null;
private ITopicClient topicClient = null;
private StringMomentoTokenProvider authProvider = null;
private TopicSubscribeResponse.Subscription subscription = null;
```

We'll also set up a few variables to hold our `GameObject`'s that will be used to spawn new obstacles and modify the environment. Additionally, we will set a variable for the URL of our Token Vending Machine endpoint that we deployed as an AWS Lambda.

```cs
[SerializeField] private GameObject jump;
[SerializeField] private GameObject wall;
[SerializeField] private GameObject stone;
[SerializeField] private GameObject kart;
[SerializeField] private GameObject defaultTrackEntrance;
[SerializeField] private GameObject altTrackEntrance;
[SerializeField] private GameObject defaultTrackExit;
[SerializeField] private GameObject altTrackExit;

public string tokenVendingMachineURL = "https://[redacted].execute-api.us-east-1.amazonaws.com/prod?name=";
```

In the `Start()` method, we'll get a new token.

```cs
void Start()
{
  StartCoroutine(GetTokenFromVendingMachine(clientName));
}
```

The `GetTokenFromVendingMachine()` function will make a request to the serverless function and retrieve a token. Once the token is retrieved and set, we'll call the `Main()` function.

```cs
private IEnumerator GetTokenFromVendingMachine(string name)
{
  string uri = tokenVendingMachineURL + UnityWebRequest.EscapeURL(name);
  using (UnityWebRequest webRequest = UnityWebRequest.Get(uri))
  {
    webRequest.SetRequestHeader("Cache-Control", "no-cache");
    yield return webRequest.SendWebRequest();

    if (webRequest.result == UnityWebRequest.Result.Success)
    {
      TokenVendingMachineResponse response =
        JsonUtility
          .FromJson<TokenVendingMachineResponse>(webRequest.downloadHandler.text);
      DateTimeOffset dateTimeOffset =
        DateTimeOffset
          .FromUnixTimeSeconds((long)response.expiresAt);
      try
      {
        authProvider = new StringMomentoTokenProvider(response.authToken);
      }
      catch (InvalidArgumentException e)
      {
        Debug.LogError("Invalid auth token provided! " + e);
      }
      Main(authProvider);
    }
    else
    {
      Debug.LogError("Error trying to get token from vending machine: " + webRequest.error);
    }
  }
}
```

The `Main()` function sets up a `CacheClient` and the Topic subscription.

```cs
public async void Main(ICredentialProvider authProvider)
{
  try
  {
    using ICacheClient client =
      new CacheClient(
        Configurations.Laptop.V1(),
        authProvider,
        TimeSpan.FromSeconds(60)
      );
    topicClient =
      new TopicClient(
        TopicConfigurations.Laptop.latest(),
        authProvider
      );
    cts = new CancellationTokenSource();
    var subscribeResponse =
      await topicClient.SubscribeAsync(
        cacheName,
        TopicName
      );
    StartCoroutine(
      SubscriptionCoroutine(subscribeResponse)
    );
  }
  catch (Exception e)
  {
    Debug.LogError("Could not set up clients " + e.ToString());
  }
}
```

> ❗️**Note:** We're assuming that a Momento Cache named `demo-cache` exists. If you'd prefer to verify that the cache exists, refer to the `EnsureCacheExistsAsync()` function in the [Momento sample app](https://github.com/momentohq/momento-unity-demo/blob/main/Assets/Scripts/TopicsTestCoroutine.cs). This requires that your token that is returned from your vending machine has the proper permissions to read/create a cache.

The `SubscriptionCoroutine()` handles the response from the topic subscription.

```cs
IEnumerator SubscriptionCoroutine(TopicSubscribeResponse subscribeResponse)
{
  switch (subscribeResponse)
  {
    case TopicSubscribeResponse.Subscription:
      subscription = (TopicSubscribeResponse.Subscription)subscribeResponse;
      Debug.Log("Successfully subscribed to topic " + TopicName);
      try
      {
        var cancellableSubscription =
          subscription.WithCancellation(cts.Token);
        var enumerator =
          cancellableSubscription.GetAsyncEnumerator();
        while (!cts.IsCancellationRequested)
        {
          var message = enumerator.Current;
          switch (message)
          {
            case TopicMessage.Binary:
              Debug.Log("Received unexpected binary message from topic.");
              break;
            case TopicMessage.Text text:
              Debug.Log(String.Format("Received string message from topic: {0}", text.Value));
              GameCommand gameCommand =
                JsonUtility.FromJson<GameCommand>(text.Value);
              HandleCommand(gameCommand);
              break;
            case TopicMessage.Error error:
              Debug.LogError(String.Format("Received error message from topic: {0}", error.Message));
              cts.Cancel();
              break;
          }
          yield return null;
          // wait for the next message
          var awaitable = enumerator.MoveNextAsync().GetAwaiter();
          while (!awaitable.IsCompleted)
          {
            if (cts.IsCancellationRequested)
            {
              break;
            }
            yield return null;
          }
        }
      }
      finally
      {
        Debug.Log("Subscription to the Topic has been cancelled");
      }

      break;
    case TopicSubscribeResponse.Error error:
      Debug.LogError(String.Format("Error subscribing to a topic: {0}", error.Message));
      cts.Cancel();
      break;
  }
  Dispose();
}
```

If the received message is text, we serialize the response as a `GameCommand`.

```cs
public struct GameCommand
{
  public const string ENVIRONMENT = "environment";
  public string command;
  public string commandType;
}
```

And pass the command to `HandleMessage()` which takes the necessary action that is passed from the stream viewer (spawn obstacle, modify the racetrack, etc).

```cs
void HandleCommand(GameCommand incomingCommand)
{
  switch (incomingCommand.commandType)
  {
    case GameCommand.ENVIRONMENT:
      if (incomingCommand.command.ToLower() == "jump")
      {
        Debug.Log(kart, kart);
        Vector3 kartPos = kart.transform.position;
        Vector3 kartDirection = kart.transform.forward;
        Quaternion kartRotation = kart.transform.rotation;
        float spawnDistance = 10;
        Vector3 spawnPos = kartPos + kartDirection * spawnDistance;
        Instantiate(jump, spawnPos, kartRotation);
      }
      if (incomingCommand.command.ToLower() == "stone")
      {
        Rigidbody rb = stone.GetComponent<Rigidbody>();
        rb.velocity = new Vector3(0, 100);
        Vector3 kartPos = kart.transform.position;
        Vector3 kartDirection = kart.transform.forward;
        Quaternion kartRotation = kart.transform.rotation;
        float spawnDistance = 10;
        kartPos[1] = kartPos[1] + 1;
        Vector3 spawnPos = kartPos + kartDirection * spawnDistance;
        Instantiate(stone, spawnPos, kartRotation);
      }
      if (incomingCommand.command.ToLower() == "wall")
      {
        Vector3 kartPos = kart.transform.position;
        kartPos[0] = kartPos[0];
        kartPos[1] = 1;
        Vector3 kartDirection = kart.transform.forward;
        Quaternion kartRotation = kart.transform.rotation;
        float spawnDistance = 10;
        Vector3 spawnPos = kartPos + kartDirection * spawnDistance;
        Instantiate(wall, spawnPos, kartRotation);
      }
      if (incomingCommand.command.ToLower() == "alt-track")
      {
        defaultTrackEntrance.SetActive(false);
        defaultTrackExit.SetActive(false);
        altTrackEntrance.SetActive(true);
        altTrackExit.SetActive(true);
      }
      if (incomingCommand.command.ToLower() == "default-track")
      {
        defaultTrackEntrance.SetActive(true);
        defaultTrackExit.SetActive(true);
        altTrackEntrance.SetActive(false);
        altTrackExit.SetActive(false);
      }
      break;
    default:
      break;
  }
}
```

And that's it! Our live stream viewers can now dynamically interact with the Unity game by publishing messages in real-time on the Momento Topic. And since our Amazon IVS stage is broadcast with less than 300ms of latency, the interactions will impact the game in real-time.

Here's the entire `ViewerInteractionManager` [script](https://gist.github.com/recursivecodes/3ae9fd87753d28afacc5ba58741fae75) as a reference.

## Summary

In this post, we looked at using Momento Topics for highly scalable, extremely low-latency messaging between Amazon IVS real-time stream viewers and a game built in Unity. Do you have a use case for real-time streaming from a Unity game that you'd like to discuss? Check out [https://ivs.rocks](https://ivs.rocks) or drop a comment below and let's chat!
