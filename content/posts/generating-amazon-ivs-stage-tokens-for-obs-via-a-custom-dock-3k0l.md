---
title: "Generating Amazon IVS Stage Tokens for OBS via a Custom Dock"
slug: "generating-amazon-ivs-stage-tokens-for-obs-via-a-custom-dock-3k0l"
author: "Todd Sharp"
date: 2024-07-30T11:24:34Z
summary: "So you've created an amazing live streaming application with Amazon Interactive Video Service (Amazon..."
tags: ["aws", "amazonivs", "obs", "livestreaming"]
canonical_url: "https://dev.to/aws/generating-amazon-ivs-stage-tokens-for-obs-via-a-custom-dock-3k0l"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-w1usxky3pv7we4ooq9lc.png"
imagecontain: true
---

So you've created an amazing live streaming application with Amazon Interactive Video Service (Amazon IVS) real-time stages. Everything works great, and your users love streaming to the app from the comfort of their favorite browser! But some of your users keep asking you if it's possible to stream from OBS since they're comfortable using it for its advanced streaming capabilities like scenes, custom layouts and transitions. The good news is that this is totally possible via custom [WHIP endpoints in OBS](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/obs-whip-support.html). However, there are a few caveats to be aware of. First, each broadcaster will still need a valid [participant token](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/getting-started-distribute-tokens.html). Additionally, there is no built-in support for viewing remote participants in OBS. In this short series, we'll look at some features and various approaches to make this workflow a bit more user friendly. We'll start off by addressing participant tokens.

## Generating Participant Tokens

Each participant in an Amazon IVS stage must have a valid participant token. This token can be [created via the Amazon IVS real-time streaming APIs](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/getting-started-distribute-tokens.html#getting-started-distribute-tokens-api) (and the AWS CLI or AWS Management Console). Here's an example of generating a participant token via the AWS SDK for JavaScript (v3) that could be wrapped in an AWS Lambda function:

```js
import { IVSRealTimeClient, CreateParticipantTokenCommand } from "@aws-sdk/client-ivs-realtime";

const ivsRealtimeClient = new IVSRealTimeClient({ region: "us-west-2" });
const stageArn = "arn:aws:ivs:us-west-2:123456789012:stage/L210UYabcdef";
const createStageTokenRequest = new CreateParticipantTokenCommand({
  stageArn,
});
const response = await ivsRealtimeClient.send(createStageTokenRequest);
console.log("token", response.participantToken.token);
```

> 💡 Tip: If you're looking to shave a few hundred milliseconds from your user's connection time and need to generate more tokens then the service quota allows, consider generating and signing your own participant tokens. See the docs for more [information on self-signed tokens](https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/getting-started-distribute-tokens.html#getting-started-distribute-tokens-self-signed).

## Distributing Participant Tokens

Once you've got a process in place for generating tokens in your application, you'll need to distribute them to your users so that they can configure OBS to broadcast to their real-time stage. This process will depend on your application, but I've found it helpful to create a web page that can be used to authenticate a user and allow them to copy the token. To take this approach a step further, I like to take advantage of Custom Docks in OBS.

First, create a form in your application to give users the ability to login to your service. This form would likely include the user's password, but in my simple example I'm just prompting for username:

![login form](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-njgn5du3yv9jfcq7ko5y.png)

When the 'Get Token' button is clicked, generate the participant token via your normal method as mentioned above. When the token is generated, you can provide the endpoint and token so that the user can copy/paste them into OBS!

![Endpoint and Token](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7w8q8uampz094vty2u9p.png)

> **Note:** If you plan on using this form in a custom OBS dock, be aware that `navigator.clipboard.writeText()` will not work to set the value to the user's clipboard. Instead, you can select the element (`el.select()`) and use `document.execCommand("copy")` since this does not require permissions.

To provide a better user experience, this form can be added as a custom dock in OBS!

![Add dock](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bxv3pgkbyyega04tykun.png)

![Add dock link](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5qxpmrvev2i9ohopyyo4.png)

Now your users can generate new participant tokens directly within OBS!

## Bonus: Automatically Set Tokens in OBS

As an added bonus to greatly improve the user experience, we can utilize the built in WebSocket server in OBS to automatically set the token and endpoint. For this, enable the server via `Tools` -> `WebSocket Server Settings`.

![OBS WebSocket Server Settings](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-0iq5px0cills5685zqja.png)

Once enabled, your application can connect to the WebSocket server:

```js
this.obsConnection = new WebSocket("ws://localhost:4455");
```

In the `onmessage` handler, once we receive a connection message we'll need to identify the client via a one-time message.

```js
this.obsConnection.onmessage = (event) => {
  if (!this.obsIdentified && this.obsConnection) {
    this.obsConnection.send(
      JSON.stringify({
        op: 1,
        d: {
          rpcVersion: 1,
          eventSubscriptions: 1023, // receive ALL events
        },
      }),
    );
    this.obsIdentified = true;
  }
};
```

Now we can add some more logic to the `onmessage` handler function to listen for confirmation of the command that we'll send to set the token and endpoint.

```js
const payload = JSON.parse(event.data);
if (payload.op === 7 && payload?.d?.requestType === "SetStreamServiceSettings" && payload?.d?.requestStatus?.code !== 500) {
  this.obsConfirmed = true;
}
```

We can only send a message to modify settings if the user is not currently streaming. If we try to send the message during a stream, we'll receive an error:

```json
{
  "d": {
    "requestId": "1721060432114",
    "requestStatus": {
      "code": 500,
      "comment": "You cannot change stream service settings while streaming.",
      "result": false
    },
    "requestType": "SetStreamServiceSettings"
  },
  "op": 7
}
```

To avoid this error, we can disable our token setting logic if the stream has started. We can listen for an event that contains the following payload to know when the stream has started.

```json
{
  "d": {
    "eventData": {
      "outputActive": true,
      "outputState": "OBS_WEBSOCKET_OUTPUT_STARTED"
    },
    "eventIntent": 64,
    "eventType": "StreamStateChanged"
  },
  "op": 5
}
```

Finally, to set the token and endpoint we can send a message with the `requestType` of `SetStreamServiceSettings` which contains the proper `bearer_token` and `endpoint`:

```js
updateStreamSettings() {
  if (!this.obsConnection) return;
  this.obsConnection.send(JSON.stringify({
    "op": 6,
    "d": {
      "requestType": "SetStreamServiceSettings",
      "requestId": Date.now().toString(),
      "requestData": {
        "streamServiceType": "whip_custom",
        "streamServiceSettings": {
          "bearer_token": this.token,
          "server": this.endpoint,
        }
      }
    }
  }));
}
```

## Summary

In this post, we looked at one approach for improving user experience when broadcasting to an Amazon IVS real-time stage from OBS. In the next post, we'll look at another creative use of custom docks in OBS to enable users to see, hear and interact with other participants in a real-time stage.
