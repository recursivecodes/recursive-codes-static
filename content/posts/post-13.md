---
title: "Creating Your First Website On Raspberry Pi"
slug: ""
author: "Todd Sharp"
date: 2017-03-27
summary: "In this post we'll create and deploy a simple website on the Raspberry Pi.  There are a few prerequisites that I've covered in some previous posts - notably installing Grails and remotely deploying our code - so please refer to the previous posts in this series if you get stuck:"
tags: ["Grails", "Groovy", "Groovy On Raspberry Pi", "Raspberry Pi"]
keywords: "raspberry pi, first website, website on raspberry pi, grails on raspberry pi"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/13/banner_55e2dc474c5aad14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

In this post we'll create and deploy a simple website on the Raspberry Pi.  There are a few prerequisites that I've covered in some previous posts - notably installing Grails and remotely deploying our code - so please refer to the previous posts in this series if you get stuck:

[Part 1](http://recursive.codes/blog/post/5) \

[Part 2](http://recursive.codes/blog/post/6)

[Part 3](http://recursive.codes/blog/post/7)

[Part 4](http://recursive.codes/blog/edit/8)

[Part 5](http://recursive.codes/blog/edit/10)

In the previous posts we had not yet installed Gradle on the Raspberry Pi, so before we get started, SSH into your Raspberry Pi and use SDKMAN to install Gradle:

`sdk install gradle`\

Now lets create a new Grails project in IntelliJ IDEA on a machine other than your Pi (see this [previous post](http://recursive.codes/blog/edit/10)).

{{< callout >}}
Make sure that the Grails version that you choose matches the version of Grails you've previously installed on your Pi.  (You did [install it](http://recursive.codes/blog/post/7) already, right?)\
{{< /callout >}}
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-1.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-2.jpg)

When IntelliJ prompts you, go ahead and click `Run 'create-app'`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-3.jpg)

After your project has been created, if you've got Grails installed on your machine that you're developing on you can try `grails run-app` and see the application running on your local machine.  You won't be able to run it locally like this much longer since we'll be getting into GPIO integration and your local machine doesn't have any GPIO access!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-4.jpg)

Set up a remote deployment server (see [post 5](http://recursive.codes/blog/post/10)) and after you've created the application, go to Tools - Deployment - Sync with Deployed\...

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-5.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-6.jpg)

After you've synched up with the Pi, do a directory listing on the project directory on the Pi and you'll see all of the files that we just transferred. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-7.jpg)

At this point you should be set to run `grails run-app` on the Pi.  The first time it runs you'll notice quite a bit of dependencies need to be downloaded.  That'll only happen the first time you run the app.  Once the dependencies are downloaded, you'll get a message that the app is running:

    Grails application running at http://localhost:8080 in environment: development

The localhost in this case refers to the Pi, so unless you're using VNC you won't be able to use localhost.  Instead, try:

    http://[Raspberry Pi IP]:8080

And you should see:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/grails-pi/new-grails-project-8.jpg)

Woohoo!  You've now got a website up and running on the Pi!  The cool thing about our setup at this point is that Grails is running in development mode.  This means we can change code and Grails will compile and deploy the change on the fly.  Open up the view called `index.gsp` inside the `/views `directory and make a change to the text and see what happens.

\[youtube id=BUuFHaVqxxE\]

Image by [jplenio](https://pixabay.com/users/jplenio-7645255) from [Pixabay](https://pixabay.com)
