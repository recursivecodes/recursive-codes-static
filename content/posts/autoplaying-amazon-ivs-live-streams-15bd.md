---
title: "Autoplaying Amazon IVS Live Streams"
slug: "autoplaying-amazon-ivs-live-streams-15bd"
author: "Todd Sharp"
date: 2023-03-10T15:23:10Z
summary: "Sometimes it's the little features that differentiate one application from another. If you've added..."
tags: ["express", "linting", "productivity"]
canonical_url: "https://dev.to/aws/autoplaying-amazon-ivs-live-streams-15bd"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-da8fziypl5q2jmt1qyji.jpeg"
---

Sometimes it's the little features that differentiate one application from another. If you've added live streaming to your application and your user's navigate to a channel that they are interested in viewing, what happens if the channel is not currently broadcasting when they hit the page? Maybe you have added [Amazon Interactive Video Service (Amazon IVS) chat](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) to create an interactive experience so that viewers can spend the time waiting for a broadcasting chatting with each other, but what happens when the broadcast goes live? Do your viewers have to click a 'play' button, or worse yet reload the entire web page to view the stream? How can we improve this experience? Wouldn't it be better to autoplay the stream when it goes live? Of course it would! Sadly, the Amazon IVS [player](https://docs.aws.amazon.com/ivs/latest/userguide/player.html) does not have a built-in method for autoplaying live stream. But, we can workaround this limitation! 

One option to autoplay videos is to use polling (via `setInterval()` on the client side) to check to see if the stream is broadcasting:

```js
setInterval(() => {
  ivsPlayer.load(streamUrl);
  ivsPlayer.play();
});
```

This technically _works_, but it's not the best idea. With the polling approach, you would end up with tons of `404` errors in the console. Also, you'd have to store the interval and eventually clear it later on when the stream starts playing. How often should you run the check? Every second seems to frequent, every 10 seconds seems to infrequent. It's a messy approach, and requires extra code to manage.

A better approach would be to send a push notification to the client when a stream goes online. With this approach, you avoid the messiness of polling and can be assured that the stream starts as soon as possible after the broadcaster has gone online. So how do we know when a stream is online, and how can we easily send the notification to the client? 

We've previously looked at using [Amazon EventBridge rules to send push notifications](https://dev.to/aws/notifying-subscribers-when-an-amazon-ivs-stream-is-online-f1c) or alerts when a stream goes online, and we can use a similar approach to autoplay live streams. With this approach, we'll create an EventBridge rule that triggers an AWS Lambda function when a stream goes online. But, instead of (or in addition to) sending a push notification, we can use Amazon IVS chat custom events to send a message to all connected chat clients and in the client-side handler start playing the stream when the message is received. 

> **Not using Amazon IVS Chat?** That's OK! You can utilize any pub/sub or WebSocket implementation to send the message to your front end. Also, even if you're not using Amazon IVS chat for interactive chat, you can still utilize it as an event bus for application messaging. 

## Creating the Lambda Function and EventBridge Rule

Let's set up a serverless application using AWS Serverless Application Model (AWS SAM). In this application, we'll have a function that will be used to send the custom chat event. Let's first look at the AWS Lambda function (`index.mjs`). This function will need to use a layer that enables us to utilize the `@aws-sdk/ivs-chat` module from the AWS SDK for JavaScript (v3). We'll use the `SendEvent` ([docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivschat/classes/sendeventcommand.html)) method to send a custom event to our chat clients.

```js
import { IvschatClient, CreateChatTokenCommand, SendEventCommand } from '@aws-sdk/client-ivschat';

const chatArn = process.env.DEMO_CHAT_ARN;

export const streamStarted = async (event) => {
  const client = new IvschatClient();

  const sendEventInput = {
    roomIdentifier: chatArn,
    eventName: 'STREAM_STARTED',
    attributes: {
      event: JSON.stringify(event),
    },
  }
  const sendEventRequest = new SendEventCommand(sendEventInput);
  const sendEventResponse = await client.send(sendEventRequest)

  const response = {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'OPTIONS,GET,PUT,POST,DELETE',
      'Content-Type': 'application/json'
    },
    isBase64Encoded: false
  };
  response.statusCode = 200;
  response.body = JSON.stringify(sendEventResponse, '', 2);
  return response;
};
```

We'll need a `template.yaml` file to create and deploy the function. In this template, we'll also add a definition for the EventBridge rule and create the necessary permissions for the rule to invoke the AWS Lambda function. Also note that I'm setting the `DEMO_CHAT_ARN` as an environment variable so that it can be accessed in the AWS Lambda function. 

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: 'AWS::Serverless-2016-10-31'
Description: Amazon IVS Functions
Globals:
  Function:
    Runtime: nodejs18.x
    Timeout: 30
    MemorySize: 128
  Api:
    Cors:
      AllowMethods: "'GET,POST,OPTIONS'"
      AllowHeaders: "'Content-Type'"
      AllowOrigin: "'*'"
      MaxAge: "'600'"
Resources:
  LambdaRefLayer:
    Type: AWS::Serverless::LayerVersion
    Properties:
      LayerName: sam-app-dependencies
      Description: Dependencies for sam app
      ContentUri: dependencies/
      CompatibleRuntimes:
        - nodejs18.x
      LicenseInfo: "MIT"
      RetentionPolicy: Retain

  IVSAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: IVSAccess
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - 'ivschat:*'
            Resource: '*'
      Roles:
        - Ref: StreamStartedRole

  StreamStarted:
    Type: 'AWS::Serverless::Function'
    Properties:
      Environment:
        Variables:
          DEMO_CHAT_ARN: 'arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]'
      Handler: index.streamStarted
      Layers:
        - !Ref LambdaRefLayer
      CodeUri: lambda/

  EventRule0:
    Type: AWS::Events::Rule
    Properties:
      Description: >-
        Rule to send a custom chat event when an Amazon IVS live stream session
        begins
      EventBusName: default
      EventPattern:
        source:
          - aws.ivs
        detail-type:
          - IVS Stream State Change
        detail:
          event_name:
            - Stream Start
      Name: demo-stream-started-0
      State: ENABLED
      Targets:
        -
          Arn: 
            Fn::GetAtt: 
              - "StreamStarted"
              - "Arn"
          Id: "StreamStartedTarget"
          
  PermissionForEventsToInvokeLambda: 
    Type: AWS::Lambda::Permission
    Properties: 
      FunctionName: 
        Ref: "StreamStarted"
      Action: "lambda:InvokeFunction"
      Principal: "events.amazonaws.com"
      SourceArn: 
        Fn::GetAtt: 
          - "EventRule0"
          - "Arn"
```

Now we can `package` this serverless application via the AWS SAM CLI. 

>**Note:** If you're not familiar with AWS SAM, check out the 'getting started' [guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-getting-started.html).

```bash
sam package --template-file template.yaml --output-template-file packaged.yaml --s3-bucket ivs-demo
```

And `deploy` it.

```bash
sam deploy --template-file packaged.yaml --stack-name ivs-demo-stack --capabilities CAPABILITY_IAM
```

Once deployed, you can verify that the EventBridge rule was created. One way to do that is to view your rules in the EventBridge console.

![EventBridge rules](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-xz43o1348nfzateko1zs.png)

You can also verify that the AWS Lambda was created via the console.

![AWS Lambda function](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-u7n3k785355ynd8tllym.png)

Now we can start a broadcast on the Amazon IVS channel, and observe that the EventBridge rule has been invoked via the console.

![EventBridge rule invocations](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-mxj257s7dck59q9c9sg7.png)

## Listening For Custom Events on the Client Side

Now that the we have custom events being published to an Amazon IVS chat room, we can set up our front-end to connect to the chat room and add some logic to our `onmessage` handler to play the stream when the custom event is received. The AWS Lambda function above sends the triggering event in the `Attributes` property of the custom event, so we can use the data from that triggering event to check the channel name and determine if we need to play the stream. The `playStream()` method is not defined in the example below, but it would contain any necessary logic to play the stream depending on your chosen video player.

```js
const connection = new WebSocket('[chat room endpoint]', '[chat token]');

connection.onmessage = (event) => {
  const data = JSON.parse(event.data);

  if (data.Type === 'MESSAGE') {
    // render chat message 
  }
  if (data.Type === 'EVENT') {
    switch (data.EventName) {
      case 'STREAM_STARTED':
        const triggerEvent = JSON.parse(data.Attributes.event);
        if (triggerEvent.detail.channel_name === 'demo-channel' && !isPlaying) {
          playStream();
        } 
        break;
    }
  }
}
```

And that's it! Our stream will now automatically play when a broadcaster goes online.


## Summary

In this post, we learned how to use EventBridge rules to send a custom Amazon IVS chat event when an Amazon IVS live stream session begins so that the live stream video can be automatically played. Question, comments, and feedback is always welcomed below.