---
title: "Getting Started With The Spark Java Framework"
slug: ""
author: "Todd Sharp"
date: 2017-04-04
summary: "I published a post last week showing how to use Grails to create a website on the Raspberry Pi.  After some feedback and conversations about whether this was \"overkill\" for a simple Raspberry Pi website I decided to revisit the topic and see how I could simplify things a bit without sacrificing the power of Groovy and Pi4J. I've done a bit of digging and discovered the Spark Java framework."
tags: ["Groovy", "Groovy On Raspberry Pi", "Raspberry Pi", "Spark Java"]
keywords: "raspberry pi, first website, website on raspberry pi, groovy on raspberry pi, spark java, spark java groovy"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/19/banner_54e5d4454c56ad14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

I published a post last week showing how to use Grails to [create a website on the Raspberry Pi](http://recursive.codes/blog/post/13).  After some feedback and conversations about whether this was "overkill" for a simple Raspberry Pi website I decided to revisit the topic and see how I could simplify things a bit without sacrificing the power of Groovy and Pi4J. I've done a bit of digging and discovered the [Spark Java](http://sparkjava.com/) framework.  

{{< callout >}}
Although this post refers to deploying on Raspberry Pi, it should be noted that it isn't limited to Raspberry Pi.  Spark Java is a simple and lightweight framework that can be used for any web application.
{{< /callout >}}
So what is Spark Java?  From the Spark Java site:

> Spark Framework is a simple and lightweight Java web framework built for rapid development. Spark was originally inspired by the web framework Sinatra, but it's intention isn't to compete with Sinatra, or other similar web frameworks in different languages. Sparks intention is to provide a pure Java alternative for developers that want to (or are required to), develop their web application in Java. Spark is built around Java 8's lambda philosophy, which makes a typical Spark application a lot less verbose than most application written in other Java web frameworks.\
> Spark focuses on being as simple and straight-forward as possible, without the need for cumbersome (XML) configuration, to enable very fast web application development in pure Java with minimal effort. It's a totally different paradigm when compared to the overuse of annotations for accomplishing pretty trivial stuff seen in other web frameworks.

Sounds like a perfect framework for the Pi.  Simple, self-contained, lightweight and convention based.  No need to install a web server like Tomcat or Apache, no need for a full blown framework like Grails.  And since [Groovy closures can be used as Lambda expressions](http://mrhaki.blogspot.com/2015/04/groovy-goodness-use-closures-as-java.html) there is nothing stopping us from using Groovy instead of Java with Spark Java.  So, let's do that.

Create a new Gradle project in IntelliJ.  Once you've got your project created, open up your `build.gradle` script and paste the following:
```groovy
group 'codes.recursive'
version '1.0-SNAPSHOT'

apply plugin: 'idea'
apply plugin: 'groovy'
apply plugin: 'java'

configurations {
    localGroovyConf
}

repositories {
    mavenCentral()
}
dependencies {
    localGroovyConf localGroovy()
    compile 'org.codehaus.groovy:groovy-all:2.3.11'
    compile group: 'com.pi4j', name: 'pi4j-core', version: '1.1'
    compile 'com.sparkjava:spark-core:2.3'
}

task runServer(dependsOn: 'classes', type: JavaExec) {
    classpath = sourceSets.main.runtimeClasspath
    main = 'Bootstrap'
}
```



We declare three dependencies here:

1.  Groovy
2.  The Spark Java Framework
3.  Pi4J (we'll get to that in another post)

The `runServer` task is what we'll use to launch the server via Gradle.  Next we need a simple Bootstrap script which is what we'll need to declare our [routes](http://sparkjava.com/documentation.html#routes) within the Spark Java application (basically - one route for each verb, if needed, for each path within the application).

{{< callout >}}
**Note:  **Your Groovy files will need to be under `src/main/groovy` or Gradle won't find them!
{{< /callout >}}
Now populate your `src/main/groovy/Bootstrap.groovy` class as such:
```groovy
import static spark.Spark.*

class Bootstrap {
    static void main(String[] args) {
        get "/hello", {req, res -> "Hello World"}
        get "/goodbye", {req, res -> "Goodbye World"}
    }
}
```



And sync the code with your Pi.  \
\

{{< callout >}}
Check [this post](http://recursive.codes/blog/post/18) to see how I sync with my Pi.  You can always use `SCP` or `FTP` as desired.
{{< /callout >}}
You're now ready to launch the app.  In an `SSH` session navigate to where the `build.gradle` script is and run `gradle runServer`.  The first time you run it will take a bit longer than subsequent runs, since the dependencies need to be downloaded.  Eventually you'll see the following in your console:

    runServer[Thread-1] INFO org.eclipse.jetty.util.log - Logging initialized @1898ms
    [Thread-1] INFO spark.webserver.JettySparkServer - == Spark has ignited ...
    [Thread-1] INFO spark.webserver.JettySparkServer - >> Listening on 0.0.0.0:4567
    [Thread-1] INFO org.eclipse.jetty.server.Server - jetty-9.3.2.v20150730
    [Thread-1] INFO org.eclipse.jetty.server.ServerConnector - Started ServerConnector@2ad3bd
    [Thread-1] INFO org.eclipse.jetty.server.Server - Started @2319ms

And that's it!  Your site is now up and running.  Try it out by hitting `http://[Raspberry Pi or localhost IP]:4567/hello` and you should see the message 'Hello World' in your browser.  

Image by [cocoparisienne](https://pixabay.com/users/cocoparisienne-127419) from [Pixabay](https://pixabay.com)
