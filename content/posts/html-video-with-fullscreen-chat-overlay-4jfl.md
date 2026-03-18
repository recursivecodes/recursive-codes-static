---
title: "HTML Video with Fullscreen Chat Overlay"
slug: "html-video-with-fullscreen-chat-overlay-4jfl"
author: "Todd Sharp"
date: 2022-11-11T12:25:57Z
summary: "I've been focusing a lot lately on chat, because I feel like it's an important feature for any live..."
tags: ["amazonivs", "aws", "chat", "javascript"]
canonical_url: "https://dev.to/aws/html-video-with-fullscreen-chat-overlay-4jfl"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5xavwhny5t6pvl0dfvvv.png"
---

I've been focusing a lot lately on chat, because I feel like it's an important feature for any live streaming user generated content (UGC) platform. Over the past 6 weeks, we've learned how to [create a chat room and integrate it into a live streaming application](https://dev.to/aws/adding-chat-to-your-amazon-ivs-live-stream-43i6), and how to moderate chat messages (in both an [automated](https://dev.to/aws/moderating-amazon-ivs-chat-messages-with-an-aws-lambda-function-4b7p) and [manual](https://dev.to/aws/manually-moderating-amazon-ivs-chat-messages-5646) manner). We've even looked at how to create an [interactive whiteboard](todo: add link) with Amazon Interactive Video Service (Amazon IVS) chat. In this post, we won't look at anything specific to Amazon IVS chat, but rather a way to enhance the user experience by overlaying a chat view on top of a fullscreen video. 

## The Problem with Native Controls

The nice thing about the `<video>` tag in HTML is that it allows users to go fullscreen by clicking the button in the native browser control or by double clicking on the video itself. Here's the native control button in Chrome:

![Native HTML video tag in Chrome](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-caul78qzqoeoga7ua2f5.png)

<small>Stills used from Big Buck Bunny © copyright 2008, Blender Foundation / [www.bigbuckbunny.org](http://www.bigbuckbunny.org/)</small>

This allows the video that is being played to fill our entire display.

![Fullscreen video](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-5w6j2kzhm16sl2nilkvj.png)

However, any nearby content or other elements - even elements that we've overlaid on the video with absolute positioning - are not visible in this view. If that works for your requirements, great! But, sometimes our requirements call for a more custom view that includes additional elements in the fullscreen view.

If you think about a typical live streaming UGC platform, many times the video is accompanied by a live chat stream located somewhere nearby. Something like this:

![Chat next to video](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ygf8ygw16krcc2xnpuxi.png)

Chat adds a layer of interactivity to live streaming platforms. Our viewers can actively participate in the conversation instead of passively consuming it. So why shouldn't chat be visible when viewing in fullscreen? Wouldn't it be nicer to create an immersive fullscreen experience like this instead?

![Full screen video with chat overlay](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-kt2ghrwfl969wixror6v.png)

## The Solution - Fullscreen API and CSS

Before we look at the code involved, let's take a look at the finished product so we can see the effect we are trying to achieve. To keep things simple and focus on the CSS and HTML APIs, this demo doesn't contain an actual live stream or chat. Instead, chat messages are added directly to the chat container to simulate a real chat experience so that you can see what messages look like both in and out of fullscreen.

> **Note:** CodePens are embedded in an `<iframe>` on dev.to which does not include permissions for fullscreen. To [try out the demo](https://codepen.io/recursivecodes/pen/qBKbxBy), open it in a new browser tab and click the fullscreen icon in the top right corner of the video player.

To achieve this enhanced user experience, we'll hide the native controls and use the [HTML Fullscreen API](https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API) and some CSS using pseudo-classes to modify the look and position of our elements when in fullscreen. An alternative approach is to listen for the `fullscreenchange` event and add/remove classes to achieve different styles per view, but that would involve a lot of JavaScript and I personally find the pseudo-class approach cleaner and easier to work with. 

> **Note:** The `:fullscreen` pseudo-class is well supported in modern browsers but has some caveats. For example, Safari uses the non-standard `:-webkit-full-screen` name. Make sure to check [support and limitations](https://caniuse.com/mdn-css_selectors_fullscreen) before implementing it in your production application.

### The Fullscreen API

The HTML Fullscreen API lets us present a specific HTML node in fullscreen view. That might sound obvious, but what you may not realize is that it can present _any_ HTML element in fullscreen mode. That means we can hide the native browser controls and wrap the video player and chat element group in a single `<div>` and go fullscreen with the entire layout. We'll need to add our own fullscreen button and playback and volume controls since the built-in button in the video control will only work to make the `<video>` itself fullscreen.

Let's look at a simplified example of a typical video/chat view. I'm going to use Bootstrap here, but you can use whichever CSS framework you're comfortable with. The markup here is heavily commented to help you understand what is going on. To focus on the important bits, styling (layout, borders, shadows, etc) classes have been replaced with `...`.

```html
<div class="row" id="video-chat-container">

  <!-- left (video) column -->
  <div class="...">
    <!-- relative position container for video -->
    <div>
      <!-- fix the video container to 16x9-->
      <div class="ratio ratio-16x9">
        <video
          id="video-player"
          class="..."
          src="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
          autoplay playsinline muted>
        </video>
      </div>
      <!-- video overlay for status indicator and fullscreen button -->
      <div
        id="top-overlay"
        class="...">
        <!-- status indicator in the top left -->
        <div>
          <span id="online-indicator" class="...">Offline</span>
        </div>
        <!-- manual fullscreen button in the top right -->
        <div>
          <i
            id="fullscreen-toggle-btn"
            role="button"
            class="...">
          </i>
        </div>
      </div>
      <div id="bottom-overlay">
        <!-- bottom div for player controls -->
      </div>
    </div>
  </div>

  <!-- right (chat) container -->
  <div class="...">
    <!-- vertically stack the controls with flex and fill the height of the row-->
    <div
      id="chat-container"
      class="vstack ...">
      <!-- the chat div - fill the height of the container (minus the chat input container height)-->
      <div
        id="chat"
        class="flex-grow-1 ...">
      </div>
      <!-- chat input and submit button -->
      <div
        id="chat-input-container"
        class="flex-grow ...">
        <input
          id="chat-input"
          class="..."
          placeholder="Message"
          maxlength="500"
          type="text" />
        <button
          type="button"
          id="submit-chat"
          class="...">Send</button>
      </div>
    </div>
  </div>

</div>
```

When the DOM is ready, we'll add a click handler to the fullscreen button to call the `toggleFullscreen()` method.

```js
document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('fullscreen-toggle-btn')
    .addEventListener('click', toggleFullScreen);
});
```

The `toggleFullscreen()` switches the wrapping `<div>` into and out of fullscreen mode. Note that we're accounting for the various browser implementations in the event that the standard `requestFullscreen()` method is not available.

```js
const toggleFullScreen = async () => {
  const container = document.getElementById('video-chat-container');
  const fullscreenApi = container.requestFullscreen
    || container.webkitRequestFullScreen
    || container.mozRequestFullScreen
    || container.msRequestFullscreen;
  if (!document.fullscreenElement) {
    fullscreenApi.call(container);
  }
  else {
    document.exitFullscreen();
  }
};
```

At this point, the button will toggle the wrapping `<div>` as we'd expect it to, but it won't look very nice.

![Fullscreen mode without styles](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-hrifmxbib5qx8syzgd0t.png)

### Applying Styles in Fullscreen

So how could we make this look a bit cleaner? Well, we can start out by addressing the `<video>` tag. It's still stuck in 16x9 ratio, so let's make it fill the entire view height and width.

```css
#video-chat-container:fullscreen video {
  height: 100vh;
  width: 100vw;
}
```

> **Reminder:** As mentioned above, the `:fullscreen` pseudo-class works in most browsers, but `:-webkit-full-screen` must be used in Safari. These declarations cannot be combined, so you'll notice "duplicate" looking rules in the CodePen to account for Safari.

And apply fixed positioning to the top overlay that contain the status indicator and our manual fullscreen button and the bottom overlay for the custom playback controls.

```css
#video-chat-container:fullscreen #top-overlay,
#video-chat-container:fullscreen #bottom-overlay {
  position: fixed;
}
```

The chat div might look nicer with a transparent background. We'll also limit it to 400px wide.

```css
#video-chat-container:fullscreen #chat {
  background-color: rgba(0, 0, 0, 0.3);
  max-width: 400px;
  width: 400px;
}
```

Let's not forget about mobile users. We'll use a media query to change that width to 200px on smaller displays.

```css
@media (max-width: 575.98px) {
  #video-chat-container:fullscreen #chat {
    max-width: 200px;
    width: 200px;
  }
  #video-chat-container:fullscreen #chat-input-container {
    width: 200px !important;
  }
}
```

> **575.98px?** This may seem like a weird value to use for a mobile breakpoint. This value is borrowed from Bootstrap and is used for cross-browser compatibility to workaround an issue with Safari. Read more about it [here](> **575.98px?** This may seem like a weird value to use for a mobile breakpoint. ).

For the chat container that wraps the chat div and the chat input controls, let's make it 80% of the current view height, vertically centered, and make the text white.

```css
#video-chat-container:fullscreen #chat-container {
  height: 80vh;
  position: fixed;
  top: calc(50vh - (80vh / 2));
  right: 10px;
  color: #ffffff;
}
```

Finally, we'll change the chat text input and submit button to also have a white border and white text.

```css
#video-chat-container:fullscreen #chat-input,
#video-chat-container:fullscreen #submit-chat{
  background: rgba(0,0,0,0.3);
  color: #ffffff;
  border: 1px solid rgb(var(--bs-white-rgb));
}
```

The end result looks quite nice.


![Fullscreen video and chat overlay](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-cwdog94byl8khc6c0qaa.png)

The chat can still be interacted with when it is overlaid on the video, and is presented in a way that does not overly obscure the underlying video.

## Summary

In this post, we learned how to use the HTML fullscreen API and the `:fullscreen` CSS pseudo-class to present an improved user experience for live stream viewers. What we've learned here is just a starting point. Feel free to modify the classes and create your own engaging live streaming experiences. If you have any questions, leave a comment or reach out to me on [Twitter](https://twitter.com/recursivecodes).