---
title: "Grails on Raspberry Pi Part 2 - Why Grails?"
slug: ""
author: "Todd Sharp"
date: 2017-03-15
summary: ""
tags: ["Grails", "Groovy", "Groovy On Raspberry Pi", "Java", "Raspberry Pi"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6/banner_54e1d54a4b51b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

So why Grails on a Raspberry Pi?  It's a valid question and one that I hope to answer with this post.  If you're not familiar with Grails, perhaps I should first answer - what is Grails?\
[](https://grails.org)

[Grails.org](https://grails.org) says:

> **Grails** is a **powerful** web framework, for the Java platform aimed at multiplying developers' productivity thanks to a Convention-over-Configuration, sensible defaults and opinionated APIs. It integrates smoothly with the JVM, allowing you to be immediately productive whilst providing powerful features, including integrated ORM, **Domain-Specific Languages**, runtime and compile-time **meta-programming** and **Asynchronous** programming.\

There are a few buzzwords thrown in that description, but put simply - Grails is a fast, intuitive web framework that doesn't get hung up on verbose and redundant configuration files.  If you need a simple site you can do that quickly and easily with Grails.  Conversely, if you need a framework to empower you to build a robust, data-driven site with support for asynchronous programming and REST APIs - Grails has your back there too.  It's as simple and as complex as you want it to be.  

### Why Grails on the Pi?

I'd been meaning to get into playing around with the Raspberry Pi for years.  When I finally took the plunge last year I had planned on taking the opportunity to learn some Python since many of the examples and demos I had seen online seemed to use it.  But the more I looked at Python, the more I realized that I already knew a pretty powerful scripting language that could do whatever Python does - Groovy.  Thing is, I've got nothing against Python - it's very readable and I have a few scripts that I have thrown together in the past year that I use often.  I just view it as a different type of hammer - and the one in my tool belt handles all the nails that I use just fine, thank you very much.  \
\
I did have one issue with some of the Python solutions that I ended up finding on the web.  Well, a few issues - but, let's start with this one.  A lot of the examples I found looked like this one that checks the state of a magnetic door sensor attached to the Pi:
```python
#!/usr/bin/env python

import RPi.GPIO as GPIO 
import time

GPIO.setmode(GPIO.BCM) 
GPIO.setwarnings(False)

LED1 = 18
LED2 = 23
door1 = 12
door2 = 16

GPIO.setup(LED1, GPIO.OUT)
GPIO.setup(LED2, GPIO.OUT)
GPIO.setup(door1, GPIO.IN, GPIO.PUD_UP)
GPIO.setup(door2, GPIO.IN, GPIO.PUD_UP)

GPIO.output(LED1, 0)
GPIO.output(LED2, 0)

while True:
    if GPIO.input(door1) == False:
       print("Door 1 is closed.")
   time.sleep(2)
    else:
   if GPIO.input(door1) == True:
       print("Door 1 is open.")
       time.sleep(2)       
    if GPIO.input(door2) == False:
       print("Door 2 is closed.")
   time.sleep(2)
    else:
   if GPIO.input(door2) == True:
       print("Door 2 is open.")
       time.sleep(2)
GPIO.cleanup()
```



Can you spot what bothers me about that script?  Hint:  take a look at line 22.  Yeah, I'm not much of a fan of infinite loops either.  Is this the best practice for Python scripts on the Pi?  Not sure.  But, even for a proof of concept, it leaves a bit to be desired.\
\
So I started to look into Java based solutions for interacting with the Pi's GPIO pins.  After all, that's pretty much the big draw with the Pi for tinkering.  The ability to hook up various sensors and switches and whatnot - basically it's the old '150 in 1' kit from Radio Shack that I used to play as a kid, but more socially acceptable to play with as a 40 year old man.\
\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/150in1kit.png)

<div>

Yeah, I'm pretty much a dinosaur.

</div>

My search for Java based solutions quickly led me to [Pi4J](http://pi4j.com/).  This got me excited pretty quickly, but then I took a look at a few of the examples like this one ([via](http://pi4j.com/example/listener.html)):
```java
import com.pi4j.io.gpio.*;
import com.pi4j.io.gpio.event.GpioPinDigitalStateChangeEvent;
import com.pi4j.io.gpio.event.GpioPinListenerDigital;

/**
 * This example code demonstrates how to setup a listener
 * for GPIO pin state changes on the Raspberry Pi.
 *
 * @author Robert Savage
 */
public class ListenGpioExample {

    public static void main(String args[]) throws InterruptedException {
        System.out.println("<--Pi4J--> GPIO Listen Example ... started.");

        // create gpio controller
        final GpioController gpio = GpioFactory.getInstance();

        // provision gpio pin #02 as an input pin with its internal pull down resistor enabled
        final GpioPinDigitalInput myButton = gpio.provisionDigitalInputPin(RaspiPin.GPIO_02, PinPullResistance.PULL_DOWN);

        // set shutdown state for this input pin
        myButton.setShutdownOptions(true);

        // create and register gpio pin listener
        myButton.addListener(new GpioPinListenerDigital() {
            @Override
            public void handleGpioPinDigitalStateChangeEvent(GpioPinDigitalStateChangeEvent event) {
                // display pin state on console
                System.out.println(" --> GPIO PIN STATE CHANGE: " + event.getPin() + " = " + event.getState());
            }

        });

        System.out.println(" ... complete the GPIO #02 circuit and see the listener feedback here in the console.");

        // keep program running until user aborts (CTRL-C)
        while(true) {
            Thread.sleep(500);
        }

        // stop all GPIO activity/threads by shutting down the GPIO controller
        // (this method will forcefully shutdown all GPIO monitoring threads and scheduled tasks)
        // gpio.shutdown();   <--- implement this method call if you wish to terminate the Pi4J GPIO controller
    }
}

// END SNIPPET: listen-gpio-snippet
```



Much bet\....uhhh\...wait a sec\....what is that on line 38?!  \

### Enter Grails

The problem with standalone scripts is that they're designed to be run once (and put to bed wet?).  So if you want them to continually listen for (and respond to) events you have to keep them from terminating and the only way to do that is with an infinite loop.  Grails solves that problem because it is a web application that runs on an application server so we can do things like create a singleton service to interact with the GPIO pins (via a dependency on Pi4J) and count on the fact that the service will be in memory, ready to respond to our requests at any time.  Since Grails requires nothing more than a single entry in a Gradle script to add a dependency we can easily add Pi4J and create a service that our application can use.\
\
The other added benefit is that Grails lets us create a web accessible front end to control and display data from the various sensors that our GPIO service interacts with.  Plus the Grails plugin ecosystem is pretty huge, GORM is built in for easy Hibernate based object persistence and almost any Java project that you can think of can be easily integrated.  \
\
You'll see in some upcoming posts how easy it is to get started running Grails on the Pi.  You may also be surprised how well it runs even with the limited system resources available on the Raspberry Pi.

Image by [12019](https://pixabay.com/users/12019-12019) from [Pixabay](https://pixabay.com)
