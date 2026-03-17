---
title: "The Trials And Tribulations of Creating An SDK - Part 1"
slug: ""
author: "Todd Sharp"
date: 2019-02-28
summary: ""
tags: ["Misc"]
keywords: "REST, API, REST API, SDK"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/45/banner_54e1d4424253ad14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

<div>

<div>

I'd like to tell you a story. It's an inspiring tale. One of mistakes and perseverance, but full of learning and growth. It's the epic about my adventures in creating an SDK. I'm a software developer - full stack, thank you very much. I've been getting paid to write code for about 15 years now, but in reality I've been a developer since I was born. Some of us are like that - we're problem solvers, tinkerers who can't sit still and crave the next adrenaline rush that comes with fixing a bug or implementing a shiny new feature. We live for that high. You may know someone like me. Hell, you may be one of us. If so, join me in the spinning of this yarn. You'll laugh at my mistakes, you'll cringe at some of the things I did, but in the end I hope you'll learn something. I know I did, and I'd like to share those learnings with you in hopes that you'll be inspired to try something new. Because that's how we grow as developers - even as people. By moving out of our comfort zone and taking a "leap of faith" into the unknown. Let's get into it, shall we?

</div>

</div>

<div>

------------------------------------------------------------------------

</div>

<div>

<div>

### Preamble

Let's first define a few things. What's an SDK? You've heard the term before I'm sure. And if you've been a developer for more than a day you've also heard the term API. They're both kind of "buzzword-y" terms that are sometimes over/misused, but they are important so let's lay them out in an easy way to understand so that it's clear what we're talking about.

#### API

An API, or Application Programming Interface, is a way to expose methods and functionality to consumers of your application. Wait, didn't I say that we'd define these terms in a way that's easy to understand?? Let me start over.

What if we thought of your software like a retail transaction. Say you wanted to buy something. Maybe you want to purchase a new car. Think of an API like a car salesmen. The salesman has something that you want - a vehicle. In order to obtain that vehicle you have to provide him with something in return - money and your identification to prove who you are.

An API works the same exact way. It has something that you want (data). In order to give it to you it expects something in return (a specifically formatted request and possibly some credentials). By far, the most common architecture used for APIs these days is Representational State Transfer (REST). In ancient and much more masochistic days in a far away land there once existed a protocol named SOAP. But, us elders don't speak much of those days anymore and I'm pretty sure it has been outlawed by the Geneva Convention. (You've likely read about SOAP - maybe even used it. For the uninitiated, let me present you with the most [legendary narrative on SOAP that ever existed](http://harmful.cat-v.org/software/xml/soap/simple).)

So if I could sum them up in a single sentence, I'd say that REST APIs use HTTP methods (PUT, GET, etc) to perform operations (like editing a user or creating a new item) and transfer data (such as retrieving a list of groups) in a (sometimes, but not necessarily always) secure manner using some sort of authentication (perhaps a JSON Web Token) and/or request signing mechanism.

Let's get back to the vehicle example. The thing is, sometimes a vehicle purchase isn't that easy. What if the specific vehicle you wanted to purchase was only available from another country? What if it was a super complex vehicle that could be configured in many different ways depending on the options that you chose? What if the salesman accepted euros but you only had rupees?

(Note to self: this has got to be the craziest analogy ever used to explain an API).

#### SDK

So purchasing a vehicle can get crazy, yeah? Well, maybe not so much, but let's go with it, OK? An SDK (Software Development Kit) is a way to work with with an API much easier manner than using via raw HTTP requests. Usually a REST API call via HTTP might look something like this:

    GET /n//b//o/dummy_object HTTP/1.1
    Host: objectstorage.us-phoenix-1.oraclecloud.com
    connection: keep-alive
    accept-encoding: gzip, deflate
    accept: */*
    user-agent: python-requests/2.10.0
    date: Fri, 19 Aug 2016 23:43:49 GMT
    authorization: 

And that's fine. If you're a web developer that should make sense to you. It's a GET request to an endpoint with a few variables in the path and in return you'll receive some headers and a JSON string in the body. The thing is, much like our fictional car buying experience, APIs can get complicated. Operations can have many parameters and request signing schemes can be complex which means you might end up spending more time in the API documentation than you might otherwise feel is sane.

To tie it back to the car buying analogy, what if we could introduce an intermediary into the picture? Perhaps this fictional purchasing agent is an expert in the field of vehicle transactions. In fact, she's so amazing that she can speak both your language and the manufacturer's language thus facilitating easy communication between both of you. She knows all of the forms necessary to fill out to import your vehicle, and even has a few shortcuts to make filling them out easier. Wouldn't that make this contrived and overly complex car purchasing experience much easier?

And that's an SDK. To repeat my above attempt at summarizing an SDK in a single sentence, I'll say that an SDK is an interface to perform API operations in a simplified manner that is implemented in a specific programming language with a normalized authentication and/or request signing process that allows developers to work with potentially raw data in a way that is native to their given environment.

</div>

</div>

<div>

------------------------------------------------------------------------

</div>

<div>

<div>

### Putting A Bow On It

Just like those obnoxious luxury car commercials that seem to imply that we're all just rolling in enough money to surprise our significant other with a present that likely costs more than most of us can feasibly and comfortably afford, let me wrap up this entry with a nice large bow.

APIs and SDKs are things we work with a lot. I created one, and I learned a lot in doing so. I'm sharing my experience in hopes that you can laugh and learn with me and in this first entry we laid the groundwork for future posts where I'll cover lessons learned.

If you enjoyed this post, please share it with someone. And join me on Twitter where I like to interact with other fellow geeks and nerds [\@recursivecodes](https://twitter.com/recursivecodes).

</div>

</div>

\

Image by [12019](https://pixabay.com/users/12019-12019) from [Pixabay](https://pixabay.com)
