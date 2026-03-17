---
title: "Message Driven Microservices & Monoliths with Micronaut - Part 1: Installing Kafka & Sending Your First Message"
slug: "message-driven-microservices-monoliths-with-micronaut-part-1:-installing-kafka-sending-your-first-message"
author: "Todd Sharp"
date: 2021-01-19
summary: "In this post, we're going to start looking at what it takes to implement messaging between your distributed cloud-based services. We'll install Kafka and create an e-commerce microservice that sends \"order\" messages to a queue."
tags: ["Cloud", "Developers", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/592f02d5-a0e7-4d54-9043-fe4075f647cd/banner_anne_nygard_rauuoanvgca_unsplash.jpg"
---

One of the biggest challenges that developers face when working in a microservice environment is ensuring data consistency. Distributed services must be able to communicate with each other in order for your application to deliver all of the requirements and functionality that your users expect. Think about an e-commerce application, for example. Your shipment service needs to know when an order is placed, right? Your order service, in turn, should also know when it has been shipped! Even if your application is less "pure microservice" and more of a hybrid approach you probably have at least a few distributed services that ultimately need to communicate with each other. Communication between distributed services is challenging and I want to show you a few tricks for simplifying this difficult task by using Micronaut and some fairly popular messaging solutions. We'll break this down in the next few posts to hopefully help you to implement messaging in your applications using some popular open source tools as well as an Oracle Cloud based option that can be plugged into your service with very little setup and configuration.

You may be asking yourself why this approach is even necessary. The obvious and traditional approach would be to have your services communicate with each other with HTTP via REST endpoints, but that's asking for trouble. What happens if one (or more) of your services are down? That could mean that an incoming order to your application never gets shipped, and that's not good for business! A better option would be to use a messaging queue to pass system events and messages between your services. In this post, we will get started by setting up Kafka to use as our message broker and getting our initial services set up to talk to the Kafka broker.

I'm going to focus on Micronaut in this series because it solves the problem of messaging in your Java services with built-in support for Kafka (as well as MQTT which we'll look at later on in this series). We'll walk through the steps together, but if you want to read more about the built-in support for Kafka in Micronaut, [bookmark and refer to the docs](https://docs.micronaut.io/latest/guide/index.html#kafka). In fact, I've covered some of the technical details on how to connect [Micronaut to an Oracle Cloud Streaming Service endpoint in a previous blog post](/posts/easy-messaging-with-micronauts-kafka-support-and-oracle-streaming-service), but in this series, we're going to discuss more of the "why" along with the "how" to hopefully give the concept more context and demonstrate some use cases.

## Installing Kafka Locally

The first thing we'll do here is to download Apache Kafka so that we can use it as our message broker locally. I'm quite sure you've heard of Kafka - it's massively popular and in use at many companies today. That said, my experience has shown me that no matter how popular a library, tool, or service is there is often a good portion of developers who are still unfamiliar or uncomfortable with said tool or service. If that's you, no worries - let's quickly discuss. Kafka is an open source streaming tool that lets you produce (sometimes called publish) key/value based messages to a queue and later on consume (or subscribe to) the queue in the order in which they were published. There is much more to the Kafka ecosystem, but if you're new to working with it then you now have enough basic knowledge to move forward with this series. 

Let's install Kafka. Most of these instructions are found on the [Kafka Quickstart](https://kafka.apache.org/quickstart), but I'll post them here to save you a click. You'll need to first [download](https://kafka.apache.org/downloads) the latest binary version of Kafka (which as of the time of this blog post is currently 2.7.0). 
```bash
$ curl -O https://ftp.wayne.edu/apache/kafka/2.7.0/kafka_2.13-2.7.0.tgz
```



Next, unzip it and switch to the directory where it was unzipped.
```bash
$ tar xvf kafka_2.13-2.7.0.tgz && cd kafka_2.13-2.7.0/
```



Kafka depends on a service called ZooKeeper (for now, but this will go away in the future). Start ZooKeeper in a console window/tab like so:
```bash
$ bin/zookeeper-server-start.sh config/zookeeper.properties
```



Now we can start the Kafka Broker Service itself. In another console/tab, run:
```bash
$ bin/kafka-server-start.sh config/server.properties
```



Cool, easy. Now that Zookeeper and the Kafka Broker are running (the broker runs on \`localhost:9092\`), open a third console window/tab. We'll now create a few "topics" in our running broker that we'll use later on from our Micronaut service. Since we're going with an "e-commerce" example here, create an "Order" topic by using the \`kafka-topics.sh\` script in the \`bin\` directory. 
```bash
$ bin/kafka-topics.sh --create --topic order-topic --bootstrap-server localhost:9092
```



Kafka includes a few utility scripts that we can use to test producing and consuming to the brand new topics. If you want to test out the new topics, a new console window and start a producer.
```bash
$ bin/kafka-console-producer.sh --topic order-topic --bootstrap-server localhost:9092
>
```



You'll notice that the producer script gives you a prompt that can be used to enter your message. Before you try it out, open one more console window/tab and start a consumer to listen to the topic:
```bash
$ bin/kafka-console-consumer.sh --topic order-topic --from-beginning --bootstrap-server localhost:9092
```



The consumer script runs and patiently waits for an incoming message. Jump back to your producer console and type a message - anything you'd like.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/592f02d5-a0e7-4d54-9043-fe4075f647cd/file_1610647729366.png)

We've got our broker up and running and we've published a message to confirm that our topic works as expected. Now let's move on to creating our "Order" service with Micronaut.

## Creating the Order Service

For our e-commerce example, we'll need to first create our Micronaut app. The easiest way to do this is to use [Micronaut Launch](https://micronaut.io/launch/). We'll use Java 11, Gradle, and add Kafka and Netty Server.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/592f02d5-a0e7-4d54-9043-fe4075f647cd/file_1610651408263.png)

Once the bootstrapped application has been downloaded, we can unzip it and open it up in our favorite editor.
```bash
$ unzip order-svc-kafka.zip -d order-svc-kafka
$ cd order-svc-kafka && idea build.gradle
```



### Order Service Config

Let's set up a config file for the app that will be used when we are connecting up to our local Kafka broker. Create a new file in `resources/` called `application-local.yml` and populate it as such:
```yaml
micronaut:
  application:
    name: orderSvc
  server:
    port: 8080
```



To make sure that this configuration is used when we launch the application, pass in the following system property when launching the app: -Dmicronaut.environments=local.

### Creating a Domain, Service, and Controller

Our order microservice will need a domain object to represent our e-commerce orders, a service to mock persistence, and a controller to handle incoming requests. First, create a class to represent the `Order` in a package called `domain` and add 4 properties: `id`, `customerId`, `totalCost` and `shipmentStatus`. Add a constructor and getters/setters as you would any normal domain entity. Of course, this object is greatly simplified, but I think it properly illustrates the point without needlessly complicating this example.
```java
package codes.recursive.domain;
import io.micronaut.core.annotation.Introspected;
@Introspected
public class Order {
    private Long id;
    private Integer customerId;
    private Double totalCost;
    private ShipmentStatus shipmentStatus;

    public Order(Long id, Integer customerId, Double totalCost, ShipmentStatus shipmentStatus) {
        this.id = id;
        this.customerId = customerId;
        this.totalCost = totalCost;
        this.shipmentStatus = shipmentStatus != null ? shipmentStatus : ShipmentStatus.PENDING;
    }
    public Long getId() {
        return id;
    }
    public void setId(Long id) {
        this.id = id;
    }
    public Integer getCustomerId() {
        return customerId;
    }
    public void setCustomerId(Integer customerId) {
        this.customerId = customerId;
    }
    public Double getTotalCost() {
        return totalCost;
    }
    public void setTotalCost(Double totalCost) {
        this.totalCost = totalCost;
    }
    public ShipmentStatus getShipmentStatus() {
        return shipmentStatus;
    }
    public void setShipmentStatus(ShipmentStatus shipmentStatus) {
        this.shipmentStatus = shipmentStatus;
    }
}
```



Add a simple enum for the ShipmentStatus:
```java
package codes.recursive.domain;
public enum ShipmentStatus {
    PENDING, SHIPPED
}
```



Next, let's create an `OrderService` to simulate a proper persistence tier. Certainly, Micronaut Data would be a logical choice for a true persistence tier, but again I'd like to keep this service focused on the messaging aspect so I will forgo that aspect for this demo and just use a simple `List` to store orders in memory whilst the service is running.
```java
package codes.recursive.service;

import codes.recursive.domain.Order;

import javax.inject.Singleton;
import java.util.ArrayList;
import java.util.List;

@Singleton
public class OrderService {
    public List<Order> orders = new ArrayList<>();

    public Order getOrderById(Long id) {
        return orders.stream().filter(it -> it.getId().equals(id)).findFirst().orElse(null);
    }

    public List<Order> listOrders() {
        return orders;
    }

    public void updateOrder(Order order) {
        Order existingOrder = getOrderById(order.getId());
        int i = orders.indexOf(existingOrder);
        orders.set(i, order);
    }

    public Order newOrder(Order order) {
        order.setId((long) orders.size());
        this.orders.add(order);
        return order;
    }
}
```



And now we'll add a controller that will give our service some HTTP endpoints for our standard CRUD operations. The `OrderController` will have methods for listing orders, getting a single order, creating a new order, and updating an existing order. Nothing fancy, just a way to invoke our `OrderService` methods. 
```java
package codes.recursive.controller;

import codes.recursive.domain.Order;
import codes.recursive.service.OrderService;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.*;

import java.util.List;

@Controller("/order")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @Get("/")
    public HttpResponse<List<Order>> listOrders() {
        return HttpResponse.ok(
                orderService.listOrders()
        );
    }

    @Get("/{id}")
    public HttpResponse getOrder(Long id) {
        Order order = orderService.getOrderById(id);
        if( order != null ) {
            return HttpResponse.ok(
                    order
            );
        }
        return HttpResponse.notFound();
    }

    @Post("/")
    public HttpResponse<Order> newOrder(@Body Order order) {
        return HttpResponse.created(
                orderService.newOrder(order)
        );
    }

    @Put("/")
    public HttpResponse updateOrder(@Body Order order) {
        orderService.updateOrder(order);
        return HttpResponse.ok();
    }

}
```



The basic order microservice is now ready for action. We can start it up with:
```bash
$ ./gradlew run -Dmicronaut.environments=local
```



## Testing the Order Service

We could certainly write some unit tests to confirm that our Order Service is working as expected (and I strongly encourage unit tests), but I find the visual impact of invoking the endpoints via cURL to be more impactful for blog posts. We'll hit a few endpoints in our terminal to make sure things are working as expected. 

First, let's add a few orders. Note that the `ShipmentStatus` will default to `PENDING`, so there is no need to pass that in when creating a new order.

[]

We can now list all orders with a `GET` request to `/order`.
```bash
$ curl -s localhost:8080/order | jq
[
  {
    "id": 0,
    "customerId": 1,
    "totalCost": 19.17,
    "shipmentStatus": "PENDING"
  },
  {
    "id": 1,
    "customerId": 1,
    "totalCost": 9.44,
    "shipmentStatus": "PENDING"
  }
]
```



Or get a single order by passing in the order id.
```bash
$ curl -s localhost:8080/order/0 | jq
{
  "id": 0,
  "customerId": 1,
  "totalCost": 9.44,
  "shipmentStatus": "PENDING"
}
```



## Publishing Orders

We've set up Kafka and created a basic order service so far. In the next step, we'll publish our orders to the `order-topic` that we set up earlier. Since we chose the 'Kafka' feature above when we bootstrapped the application via Micronaut Launch, all of the dependencies that we need are already set up in our project. We'll need to update our configuration file to tell Micronaut where our Kafka broker is running, so open up `resources/application-local.yml` and add the broker config info. When it's complete, the whole config file should look like so:

[]

Now we can use the [Micronaut CLI](https://docs.micronaut.io/latest/guide/index.html%3Ch1%3EbuildCLI) to add an `OrderProducer` with the following command.

[]

Which will create a basic producer that looks like this:
```java
package codes.recursive.messaging;

import io.micronaut.configuration.kafka.annotation.KafkaClient;

@KafkaClient
public interface OrderProducer {

}
```



We just need to create a single message signature for `sendMessage` and annotate it with `@Topic` to point it at our `order-topic`. 
```java
package codes.recursive.messaging;

import io.micronaut.configuration.kafka.annotation.KafkaClient;
import io.micronaut.configuration.kafka.annotation.KafkaKey;
import io.micronaut.configuration.kafka.annotation.Topic;

@KafkaClient
public interface OrderProducer {
    @Topic("order-topic")
    void sendMessage(@KafkaKey String key, String value);
}
```



Now we can inject our `OrderProducer` into our `OrderService`.
```java
private final OrderProducer orderProducer;

public OrderService(OrderProducer orderProducer) {
    this.orderProducer = orderProducer;
}
```



And modify the `newOrder` method in `OrderService` to use the `OrderProducer` to publish the order as a message to the topic. Note that the order will be serialized as JSON and the order JSON will be the body of the message. We're using a random UUID as the message key, but you can use whatever unique identifier you'd like.
```java
public Order newOrder(Order order) {
    order.setId((long) orders.size());
    this.orders.add(order);
    orderProducer.sendMessage(UUID.randomUUID().toString(), order);
    return order;
}
```



Before we can test this, make sure that you have the simple Kafka consumer still running in a terminal window (or start a new consumer if you've already closed it from earlier) on the `order-topic`.
```bash
$ bin/kafka-console-consumer.sh --topic order-topic --bootstrap-server localhost:9092
```



Now add a new order to the system via cURL:
```bash
$ curl -s -H "Content-Type: application/json" -X POST -d '{"customerId": 1, "totalCost": 34.53}' localhost:8080/order | jq
{
  "id": 2,
  "customerId": 1,
  "totalCost": 34.53,
  "shipmentStatus": "PENDING"
}
```



And observe the consumer console which will receive the message for the new order!
```bash
$ bin/kafka-console-consumer.sh --topic order-topic --bootstrap-server localhost:9092
{"id":2,"customerId":1,"totalCost":34.53,"shipmentStatus":"PENDING"}
```



## Summary

We covered quite a bit in this post, but hopefully you found it easy to follow and helpful. We set up a local Kafka broker, created a basic e-commerce service for handling orders and published the incoming orders to our Kafka broker. In the next post, we'll add a shipment service that will consume the order messages, ship the orders and publish a shipment confirmation back to the order service for updating the order status for our users. If you have any questions, please leave a comment below or contact me via [Twitter](https://twitter.com/recursivecodes). 

Check out the code used in this post on GitHub at <https://github.com/recursivecodes/order-svc-kafka>.

Photo by [Anne Nygård](https://unsplash.com/@polarmermaid?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/envelope?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

