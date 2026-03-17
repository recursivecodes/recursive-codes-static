---
title: "Realtime GPIO On Raspberry Pi With Spark Java And WebSockets"
slug: ""
author: "Todd Sharp"
date: 2017-04-10
summary: "I've blogged in the past about using Spark Java to get a simple website running on the Raspberry Pi.  In this demo I'll do just that and in addition I'll implement a simple GPIO handler to listen for a button press event.  When the event handler fires, I'll turn on an LED and broadcast a message to subscribed websocket clients to tell them about the message."
tags: ["Groovy", "Java", "Raspberry Pi", "Spark Java", "WebSockets"]
keywords: "realtime gpio, gpio, raspberry pi, spark java, websockets"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/28/banner_55e1d4404953a414f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

One of the cooler things about the Spark Java framework is built in [websocket support](http://sparkjava.com/documentation.html#websockets) thanks to the embedded Jetty server.  I've long been fascinated with websockets since they can push data in realtime to a subscribed client without the need for client side polling. \
\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/websocket-magic.gif)

[The first (and only) demo often seen is the good old "chat" demo.  Don't get me wrong, chat is still a useful (and often implemented) feature, but I've always wanted to find a more interesting use case for them.  I think I've finally found a pretty cool use case so I wanted to share it here.  ]\

[I've blogged in the past about using Spark Java to get a simple website running on the Raspberry Pi.  In this demo I'll do just that and in addition I'll implement a simple GPIO handler to listen for a button press event.  When the event handler fires, I'll turn on an LED and broadcast a message to subscribed websocket clients to tell them about the message.  The majority of the websocket code is altered from [this demo](https://sparktutorials.github.io/2015/11/08/spark-websocket-chat.html).  ]

[Let's get started by looking at our build.gradle file as it has a few dependencies we'll need for this demo.]

```groovy
group 'codes.recursive'
version '1.0-SNAPSHOT'

apply plugin: 'idea'
apply plugin: 'groovy'
apply plugin: 'java'

configurations {
    localGroovyConf
}

repositories {
    mavenCentral()
}
dependencies {
    localGroovyConf localGroovy()
    compile 'org.codehaus.groovy:groovy-all:2.3.11'
    compile group: 'com.pi4j', name: 'pi4j-core', version: '1.1'
    compile group: 'com.sparkjava', name: 'spark-template-thymeleaf', version: '2.5.5'
    compile group: 'org.slf4j', name: 'slf4j-simple', version: '1.7.21'
    compile 'com.sparkjava:spark-core:2.5.5'
}

task runServer(dependsOn: 'classes', type: JavaExec) {
    classpath = sourceSets.main.runtimeClasspath
    main = 'Bootstrap'
}
```
[Next up - the Bootstrap.groovy class:]

```groovy
import com.pi4j.io.gpio.PinPullResistance
import com.pi4j.io.gpio.PinState
import com.pi4j.io.gpio.RaspiPin
import com.pi4j.io.gpio.event.GpioPinDigitalStateChangeEvent
import com.pi4j.io.gpio.event.GpioPinListenerDigital
import gpio.GpioHandler
import groovy.json.JsonOutput
import org.eclipse.jetty.websocket.api.Session
import spark.Spark
import spark.template.thymeleaf.ThymeleafTemplateEngine

import java.util.concurrent.ConcurrentHashMap

import static spark.Spark.*

class Bootstrap {
    static Map<Session, String> userMap = new ConcurrentHashMap<>()
    static int nextUserNumber = 1

    static void main(String[] args) {
        Spark.staticFileLocation('/static')
        webSocket("/chat", ChatWebSocketHandler.class);
        init()

        GpioHandler.instance.init()

        def ledPin = RaspiPin.getPinByAddress(0)
        def buttonPin = RaspiPin.getPinByAddress(2)
        def led = GpioHandler.instance.gpio.provisionDigitalOutputPin(ledPin)

        def button = GpioHandler.instance.gpio.provisionDigitalInputPin(buttonPin, PinPullResistance.PULL_UP)
        button.setShutdownOptions(true)

        button.addListener(new GpioPinListenerDigital() {
            @Override
            public void handleGpioPinDigitalStateChangeEvent(GpioPinDigitalStateChangeEvent event) {
                // if the button state is HIGH, set the led state to LOW
                led.setState(event.getState() == PinState.HIGH ? PinState.LOW : PinState.HIGH)
                println(" --> GPIO PIN STATE CHANGE: " + event.getPin() + " = " + event.getState());
                broadcastMessage('GPIO', [event: event, message: " --> GPIO PIN STATE CHANGE: " + event.getPin() + " = " + event.getState()])
            }

        })

    }

    //Sends a message from one user to all users, along with a list of current usernames
    static void broadcastMessage(String sender, Object message) {
        userMap.keySet().stream().findAll{ Session it -> it.isOpen() }.each{ Session it ->
            try {
                def msg = JsonOutput.toJson([message: message, userList: userMap.values()])
                it.getRemote().sendString(String.valueOf(msg))
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}
```
[A few notes on the Bootstrap class:]

1.  Line 22 - we create our websocket endpoint and tell Spark to use the `ChatWebSocketHandler` class.
2.  Line 23 - call the static `init()` method on Spark since we have no other routes defined.
3.  GPIO is initialized next, using a singleton `GpioHandler` (code below).  We attach a listener starting on line 36 that ultimately calls a `broadcastMessage()` method when it handles the button press event. 
4.  `broadcastMessage()` notifies all connected clients of the event, passing a message to them.

Here's the `GpioHandler` - nothing fancy here:
```groovy
package gpio

import com.pi4j.io.gpio.GpioController
import com.pi4j.io.gpio.GpioFactory
import com.pi4j.wiringpi.GpioUtil

@Singleton
class GpioHandler {
    GpioController gpio
    Boolean init=false

    def init(){
        if( !init ) {
            GpioUtil.enableNonPrivilegedAccess()
            gpio = GpioFactory.getInstance()
            this.init = true
        }
    }
}
```



And the `ChatWebSocketHandler` - mostly the same as the demo we're copying:\
```groovy
import org.eclipse.jetty.websocket.api.*
import org.eclipse.jetty.websocket.api.annotations.*

@WebSocket
class ChatWebSocketHandler {

    private String sender, msg;

    @OnWebSocketConnect
    void onConnect(Session user) throws Exception {
        String username = "User" + Bootstrap.nextUserNumber++
        Bootstrap.userMap.put(user, username)
        Bootstrap.broadcastMessage("Server", [message: username + " joined the chat"])
    }

    @OnWebSocketClose
    void onClose(Session user, int statusCode, String reason) {
        String username = Bootstrap.userUsernameMap.get(user)
        Bootstrap.userMap.remove(user)
        Bootstrap.broadcastMessage("Server", [message: username + " left the chat"])
    }

    @OnWebSocketMessage
    void onMessage(Session user, String message) {
        Bootstrap.broadcastMessage(Bootstrap.userMap.get(user), [message: message])
    }

}
```



The view (unchanged from the demo):\
```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>WebsSockets</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div id="chatControls">
    <input id="message" placeholder="Type your message">
    <button id="send">Send</button>
</div>
<ul id="userlist"> <!-- Built by JS --> </ul>
<div id="chat">    <!-- Built by JS --> </div>
<script src="websocketDemo.js"></script>
</body>
</html>
```



And the JavaScript (mildly changed from the demo):\
```javascript
//Establish the WebSocket connection and set up event handlers
var webSocket = new WebSocket("ws://" + location.hostname + ":" + location.port + "/chat/");
webSocket.onmessage = function (msg) {
    var response = JSON.parse(msg.data)
    updateChat(response.message);
    updateUserList(response.userList)
};
webSocket.onclose = function () { alert("WebSocket connection closed") };

//Send message if "Send" is clicked
id("send").addEventListener("click", function () {
    sendMessage(id("message").value);
});

//Send message if enter is pressed in the input field
id("message").addEventListener("keypress", function (e) {
    if (e.keyCode === 13) { sendMessage(e.target.value); }
});

//Send a message if it's not empty, then clear the input field
function sendMessage(message) {
    if (message !== "") {
        webSocket.send(message);
        id("message").value = "";
    }
}

function updateUserList(list) {
    id("userlist").innerHTML = "";
    list.forEach(function (user) {
        insert("userlist", "<li>" + user + "</li>");
    });
}

//Update the chat-panel, and the list of connected users
function updateChat(data) {
    insert("chat", data.message);
}

//Helper function for inserting HTML as the first child of an element
function insert(targetId, message) {
    id(targetId).insertAdjacentHTML("afterbegin", message+'<br/>');
}

//Helper function for selecting element by id
function id(id) {
    return document.getElementById(id);
}
```



After pushing the code to the Pi and running the app, here's how it responds:\

\[youtube id=izMLmb1YxCs\]

There are tons of possibilities for GPIO with websockets.  Real-time temperature charts, sensors providing immediate feedback to the connected web client, etc.  

Image by [bichnguyenvo](https://pixabay.com/users/bichnguyenvo-7410713) from [Pixabay](https://pixabay.com)
