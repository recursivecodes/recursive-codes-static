---
title: "Adding Desktop Notifications To My Electron Twilio Slack Clone"
slug: ""
author: "Todd Sharp"
date: 2018-04-10
summary: ""
tags: ["Angular", "Electron", "JavaScript", "Twilio"]
keywords: "electron, electronjs, twilio, angular, angular 5"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/38/banner_57e1d544495bab14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

In my [last post](https://recursive.codes/blog/post/37) we looked at how to create a very minimal Slack clone with Twilio, ElectronJS and Angular 5.  Although I used Electron to give the app the ability to run as a standalone app, I didn't really use too many features inherent to Electron so I thought it would be a good idea to continue building on this application as an exercise to learn more about the entire stack that I chose to build the application with.

So in this post, we'll take a look at adding support for desktop notifications.  To be perfectly honest, I'm not sure how much this particular feature counts as an Electron feature since most modern browsers support notifications, but that's OK, it was still a good exercise for myself since I haven't really worked with them much until now.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/desktop_notification.png)

As it turns out, notifications aren't very complicated.  I decided to wrap some logic around the notifications without over complicating them, so I decided on the following criteria for displaying them:

1.  When a message is received, call the `notifyMessage()` function and pass it the incoming message
2.  If the message author was **not **the current user, and the application is **not** visible (IE: it's minimized), show the message
3.  If/when the user clicks on the notification, restore the application window

That seems like a pretty fair "starting list" of requirements that any "real" application would probably have defined. So here's the modified `messageAdded()` listener that calls `notifyMessage()`:
```typescript

this.currentChannel.on('messageAdded', (m) => {
  this.messages.push(m);
  const el = this.chatDisplay.nativeElement;
  this.notifyMessage(m);
  setTimeout( () => {
    el.scrollTop = el.scrollHeight;
  });
});
```



And here is what the `notifyMessage()` method looks like.  I'll break this down a bit further after the code:
```typescript
notifyMessage(message: Message):void {
  // don't notify the user of messages they sent
  // and only show a notification if the application
  // isn't visible (IE: it is minimized)
  if( message.author === this.currentUsername || !this.showDesktopNotification ) {
    return;
  }
  const notification = {
    title: `TWACK Message from ${message.author}`,
    body: message.body
  }
  const desktopNotification = new Notification(notification.title, notification);

  // the following click handler is not fired
  // in Debian 9 running KDE (seems to be an OS bug)
  // but tested and works in macOS High Sierra
  desktopNotification.onclick = () => {
    const win = window.require('electron').remote.getCurrentWindow();
    win.restore();
  };
}
```



The first thing we do in the `notifyMessage()` function is check our "early escape" clause.  If the message being passed was authored by the current user, or the boolean `showDesktopNotification` flag is false, we bail out right away.  Moving forward though, we declare on object containing the title and the message body we want to use to craft the notification and we use that to pass it to the `Notification` class.  Note, we don't have to call a `show()` method at this point - just declaring the class is enough to trigger the notification at this point.  We could have also included an icon if we wanted to display a nice custom application specific icon.  Finally, we add a click listener and restore the window if it is minimized.  This is where I ran into a bit of trouble developing on Debian 9 - it seems that the click event is not dispatched (at least not in KDE) so I was never able to confirm the restore functionality on Linux, but I tested it on a Mac running High Sierra and confirmed that the window was properly restored.

Oh, I should also mention how the `showDesktopNotification` flag gets set.  It turns out that there is a [page visibility API](https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API) that I wasn't familiar with.  Of course, different browsers have different implementations at this point, but since we're using Electron we only have to concern ourselves with the Webkit implementation.  I added the following code to my `ngOnInit` method to toggle the flag when the application visibility changes:
```typescript
// page visibility API
// see: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
window.addEventListener('webkitvisibilitychange', (e) => {
  this.showDesktopNotification = document['webkitHidden'];
});
```



If you'd like to check out the code, please see the [GitHub repo](https://github.com/cfsilence/twack).

Image by [dannymoore1973](https://pixabay.com/users/dannymoore1973-1813225) from [Pixabay](https://pixabay.com)
