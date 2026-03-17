---
title: "Oracle Functions: Invoking Functions Automatically With Cloud Events"
slug: "oracle-functions-invoking-functions-automatically-with-cloud-events"
author: "Todd Sharp"
date: 2019-08-13
summary: "In this post we'll look at invoking serverless functions automatically in response to a cloud event."
tags: ["Cloud", "Containers, Microservices, APIs", "Java"]
keywords: "serverless, Java, Events, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/banner_danny_froese_jxkclzhhrjg_unsplash.jpg"
---

I've written several posts here on the developer blog that show you how to create and invoke your serverless functions, but so far we've only covered how to manually invoke those functions or programmatically invoke them via the OCI Java SDK. Today I want to show you a much more powerful way to invoke your functions that responds automatically to certain actions in your cloud tenancy. This method involves utilizing the [recently announced Cloud Events service](https://blogs.oracle.com/cloud-infrastructure/oracle-cloud-infrastructure-events-service-now-generally-available) which freely available within your cloud tenancy. 

In this post, we'll look at triggering an Oracle Function when an object is uploaded to an Object Storage bucket in your tenancy. We'll use cloud events to call our function which will retrieve metadata from the image. 

Before we get into this post, here's a list of my previous blog posts. If you're new to Oracle Functions, these posts will help get you started and should answer any questions you may have about creating and manually invoking your functions:

- [Getting Started](/posts/oracle-functions:-serverless-on-oracle-cloud-developers-guide-to-getting-started-quickly)
- [Connecting A Serverless Function to Autonomous DB with Java](/posts/oracle-functions-connecting-to-an-atp-database)
- [Connecting A Serverless Function to Autonomous DB with Node.JS](/posts/oracle-functions-connecting-to-atp-with-nodejs)
- [Invoking A Serverless Function with OCI Java SDK](/posts/oracle-functions-invoking-functions-with-the-oci-sdk)
- [An Easier Way To Work With Autonomous DB](/posts/oracle-functions-an-easier-way-to-talk-to-your-autonomous-database)

## Creating A Serverless Application

Let's start by creating a brand new serverless application that we can use for our function. In my previous posts, we created the application via the Fn CLI, so this time let's use the cloud dashboard instead.  Start by selecting Developer Services -\> Functions in the sidebar menu.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/2019_08_12_12_23_13.jpg)

Next, click 'Create Application' and then populate the form on the next page. Note, your previously created VCNs are listed here and you can select the appropriate subnet instead of manually providing the OCID of the subnet via the Fn CLI:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/2019_08_12_10_05_02.jpg)

Also note in the screenshot above that we can provide our log URL from Papertrail so we can view our log output later on.

Let's head back to our local terminal to create the application:

`fn init --runtime java cloud-events-demo-fn`

We'll add two dependencies to the `pom.xml` file. One for the `cloudevents-api`, and another for `metadata-extractor` so we can extract the image metadata later on:
```xml
<dependency>
    <groupId>io.cloudevents</groupId>
    <artifactId>cloudevents-api</artifactId>
    <version>0.2.1</version>
</dependency>
<dependency>
    <groupId>com.drewnoakes</groupId>
    <artifactId>metadata-extractor</artifactId>
    <version>2.12.0</version>
</dependency>
```



We'll write a test for our function next. You'll need to manually upload a sample image to your object storage bucket first. Then use the following JSON structure for your test (substituting the proper values for your test image name, tenancy name and bucket name):
```json
{
 "cloudEventsVersion": "0.1",
 "eventID": "[UUID]",
 "eventType": "com.oraclecloud.objectstorage.createobject",
 "source": "objectstorage",
 "eventTypeVersion": "1.0",
 "eventTime": "2019-07-31T17:41:03Z",
 "schemaURL": null,
 "contentType": "application/json",
 "extensions": {
  "compartmentId": "ocid1.compartment.oc1...."
 },
 "data": {
  "compartmentId": "ocid1.compartment.oc1....",
  "compartmentName": "[compartment name]",
  "resourceName": "[test image name.jpg]",
  "resourceId": "",
  "availabilityDomain": "all",
  "freeFormTags": {
  
  },
  "definedTags": {
  
  },
  "additionalDetails": {
   "eTag": "[UUID]",
   "namespace": "[tenancy name]",
   "archivalState": "Available",
   "bucketName": "[bucket name]",
   "bucketId": "ocid1.bucket.oc1.phx..."
  }
 }
}
```



Once you've uploaded your test image and modified that JSON, you'll be able to use it in your test which looks like so:
```java
package com.example.fn;

import com.fnproject.fn.testing.*;
import org.junit.*;

import static org.junit.Assert.*;

public class HelloFunctionTest {

    @Rule
    public final FnTestingRule testing = FnTestingRule.createDefault();

    @Test
    public void shouldReturnGreeting() {
        String event = "[your test image event JSON]";
        testing.givenEvent().withBody(event).enqueue();
        testing.thenRun(HelloFunction.class, "handleRequest");

        FnResult result = testing.getOnlyResult();
        assertTrue(result.isSuccess());
    }

}
```



The test will obviously fail at this point, so let's implement the function so that our test passes. Since Oracle Cloud Events conform to the [CNCF Cloud Events spec](https://cloudevents.io/), we can safely type our incoming parameter as a `CloudEvent` and the FDK will handle properly serializing the parameter when the function is triggered. Once we have our CloudEvent data we can construct a URL that points to our image (a public image in this case) and open that URL as a stream that can be passed to the metadata extractor.
```java
package com.example.fn;

import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import com.drew.metadata.Metadata;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cloudevents.CloudEvent;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.Map;

public class HelloFunction {

    public Metadata handleRequest(CloudEvent event) throws IOException, ImageProcessingException {
        ObjectMapper objectMapper = new ObjectMapper();
        Map data = objectMapper.convertValue(event.getData().get(), Map.class);
        Map additionalDetails = objectMapper.convertValue(data.get("additionalDetails"), Map.class);

        String imageUrl = "https://objectstorage.us-phoenix-1.oraclecloud.com/n/" +
                additionalDetails.get("namespace") +
                "/b/" +
                additionalDetails.get("bucketName") +
                "/o/" +
                data.get("resourceName");

        InputStream imageStream = new URL(imageUrl).openStream();
        Metadata metadata = ImageMetadataReader.readMetadata(imageStream);
        System.out.println(objectMapper.writeValueAsString(metadata));

        //todo: do something with the metadata

        return metadata;
    }

}
```



At this point our test will pass and we can deploy the function to our application with:

`fn deploy --app cloud-events-demo`

We can manually invoke this by passing our event JSON string:

`echo "[event JSON string]" | fn invoke cloud-events-demo cloud-events-demo-fn`\
\
And we'll see that our function works as expected. Now let's create the cloud event rule!

## Creating A Cloud Event

To create a new cloud event rule, click on Application Integration -\> Events Service in the sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/2019_08_12_10_31_11.jpg)

Click on 'Create Rule' and populate the form:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/2019_08_12_10_41_58.jpg)

Note the conditions above. I've selected 'Object Storage' as the 'Service Name' and 'Object Storage - Create Object' as the 'Event Type'. I'm also able to filter the events by attributes - in this case, I'm only interested in uploads to my specific bucket. There are a number of event types and filter possibilities that you can choose from. Refer to the [service documentation for more information](https://docs.cloud.oracle.com/iaas/Content/Events/Reference/eventsproducers.htm) on the event types and filters. The rest of the form looks like this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/2019_08_12_10_32_18.jpg)

Here we are able to specify the action we would like taken when this cloud event is fired. In this case, we want to call our serverless function, but we could also publish to an Oracle Stream or invoke a notification. Click 'Create Rule' and the rule will be immediately available for use.

## Testing The Rule

To test the rule, simply upload a file to the bucket that you have specified in your rule. One way to do that is via the OCI CLI:

`oci os object put --bucket-name object-upload-demo-public --file /Users/trsharp/Pictures/test.jpg`

After a few seconds you can check your papertrail logs to see the metatadata that we wrote to `System.out`. Here is a formatted example from a test image that I have uploaded:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2401df80-2361-466a-b883-612ca483381c/2019_08_12_12_53_18.jpg)

## Summary

In this post we created a serverless function to extract image metadata that is automatically triggered upon an image being uploaded to a given object storage bucket. We learned that cloud event rules can be tied to various actions within our OCI tenancy such as Database and Object Storage activities and can automatically trigger serverless functions, notifications or publish items to an Oracle Stream.

[Photo by ][Danny Froese](https://unsplash.com/@dannyfroese?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/cloud-event?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
