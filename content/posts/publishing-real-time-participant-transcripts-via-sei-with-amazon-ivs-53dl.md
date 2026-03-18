---
title: "Publishing Real-Time Participant Transcripts via SEI with Amazon IVS"
slug: "publishing-real-time-participant-transcripts-via-sei-with-amazon-ivs-53dl"
author: "Todd Sharp"
date: 2025-03-24T14:30:22Z
summary: "Last time, we learned about Supplemental Enhancement Information (SEI) which provides a way to add..."
tags: ["aws", "amazonivs", "livestreaming"]
canonical_url: "https://dev.to/aws/publishing-real-time-participant-transcripts-via-sei-with-amazon-ivs-53dl"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-g7g1cuwqdu1z4315gqvz.png"
imagecontain: true
---

Last time, we learned about [Supplemental Enhancement Information (SEI)](https://dev.to/aws/intro-to-supplemental-enhancement-information-sei-with-amazon-ivs-3jn2) which provides a way to add frame aligned metadata to real-time streaming applications built with Amazon Interactive Video Service (Amazon IVS). Today, we'll look at a much more practical use case for SEI - publishing a transcript of each participant's audio. This transcript can be used to render caption overlays on the viewer's side for the hearing impaired, or stitched together to provide a complete transcript of the conversation that can be used with Generative AI for summarization, content discovery and more. Publishing speaker transcripts also give us the ability to provide real-time translations for viewers. We'll dig into the topic of translation in the next post, so for now let's see how to use SEI to publish transcriptions.

> ⚠️ Note: The usage of SEI to publish transcriptions as demonstrated in this blog post does not result in proper WebVTT or CEA-708/EIA-608 captions.

If you think about the concept of SEI that we talked about in the last post, publishing a transcript is truly the perfect use case for it. It's typically going to be a fairly small payload that will fit within the constraints of SEI, and it's time-bound. Each participant can publish their own transcript, and the application can receive each transcript and handle them as necessary.

## The "Right" Way to Transcribe

There really isn't one. There are a handful of approaches, but we've not yet arrived at the utopian future that includes a speech-to-text engine that works in every browser, on every device, without third-party dependencies, and with great accuracy and performance. Will we ever get that? Who knows. But until then, we do have a lot of really good options at our disposal.

## The "Easiest" Way to Transcribe

Since there's no "right" way to transcribe, I'll pick the next best option - the "easiest". And honestly, it couldn't be easier than using the `SpeechReconition` [interface](https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition) of the [Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API). It's not ideal, since it doesn't work in every browser, but it's a great way to demo real-time transcription. If you've got a better approach to speech-to-text that works in your application, feel free to plug that in!

## Another Way to Transcribe

Each application has different requirements. The approach we're looking at in this post transcribes the audio on the broadcaster side, but you may want to handle the transcription on the client/viewer side instead. If that sounds like something that fits your needs, check out the experimental [Amazon IVS WebGPU Captions Demo](https://github.com/aws-samples/amazon-ivs-webgpu-captions-demo) on GitHub.

## Using The Speech Recognition API

To get our participant's speech converted to a text that can be published as a transcript using SEI, we construct an instance of the `SpeechRecognition` interface. Note that some browsers use a vendor prefix, so to make things easier we just normalize the name.

```js
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

const speechRecognition = new SpeechRecognition();
speechRecognition.continuous = true; //keep listening, or just a one-time shot? obviously we want continuous
speechRecognition.lang = 'en-US'; // or a variable/selection
speechRecognition.interimResults = true; // return results that aren't "final"
speechRecognition.maxAlternatives = 1;
speechRecognition.start();

speechRecognition.onresult = (event) => {
  const transcript = event.results[event.resultIndex][0].transcript;
  publishMessage({ transcript, participantId, username });
  renderTranscript(transcript participantId); // implementation not shown
};
```

We're not showing the `renderTranscript()` implementation here since the implementation will vary based on your application. Just remember that participants **don't receive the messages that they publish themselves**. So, if you want the user to view their own transcript, you'll need to also render it to them. I like to do this at the same time the transcript is published.

Assuming we've set up publishing and subscribing the same way that we did in the previous post, the `publishMessage` method just inserts the SEI message on the user's `LocalStageStream`.

```js
publishMessage(message) {
  const msgString = JSON.stringify(message);
  const payload = new TextEncoder().encode(msgString).buffer;
  localVideoStream.insertSeiMessage(payload);
},
```

In our SEI event handler, we render the participant's transcript as it is received.

```js
this.stage.on(StageEvents.STAGE_STREAM_SEI_MESSAGE_RECEIVED, (participant, seiMessage) => {
  const msgString = new TextDecoder().decode(seiMessage.payload);
  const message = JSON.parse(msgString);
  // store the latest transcript by participant id
  transcriptions[message.participantId] = message.transcript;

  // render the transcript
  renderTranscript(message.transcript, message.participantId);

  // clear out any timeout that may exist for this participant
  clearTimeout(transcriptionTimers[message.participantId]);

  // create a timeout that clears the transcript after 5 seconds
  // which will reset the UI when the person is no longer speaking
  let self = this;
  transcriptionTimers[message.participantId] = setTimeout(() => {
    self.transcriptions[message.participantId] = "";
    hideTranscript(message.participantId);
  }, 5000);
});
```

The end result looks like this. On the left hand side, the user's speech is transcribed and rendered in an overlay on top of their video. On the right, the viewer receives the transcript nearly instantaneously.

{{< youtube QrBPoQwhyE4 >}}

## Summary

In this post, we looked at a great use case for our little envelopes – real-time transcription. I hope you've enjoyed learning about Supplemental Enhancement Information (SEI) and are inspired to use it in your next real-time streaming application.

## Bonus

If you're interested in an approach to real-time translation of our near instantaneous transcription, check out my next post (coming soon) see how we can build on this transcription demo using on-device AI models.
