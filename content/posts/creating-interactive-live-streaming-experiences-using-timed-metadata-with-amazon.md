---
title: "Creating Interactive Live Streaming Experiences Using Timed Metadata with Amazon IVS"
slug: "creating-interactive-live-streaming-experiences-using-timed-metadata-with-amazon-ivs-2kp6"
author: "Todd Sharp"
date: 2022-09-07T11:44:19Z
summary: "So far in this blog series, we've created our first live streaming channel, learned how to create a..."
tags: ["aws", "cloud", "amazonivs", "livestreaming"]
canonical_url: "https://dev.to/aws/creating-interactive-live-streaming-experiences-using-timed-metadata-with-amazon-ivs-2kp6"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gidcfe8pck3sr6hgw6ix.jpeg"
---

So far in this blog series, we've created our first live streaming channel, learned how to create a playback experience in the browser, and enhanced that experience with the Amazon Interactive Video Service (Amazon IVS) player SDK. In the next few posts, we're going to look at adding some interactivity to our playback experience. 

Live streaming is clearly popular, but it's more than just the video that appeals to viewers. Interacting with the broadcaster and other viewers is a major reason so many people keep coming back to certain streams and streamers. Amazon IVS gives us a few pretty amazing features that enable interactivity, and one of the cooler elements that we can use to enhance our live stream is **timed metadata** (obligatory "[official doc link](https://docs.aws.amazon.com/ivs/latest/userguide/metadata.html)").

## Timed Metadata? 

Timed metadata is a way to embed information in your live stream at a specific point in time. The metadata that you publish becomes a part of the video stream itself since it uses ID3 tags embedded directly into the video segments. That means they are available in later on if we record our live streams.

> ID3 tags? Ever wonder how your music player knows the artist, song title, album and more about the song it’s playing? Audio files contain a small chunk of data that contains this information. Audio players read this data and display it!

## What Is It Good For?

All kinds of stuff! Using timed metadata, we can create an interactive experience for our viewers outside of the video player. Imagine a game show live stream that can render questions in the browser when the host asks them. Think about a live shopping experience that updates the page with product images, reviews, pricing information, or discount codes as the presenter is demoing the product. What about updating leaderboards, box scores, detailed stats during a live streamed sporting (or e-sports) event? Picture a live streamed bike race that broadcasts the rider’s GPS location with the stream and display it in real time on a map. There are so many use cases, and I’m sure you’ve already thought of a few for your own applications. Enough talk, let’s build something!

## Listening For Timed Metadata

Let's head back once again to the Amazon IVS [test streams](https://github.com/aws-samples/amazon-ivs-player-web-sample#test-streams) page. Notice that there is a test stream listed here that contains timed metadata. Nice! We'll plug this into our Amazon IVS player example that we've been working with and build upon it. Here's how that looks:

```html
<video id="video-player" controls autoplay playsinline></video>
```

```js
const videoEl = document.getElementById('video-player');
const streamUrl = 'https://fcc3ddae59ed.us-west-2.playback.live-video.net/api/video/v1/us-west-2.893648527354.channel.xhP3ExfcX8ON.m3u8';
const ivsPlayer = IVSPlayer.create();
ivsPlayer.attachHTMLVideoElement(videoEl);
ivsPlayer.load(streamUrl);
ivsPlayer.play();
```

This stream is an example of a “live trivia” stream where the host reads a few trivia questions. A timed metadata event is embedded at the exact point in time that the host reads a trivia question. We can listen for, and respond to this event. If you remember from our last post, we can use `addEventListener()` on the Amazon IVS player to listen for various events, and `TEXT_METADATA_CUE` ([docs](https://aws.github.io/amazon-ivs-player-docs/1.11.0/web/index.html#playereventtype.text_metadata_cue)) is one of those events. 

```js
ivsPlayer.addEventListener(IVSPlayer.PlayerEventType.TEXT_METADATA_CUE, (e) => {
    console.log(e);
});
```

If we play our stream, we can check the console after the host reads a question and observe the logged event. It should look similar to this:

```json
{
    "startTime": 61.04233333333333,
    "endTime": 61.04233333333333,
    "type": "TextMetadataCue",
    "description": "",
    "text": "{\"question\": \"From what language does the term R.S.V.P. originate from?\",\"answers\": [ \"Russian\", \"Italian\", \"French\", \"Portuguese\" ],\"correctIndex\": 2}",
    "owner": "metadata.live-video.net"
}
```

The `startTime` key represents the time since the stream started the event took place (61 seconds in the example above). The interesting bit we're after here is the `text` key, which contains the metadata. Here, it's a JSON string, but it can be whatever you need it to be. 

>The only limitation on timed metadata is that the payload must be less than 1kb. 

That might sound small, but metadata isn't intended to deliver large payloads. We can perform additional steps on the client side if necessary. For example, we could pass a question ID in the example above instead of passing the question, answers, and correct answer and fetch the rest of the information from client memory or a remote API call.

But since we've got the entire trivia payload, let's parse the metadata.

```js
const metadata = JSON.parse(e.text);
```

The parsed metadata structure uses the following structure:

```json
{
    "question": "From what language does the term R.S.V.P. originate from?",
    "answers": [
        "Russian",
        "Italian",
        "French",
        "Portuguese"
    ],
    "correctIndex": 2
}
```

## Rendering the Question and Answers

So we've got the questions, answers, and the index of the correct answer. Certainly our viewers would be really honest and never poke around in the browser's developer tools to view the correct answer, so we'll proceed with our trivia app on the honor system. Let's render the question and answers. First, we'll add some HTML markup (styled with Bootstrap) below the video player.

```html
<div class="card mt-3">
    
    <div class="card-header bg-dark text-white">
        <h4>Question</h4>
    </div>

    <div class="card-body">
    
        <div class="card-title">
            <h4 id="question"></h4>
        </div>

        <div id="answerContainer">
            <ul id="answers" class="list-group"></ul>
        </div>

    </div>

    <div class="card-footer text-center">
        <button class="btn btn-dark" id="check-answer-btn" disabled>Submit</button>
    </div>

</div>
```

So we've got a container for our question, and the answers. We've also added a button to check the answer that is initially `disabled`. Let's add some code inside of our event handler to store the correct answer in the global scope so that we can check the user's answer later on.

```js
window.correctIndex = metadata.correctIndex;
```

Now we can enable the submit button, display the question, and clear out the answer container.

```js
// enable the submit button
document.getElementById('check-answer-btn').removeAttribute('disabled');

// display the question
document.getElementById('question').innerHTML = metadata.question;

// clear previous answers
const answersEl = document.getElementById('answers');
answersEl.replaceChildren();
```

Now we can loop over all the answers in the metadata object and render them to the page.

```js
// render the answers for this question
metadata.answers.forEach((a, i) => {
    // create an answer container
    const answerEl = document.createElement('li');
    answerEl.classList.add('list-group-item');

    // radio button to select the answer
    const answerRadio = document.createElement('input');
    answerRadio.setAttribute('name', 'answer-input');
    answerRadio.type = 'radio';
    answerRadio.id = `answer-input-${i}`;
    answerRadio.classList.add('me-2', 'form-check-input');
    answerRadio.dataset.index = i;
    answerEl.appendChild(answerRadio);

    // label to display the answer text
    const answerLbl = document.createElement('label');
    answerLbl.setAttribute('for', `answer-input-${i}`);
    answerLbl.innerHTML = a;
    answerEl.appendChild(answerLbl);

    answersEl.appendChild(answerEl);
});
```

## Checking for the Correct Answer

Now our application will display the question and answers on the page. We'll need a function that can check whether the user's answer is correct that will provide user feedback, so let's create that now.

```js
const checkAnswer = () => {
    // disable the submit btn
    document.getElementById('check-answer-btn').setAttribute('disabled', 'disabled');

    // check the current answer
    const selectedAnswer = document.querySelector('input[name="answer-input"]:checked');
    const selectedIdx = parseInt(selectedAnswer.dataset.index);

    // highlight the correct answer
    document.querySelector(`input[data-index="${window.correctIndex}"]`).nextSibling.classList.add('text-success');

    // if they're wrong, highlight the incorrect answer
    if (selectedIdx !== window.correctIndex) {
        selectedAnswer.nextSibling.classList.add('text-danger');
    }
}
```

Don't forget to attach an event listener for the `click` event on our **Submit** button. We'll add that in our `init()` function.

```js
document.getElementById('check-answer-btn').addEventListener('click', checkAnswer);
```

And we're ready to see it in action! If you're playing along at home, check your code against the code in the demo below. If not, check it out anyway to see the final solution. Give it a shot and see how many questions you can get right! Note, you may have to scroll down in the demo below to see the question.

{% codepen https://codepen.io/recursivecodes/pen/JjLLKWz %}

## Producing Timed Metadata

We've looked at how to consume metadata, but we've not yet seen how to produce it. No worries - it's not that hard to do! There are several ways to produce timed metadata, and all of them require the **Channel ARN**. You can get this value from the Amazon IVS Management Console in the channel details, or via the AWS CLI.

```bash
$ aws \
    ivs \
    list-channels \
    --filter-by-name [YOUR CHANNEL NAME] \
    --query "channels[0].arn" \
    --output text
```

> **Need to Install the CLI?** Check out the [install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

### With the AWS CLI

One way to produce timed metadata is to use the AWS CLI. I don't know if this is a method that you'd use very often, but for testing and debugging purposes, it's good to know how to do it. 

```bash
$ aws \
    ivs \
    put-metadata \
    --channel-arn [YOUR CHANNEL ARN] \
    --metadata '{"test": true}'
```

[AWS CLI Docs](https://docs.aws.amazon.com/cli/latest/reference/ivs/put-metadata.html).

### With the Amazon IVS SDK

#### Node SDK

```js
import AWS from 'aws-sdk';
const Ivs = new AWS.IVS({ region: 'us-east-1', credentials });

const putMetadata = async (metadata) => {
    const input = {
        channelArn: '[YOUR CHANNEL ARN]',
        metadata: JSON.stringify(metadata)
    };
    let output;
    try {
        output = await Ivs.putMetadata(input).promise();
    }
    catch (e) {
        console.error(e);
        if (e.name === 'ChannelNotBroadcasting') {
            output = { offline: true };
        }
        else {
            throw new Error(e);
        }
    }
    return output;
}
```

[Node SDK docs](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ivs/classes/putmetadatacommand.html).

#### Python SDK

```python
import boto3
client = boto3.client('ivs')

response = client.put_metadata(
    channelArn='[YOUR CHANNEL ARN]',
    metadata='{"python": true}'
)
print(response)
```

[Python SDK Docs](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ivs.html?highlight=ivs#IVS.Client.put_metadata).

#### Other Languages

Check the [SDK specific documentation](https://aws.amazon.com/developer/tools/) for the syntax to publish metadata events in your favorite language.

## Summary

Timed metadata is infinitely cool and has many applications to make our live stream engaging and interactive. In our next post, we’re going to look at another way we can add interactivity to our live streams - Amazon IVS Chat! If you have questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by [Reto Scheiwiller](https://pixabay.com/users/xresch-7410129/) from [Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=image&amp;utm_content=3088958)