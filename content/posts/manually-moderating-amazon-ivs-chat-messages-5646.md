---
title: "Manually Moderating Amazon IVS Chat Messages"
slug: "manually-moderating-amazon-ivs-chat-messages-5646"
author: "Todd Sharp"
date: 2022-10-21T12:38:01Z
summary: "In my last post, we learned how to use an AWS Lambda function to moderate Amazon Interactive Video..."
tags: ["aws", "websockets", "amazonivs", "javascript"]
canonical_url: "https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wi67se7ktkhzvoifo1vo.png"
---

In my [last post](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p), we learned how to use an AWS Lambda function to moderate Amazon Interactive Video Service (Amazon IVS) chat messages. In that post, we looked at the pros and cons of both automated and manual message moderation, so we won't repeat that in this post. Instead, we'll focus on implementing manual chat moderation which requires a delegated end user (from here on referred to as a chat moderator) with a token granting them specific capabilities that we'll outline below. This chat moderator must manually identify offensive or insensitive messages and/or users that should be disconnected. Our application must also invoke the proper API or SDK methods which result in certain events being published to our connected clients that we can use to replace or remove the offensive content. 

In this post, we'll look at two different approaches to chat moderation. The first approach is to delete messages and disconnect users by publishing a message request through the chat WebSocket connection, as outlined in the Chat Messaging API ([docs](https://docs.aws.amazon.com/ivs/latest/chatmsgapireference/welcome.html)). You can use this approach when the chat moderator for your application is also connected to the chat room. This method requires the chat moderator who sends the request has a token with the `DELETE_MESSAGE` and/or `DISCONNECT_USER` capabilities assigned (depending on the action being invoked).

The second approach is to perform the delete operation with one of the AWS SDKs. We'll use the `ivschat` client ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/)) from the AWS SDK for JavaScript v3 in this post, but the operation is available in all of the Amazon IVS Chat SDKs. Feel free to refer to the documentation for your favorite language if you're not a JavaScript user. This approach isn't necessarily more difficult than using the Chat Messaging API, but it does require an authenticated SDK client running on a server (or available in a serverless environment). The AWS SDK approach can be used to moderate messages and disconnect users from a chat moderator who is not currently connected to the chat room via a WebSocket client. 

## Moderating with the Chat Messaging API

Let's look at the Chat Messaging API first. 

### Generating a Token

As you may recall from my [post a few weeks ago](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) (https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6), in order to establish a connection to an Amazon IVS chat room via WebSockets, each user must have a token that is passed to the call to `new WebSocket()` along with the chat room endpoint. You can obtain a token via the Amazon IVS console, or via the CLI, but in a production app you'll be using the Amazon IVS SDK's `CreateChatTokenCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/createchattokencommand.html)) method. That method expects a `CreateChatTokenCommandInput` object ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/interfaces/createchattokencommandinput.html)) and returns a `CreateChatTokenCommandOutput` object ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/interfaces/createchattokencommandoutput.html)). Here's an example of creating a chat token for a regular chat user:

```js
async createToken(chatArn, userId, username) {
  let capabilities = ['SEND_MESSAGE'];
  const params = {
    roomIdentifier: chatArn,
    userId: userId,
    attributes: {},
    capabilities,
    sessionDurationInMinutes: 60,
  };
  const response = await IvsChat.createChatToken(params).promise();
  return response.token;
}
```

Regular chat users require the `SEND_MESSAGE` capability, but if we look at the [documentation](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/enums/chattokencapability.html) for `ChatTokenCapability`, we can see two other capabilities that can be assigned to a user: `DELETE_MESSAGE` and `DISCONNECT_USER`. These are aptly named - they allow a user to do exactly what you'd expect them to do. Let's modify the `createToken()` function above to accommodate the creation of tokens for admin users:

```js
async createToken(chatArn, userId, username, isAdmin) {
  let capabilities = ['SEND_MESSAGE'];
  if (isAdmin) {
    capabilities = [
      ...capabilities,
      'DISCONNECT_USER',
      'DELETE_MESSAGE',
    ];
  }
  const params = {
    roomIdentifier: chatArn,
    userId: userId,
    attributes: {},
    capabilities,
    sessionDurationInMinutes: 60,
  };
  const response = await IvsChat.createChatToken(params).promise();
  return response.token;
}
```

In this updated function, we've added an `isAdmin` parameter, and if we pass `true` as that parameter, we'll grant the user the additional capabilities they need in order to moderate chat messages. Your front end will likely use some logic based on the logged in user to determine whether or not the user is an admin (and you should secure the method appropriately to make sure that only the proper user is granted an admin token). Additionally, you'll probably want to use that logic to present a button for the admin user to quickly and easily remove a message.

### Deleting an Existing Message

When an end user has the `DELETE_MESSAGE` capability, they are able to publish a specially formatted message via their chat WebSocket connection to delete a message. Here's the required format:

```json
{
  "Action": "DELETE_MESSAGE",
  "Id": "string",
  "Reason": "string",
  "RequestId": "string"
}
```

The `Id` parameter comes from the `Id` in the offending message when it was originally received, so you'll want to store this somehow. One way to do that is by saving it via a `data-*` attribute ([docs](https://developer.mozilla.org/en-US/docs/Learn/HTML/Howto/Use_data_attributes)) on the message that you append to your chat container when a new message is received. That might look similar to this:

```html
<div>
  <i class="trash-icon" role="button"></i> 
  <b>Todd</b>: 
  <span class="msg" data-msg-id="I4fme01f7HYM">
    you are not very nice, admin person!
  </span>
</div>
```

When the admin clicks the `trash-icon`, the click handler can call a `deleteMessage(id)` function.

```js
document.getElementById('chat').addEventListener('click', (e) => {
  if (e.target.classList.contains('trash-icon')) {
    const icon = e.target;
    const msgEl = icon.parentElement.querySelector('[data-msg-id]');
    deleteMessage(msgEl.dataset.msgId);
  }
});

const deleteMessage = (id) => {
  const payload = {
    'Action': 'DELETE_MESSAGE',
    'Id': id,
    'Reason': '[removed by moderator]'
  };
  window.chatConnection.send(JSON.stringify(payload));
};
```
The value passed as the 'Reason' is available to connected clients in the incoming event message (as shown below). This might allow your moderator to pass a custom message to display to the offending user or to replace the existing chat message contents. You can also choose to delete the existing message altogether - it's up to you and your business needs.

After publishing the request to delete the message, a new message will be received with a `Type` of `EVENT` and an `EventName` of `aws:DELETE_MESSAGE`. This might look like this.

```json
{
  "Type": "EVENT",
  "Id": "1OjMY6p8h4uv",
  "RequestId": "",
  "EventName": "aws:DELETE_MESSAGE",
  "Attributes": {
    "MessageID": "I4fme01f7HYM",
    "Reason": "[removed by moderator]"
  },
  "SendTime": "2022-10-14T20:08:11.258800067Z"
}
```

Finally, we can modify our `onmessage` handler on the WebSocket connection to handle this new event and take any necessary action.

```js
window.chatConnection.onmessage = (event) => {
  const data = JSON.parse(event.data);
  const chatEl = document.getElementById('chat');
  if (data.Type === 'MESSAGE') {
    // removed for brevity...
  }
  if (data.Type === 'EVENT') {
    switch (data.EventName) {
      case 'aws:DELETE_MESSAGE':
        // find the existing msg in chat
        const msg = chatEl.querySelector(`[data-msg-id="${data.Attributes.MessageID}"]`);
        // replace the msg contents with the removed reason
        // (could also delete, if necessary)
        msg.innerHTML = data.Attributes.Reason;
    }
  }
};
```

Here's how this looks in action:

![Manual chat moderation demo](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-aa2atztz58bkuf97yfwq.gif)

### Disconnecting Users

Sometimes we need to take the additional step of banning users who repeatedly post offensive messages in chat rooms. To do this, we can use the `DISCONNECT_USER` method of the Chat Messaging API. This is very similar to the `DELETE_MESSAGE` method, and looks like this:

```js
const disconnectUser = (id, reason) => {
  const payload = {
    'Action': 'DISCONNECT_USER',
    'UserId': id,
    'Reason': reason,
  };
  window.chatConnection.send(JSON.stringify(payload));
};
```

We can modify our `onmessage` handler to listen for this new event and display a message (if desired) to the user:

```js
if (data.Type === 'EVENT') {
  switch (data.EventName) {
    case 'aws:DELETE_MESSAGE':
      // [removed for brevity]
    case 'aws:DISCONNECT_USER':
      alert(`You have been disconnected by the chat moderator. Message from mod: ${data.Attributes.Reason}.`);
  }
}
```
The `DISONNECT_USER` event looks similar to the `DELETE_MESSAGE` event.

```json
{
  "Type": "EVENT",
  "Id": "b4aYjMZyU8bo",
  "RequestId": "",
  "EventName": "aws:DISCONNECT_USER",
  "Attributes": {
    "Reason": "Repeated offensive messages. Be nice!",
    "UserId": "42fb390e-2fb0-4e4e-b25f-c97f661da5fa"
  },
  "SendTime": "2022-10-17T12:53:12.922376139Z"
}
```

When the `DISCONNECT_USER` message is received on a WebSocket, the user is automatically disconnected and is unable to publish new messages. It's up to your application to determine the length of any such ban and perform and implement the necessary logic on the server side to prevent further reconnections by the user.

## Moderating with the AWS SDK for JavaScript v3

As mentioned above, we can also use the AWS SDK for JavaScript to handle manual chat moderation. The user performing the SDK operation must have the `ivschat:DeleteMessage` and `ivschat:DisconnectUser` IAM permissions. Here are a few functions that can delete existing chat messages with `DeleteMessageCommand` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/deletemessagecommand.html)) and disconnect users with `DisconnectUserRequest` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/disconnectusercommand.html)).

```js
const ivsChat = new AWS.Ivschat({ apiVersion: '2020-07-14', region: 'us-east-1' });

deleteChat = async (msgId, chatArn) => {
  const result = await ivsChat.deleteMessage({
    roomIdentifier: chatArn,
    id: msgId,
    reason: '[removed by moderator]',
  }).promise();
  return result;
};

disconnectUser = async (userId, chatArn, reason) => {
  const result = await ivsChat.disconnectUser({
    roomIdentifier: chatArn,
    userId: msgId,
    reason: reason,
  }).promise();
  return result;
};
```

Invoking the `deleteChat` function from the server side via the AWS SDK performs the exact same operation as when it is invoked via WebSockets with the Chat Messaging API, and the message that is published to all connected clients will look identical:

```json
{
  "Type": "EVENT",
  "Id": "1OjMY6p8h4uv",
  "RequestId": "",
  "EventName": "aws:DELETE_MESSAGE",
  "Attributes": {
    "MessageID": "I4fme01f7HYM",
    "Reason": "[removed by moderator]"
  },
  "SendTime": "2022-10-14T20:08:11.258800067Z"
}
```

The `DELETE_MESSAGE` event can be handled in the same manner as above. You can replace the offending message or delete it.

Invoking the `disconnectUser` function via the AWS SDK also performs the same operation as when it's invoked via the Chat Messaging API and results in an event being published to all connected clients and the offending user being disconnected just as with the Chat Messaging API that we saw above. Again, it's left to your application to prevent further connections by the user (if necessary).

```json
{
  "Type": "EVENT",
  "Id": "b4aYjMZyU8bo",
  "RequestId": "",
  "EventName": "aws:DISCONNECT_USER",
  "Attributes": {
    "Reason": "repeated offensive messages. be nice!",
    "UserId": "42fb390e-2fb0-4e4e-b25f-c97f661da5fa"
  },
  "SendTime": "2022-10-17T12:53:12.922376139Z"
}
```

## Summary

In this post we learned how to manually moderate chat messages and disconnect users via the Chat Messaging API and the AWS SDK for JavaScript. If you have any questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).
