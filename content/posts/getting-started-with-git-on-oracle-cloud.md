---
title: "Getting Started With Git On Oracle Cloud"
slug: "getting-started-with-git-on-oracle-cloud"
author: "Todd Sharp"
date: 2019-03-25
summary: "Get started with Git on Oracle Cloud in less than 15 minutes. "
tags: ["Cloud", "DevOps", "Developers"]
keywords: "git, Cloud, OCI"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/banner_2019_03_25_11_44_12.png"
---

The new and improved Oracle Marketplace is now available from within the Oracle Cloud Infrastructure console.  The marketplace contains several applications that developers commonly use in their projects; things like source control, bug tracking and CI/CD applications - with more being added all the time.  The best part about the marketplace is that it gives you the ability to launch instances running these tools with one click.  Let's take a look at how to launch one of these instances using something that nearly every software project uses - source control.  More specifically, the current most popular source control system: Git.

To get started with git, head to your Oracle Cloud console and select Marketplace from the left sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_09_31.png)

From the Marketplace, select 'GitLab CE Certified by Bitnami':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_10_58.png)

On the following page, click 'Launch Instance':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_13_42.png)

Choose the image and compartment, review and accept the terms, then click 'Launch Instance':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_14_53.png)

The next page should look familiar to you if you have previously launched an instance on Oracle Cloud.  Enter your instance name, choose your options related to the instance shape and make necessary networking selections.  Be sure to upload an SSH key, we'll need it later on.  When you're satisfied, click 'Create':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_16_38.png)

You'll be taken next to the instance details page while the instance is provisioned.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_19_28.png)

While the instance provisions, double check that the subnet you have chosen has the proper security and route table rules to allow the instance to be web accessible.  From the sidebar, select 'Networking' then 'Virtual Cloud Networks':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_23_19.png)

From the Virtual Cloud Networks landing page, select the VCN you chose when creating the network, then from the following page locate the subnet that you chose.  Here you'll be able to navigate directly to the proper rules that you will need to verify or create:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_25_32.png)

First verify (or create) a route table rule that targets your internet gateway for all incoming traffic:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_27_04.png)

Then make sure the security list allows ports 80 and 443 for all incoming traffic (please ensure that this subnet is not associated with any instances that you do not want to expose to the web):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_28_32.png)

By now your GitLab instance should be fully provisioned.  Head to the instance details page (Compute -\> Instances in the left sidebar) and view the details for your GitLab instance.  Take note of the public IP address:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_30_27.png)

Click on 'Console Connections' in the left menu, then 'Create Console Connection' and populate the dialog with the SSH key you used when creating the instance and click 'Create Console Connection':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_33_38.png)

Now you should be able to hit your running GitLab administrator via your browser at http://\<public ip\>:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_37_45.png)

The default username is 'root'.  To find your initial password, SSH into the instance using the following command:

`ssh bitnami@<public ip> -i /path/to/ssh_key`

The initial password is stored in a file called 'bitnami_credentials'. To view it:

`cat ./bitnami_credentials`

Which will look similar to:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_42_25.png)

Log in and get started working with GitLab on Oracle Cloud!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/523bab0c-c68d-4aaf-8a98-323a34678ce6/2019_03_25_11_44_12.png)
