---
title: "Blast Off To The Cloud: Free Team Chat With Rocket.Chat In The Oracle Cloud"
slug: "team-chat-for-free-with-rocketchat-on-the-oracle-cloud"
author: "Todd Sharp"
date: 2019-11-04
summary: "Do you talk to people online? If so, this post is for you! We'll install Rocket.Chat on an always free VM. As an added bonus, we'll set it up to use Oracle IDCS for authentication and configure it to use your free object storage in the Oracle Cloud for uploads. "
tags: ["Cloud", "Open Source"]
keywords: "Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/banner_john_baker_uzokdforrdu_unsplash.jpg"
---

Just about every single company these days uses some sort of chat application for team-based communications. And it's not just our workplaces. Conferences, organizations, colleges, schools - you name it, and I'm willing to bet they are using something to keep in touch. There are a few major players in the world of communications apps, but most of them aren't free or open source. But that doesn't mean you're stuck paying licensing fees for your organization. There are a handful of **really nice** alternatives out there that are both free and open source if you're willing to install it yourself and maintain the installation (it's not hard - trust me). So that means for the price of a VM, some storage and bandwidth you can get a team chat solution online quickly and easily. And if you've read any of my other blog posts recently then you'll know what I'm about to tell you. That's right, with the [Oracle Cloud "always free" tier](https://oracle.com/cloud/free/) you can get up and running for absolutely nothing. **Zero dollars.** 

Today we're going to look at one of the major players in the free, open source, team-based communication and collaboration market: [Rocket.Chat](https://rocket.chat). We're going to do the following (but feel free to skip ahead if you know how to create a VM already):

- [Create An Always Free VM](#create)
- [Before You Install Rocket.Chat](#before)
- [Install Rocket.Chat](#install)
- [Configure Oracle IDCS As An Auth Provider](#idcs)
- [Use Oracle Object Storage For Upload Storage](#os)

## Create An Always Free VM 

If you're new to Oracle Cloud, you'll have to first [sign up for a completely free account](https://www.oracle.com/cloud/free/). You'll need to have a credit card on file, but you'll absolutely never be charged if you stick to the "always free" services. Once you've signed up for your free account, log in and head to the Oracle Cloud dashboard. It looks like this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/oci_dashboard.jpg)

Let's create a VM. Click on 'Create a VM instance':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_1.jpg)

Give your instance a name and optionally change the image source. The instructions below will be for the default OS which is Oracle Linux, so it's probably best to stick with the default.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_2.jpg)

If necessary, click 'Show Shape, Network, Storage Options' and make sure the Availability Domain and Instance Type are both 'Always Free Eligible'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_3.jpg)

Same thing goes for the instance shape - choose the 'Always Free Eligible' option.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_4.jpg)

Make sure to check 'Assign a public IP address' otherwise you will not be able to access the VM via the web!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_5.jpg)

Next, choose a public key file that has an associated private key that can be used to access this VM after it is created.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_6.jpg)

Click on 'Create' and you'll be directed to the instance details page and the VM will be in a 'Provisioning' state:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_7.jpg)

After a short wait the instance will become 'Available'. Copy the public IP address that has been assigned to the VM. We'll need this as we move on in this tutorial.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_vm_step_8.jpg)

Your VM is now ready to go. You can now SSH in to the machine using the private key associated with the public key you uploaded when you created the VM.

## Before You Install Rocket.Chat 

We'll need to take care of a few items before we can start the Rocket.Chat install. If you skip this step your install will certainly fail.

### Domain Name Record Set

The first thing we'll need to do is associate our VM's public IP address with a domain name. Rocket.Chat will give us free SSL out of the box by creating a reverse proxy with [Caddy](http://caddyserver.com) which makes use of [Let's Encrypt](https://letsencrypt.org/) to automatically provide you SSL protection for your communications. In my case, I'm going to use the URL `chat.toddrsharp.com`, so I'll add an A record with my DNS host to point at my VM's IP address:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_14_33_52.jpg)

Follow the directions of your particular hosting provider to point a domain (or subdomain) at your VMs IP address and you're ready to SSH in to the VM and continue the process.

### Configure Firewall And Security List

We'll need to open some ports in our firewall and security list to expose the Rocket.Chat application to the web, so let's start by add some ingress rules to our VM security list in the Oracle Cloud dashboard. From the VM details page, click on the subnet:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/edit_security_list_step_1.jpg)

On the subnet details page, click on 'Security Lists'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/edit_security_list_step_2.jpg)

Click on the default security list to edit the rules.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/edit_security_list_step_3.jpg)

Click 'Add Ingress Rule' and enter a rule to open ports `80,443` to the 'Source CIDR' `0.0.0.0/0` (all IP addresses):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/edit_security_list_step_4b.jpg)Ø

## Install Rocket.Chat 

At this point we've got a VM up and running with a security list that allows ports 80 and 443. Let's SSH in to the VM and handle a few quick tasks before we start the install process. The first task will be to make sure everything is up to date with a `sudo yum update -y`. Next, make sure the VM firewall has an opening for the same ports that we created ingress rules for:
```bash
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
sudo firewall-cmd —reload
```



### Prepare For Install

We'll be using [Snappy](https://en.wikipedia.org/wiki/Snappy_(package_manager)) to install Rocket.Chat, so let's get that installed first. Enable EPEL with the following:
```bash
cd /tmp
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo rpm -Uvh /tmp/epel-release-latest-7.noarch.rpm
```



Now we'll install snap with the following instructions ([via](https://snapcraft.io/docs/installing-snap-on-centos)):

{{< callout >}}
With the EPEL repository added to your installation, simply install the snapd package:

`sudo yum install snapd`

Once installed, the `systemd` unit that manages the main snap communication socket needs to be enabled:

`sudo systemctl enable --now snapd.socket`

To enable classic snap support, enter the following to create a symbolic link between `/var/lib/snapd/snap` and `/snap`:

`sudo ln -s /var/lib/snapd/snap /snap`

Either log out and back in again or restart your system to ensure snap's paths are updated correctly.
{{< /callout >}}
### Install Rocket.Chat Server

The install process is really easy. If you need to [refer to the official install instructions you can refer to them here](https://rocket.chat/docs/installation/manual-installation/ubuntu/snaps/), but to start the install you just need to run:

`sudo snap install rocketchat-server`

And just wait a few minutes for the install to complete.

### Configure Caddy For HTTPS

Because everyone loves TLS, we'll take the next step and configure our Rocket.Chat install to use HTTPS for communications by using the Caddy integration. Again, the [official documentation can be referred to if you get stuck](https://rocket.chat/docs/installation/manual-installation/ubuntu/snaps/autossl/), but here is what it takes (assuming you've opened the necessary firewall ports, created ingress rules and have a proper domain pointed at your VM IP):
```bash
sudo snap set rocketchat-server caddy-url=https://<your-domain-name>
sudo snap set rocketchat-server caddy=enable
sudo snap set rocketchat-server https=enable
```



The official docs would have your run a different command at this point, but I found that it failed on Oracle Linux, so if you did not receive any errors run the following to complete the configuration:
```bash
sudo snap run rocketchat-server.initcaddy
```



If the init ran without error, restart the services:
```bash
sudo systemctl restart snap.rocketchat-server.rocketchat-server.service
sudo systemctl restart snap.rocketchat-server.rocketchat-caddy.service
```



At this point your install should be ready to go at the domain you specified. Visit it in the browser and continue the setup.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_10_53_24.jpg)

In step 4, select 'Keep standalone':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_step_4.jpg)

## Configure Oracle IDCS As An Auth Provider 

This is certainly optional - you can use the built in user registration for Rocket.Chat if you would like to, but if your team or organization uses Oracle IDCS you can setup Rocket.Chat to use SAML. Follow the steps below (which are almost identical to the [official docs](https://rocket.chat/docs/administrator-guides/authentication/saml/oracle-cloud/)) to configure SAML and IDCS.

### Enable SAML In Rocket.Chat

You'll have to enable SAML in Rocket.Chat to get started.

**Note:** In this step, we'll enter a few values but leave some other values as their default. We'll come back to those other values later on.

Log in to Rocket.Chat as an admin and go to the Administration section:

### ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_idcs_step_0_1.jpg)

Search for SAML in the sidebar:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_idcs_step_0_2.jpg)

In the SAML settings, enable SAML. Next, enter a **Custom Provider** which is a simple name for your service, but it will be used in URL paths so avoid spaces.  Finally, enter a **Custom Issuer URL** which follows the format `https://[your domain]/_saml/metadata/[custom provider]`. Save these changes. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_11_52_59.jpg)

Next, open the exact URL that you used for the **Custom Issuer** in a new tab. We'll need some of the values from this XML file in the next step. 

### Create Application In IDCS

Let's head over to IDCS to add our application. If you're not sure how to get there, in the Oracle Cloud console, click on your user icon in the top right and select 'Service User Console':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_idcs_step_1.jpg)

Next, search the list of services for 'id' and once you find the Oracle Identity Cloud Service select 'Admin Console'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_idcs_step_2.jpg)

From the IDCS console, click on the 'Add Application' icon:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_idcs_step_3.jpg)

Choose 'SAML Application'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/rocketchat_idcs_step_4.jpg)

In your new application, give it a name and use the **Custom Issuer **as the Application URL/Relay State:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_11_55_33.jpg)

Click 'Next' to get to the SSO Configuration state. We're going to now look at the XML available at the **Custom Issuer** URL to grab the values for this section:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_15_21_15.jpg)

The entity ID is again the link to the **Custom Issuer** from earlier, and the **Assertion Consumer URL**, **Single Logout URL** and **Logout Response URL** can all be obtained from viewing the XML from the **Custom Issuer** (as shown in the image above).  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_11_59_45.jpg)

Before you click 'Finish', download the Identity Provider Metadata by clicking the button:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_15_51_49.jpg)

We'll use this XML file in the next step.

### Update Rocket.Chat SAML Settings 

Open the SAML settings back up. We're ready to populate the **Custom Entry Point** and **IDP SLO Redirect URL**:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_11_52_59.jpg)

Let's look at the identity provider metadata XML file that we just downloaded to grab the last two URL values and update the settings. Find the node labeled `md:SingleLogoutService` (highlighted yellow below) and grab the "Location" attribute and use it for the **IDP SLO Redirect URL**. Next, grab the "Location" attribute from the `md:SingleSignOnService` (highlighted green) and use that for the **Custom Entry Point**.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_15_56_37.jpg)

**Note:** There may be multiple nodes that match these, so make sure your grab URLs that contain `/idp/sso` and `/idp/slo` and not `/sp/sso` and `/sp/slo` in them.

Scroll down a bit and customize the SAML button:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_16_06_11.jpg)

You're now ready to add users to your IDCS application.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_12_06_15.jpg)

And assign them to the application.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_12_07_23.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_12_08_02.jpg)

And use them to log in to Rocket.Chat:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_12_15_45.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_12_16_06.jpg)

Upon first login, you'll be asked to register a username for Rocket.Chat.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_12_16_29.jpg)

## Use Oracle Object Storage For Upload Storage 

The always free includes 10GB of Object Storage. Rocket.Chat can utilize the OCI S3 compatible API to store uploads in your Oracle Cloud Object Storage buckets. Let's create a user for Object Storage, create a S3 compatible token.

### Create Storage User & Credentials

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/console_sidebar_create_user.jpg)

Create a user:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_user.jpg)

Click 'Customer Secret Keys' and then 'Generate Secret Key'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/os_generate_token.jpg)

Enter a description for the key.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/os_generating_key_dialog.jpg)

Copy the generated secret key (it won't be shown again):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/os_generated_key.jpg)

Then copy the corresponding access key:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/os_access_key.jpg)

### Create Object Storage Bucket

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_object_storage_bucket.jpg)

Click 'Create Bucket'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_bucket.jpg)

Enter a bucket name.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/create_bucket_details.jpg)

When your bucket is created, grab the 'namespace' from the bucket details.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/bucket_namespace.jpg)

Your upload endpoint will use the following format:

`https://[namespace].compat.objectstorage.[region].oraclecloud.com`

Now head to the Rocket.Chat admin and search for the '**File Upload**' settings. Choose 'Amazon S3' as the **Storage Type** and expand the Amazon S3 section below:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_13_41_30.jpg)

Enter your **Access Key**, **Secret Key**, **Region**, **Bucket URL** (in the format shown above) and select True for **Force Path Style**:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c352d70c-c118-404c-9a61-e8f939ab768d/2019_11_01_13_42_48.jpg)

Save your settings and you're all set! All user file uploads will be stored and served from your Oracle Cloud Object Storage bucket.

## Summary

In this post we created an always free VM, installed Rocket.Chat, configured it to use IDCS for authentication and Oracle Cloud Object Storage for uploads. If you'd like to see a demo of Rocket.Chat in action, register for an account and join the following channel:\
\
<https://chat.toddrsharp.com/channel/oci-chat>\
\
Chat with you soon!

Photo by [John Baker](https://unsplash.com/@jlondonbaker?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/rocket?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
