---
title: "Project GreenThumb Part 2 - The Data Collection"
slug: "project-greenthumb-part-2-the-data-collection"
author: "Todd Sharp"
date: 2021-03-24
summary: "In this post, we'll start looking at the data collection process for Project GreenThumb."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1beb3da2-5bca-439d-a76c-e8a4305e247f/banner_vishnu_mohanan_pfr18jnemv8_unsplash.jpeg"
---

Welcome to part 2 of my short series about Project GreenThumb, a hardware, software and cloud-based solution for monitoring and automating seedling growth. In [my last post](/posts/project-greenthumb-part-1-automating-monitoring-seedling-growth-with-microcontrollers-the-cloud), I introduced you to the motivation and goals of the project and we looked at the hardware setup. In this post, I want to go a bit more in-depth about the Arduino code necessary to collect the environment data and publish it to a message queue so that it can later be consumed, persisted and visualized. Let's get into it!

## The Hardware Build & Schematic 

I assembled the hardware by soldering the sensors mentioned in the last post to the NodeMCU board and leaving plenty of slack in each lead wire in order to ensure they would reach the seedling tray. Here's a wiring diagram that shows which pins were used for which sensors. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1beb3da2-5bca-439d-a76c-e8a4305e247f/file_1616174810481.png)

### The Arduino Code

Thanks to the amazing Arduino community, I was able to rely on a number of libraries to read all of the sensors, output the data to the OLED display and publish the messages to MQTT. 

#### Reading Sensors

Some sensors are straightforward - just read the value using `analogRead` or `digitalRead`. 
```ino
#define WATER_SENSOR A0
moisture = analogRead(WATER_SENSOR);
```



Others are a bit more complex, requiring third-party libraries.
```ino
#include <dht.h>
#define DHT11_PIN 10
DHT.read11(DHT11_PIN);
int tempC = DHT.temperature
int humidity = DHT.humidity
```



There's nothing really complex about reading most sensors with Arduino and as I mentioned there are open source libraries that can help with just about every sensor out there. 

**Need To See More?** Don't worry, I've published the entire client source code on [GitHub](https://github.com/recursivecodes/project-greenthumb-microcontroller).

#### Serializing Messages as JSON

I planned on publishing all of the sensor readings from each iteration to a message queue in the cloud as a single JSON object. Once the readings are obtained, JSON Serialization was done with the `ArduinoJson` library ([https://arduinojson.org](https://arduinojson.org/)). 

##### Step 1 - Include the Library 
```ino
#include <ArduinoJson.h>
```



##### Step 2 - Create a JSON Document & String to Hold Serialized Result 
```ino
StaticJsonDocument<150> doc;
char readingsJson[256];
```



##### Step 3 - Set Document Values & Serialize 
```ino
doc["outletState"] = relayState;
doc["airTemp"] = cToF(DHT.temperature);
doc["soilTemp"] = probeTempF;
doc["humidity"] = DHT.humidity;
doc["moisture"] = moisturePct;
doc["light"] = lux;
  
serializeJson(doc, readingsJson);
```



#### The MQTT Client

The MQTT Client by Adafruit was used to publish the messages to an MQTT topic running on RabbitMQ in an always free VM instance in the Oracle Cloud. 

**Need A RabbitMQ Instance?** Check out [how to launch your own instance of the popular messaging queue](/posts/getting-started-with-rabbitmq-in-the-oracle-cloud) on an always free instance in the Oracle Cloud!

I'm only doing one-way messaging (publishing sensor data), but I could quite easily modify the code to receive incoming messages as well. Here's a simple overview of how to use the MQTT client:

##### Step 1 - Include the Library 
```ino
#include "Adafruit_MQTT.h"
#include "Adafruit_MQTT_Client.h"
```



##### Step 2 - Create the Client & Publisher 
```ino
WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, RABBIT_SERVER, RABBIT_PORT, RABBIT_USER, RABBIT_PASSWORD);
Adafruit_MQTT_Publish readingsTopic = Adafruit_MQTT_Publish(&mqtt, "greenthumb/readings");
```



##### Step 3 - Create a Function for Connecting to the Client 
```ino
void MQTT_connect() {
  int8_t ret;
  if (mqtt.connected()) {
    return;
  }
  Serial.print("Connecting to MQTT... ");
  uint8_t retries = 3;
  while ((ret = mqtt.connect()) != 0) {
       Serial.println(mqtt.connectErrorString(ret));
       Serial.println("Retrying MQTT connection in 5 seconds...");
       mqtt.disconnect();
       delay(5000);
       retries--;
       if (retries == 0) {
         while (1);
       }
  }
  Serial.println("MQTT Connected!");
}
```



##### Step 4 - Connect & Publish Message 
```ino
MQTT_connect();
readingsTopic.publish(readingsJson);
```



I won't cover every bit of the microcontroller code here, but the examples above should give you a basic idea of what it takes to read the sensors, serialize the data, and publish it to the MQTT topic. The [full source code for the microcontroller project is available on GitHub](https://github.com/recursivecodes/project-greenthumb-microcontroller) if you'd like to check it out.

## Summary

In this post, we looked at some of the code that I used to read and publish the sensor data to a message queue. In the next post, we'll start to look at how I consumed that sensor data, persist and visualize it. 

Photo by [Vishnu Mohanan](https://unsplash.com/@vishnumaiea?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](/s/photos/microcontroller?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

