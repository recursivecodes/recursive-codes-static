---
title: "Microservices The Easy Way With ORDS And Micronaut - Part 3"
slug: "microservices-the-easy-way-with-ords-and-micronaut-part-3"
author: "Todd Sharp"
date: 2019-07-17
summary: "In this post we'll deploy our Micronaut microservice to Kubernetes as both a Java application and a Graal native image."
tags: ["Cloud", "Containers, Microservices, APIs", "Java"]
keywords: "microservices, Kubernetes, container, Java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6848b519-a297-4dc7-9232-b8a9ca6a561e/banner_jeshoots_com__2vd8lihdnw_unsplash.jpg"
---

We've come to the final part of this portion of this blog series where we focus on microservices with ORDS and Micronaut. In this post we'll look at deploying the service as a Docker container on Kubernetes, and while that sounds very similar to the final part of the Helidon portion of this series, I promise you that there is a different twist to this post that you will definitely be interested in checking out.

Please make sure to check out the rest of this series (at the very least, make sure you've read parts 1 & 2 of the ORDS with Micronaut chapter).

Intro posts:

- [Intro](/posts/microservices-are-easy "https://blogs.oracle.com/developers/microservices-are-easy")
- [Getting Started With Kubernetes And Docker](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud "https://blogs.oracle.com/developers/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud")
- [Getting Started With Autonomous DB](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud "https://blogs.oracle.com/developers/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud")

Helidon And Hibernate:

- [Building A Helidon Microservice Part 1](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-1)
- [Building A Helidon Microservice Part 2](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-2)
- [Building A Helidon Microservice Part 3](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-3)

ORDS With Micronaut:

- [Microservices The Easy Way With ORDS And Micronaut - Part 1](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-1)
- [Microservices The Easy Way With ORDS And Micronaut - Part 2](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-2)

## Deploying With Docker

We can easily deploy our ORDS with Micronaut service as a Docker container, just as we did before with Helidon. Like Helidon, Micronaut gives us a generated Dockerfile to get started. We'll modify it ever so slightly to take advantage of the Graal JIT compiler. If you are not familiar with Graal, I highly encourage you to [read more about it](https://www.baeldung.com/graal-java-jit-compiler). There are numerous advantages to using Graal, but the easiest way to see an immediate improvement in your application is to enable the Graal JIT compiler via a few Java options:

`-XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler`

You can [read more about the JIT compiler](https://chrisseaton.com/truffleruby/jokerconf17/) if you're interested, but further discussion on the topic is out of scope for the current blog post. For now, add the options above to the generated `Dockerfile` so you end up with something that looks like this:
```text
FROM openjdk:11.0.3-jdk-slim-stretch
COPY build/libs/*.jar user-service-ords.jar
EXPOSE 8080
CMD java -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler -Dcom.sun.management.jmxremote -noverify ${JAVA_OPTS} -jar user-service-ords.jar
```



And build the Docker image with:

`docker build -t user-svc-micronaut .`

Before you run the image, make sure you have the [environment variables set in your terminal that we set in part 2](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-2), then run:
```bash
docker run \
--env CODES_RECURSIVE_CNMS_ORDS_CLIENT_ID \
--env CODES_RECURSIVE_CNMS_ORDS_CLIENT_SECRET \
--env CODES_RECURSIVE_CNMS_ORDS_BASE_URL \
--rm -p 8080:8080 -t user-svc-micronaut
```



We'll see the application start up:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6848b519-a297-4dc7-9232-b8a9ca6a561e/2019_07_16_10_54_16.jpg)

In this example the application started up in 2432ms. Micronaut's AOT compilation has definitely given us a much quicker startup time than we might be used to seeing just a few years ago!

We can test that our application responds to requests just as it did before when we ran it as a JAR file:
```bash
curl -i http://localhost:8080/user/users/0/1
HTTP/1.1 200 OK
Date: Tue, 16 Jul 2019 14:59:28 GMT
content-type: application/json
content-length: 199
connection: keep-alive

{"offset":0,"count":1,"hasMore":true,"limit":1,"users":[{"id":"8C561D58E856DD25E0532010000AF462","username":"tsharp","first_name":"todd","last_name":"sharp","created_on":"2019-06-27T15:31:40.385Z"}]}
```



Let's shut down the local Docker container and deploy to Kubernetes. First, push the Docker image to our OCIR registry just as we did in the Helidon portion of this series:

`docker tag user-svc-micronaut [region].ocir.io/[tenancy]/cloud-native-microservice/user-svc-micronaut`

`docker push [region].ocir.io/[tenancy]/cloud-native-microservice/user-svc-micronaut`

We'll need a Kubernetes YAML file for the deployment and the secret which will contain our config values. We'll need to Base64 encode the secret values before creating the YAML file. On \*nix systems, use something like this to accomplish for each value:

`echo -n "client_id.." | base64`

Plug the encoded values into a `secret.yaml` file:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: user-svc-micronaut-native-secrets
data:
  clientId: [Base64 client ID]
  clientSecret: [Base64 client secret]
  baseUrl: [Base 64 base URL]
---
```



Then deploy the secret with:

`kubectl create -f secret.yaml`

Next, create an `app.yaml` file for the deployment. You can [use mine as an example](https://github.com/cloud-native-microservices/user-svc-micronaut-ords/blob/master/app.yaml), but make sure that you substitute the proper URL for your Docker image. Then deploy with:

kubectl create -f app.yaml

Check the pod status with `kubectl get pods` and the service with `kubectl get services`. Once the service has been assigned an IP address your service has been fully deployed!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6848b519-a297-4dc7-9232-b8a9ca6a561e/2019_07_16_11_11_25.jpg)

## Deploying As A Native Image

So we've deployed as a JAR using the Graal JIT compiler which means we have super fast startup times thanks to Micronaut's AOT and improved performance thanks to the JIT compiler. But what if we took it one step further and deployed as a native image? It's surprisingly easy and we should end up with even better resource utilization in our Docker image.

We'll create a new `Dockerfile`, this one called `Graal-Dockerfile`. Since our ORDS service utilizes HTTPS, we'll need to make sure that we include `libsunec` in our container so that we can enable HTTPS in the native image. This [blog post goes into great detail on why this is necessary](https://blog.taylorwood.io/2018/10/04/graalvm-https.html), but for now just make sure that you have a copy of the file inside your `build-resource` directory of the project. We'll make sure that this file gets into our Docker image and we'll also set an additional environment variable to tell our application the path to that file. Finally, make a slight modification to our `Application.java` file to make sure the `sunec` library is loaded at startup:
```java
package codes.recursive.cnms.ords;

import io.micronaut.runtime.Micronaut;

public class Application {

    public static void main(String[] args) {
        String libsunecPath = System.getenv("LIBSUNEC_PATH");
        if( libsunecPath != null ) {
            System.setProperty("java.library.path", libsunecPath);
            System.loadLibrary("sunec");
        }
        Micronaut.run(Application.class);
    }
}
```



Now populate `Graal.Dockerfile`:
```dockerfile
FROM oracle/graalvm-ce:19.1.0 as graalvm
RUN gu install native-image
COPY . /home/app/user-service-ords
WORKDIR /home/app/user-service-ords
RUN native-image --no-server --no-fallback -cp build/libs/user-service-ords-*.jar

FROM frolvlad/alpine-glibc
EXPOSE 8080
COPY --from=graalvm /home/app/user-service-ords/user-service-ords .
RUN mkdir resources
COPY --from=graalvm /opt/graalvm-ce-19.1.0/jre/lib/amd64/libsunec.so /resources
ENV LIBSUNEC_PATH /resources
ENTRYPOINT ["./user-service-ords", "-Xmx64m"]
```



Here we're using a builder image, installing the Graal native-image tool, copying our files into the base image and generating the native-image from the JAR file on line 5. The next step is to copy the generated native image and `libsunec` library in, set the path to the `libsunec` library and tell Docker to start our image. Note that we're using the `-Xmx64m` option to set the maximum heap size to keep the memory consumption low on our application.  You may need to adjust this setting for your application - read [more about this option and how to experiment](https://e.printstacktrace.blog/graalvm-heap-size-of-native-image-how-to-set-it/) with it.

We can build, push and deploy this Dockerfile just as before.
```bash
docker build -f Graal.Dockerfile -t user-svc-micronaut-native .
docker tag user-svc-micronaut-native [region].ocir.io/[tenancy]/cloud-native-microservice/user-svc-micronaut-native
docker push [region].ocir.io/[tenancy]/cloud-native-microservice/user-svc-micronaut-native
```



The [deployment configuration](https://github.com/cloud-native-microservices/user-svc-micronaut-ords/blob/master/app-native.yaml) is similar, just pointing at the native Docker image instead. Again, deploy with `kubectl create -f app-native.yaml`, check with `kubectl get pods` and `kubectl get services`. Note the startup time with the native image is now significantly improved:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6848b519-a297-4dc7-9232-b8a9ca6a561e/2019_07_16_11_54_20.jpg)

## Comparing Performance

It's interesting to look at the performance of the JIT version compared to the AOT native image. To compare, I ran a very simple load test (600 users over 1 minute) against each deployed service and monitored the CPU, Memory of each during that test. We'll look at median response time as well to see how each fares with throughput. 

First up, the JIT version load test results:
```bash
Summary report @ 02:57:15(-0400) 2019-07-09
  Scenarios launched:  600
  Scenarios completed: 600
  Requests completed:  600
  RPS sent: 9.94
  Request latency:
    min: 269.4
    max: 514.6
    median: 307
    p95: 346.4
    p99: 408.9
  Scenario counts:
    0: 600 (100%)
  Codes:
    200: 600
```



A median response time of 307ms is pretty decent, considering our application utilizes ORDS to retrieve data we should expect some additional latency over a typical JDBC transaction. Let's look at the CPU and memory consumption:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6848b519-a297-4dc7-9232-b8a9ca6a561e/2019_07_16_11_59_32.jpg)

The performance here is better than what we'd expect to see if we weren't using the JIT compiler, but we still see some spikes and overall high utilization numbers on the CPU. Memory consumption is pretty level, running around 325MB on average.

Next, let's see how the native image performed. 
```bash
Summary report @ 10:01:37(-0400) 2019-07-09
  Scenarios launched:  600
  Scenarios completed: 600
  Requests completed:  600
  RPS sent: 9.94
  Request latency:
    min: 283.9
    max: 6436.8
    median: 323
    p95: 1952.6
    p99: 4148.6
  Scenario counts:
    0: 600 (100%)
  Codes:
    200: 600
```



The median response time here is ever so slightly slower than the JIT version by 16ms, but not nearly enough to be concerned that the throughput on the native image version is inadequate or lacking. What about CPU and memory?

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6848b519-a297-4dc7-9232-b8a9ca6a561e/2019_07_16_12_03_42.jpg)

Amazingly, the CPU stays consistently under 1% utilization with the native image and the memory consumption hovers around 72MB throughout the duration of the load test. 

## Summary

So what have we learned during this portion of the microservice blog series? Well, we found out that it's possible to create a microservice to perform CRUD operations without a single SQL statement in our application code. We learned that we could create declarative HTTP clients using a simple interface or abstract class and let Micronaut handle the implementation of that service. We also looked at how that declarative client can use RxJava to perform our HTTP requests in an async and non-blocking manner. We can take advantage of the Graal JIT compiler as well as the AOT native image capabilities to increase our deployed microservice's performance.

## Up Next

In future posts we'll take a look at a new approach to persisting JSON documents and eventually take a look at how we can tie all of these posts together in a meaningful way.

[Photo by ][JESHOOTS.COM](https://unsplash.com/@jeshoots?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/programmer?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
