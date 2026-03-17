---
title: "Intro To Oracle Application Container Cloud Services"
slug: ""
author: "Todd Sharp"
date: 2018-05-02
summary: ""
tags: ["Spark Java"]
keywords: "oracle, accs, spark java app, groovy, cloud, deploy"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/39/banner_54e1d1404255ab14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

I've long been an AWS user, but recently one of my projects at work has expressed some interest in getting our platform running on multiple cloud service providers so based on the recommendations of a few friends I decided to give Oracle's cloud offering a look.  I'd heard a bit about their cloud offerings, but I honestly had no idea just how many services they offered.  I mean, seriously - everything from application/container hosting to messaging queues, security, AI, Machine Learning - you name it and they seem to offer a product or service to support it.  I guess it really shouldn't surprise me though - cloud services are undeniably the future of our industry.

To get started I thought I'd just throw together a basic "hello world" application.  First things first, I [signed up](https://cloud.oracle.com/en_US/tryit) for a free trial.  They give you \$300 credit for 30 days so it's easy to take a look at their offerings without a financial commitment (and I've yet to be called and bugged by a salesperson into signing up for a contract, so that's good!).  I do feel like a free tier would make Oracle's offerings much more attractive - especially to developers looking to host a simple blog or smaller project or just to tinker with their services for a longer period of time.  To be fair, the AWS free tier is pretty limited and is still time bound (most free tiers expire after 12 months). I don't even use the free tier for my blog, but it is a nice option to use at least as a "playground" for their services that gives you plenty of time to fully evaluate them.

[The nice thing about [Oracle's Application Container Cloud Service (which, from here on out I'll be abbreviating ACCS for the sake of brevity!)] is that it supports pretty much any kind of application. You might think that Oracle would be strictly focused on Java applications, but that's not the case. Of course, support for Java (SE and EE - or I guess Jakarta EE as it's now known) is there, but so is support for Node.JS, PHP, Ruby, Python, Go and .NET. The other nice thing is that ACCS is Docker based - but you'd never know it because all you have to do is deploy your application archive (a JAR in my case) and it handles the container creation, configuration and deployment. Which is really nice, but sometimes you want more granular control over the container creation and configuration - and in those cases Oracle has a solution, but it's not ACCS. Sometimes you just need a microservice deployed and don't need to fuss over the details - and that's where ACCS shines in my opinion. Finally, Oracle gives you multiple deployment options: a web based interface, full REST API ([which could be useful CI/CD pipeline integration) ]and a full featured CLI. For this demo we'll take a look at the web based interface, but I may take a deeper dive into the CLI in the near future since it offers the ability to do things like deploy directly from a source control (GitHub) repo.]

I figured my [Spark Java "Skeleton"](https://github.com/cfsilence/spark-groovy-skeleton) app would be the perfect place to start so I cloned it and made some slight modifications in order to make it work with ACCS.  The first thing I needed to do was make sure that I created a "fat" JAR (that is, a JAR file with all the dependencies bundled within it - ready to be executed).  To do so, I made a few modifications to my `build.gradle`.  The first step was to add a `jar` task:
```groovy
jar {
    dependsOn configurations.runtime

    manifest {
        attributes "Main-Class": "$mainClassName"
    }
    from {
        configurations.compile.collect { it.isDirectory() ? it : zipTree(it) }
    }
    archiveName "app.jar"
}
```



I also added a few additions to make sure my config files ended up in the JAR file:
```groovy
sourceSets.main.resources.srcDirs = [ "src/main/groovy" ]
sourceSets.main.resources.includes = [ "**/conf/**" ]
```



Finally, I added a `packageOracle` task to zip up the resulting JAR file along side a `manifest.json` file per the [ACCS documentation](https://docs.oracle.com/en/cloud/paas/app-container-cloud/dvcjv/creating-meta-data-files.html) (we'll look at my `manifest.json` next):
```groovy
task packageOracle(type: Zip) {
    dependsOn jar
    from configurations.runtime.allArtifacts.files
    from 'manifest.json'
}
```



The manifest.json file is a JSON file that provides some necessary information used in the creation of the Docker container and in launching the application.  Mine is shown below, but yours might look different depending on the choices you've made when creating your application (language choice, for one, would result in a different 'command' value):
```json
{
  "runtime": {
    "majorVersion": "8"
  },
  "type": "web",
  "command": "java -jar app.jar",
  "startupTime": "120",
  "notes": "notes related to release",
  "mode": "rolling",
  "home": "/",
  "healthCheck": {
    "http-endpoint": "/"
  }
}
```



The only other modification to my Spark Java app that was necessary was to grab the port assigned by ACCS and pass it to Spark Java. ACCS sets the port (and the hostname) into your environment properties, so here's how I modified my application to account for that:
```groovy
Integer p = System.getenv("PORT")?.toInteger() ?: 9000
port(p)
```



Once I made those modifications and ran my `packageOracle` task I was ready to deploy my application to ACCS.  To create the application, I logged in to the ACCS console and selected 'Create Application' from the dashboard.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/oracle/accs/console.png)

In the 'Create Application' dialog, you have to choose your application platform.  Since I'm deploying a JAR file, I chose 'Java SE'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/oracle/accs/choose_application_type.png)

In the next dialog, I named my application, chose the ZIP file (that contains my `manifest.json` and my fat JAR), select how many instances, how much memory and which region I'd like the application deployed to.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/oracle/accs/create_application_details.png)

After clicking 'Create' I get a confirmation that the creation request was accepted.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/oracle/accs/application_created.png)

Clicking into the application for more details presents you with the following view.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/oracle/accs/application_created_detail.png)

Once the application is created and deployed (a few minutes) I was able to click on the URL at the top of the page to view my running application.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/oracle/accs/running_app.png)

As I stated earlier, ACCS gives you the ability to deploy via the CLI directly from GitHub, however there are a few limitations at this time (Java SE, Maven based builds only).  Probably the most commonly used option would be to deploy via the REST API, since any CI/CD pipeline absolutely needs the ability to remotely publish an application.  See the [docs](https://docs.oracle.com/en/cloud/paas/app-container-cloud/dvcjv/preparing-worker-application-deployment.html) for more info.

If you'd like to see the full application source you can find it on [GitHub](https://github.com/cfsilence/spark-groovy-cloud-demo).

Image by [TheDigitalArtist](https://pixabay.com/users/TheDigitalArtist-202249) from [Pixabay](https://pixabay.com)
