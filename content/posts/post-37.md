---
title: "Creating A Slack Clone With Twilio, Angular 5 And Electron"
slug: ""
author: "Todd Sharp"
date: 2018-04-06
summary: ""
tags: ["Angular", "Electron", "Spark Java", "Twilio"]
keywords: "slack clone, chat, angular, angular5, electron, electronJS, twilio, sparkjava"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37/banner_57e7d2454d56aa14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

I've heard plenty about [Twilio](https://www.twilio.com) over the past few years and had always wanted to learn more about their APIs.  They have a ton of different products - APIs for everything from SMS and Voice Calling to Video and VOIP trunking - but the product I decided to take a deeper look at was their Programmable Chat service.  I figured it would be a fun API to learn and at the same time it would let me dig into another project that I'd been meaning to dig into - [Electron](https://electronjs.org/).  Electron is a tool for building cross platform desktop applications with HTML and JavaScript.  To super simplify it:  Electron combines Node.JS and Chromium to create a distributable application that runs on any desktop.

To make things interesting, I decided to build a simple clone of a massively popular application (that also happens to use Electron): Slack.  What I've come up with is **far** from feature complete, but I think it's impressive that I was able to knock this together in about two evenings which I think speaks to the simplicity of the tools that I've selected to build it with.  In this post we'll take a look at building the application from the ground up and I'll discuss some of the pros and cons (and a few tiny bugs that I found).

To get started, head over to Twilio and create an account.  Once you've signed up and verified your account, head to your dashboard and create a new Chat Service.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_twilio_create_chat_2.png)

You'll need to collect some info from the next screen, so take note of the 'Service SID' entry from this page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_twilio_config_chat_2.png)

You'll need a few more items too, so head to your dashboard and grab your 'Account SID', Auth Token, and create an API key and grab the API key and API secret while you're there.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_twilio_dashboard_2.png)

You'll need a back end to communicate with the application. I decided to use Spark Java to create the back end, but you can use Node, PHP or whatever you'd like. Twilio provides a handful of SDKs to make your life easier, and I chose the Java SDK to drop into my Spark app.

The full backend is available on [GitHub](https://github.com/cfsilence/twack-server), or if you want to build it from scratch with Spark Java and Groovy you can grab my [Spark Groovy Skeleton](https://github.com/cfsilence/spark-groovy-skeleton) app and modify it yourself.  The first step to getting the back end up and running is to drop in the Twilio SDK dependency into the `build.gradle` file:
```groovy
dependencies {
    localGroovyConf localGroovy()
    compile 'org.codehaus.groovy:groovy-all:2.5.0-beta-2'
    compile 'com.sparkjava:spark-core:2.6.0'
    compile 'org.slf4j:slf4j-simple:1.7.21'
    compile 'com.twilio.sdk:twilio:7.17.+'
}
```



Now create a copy of the `config-template.groovy` file, rename it do `config-dev.groovy` and modify it with the proper values from Twilio.
```groovy
codes {
	recursive {
		twilio {
			accountSid = ''
			authToken = ''
			apiKey = ''
			apiSecret = ''
			serviceSid = ''
		}
	}
}
```



The only other thing left to do for the backend is to create a single route to generate and return a token. Obviously in a production application you might have some more logic around things - a password, for starters, would be nice. You might even tie it into an authentication service (or use Twilio's SMS capabilities to verify the user). Add the following to the `Bootstrap.groovy` file to handle the token generation:
```groovy
get "/token/:username", { req, res ->
   def identity = req.params('username')

    ChatGrant grant = new ChatGrant()
    grant.setServiceSid(config.codes.recursive.twilio.serviceSid)

    AccessToken token = new AccessToken.Builder(
            config.codes.recursive.twilio.accountSid,
            config.codes.recursive.twilio.apiKey,
            config.codes.recursive.twilio.apiSecret)
            .identity(identity).grant(grant).build()
    return JsonOutput.toJson([token: token.toJwt()])
}
```



To run the backend, simply do `gradle runDev`. That's it, the backend is done! Let's move on to the chat application.

Originally I had decided to just do a front end with Vanilla JS, but the more I thought about it I decided that I really wanted to take advantage of things like data binding and event handling - things that Angular does really well. I found Electron Forge, but unfortunately their template for Angular was only good for Angular 2, and rather than try to update it to work with Angular 5 I decided to dig a little more. I quickly found another awesome project that integrated Angular 5 with Electron and bootstraps an application for you, ready to use after a Git clone.

With my Angular 5 Electron application bootstrapped, I added a quick login screen that makes a call to the backend and stores the returned token in `localStorage`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_login_2.png)

Now we can send the user into the application, confident that they'll have all they need to make calls to the Twilio API from Angular. The first step in creating the chat client is to grab the Twilio bits we need on the front end. Again, Twilio provides all the code we need - just grab the `twilio-chat` [library](https://www.npmjs.com/package/twilio-chat) from NPM and install it into the Angular app.

The anatomy of my Twilio chat application boils down to:

1.  Initialize a chat client
2.  List client 'channels'
3.  Create a channel (if none exist)
4.  User joins a channel (if not already joined)
5.  Send feedback when a user begins typing
6.  Respond to other user's typing in the channel
7.  Send message(s) to channel
8.  Respond to incoming messages to the channel

There's a bit more to it then that - for example, before joining a channel we need to exit the previous channel (if any exist) and clean up any listeners to avoid things getting wonky (which I believe is the proper technical term here). But generally speaking, it's a simple workflow.

I created a `chat.service.ts` to handle things like initializing the client, listing, getting and creating a channel. Once we have joined a channel, the rest of the bits are handled in the chat component itself (things like attaching listeners, sending channel events/messages, etc). This feels like the right thing to do, but if I were to get a bit more advanced I might move some of that logic into the service at a later point. For now, the service remains bare bones. Here's what it looks like:
```typescript
import {EventEmitter, Injectable} from '@angular/core';
import * as Twilio from 'twilio-chat';
import Client from "twilio-chat";
import {Util} from "../util/util";
import {Channel} from "twilio-chat/lib/channel";
import {Router} from "@angular/router";
import {AuthService} from "./auth.service";

@Injectable()
export class ChatService {

  public chatClient: Client;
  public currentChannel: Channel;
  public chatConnectedEmitter: EventEmitter<any> = new EventEmitter<any>()
  public chatDisconnectedEmitter: EventEmitter<any> = new EventEmitter<any>()

  constructor(
    private router: Router,
    private authService: AuthService,
  ) { }

  connect(token) {
    Twilio.Client.create(token).then( (client: Client) => {
      this.chatClient = client;
      this.chatConnectedEmitter.emit(true);
    }).catch( (err: any) => {
      this.chatDisconnectedEmitter.emit(true);
      if( err.message.indexOf('token is expired') ) {
        localStorage.removeItem('twackToken');
        this.router.navigate(['/']);
      }
    });
  }

  getPublicChannels() {
    return this.chatClient.getPublicChannelDescriptors();
  }

  getChannel(sid: string): Promise<Channel> {
    return this.chatClient.getChannelBySid(sid);
  }

  createChannel(friendlyName: string, isPrivate: boolean=false) {
    return this.chatClient.createChannel({friendlyName: friendlyName, isPrivate: isPrivate, uniqueName: Util.guid()});
  }

}
```



I found it a bit odd that the NPM documentation should a package of `Twilio.Chat.Client` and I found the code in `Twilio.Client`, but maybe things have changed recently and the documentation hasn't caught up yet? Minor detail, and no real deterrent to anything, but worth mentioning. Most of the methods in the Twilio chat API return a `Promise` which makes things pretty nice and clean to work with. Also note the usage of an `EventEmitter` in the service so that the component can call connect and react to the connection/disconnection by subscribing to the associated events from the service. Not really necessary, but it makes for a bit cleaner code then nesting calls in my opinion.

In the `chat.component.ts` itself, I inject the `chat.service.ts` and make a call to the service to initialize the client in `ngOnInit`
```typescript
ngOnInit() {
  this.isConnecting = true;
  this.chatService.connect(localStorage.getItem('twackToken'));

  this.conSub = this.chatService.chatConnectedEmitter.subscribe( () => {
    this.isConnected = true;
    this.isConnecting = false;
    this.getChannels();
    this.chatService.chatClient.on('channelAdded', () => {
      this.getChannels();
    });
    this.chatService.chatClient.on('channelRemoved', () => {
      this.getChannels();
    });
    this.chatService.chatClient.on('tokenExpired', () => {
      this.authService.refreshToken();
    });
  })

  this.disconSub = this.chatService.chatDisconnectedEmitter.subscribe( () => {
    this.isConnecting = false;
    this.isConnected = false;
  });
}
```



When the client is connected, I attach a few listeners to it to know when channels have been added or removed so that the channel list will always be in sync in the component (which will update the UI accordingly). I also added a listener for token expiration that will automatically refresh the token to keep users explicitly logged in.

So how do we get a list of the channels in this client? Simply call the service (with a nice flag to allow me to provide feedback to the front end while things are happening):
```typescript
getChannels() {
  this.isGettingChannels = true;
  this.chatService.getPublicChannels().then( (channels: any) => {
    this.channelObj = channels;
    this.channels = this.channelObj.items;
    console.log(channels);
    this.isGettingChannels = false;
  });
}
```



In a brand new chat application there won't be any channels to list, so create a method to create a channel and call that method with a button click in Angular. Obviously you'd want to provide a dialog or text input to allow your user to name the channel, but for now it gets a nice, generic 'Channel X' label:
```typescript
createChannel() {
  this.chatService.createChannel(`Channel ${this.channels.length+1}`);
  return false;
}
```



Once the channel is created, the listener we created above will automatically fire to get a list of the channels which in turn will bind that list to the front end, so no further action should be necessary. However, I found that occasionally the result of that call did not include the most recently created channel. I'm not sure if that's a bug with Twilio, or something I'm doing wrong, but to compensate I added a refresh button on the front end to allow for manual refresh if the list looks stale. At this point, the front end will now show a list of channels for the user:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_client_2.png)

Each channel in the list is an anchor that calls the `joinChannel()` method in the component. Per my workflow above, the user must be a 'member' of the channel before they can enter the channel and participate in the chat. We should also take care to leave an existing channel and clean up any listeners before we enter the new channel, or we'll end up with multiple messages being posted into a channel each time we enter one. Sounds like a complicated workflow, but it's really not. The only minor catch I found with the API at this point was the inability to know if a user was already a member of the channel before attempting to join it. If we try to join without being a member we'll get a permission error and if we attempt to join a channel that we're already a member of we'll also get an error, so without the ability to check before joining I decided to add a `catch()` to the `joinChannel()` promise call to enter the channel if we get a message that the user is already a member. Again, not ideal, but I couldn't find any methods in the API to work around this. Here's the workflow, in code, to join/enter a channel:
```typescript
leaveChannel() {
  if( this.currentChannel ) {
    return this.currentChannel.leave().then( (channel: Channel) => {
      channel.removeAllListeners('messageAdded');
      channel.removeAllListeners('typingStarted');
      channel.removeAllListeners('typingEnded');
    });
  }
  else {
    return Promise.resolve();
  }
}

enterChannel(sid: string) {
  this.messages = [];
  this.membersTyping = [];

  this.leaveChannel()
    .then(() => {
      this.chatService.getChannel(sid).then( channel => {
        this.currentChannel = channel;
        console.log(channel);
        this.currentChannel.join()
          .then( r => {
            this.initChannel();
          })
          .catch( e => {
            if( e.message.indexOf('already exists') > 0 ) {
              this.initChannel();
            }
          });
      });
    });
}

initChannel() {
  this.typeObservable = Observable.fromEvent(this.chatElement.nativeElement, 'keyup').debounceTime(100).subscribe( () => {
    this.typing();
  });

  this.currentChannel.on('messageAdded', (m) => {
    this.messages.push(m);
    const el = this.chatDisplay.nativeElement;
    setTimeout( () => {
      el.scrollTop = el.scrollHeight;
    });
  });
  this.currentChannel.on('typingStarted', (m) => {
    this.membersTyping.push(m);
  });
  this.currentChannel.on('typingEnded', (m) => {
    const mIdx = this.membersTyping.findIndex( mem => mem.identity === m.identity );
    this.membersTyping = this.membersTyping.splice(mIdx, 0);
  });
}
```



Pretty straightforward, but you'll notice a few listeners set up here, specifically for `messageAdded`, `typingStarted` and `typingEnded`. This will allow us to keep the chat log up to date as well as provide UI feedback when another user has started/stopped typing a message, just like Slack. Also, an Observable is created (which I've just now realized is not cleaned up when a user leaves a channel) to debounce the user typing a message so that we're not making constant API calls every time the user types a message. It gets really tricky in the method that is called from the debounced Observable:
```typescript
typing() {
  this.currentChannel.typing();
}
```



OK, not so tricky - just a call to let the API know the user is typing. Notice above that I store the results of the typingStarted in an array so that we can provide feedback that multiple users are typing at the same time if need be.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_user_typing_2.png)

The final step is to post an actual message to the chat which is just call `sendMessage()` on the current channel:
```typescript
sendMessage() {
  this.currentChannel.sendMessage(this.chatMessage);
  this.chatMessage = null;
}
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/twack/twack_messages_2.png)

And that's it! As I said above, there are obvious features missing from a true Slack clone, but the fact that login, channel listing/creation/joining and chat messaging is something that can be thrown together in a few hours over two nights is impressive to me. I know what it takes to set up websockets and the infrastructure involved on the back end to make it this easy to integrate and the fact that I can focus on the application itself is a relief. If you'd like to take a look at the full code or run it yourself, please check it out on [GitHub](https://github.com/cfsilence/twack).

Image by [castleguard](https://pixabay.com/users/castleguard-2970404) from [Pixabay](https://pixabay.com)
