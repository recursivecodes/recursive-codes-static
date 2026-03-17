---
title: "Installing Node-RED In An Always Free VM On Oracle Cloud"
slug: "installing-node-red-in-an-always-free-vm-on-oracle-cloud"
author: "Todd Sharp"
date: 2019-10-16
summary: "In this post we'll look at how to install Node RED in an \"always free\" VM on the Oracle Cloud."
tags: ["Cloud", "JavaScript"]
keywords: "Cloud, Javascript, node.js"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/banner_samuel_ferrara_o3qec4dowkm_unsplash.jpg"
---

Last month at Oracle Open World we announced a very exciting "always free" tier for Oracle Cloud. I recently [blogged about how you could use an "always free" VM to run a Minecraft server](/posts/how-to-setup-and-run-a-free-minecraft-server-in-the-cloud), and I thought that it would be good to do an ongoing series of posts that highlight some different projects that our "always free" VMs and Autonomous DB instances can be used for. In today's edition, we'll take a look at installing [Node-RED](https://nodered.org/).

Here's an outline of the sections below, feel free to skip ahead if you're already familiar with a specific step:

- [Free Cloud Sign Up](#signup)
- [What Is Node-RED?](#what)
- [Creating An Always Free VM](#create-vm)
- [Modifying Your Security List](#security-list)
- [SSH Into Your VM](#ssh)
- [Installing Node-RED](#install-node-red)
- [Securing Node-RED](#securing)

Let's get into it!

## Free Cloud Sign Up 

Before we get started, you'll have to [sign up for a free account](https://www.oracle.com/cloud/free/) with Oracle Cloud. Sign up requires a credit card, but there are absolutely no charges at all if you follow the tutorial below.

If you're not yet the age of majority (usually 18), please have your parent sign up for a free Oracle Cloud account and help you with the steps below!

After you have created your free account and signed in, the first thing you'll need to do is create a virtual machine that will be used to host the Minecraft server.

## What Is Node-RED? 

If you're not familiar with Node-RED, their website describes the project as:

{{< callout >}}
Node-RED is a programming tool for wiring together hardware devices, APIs and online services in new and interesting ways.

It provides a browser-based editor that makes it easy to wire together flows using the wide range of nodes in the palette that can be deployed to its runtime in a single-click.
{{< /callout >}}
Here's a quick intro video to help you understand what it is and how it 

As you can see, it's a pretty powerful and fun application to play around with. Let's create a VM that we can use to install it! 

## Creating An Always Free VM 

Log in to your Oracle Cloud account and head to the console. From the dashboard, select 'Create a VM Instance' to get started.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_12_19_08.jpg)

Next, enter a name for your instance and make sure that the Image Source is Oracle Linux 7.7.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_09_52_41.jpg)

Make sure that the Availability Domain, Instance Type and Instance Shape are all "Always Free Eligible".

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_09_56_58.jpg)

Now scroll down and upload a public SSH key that you can use later on to SSH in to the VM once it is running.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_02_05.jpg)

Scroll down and make sure that "Assign a public IP address" is selected.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_09_59_06.jpg)

Click 'Create' and you'll be taken to the instance details where the VM will be in a "Provisioning" state.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_05_09.jpg)

When the VM becomes "Active" you'll have a public IP address assigned. Copy this and keep it handy for later.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_06_14.jpg)

## Modifying Your Security List 

On the instance details page, click on your assigned subnet.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_07_40.jpg)

In the left hand sidebar on the subnet details page, click on "Security Lists":

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_08_15.jpg)

Then click on the default security list to edit it:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_08_38.jpg)

Add an ingress rule for port 1880, the port used by Node-RED:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_09_24.jpg)

## SSH Into Your VM 

From a terminal window on your local machine, make an SSH connection into your VM using the private key associated with the public key you specified at instance creation and the IP address of your VM. Use `opc` as the username:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_13_18_51.jpg)

## Installing Node-RED 

There are a [number of tutorials for installing Node-RED](https://nodered.org/docs/getting-started/), but the one we'll use is [the "manual install" method](https://github.com/node-red/linux-installers) (just ignore any references to Raspberry Pi in this script). To run this script, first evaluate it on GitHub and then run:

`bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/rpm/update-nodejs-and-nodered)`

Note: This script will install Node.JS, Node-RED and optionally add a firewall rule that adds port 1880 to the public zone. Answer "y" to allow this firewall rule to be created when it asks you.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_15_18.jpg)

Once it is complete you will see output similar to this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_25_15.jpg)

Start Node-RED with `node-red-start`and you will see output similar to the following:
```bash
Once Node-RED has started, point a browser at http://10.0.2.6:1880
On Pi Node-RED works better with the Firefox or Chrome browser

Use   node-red-stop                          to stop Node-RED
Use   node-red-start                         to start Node-RED again
Use   node-red-log                           to view the recent log output
Use   sudo systemctl enable nodered.service  to autostart Node-RED at every boot
Use   sudo systemctl disable nodered.service to disable autostart on boot

To find more nodes and example flows - go to http://flows.nodered.org

Starting as a systemd service.
Started Node-RED graphical event wiring tool.
15 Oct 14:28:07 - [info]
Welcome to Node-RED
===================
15 Oct 14:28:07 - [info] Node-RED version: v1.0.2
15 Oct 14:28:07 - [info] Node.js  version: v10.16.3
15 Oct 14:28:07 - [info] Linux 4.14.35-1902.5.2.2.el7uek.x86_64 x64 LE
15 Oct 14:28:08 - [info] Loading palette nodes
15 Oct 14:28:09 - [info] Settings file  : /home/opc/.node-red/settings.js
15 Oct 14:28:09 - [info] Context store  : 'default' [module=memory]
15 Oct 14:28:09 - [info] User directory : /home/opc/.node-red
15 Oct 14:28:09 - [warn] Projects disabled : editorTheme.projects.enabled=false
15 Oct 14:28:09 - [info] Flows file     : /home/opc/.node-red/flows_node-red.json
15 Oct 14:28:09 - [info] Creating new flow file
15 Oct 14:28:10 - [warn]
---------------------------------------------------------------------
Your flow credentials file is encrypted using a system-generated key.
If the system-generated key is lost for any reason, your credentials
file will not be recoverable, you will have to delete it and re-enter
your credentials.
You should set your own key using the 'credentialSecret' option in
your settings file. Node-RED will then re-encrypt your credentials
file using your chosen key the next time you deploy a change.
---------------------------------------------------------------------
15 Oct 14:28:10 - [info] Server now running at http://127.0.0.1:1880/
15 Oct 14:28:10 - [info] Starting flows
15 Oct 14:28:10 - [info] Started flows
```



You can ensure that Node-RED always starts at boot with:

`sudo systemctl enable nodered.service`

You're now ready to launch Node-RED in your browser at `http://[public-IP]:1880`

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/557050d0-04df-4af7-980d-355947239834/2019_10_15_10_30_26.jpg)

You're now ready to start creating and deploying flows in your "always free" VM on the Oracle Cloud.  You can create your own flow from scratch or [import a flow from the Node-RED Library](https://flows.nodered.org/). What great ideas do you have for Node-RED in your "always free" VM? Leave them in the comments below!

## Securing Node-RED 

Now that you're up and running, you'll need to secure your Node-RED install in a few ways. You should [check out the Node-RED docs to learn how to properly secure your install](https://nodered.org/docs/user-guide/runtime/securing-node-red) with a username and password. Also, you'll want to [use a SSL/TLS cert for HTTPS transport and encryption which is easy to configure in the Oracle Cloud](/posts/free-ssl-certificates-in-the-oracle-cloud-using-certbot-and-lets-encrypt).

Photo by [Samuel Ferrara](https://unsplash.com/@samferrara?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/flow?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
