---
title: "Creating Safer Online Communities with AI/ML Content Moderation"
slug: "creating-safer-online-communities-with-aiml-content-moderation-1bn"
author: "Todd Sharp"
date: 2023-04-21T12:43:12Z
summary: "The interactivity and unpredictability of live streaming user generated content (UGC) platforms is a..."
tags: ["aws", "amazonivs", "machinelearning", "ai"]
canonical_url: "https://dev.to/aws/creating-safer-online-communities-with-aiml-content-moderation-1bn"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rrduq1jg3yuq6sgyv2tl.jpeg"
---

The interactivity and unpredictability of live streaming user generated content (UGC) platforms is a big part of why they are so popular. But, that unpredictability means that communities must be diligent in monitoring their content to make sure that it meets their community guidelines or acceptable use policy and is appropriate, safe, and welcoming for all users. This often results in a moderation system where users report potential offenses to the community guidelines and moderators or admins take action as necessary. This is often a manual process that leaves much to be desired. Artificial Intelligence (AI) and Machine Learning (ML) tools have improved in recent years, and developers can use these tools to assist in moderating their communities. In this post, we'll look at one way to do that with Amazon Interactive Video Service (Amazon IVS) and Amazon Rekognition.

## Solution Overview

Analyzing every frame of every live stream in an application with AI/ML would be a very expensive and difficult task. Instead, developers can analyze samples of the live streams in their applications on a specified frequency to assist their moderators by alerting them if there is content in need of further review by a human moderator. It isn't a 100% perfect solution, but it's one way to automate content moderation and help make moderators' jobs easier. 

This solution involves the following steps:

* Configure [auto recording of live streams to Amazon Simple Storage Service (Amazon S3)](https://dev.to/aws/auto-recording-amazon-ivs-live-streams-to-s3-m64) on your Amazon IVS Channels to save thumbnail images on a specified frequency
* Create an Amazon EventBridge rule that fires when a new object is created in the Amazon S3 bucket
* Create an AWS Lambda function that gets triggered by the EventBridge rule and uses Amazon Rekognition to detect content like nudity, violence or gambling that might need to be moderated by a human moderator
* Create an AWS Lambda function and expose it via Amazon API Gateway to provide a means to stop a live stream, if necessary
* Send a custom event to an [Amazon IVS chat room](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) containing the results of the analysis

## Creating the Amazon EventBridge Rule and AWS Lambda Functions

We'll use AWS Serverless Application Model (SAM) to make it easy to create the rule and functions. Here's the entire `template.yaml` file that describes the necessary permissions, the Amazon EventBridge rule, and the AWS Lambda layer (for the AWS SDK dependency) and the function definitions. We'll break this down below.

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: 'AWS::Serverless-2016-10-31'
Description: Amazon IVS Moderation Functions
Globals:
  Function:
    Runtime: nodejs18.x
    Timeout: 30
    MemorySize: 128
  Api:
    EndpointConfiguration: 
      Type: REGIONAL
    Cors:
      AllowMethods: "'GET, POST, OPTIONS'"
      AllowHeaders: "'Content-Type'"
      AllowOrigin: "'*'"
      MaxAge: "'600'"
Resources:
  IvsChatLambdaRefLayer:
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
      PolicyName: IVSModerationAccessPolicy
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - 's3:GetObject'
              - 's3:GetObjectAcl'
              - 'ivschat:SendEvent'
              - 'ivs:StopStream'
              - 'rekognition:DetectModerationLabels'
            Resource: '*'
      Roles:
        - Ref: ModerateImageRole
        - Ref: StopStreamRole
  ApiAccessPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: ApiAccessPolicy
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - 'sts:AssumeRole'
            Resource: '*'
      Roles:
        - Ref: ModerateImageRole
        - Ref: StopStreamRole
  EventRule:
    Type: AWS::Events::Rule
    Properties:
      Description: EventRule
      State: ENABLED
      EventPattern: 
        source:
          - aws.s3
        detail-type:
          - "Object Created"
        detail:
          bucket:
            name:
              - ivs-demo-channel-stream-archive
          object:
            key:
              - suffix: .jpg
      Targets:
        - Arn: !GetAtt ModerateImage.Arn
          Id: MyLambdaFunctionTarget
  PermissionForEventsToInvokeLambda:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ModerateImage
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt EventRule.Arn
  ModerateImage:
    Type: 'AWS::Serverless::Function'
    Properties:
      Environment:
        Variables:
          DEMO_CHAT_ARN: 'arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]'
          DEMO_CHANNEL_ARN: 'arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]'
      Handler: index.moderateImage
      Layers:
        - !Ref IvsChatLambdaRefLayer
      CodeUri: lambda/
  StopStream:
    Type: 'AWS::Serverless::Function'
    Properties:
      Environment:
        Variables:
          DEMO_CHAT_ARN: 'arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]'
          DEMO_CHANNEL_ARN: 'arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]'
      Handler: index.stopStream
      Layers:
        - !Ref IvsChatLambdaRefLayer
      CodeUri: lambda/
      Events:
        Api1:
          Type: Api
          Properties:
            Path: /stop-stream
            Method: POST
Outputs:
  ApiURL:
    Description: "API endpoint URL for Prod environment"
    Value: !Sub "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/"
```

There's a lot going on in that file, so let's break it down a bit. First, we create a layer to enable the inclusion of the AWS SDK for JavaScript (v3) in our function.

```yaml
IvsChatLambdaRefLayer:
  Type: AWS::Serverless::LayerVersion
  Properties:
    LayerName: sam-app-dependencies
    Description: Dependencies for sam app
    ContentUri: dependencies/
    CompatibleRuntimes:
      - nodejs18.x
    LicenseInfo: "MIT"
    RetentionPolicy: Retain
```

In the `dependencies/nodejs` directory, there is a `package.json` file that includes the modules that our function needs.

```json
{
  "dependencies": {
    "@aws-sdk/client-ivs": "^3.289.0",
    "@aws-sdk/client-ivschat": "^3.289.0",
    "@aws-sdk/client-rekognition": "^3.289.0"
  }
}
```

The next section, identified by the keys `IVSAccessPolicy` and `APIAccessPolicy` gives our serverless application the ability to access the necessary APIs (`s3:GetObject`,`s3:GetObjectAcl`, `ivschat:SendEvent`, `ivs:StopStream`, and `rekognition:DetectModerationLabels`) and expose the the stop stream method that we'll create below via Amazon API Gateway.

Next, we create the Amazon EventBridge rule. The `name` property under `bucket` should match the name of the Amazon S3 bucket that you configured in your recording configuration. Recording to Amazon S3 creates various files, including playlists and HLS media, so we can filter this rule to only fire for our thumbnails by setting the `key` under `object` to be `suffix: jpg`.

```yaml
EventRule:
  Type: AWS::Events::Rule
  Properties:
    Description: EventRule
    State: ENABLED
    EventPattern: 
      source:
        - aws.s3
      detail-type:
        - "Object Created"
      detail:
        bucket:
          name:
            - ivs-demo-channel-stream-archive
        object:
          key:
            - suffix: .jpg
    Targets:
      - Arn: !GetAtt ModerateImage.Arn
        Id: MyLambdaFunctionTarget
```

Next, we give the rule the necessary permissions to invoke the AWS Lambda function.

```yaml
PermissionForEventsToInvokeLambda:
  Type: AWS::Lambda::Permission
  Properties:
    FunctionName: !Ref ModerateImage
    Action: lambda:InvokeFunction
    Principal: events.amazonaws.com
    SourceArn: !GetAtt EventRule.Arn
```

Now we can define our function that will be invoked by the Amazon EventBridge rule.

```yaml
ModerateImage:
  Type: 'AWS::Serverless::Function'
  Properties:
    Environment:
      Variables:
        DEMO_CHAT_ARN: 'arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]'
        DEMO_CHANNEL_ARN: 'arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]'
    Handler: index.moderateImage
    Layers:
      - !Ref IvsChatLambdaRefLayer
    CodeUri: lambda/
```

>**Note:** I'm declaring the `DEMO_CHAT_ARN` and `DEMO_CHANNEL_ARN` as environment variables, but your application would likely derive the ARN values from the event passed into the function since you would likely use this functionality with more than just a single Amazon IVS channel.

Finally, we can define the function that will be used to stop a stream, if necessary.

```yaml
StopStream:
  Type: 'AWS::Serverless::Function'
  Properties:
    Environment:
      Variables:
        DEMO_CHAT_ARN: 'arn:aws:ivschat:us-east-1:[redacted]:room/[redacted]'
        DEMO_CHANNEL_ARN: 'arn:aws:ivs:us-east-1:[redacted]:channel/[redacted]'
    Handler: index.stopStream
    Layers:
      - !Ref IvsChatLambdaRefLayer
    CodeUri: lambda/
    Events:
      Api1:
        Type: Api
        Properties:
          Path: /stop-stream
          Method: POST
```

### Creating the AWS Lambda Functions

Now that we've described our infrastructure with AWS SAM, let's create the functions that we described. In `index.mjs`, we `import` the SDK classes, retrieve the **Arn** values from the environment variables that we passed in, and create instances of the clients needed for our functions.

```js
import { IvsClient, StopStreamCommand } from "@aws-sdk/client-ivs";
import { IvschatClient, SendEventCommand } from "@aws-sdk/client-ivschat";
import { RekognitionClient, DetectModerationLabelsCommand } from "@aws-sdk/client-rekognition";

const chatArn = process.env.DEMO_CHAT_ARN;
const channelArn = process.env.DEMO_CHANNEL_ARN;

const ivsClient = new IvsClient();
const ivsChatClient = new IvschatClient();
const rekognitionClient = new RekognitionClient();
```

The `moderateImage` function will receive the Amazon EventBridge event, extract the `bucket` and `key` from the event, and send a `DetectModerationLabelsCommand` via the `rekognitionClient` to detect any inappropriate or offensive content in images based on the categories [listed here](https://docs.aws.amazon.com/rekognition/latest/dg/moderation.html#moderation-api).

```js
export const moderateImage = async (event) => {
  console.log('moderateImage:', JSON.stringify(event, null, 2));
  const bucket = event.detail.bucket.name;
  const key = event.detail.object.key;

  const detectLabelsCommandInput = {
    Image: {
      S3Object: {
        Bucket: bucket,
        Name: key,
      }
    },
  };
  const detectLabelsRequest = new DetectModerationLabelsCommand(detectLabelsCommandInput);
  const detectLabelsResponse = await rekognitionClient.send(detectLabelsRequest);

  if (detectLabelsResponse.ModerationLabels) {
    sendEvent('STREAM_MODERATION', detectLabelsResponse.ModerationLabels);
  }
};
```

If necessary, the `moderateImage` function calls `sendEvent` to publish a custom event to any front end connected clients to a given Amazon IVS chat room. 

```js
const sendEvent = async (eventName, eventDetails) => {
  const sendEventInput = {
    roomIdentifier: chatArn,
    attributes: {
      streamModerationEvent: JSON.stringify(eventDetails),
    },
    eventName,
  };
  const sendEventRequest = new SendEventCommand(sendEventInput);
  await ivsChatClient.send(sendEventRequest);
};
```

Your front end can decide how to handle this event and the logic for publishing this event will depend on your business needs. Maybe you'd rather trigger a custom alarm in CloudWatch, send an email, or publish a notification via Amazon SNS? Every application's needs differ, but the moderation data is available at this point to do with it what you need.

The `stopStream` method uses the `ivsClient` to send a `StopStreamCommand`. Again, the implementation of this is up to you. You could even potentially fully automate this command if the Amazon Rekognition result matches a certain category or exceeds a confidence level.

```js
export const stopStream = async (event) => {
  console.log('stopStream:', JSON.stringify(event, null, 2));
  try {
    const stopStreamRequest = new StopStreamCommand({ channelArn });
    const stopStreamResponse = await ivsClient.send(stopStreamRequest);
    responseObject.body = JSON.stringify(stopStreamResponse);
  }
  catch (err) {
    responseObject.statusCode = err?.name === 'ChannelNotBroadcasting' ? 404 : 500;
    responseObject.body = JSON.stringify(err);
  }
  return responseObject;
};
``` 

## Demo

In my demo, I decided to listen for the custom events and display the results in a moderator view that shows the detected item and the confidence level. I also present the moderator with a 'Stop Stream' button that invokes the `stopStream` method via the exposed Amazon API Gateway.

![content moderation demo](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-09xlx7vjla1cck9ehqs6.png)

## Summary

In this post we learned how to use Amazon Rekognition to assist human moderators moderate the content in the applications that they build using Amazon IVS. If you'd like to learn more about how Amazon IVS can help create safer UGC communities, check out the following blog posts:

* [Moderating Amazon IVS Chat Messages with an AWS Lambda Function](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p
)
* [Manually Moderating Amazon IVS Chat Messages](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646) 