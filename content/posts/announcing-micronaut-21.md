---
title: "Announcing Micronaut 2.1"
slug: "announcing-micronaut-21"
author: "Todd Sharp"
date: 2020-10-02
summary: "In this post, we'll look at the new features in Micronaut 2.1 including some exciting framework enhancement for the Oracle Cloud."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/06263770-6c20-4f6b-a4d3-5bde72aee3bf/banner_board_1647322_1280.jpg"
---

I'm happy to announce the release of Micronaut 2.1, which brings a handful of new features, bug fixes and upgrades to existing features. Let's take a quick look at some of the highlights.

## Core Features

There are several exciting core features that have been added to the framework.

### Introspections for JDK 14 Records

It is now possible to define bean introspections on JDK 14+ record types (note these currently require the `--enable–preview` flag to the compiler and JVM).

### Default Environment

Micronaut 2.1 introduces the concept of a default environment. One or more default environments can be set and they will apply if no other environments are explicitly specified. See the [environments documentation](https://docs.micronaut.io/latest/guide/index.html#environments) for information on how to use this new feature.

### \@Order Annotation 

The `Order` annotation has been added to support supplying bean order for factory methods or for those who prefer the use of annotations over `Ordered` interface.

### Kotlin 1.4 

Micronaut now ships with Kotlin 1.4 for those users using Kotlin.

## Build Features

### New Gradle Plugin

A new Gradle plugin is available that provides a more expressive way to define a Micronaut application and includes awesome new features for GraalVM Native Image and Docker. The minimum required build to build a Micronaut application is now:
```groovy
plugins {
     id 'io.micronaut.application' version '{version}'
}
repositories {
    jcenter()
    mavenCentral()
}

micronaut {
    version = "2.1.0" // The Micronaut Version
    runtime "netty" // Using the Netty runtime
}
mainClassName = "example.Application" // Your main class
```



Building a Native Image is then as simple as:
```bash
$ ./gradlew nativeImage
```



Building a Docker image using GraalVM Native Image can be done with:
```bash
$ ./gradlew dockerBuildNative
```



To push a native image to a Docker registry
```bash
$ ./gradlew dockerPushNative
```



Stay tuned for a blog post that goes into more details about the Gradle Plugin coming very soon!

## Web Features

Highlights include a new API for binding declarative HTTP client methods to an HTTP request, query parameter support for websockets, and cookie retrieval from `HttpResponse`.

## Cloud Features

As usual, cloud support is a top priority of Micronaut, and this release brings some exciting integrations for Oracle Cloud as well as some enhancements for other cloud vendors.

### Support for Oracle Cloud SDK

A new GraalVM Native Image compatible module for Oracle Cloud SDK has been added allowing you to use any part of the Oracle Cloud SDK with Native Image and also enhancing the SDK with RxJava 2 support. See this blog post for more information.

### Support for Oracle Function

Support has been added for building Oracle Functions deployable to Oracle Cloud including the ability to compute the functions in native images using GraalVM. See this blog post for more information.

### Launch Updated for Oracle Cloud SDK and Oracle Functions

These Oracle Cloud features are also now available in Micronaut Launch so you can easily bootstrap a new application that uses them.

{{< callout >}}
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/06263770-6c20-4f6b-a4d3-5bde72aee3bf/2020_09_30_13_25_50.png)

Simply search for "Oracle" in the Features dialog:
{{< /callout >}}
{{< callout >}}
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/06263770-6c20-4f6b-a4d3-5bde72aee3bf/2020_09_30_13_25_10.png)
{{< /callout >}}
Many modules and dependencies have received upgrades in 2.1. To read about these and all of the other features that were not mentioned here, or for more information about anything above, check out the [release notes](https://docs.micronaut.io/2.1.0/guide/index.html#whatsNew). As always, your feedback is encouraged and appreciated.

Image by [Gerd Altmann](https://pixabay.com/users/geralt-9301/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=1647322) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=1647322)
