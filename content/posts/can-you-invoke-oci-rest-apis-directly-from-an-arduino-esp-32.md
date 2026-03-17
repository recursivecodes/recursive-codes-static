---
title: "Can You Invoke OCI REST APIs Directly from an Arduino (ESP-32)?"
slug: "can-you-invoke-oci-rest-apis-directly-from-an-arduino-esp-32"
author: "Todd Sharp"
date: 2021-04-23
summary: "In this post, we'll look at what it takes to make OCI REST API calls directly from a microcontroller device. It's super handy and easy to do!"
tags: ["APIs", "Cloud"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b321b5df-a430-4e91-bd5f-07aa2adbba09/banner_pxl_20210328_025244223_portrait.jpg"
---

Recently I had a flash of inspiration to build a standalone project on a microcontroller that would invoke OCI APIs directly from the device. I've played with microcontrollers and single-board computers many times in the past, and every time I've done so it has always involved some sort of VM or service in the cloud that would act as a "proxy" for the device. Often times this would be a service tier (either a Java or Node application) that would perform some task like data persistence or retrieval. On other occasions, it might be some kind of message queue like RabbitMQ that the device would produce messages to or consume messages from. Often times the "cloud" bit can't be avoided, but wouldn't it be nice if certain tasks could be performed without having to turn up a service in the cloud? We can already do this to some extent by persisting or querying a database with Oracle REST Data Services, but I wanted to open this up a bit more and provide the ability to utilize the full complement of Oracle Cloud Infrastructure REST APIs from a microcontroller. This would provide the ability to interact directly with a cloud tenancy from an Arduino device, but since it's a somewhat complex operation, it would only work on boards with a decent amount of RAM onboard like the ESP-32.

Why would you want to do this? That's a good question! There are quite a few use cases that inspired me down the path to seeing if I could make this work. One potential use case would be writing data collected from the microcontroller directly to [Object Storage](https://docs.oracle.com/en-us/iaas/api/#/en/objectstorage/20160918/) or to the OCI [Monitoring Service](https://docs.oracle.com/en-us/iaas/api/#/en/monitoring/20180401/) via [custom metrics](https://docs.oracle.com/en-us/iaas/api/#/en/monitoring/20180401/MetricData/PostMetricData). This could prove very valuable for customers who collect large amounts of data from their environment and would like that data to be available in the cloud for further analysis. Another use case for invoking the OCI REST APIs on a device would be to take advantage of the [Oracle Streaming Service](https://docs.oracle.com/en-us/iaas/api/#/en/streaming/20180418/) and [produce](https://docs.oracle.com/en-us/iaas/api/#/en/streaming/20180418/Message/PutMessages)/[consume](https://docs.oracle.com/en-us/iaas/api/#/en/streaming/20180418/Message/GetMessages) messages directly from the device. This would eliminate the need for a third-party messaging queue as well as "yet another" VM running in the cloud. Maybe you just want to automate certain tasks or collect bits of data about your tenancy on demand from a simple little device. There are tons of potential uses, and I'm sure your mind is already coming up with a bunch of ideas that I haven't even thought of.

So, enough backstory and justification. You're here because you want to know the answer to the question that I posed in the title. Can it be done? The answer, of course, is YES! And I've thrown together [a little (](https://github.com/recursivecodes/oci_rest_api_esp32)[unofficial)](https://github.com/recursivecodes/oci_rest_api_esp32) library to help you out with this. This is not an "official" SDK, but it will help you make calls to the OCI REST API from your ESP-32. Honestly, I hesitated to even create a library in favor of just demoing how to sign your REST API request in a blog post, but the process turned out to be pretty complex so for portability and repeatability sake, I bundled it into a library. If you've ever tried to manually sign an HTTP request to the OCI REST APIs, you'll know that this is not a fun (nor easy) thing to do. The [docs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm) certainly make it sound easy:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b321b5df-a430-4e91-bd5f-07aa2adbba09/file_1618932418796.png)

For the most part, it's not complicated. But it does require some specialized libraries to encode and sign the request, and thankfully the ESP-32 ships with [mbedtls](https://github.com/ARMmbed/mbedtls) which we can use to do the rather complicated signing operations. Let's dig in and see how to use this library to call the OCI REST APIs.

{{< callout >}}
Heads Up! We're not going to discuss how the library itself signs and makes the HTTPS request. Instead, we'll look at how to use the library in your own Arduino project. If you'd like to see how the library constructs and signs the request, [check the source code on GitHub](https://github.com/recursivecodes/oci_rest_api_esp32/blob/main/src/oci.h).
{{< /callout >}}
Here is a handy table of contents for your navigation pleasure:

- [OCI APIs (Unofficial Library)](#oci-apis-unofficial-library)
  - [Before You Use This...](#before-you-use-this)
  - [About](#about)
  - [Using This Library](#using-this-library)
  - [Documentation](#documentation)
  - [Usage](#usage)
    - [Include the Library](#include-the-library)
    - [Declare Variables for Keys and OCIDs](#declare-variables-for-keys-and-ocids)
    - [Construct OCI Profile](#construct-oci-profile)
    - [Construct OCI Instance](#construct-oci-instance)
    - [Request Object](#request-object)
  - [Response Object](#response-object)
    - [Call API](#call-api)
  - [Publishing and Subscribing to an Oracle Stream](#publishing-and-subscribing-to-an-oracle-stream)
  - [Summary](#summary)

## OCI APIs (Unofficial Library)

The purpose of this library is to let you invoke Oracle Cloud Infrastructure (OCI) REST APIs directly from your device.

### Before You Use This...

You should already be familiar with the OCI REST APIs:

- [Using OCI REST APIs](http://oracle.com/en-us/iaas/Content/API/Concepts/usingapi.htm)

- [REST API Endpoints](https://docs.oracle.com/en-us/iaas/api/#/)

You should also have already created the required keys and collected the necessary OCIDs.  See [Required Keys and OCIDs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#Required_Keys_and_OCIDs).

### About

This library exists to make it easier to make calls to the OCI APIs from your microcontroller. The [request signature](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm) process is complex, and it can be tricky to sign an HTTPS request from a memory-constrained device. I created this library to simplify the process.

{{< callout >}}
Please note! This library has only been successfully tested on an ESP-32. It has not been tested on any other board, and probably won't work on any other board due to memory constraints and dependent libraries.
{{< /callout >}}
### Using This Library

To use this library in your own project, download the [latest release](https://github.com/recursivecodes/oci_rest_api_esp32/releases/latest) from GitHub and unzip it into your Arduino library directory. There are several examples included that you can access by opening 'File' -\> 'Examples' -\> OCI REST for ESP32 in your Arduino IDE.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b321b5df-a430-4e91-bd5f-07aa2adbba09/file_1618932418805.png)

### Documentation

The latest documentation for this library lives online at <https://recursivecodes.github.io/oci_rest_api_esp32/html/index.html>.

### Usage

#### Include the Library
```ino
#include "oci.h"
```



#### Declare Variables for Keys and OCIDs

Declare some variables to hold your keys and OCIDs. Keep this out of source control!
```ino
char tenancyOcid[] = "ocid1.tenancy.oc1..[redacted]]";
char userOcid[] = "ocid1.user.oc1..[redacted]";
char keyFingerprint[] = "1z:[redacted]:99";
char* apiKey = \
"-----BEGIN RSA PRIVATE KEY-----\n"\
"MI[redacted]4h\n"\
...
"Q0[redacted]PGj\n"\
"-----END RSA PRIVATE KEY-----\n";
```



#### Construct OCI Profile

Pass in your `tenancyOcid`, `userOcid`, `keyFingerprint`, `apiKey`. If your private key is password-protected, pass the password in as the 5th argument.
```ino
OciProfile ociProfile(tenancyOcid, userOcid, keyFingerprint, apiKey);
```



#### Construct OCI Instance

Construct an instance of the `Oci` class, passing in your profile. This will initialize the API class and configure the NTP server needed to obtain a timestamp to include with each request.
```ino
Oci oci(ociProfile);
```



#### Request Object

Construct a request object. Pass in the REST endpoint host, the path, HTTP method as the first 3 arguments.
```ino
OciApiRequest listBucketsRequest(osHost, osPath, oci.HTTP_METHOD_GET, {}, 0,  objectStorageRootCert);
```



The example above makes a secure request because a copy of the endpoint's Root CA Cert is passed in as the final argument. You can get a copy of the Root CA Cert in many ways. Here's an example using `openssl` on \*nix compatible systems:
```bash
$ openssl s_client -connect objectstorage.us-phoenix-1.oraclecloud.com:443 -showcerts
```



If you want to make the request insecure (the Root CA Cert will not be validated), pass `NULL` instead of the cert.
```ino
OciApiRequest listBucketsRequest(osHost, osPath, oci.HTTP_METHOD_GET, {}, 0,  NULL);
```



If you want/need to add request headers to the API call, construct and pass an array of `Header` structs in argument 4 and the length of that array in argument 5.
```ino
/* headers to add to the request */
Header reqHeaders[] = { {"opc-client-request-id", "1234-ABCD"} };
OciApiRequest listBucketsRequest(osHost, osPath, oci.HTTP_METHOD_GET, reqHeaders, 1, objectStorageRootCert);
```



### Response Object

Construct a response object. This will ultimately hold the results (or any errors) of your API call.
```ino
OciApiResponse listBucketsResponse;
```



If you want/need to retrieve any headers from the API response, construct and add an array of `Header` structs. Just add the name of the header to retrieve, the value will be populated when the API call is complete.
```ino
/* headers to retrieve from the result (name only) */
Header resHeaders[] = { {"opc-request-id"} };
OciApiResponse listBucketsResponse(resHeaders, 1);
```



#### Call API

Call the `apiCall()` method of `Oci`, passing the request and response objects.
```ino
oci.apiCall(listBucketsRequest, listBucketsResponse);
```



If successful, the `statusCode` property of the response object will be populated with `200`. You can then print/handle the result as needed. In this example, I'm deserializing the JSON string into an object using [ArduinoJson](https://arduinojson.org/).
```ino
if( listBucketsResponse.statusCode == 200 ) {
  // print the <code class="code-inline">opc-request-id</code> from the response headers
  Serial.println(resHeaders[0].headerValue);
  // deserialize and pretty print the response
  Serial.println("List Buckets Response:");
  DynamicJsonDocument doc(6000);
  deserializeJson(doc, listBucketsResponse.response);
  serializeJsonPretty(doc, Serial); 
}
else {
  Serial.println(listBucketsResponse.errorMsg);
}
```



The previous example might produce output such as this:
```json
[
  {
    "namespace": "toddrsharp",
    "name": "archive-demo",
    "compartmentId": "ocid1.compartment.oc1...",
    "createdBy": "ocid1.saml2idp.oc1.../...",
    "timeCreated": "2020-06-18T17:49:14.490Z",
    "etag": "11e0fffe-280c-4311-8d72-755805766815",
    "freeformTags": null,
    "definedTags": null
  },
  {
    "namespace": "toddrsharp",
    "name": "custom-images",
    "compartmentId": "ocid1.compartment.oc1...",
    "createdBy": "ocid1.saml2idp.oc1.../...",
    "timeCreated": "2019-10-24T17:52:47.425Z",
    "etag": "00c17467-2ac3-4257-aef0-a619aa4cab2b",
    "freeformTags": null,
    "definedTags": null
  }
]
```



### Publishing and Subscribing to an Oracle Stream

One of the more exciting possibilities with this library is the ability to publish and consume messages from an Oracle Stream. There's an example included in the library, but let's take a look at how easy it is.

We'll need this library, [ArduinoJson](https://arduinojson.org), and the mbedtls library (available when using ESP-32 boards) to Base64 values.  Install them, and include them in the sketch.
```ino
#include “oci.h"
#include "ArduinoJson.h"
#include "mbedtls/base64.h"
```



Set the required variables for the tenancy and instantiate the library as we did above. Then we'll set a few variables necessary for streaming.
```ino
/* update streaming host with the proper endpoint for your region */
char streamingHost[] = "streaming.us-phoenix-1.oci.oraclecloud.com";
/* populate your stream OCID */
char demoStreamOcid[] = "ocid1.stream.oc1.phx...";
```



Next, create a `postMessage()` function. In this function, we'll create a JSON object and Base64 encode the value of the message. We'll then POST that message to the proper API endpoint.
```ino
void postMessage() {
  
  /* base64 encode the message value */
  const char *input = "{"msg": "hello, world!"}";
  unsigned char output[64];
  size_t msgOutLen;
  mbedtls_base64_encode(output, 64, &msgOutLen, (const unsigned char*) input, strlen((char*) ((const unsigned char*) input)));

  /* construct a JSON object to contain the message to POST */
  char message[150] = "{ "messages": [ { "key": null, "value": "";
  strcat(message, (char*) output);
  strcat(message, "" } ] }");

  // the path to the API endpoint containing the stream OCID
  char postMsgPath[120] = "/20180418/streams/";
  strcat(postMsgPath, demoStreamOcid);
  strcat(postMsgPath, "/messages");
  
  OciApiRequest postMessageRequest(streamingHost, postMsgPath, oci.HTTP_METHOD_POST, {}, 0, NULL, message);
  OciApiResponse postMessageResponse;
  oci.apiCall(postMessageRequest, postMessageResponse);

  if( postMessageResponse.statusCode == 200 ) {
    Serial.println("Post Message Response:");
    DynamicJsonDocument doc(6000);
    deserializeJson(doc, postMessageResponse.response);
    serializeJsonPretty(doc, Serial);  
  }
  else {
    Serial.println(postMessageResponse.errorMsg);
  }  
}
```



To read from a stream, we'll first need a cursor. Create a variable to store the cursor globally (since it'll change with each retrieval) and add a function called `getCursor()`. We'll use `LATEST` as the cursor type.
```ino
char* cursor;

void getCursor() {
  char cursorPath[130] = "/20180418/streams/";
  strcat(cursorPath, demoStreamOcid);
  strcat(cursorPath, "/cursors");

  char createCursorBody[] = "{"partition": "0", "type": "LATEST"}";
  OciApiRequest getCursorRequest(streamingHost, cursorPath, oci.HTTP_METHOD_POST, {}, 0, streamingServiceRootCert, createCursorBody);
  OciApiResponse getCursorResponse;
  oci.apiCall(getCursorRequest, getCursorResponse);

  if( getCursorResponse.statusCode == 200 ) {
    Serial.println("Get Cursor Response:");
    DynamicJsonDocument doc(6000);
    deserializeJson(doc, getCursorResponse.response);
    serializeJsonPretty(doc, Serial);
    int cursorLen = strlen(doc["value"])+1;
    cursor = (char*)malloc(cursorLen);
    strncpy(cursor, (const char*) doc["value"], cursorLen);
  }
  else {
    Serial.println(getCursorResponse.errorMsg);
  }
}
```



Finally, add the `getMessages()` function that will retrieve the messages from the stream.
```ino
void getMessages() {
  char getMsgPath[600] = "/20180418/streams/";
  strcat(getMsgPath, demoStreamOcid);
  strcat(getMsgPath, "/messages?cursor=");
  strcat(getMsgPath, cursor);
  strcat(getMsgPath, "&limit=2");
  
  Header getMsgsHeaders[] = { {"opc-next-cursor"} };
  OciApiRequest getMsgsRequest(streamingHost, getMsgPath, oci.HTTP_METHOD_GET, getMsgsHeaders, 1);
  OciApiResponse getMsgsResponse;
  oci.apiCall(getMsgsRequest, getMsgsResponse);
  
  if( getMsgsResponse.statusCode == 200 ) {
    Serial.println("Get Messages Response:");
    DynamicJsonDocument doc(6000);
    deserializeJson(doc, getMsgsResponse.response);
    serializeJsonPretty(doc, Serial);
    int newCursorLen = strlen(getMsgsHeaders[0].headerValue)+1;
    cursor = (char*)malloc(newCursorLen);
    strncpy(cursor, (const char*) getMsgsHeaders[0].headerValue, newCursorLen);
  }
  else {
    Serial.println(getMsgsResponse.errorMsg);
  }
}
```



Call the functions as necessary:
```ino
Serial.println("\n*** get an OSS cursor ***\n");
getCursor();

Serial.println("\n*** post a message to OSS ***\n");
postMessage();

Serial.println("\n*** retrieve messages from OSS ***\n");
getMessages();
```



### Summary

In this post, we looked at how to call OCI REST APIs from an Arduino (ESP-32) device. Please leave your feedback below if there are any further enhancements that you'd like to see in this library.

