---
title: "Free SSL Certificates In The Oracle Cloud Using CertBot And Let's Encrypt "
slug: "free-ssl-certificates-in-the-oracle-cloud-using-certbot-and-lets-encrypt"
author: "Todd Sharp"
date: 2019-10-23
summary: "In this post we'll look at how you can enable HTTPS for your web application that runs on Oracle Linux in the Oracle Cloud by using an application called CertBot to create your SSL/TLS certificates via Let's Encrypt."
tags: ["Cloud", "Containers, Microservices, APIs"]
keywords: "SSL, TLS, TLSv1.2, HTTPS, Security, Cloud, Cloud Security, encryption"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/banner_james_sutton_fqaybx9ziou_unsplash.jpg"
---

If you're deploying your web site or application on the Oracle Cloud, chances are pretty high that you're going to be using HTTPS to secure your connections. And if you're not deploying your site with HTTPS, you should be. Most browsers nowadays will flag your HTTP only site as "Not Secure" which means the data that you enter on such sites can be easily intercepted by someone listening.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_08_33_10.jpg)

To illustrate this point really simply, take a simple login form on an insecure (HTTP) site. When we post our login form on this site, all of the data that we send through with that request is sent in plain text. This means that anyone who may be "listening" on that network can easily see your credentials.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_14_14_16.jpg)

But when we use TLS (HTTPS) to post that form, the data is encrypted so that it is protected in transport. Someone listening in on this "conversation" would hear total gibberish.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_14_34_16.jpg)

Of course, I'm greatly simplifying things here to illustrate my point, but in practice this is exactly why you should be using HTTPS on all of your sites and applications. 

Clearly, we want to use SSL/TLS, so the next question is: how? For this we need to get a certificate and configure our application to use that cert. To generate our cert we'll be using a program called [CertBot](https://certbot.eff.org/) that generates a free cert via a service called [Let's Encrypt](https://letsencrypt.org/). There aren't a lot of steps to do this, but in my personal experience it can be tricky to get working in certain environments and with certain application deployment strategies. In this guide I'll show you how to install CertBot in an Oracle Linux instance in the Oracle Cloud. You might be using an "always free" VM, or any other shape - it doesn't matter. Follow the instructions below and get your cert generated, setup for automatic renewal and deployed to your site in minutes.

**But I'm Not Using Oracle Linux! ** That's totally cool - we offer many other OS images and the steps below should work for pretty much any \*nix variant since we're using the generic instructions from CertBot that aren't specific to a certain distribution.

Here are the steps we'll take. If you need to jump past a section, use the links below.

- [Create Your VM](#create-vm)
- [Before You Get Started](#before)
- [Installing CertBot](#install)
- [Creating A Certificate](#create)
- [Scheduling Certificate Renewal](#renew)
- [Deploying A Site With Your New Certificate](#deploy)

## Create Your VM 

To create an "always free" VM, click 'Create a VM instance' from the Oracle Cloud console.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_06_23.jpg)

Give your instance a name and choose the image source. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_06_56.jpg)

Make sure the Availability Domain and Instance Type are both "always free eligible".

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_07_19.jpg)

As well as the instance shape.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_07_36.jpg)

Make sure 'Assign a public IP address' is selected (it is not selected by default):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_07_51.jpg)

Add a public SSH key.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_08_19.jpg)

Click 'Create' and your VM will be shown in a 'Provisioning' state:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_15_10_05_09.jpg)

When it is provisioned, grab your public IP:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_15_10_06_14.jpg)

## Before You Get Started 

Before you can create a certificate for your application, you'll need a domain name to be associated with your public IP address. Follow the instructions for your domain name host to point a domain name at your public IP.  Here's what that might look like using Route 53:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_22_14_59_23.jpg)

Before we move on, make sure that port 80 is open in your security list and in the VM firewall. CertBot will need this open to verify your machine during certificate creation.

From the VM details page, click on the subnet:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_22_16_14_38.jpg)

Choose 'Security Lists' from the subnet details sidebar:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_22_16_15_38.jpg)

Select the security list:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_22_16_15_57.jpg)

And add an ingress rule for port 80:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_22_16_16_37.jpg)

Next, run the following to open up port 80 on the VM firewall:
```bash
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload
```

 

## Installing CertBot 

**Heads Up!** If you've skipped ahead, are you sure that port 80 is open on the VM and in your VM's security list?

We can now SSH in to our VM and begin the install process for CertBot. As I mentioned above, [we'll use the generic "Other UNIX" instructions](https://certbot.eff.org/lets-encrypt/pip-other) from CertBot to avoid any potential issues that may arise with distribution specific installations. 

Run the following commands to install CertBot:
```bash
wget https://dl.eff.org/certbot-auto
sudo mv certbot-auto /usr/local/bin/certbot-auto
sudo chown root /usr/local/bin/certbot-auto
sudo chmod 0755 /usr/local/bin/certbot-auto
```



You're now ready to create a cert.

## Creating A Certificate 

Since we haven't yet installed a webserver, let's run CertBot in standalone mode. It will spin up a temporary webserver during this process:
```bash
sudo /usr/local/bin/certbot-auto certonly --standalone
```



The first time you run CertBot you'll need to provide some info that is used when the cert is generated:
```bash
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator standalone, Installer None
Enter email address (used for urgent renewal and security notices) (Enter 'c' to
cancel):

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please read the Terms of Service at
https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf. You must
agree in order to register with the ACME server at
https://acme-v02.api.letsencrypt.org/directory
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(A)gree/(C)ancel:


- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about our work
encrypting the web, EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o:

Please enter in your domain name(s) (comma and/or space separated)  (Enter 'c'
to cancel): node-red.toddrsharp.com
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for node-red.toddrsharp.com
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/node-red.toddrsharp.com/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/node-red.toddrsharp.com/privkey.pem
   Your cert will expire on 2020-01-20. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot-auto
   again. To non-interactively renew *all* of your certificates, run
   "certbot-auto renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
```



Congrats, you've generated your free certificate! Now, let's move the new certs to another directory. In this example, I'm going to use the cert to secure an [instance of Node-RED that I have spun up in an "always free" VM](/posts/installing-node-red-in-an-always-free-vm-on-oracle-cloud), so I'll move them to the proper directory for that:
```bash
mkdir ~/.node-red/certs
cp  /etc/letsencrypt/live/node-red.toddrsharp.com/*.pem /home/opc/.node-red/certs/
```



We'll want this to happen every time the certs are renewed, so create a script at `/etc/letsencrypt/renewal-hooks/deploy/copy-certs` and populate it with the script below. Files contained in the "deploy" directory will be executed after each successful renewal.
```bash
#!/bin/bash

domain=[your domain name]
cert_dir=[/path/to/cert/copy/dir]
user=opc

cp /etc/letsencrypt/live/$domain/*.pem "$cert_dir"/
chown $user "$cert_dir"/*.pem
```



Now let's schedule the cert to automatically renew before it expires.

## Scheduling Certificate Renewal 

Scheduling renewal is easy. Create a CRON task to run CertBot:
```bash
echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/local/bin/certbot-auto renew" | sudo tee -a /etc/crontab > /dev/null
```



If you want to stop a running webserver before renewal and start it after renewal, use `--pre-hook` and `--post-hook`:
```bash
echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/local/bin/certbot-auto renew --pre-hook 'node-red-stop' --post-hook 'node-red-start'" | sudo tee -a /etc/crontab > /dev/null
```



Your certs will now be automatically renewed!

## Deploying A Site With Your New Certificate 

This step can vary widely depending on your application and how it is deployed, but essentially at this point you have legitimate certificates that can be used with your application. Since I [recently blogged about creating an instance of Node-RED](/posts/installing-node-red-in-an-always-free-vm-on-oracle-cloud), let's take a look at how you might use these certs to secure a Node-RED instance.

Find your `settings.js` file - with a default install it will be located at `~/.node-red/settings.js`. Open this file up and make the changes below.

**Step 1**:  Uncomment to include the '`fs`' module:
```javascript
var fs = require("fs");
```



**Step 2**: Uncomment the https object and update the paths for the key and cert to point at our new cert:
```javascript
https: {
    key: fs.readFileSync('/home/opc/.node-red/certs/privkey.pem'),
    cert: fs.readFileSync('/home/opc/.node-red/certs/fullchain.pem')
},
```



**Step 3**:  Uncomment (if necessary) and update the `requireHttps` value to be `true`. You can now restart node-red and your instance will be running on HTTPS!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6fc2985d-db8b-4002-8733-d6f6c8be54ed/2019_10_23_16_45_47.jpg)

## Footnote

Note:  You may have come across [this guide in the past when trying to configure your certs on Oracle Linux](https://oracle-base.com/articles/linux/letsencrypt-free-certificates-on-oracle-linux). Unfortunately, it seems that something has changed since that article was published. When you try and follow the instructions in Tim's post when using Oracle Linux 7.7 you'd end up with the following exception:

ImportError: 'pyOpenSSL' module missing required functionality. Try upgrading to v0.14 or newer.

Trying to resolve this issue only led to further issues with other Python dependencies, so I decided to follow the generic "Other UNIX" instructions via the CertBot site. This led to an error free install and seems to be the safest and most "future-proof" route for installing CertBot. 

Photo by [James Sutton](https://unsplash.com/@jamessutton_photography?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/secure?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
