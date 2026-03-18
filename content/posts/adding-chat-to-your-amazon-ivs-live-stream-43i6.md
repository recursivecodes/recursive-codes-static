---
title: "Adding Chat to Your Amazon IVS Live Stream"
slug: "adding-chat-to-your-amazon-ivs-live-stream-43i6"
author: "Todd Sharp"
date: 2022-09-16T13:41:56Z
summary: "Welcome back to this series where we're learning all about live streaming in the cloud with Amazon..."
tags: ["aws", "cloud", "amazonivs", "livestreaming"]
canonical_url: "https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-9gr6cwrj2u875azo29jq.png"
---

Welcome back to this series where we're learning all about live streaming in the cloud with Amazon Interactive Video Service (Amazon IVS). If you're new to this series, here's what we've covered so far:

- Getting Started Live Streaming in the Cloud with Amazon IVS
- Creating Your First Live Stream Playback Experience with Amazon IVS
- Enhancing Your Amazon IVS Playback Experience
- Creating Interactive Live Streaming Experiences Using Timed Metadata with Amazon IVS

In this post, we're going to level up the interactivity and add live chat alongside our live stream viewer. 

> If you want to play along at home with this blog post, you will need to create your own chat room. Amazon IVS Chat rooms require custom user tokens, so you'll need to plug in your own token and chat endpoint in the embedded demo below to try it out!

## Creating a Chat Room

The first step here is to create a chat room for our application.

> **Free?** The [AWS Free Tier for Amazon IVS](https://aws.amazon.com/ivs/pricing/) provides 13,500 messages sent and 270,000 messages delivered every month. [Sign up](https://aws.amazon.com/free) to get started for free!

I should also mention that as of the the published date of this post, Amazon IVS Chat is available in the following regions:

- us-east-1
- us-west-2
- eu-west-1

Keep an eye out for future region support if you are trying to create a chat room in a region other than those listed above.

### Using the Console

One way to create our chat room is by using the [Amazon IVS Management Console](https://console.aws.amazon.com/ivs). From the console home page, expand **Chat** and select **Rooms**.

![Chat rooms menu](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gn3wsrpx38ng2oyauquc.png)
 
From the chat room list page, click on **Create room**.

![Create room button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-qn5aw3tw5xll1ixx3bb5.png)
 
On the create room page, enter a **Room name**, and leave **Default configuration** selected under **Room configuration**. The default configuration gives us a maximum message length of 500 characters, and 10 messages per second. If this is not sufficient for your application, you can select **Custom configuration** and override it as necessary.

![Room name and configuration](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-sxcv6dznjfse5jm5rlz9.png)
 
Next, under **Message review handler**, leave **Disabled** selected. 

![Message review handler](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-6dsu1uf3lxpc4efs0i89.png)
 
The message review handler is a really powerful way to provide AI moderation of chat messages via an AWS Lambda function. Per the help text:

> When a message review handler is associated with a room, it is invoked for each SendMessage request to that room. The handler enforces any business logic that has been defined and determines whether to allow, deny, or modify a message.

We'll cover using a custom event handler in a future post, but for now, we'll leave it disabled.

Enter any desired tags for this resource, and then click **Create room**.

![Tags and create room button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-s5iwmzjcvvxysojax3do.png)
 
Our room will be created with no delay, and we'll be redirected to the room details page. On that page, you'll see a summary of the room configuration. The important bit that we'll need from this section is the **Messaging endpoint**. Since Amazon IVS Chat rooms are based on WebSockets, this is the secure endpoint that we'll use in the frontend to connect to our chat room.

![Chat room details and messaging endpoint](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ygxm3aqg2c46pq8s625i.png)
 
There is also a panel titled **Chat tokens** that gives us a helpful tool to generate a chat token for development purposes. As I mentioned above, if you'd like to try the embedded chat experience below, you'll need a token and this is one way to generate it.

![Chat tokens](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-95dw9wn0mcpa0luv1mje.png)
 
### Using the AWS CLI

We can also use the AWS CLI to create a chat room via the following command.

```bash
$ aws ivschat create-room --name my-first-ivs-chat-room
```

Which returns the chat room information in JSON format:

```json
{
    "arn": "arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]",
    "createTime": "2022-08-05T12:46:17.945000+00:00",
    "id": "j0mJloyM8mOy",
    "maximumMessageLength": 500,
    "maximumMessageRatePerSecond": 10,
    "name": "my-first-ivs-chat-room",
    "tags": {},
    "updateTime": "2022-08-05T12:46:17.945000+00:00"
}
```

The CLI does not return the messaging endpoint. However, it's easy to determine this. There are only three options and they correspond to the region in which your chat room was created.

| Region     | Endpoint                                    |
|------------|---------------------------------------------|
| us-east-1  | wss://edge.ivschat.us-east-1.amazonaws.com  |
| us-west-2  | wss://edge.ivschat.us-west-2.amazonaws.com  |
| eu-west-1  | wss://edge.ivschat.eu-west-1.amazonaws.com  |

To retrieve a chat token from the CLI, you can use the following command. But hold off on generating that for now until we need it below, because the token will expire pretty quickly. To clarify - the token itself is used to authorize a chat user and establish a session. The default timeout for the session established via the token is 60 minutes, at which point a new session will need to be established (via logic in your application - more on this later on).

```bash
$ aws \
    ivschat \
    create-chat-token \
    --room-identifier "[YOUR CHAT ROOM ARN]" \
    --user-id "[A UNIQUE ID FOR THIS USER]" \
    --capabilities "SEND_MESSAGE"
```

## Integrating Chat 

Now that we have a chat room, let's build out a demo to see it in action. As I mentioned above, since the chat room requires a chat token, we'll create a form to capture the token and the messaging endpoint. 

```html
<form id="settings-form" class="needs-validation" novalidate>

  <div class="mb-3 row">
    <label for="chat-token" class="col-sm-2 col-form-label">Chat Token</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" id="chat-token" required />
    </div>
  </div>

  <div class="mb-3 row">
    <label for="chat-endpoint" class="col-sm-2 col-form-label">Endpoint</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" id="chat-endpoint" placeholder="Begins with: wss://" required />
    </div>
  </div>

  <div class="mb-3 row">
    <div class="col-sm-10 offset-sm-2">
      <button type="submit" class="btn btn-dark" id="submit-settings" disabled>Submit</button>
    </div>
  </div>

</form>
```

You can generate your own token to plug in to this form via the console or the CLI methods shown above. In your production applications, you'll use an SDK to generate this token (and refresh, if necessary). Here's how you might generate a token with the Node SDK ([reference docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/createchattokencommand.html)).

```js
import AWS from 'aws-sdk';

const credentials = new AWS.Credentials({
  accessKeyId: process.env.ACCESS_KEY,
  secretAccessKey: process.env.SECRET_KEY,
});
const IvsChat = new AWS.Ivschat({ region: 'us-east-1', credentials });

const createToken = async () {
  let token;

  const params = {
    roomIdentifier: "[YOUR CHAT ARN]",
    userId: "[UNIQUE USERID]",
    attributes: {},
    capabilities: ['SEND_MESSAGE'],
    sessionDurationInMinutes: 60,
  };
  try {
    const data = await IvsChat.createChatToken(params).promise();
    token = data.token;
  }
  catch (e) {
    console.error(e);
    throw new Error(e);
  }
  return token;
}
```

Next, add some markup to display the chat messages, a text input to enter a new message, and a send button.

```html
<div id="chat-container" class="d-none">
  <div id="chat" class="border rounded mb-3 p-3" style="height: 300px; overflow-y: auto;"></div>
    <div id="chat-input-container">
      <div class="input-group">
        <input id="chat-input" placeholder="Message" maxlength="500" type="text" class="form-control" />
        <button id="submit-chat" class="btn btn-outline-secondary">Send</button>
      </div>
  </div>
</div>
```

We'll listen for the form submission, and when that happens we can initialize the chat room WebSocket connection.

```js
const endpoint = document.getElementById('chat-endpoint').value;
const token = document.getElementById('chat-token').value;

window.chatConnection = new WebSocket(endpoint, token);
```

All of the standard [WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) events apply here. For example, to listen for incoming messages, we use `onmessage`.

```js
window.chatConnection.onmessage = (event) => {
  // parse the event data
  const data = JSON.parse(event.data);

  // append the incoming msg to the chat
  const msgHtml = `<div class="mb-2"><b class="text-primary">${data.Attributes.username}</b>: ${data.Content}</div>`;
  const chatContainer = document.getElementById('chat');
  chatContainer.innerHTML += msgHtml;
  chatContainer.scrollTop = chatContainer.scrollHeight;
};
```

And finally, an event listener on the **Send** button that will send the message using the `chatConnection`.

```js
document.getElementById('submit-chat').addEventListener('click', () => {
  const msgInput = document.getElementById('chat-input');
  const payload = {
    "action": "SEND_MESSAGE",
    "content": stripHtml(msgInput.value),
    "attributes": {
      "username": username
    }
  }
  try {
    window.chatConnection.send(JSON.stringify(payload));
  }
  catch (e) {
    console.error(e);
  }
  msgInput.value = '';
  msgInput.focus();
});
```
## The Demo

Let's see our chat demo in action! Use one of the methods we looked at above to get a chat token, and use your chat room's messaging endpoint to login and give it a shot!

{% codepen https://codepen.io/recursivecodes/pen/MWVVZvR %}

Check out the full source in the CodePen above to see the complete example.

## Summary

In this post, we created our first Amazon IVS Chat room and learned how to integrate it into our live streaming application. We’ll switch gears in the next post and focus a bit more on broadcasting to our live stream. If you have questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by [Pontep Luangon](https://pixabay.com/users/vvadyab-13368278/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=4457839) from [Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=4457839)