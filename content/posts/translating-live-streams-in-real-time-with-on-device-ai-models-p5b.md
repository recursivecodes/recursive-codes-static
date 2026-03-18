---
title: "Translating Live Streams in Real-Time with On-Device AI Models"
slug: "translating-live-streams-in-real-time-with-on-device-ai-models-p5b"
author: "Todd Sharp"
date: 2025-04-15T18:38:16Z
summary: "I've built demos of real-time transcription and translation in the past. But this? This is different...."
tags: ["aws", "amazonivs", "livestreaming", "ai"]
canonical_url: "https://dev.to/aws/translating-live-streams-in-real-time-with-on-device-ai-models-p5b"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-jb1fyh865x5n86xdb8wc.png"
imagecontain: true
---

I've built demos of real-time transcription and translation in the past. But this? This is _different_.

{{< youtube CtVPHCSJkhM >}}

## The Various Ways to Transcribe & Translate Live Video

Real-time transcription and translation is a tricky problem to solve. There are many different ways to approach the solution, each with their own pros and cons.

### Broadcaster Transcribe

With this approach, the speech is converted to text on the broadcaster's side. This can be either via a remote cloud/managed service or on-device. The on-device approach is the most performant, but choosing the right tool requires consideration of quality/accuracy versus performance. The benefit of transcribing on the broadcaster side is that it can be cost effective compared to server-based solutions, but can introduce latency (when using a cloud/managed service) or put additional CPU/GPU strain on the broadcaster's machine. If combined with viewer-side translate, this approach allows each viewer to choose their own target language (which is a great thing), but depending on the approach to viewer side translation, even more latency and/or CPU/GPU/Bandwidth utilization could be necessary.

### Server-Transcribe

Server side transcribing can eliminate the RAM, CPU, GPU and bandwidth requirements to perform this task on the broadcaster or viewer side, but requires additional cloud-based server resources which can quickly end up costing a lot of money.

### Viewer Transcribe

Of course, you could push the entire burden to the viewer and transcribe/translate the incoming audio when it's received. But, this approach can get ugly fast. At this point, it's difficult to differentiate between speakers if they're combined into a single audio feed. Additionally, the burden of both transcribing and translating on the viewer side can quickly overwhelm all but higher-end machines with a great internet connections. And that's if it is done locally - if you add in the dependency on a cloud or managed service and now you're looking at at least an additional second of delay (if not more).

Certainly, there must be a "holy grail" of transcription and translation?

## The Holy Grail 🏆

The way I see it, the ultimate solution is having each broadcaster transcribe on-device and publishing the transcription to each viewer. Once the transcription is received by the viewer, it can then be translated (again, on-device) into the viewer's desired target language (if necessary). This is the way.

## Real-Time On-Device Translation

> 🐉 **Here be dragons!**

Let's take a look at how to enhance the real-time transcription that we created in the last post to translate it in real time. Here's how we received the transcript as SEI data on our real-time stream.

```js
this.stage.on(StageEvents.STAGE_STREAM_SEI_MESSAGE_RECEIVED, (participant, seiMessage) => {
  const msgString = new TextDecoder().decode(seiMessage.payload);
  const message = JSON.parse(msgString);
  // store the latest transcript by participant id
  transcriptions[message.participantId] = message.transcript;

  // translate it...
  aiTranslate(message.participantId, message.transcript);

  // render to UI...
});
```

For the on-device AI translation, we'll use built-in AI translation in Chrome.

> ⚠️ **Note:** This method uses an early preview of on-device AI for translation which is currently in origin trial. See [this doc](https://developer.chrome.com/docs/ai/translator-api) for further information. Also, since I wrote this post the Chrome Canary version of the API has changed from `window.ai.translator` to `Translator` (see [this doc](https://github.com/webmachinelearning/translation-api)). Things are changing rapidly in this space.

Let's take a look at the `aiTranslate()` function.

```js
async aiTranslate(participantId, txt) {
  if ('ai' in window && 'translator' in window.ai) {
    const srcLang = 'en';
    const targetLang = 'de';
    const capabilities = await window.ai.translator.capabilities();
    const available = capabilities.languagePairAvailable(srcLang, targetLang);

    if (available !== 'no') {
      if (!this.aiTranslator) {
        this.aiTranslator = await window.ai.translator.create({
          sourceLanguage: srcLang,
          targetLanguage: targetLang,
          monitor(m) {
            console.log(`Downloading language pack '${srcLang}'...`);
            m.addEventListener('downloadprogress', (e) => {
              console.log(`Downloaded ${e.loaded} of ${e.total} bytes.`);
            });
          },
        });
      }
      else {
        this.translations[participantId] = await this.aiTranslator.translate(txt);
      }
    }
    else {
      console.warn(`Unable to translate from ${srcLang} to ${targetLang}`);
    }
  }
}
```

The translate function checks to see if the browser supports AI translation, and if it can translate between the `src` and `target` languages. If so, it creates a translator instance. If the current model is not available, it downloads it at this time (and caches it for further use). Once the translator instance is ready to go, the transcript is translated and can be rendered to the viewer.

The nice thing about using language pair models is that it reduces the overall model size since the model does not need to contain every possible language combination. This means the language model download is faster. Of course this means that the very first time a viewer tries to translate a real-time stream, they'll have to wait a short period of time to download the model, but this is a one time operation.

## Summary

Real-time translation of live streams is "the future", and the future is closer than any of us could have imagined. On-device models provide the best performance and reduce costs down by limiting network calls and third-party dependencies. This solution might not be production ready today - but as on-device models get more popular and all browsers begin adopting and implementing these new specs, real-time translation will become a reality sooner than later.
