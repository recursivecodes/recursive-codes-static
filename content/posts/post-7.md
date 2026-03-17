---
title: "Grails on Raspberry Pi Part 3 - Installing Groovy And Grails"
slug: ""
author: "Todd Sharp"
date: 2017-03-16
summary: ""
tags: ["Grails", "Groovy", "Groovy On Raspberry Pi", "Java", "Raspberry Pi"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7/banner_51e4dc454857b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/start.jpg)

The first step in getting working with Grails on the Raspberry Pi is, of course, installing Grails.  I've been somewhat dreading this post because it's pretty hard to make installing software interesting, but it's necessary so we'll trudge through it and try to have a good time with it.  If you've never worked with Groovy or Grails before, that's quite alright.  I'll do my best to make sure that I keep things basic, but at the same time you might want to run through some Groovy or Grails tutorials (there are plenty out there).  Also, feel free to ask questions.  My goal is to help you get a web site up and running on the Raspberry Pi.

There are two ways to [install Grails](https://grails.org/download.html).  One way is to download it yourself, and the right way is to install [SDKMAN](http://sdkman.io/) and use it to install Grails for you.  Follow the instructions on the Grails download page to install SDKMAN, but before you do make sure that you have "zip" installed first via:\
\
`sudo apt-get install zip`\

**Note:  **SDKMAN will prompt you to run the following command after it installs:

    Please open a new terminal, or run the following in the existing one:
    source "/home/pi/.sdkman/bin/sdkman-init.sh"

Don't skip this step, else you'll get errors complaining that "sdk: command not found".  Once SDKMAN is installed, install Grails via:

`sdk install grails`

Seriously, that's all it takes. Since you didn't pass a specific version to SDKMAN it'll grab the latest version and install it (which is 3.2.7 as of the time this post was published).  

Well, I kinda lied - if you actually want to *run* Grails, you'll have to [set the JAVA_HOME](http://tiriboy.blogspot.com/2015/08/setting-javahome-on-raspberry-pi.html) environment variable so that Grails knows where Java is.  After you set JAVA_HOME, run:

`grails -version`\

Since Grails uses the Groovy language, it'll also install the required Groovy version, but I typically like to also install a standalone version of Groovy for one off scripts and testing purposes.  To install Groovy, just do:

`sdk install groovy`\

I typically also create a folder called "Projects" in my home directory so feel free to do something similar at this point.  If you want to create a simple test Groovy script, create a file called test.groovy and enter the following using nano (or vi if you're crazy):

`println new Date().format('MM-dd-yyyy')`\

Run it from the command line with:

`groovy test.groovy`\

And it'll output the current date.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/thumbsup.jpg)

And that's all it takes to get Groovy and Grails installed on the Raspberry Pi.  In the next post we'll look at creating a slightly more complex Groovy script to illustrate how easy it is to use for simple scripting and even more complex tasks.

Image by [Comfreak](https://pixabay.com/users/Comfreak-51581) from [Pixabay](https://pixabay.com)
