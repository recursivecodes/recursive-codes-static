---
title: "Moderating Amazon IVS Chat Messages with an AWS Lambda Function"
slug: "moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p"
author: "Todd Sharp"
date: 2022-10-14T13:40:35Z
summary: "In a recent post we looked at how to add chat to an Amazon Interactive Video Service (Amazon IVS)..."
tags: ["amazonivs", "aws", "chat", "lambda"]
canonical_url: "https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-56njikq6gk2oky0r1yx4.png"
---

In a [recent post](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) we looked at how to add chat to an Amazon Interactive Video Service (Amazon IVS) live stream. Chat rooms are a huge part of creating interactive live streaming experiences, but unfortunately they come with the inevitable possibility that some users may post messages that are insensitive or otherwise offensive. In this post, I'll show you a very simple, but effective way to moderate your Amazon IVS chat rooms to keep things fun and friendly. 

## Introducing Chat Moderation Review Handlers

There are two ways to address chat moderation: manual and automated. The manual method, which we'll cover in a future post, requires a moderator (the broadcaster or another designated user) to 'flag' a chat message for removal via one of the Amazon IVS Chat SDKs [docs](https://docs.aws.amazon.com/ivs/latest/chatmsgapireference/actions-deletemessage-publish.html). Flagging a message sends an event to all connected WebSocket clients that can be used to update or remove the offending message. The automated method, which we'll cover in this post, lets us utilize an AWS Lambda function to perform substitutions on the chat message or reject the delivery based on the business needs of the application. 

There are both pros and cons to both manual and automated moderation. One "pro" to manual moderation is that since it requires human intervention, you're less likely to have "false positives" that are possible with automated moderation. Another positive of manual intervention is that humans are generally better than machines at identifying messages that should be moderated. However, a "con" of manual moderation is that messages can only be removed **after** they have been posted to a chat room room. And as the saying goes, "you can't put the toothpaste back in the tube". In other words, potentially offensive messages have already been viewed by your users - you can't make them "unsee" a message they may have already seen. 

On the other hand, automated moderation gives us the ability to reject (or censor) harmful messages before they get posted to a chat room. But, as mentioned above, it's really difficult for chat messages to be properly moderated by a machine with a great deal of accuracy. Have you ever been in a chat room or posted a comment to a blog post that is purely innocent and had it rejected or censored incorrectly? It can be very frustrating for a chat user who submits a message saying "This person would be a real asset to our team" only to see "This person would be a real ***et to our team" posted to the chat room (or simply rejected)!

With that said, the best approach for chat moderation is an individual decision for your application based on your intended audience and business needs. I suspect that many applications that require moderation would ultimately utilize a combination of manual and automated moderation. 

Now that we've talked about both possible approaches, let's dig into how you can use an AWS Lambda function to perform automated moderation for your Amazon IVS chat room.

## Adding a Message Review Handler

When creating (or updating) an Amazon IVS chat room via the Amazon IVS console, AWS CLI, or one of the Amazon IVS SDKs, we can specify an AWS Lambda function that will serve as our message review handler. In this post, we'll focus on using the Amazon IVS console, but you can refer to the appropriate documentation if you'd like to use another method. To add a handler, scroll down to the* Message review handler* section while creating or editing an Amazon IVS chat room. By default, the 'Disabled' option will be selected.

![Message review handler options](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-hm8oydvrluohvvrmjcmq.png)

Let's change this by selecting *Handle with AWS Lambda*.

![Select Handle with AWS Lambda](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dv4uq7r8jdiccvtid0vv.png)

This presents us with a few more options. The first option, *Fallback result* lets us choose how we want to handle invalid responses, errors, and timeouts from our handler function. Again, this depends on your business needs. If you would rather reject messages in this case, select *Deny*. If you choose *Allow*, potentially harmful messages may be posted to your chat room. This is where a combination approach could provide you with a 'backup plan' so that a moderator could still remove messages that are missed by the handler for whatever reason. For this demo, I'll choose *Allow*. Next, we'll need to specify the AWS Lambda function that will act as our handler. We'll create a new function via the console for this demo, so let's click on *Create Lambda function*.

![Create Lambda function button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-b1vpbgcs8bqsi7b5iq06.png)

Clicking on this button will take us to the list of our current functions. On this page, click *Create function*.

![Create function button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gkuowvzcw2jff7my3s1a.png)

On the next page, enter the name ivs-chat-moderation-function, leave the defaults selected for the rest of the options, and then click *Create function*.

![Create function button](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dxia4wg38ekktrjh39sx.png)

Now let's update the code for our function. The documentation (https://docs.aws.amazon.com/ivs/latest/userguide/chat-message-review-handler.html) tells us that the function will receive an event object in the following format:

```json
{
  "Content": "string",
  "MessageId": "string",
  "RoomArn": "string",
  "Attributes": {"string": "string"},
  "Sender": {
    "Attributes": { "string": "string" },
    "UserId": "string",
    "Ip": "string"
  }
}
```

In order to return a value from our function using Node, we must use an async function (see the [AWS Lambda documentation](https://docs.aws.amazon.com/lambda/latest/dg/nodejs-handler.html) for more info). The object that we return must use the following format:

```json
{
 "Content": "string",
 "ReviewResult": "string",
 "Attributes": {"string": "string"},
}
```

The value that we set for ReviewResult must be `ALLOW` or `DENY` and will determine whether or not the message is delivered to the chat room. We can modify the message Content as necessary, meaning we can remove or replace potentially offensive or insensitive content and `ALLOW` the message to be posted. Any additional attributes can be passed with `Attributes`. If you choose to send a `ReviewResult` of `DENY`, you can pass a `Reason` attribute which will be used to return a `406 Not Acceptable` response to the client including the value specified as the `Reason`.

> Refer to the [Chat Message Review Handler documentation](https://docs.aws.amazon.com/ivs/latest/userguide/chat-message-review-handler.html#create-lambda-function) for further information including length constraints and valid values.  

Now we can modify the code of the function to replace a 'bad word' in the incoming content with asterisks. 

```js
exports.handler = async (event) => {
  return {
    ReviewResult: 'ALLOW',
    Content: event.Content.replace(/bad word/ig, '*** ****'),
    Attributes: {
      username: event.Attributes.username
    }
  };
};
```
Let's head back to our chat room, refresh the list of functions, select our new function and click **Save changes**.

![Saving the chat room](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dtivv66eq9dnzajzf9jw.png)

Now we can post a message to our chat room and see what happens.

![Posting a message with a bad word in it](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ica8r4sdgha7i6nywb0i.gif)

Excellent! Our chat message handler was properly invoked and our 'bad word' was removed before it was posted to the chat room.

In reality, you'd want to use a much more sophisticated solution for replacing harmful text than the simple regex that I'm using above. I've tested the [@2toad/profanity](https://www.npmjs.com/package/@2toad/profanity) library and found it to do a great job of censoring and identifying profane words in an incoming message. Feel free to use whatever solution works for you, but keep in mind that your function must return a response within 200ms or it will timeout, so third-party API calls may be out of the question. 

Here's an example of a handler that uses the `@2toad/profanity` library to censor harmful words:

```js
exports.censorChat = async (event) => {
  console.log('censorChat:', JSON.stringify(event, null, 2));
  return {
    ReviewResult: 'ALLOW',
    Content: profanity.censor(event.Content),
    Attributes: {
      username: event.Attributes.username
    }
  };
};
```

And an example of rejecting a message instead of censoring.

```js
exports.rejectInappropriateChat = async (event) => {
  console.log('rejectInappropriateChat:', JSON.stringify(event, null, 2));
  const profane = profanity.exists(event.Content);
  return {
    ReviewResult: profane ? 'DENY' : 'ALLOW',
    Content: profane ? '' : event.Content,
    Attributes: {
      username: event.Attributes.username
    }
  };
};
```

## Summary

In this post we learned about two different approaches to moderate chat messages: manual and automated. We then created an AWS Lambda function and associated it with an Amazon IVS chat room to perform automated chat moderation. In a future post, we'll look at how you can use the Amazon IVS Chat SDK to manually moderate chat messages. If you have any questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).