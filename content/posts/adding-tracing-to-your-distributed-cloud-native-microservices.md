---
title: "Adding Tracing to Your Distributed Cloud Native Microservices "
slug: "adding-tracing-to-your-distributed-cloud-native-microservices"
author: "Todd Sharp"
date: 2021-04-05
summary: "In this post, we'll look at tracing for distributed services using Zipkin and a fully compatible managed option in the Oracle Cloud."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/banner_forest_931706_1280.jpg"
---

When adopting cloud-native technologies and certain architectures such as the microservice pattern, observability and monitoring become a huge need and a high priority for many development teams. On the "monitoring" side, I recently blogged about using [Micronaut's built-in support for Micrometer and the OCI SDK integrations](/posts/collect-and-analyze-application-and-server-metric-data-with-micronauts-support-for-oci-monitoring) to collect and analyze your server and application-related performance metrics with OCI Monitoring. But what about "observability"? It's just as important to be able to trace and analyze requests across your distributed services so you can obtain a complete picture and be able to pinpoint bottlenecks and issues before they become a real headache. To that end, I want to talk to you about adding tracing to your Micronaut applications. Just as you'd expect, there is plenty of support for adding tracing to your applications in the Micronaut ecosystem. Is it easy to integrate this support into your OCI environment? Let's take a look.

## Tracing Requests with Micronaut

Micronaut [features support for integrating](https://docs.micronaut.io/latest/guide/index.html#distributedTracing) with the two most popular solutions for tracing: [Zipkin](https://zipkin.io/) and [Jaeger](https://www.jaegertracing.io/). To get comfortable with tracing, let's launch Zipkin locally and create two simple microservices that communicate to see how distributed tracing works.

### Launch Zipkin

The quickest and easiest way is to launch a Docker container.
```bash
$ docker run -d -p 9411:9411 openzipkin/zipkin
```



Hit `localhost:9411` in your browser to make sure it's up and running.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039988967.png)

### Generate & Configure Microservices 

Using the Micronaut CLI, generate two services. Include the `management` and `tracing-zipkin` features.
```bash
mn create-app --build=gradle --jdk=11 --lang=java --test=spock --features=management,tracing-zipkin codes.recursive.demo1
mn create-app --build=gradle --jdk=11 --lang=java --test=spock --features=management,tracing-zipkin codes.recursive.demo2
```



Edit `src/main/resources/application.yml` in `demo1` to configure a few variables and point the application at the local Zipkin install.
```yaml
micronaut:
  application:
    name: demo1
tracing:
  zipkin:
    enabled: true
    http:
      url: http://localhost:9411
    sampler:
      probability: 1
    supportsJoin: false
codes:
  recursive:
    demo2:
      baseUrl: http://localhost:8081
```



Configure `demo2` to run on port 8081 (to avoid conflict with `demo1`) and point at the local Zipkin install as well.
```yaml
micronaut:
  server:
    port: 8081
  application:
    name: demo2
tracing:
  zipkin:
    enabled: true
    sampler:
      probability: 1
    http:
      url: http://locahost:9411
    supportsJoin: false
```



### Create Controllers

Starting with `demo2`, create a controller that returns a "favorite number" for a user based on their ID. We use the special annotation `@ContinueSpan` to indicate that we want to group this endpoint along with whatever request called it in our traces. The `@SpanTag` annotation on the method parameter lets us pull out specific variables to include in our tracing spans so that we can filter or use them for troubleshooting later on.
```java
@Controller("/demo2")
public class DemoController {

    @Get(uri="/favoriteNumber/{id}")
    @ContinueSpan
    public HttpResponse favoriteNumber(@SpanTag("user.id") int id) {
        List<String> nums = List.of("9", "11", "2", "4", "99", "33", "7", "1223", "3", "0");
        if (id < 1 || id > nums.size()) {
            return HttpResponse.notFound();
        } else {
            String num = nums.get(id-1);
            return HttpResponse.ok(
                    CollectionUtils.mapOf("favoriteNumber", num)
            );
        }
    }
}
```



Next, in the `demo1` service, create a declarative HTTP client that can be used to make calls to `demo2` from `demo1`.
```java
@Client("${codes.recursive.demo2.baseUrl}")
public interface Demo2Client {
    @Get ("/demo2/favoriteNumber/{id}")
    Flowable<FavoriteNumber> favoriteNumber(int id);
}
```



Now we'll create a controller in `demo1` that has a few endpoints for testing. Note that we're injecting the `Demo2Client` and making a call to `demo2` from `demo1` in the `/user/` endpoint.
```java
@Controller("/demo1")
public class DemoController {

    private final Demo2Client demo2Client;

    public DemoController(Demo2Client demo2Client) {
        this.demo2Client = demo2Client;
    }

    @Get(uri = "/", produces = "text/plain")
    public String index() {
        return "Example Response";
    }

    @Get(uri = "/user/{id}", produces = MediaType.APPLICATION_JSON)
    public HttpResponse user(int id) {
        List<String> users = List.of(
                "Todd", "Graeme", "Thomas", "Oleg", "Gerald",
                "Andres", "Jenn", "Michael", "Phil", "Aaron");
        if (id < 1 || id > users.size()) {
            return HttpResponse.notFound();
        } else {
            String user = users.get(id-1);
            FavoriteNumber favoriteNumber = demo2Client.favoriteNumber(id).blockingFirst();
            return HttpResponse.ok(
                    CollectionUtils.mapOf("username", user, "userId", String.valueOf(id), "favoriteNumber", String.valueOf(favoriteNumber.getFavoriteNumber()))
            );
        }
    }

    @Get(uri = "/slow")
    public String slow() throws InterruptedException {
        Thread.sleep(3500);
        return "slow";
    }

    @Get(uri = "/error")
    public String error() throws Exception {
        throw new Exception("This is an error!");
    }

    @Get(uri = "/unauthorized")
    public HttpResponse unauthorized() {
        return HttpResponse.unauthorized();
    }

    @Get(uri = "/notfound")
    public HttpResponse notfound() {
        return HttpResponse.notFound();
    }
}
```



We can run each service at this point and make some calls to the various endpoints. Take a look at Zipkin and see how it handles tracing for the microservices. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989008.png)

Now drill in to one of the `/user/` calls (by clicking on 'Show') to see the spans from `demo2` included in the trace.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617040125160.png)

Click on the 'Demo2' span to highlight the row and then click 'Show Annotations' on the right-hand side to view span details and the `user.id` that we tagged with the `@SpanTag` annotation.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989048.png)

We can also use the `user.id` to query spans.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989061.png)

As you can see, tracing distributed microservices with Micronaut and Zipkin is not difficult. However, it does require that you install, configure, maintain, and secure your own Zipkin install. For larger teams with a strong DevOps presence, this isn't a problem. But for smaller teams or organizations who don't have the resources to dedicate to infrastructure management, is there a managed service option? The answer to that question is almost always "yes", but that answer invariably leads to the next obvious question: "how difficult is it to migrate to the managed option and what will it take to migrate off of it if we ever have to"? Those are fair questions - and as usual with Oracle Cloud Infrastructure, you have an option that is fully compatible with the popular industry standard that can be dropped in with just minor config changes. Let's look at using Application Performance Monitoring for our tracing endpoint instead of Zipkin.

## Using OCI Application Performance Monitoring as a Drop-In Tracing Replacement

OCI [Application Performance Monitoring](https://docs.oracle.com/en-us/iaas/application-performance-monitoring/index.html) (APM) is a suite of services that give you insight into your applications and servers running in OCI via a small agent that runs on the machine and aggregates and reports metric data. It's a nice service to monitor and diagnose performance issues. It also includes a Trace Explorer that is Zipkin (and Jaeger) compatible and we can use that Trace Explorer from our Micronaut applications (even without taking full advantage of APM via the Java Agent). Let's swap out Zipkin for APM Trace Explorer in our microservices.

### Create Cloud Configuration

In the `demo1` project, create a new file in `src/main/resources/` called `application-oraclecloud.yml`. This file will automatically be used when your application runs in the Oracle Cloud thanks to Micronaut's environment detection features.
```yaml
micronaut:
  application:
    name: demo1
tracing:
  zipkin:
    enabled: true
    http:
      url:
      path:
    sampler:
      probability: 1
    supportsJoin: false
codes:
  recursive:
    demo2:
      baseUrl: http://demo2.toddrsharp.com
```



Do the same for `demo2`.
```yaml
micronaut:
  server:
    port: 8080
  application:
    name: demo2
tracing:
  zipkin:
    enabled: true
    sampler:
      probability: 1
    http:
      url:
      path:
    supportsJoin: false
```



### Create an APM Domain

Now, in the OCI console, create an APM domain. We'll share a single domain that will be used to group and trace all of our services. I know that may seem a bit confusing given the name 'domain', but think of it more like a "project group" or an "environment" (you may want to create separate domains for QA, Test, Prod, etc). Search for 'Application Performance Monitoring' and click on 'Administration'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989066.png)

In the left sidebar, click on 'APM Domains'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989069.png)

Click on 'Create APM Domain'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989075.png)

Name it, choose a compartment and enter a description.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617040149442.png)

Once the domain is created, view the domain details. Here you'll need to grab a few values, so copy the data upload endpoint (#1), private key (#2), and public key (#3).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989084.png)

Now we have what we need to construct a URL to plug in to our application config files. The 'Collector URL' format requires us to construct a URL by using the `data upload endpoint` as our base URL and generate the path based on some choices including values from our private or public key. The format is [documented here](https://docs.oracle.com/en-us/iaas/application-performance-monitoring/doc/configure-open-source-tracing-systems.html#APMGN-GUID-B5EDE254-C854-436D-B844-B986A4E077AA). Once we've constructed the URL path, we can plug it in to our `application-oraclecloud.yml` config. Since we use the same domain for both services, the URL and path would be the same for both config files.
```yaml
micronaut:
  application:
    name: demo2
tracing:
  zipkin:
    enabled: true
    sampler:
      probability: 1
    http:
      url: https://[redacted].apm-agt.us-phoenix-1.oci.oraclecloud.com
      path: /20200101/observations/public-span?dataFormat=zipkin&dataFormatVersion=2&dataKey=[public key]
    supportsJoin: false
```



If you wanted to keep these values out of the config file, you could alternatively set them as environment variables on the server like so:
```bash
export TRACING_ZIPKIN_HTTP_URL="https://[redacted].apm-agt.us-phoenix-1.oci.oraclecloud.com"
export TRACING_ZIPKIN_HTTP_PATH="/20200101/observations/public-span?dataFormat=zipkin&dataFormatVersion=2&dataKey=[public key]"
```



And that's it! Just by creating an APM domain and plugging in our new URL and path our application will start producing tracing data to APM. We can run a few requests and then head to the Trace Explorer in the OCI console to view, search and filter our traces just like we did in Zipkin. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617040179203.png)

Choose your APM domain in the top right and the time period that you'd like to view/search.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989092.png)

Choose one of the available pre-configured queries across the top.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989097.png)

View traces and spans:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989105.png)

Click on a trace to view detailed info.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989110.png)

Click on a span inside a trace to view detailed info and tagged values.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d892ad8f-0d40-44f3-bdbd-32103077c6ae/file_1617039989119.png)

Read more about the [Trace Explorer in the documentation](https://docs.oracle.com/en-us/iaas/application-performance-monitoring/doc/use-trace-explorer.html).

## Summary

In this post, we looked at how to use tracing to gain insight into our Micronaut microservices. We first looked at using Zipkin, then we switched to the fully managed OCI Trace Explorer with nothing but a few changes to our configuration.

If you'd like to see the code used in this demo, check out the following GitHub repos.\
 

- <https://github.com/recursivecodes/mn-apm-demo-1>

- <https://github.com/recursivecodes/mn-apm-demo-2>

I hope you enjoyed this look at tracing in the cloud. If there is another topic you'd like to see covered here on the developer blog, please drop a comment below!

Image by [Free-Photos](https://pixabay.com/photos/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=931706) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=931706) 

