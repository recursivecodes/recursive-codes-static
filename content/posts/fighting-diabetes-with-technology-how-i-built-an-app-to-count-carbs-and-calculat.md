---
title: "Fighting Diabetes With Technology - How I Built An App To Count Carbs And Calculate Insulin Doses"
slug: "fighting-diabetes-with-technology-how-i-built-an-app-to-count-carbs-and-calculate-insulin-doses"
author: "Todd Sharp"
date: 2019-12-18
summary: "When my daughter was diagnosed with diabetes, my first thought was to see what technology is available to help fight the disease. I quickly learned that something was missing so I decided to address that gap."
tags: ["Cloud", "Containers, Microservices, APIs", "Database", "Java", "JavaScript", "Open Source"]
keywords: "Healthcare, microservices, Java, Cloud, Javascript, node.js, container"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/banner_img_20190711_174736_copy.jpg"
---

I'd like to tell you a story about my daughter Ava. She's a typical 13-year-old girl for the most part -- she's smart, very mature and organized - involved in honor chorus, beta club and activities like archery. She can be quiet and shy around new people, but when she's around her family and friends she's a fun, silly, and goofy girl. Last spring and into the summer, Ava started experiencing various symptoms that, at first, seemed unrelated to each other  and kind of appeared to be pretty "normal" signs of adolescence. Things like being tired all the time, always hungry and thirsty. The initial signs weren't too alarming, but when she started getting headaches and blurred vision we became concerned. It finally came to a point where my wife suspected that it might be Diabetes and quickly made an appointment with Ava's doctor. The doctor did a blood test and confirmed my wife's suspicions - Ava's blood sugar level was 475 mg/dl - much higher than the "normal" range of around 100 mg/dl. That night Ava was admitted into the hospital and diagnosed with Type 1 Diabetes. 

We spent the next three days in the hospital getting her blood sugar levels under control and the next few months learning how to manage the disease. We're learning as much as we possibly can about the disease and how to care for Ava and help her learn what it means to be diabetic and how to listen to what her body is telling her. Most importantly though, we're trying to help her realize that the disease does not define her and is nothing that could have been prevented. It's just a challenge that she has to deal with now -- and one that she's strong enough to overcome.

## What Is Diabetes?

So what, exactly, is diabetes? Everyone here has likely heard of it, and there are definitely people here who are affected by the disease in one way or another, but just for clarity let's define it:

Type 1 diabetes (T1D) is an autoimmune disease that occurs when a person's pancreas stops producing insulin, the hormone that controls blood-sugar levels. T1D develops when the insulin-producing pancreatic beta cells are mistakenly destroyed by the body's immune system. Diabetes can't be cured, but diabetics can manage the disease through diet, getting regular exercise and receiving insulin. Every diabetic is different, but a typical day might involve:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_38_25.png)

Blood sugar levels must be constantly monitored throughout the day. Many diabetics accomplish this with glucose monitors that measure levels via a tiny drop of blood that must be drawn with a finger prick. This happens at a minimum of 6 times a day, sometimes more. Diabetics must count carbohydrates at every single meal and most snacks. It's important to be as accurate as possible when doing this, because they use this carbohydrate data, along with their current blood sugar levels, to perform a calculation to determine the amount of insulin they need based on a personalized formula. And this formula may differ for every single meal of the day. Once the insulin dose is calculated, it is administered injection via needles or pens. Finally, diabetics have to be aware of, and manage, unexpected hypo and hyperglycemic events throughout the day. This routine is a reality for millions of diabetics - every single day, without breaks, without "cheat days", no matter what, just to stay alive. 

## Technology To The Rescue!

Thankfully, technology has come a long way as it relates to diabetes management. If the diabetic is lucky enough to have the insurance coverage or be able to afford these things, they have the option to use:

**Continuous Glucose Monitors (CGM)**: These track glucose levels throughout the day via a tiny sensor wire inserted just below the skin, and transmit those levels to a receiver or smart device via Bluetooth and shared via the cloud. A CGM is often hidden by clothing and is more discreet than manual monitoring. No one suspects that a teenager is checking their blood sugar when they're staring at a smart phone.  

**Pumps**: These deliver insulin doses - both constant (known as basal), and on-demand (or, bolus) - via a tiny tube inserted just below the skin. These provide a more reliable stream of insulin and are also more discreet than manual injections. They can also be controlled via smartphone and share data via the cloud. 

**Artificial Pancreas Systems**: To overly simplify things -- an artificial pancreas is a system of hardware and software -- a CGM and a pump -- that work together to deliver insulin as needed to keep blood sugar levels stable. 

All of this technology can be life-changing for a diabetic by enabling them to spend much less time managing their diabetes and allowing them to focus their time and efforts on things **other** than diabetes. As amazing as this technology is, due to cost and other limitations they aren't available or feasible for all patients.

## What's Missing?

So, What's Missing? Well, with or without technology, every diabetic must **manually** **calculate** their carbohydrate consumption and enter that value into an app or device to calculate their insulin dosage. This can be time consuming and error prone which can lead to an over or under dose - something that can be devastating to a diabetic. That's why I decided to build something to simplify the process and increase the accuracy of carb counting. Let's take a look at a demo of my Insulin Helper application for carb counting and insulin calculating.

## PWA & Microservices Powered By Oracle Cloud And Open Source Technologies

Let's take a quick look at the architecture. At the heart of the system is the progressive web application. The application can be installed and run on a laptop, desktop or mobile device. The PWA is backed by three different microservices. Each of the microservices are wrapped in a Docker container that is hosted in [Oracle Cloud Infrastructure Registry (](http://www.oracle.com/cloud/compute/container-registry.html)[OCIR](https://www.oracle.com/cloud/compute/container-registry.html)[)](http://www.oracle.com/cloud/compute/container-registry.html). Those Docker containers are deployed on Kubernetes via an [Oracle Kubernetes Engine (OKE)](https://www.oracle.com/cloud/compute/container-engine-kubernetes.html) cluster within the Oracle Cloud. The user service stores information like target ranges and profile data in an [Autonomous DB](https://www.oracle.com/database/autonomous-database.html) instance. It's a [Helidon SE](https://helidon.io) Java microservice that handles persistence via [Oracle REST Data Services](https://www.oracle.com/database/technologies/appdev/rest.html), aka ORDS. If you're not familiar with ORDS, I'd describe it as: "A way to get data in and out of Oracle DB using REST instead of SQL." It's easy to configure and gives you a simple API for persistence and querying.

The next microservice is the Formula Service - written in Node.JS using the Express framework. This service handles persistence operations for the user-specific formulas used in calculating insulin dosages. For this service, I decided to store the data as a JSON document in autonomous DB using [Simple Oracle Document Access](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/) (SODA). What's SODA? It's a set of NoSQL-style APIs that let you create and store collections of JSON documents in Oracle DB, retrieve them, and query them, without needing to know SQL or how the documents are stored in the database.

The final microservice is the Nutrition Service. This service is also powered by Java, but this time using the [Micronaut](https://micronaut.io) framework. For persistence, this service utilizes [Micronaut Data](https://micronaut-projects.github.io/micronaut-data/latest/guide/) JDBC. Micronaut Data is a database access toolkit that uses Ahead of Time (AoT) compilation to pre-compute queries for repository interfaces that are then executed by a thin, lightweight runtime layer. The Nutrition Service also provides an endpoint for image upload and also interacts with the USDA's [Food Data Central API](https://fdc.nal.usda.gov/api-guide.html) for nutrition information. It's interesting to note, that across the entire architecture there is only one manual SQL query used thanks to ORDS, SODA and Micronaut Data. More on that query later...

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_42_23.png)

Let's look at the food identification process in a little more detail.

## Food Identification

So how is the food actually identified? As you saw in the demo, the user can input foods by either photo or voice, and depending on which method is chosen there are a few different things that happen on the back end. If a photo is used for food identification, it's uploaded to Oracle [Object Storage](https://www.oracle.com/cloud/storage/object-storage.html) and a configured cloud event fires which triggers a serverless function (using [Oracle Functions - our FaaS offering](https://www.oracle.com/cloud/cloud-native/functions/)). The serverless function performs calls to several third-party APIs to perform OCR and image recognition and the results are published to a stream using the [Oracle Streaming Service](https://www.oracle.com/in/big-data/streaming/). The nutrition microservice subscribes to that stream and posts the incoming messages to a server-sent-event endpoint that the PWA client subscribes to. This enables the results to be pushed in real-time to the connected client without the need for polling or socket connections. This provides the front end with image "concepts" or text extracted directly from the image which is used in the next step.

The next step is to grab the nutrition information. If an image concept is identified (For Example, Apple), but no text was extracted, the concept with the highest confidence value is used as a keyword for a search of the USDA's Food Data Central API which returns a list of potential foods. The user can of course override the image concept if the image recognition process wasn't perfect. If an image **did** contain text, or the food was input via voice search, then that text is used as the basis for the Food Data Central query. The user then selects the exact food from the list of foods returned, and the detailed nutritional information is retrieved (again, from Food Data Central).

## Glucose Predictions With Oracle Machine Learning

Let's look now at how the next glucose reading is predicted. For this, I utilized [Oracle Machine Learning Notebooks](https://www.oracle.com/database/technologies/datawarehouse-bigdata/oml-notebooks.html) to construct and train a model for my predictions. These notebooks are freely available with all Autonomous DB instances. 

### Step 1: Create View

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_49_57.png)

Essentially what we're doing here in step one is to create a single "unified" view of the data that will be used to train the model. The beauty of this query is that even though we've stored our data in three distinct schemas, sometimes in a different model altogether like JSON, we still have the ability to combine them in a familiar "tabular" format via simple queries. In this case, we combine the user, formula, and the nutrition/meal data into a single materialized view.

### Step 2: Create Model

### ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_50_26.png)

Next, we create our model. I've chosen a linear regression mining function, but there are many, many different options to choose from when it comes to creating machine learning models in Oracle DB.

### Step 3: Create Train & Test Datasets

### ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_50_36.png)

The next step is to create our train and test datasets. We use a sample from the combined materialized view from step one to train and the remaining data to test our model.

### Step 4: Make Predictions With Upper & Lower Bounds

### ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_50_47.png)

Next, we make predictions against our test data with upper and lower bounds to determine our accuracy. 

### Step 5: Make Prediction From App Data

### ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c33dbb8f-7ae3-49d8-b068-35518e9d5079/2019_11_14_15_50_59.png)

And finally, we finish we the only SQL query that is used in the entire architecture: a query that predicts the next glucose reading based on the inputs provided from the current meal.

## Summary

I believe what I've created here in just a few short weeks can be developed into something that makes carbohydrate counting much easier for many diabetics, especially those who are younger or newly diagnosed. While that's truly important, what I'd like to leave you with today is this: Everyone in this room and those watching online right now have a unique set of talents, skills and abilities. And we're living in an age of amazing technology - things like AI and ML are already doing so much to improve the lives of so many people with needs. My challenge to you is this: find something that is important to you. Something you're truly passionate about. Maybe it's something that affects you directly, or someone that you love. Maybe it affects total strangers - it doesn't matter. But take advantage of the technology we have available and use your skills and abilities to do **something** improve the lives of those affected by it. Let's do more than just build software that counts widgets or manages e-commerce. Those things are great, but let's do **something** that will make this world a better place.
