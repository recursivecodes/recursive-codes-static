---
title: "Controlling Your Cloud - A Look At The Oracle Cloud Infrastructure Java SDK"
slug: "controlling-your-cloud-a-look-at-the-oracle-cloud-infrastructure-java-sdk"
author: "Todd Sharp"
date: 2019-01-02
summary: "In this post we take a look at the Java SDK for interacting with various elements within the Oracle Cloud Infrastructure.  Specifically, we'll look at authentication and basic object storage APIs."
tags: ["Cloud", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0ba6c4a-1b2b-47fc-b7fa-d224d6056ff1/banner_2018_12_19_09_13_40.png"
---

A few weeks ago our cloud evangelism team got the opportunity to spend some time on site with some amazing developers from one of Oracle's clients in Santa Clara, CA for a 3-day cloud hackfest.  During the event, one of the developers mentioned that a challenge his team faced was handling file uploads for potentially extremely large files.  I've faced this problem before as a developer and it's certainly challenging.  The web just wasn't really built for large file transfers (though, things have gotten much better in the past few years as we'll discuss later on).  We didn't end up with an opportunity to fully address the issue during the hackfest, but I promised the developer that I would follow-up with a solution after digging deeper into the Oracle Cloud Infrastructure APIs once I got back home.  So yesterday I got down to digging into the process and engineered a pretty solid demo for that developer on how to achieve large file uploads to OCI Object Storage, but before I show that solution I wanted to give a basic introduction to working with your Oracle Cloud via the available SDK so that things are easier to follow once we get into some more advanced interactions. 

Oracle offers [several other SDKs](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/sdks.htm) (Python, Ruby and Go), but since I typically write my code in Groovy I went with the [Java SDK](https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/javasdk.htm).  Oracle provides a full REST API for working with your cloud, but the SDK provides a nice native solution and abstracts away some of the painful bits of signing your request and making the HTTP calls into a nice package that can be bundled within your application. The Java SDK supports the following OCI services:

- Audit
- Container Engine for Kubernetes
- Core Services (Networking, Compute, Block Volume)
- Database
- DNS
- Email Delivery
- File Storage
- IAM
- Load Balancing
- Object Storage
- Search
- Key Management

Let's take a look at the Java SDK in action, specifically how it can be used to interact with the Object Storage service.  The SDK is open source and available on [GitHub](https://github.com/oracle/oci-java-sdk).  I created a very simple web app for this demo.  Unfortunately, the SDK is not yet available via Maven (see [here](https://github.com/oracle/oci-java-sdk/issues/25)), so step one was to [download the SDK](https://github.com/oracle/oci-java-sdk/releases) and include it as a dependency in my application.  I use Gradle, so I dropped the JARs into a "libs" directory in the root of my app and declared the following dependencies block to make sure that Gradle picked up the local JARs (the key being the "implementation" method on line 8):
```groovy
dependencies {
    localGroovyConf localGroovy()
    compile 'org.codehaus.groovy:groovy-all:2.5.4'
    compile 'com.sparkjava:spark-core:2.7.2'
    compile 'org.slf4j:slf4j-simple:1.7.21'
    compile group: 'org.apache.tika', name: 'tika-core', version: '1.19.1'
    
    implementation fileTree(dir: 'libs', include: ['*.jar'])
}
```



The next step is to create some system properties that we'll need for authentication and some of our service calls.  To do this, you'll need to [set up some config files locally and generate some key pairs](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/sdkconfig.htm), which can be mildly annoying at first, but once you're set up you're good to go in the future and you get the added bonus of being set up for the OCI CLI if you want to use it later on.  Once I had the config file and keys generated, I set my props into a file in the app root called 'gradle.properties'.  Using this properties file and the key naming convention shown below Gradle makes the variables available within your build script as system properties.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0ba6c4a-1b2b-47fc-b7fa-d224d6056ff1/2018_12_19_09_13_40.png)

Note that having the variables as system properties in your build script does **not** make them available within your application, but to do that you can simply pass them in via your 'run' task:
```groovy
task runServer(dependsOn: 'classes', type: JavaExec) {
    System.setProperty('environment', 'prod')
    dependsOn 'classes'
    classpath = sourceSets.main.runtimeClasspath
    main = 'codes.recursive.Bootstrap'
    systemProperties = System.getProperties()
}
```



Next, I created a class to manage the provider and service clients.  This class only has a single client right now, but adding additional clients for other services in the future would be trivial.
```groovy
package codes.recursive.service

import com.oracle.bmc.auth.AuthenticationDetailsProvider
import com.oracle.bmc.auth.ConfigFileAuthenticationDetailsProvider
import com.oracle.bmc.objectstorage.ObjectStorage
import com.oracle.bmc.objectstorage.ObjectStorageClient

import java.security.Security

class OciClientManager {

    AuthenticationDetailsProvider provider

    OciClientManager(configFilePath=System.getProperty("ociConfigPath"), profile=System.getProperty("ociProfile")) {
        this.provider =  new ConfigFileAuthenticationDetailsProvider(configFilePath, profile)
        // per https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/javasdkconfig.htm#JavaVirtualMachineTTLforDNSNameLookups
        Security.setProperty("networkaddress.cache.ttl" , "60")
    }

    ObjectStorage getObjectClient(region=System.getProperty("ociObjectStorageRegion")) {
        ObjectStorage client = new ObjectStorageClient(this.provider)
        client.setRegion(region)
        return client
    }
}
```



I then created an 'ObjectService' for working with the Object Storage API.  The constructor accepts an instance of the OciClientManager that we looked at above, and sets some class variables for some things that are common to many of the SDK methods (namespace, bucket name, compartment ID, etc):
```groovy
OciClientManager clientManager
ObjectStorage objectClient
String bucketName = "doggos"
String namespaceName

ObjectService(OciClientManager clientManager) {
    this.clientManager = clientManager
    this.objectClient = clientManager.getObjectClient()
    GetNamespaceResponse namespaceResponse = objectClient.getNamespace(
            GetNamespaceRequest.builder().build()
    )
    this.namespaceName = namespaceResponse.getValue()
}
```



At this point, we're ready to interact with the SDK.  As a developer, it definitely feels like an intuitive API and follows a standard "request/response" model that other cloud providers use in their APIs as well.  I found myself often simply guessing what the next method or property might be called and often being right (or close enough for intellisense to guide me to the right place).  That's pretty much my benchmark for a great API - if it's intuitive and doesn't get in my way with bloated authentication schemes and such then I'm going to love working with it.  Don't get me wrong, strong authentication and security are assuredly important, but the purpose of an SDK is to hide the complexity and expose a method to use the API in a straightforward manner.  All that said, let's look at using the Object Storage client.  

We'll go rapid fire here and show how to use the client to do the following actions (with a sample result shown after each code block):

1.  List Buckets
2.  Get A Bucket
3.  List Objects In A Bucket
4.  Get An Object

List Buckets:
```groovy
def listBuckets() {
    ListBucketsRequest listBucketsRequest = ListBucketsRequest.builder()
            .namespaceName(this.namespaceName)
            .compartmentId(System.getProperty("ociCompartmentId"))
            .build()
    ListBucketsResponse listBucketsResponse = objectClient.listBuckets(listBucketsRequest)
    return listBucketsResponse
}
```



 ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0ba6c4a-1b2b-47fc-b7fa-d224d6056ff1/list_buckets.png)

Get Bucket:
```groovy
def getBucket() {
    def listBucketsResponse = listBuckets()
    GetBucketRequest getBucketRequest = GetBucketRequest.builder()
            .namespaceName(this.namespaceName)
            .bucketName( listBucketsResponse.items.find { it.name == this.bucketName }.name )
            .fields([GetBucketRequest.Fields.ApproximateCount])
            .build()
    GetBucketResponse getBucketResponse = objectClient.getBucket(getBucketRequest)
    return getBucketResponse
}
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0ba6c4a-1b2b-47fc-b7fa-d224d6056ff1/get_bucket.png)

List Objects:
```groovy
def listObjects() {
    ListObjectsRequest listObjectsRequest = ListObjectsRequest.builder()
            .namespaceName(this.namespaceName)
            .bucketName(this.bucketName)
            .build()
    ListObjectsResponse listObjectsResponse = objectClient.listObjects(listObjectsRequest)
    return listObjectsResponse
}
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0ba6c4a-1b2b-47fc-b7fa-d224d6056ff1/list_objects.png)

Get Object:
```groovy
def getObject() {
    def listObjectsResponse = listObjects()
    GetObjectRequest getObjectRequest = GetObjectRequest.builder()
            .namespaceName(namespaceName)
            .bucketName(bucketName)
            .objectName(listObjectsResponse.listObjects.objects.first().name)
            .build()
    GetObjectResponse getObjectResponse = objectClient.getObject(getObjectRequest)
    def object = Util.writeInputStream(getObjectResponse.inputStream, getObjectResponse.contentType)
    return [object: object, response: getObjectResponse]
}
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0ba6c4a-1b2b-47fc-b7fa-d224d6056ff1/get_object.png)

The 'Get Object' example also contains an InputStream containing the object that can be written to file.

As you can see, the Object Storage API is predictable and consistent.  In another post, we'll finally tackle the more complex issue of handling large file uploads via the SDK.
