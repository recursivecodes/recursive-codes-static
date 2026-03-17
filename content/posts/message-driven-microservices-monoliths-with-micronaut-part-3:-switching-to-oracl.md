---
title: "Message Driven Microservices & Monoliths with Micronaut - Part 3: Switching to Oracle Streaming Service"
slug: "message-driven-microservices-monoliths-with-micronaut-part-3:-switching-to-oracle-streaming-service"
author: "Todd Sharp"
date: 2021-02-01
summary: "In this post, we'll switch our distributed service e-commerce example to use the fully managed Oracle Streaming Service instead of Kafka for messaging."
tags: ["Cloud", "Developers", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/19f2db6e-2ada-4c16-b686-c7691c4ffa78/banner_stream_5680609_1280.jpg"
---

So far in this series ([part 1](/posts/message-driven-microservices-monoliths-with-micronaut-part-1:-installing-kafka-sending-your-first-message), [part 2](/posts/message-driven-microservices-monoliths-with-micronaut-part-2:-consuming-messages)), we've covered both the "how" and the "why" as it relates to messaging in your modern web applications. We used an e-commerce example to illustrate the need for messaging and we looked in depth at launching a local Kafka broker and creating both an "order" service and a "shipping" service that communicated via the Kafka broker. If you haven't yet read those two posts, I highly recommend that you do so before proceeding here.

Back from reading them? Great, so you're all up to speed! The natural next step in this series, I believe, is to talk about how this approach would be applied in your cloud based microservice (or monolithic) deployments. Like always, the approach will heavily depend on your team's preference. If you have a strong DevOps presence on your team and aren't afraid of getting your hands dirty then you could certainly choose to roll your own Kafka broker in the cloud by turning up the appropriate VM resources and installing and maintaining them. Other teams might shy away from that approach, and that's perfectly understandable as it means there are additional resources to maintain (not to mention pay for). 

For those who choose to avoid running their own broker, there is an awesome option available: Oracle Streaming Service (OSS). OSS is a fully managed, scalable, durable and secure service for consuming and producing messages. I know that sounds like marketing speak (probably because I mostly copied it from our marketing page) but in essence, what we are talking about here is a managed service that provides all of the benefits of a Kafka messaging broker without much of the setup and maintenance. Of course, the first objection at this point is usually from those who are afraid of "vendor lock-in" by tightly coupling their application code to a proprietary SDK. That's a perfectly valid concern, but I would argue that we do this all the time when we consume third-party APIs or use proprietary RDBMS systems, so what's the difference? Still, if it concerns you I have great news: we can modify our order and shipping services to utilize OSS with nothing more than a few changes to our configuration because OSS offers compatibility with the Kafka API. Yeah, it's super cool and I'm going to show you how to do it in this post!

Note: I should mention that I've already [blogged about this topic in depth in a previous post](/posts/easy-messaging-with-micronauts-kafka-support-and-oracle-streaming-service). Therefore, I won't go into much detail about how to set up your stream or the topics. Please read the previous post for those details.

## Switching our Services to use Oracle Streaming Service

In case you missed the note right above this, [please refer to this blog post for information on getting your stream and topics configured](/posts/easy-messaging-with-micronauts-kafka-support-and-oracle-streaming-service). Once you've gone through those steps and have set an environment variable for your `KAFKA_SASL_JAAS_CONFIG` you are ready to create a new configuration file at `resources/application-oss.yml` with the following modifications (update the region in your server URL as necessary):
```yaml
kafka:
  bootstrap:
    servers: streaming.us-phoenix-1.oci.oraclecloud.com:9092
  security:
    protocol: SASL_SSL
  sasl:
    mechanism: PLAIN
    jaas:
      config: ${KAFKA_SASL_JAAS_CONFIG}
```



Now you can run your services with:
```bash
$ ./gradlew run -Dmicronaut.environments=oss
```



And your services will now utilize OSS instead of your local Kafka broker! No, really - that's all it takes! After you place a few "orders" locally, you can confirm that the services work just as they did before. You can also verify the messages via the Oracle Cloud console if you'd like.

My `order-topic`:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/19f2db6e-2ada-4c16-b686-c7691c4ffa78/file_1610755982171.png)

My `shipping-topic`:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/19f2db6e-2ada-4c16-b686-c7691c4ffa78/file_1610755982177.png)

## Summary

In this post, we discussed options for messaging in the cloud and looked at why using Oracle Streaming Service is a valid and smart choice. We then swapped out our local Kafka broker for OSS in our previous e-commerce order and shipping microservices. 

Check out the code used in this post on GitHub:

- <https://github.com/recursivecodes/shipping-svc-kafka>

- <https://github.com/recursivecodes/order-svc-kafka>

Image by [춘성 강](https://pixabay.com/users/%EA%B0%95%EC%B6%98%EC%84%B1-15738132/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=5680609) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=5680609) 

\

