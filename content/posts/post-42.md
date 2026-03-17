---
title: "Sensing Water With Arduino"
slug: ""
author: "Todd Sharp"
date: 2018-10-12
summary: ""
tags: ["Arduino"]
keywords: "arduino, water sensor, buzzer, arduino uno, microcontroller"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/42/banner_54e2dc464e51ad14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

The other day a few friends and I were trying to help one of our group troubleshoot why he was seeing some moisture around his air conditioning unit.  During the group chat, one of the people in the group mentioned that he has a simple moisture alarm near his unit to alert him to these kinds of situations before they become a real problem.  I thought that was a great idea, and the next day I decided to try and build something like that myself instead of shelling out eleven whole dollars to purchase one.  Seeing as how I have a closet full of things like Raspberry Pi's, Arduino, sensors, wires, resistors, capacitors and the like I figured that I certainly had enough parts on hand to whip something together.  Here's what I came up with:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/sensing-water-with-arduino/arduino-water-sensor.png)

What you see here is an [Arduino UNO](https://store.arduino.cc/usa/arduino-uno-rev3) connected to an LED, buzzer and an analog water sensor.  If you're not familiar with Arduino, it's a pretty simple (and inexpensive) microcontroller device.  The difference between an Arduino and the (arguably more popular) Raspberry Pi is that the Arduino doesn't have an OS - it's a much simpler device that just runs a single program repeatedly.  Arduino has an IDE that you can use to write programs (called "sketches").  The IDE usually detects any board connected to your computer and lets you automatically upload and run your sketch.  

Sketches are quite simple at their purest form.  You get a setup() method and a loop() method:
```ino
void setup() {
  // put your setup code here, to run once:

}

void loop() {
  // put your main code here, to run repeatedly:

}
```



The Arduino has both analog and digital pins that you can read from and write to.  I found some documentation for the water sensor (you tend to do a lot of Googling for sensor docs when developing with these things) which told me that it was an analog sensor that took 5V power, so I hooked the positive lead up to 5V, the negative lead to ground and the 'S' lead to the first analog port on the Arduino (labeled A0).  For my buzzer, I determined that it was digital and also 5V, so I hooked up the power and ground and the 'S' pin to a digital port (11).  Finally, I hooked up an LED - the cathode (short side) to ground and the anode (long side) to digital pin 9 (with a 330ohm resistor inline).  With the sensors wired in, it was time to write up a quick sketch.

Outside of the setup() and loop() methods you can declare some constants, so I started off by declaring some variables representing the pins I needed to work with:
```ino
#define SENSOR A0 
#define LED 9 
#define BUZZER 11
```



Next, the setup() method.  Here I tell the program what mode (input/output) the pins I'm working with should be treated as.  I also initialize the Serial port so that I can use the IDE's serial monitor to debug things.
```ino
void setup() {
   pinMode(SENSOR, INPUT); 
   pinMode(LED, OUTPUT);     
   pinMode(BUZZER, OUTPUT);
   Serial.begin(9600);
}
```



Finally, the loop method.  For each iteration, I read the analog output of the water sensor.  If the value provided by the sensor is greater than 50 then I turn on the LED, and turn on the buzzer.  The value of '50' took a bit of trial and error to find a number that wasn't too sensitive or too forgiving.  The serial monitor was crucial in determining that value.
```ino
void loop() {
   int read = analogRead(SENSOR);
   Serial.println(read);
   
   if( read > 50 ) {
      Serial.println("on");
      digitalWrite(LED,HIGH);
      tone(BUZZER, 10);
      delay(100);
   }else {
      digitalWrite(LED,LOW);
      noTone(BUZZER);
   }
}
```



And here's a quick video of it in action:

\[youtube id=hR9HR42PCa0\]

Image by [JillWellington](https://pixabay.com/users/JillWellington-334088) from [Pixabay](https://pixabay.com)
