---
title: "Cloud Cost Cutting: Save Money By Resizing Large Images In Object Storage"
slug: "cloud-cost-cutting:-save-money-by-resizing-large-images-in-object-storage"
author: "Todd Sharp"
date: 2020-06-03
summary: "In this post, we'll look at one way to cut your costs in the cloud by performing a resize of large images in object storage via the OCI Java SDK."
tags: ["Cloud", "Java"]
keywords: "Java, OBJECT STORAGE, Groovy"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/41c50ea5-f0cd-4f9c-80f5-65022dee984e/banner_geronimo_giqueaux_mp4fq6zj6d4_unsplash.jpg"
---

Like many of you, I have an account on our Oracle Cloud "always free" tier that I use for hosting personal projects, most notably my personal blog [recursive.codes](https://recursive.codes). After importing a large amount of content recently I noticed that I was starting to be billed a few dollars (\$2-4) every month. Since I'm an incredibly cheap person I decided to see what I could do to get that cost down. One of the easiest ways to reduce object storage costs is to reduce the number of bytes being stored, so I decided to write a quick script to do just that. 

**What?! **You don't have an account on the [Oracle Cloud "always free" tier](https://www.oracle.com/cloud/free/) yet?  What are you waiting for? You can get 2 Autonomous DB instances, 2 VMs, Object Storage, and much more. For FREE!  

I will explain the script below, but for those who are wondering it is written using the [Groovy](https://groovy-lang.org/) programming language. Groovy is an optionally typed, dynamic JVM language (that offers static compilation as well) and I've been using it to write both web applications and for simple scripting tasks for the last 9 years. If you've worked with Gradle or Jenkins, you've probably already written some Groovy and you just might not have known it.  If you're a Java user, this script will look familiar to you for the most part. The only tricky bit might be the `each` [closure](http://docs.groovy-lang.org/next/html/documentation/#_closures) which is one of the collection method add-ons to the List class in the GDK. If you're looking to learn more about then you should certainly refer to the [documentation](http://docs.groovy-lang.org/next/html/documentation/#_introduction).

## Setup

I usually create a project that is used for common scripts that utilizes a Gradle build file to pull in any necessary dependencies. We can run any Groovy file via Gradle with some simple setup. In this case, my project is for scripts that utilize the OCI Java SDK so I have the following `build.gradle` in the project root directory.
```groovy
apply plugin: 'groovy'
repositories {
    jcenter()
}
dependencies {
    compile localGroovy()
    implementation('javax.activation:javax.activation-api:1.2.0')
    implementation('com.oracle.oci.sdk:oci-java-sdk-full:1.17.4')
}
```



Then I add a task for each individual script in the project directory so I can run them individually. Here's the task for my `ResizeImages.groovy` script (that resides in the `src/main/groovy/codes/recursive` directory):
```groovy
task resizeImages(type: JavaExec) {
    description 'Run resize images script'
    main = 'codes.recursive.ResizeImages'
    classpath = sourceSets.main.runtimeClasspath
}
```



## The Script

The script begins with the creation of an auth provider object and an object storage client instance. It's easiest to use a `ConfigFileAuthenticationDetailsProvider`, especially if you're already using the OCI CLI locally since you'll have an existing config file to point at.
```groovy
AuthenticationDetailsProvider provider =
        new ConfigFileAuthenticationDetailsProvider(
                '~/.oci/config', 
                'recursivecodes')

ObjectStorage client = new ObjectStorageClient(provider)
client.setRegion(Region.US_ASHBURN_1)
```



**Confused?**  Groovy doesn't require the use of semi-colons. You won't miss them, trust me!

Next, declare a few variables to contain your object storage namespace and the name of the bucket you want to operate on.
```groovy
def ns = '[your namespace]'
def bucket = '[your bucket name]'
```



In Groovy, `def` can be used to define a variable without declaring it's type ahead of time. You can even change the type later on by assigning a value of a different type!

Now I create the ListObjectsRequest (indicating that we want the "size" field returned along with each item) and pass the listObjectsRequest to the listObjects method on the client. This gives us back a ListObjectsResponse that we'll iterate over next.
```groovy
ListObjectsRequest listObjectsRequest = ListObjectsRequest.builder()
        .bucketName(bucket)
        .namespaceName(ns)
        .fields("size")
        .build()

ListObjectsResponse listObjectsResponse = client.listObjects(listObjectsRequest)
```



Now we can iterate over the response using the `each` closure that Groovy adds to `java.util.List.`
```groovy
listObjectsResponse.listObjects.objects.each { ObjectSummary it -> }
```



Within the closure, we receive the current list item, in this case, an `ObjectSummary` containing information about the object. If the object is larger than 500kb then we'll construct a `GetObjectRequest` to retrieve the object, then resize the image by 50%, save a copy locally in case something happens, then craft and send a `PutObjectRequest` to overwrite the previous image. Certainly, I could have added more logic to make sure the object was a valid image first, but in this case, I know for a fact that all of the items in my bucket were either JPG or PNG. Here's the fully populated loop.
```groovy
listObjectsResponse.listObjects.objects.each { ObjectSummary it ->
    def kb = it.size / 1024

    if( kb > 500 ) {

        def getObjectReq = GetObjectRequest.builder()
                .namespaceName(ns)
                .bucketName(bucket)
                .objectName(it.name)
                .build()

        GetObjectResponse getObjectResponse = client.getObject(getObjectReq)
        BufferedImage img = ImageIO.read(getObjectResponse.inputStream)

        final int w = img.getWidth()
        final int h = img.getHeight()

        int type = img.getType() == 0? BufferedImage.TYPE_INT_ARGB : img.getType()
        final int w2 = Math.ceil(w/2).toInteger()
        final int h2 = Math.ceil(h/2).toInteger()

        BufferedImage resizedBuffImg = new BufferedImage(w2, h2, type)
        Graphics2D g = resizedBuffImg.createGraphics()
        g.drawImage(img, 0, 0, w2, h2, null)
        g.dispose()

        def newFile = new File("/tmp/resizedimages/${it.name}")
        newFile.getParentFile().mkdirs()
        String ext = it.name.tokenize(".").last()

        ImageIO.write(resizedBuffImg, ext, newFile)

        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                            .objectName(it.name)
                            .bucketName(bucket)
                            .namespaceName(ns)
                            .putObjectBody( newFile.newInputStream() )
                            .build()

        client.putObject(putObjectRequest)

        println "$it.name was reduced from ${kb}kb to ${newFile.size()/1024}kb"

    }
}
```



So what did this do for me? Pictures and graphs often tell a better story than words, so let's look at my bucket metrics for the past 7 days:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/41c50ea5-f0cd-4f9c-80f5-65022dee984e/2020_06_02_13_31_31.png)

As you can see, the total bucket size was reduced from around 205MB to around 71MB. This will easily result in approximately 65% cost savings for me every month. Which means I've got about an extra dollar or two to spend every month. Yeah!!!

Check out the [entire script on GitHub](https://gist.github.com/recursivecodes/fd0277c81bcb366af82e2f6a6d5096c2)!

Photo by [Geronimo Giqueaux](https://unsplash.com/@ggiqueaux?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/money?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
