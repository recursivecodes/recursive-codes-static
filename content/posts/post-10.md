---
title: "A Better Way To Develop For The Raspberry Pi"
slug: ""
author: "Todd Sharp"
date: 2017-03-20
summary: "In the last post in this series we took a look at creating a simple Groovy script using Pi4J to interact with the GPIO pins on a Raspberry Pi.  In this post we'll look at using IntelliJ IDEA to code for the Raspberry Pi."
tags: ["Grails", "Groovy", "Groovy On Raspberry Pi", "Raspberry Pi"]
keywords: "IntelliJ, IDEA, Raspberry Pi, Developing for Raspberry Pi, Grails on Raspberry Pi, Groovy, Programming Raspberry Pi"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/10/banner_51e4d6464e5bb108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

{{< callout >}}
**Note**:  I've dropped the "Grails on Raspbery Pi" intro to the title of these posts for the sake of brevity, but this post and most of the posts coming in the near future continue upon that series. You can follow [this tag](http://recursive.codes/page/tagged/9?tag=Grails+On+Raspberry+Pi) if you would like to see all the posts in this series.
{{< /callout >}}
In the [last post](http://recursive.codes/blog/post/8) in this series we took a look at creating a simple Groovy script using Pi4J to interact with the GPIO pins on a Raspberry Pi.  It was a simple example, so writing the code in nano wasn't really a big deal, but as you get into more complex scripts having a true IDE to write our scripts will make a heck of a lot easier.  Problem is, running a full blown IDE like [IntelliJ IDEA](https://www.jetbrains.com/idea/) and accessing it via VNC on the Pi is a pretty sketchy proposition.  Trust me, I've tried.  ***Technically***,  it works, but about as well as [one of these](http://www.sciencealert.com/the-close-door-buttons-in-elevators-don-t-actually-do-anything):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/elevator-close.jpg)\

So why not use IntelliJ on another machine on your home network (or any network, as long as the Pi is web accessible)?  Unlike an elevator close button, it actually works (and quite well, thank you very much)!  This post is going to be pretty heavy on screenshots because I think they tell the story pretty well.  

{{< callout >}}
**Note:** Remote development is only available in IntelliJ IDEA Ultimate Edition.
{{< /callout >}}
**Step 1**:  Create a new Groovy project in IDEA:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-1.jpg)

**Step 2**: Name it, and choose a location to store it.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-2.jpg)

**Step 3**:  Create a new Groovy class file.  Delete whatever code IDEA automatically populates in the file.  We're using this as a Groovy script, not a true class file.  Like the last post, name it `led-test.groovy`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-3.jpg)

**Step 4**:  Paste the code from the [last post](http://recursive.codes/blog/post/8) into our new Groovy script.  Here it is again for your reference:
```groovy
Grapes([
        @GrabResolver(name='sonatype', root='https://oss.sonatype.org/content/groups/public/'),
        @Grab(group='com.pi4j', module='pi4j-core', version='1.2-SNAPSHOT')
])

import com.pi4j.io.gpio.*

println('getting gpio controller')

GpioController gpio = GpioFactory.getInstance()
GpioPinDigitalOutput outputPin = gpio.provisionDigitalOutputPin(RaspiPin.getPinByAddress(8))

println('turn on led')
outputPin.setState(true)
sleep(3000)

println('turn off led')
outputPin.setState(false)
println 'done'

gpio.shutdown()
```

\

You'll notice in the screenshot below that we have some errors, we'll get to those in a second.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-4.jpg)

**Step 5**:  Place your cursor right after the `@Grab` annotation and press ALT+ENTER, then select 'Grab the artifacts'.  IDEA will download the Pi4J dependency.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-5.png)

**Step 6**: Confirm in the Event Log that IDEA successfully downloaded the dependency.  Observe the errors with class resolution are now resolved.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-6a.jpg)

**Step 7**: Try code completion, notice that it works, nod your head and smile.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-6b.png)

**Step 8**: Let's set up remote deployment.  In IDEA, go to Tools - Deployment - Configuration.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-7.jpg)

**Step 9**:  Set up the connection.  Enter your Pi's local IP, use port 22, enter the root path for your project on the Pi and enter your credentials.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-8.jpg)

**Step 10**:  Click 'Test SFTP connection', if you receive the following warning, click Yes.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-9.jpg)

**Step 11**:  Marvel in amazement with your jaw agape at the successful connection.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-10.jpg)

**Step 12**:  Jump to the Mappings tab, if it is enabled click the 'Use this server as default' button.  Enter or modify the local path if necessary.  Make sure to add the 'src' directory if it's not there on the end. Click OK and exit the dialog.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-11.jpg)

**Step 13**:  Back in IDEA, click Tools - Deployment - Options.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-12.jpg)

**Step 14**:  Make sure that 'Upload changed files automatically to the default server' is set to 'On explicit save action (CTRL+S).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-13.jpg)

**Step 15**:  Now we should be ready to test things out.  SSH into your Pi (I use the Terminal window in IDEA for this).  Take a look at the directory where you previously saved your script.  Note that this script hasn't been changed since March 16 at 10:01 PM.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-14.jpg)

**Step 16**:  Run the script from the SSH terminal.  You'll see your LED light up just like it did in our last post.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-15.jpg)

**Step 17**:  It might not be necessary, but I like to go back and hit Tools - Deployment - Sync with Deployed\... just to make sure the contents on both boxes match up before I change anything.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-16.jpg)

**Step 18**:  Change the `println` statement on line 19 and save the file.  Notice that IDEA immediately pushes the change up to the Pi.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-17.jpg)

**Step 19**:  List the contents of your directory (not shown in screenshot) and you'll notice the updated modified timestamp on the file.  Run the script again on the Pi.  You'll see the result of your change in the console.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/intellij-remote-deploy-18.jpg)

And that's how you make your life super duper easy when writing code for the Raspberry Pi.  When we get into writing Grails applications, we'll run Grails on the Pi as we develop remotely.  Grails will automatically load the changes when running in development mode and our running application will immediately reflect them.  

As a footnote, I should mention that a similar process should absolutely work with PyCharm if you're doing Python development for the Pi. Here is a [blog post](https://blog.jetbrains.com/pycharm/2015/03/feature-spotlight-python-remote-development-with-pycharm/) that outlines the steps involved, but they're almost identical to this process.

Image by [ElinaElena](https://pixabay.com/users/ElinaElena-970541) from [Pixabay](https://pixabay.com)
