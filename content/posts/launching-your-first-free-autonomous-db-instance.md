---
title: "Launching Your First Free Autonomous DB Instance"
slug: "launching-your-first-free-autonomous-db-instance"
author: "Todd Sharp"
date: 2019-09-27
summary: "Autonomous DB is available as an \"always free\" service on Oracle Cloud. Here's everything you need to get started using it in less than 15 minutes!"
tags: ["Cloud", "Database"]
keywords: "Database, AUTONOMOUS, DB"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/banner_william_white_cf6fz9qwfry_unsplash.jpg"
---

You're a developer, which means you have roughly 4.3 conversations each week with friends and family about building an application for a club, sports league, charity, church group or other organization. I know this, because I also have those same conversations every week, without fail. And I've built a few of those apps myself. The thing that those friends and family don't realize is that it costs actual money to host those sites on the internet. Sometimes we can find free hosting for the simple ones, but for the more advanced or custom applications we often end up going to a cloud provider and finding the cheapest tier available and using that. Things like simple custom blogs or golf league websites that don't draw more than a few dozen hits a week often can use the cheap tier without concern. But even the cheap tier can start to add up over time.

I've got good news. You don't have to host that stuff on the cheap (or time bound "free") tiers anymore. Introducing the ["always free" tier from Oracle Cloud](https://www.oracle.com/cloud/free/#always-free). Now you can host those robotics club websites and simple bowling league blogs for free, forever, in the easy to use Oracle Cloud. I'm not just talking about compute here either - you get a few VMs, of course - but you also get storage, load balancing and **2 free Autonomous DB instances**. Yeah, that's pretty amazing. 

But before you run off to sign up, let me show you just how easy it is to get started with free Autonomous DB in the Oracle Cloud.

## Sign Up

It's really quick and easy. [Go here, enter your info and sign up](https://www.oracle.com/cloud/free/#always-free). Yeah, you need to put in a credit card. No, you won't be charged unless you opt in to paid services. Yes, we clearly tell you "always free" when something is "always free". It's not hidden, or ambiguous. Here's the first screen you need to fill out:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_27_18.jpg)

Click Next, and enter some personal info:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_29_20.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_30_27.jpg)

Then verify your mobile number:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_31_35.jpg)

Next, choose an account password (this will be used to log in to your cloud account):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_32_30.jpg)

Next, enter your payment information and then click 'Complete Sign-Up':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_36_04.jpg)

It takes about 10 minutes to fully provision your account, but once that's complete you'll receive an email letting you know it's ready to go. You can login in with your email and password at the following url:

**Oracle Cloud Console**: <https://cloud.oracle.com/sign-in>

 

## Creating Your First Free Autonomous DB

Once you've logged in to your fully provisioned account you are immediately able to start creating your free Compute and Autonomous DB instances. In fact, the very first thing you'll probably see is "Quick Actions" to do just that:

## ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_23_10_22_33.jpg)

Notice the 'Always Free Eligible' label. You'll see this label, or a label that says "Always Free" on created resources, for items that will never include any charges whatsoever. Click 'Create a database' to get started, which will bring you to the Autonomous DB instance creation screen where you can enter a display name, database name and choose your workload type:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_23_10_24_05.jpg)

Choose deployment type - most likely you'll choose 'serverless' (which really just means the DB resides on shared infrastructure) and toggle the "Always Free" option:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_23_10_24_30.jpg)

Create your admin credentials and finally click 'Create Autonomous Database' to launch the provisioning of your first free instance:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_26_11_45_54.jpg)

You'll be redirected to the instance details page - note the 'Always Free' label and the Instance Type of "Free". It'll take a few minutes to provision your instance:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_23_10_29_30.jpg)

And when it's complete, you'll see the state change to 'Running'. Next, click on 'DB Connection':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_23_10_30_38.jpg)

Within the Database Connection dialog, download your Client Credentials Wallet. This is used by your applications and tools to initiate a secure connection to your Autonomous DB instance.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b023ff0b-ed0e-4e6c-9351-76c6308d0f12/2019_09_23_10_31_39.jpg)

And that's it. You've signed up for a free Oracle Cloud account and launched an always free DB instance with 20 GB of storage in less than 15 minutes. 

Photo by [William White](https://unsplash.com/@wrwhite3?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/free?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
