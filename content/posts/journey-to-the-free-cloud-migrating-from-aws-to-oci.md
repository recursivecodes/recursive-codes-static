---
title: "Journey To The Free Cloud - Migrating From AWS To OCI"
slug: "journey-to-the-free-cloud-migrating-from-aws-to-oci"
author: "Todd Sharp"
date: 2019-09-30
summary: "Everything you need to know about migrating an application from Amazon Web Services to Oracle Cloud. "
tags: ["Cloud", "Database", "Developers"]
keywords: "migration, Cloud, Database, AUTONOMOUS"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/banner_nghia_le_v3dokm1nqcs_unsplash__1_.jpg"
---

Last week at Oracle Open World we made a game changing announcement - a completely free tier of services for Oracle Cloud. I've read the criticisms on Twitter and I know you're skeptical. Nothing's truly free, right? But it's true - a [completely free tier](https://www.oracle.com/cloud/free/#always-free). Not for 1 month. Not for 12 months. Forever. Autonomous Database is included in the "always free" tier offering and you can get 2 instances - each with 1 OCPU and 20 GB storage.  What can you do with this? Tons - and I'll be blogging more about this in the near future, so stay tuned. You also get compute power with 2 virtual machines with 1/8 OCPU and 1 GB memory each. These aren't blazing fast, but trust me - they're good enough for certain applications and I'll be blogging about some ideas for these as well. You also get storage - 2 Block Volumes, 100 GB total, 10 GB Object Storage and 10 GB Archive Storage, a Load Balancer (1 instance), and 10 Mbps bandwidth.  Also included is monitoring, notifications, and email delivery. There's honestly no reason that you shouldn't take advantage of this, so [learn more and sign up today](https://www.oracle.com/cloud/free/#always-free). Yes, you need to put in a credit card for verification. No, you won't be charged a thing without consent. I've signed up for other cloud providers free tiers lately, and I don't recall any of them letting you sign up without a credit card on file. 

## Hands On

Since I'm a developer advocate for Oracle Cloud (and not in marketing or sales), there was no way I'd be blogging about this free tier unless I first got my hands dirty with it myself and had faith that it was worthwhile and was something other developers would find useful. So I signed up for a personal account and decided to move my personal blog over from Amazon Web Services to the Oracle Cloud free tier. I've been using AWS for several years prior to joining Oracle to host my [personal blog](https://recursive.codes) and just hadn't yet gotten around to migrating it to Oracle Cloud so this was the perfect project to try out with the free tier. My blog is a pretty straightforward application: for the database I was using MySQL on Amazon RDS and the blogware is a custom Grails application deployed as a WAR file on Apache Tomcat with S3 used as image hosting and Amazon SES for email delivery. So the migration plan looked like this:

- Migrate DB from MySQL RDS to Autonomous DB
- Migrate images from S3 to OCI Object Storage
- Swap SES for OCI email delivery
- Deploy application on OCI VM

The first step was obviously signing up for my free account and launching my new DB instance and VM. I've [blogged about the sign up process and launching your first free Autonomous DB instance before, so check that out](/posts/launching-your-first-free-autonomous-db-instance) if you need help.

## Migrating The DB

The DB migration was [easy and painless using SQL Developer](https://www.oracle.com/database/technologies/appdev/sql-developer.html) which includes a wizard that is used to guide you through the migration. There's a catch though - you need to use a user with some very liberal permissions to perform the migration, so [please read the full documentation](https://docs.oracle.com/en/database/oracle/sql-developer/19.2/rptug/migrating-third-party-databases.html#GUID-299A057B-2B51-4646-9285-043A848D2A0B) before you attempt your migration. Let's be honest though - you're not going to read that whole document, are you?  No, you're not, but I know that you'll at least [read this section that tells you the permissions required for the migration user](https://docs.oracle.com/en/database/oracle/sql-developer/19.2/rptug/migrating-third-party-databases.html#GUID-003DDC4C-9A35-40A5-8396-F726F22DAE0F). 

Once my data was migrated, I had to make some slight changes to the Grails application to account for using Oracle DB instead of MySQL. Things like changing the settings for the Hibernate dialect and using sequences instead of auto-incrementing keys. Nothing out of the ordinary though - anytime you change the backend for an application you have to expect that there will be some minor tweaks involved.

## Migrating Objects From S3

This was relatively easy because I only had about 100 images to move, so I simply downloaded them all manually from S3 and uploaded them into Oracle Cloud Object Storage by hand. More complex migrations are certainly possible, [check this whitepaper if you have such a need](https://docs.cloud.oracle.com/iaas/Content/Resources/Assets/whitepapers/transfer-data-to-object-storage.pdf). Once the objects were in place, I ran a SQL update query to replace the existing links in all of my blog posts with the new link location in OCI Object Storage. Finally, I needed to modify my code to point at Oracle Cloud instead of S3 so that any new uploads would end up in Object Storage instead of my old AWS  bucket. My Grails application utilizes the AWS SDK via a Grails plugin and I certainly could have swapped that out for the OCI SDK, but why bother with that when **OCI Object Storage provides a compatible S3 endpoint that can be used with the existing AWS SDK**. The only change that was required for the plugin was to change the endpoint and a few settings, and that was accomplished via 3 lines of code in my Controller (lines 4-6 below):
```groovy
BlogController(BlogService blogService, AmazonS3Service amazonS3Service) {
    this.blogService = blogService
    this.amazonS3Service = amazonS3Service
    this.amazonS3Service.client.clientOptions.pathStyleAccess = true
    this.amazonS3Service.client.clientOptions.chunkedEncodingDisabled = true
    this.amazonS3Service.client.endpoint = "${grailsApplication.config.codes.recursive.aws.s3.namespace}.compat.objectstorage.${grailsApplication.config.codes.recursive.aws.s3.region}.oraclecloud.com"
}
```



Next, I swapped out my Grails Mail plugin settings from the AWS SES server to the OCI server. I found these settings via the console sidebar menu, under Email Delivery - Email Configuration:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_31_26.jpg)

The settings were shown here:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_31_35.jpg)

Clicking 'Manage SMTP Credentials' on the configuration page takes you to the user management section where you can generate the credentials for your application to use.

## Deploying The Application

So at this point, I've created and migrated the DB, migrated my objects and configured the application to work with the new environment (the DB, object store and email delivery services in Oracle Cloud). The next step is deploying the application itself, which means I'll need to create a compute instance. To get started, head back to the console dashboard and click 'Create a VM Instance':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_36_20.jpg)

Name your instance, choose the image OS:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_36_55.jpg)

Next, upload an SSH public key that you'll be able to use to connect to the instance and click 'Create':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_37_12.jpg)

Once the instance has been created you are able to view the instance details. Take note of the public IP address, you'll use this to SSH into the machine (using the username '`opc`' and the SSH key you specified previously. We'll need to add some ingress rules if we want to allow web traffic, so click on the subnet listed here:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_42_24.jpg)

On the subnet details page, in the left sidebar, click 'Security Lists' and then select the default security list to edit:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_42_57.jpg)

Add an ingress rule to allow traffic on ports 80 and 443:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_43_38.jpg)

The compute instance is now ready to go. You may need to also [open up local firewall ports on the VM itself if traffic is blocked](https://oracle-base.com/articles/vm/oracle-cloud-infrastructure-oci-amend-firewall-rules).

At this point, I installed Tomcat and uploaded my WAR file and deployed it. Some additional setup for SSL certs was required in my case, but it was a very easy migration overall.

## Comparing AWS to OCI

So what do I gain with this migration? Let's break it down:

## Cost

The easy answer here is that I no longer need to pay \$35 to Amazon each month for hosting my blog. The OCI "always free" tier costs - well, nothing\...ever. It doesn't expire after 12 months like AWS free tier.

**Cost**: Hands down, the winner is **OCI **for being 'always free'.

While cost is nothing to sneeze at, there's more to talk about here.

## Reliability

It's hard to find numbers for AWS which makes comparisons difficult. But, Autonomous DB is Self-Securing and Self-Repairing and actually patch themselves while running. SLAs should guarantee 99.995% reliability which means less than 2.5 minutes of downtime a month (including patching). Even routine maintenance, patching and updates on AWS can't compare to that.

**Reliability**: Data shows that Autonomous DB and Autonomous OS (Oracle Linux) lead to less downtime and a more reliable experience on Oracle Cloud. Winner: **OCI**. 

## User Experience

I'm going to show you some screenshots here, because they tell the best story. You can judge this for yourself, but I think it's pretty evident which console experience is more consistent, clean, well-organized and easy to use (and look at for that matter). All examples below will show OCI first, and AWS second.

Listing compute instances:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_13_12_11.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_13_12_32.jpg)

Editing security rules:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_12_43_38.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_13_15_40.jpg)

Listing object storage buckets. S3's interface is showing improvement, but is completely inconsistent with the look-and-feel of the rest of the service offerings on AWS:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_13_16_52.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_13_16_23.jpg)

Creating a db instance. Again - the RDS interface is clean, but inconsistent with other AWS services. Meanwhile, the OCI interface is clean, organized and consistent. Once you've familiarized yourself with the OCI console, you can be confident that you'll not be confused by any other services in the dashboard because they will look and act the same way as the rest of the services in Oracle Cloud.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_23_10_24_05.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/2019_09_26_13_20_01.jpg)

**User Experience**: AWS has a few really nice interfaces (depending on the service), and some really dated and old looking services like EC2. **OCI** is the winner here with the clean, well-organized and consistent experience that isn't too busy or crowded. It's modern, clean and easy to use which even I'll admit was not a strong point of many Oracle user interfaces in the past. 

## Summary

Oracle has a free tier. It's really free. It costs nothing to use. Forever. It's awesome and you should totally use it. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/26edc804-6842-4bd2-9a5d-348073ed9a4d/3boj4a.jpg)\
\
I'd love to hear your ideas for using the Oracle Cloud free tier for compute and Autonomous DB. Reach out to me and share your ideas as I'd love to feature some of your stories in future blog posts and videos!

Photo by [Nghia Le](https://unsplash.com/@lephunghia?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/thumbs-up?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
