---
title: "Message Driven Microservices & Monoliths with Micronaut - Part 2: Consuming Messages "
slug: "message-driven-microservices-monoliths-with-micronaut-part-2:-consuming-messages"
author: "Todd Sharp"
date: 2021-01-25
summary: "In this post, we'll continue looking at messaging for distributed services. This time we'll consume the messages that we produced in the last blog post."
tags: ["Cloud", "Developers", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/e0e385c8-dde8-49c1-9e7a-ecf546e15af2/banner_fish_3062034_1280.jpg"
---

In our [last post](/posts/message-driven-microservices-monoliths-with-micronaut-part-1:-installing-kafka-sending-your-first-message), we talked about why messaging is important in our modern applications. We set up a local Kafka broker and created a basic e-commerce microservice that handled orders and published a message to our Kafka broker when new orders are received. This example illustrates the importance of reliable messaging between microservices because it shows a real-life example of the need for two services to communicate with each other in a decoupled and fail-safe manner. 

But that was only half of the story. Producing messages and consuming them from a simple terminal window is cool, but to further illustrate the example we can take it a step further and create a basic "shipping" service that consumes the messages published from our order service, "ships" the order and then notifies the order service of the updated shipping status.

## Create a Shipping Topic

Before we create the shipping service, first add another topic to our Kafka broker. We can do this the same exact way that we created the order topic by using the script located in the Kafka `bin` directory.

[]

That's all of the pre-work that we need to do for our shipping service.

## Create the Shipping Service

Now we'll bootstrap the shipping service using [Micronaut Launch](https://launch.micronaut.io/) just like we did our order service. Choose Java 11, Gradle and add the Netty Server and Kafka features again.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/e0e385c8-dde8-49c1-9e7a-ecf546e15af2/file_1610755633925.png)

Download it, unzip it and open it with your favorite IDE.

[]

Our config will be handled like it was in the order service, so create a file at `resources` called `application-local.yml`. This time, set the shipping service to run on port `8081` to prevent any conflicts with the order service.
```yaml
micronaut:
  application:
    name: shippingSvc
  server:
    port: 8081
```



Let's create a `Shipment` domain object to represent the order shipment with the properties `id`, `orderId` and a `shippedOn` date. 
```java
package codes.recursive.domain;

import com.fasterxml.jackson.annotation.JsonFormat;
import io.micronaut.core.annotation.Introspected;

import java.util.Date;

@Introspected
public class Shipment {
    private Long id;
    private Long orderId;
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
    private Date shippedOn;

    public Shipment(Long id, Long orderId, Date shippedOn) {
        this.id = id;
        this.orderId = orderId;
        this.shippedOn = shippedOn;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getOrderId() {
        return orderId;
    }

    public void setOrderId(Long orderId) {
        this.orderId = orderId;
    }

    public Date getShippedOn() {
        return shippedOn;
    }

    public void setShippedOn(Date shippedOn) {
        this.shippedOn = shippedOn;
    }
}
```



For model consistency, add the `Shipment` object as shown above to the `order-svc-kafka` project and bring the `Order` and `ShipmentStatus` model objects into this `shipment-svc-kafka` project as well. We'll want to keep our domain objects in sync and even though this presents a bit of redundant code it is necessary. In reality, you may want to create a separate Java project to manage your shared model objects and import that into each project, but that's an architecture decision that seems to be somewhat controversial with developers so I'll leave the implementation up to you and your team's best practices. Let me remind you what they look like here for the sake of this demo.
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
```java
package codes.recursive.domain;

public enum ShipmentStatus {
    PENDING, SHIPPED
}
```



Now we'll need a `ShippingService`. Again, instead of properly persisting the shipments to a database backend I will be using a synchronized `List` to store them in memory so that it's thread-safe. Using a synchronized list isn't the most performant solution since it locks the `List` on access, but since this is just for mock persistence purposes in lieu of a real backend and it serves the purpose of keeping the faux database thread-safe, we'll go with it. 
```java
package codes.recursive.service;

import codes.recursive.domain.Order;
import codes.recursive.domain.Shipment;
import codes.recursive.messaging.ShipmentProducer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Singleton;
import java.util.*;

@Singleton
public class ShippingService {
    private static final Logger LOG = LoggerFactory.getLogger(ShippingService.class);
    
    private final ShipmentProducer shipmentProducer;
    private final List<Shipment> shipments = Collections.synchronizedList(new ArrayList<>());

    public ShippingService(ShipmentProducer shipmentProducer) {
        this.shipmentProducer = shipmentProducer;
    }

    public Shipment getShipmentById(Long id) {
        Shipment shipment;
        synchronized (shipments) {
            shipment = shipments.stream().filter(it -> it.getId().equals(id)).findFirst().orElse(null);
        }
        return shipment;
    }

    public List<Shipment> listShipments() {
        return shipments;
    }

    public void updateShipment(Shipment shipment) {
        Shipment existingShipment = getShipmentById(shipment.getId());
        synchronized (shipments) {
            int i = shipments.indexOf(existingShipment);
            shipments.set(i, shipment);
        }
    }
    
    public Shipment newShipment(Order order) {
        Shipment shipment = new Shipment((long) shipments.size(), order.getId(), new Date());
        synchronized (shipments) {
            shipments.add(shipment);
        }
        LOG.info("Shipment created!");
        return shipment;
    }
}
```



As you can see above, we're just storing each `Shipment` in the `List` and have a few methods for some CRUD operations. Next, create a `ShippingController` with a single method - `getRecentShipments()`. We won't really need to expose many endpoints here because the shipping service handles most operations "behind the scenes".
```java
package codes.recursive.controller;

import codes.recursive.domain.Shipment;
import codes.recursive.service.ShippingService;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@Controller("/shipping")
public class ShippingController {

    private final ShippingService shippingService;

    public ShippingController(ShippingService shippingService) {
        this.shippingService = shippingService;
    }

    @Get("/shipments/recent/{count}")
    public HttpResponse<List<Shipment>> getRecentShipments(Long count) {
        return HttpResponse.ok(
                shippingService.listShipments().stream().limit(count).collect(Collectors.toList())
        );
    }
}
```



Startup the shipping service with:
```bash
$ ./gradlew run -Dmicronaut.environments=local
```



And check for recent shipments (which will of course be empty at this point).
```bash
$ curl -s localhost:8081/shipping/shipments/recent/5 | jq                                                                                                        
[]
```



## Consuming Order Messages

Now we can move on to the fun part - consuming orders! Again, the Micronaut CLI makes it easy to create a consumer.

[]

This creates an empty listener for us.
```java
package codes.recursive.messaging;
import io.micronaut.configuration.kafka.annotation.KafkaListener;
import io.micronaut.configuration.kafka.annotation.OffsetReset;

@KafkaListener(offsetReset = OffsetReset.EARLIEST)
public class OrderConsumer {

}
```



Note that the `@KafkaListener` annotation allows us to specify the offset at which we want to read. The choices here are `EARLIEST` and `LATEST`. You can choose whichever is most appropriate for your application. Now let's populate the listener by injecting our `ShippingService` and adding a `receive()` method that will output a message into our console log each time an order is received and ship the order via the `ShippingService`.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Order;
import codes.recursive.service.ShippingService;
import io.micronaut.configuration.kafka.annotation.KafkaKey;
import io.micronaut.configuration.kafka.annotation.KafkaListener;
import io.micronaut.configuration.kafka.annotation.OffsetReset;
import io.micronaut.configuration.kafka.annotation.Topic;
import io.reactivex.Single;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@KafkaListener(offsetReset = OffsetReset.LATEST)
public class OrderConsumer {
    private static final Logger LOG = LoggerFactory.getLogger(OrderConsumer.class);
    private final ShippingService shippingService;

    public OrderConsumer(ShippingService shippingService) {
        this.shippingService = shippingService;
    }

    @Topic("order-topic")
    public Single<Order> receive(
        @KafkaKey String key,
        Single<Order> orderFlowable) {

    return orderFlowable.doOnSuccess(order -> {
        LOG.info("Order with id {} received!", order.getId());
        LOG.info("Creating shipment...");
        /* shipping is slow! */
        Thread.sleep(15*1000);
        Shipment shipment = shippingService.newShipment(order);
        LOG.info("Shipped order {} with shipment ID {}...", order.getId(), shipment.getId());
    });
}
```



Re-run the shipping service (and make sure any console consumers are stopped) and place a new "order" with the order service. 
```bash
$ curl -s -H "Content-Type: application/json" -X POST -d '{"customerId": 1, "totalCost": 55.99}' localhost:8080/order | jq
```



Observe the shipping service console to see it log the new order when it is received.
```bash
10:54:28.241 [pool-1-thread-7] INFO  c.recursive.messaging.OrderConsumer - Order with id 12 received!
10:54:28.241 [pool-1-thread-7] INFO  c.recursive.messaging.OrderConsumer - Creating shipment…
11:00:27.265 [pool-1-thread-2] INFO  c.recursive.messaging.OrderConsumer - Shipment Created!
11:00:27.268 [pool-1-thread-2] INFO  c.recursive.messaging.OrderConsumer - Shipped order 12 with shipment ID 0...
```



To keep an eye on recent shipments, check the proper endpoint.
```bash
$ curl -s localhost:8081/shipping/shipments/recent/2 | jq
[
  {
    "id": 0,
    "orderId": 14,
    "shippedOn": "2020-08-25T13:25:34.072Z"
  }
]
```



### The Beauty of Messaging

So this is pretty amazing stuff, I know. Our microservices are reliably communicating with each other in a very decoupled and reliable manner. To illustrate the resiliency of our services so far, go ahead and stop the shipping service. Yep, just stop it. Now, place a few orders in the order service. Then wait. Go get some coffee or tea - and come back in a few minutes and re-start the shipping service. What happens? You got it - the shipping service picks up right where it left off and ships the orders even though it's been a few minutes since it was online. 

[]

## Notifying the Order Service of New Shipments

The shipping service can now handle incoming orders and ship them as needed, but wouldn't we also want to update the order status in the order service so that we can provide the proper feedback the next time an order is retrieved? Of course! To do this, we can add a new `ShipmentProducer` in the shipping microservice. We do this the same way we created the producer in the last post, with the Micronaut CLI.

[]

Populate the `ShipmentProducer`, annotating the `sendMessage` method with the new `shipping-topic` and using our `Shipment` object as the message type this time.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Shipment;
import io.micronaut.configuration.kafka.annotation.KafkaClient;
import io.micronaut.configuration.kafka.annotation.KafkaKey;
import io.micronaut.configuration.kafka.annotation.Topic;

@KafkaClient
public interface ShipmentProducer {
    @Topic("shipping-topic")
    void sendMessage(@KafkaKey String key, Shipment shipment);
}
```



Next, alter the `ShippingService` to send a shipment message when the order is shipped. First, inject the new `ShipmentProducer`:
```java
public ShippingService(ShipmentProducer shipmentProducer) {
    this.shipmentProducer = shipmentProducer;
}
```



Next, modify the `newShipment` method to send the message.
```java
public Shipment newShipment(Order order) {
    Shipment shipment = new Shipment((long) shipments.size(), order.getId(), new Date());
    shipments.add(shipment);
    LOG.info("Shipment created!");
    LOG.info("Sending shipment message...");
    shipmentProducer.sendMessage(UUID.randomUUID().toString(), shipment);
    LOG.info("Shipment message sent!");
    return shipment;
}
```



Now we can head back to our `order-svc-kafka` project and create a consumer that will receive the updated shipping status.
```bash
$ mn create-kafka-listener codes.recursive.messaging.ShipmentConsumer
```



Modify the `ShipmentConsumer` so that the order status is updated when the shipping message is received.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Order;
import codes.recursive.domain.Shipment;
import codes.recursive.domain.ShipmentStatus;
import codes.recursive.service.OrderService;
import io.micronaut.configuration.kafka.annotation.KafkaKey;
import io.micronaut.configuration.kafka.annotation.KafkaListener;
import io.micronaut.configuration.kafka.annotation.OffsetReset;
import io.micronaut.configuration.kafka.annotation.Topic;
import io.reactivex.Single;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@KafkaListener(offsetReset = OffsetReset.LATEST)
public class ShipmentConsumer {

    private static final Logger LOG = LoggerFactory.getLogger(ShipmentConsumer.class);
    private final OrderService orderService;

    public ShipmentConsumer(OrderService orderService) {
        this.orderService = orderService;
    }

    @Topic("shipping-topic")
    public Single<Shipment> receive(
            @KafkaKey String key,
            Single<Shipment> shipmentFlowable) {

        return shipmentFlowable.doOnSuccess(shipment -> {
            LOG.info("Shipment message received!");
            LOG.info("Updating order shipment status...");
            Order order = orderService.getOrderById(shipment.getOrderId());
            order.setShipmentStatus(ShipmentStatus.SHIPPED);
            orderService.updateOrder(order);
            LOG.info("Order shipment status updated!");
        });
    }
}
```



Now place another new order.
```bash
$ curl -s -H "Content-Type: application/json" -X POST -d '{"customerId": 1, "totalCost": 1.54}' localhost:8080/order | jq
{
  "id": 23,
  "customerId": 1,
  "totalCost": 1.54,
  "shipmentStatus": "PENDING"
}
```



Immediately check the status of the new order:
```bash
$ curl -s localhost:8080/order/23 | jq
{
  "id": 23,
  "customerId": 1,
  "totalCost": 1.54,
  "shipmentStatus": "PENDING"
}
```



Observe the shipping console:
```bash
12:05:51.484 [pool-1-thread-3] INFO  c.recursive.messaging.OrderConsumer - Order with id 23 received!
12:05:51.484 [pool-1-thread-3] INFO  c.recursive.messaging.OrderConsumer - Creating shipment...
12:06:06.488 [pool-1-thread-3] INFO  c.recursive.service.ShippingService - Shipment created!
12:06:06.489 [pool-1-thread-3] INFO  c.recursive.service.ShippingService - Sending shipment message...
12:06:06.491 [pool-1-thread-3] INFO  c.recursive.service.ShippingService - Shipment message sent!
12:06:06.492 [pool-1-thread-3] INFO  c.recursive.messaging.OrderConsumer - Shipped order 23 with shipment ID 5...
```



Now we can check the order service status once again and observe that the shipment status has been updated to `SHIPPED`!
```bash
$ curl -s localhost:8080/order/23 | jq
{
  "id": 23,
  "customerId": 1,
  "totalCost": 1.54,
  "shipmentStatus": "SHIPPED"
}
```



## Summary

In this post, we added a shipment microservice that listened for new orders placed with the order microservice, shipped the orders and notified the order service of the updated shipment status. As you can see, communicating with message brokers is not difficult. Messaging allows us to keep our services lean, focused and responsive while being tolerant to network partitions or system failure. I'd call that a win in my book!  Stay tuned for the next post where we'll look at hosted alternatives to Kafka to make life even easier!

Check out the code used in this post on GitHub at: <https://github.com/recursivecodes/shipping-svc-kafka>.

Image by [Quang Nguyen vinh](https://pixabay.com/users/quangpraha-7201644/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3062034) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3062034) 

