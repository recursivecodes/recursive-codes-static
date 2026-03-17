---
title: "Message Driven Microservices & Monoliths with Micronaut - Part 4: Using RabbitMQ for Messaging"
slug: "message-driven-microservices-monoliths-with-micronaut-part-4:-using-rabbitmq-for-messaging"
author: "Todd Sharp"
date: 2021-02-08
summary: "In this post, we'll modify our previous e-commerce example to use RabbitMQ for messaging instead of Kafka."
tags: ["Cloud", "Developers", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/banner_hare_3497805_1280.jpg"
---

Previously, we looked in-depth at messaging for your microservice and monoliths by using an e-commerce example. We first [set up a Kafka broker and created an order microservice](/posts/message-driven-microservices-monoliths-with-micronaut-part-1:-installing-kafka-sending-your-first-message) that published new orders to an order topic. In the next post, [we created a shipping service to consume the order messages and then sent shipment messages back](/posts/message-driven-microservices-monoliths-with-micronaut-part-2:-consuming-messages) to the order service via a separate topic on the same Kafka broker. In the third post, we looked at [how to use Oracle Streaming Service (OSS) instead of your own Kafka broker](/posts/message-driven-microservices-monoliths-with-micronaut-part-3:-switching-to-oracle-streaming-service). We've covered quite a lot of information on messaging, but there's one more option that I wanted to cover in this series - using RabbitMQ instead of Kafka or Oracle Streaming Service. 

As I've previously mentioned, using Kafka or OSS are excellent choices for messaging. But there are certainly those developers who are more comfortable or familiar with using MQTT via RabbitMQ so I wanted to cover this topic quickly because Micronaut makes using RabbitMQ just as easy as it made Kafka. We won't go into as much detail as we did in the previous posts because things would start to feel redundant, but I'll show you how to use RabbitMQ in the same use case of an e-commerce application that includes order and shipping services. Instead of walking through the service details as we did before, I'll assume you've either read those posts or can refer to the GitHub repos for this example to understand the "big picture" and we'll look at creating our producers and consumers in RabbitMQ and Micronaut in this post. Please refer to the [Micronaut RabbitMQ docs](https://micronaut-projects.github.io/micronaut-rabbitmq/latest/guide/) for further information beyond what is covered in this post.

Don't Have RabbitMQ Setup?  No problem! I published a guide last year about [Getting Started with RabbitMQ in the Oracle Cloud](/posts/getting-started-with-rabbitmq-in-the-oracle-cloud)!

## Setting up RabbitMQ

Note! When setting up your RabbitMQ server, make sure that you have the `rabbitmq_mqtt` plugin enabled! Also make sure that TCP port `5672` is exposed in your Docker container (if using Docker), your OS firewall and in your network security list!

In your RabbitMQ management console, you'll need to add a new "queue" for both orders and shipments. Click on 'Queues' and then 'Add queue'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136062.png)

Create an `order-queue`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136073.png)

And a `shipment-queue`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136081.png)

Now we'll create an exchange by clicking on 'Exchanges' then 'Add exchange'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136090.png)

Name the exchange `micronaut-demo` and click 'Add exchange'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136093.png)

Now click on the new exchange and add a binding to the `order-queue` with the routing key `order`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136096.png)

Do the same for the `shipment-queue`, using the routing key `shipment`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136100.png)

OK, we're all set up on the Rabbit MQ side.

## Create an Order Service That Uses RabbitMQ

Using [Micronaut Launch](https://launch.micronaut.io/), bootstrap, download and unzip the order service. Be sure to include the 'RabbitMQ' feature.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136107.png)

The domain objects, controller and service for the order service will all look identical for the most part from the Kafka solution, so create those as you did in the first blog post of this series (or [see the GitHub repo for this example](https://github.com/recursivecodes/order-svc-rabbitmq)).

Now with the Micronaut CLI we'll create a `ShipmentConsumer` and an `OrderProducer`, but this time with the `create-rabbitmq-listener` command from the CLI.
```bash
$ mn create-rabbitmq-listener codes.recursive.messaging.ShipmentConsumer
$ mn create-rabbitmq-producer codes.recursive.messaging.OrderProducer
```



Populate the `OrderProducer` as such. Take note that the value passed to the `@RabbitClient` annotation should be the name of the exchange we created earlier and the `@Binding` value is the routing key that we used in our queue binding earlier.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Order;
import io.micronaut.rabbitmq.annotation.Binding;
import io.micronaut.rabbitmq.annotation.RabbitClient;

@RabbitClient("micronaut.demo") /* exchange name */
public interface OrderProducer {
    @Binding(value = "order")
    void send(Order order);
}
```



In the `ShipmentConsumer`, annotate the `receive` method with `@Queue` and point it at the `shipment-queue` that we bound to our exchange earlier.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Order;
import codes.recursive.domain.Shipment;
import codes.recursive.domain.ShipmentStatus;
import codes.recursive.service.OrderService;
import io.micronaut.rabbitmq.annotation.Queue;
import io.micronaut.rabbitmq.annotation.RabbitListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RabbitListener
public class ShipmentConsumer {
    private static final Logger LOG = LoggerFactory.getLogger(ShipmentConsumer.class);
    private final OrderService orderService;

    public ShipmentConsumer(OrderService orderService) {
        this.orderService = orderService;
    }

    @Queue("shipment-queue")
    public void receive(
            Shipment shipment) {
        LOG.info("Shipment message received!");
        LOG.info("Updating order shipment status...");
        Order order = orderService.getOrderById(shipment.getOrderId());
        order.setShipmentStatus(ShipmentStatus.SHIPPED);
        orderService.updateOrder(order);
        LOG.info("Order shipment status updated!");
    }
}
```



## Create a Shipping Service That Uses RabbitMQ

Create another project with Micronaut Launch for the shipping service, again adding the 'RabbitMQ' feature.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/232f3ecf-2660-4198-beec-cc7f5282d23c/file_1610756136112.png)

As with our RabbitMQ order service, this shipment service, controller, and the domain will all be the same as the Kafka example. Refer to the [GitHub repository for this example](https://github.com/recursivecodes/shipping-svc-rabbitmq) for that code if necessary. The difference, again, is in the producer/consumer. Create a `ShipmentProducer` and an `OrderConsumer` with the CLI.
```bash
$ mn create-rabbitmq-producer codes.recursive.messaging.ShipmentProducer
$ mn create-rabbitmq-listener codes.recursive.messaging.OrderConsumer
```



Now populate the `OrderConsumer` as such. Again, note the `@Queue` annotation that points at the `order-queue` we created earlier.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Order;
import codes.recursive.domain.Shipment;
import codes.recursive.service.ShippingService;
import io.micronaut.rabbitmq.annotation.Queue;
import io.micronaut.rabbitmq.annotation.RabbitListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RabbitListener
public class OrderConsumer {
    private static final Logger LOG = LoggerFactory.getLogger(OrderConsumer.class);
    private final ShippingService shippingService;

    public OrderConsumer(ShippingService shippingService) {
        this.shippingService = shippingService;
    }

    @Queue("order-queue")
    public Shipment receive(Order order) throws InterruptedException {
        LOG.info("Order received!");
        LOG.info("Creating shipment...");
        /* shipping is slow! */
        Thread.sleep(15*1000);
        return shippingService.newShipment(order);
    }
}
```



For the `ShipmentProducer`, again use the `micronaut-demo` exchange as the `@RabbitClient` and the `shipment` routing key as the `@Binding`.
```java
package codes.recursive.messaging;

import codes.recursive.domain.Shipment;
import io.micronaut.rabbitmq.annotation.Binding;
import io.micronaut.rabbitmq.annotation.RabbitClient;

@RabbitClient("micronaut.demo")
public interface ShipmentProducer {
    @Binding("shipment")
    void send(Shipment shipment);
}
```



## RabbitMQ Configuration

Both the order and shipping microservice will require a slight addition to the `resources/application.yml` config file. Add the appropriate `uri`, `username` and `password` and you're all set.
```yaml
rabbitmq:
  uri: ${RABBITMQ_URI}
  username: ${RABBITMQ_USERNAME}
  password: ${RABBITMQ_PASSWORD}
```



## Test

At this point, we can launch both services, place an order and observe the same results that we did with our Kafka and OSS examples in the previous posts.

Place order:
```yaml
rabbitmq:
  uri: ${RABBITMQ_URI}
  username: ${RABBITMQ_USERNAME}
  password: ${RABBITMQ_PASSWORD}
```



Check order status:
```bash
$ curl -s localhost:8080/order/0 | jq
{
  "id": 0,
  "customerId": 1,
  "totalCost": 1.54,
  "shipmentStatus": "PENDING"
}
```



Observe shipping console.
```bash
15:30:47.046 [pool-2-thread-2] INFO  c.recursive.messaging.OrderConsumer - Order with ID 0 received!
15:30:47.046 [pool-2-thread-2] INFO  c.recursive.messaging.OrderConsumer - Creating shipment...
15:31:02.050 [pool-2-thread-2] INFO  c.recursive.service.ShippingService - Shipment created!
15:31:02.051 [pool-2-thread-2] INFO  c.recursive.service.ShippingService - Sending shipment message...
15:31:02.128 [pool-2-thread-2] INFO  c.recursive.service.ShippingService - Shipment message sent!
15:31:02.128 [pool-2-thread-2] INFO  c.recursive.messaging.OrderConsumer - Shipped order 0 with shipment ID 0...
```



Check order service status to confirm it was updated.
```bash
$ curl -s localhost:8080/order/0 | jq
{
  "id": 0,
  "customerId": 1,
  "totalCost": 1.54,
  "shipmentStatus": "SHIPPED"
}
```



## Summary

In this post, we used RabbitMQ instead of Kafka or OSS to handle the messaging in our e-commerce example. This brings us to the end of this brief series on messaging in the cloud. I hope that you found this series useful. Please leave a comment below or contact me via [Twitter](https://twitter.com/recursivecodes) with any feedback or to let me know what you'd like to read next here on the Developer Blog!

If you'd like to view the code used in this post, please see the repos on GitHub:

- <https://github.com/recursivecodes/order-svc-rabbitmq>

- <https://github.com/recursivecodes/shipping-svc-rabbitmq>

Image by [Comfreak](https://pixabay.com/users/comfreak-51581/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3497805) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3497805) 

