---
title: "Creating an Interactive Whiteboard with Amazon IVS Chat"
slug: "creating-an-interactive-whiteboard-with-amazon-ivs-chat-5fp"
author: "Todd Sharp"
date: 2022-11-04T13:10:24Z
summary: "In my last few posts, we've been taking an extended look at moderating Amazon Interactive Video..."
tags: ["aws", "amazonivs", "javascript", "chat"]
canonical_url: "https://dev.to/aws/creating-an-interactive-whiteboard-with-amazon-ivs-chat-5fp"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zpj194olhuk22ox1hceu.jpg"
---

In my last few posts, we've been taking an extended look at moderating Amazon Interactive Video Service (Amazon IVS) chat rooms. Two weeks ago we learned how to perform [automated chat moderation with AWS Lambda functions](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p), and last week we saw how to [manually moderate chat rooms](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646). In this post, I'd like to switch gears and talk about an interesting use case for Amazon IVS chat rooms - live, interactive whiteboards. 

Live streaming is mostly known for entertainment related streams like gaming or sports, but it is a perfect tool for delivering educational content too. I've blogged before about [screen sharing and overlaying canvas elements](https://dev.to/aws/enhancing-your-amazon-ivs-web-broadcast-with-screen-sharing-and-canvas-overlays-4dnd) on a stream, but whiteboarding is a unique way to provide a broadcaster and the viewers a live, interactive way to visualize and even collaborate on a given topic. The demo in this post is very basic - just a "pen" tool for freehand drawing - but it has the potential to be expanded for shapes and images, making it the perfect starting point for creating your own whiteboard experience to enhance your Amazon IVS live streams.

## Try it Out!

Before we get into how to build the whiteboard, check out how it works below. You'll need to generate a chat token for an existing Amazon IVS chat room for two unique users and enter the the tokens and respective `user-id` values in the two CodePen embeds. In production, you'd use one of the AWS SDKs to generate your tokens, but for this demo, you can generate them with the AWS CLI to see how it works (see [this post](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6) for more information).

```bash
$ aws ivschat create-chat-token \
  —room-identifier [CHAT ARN] \
  —user-id "1" \
  —capabilities "SEND_MESSAGE" \
  —query "token" \
  —output text 
```

Using the CLI command above, generate and enter the token for user "1" and enter that `user-id` in the first CodePen. Then, repeat the process for user "2" in the second CodePen below. If your chat room was not created in `us-east-1`, update the `Endpoint` value to match your chat room's region. Once both users are connected, you can draw on one canvas and observe the drawing on the other canvas.

{% codepen https://codepen.io/recursivecodes/pen/gOzVLyN %}

{% codepen https://codepen.io/recursivecodes/pen/gOzVLyN %}

If you don't have any Amazon IVS chat rooms to test things out with - WHY NOT?? Just kidding, of course. Here's a gif showing it in action where you can see my amazing art skills on display:

![Amazon IVS Whiteboard Demo](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-8roy1b2dk6pnltw6utwn.gif)

## Setting Things Up

For this demo, I'm collecting the user id, pen color, chat token, and chat endpoint via a `<form>`. In production, you'll have a dedicated user id, and your chat token and endpoint will come from a call to a server (or serverless function). It's important to track the user id to prevent the drawing from being replicated on the `<canvas>` of the user who is currently drawing. Here is the HTML markup for the collection form and the drawing canvas. I've removed the Bootstrap classes used in the CodePen to make the code easier to read here.

```html
<div id="settings">
  <div>Settings</div>
  <div>
    <div>
      <label for="chat-userid">Chat UserId</label>
      <div>
        <input type="text" id="chat-userid" required />
      </div>
    </div>
    <div>
      <label for="pen-color">Pen Color</label>
      <div>
        <input type="color" id="pen-color" required />
      </div>
    </div>
    <div>
      <label for="chat-token">Chat Token</label>
      <div>
        <input type="text" id="chat-token" required />
      </div>
    </div>
    <div>
      <label for="chat-endpoint">Endpoint</label>
      <div>
        <input type="text" id="chat-endpoint" required />
      </div>
    </div>
    <div>
      <div>
        <button type="button" id="submit-settings">Submit</button>
      </div>
    </div>
  </div>
</div>
<div id="whiteboard-container">
  <canvas id="whiteboard">
    Sorry, your browser does not support HTML5 canvas technology.
  </canvas>
</div>
```

Next, I've added a `DOMContentLoaded` listener to set a random pen color and listen for the **Submit** button click.

```js
document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('pen-color').value = `#${Math.floor(Math.random()*16777215).toString(16)}`;
  document.getElementById('submit-settings').addEventListener('click', () => {
    init();
  })
});
```

In the `init()` function, I set some global values for the information that we'll need later on to initialize the chat connection. In your application, you'll most likely be working with a modern JS framework and therefore would avoid using global variables like this.

```js
const init = () => {
  window.chatEndpoint = document.getElementById('chat-endpoint').value;
  window.userId = document.getElementById('chat-userid').value;
  window.chatToken = document.getElementById('chat-token').value;
  window.penColor = document.getElementById('pen-color').value;
  if (!window.chatEndpoint || !window.chatToken || !window.userId) {
    alert('Chat Endpoint, Token and UserId are required!');
    return;
  }
  document.getElementById('settings').classList.add('d-none');
  
  // init chat connection
}
```

## Initializing a Chat Connection

Now that we have the `userId`, `chatToken`, and `chatEndpoint`, we can initialize our WebSocket connection to the Amazon IVS chat room by adding it to the `init()` function:

```js
window.connection = new WebSocket(window.chatEndpoint, window.chatToken);
window.connection.addEventListener('message', (e) => {
  // todo: handle message
});
```

We'll populate the message handler in just a bit. For now, let's look at how to draw on the canvas.

## Drawing on the Canvas

Before we can draw on the canvas, we'll add a bit of configuration to the canvas element to the `init()` function.

```js
const whiteboardContainer = document.getElementById('whiteboard-container');
const canvasEl = document.getElementById('whiteboard');
canvasEl.width = whiteboardContainer.offsetWidth;
canvasEl.height = whiteboardContainer.offsetHeight;
const ctx = canvasEl.getContext('2d');
ctx.lineWidth = 5;
ctx.fillStyle = '#fff';
ctx.fillRect(0, 0, canvasEl.width, canvasEl.height);
```

The snippet above sets the width and height of the `<canvas>` and sets the default background color.

### Handling Mouse Events

We'll add three listeners to our `<canvas>` element: `mousedown`, `mousemove`, and `mouseup`. The handlers for these events will need to do two things: handle drawing on the current user's canvas, and publish an event via the WebSocket connection to other users so that the drawing can be replicated on all connected clients.

> Consider using pointer events instead of mouse events (`pointerdown`, `pointermove`, and `pointerup`) to make your whiteboard respond to both touch and mouse events.

```js
canvasEl.addEventListener('mousedown', (e) => {
  window.isDrawing = true;
  const evt = { x: e.offsetX, y: e.offsetY, type: 'mousedown' };
  onMouseDown(evt);
  // queue event for publishing
});
canvasEl.addEventListener('mousemove', (e) => {
  if (window.isDrawing) {
    const evt = { x: e.offsetX, y: e.offsetY, type: 'mousemove' };
    // queue event for publishing
    onMouseMove(evt);
  }
});
canvasEl.addEventListener('mouseup', (e) => {
  window.isDrawing = false;
  onMouseUp({});
  // queue event for publishing
});
```

Now let's look at each of the functions that perform the actual canvas drawing. First, `onMouseDown()` which gets the `2d` context for the canvas, begins a path, and moves to the proper `x` and `y` coordinates. 

```js
const onMouseDown = (e) => {
  const canvasEl = document.getElementById('whiteboard');
  const ctx = canvasEl.getContext('2d');
  ctx.beginPath();
  const x = e.x;
  const y = e.y;
  ctx.moveTo(x, y);
};
```

Next, `onMouseMove()`, which draws a line to the current `x` and `y`. Because we set a global variable `isDrawing` to `true` before calling `onMouseDown()`, this method will be called continuously until the `mouseup` event sets the `isDrawing` flag back to false. This means that `onMouseMove()` will draw a line until we release the mouse button.

```js
const onMouseMove = (e, color) => {
  const canvasEl = document.getElementById('whiteboard');
  const ctx = canvasEl.getContext('2d');
  const x = e.x;
  const y = e.y;
  ctx.lineTo(x, y);
  ctx.strokeStyle = color || window.penColor;
  ctx.stroke();
};
```

Finally, `onMouseUp()` closes the path that we started in `onMouseUp()`.

```js
const onMouseUp = (e) => {
  const canvasEl = document.getElementById('whiteboard');
  const ctx = canvasEl.getContext('2d');
  ctx.closePath();
}
```

At this point, each connected user can draw on their local `<canvas>`, but none of the other connected users will be able to see what they have drawn. For this, we need to publish the events via the WebSocket connection.

## Publishing Drawing Events

There is no guarantee for how often a mouse event will get fired, but most browsers will fire `mousemove` **quite often**. If we look at the [service quotas for Amazon IVS chat](https://docs.aws.amazon.com/ivs/latest/userguide/service-quotas.html#quotas-call-rate-ivs-chat), we can see that we're limited to 10 transactions per second. It would be pretty easy to hit quota limits if we tried to publish every single `mousemove` event for all connected chat users. To workaround this, we can do do two things: send events in a batch, and only publish a sample of the `mousemove` events to other connected clients.

### Queuing Mouse Events

Let's start by looking at how we can batch the events. First, we'll set up a few global variables to manage a queue of events.

```js
window.queue = [];
window.maxQueueSize = 20;
```

Next, we'll create a `handleQueue()` method to build up a batch of events. When the batch size is greater than our configured `window.maxQueueSize` (or when a `mouseup` event is received), we'll send the current batch.

```js
const handleQueue = (event) => {
  if (window.queue.length <= window.maxQueueSize) {
    window.queue.push(event);
  }
  if (window.queue.length === window.maxQueueSize || event.type == 'mouseup') {
    sendEvents();
  }
};
```

### Publishing Mouse Events

The `sendEvents()` method builds a payload containing a JSON serialized version of the event queue and sends it just like we would normally post a chat message to a chat room with `SEND_MESSAGE`. Notice the `Attribute` object contains a `type` of `whiteboard` which we can use to differentiate whiteboard messages from normal chat messages in the `message` handler (we'll look at that handler below).

```js
const sendEvents = () => {
  const payload = {
    'Action': 'SEND_MESSAGE',
    'Content': '[whiteboard event]',
    'Attributes': {
      'type': 'whiteboard',
      'color': window.penColor,
      'events': JSON.stringify(window.queue),
    }
  }
  try {
    window.connection.send(JSON.stringify(payload));
    window.queue = [];
  }
  catch (e) {
    console.error(e);
  }
}
```

Now we can modify the `mouse` event handlers to call `handleQueue()`.

```js
canvasEl.addEventListener('mousedown', (e) => {
  window.isDrawing = true;
  const evt = { x: e.offsetX, y: e.offsetY, type: 'mousedown' };
  onMouseDown(evt);
  handleQueue(evt);
});
canvasEl.addEventListener('mousemove', (e) => {
  if (window.isDrawing) {
    const evt = { x: e.offsetX, y: e.offsetY, type: 'mousemove' };  
  handleQueue(evt);
  onMouseMove(evt);
  }
});
canvasEl.addEventListener('mouseup', (e) => {
  window.isDrawing = false;
  onMouseUp({});
  handleQueue(evt);
});
```

#### Sampling Mouse Move Events

If we were to run this application at this point, we'd probably quickly hit our service quota even though we're sending the events in batches. As mentioned above, we can sample the `mousemove` event to prevent this. We'll add a `throttle()` method and limit our call to `handleQueue()` in the `mousemove` handler to being called every 50-100ms. In my tests, I found this to be an acceptable range that both prevents hitting the service quota and provides a reasonably good recreation of the event sequence on the other client's `<canvas>`.

```js
window.throttlePause;

const throttle = (callback, time) => {
  if (window.throttlePause) return;
  window.throttlePause = true;
  setTimeout(() => {
    callback();
    window.throttlePause = false;
  }, time);
};
```

The only thing left to do to implement this sampling is to modify the `mousemove` handler to only queue the event every 50ms.

```js
canvasEl.addEventListener('mousemove', (e) => {
  if (window.isDrawing) {
    const evt = { x: e.offsetX, y: e.offsetY, type: 'mousemove' };
    throttle(() => {
      handleQueue(evt);
    }, 50);
    onMouseMove(evt);
  }
});
```

### Handling Incoming Mouse Events

Now that we have implemented the local drawing, and the logic to queue and publish events, we just need to add our `message` handler for the WebSocket connection to handle the published events and recreate the drawings from other connected clients. Back inside of our `init()` function, right after we create the `WebSocket` connection, add the following:

```js
window.connection.addEventListener('message', (e) => {
  const data = JSON.parse(e.data);
  const msgType = data.Attributes.type;
  
  if(msgType == 'whiteboard') {
    const events = JSON.parse(data.Attributes.events);
    const color = data.Attributes.color;
    const eventUserId = data.Sender.UserId;
    events.forEach(e => {
      const type = e.type;
      if(eventUserId != window.userId) {
        switch(type){
          case 'mousedown':
            onMouseDown({x: e.x, y: e.y});
            break;
          case 'mousemove':
            onMouseMove({x: e.x, y: e.y}, color);
            break;
          case 'mouseup':
            onMouseUp({});
            break;
        };  
      }      
    });  
  }
  
  // otherwise, handle as an incoming chat...
});
```

In the handler above, we first check the `Attributes` object for the `type` key that we used when publishing the messages to differentiate these events from "normal" chat messages. If that `type` is `whiteboard`, we parse the `events` JSON string which contains an array of events and loop over the array. Within the loop, we check to make sure the `eventUserId` - the person publishing the event - is not the current `userId`. If not, we recreate the drawing operation on the local `<canvas>` by calling the appropriate function. 

## Potential Improvements

In a production application, a whiteboard might need additional features like shapes, images, and text. To add such features, your application can utilize the same architecture that we have seen in the demo above. 

### Improving Performance

Since this demo uses JSON to publish events, the payload that we are publishing is larger than it has to be. To improve on the number of events that could be published in a single message, your application can publish events in a delimited text format and use identifiers for the events. For example, instead of a JSON array like this that publishes a payload of 94 bytes:

```json
[
  {
    "x": 100,
    "y": 100,
    "type": "mousedown"
  },
  {
    "x": 100,
    "y": 100,
    "type": "mousemove"
  },
  {
    "type": "mouseup"
  }
]
```

You could instead format the data like this:

```js
0,100,100|1,100,100,#ff9911|2
```

Here we have delimited each event with a pipe (`|`) and the data within each event by a comma. The first character of the event (`0`, `1`, `2`) represents the event type (`0` for a `mousedown`, `1` for `mousemove`, and `2` for `mouseup`). The second and third characters are the `x` and `y` positions respectively. The fourth character, only necessary for `mousemove` events, is the pen color. This format results in a payload of 31 bytes - a 67% decrease in size. 

You could then handle this new payload format with this:

```js
payload = '0,100,100|1,100,100,#ff9911|2';
events = payload.split('|');
events.forEach((e) => {
  let type = e[0];
  let x = e[1];
  let y = e[2];
  let color = e[3];
  switch(type){
    case 0:
      onMouseDown({x, y});
      break;
    case 1:
      onMouseMove({x,y}, color);
      break;
    case 2:
      onMouseUp({});
      break;
  }
})
```

## Summary

In this post, we created a basic proof of concept that uses Amazon IVS chat messages to give chat developers the ability to add whiteboarding to their interactive live streaming applications. We also discussed some potential ways to improve the application in production. If you have any questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).

Image by <a href="https://pixabay.com/users/athree23-6195572/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=4876666">Adrian</a> from <a href="https://pixabay.com//?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=4876666">Pixabay</a>