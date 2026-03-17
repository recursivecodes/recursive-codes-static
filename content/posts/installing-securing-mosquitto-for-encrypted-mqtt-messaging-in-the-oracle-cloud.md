---
title: "Installing & Securing Mosquitto for Encrypted MQTT Messaging in the Oracle Cloud"
slug: "installing-securing-mosquitto-for-encrypted-mqtt-messaging-in-the-oracle-cloud"
author: "Todd Sharp"
date: 2021-11-12
summary: "Let's look at another option for lightweight, low-bandwidth messaging in the cloud. This time, we'll see how to install Mosquitto for simple MQTT messages."
tags: ["Messaging"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/communication-g7fa8137b8_1280.jpeg"
---

Messaging is critical in the cloud. Maybe you're dealing with industrial IoT applications that read sensors and report conditions from a factory line to a central reporting server. Messaging isn't just for IoT though - even traditional applications can take advantage of pub/sub and durable queues to pass notifications between distributed bits of the application. Maybe you have an application that encodes user-uploaded video files to a standard format and needs to report the progress of the encoding back to the user in real-time.  Almost every application - even traditionally "monolithic" - usually have *some* piece of functionality that happens "offline" that requires more processing time than we would want our users to wait. In other words, just about every application could utilize messaging to improve the user experience (as well as the developer experience)!

Since messaging is so important (and cool), I've got a few more interesting blog posts coming up soon that I think many of you will find helpful. We're going to look at how to create and utilize messaging "bridges" which give us a way to broker messages between different queues and topics. One of the messaging protocols that we'll be looking at in those upcoming posts is MQTT. Last January, I blogged a tutorial on how to [get up and running with Rabbit MQ on an "always free" instance](https://blogs.oracle.com/developers/post/getting-started-with-rabbitmq-in-the-oracle-cloud) in the Oracle Cloud, and that tutorial is still valid and applicable. In fact, I still have a Rabbit MQ instance running on a free tier instance, and I use it quite a bit in my projects and demos. But this time, I wanted to show an alternative approach that launches a [Mosquitto](https://mosquitto.org) server in the cloud. Mosquitto is an open-source server that is really easy to use and includes some helpful tools on the client-side that we can use to quickly publish and subscribe to a topic. We'll also launch Mosquitto on an "always free" eligible instance (this time an Arm-based instance), but in this tutorial, we'll look at providing an encrypted solution by configuring the server to obtain and utilize proper TLS certificates. Sounds like a lot of work, but it's not. If you follow the steps below, you should be sending and receiving messages in less than 15 minutes. Here are the steps we'll take in this post. Feel free to skip around if you need to. 

- [Create a VM](#Create%20a%20VM)
  - [Create VM with Console](#Create%20VM%20with%20Console)
  - [Create VM with OCI CLI](#Create%20VM%20with%20OCI%20CLI)
  - [Create Security List Ingress Rules](#Create%20Security%20List%20Ingress%20Rules)
- [Point Domain Name at VM](#Point%20Domain%20Name%20at%20VM)
- [Install Mosquitto](#Install%20Mosquitto)
- [Secure Mosquitto Install](#Secure%20Mosquitto%20Install)
  - [Install acme.sh ](#Install%20acme.sh%C2%A0)
  - [Create Pre/Post Cert Hooks](#Create%20Pre/Post%20Cert%20Hooks)
  - [Issue the TLS Certificate](#Issue%20the%20TLS%20Certificate)
- [Create Credentials and Listen for Encrypted Traffic](#Create%20Credentials%20and%20Listen%20for%20Encrypted%20Traffic)
- [Further Reading](#Summary)
- [Summary](#Summary)

## Create a VM 

The first step here is to create a virtual machine that we can use to host our Mosquitto MQTT install. We can do this with either the web console or the CLI.

### Create VM with Console 

In the console search box, search for 'instances' and then select 'Instances' under 'Services'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7ecf5dad-cc35-4254-bc51-e8ae6dd12b89/upload_d3ba021318f1882a3ca729e6853eb47a.png)

On the instance list page, click 'Create Instance'

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d502611c-81e9-4905-a98d-cfdcfc748d6e/upload_6dff8b395bd20fdc33eaac85c1e0ec46.png)

Name the instance, and choose the compartment in which you'd like to create it.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f7ff3d03-b10a-411d-96d3-55b1c9879f58/upload_a086801727993a329276b50d13e1aedb.png)

Choose the availability domain, and if necessary the capacity type and fault domain. Refer to the inline help documentation links if you need to learn more about any of the choices or options.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/bab66a54-8782-4d22-8244-d9558f508b8f/upload_2a2bf3830b27831c39fda2965f31539e.png)

Next, select the image. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/423e1f96-adf1-4525-84e2-2e6fb2962d92/upload_c3661fdce618ca6ded3ea2299e55aa95.png)

To change the shape, click 'Change Shape'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/62d0a0b4-d5f8-4e5f-a80c-d359796f3743/upload_65c7d9700a25bedf6c808944b9545718.png)

In the 'change shape' dialog, select VM.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3de21d97-95d4-42e8-a7b1-fb7b5b8ff170/upload_5d9a7de62aad65c077f8b8f7fa3489c4.png)

Next, choose the shape 'series'. For example, choose 'Ampere' if you would like to select an Arm-based processor for the VM.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a001340f-3d02-4735-97e9-09d9010777a0/upload_3c04253886b8e3962715ceadd7764d2b.png)

Once you choose a 'series', the available shapes are shown. Choose one of the available shapes (#1), and if necessary the amount of OCPUs and memory to allocate to the VM (#2-5), and finally click 'Select shape' (#6).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1385161c-d3e4-469e-9f1f-8de54ffb3128/upload_9abc0601e2d8e8afcf46d5dc8d5e3540.png)

**Always Free!** The Oracle Cloud "always free" tier includes up to 4 Arm-based Ampere cores and 24 GB of memory (which can be used as one VM, or up to 4 separate VMs). Seriously. [Totally free](https://www.oracle.com/cloud/free/#always-free)!  

Configure networking as appropriate. Select an existing public VCN, or create a new one. Make sure to assign a public IPv4 address

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d5a95db3-87fd-45cf-87c2-417e09d91f5d/upload_f27ddf12b0830464e9b7487a4ed80da9.png)

Generate, upload or paste the public key portion of an SSH keypair that you will be able to use to SSH into the machine after it is created.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1e9ba616-cdbf-42cb-b533-9f449e970b11/upload_2cf2345d0e05420018177e6a5da2efa6.png)

Modify boot volume options as necessary, or accept the defaults.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f223744f-b65b-4770-9ffc-bfa5c25aced2/upload_37d8774dbe24e2a7c7a1d4385a2d21c1.png)

Optionally, click on 'Show advanced options'. If desired, you can set management options (such as cloud-init scripts, tagging):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a0f514dc-a3c5-44be-b188-45d09deb9e84/upload_b70c1a79410b12c490dff1d4711ff78d.png)

You can also optionally set 'availability configuration'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c56d74bf-889d-4a26-b45a-f213651785aa/upload_83ecccd386039aaf6e52b92526b0da29.png)

And finally, you can optionally enable/disable Oracle Cloud Agent services.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5211eabc-833c-4fda-88f0-d97da96f8e1d/upload_08b59a6e9eb0fda779ec2662f58b0a78.png)

Now click on 'Create' to immediately create the virtual machine!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5ddda7ee-94f5-4c21-9a0b-7deaecd81b80/upload_798edb5defbe26fb32ba7c776b3eee3c.png)

### Create VM with OCI CLI 

If you've already installed and configured the OCI CLI, you can launch an instance quickly via the `oci compute instance launch` command ([docs](https://docs.oracle.com/en-us/iaas/tools/oci-cli/3.1.0/oci_cli_docs/cmdref/compute/instance/launch.html)). Of course, this requires that you know some details ahead of time, like the `subnet-id`, `image-id`, `shape`, `compartment-id`, and `availability-domain`. I like to save keep values that I use often like these set into environment variables in my `zsh` profile so that I can access them easily when I need them.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f65dea57-ab79-47a3-a290-0e6025a32a9a/upload_5f19c63773f4ebc8fc100739e70124ff.png)

If you've got the values you need, plug them in and run the command like so. In a few minutes, your instance will be up and running and ready to connect.
```bash
oci compute instance launch \
        --compartment-id $OCI_DEMO_COMPARTMENT \
        --availability-domain $OCI_PHX_AD1 \
        --shape VM.Standard.A1.Flex \
        --subnet-id $OCI_DEMO_SUBNET_ID \
        --image-id $OCI_OL79_IMAGE_ID \
        --shape-config '{"memoryInGBs": 6, "ocpus": 1}' \
        --metadata '{"ssh_authorized_keys": "'$OCI_DEMO_SSH_PUBLIC_KEY'"}'
```



### Create Security List Ingress Rules 

We need to allow a few ports through the cloud VCN security list. From your instance details, click on the subnet name:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b9d415f8-78c1-4bd8-89d0-0b9477f43b13/upload_f6138a12dcdf95e7b136d219f90c9b32.png)

Choose the default security list.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/105705cd-804e-4374-a454-f5ff127c2d40/upload_ec333096f1da0a96199e55891c585b07.png)

In the security list, click 'Add Ingress Rules'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4b5a3486-99ff-439d-b393-0f77e5717bf7/upload_775fb1c31e34daa6aeb07e6adfc895cd.png)

Add an ingress rule for ports 80, 1883, 8883. Port 80 is used in a bit to generate a TLS cert for secure MQTT messaging, 1883 is for insecure MQTT, and 8883 will be used for secure messaging.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/df82e1b5-e89d-483d-b3fe-2cda837e82e4/upload_99ee9d4e1e86a22fb294e133dd82f858.png)

## Point Domain Name at VM 

Once the VM is up and running, grab the assigned public IP address.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d264ade1-4520-465b-b5a6-b2b7c667aabb/upload_b8bc0662fbd92401ff233744f5e85d9f.png)

You'll need to point a valid domain (or subdomain) at this IP address using your domain name host. This is necessary in order to obtain a valid TLS certificate. Follow the domain host's documentation to assign a domain name at the VM's public IP address and then continue with this tutorial.

## Install Mosquitto 

Now we can SSH into the VM, either using the IP address or via the FQDN that we assigned in the previous step.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d1f52db2-c4e9-4bb8-8ba9-4350200c1843/upload_6560340578eeb684aea5796368edde29.png)

And we're ready to get started installing Mosquitto. In my case, the VM that I created was configured to use [Oracle OSMS](https://docs.oracle.com/en-us/iaas/os-management/osms/osms-package-management.htm) to manage packages. I'd prefer to manage them myself, so I disabled and unregistered OSMS like so:
```bash
sudo systemctl stop oracle-cloud-agent
sudo systemctl disable oracle-cloud-agent
sudo osms unregister
```



We're going to use Snap to install Mosquitto. The `snapd` package is found in the EPEL repo for Oracle Linux, so we need to enable that repo (since it's disabled by default). You can manually edit the file located at `/etc/yum.repos.d/oracle-epel-ol7.repo`, but you can also update it quickly with `sed`.
```bash
sudo sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/oracle-epel-ol7.repo
```



Now let's install Snap. The last line here enables "classic" snaps.
```bash
sudo yum update -y
sudo yum install snapd -y
sudo systemctl enable snapd
sudo systemctl start snapd
sudo ln -s /var/lib/snapd/snap /snap
```



Next, add `/snap/bin` to your path (via `.bash_profile`) to make sure you can execute binaries installed via Snap later on if their own installers don't modify the path themselves.
```text
PATH=$PATH:$HOME/.local/bin:$HOME/bin:/snap/bin
```



Now we can install Mosquitto via Snap.
```bash
sudo snap install mosquitto
```



At this point, we're almost ready to send and receive messages on our MQTT server. But before we do that, we have to concern ourselves with authentication. We have two choices regarding auth: create and use client keys, or username and password auth. There's not really any benefit to either one over the other option, but it could be a bit of a pain to issue and maintain keys (especially if we're going to connect from an IoT board/device). So to make life a bit easier, let's choose username/password auth. Create a text file with creds called `creds.txt`. In it, add an entry per line for each user that you want to create. Separate the username and password with a colon like so: 
```txt
username1:password1
username2:password2
```



Now we can encrypt the credentials with the `mosquitto_passwd` utility.
```bash
mosquitto_passwd -U creds.txt
```



You can read the file to confirm that the password was properly encrypted. Now, move it to the Mosquitto config directory with:
```bash
sudo mv creds.txt /var/snap/mosquitto/common/creds.txt
```



Next, create a config file with:
```bash
sudo nano /var/snap/mosquitto/common/mosquitto.conf
```



Add the following config:
```conf
listener 1883
allow_anonymous false
password_file /var/snap/mosquitto/common/creds.txt

listener 8883
cafile /var/snap/mosquitto/common/certs/ca.pem
certfile /var/snap/mosquitto/common/certs/fullchain.pem
keyfile /var/snap/mosquitto/common/certs/mosquitto.toddrsharp.com.pem
```



Before we can test publishing and subscribing, we'll need to open firewall port:
```bash
sudo firewall-cmd --permanent --zone=public --add-port=1883/tcp
sudo firewall-cmd --reload
```



And restart Mosquitto.
```bash
sudo snap restart mosquitto
```



You'll want to have the Mosquitto client tools installed on your local machine (or some other way to quickly pub/sub to a topic handy). Check out the downloads page and install the proper version for your OS. The client tools are included in the local install, so you'll be able to use `mosquitto_pub` and `mosquitto_sub` from the command line to easily test your cloud install. At this point, our MQTT server is up, running, and available to publish and subscribe to. Let's subscribe to a topic and publish a few messages to it from our local machine.
```bash
mosquitto_sub -t demo/one -h mosquitto-snap.toddrsharp.com -u username -P password -p 1883
mosquitto_pub -t demo/one -h mosquitto-snap.toddrsharp.com -u username -P password -p 1883 -m '{"message": 1}'
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b8866f80-561c-4ead-869e-82154e1f2aa3/upload_637c7ef7786711dcd75a1d5994453188.gif)

## Secure the Mosquitto Install 

A publicly accessible messaging queue that allows unencrypted publishing and subscribing in the cloud is probably a pretty bad idea. Let's enable encryption via TLS and ensure secure, authenticated connections to this queue. To enable encrypted communication, we're going to obtain a valid TLS certificate for the server. Before we start that process, let's open a few more firewall ports. We'll need `80` (used to spin up a temporary stand-alone webserver to obtain the cert) and `8883` (used for secure MQTT) open.
```bash
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --permanent --zone=public --add-port=8883/tcp
sudo firewall-cmd --reload
```



### Install acme.sh  

I've blogged about various tools and scripts that can help you obtain a free TLS certificate in the past, but this time I decided to try a new tool for this job - [acme.sh](https://github.com/acmesh-official/acme.sh). You can read about acme.sh and follow the install instructions from the docs, or just follow along here. First, we'll install acme.sh which requires a package called `socat` to be installed first. Pass the acme.sh install script your email address that you want to use when registering for your certs.
```bash
sudo yum install socat -y
curl https://get.acme.sh | sh -s email=me@mail.com
```



### Create Pre/Post Cert Hooks 

Note that the acme.sh created a new directory in your home directory called `.acme.sh`. Move to that directory and create two files. The first file we call `pre.sh` and we'll use this file to perform any tasks that we need to perform before installing (and eventually renewing) our certs. For now, the only thing we need in `pre.sh` is to stop the `mosquitto` service. 

Now create a file called `post.sh`, which we will use to move the certs from the directory where they are stored by acme.sh into a subdirectory of our home directory, rename them to be `.pem` files (expected by `mosquitto`) and restart `mosquitto`. [Don't forget to change you.your.com to your proper domain name!]

Make the hook scripts executable:
```bash
sudo chmod +x ~/.acme.sh/pre.sh ~/.acme.sh/post.sh
```



### Issue the TLS Certificate 

Now we can request the TLS certificate. Since we're using port 80 for the standalone web server (the acme.sh default), we need to execute the script as a root user (using `sudo`) because Oracle Linux restricts the usage of ports less than 1024 to root users. Note that we're passing the pre and post-hook scripts which will be executed at the proper time in the issuance. These commands will also be saved and ran before and after the scheduled cert renewal job (that is automatically created after you issue the initial cert). Remember - change `you.your.com` to your proper domain name!
```bash
sudo ./acme.sh --issue -d you.your.com --standalone --server letsencrypt --force --pre-hook "sudo /home/opc/.acme.sh/pre.sh" --post-hook "sudo /home/opc/.acme.sh/post.sh"
```



The output of this command should look something similar to the following:
```bash
[Fri Oct  1 19:30:47 GMT 2021] Using CA: https://acme-v02.api.letsencrypt.org/directory
[Fri Oct  1 19:30:47 GMT 2021] Run pre hook:'sudo /home/opc/.acme.sh/pre.sh'
mosquitto stopped!!
[Fri Oct  1 19:30:48 GMT 2021] Standalone mode.
[Fri Oct  1 19:30:48 GMT 2021] Create account key ok.
[Fri Oct  1 19:30:48 GMT 2021] Registering account: https://acme-v02.api.letsencrypt.org/directory
[Fri Oct  1 19:30:50 GMT 2021] Registered
[Fri Oct  1 19:30:50 GMT 2021] ACCOUNT_THUMBPRINT='xxx'
[Fri Oct  1 19:30:50 GMT 2021] Creating domain key
[Fri Oct  1 19:30:50 GMT 2021] The domain key is here: /root/.acme.sh/you.your.com/you.your.com.key
[Fri Oct  1 19:30:50 GMT 2021] Single domain='you.your.com'
[Fri Oct  1 19:30:50 GMT 2021] Getting domain auth token for each domain
[Fri Oct  1 19:30:52 GMT 2021] Getting webroot for domain='you.your.com'
[Fri Oct  1 19:30:52 GMT 2021] Verifying: you.your.com
[Fri Oct  1 19:30:52 GMT 2021] Standalone mode server
[Fri Oct  1 19:30:54 GMT 2021] Pending, The CA is processing your order, please just wait. (1/30)
[Fri Oct  1 19:30:56 GMT 2021] Success
[Fri Oct  1 19:30:56 GMT 2021] Verify finished, start to sign.
[Fri Oct  1 19:30:56 GMT 2021] Lets finalize the order.
[Fri Oct  1 19:30:56 GMT 2021] Le_OrderFinalize='https://acme-v02.api.letsencrypt.org/acme/finalize/xxx/xxx'
[Fri Oct  1 19:30:57 GMT 2021] Downloading cert.
[Fri Oct  1 19:30:57 GMT 2021] Le_LinkCert='https://acme-v02.api.letsencrypt.org/acme/cert/xxx'
[Fri Oct  1 19:30:57 GMT 2021] Cert success.
-----BEGIN CERTIFICATE-----
MI...
[redacted]
...A==
-----END CERTIFICATE-----
[Fri Oct  1 19:30:57 GMT 2021] Your cert is in: /root/.acme.sh/you.your.com/you.your.com.cer
[Fri Oct  1 19:30:57 GMT 2021] Your cert key is in: /root/.acme.sh/you.your.com/you.your.com.key
[Fri Oct  1 19:30:58 GMT 2021] The intermediate CA cert is in: /root/.acme.sh/you.your.com/ca.cer
[Fri Oct  1 19:30:58 GMT 2021] And the full chain certs is there: /root/.acme.sh/you.your.com/fullchain.cer
[Fri Oct  1 19:30:58 GMT 2021] Run post hook:'sudo /home/opc/.acme.sh/post.sh'
certs moved, mosquitto started!!
```



A cron job was also created to make sure that the certificate is automatically renewed before it expires in 60 days. There's no need to modify the cron job to run the pre and post-hooks because they are saved and run along with the cron job. (per <https://github.com/acmesh-official/acme.sh/wiki/Using-pre-hook-post-hook-renew-hook-reloadcmd>). Verify that the cron job was created with `crontab -e`. It should look similar to this:
```text
8 0 * * * "sudo /home/opc/.acme.sh"/acme.sh --cron --home "/home/opc/.acme.sh" > /dev/null
```



We could try to sub/pub on port `8883`, but at this point, it would fail because we have not yet told Mosquitto to listen on that port.

## Create Credentials and Listen for Encrypted Traffic 

So we have a Mosquitto user with an encrypted password, and we've issued our TLS certs. We can now modify the `mosquitto.conf` file to encrypt connections via TLS with the certs that we generated and listen for secure connections on port `8883`. Edit the file, adding the following values (again, make sure to verify the path to the certs, updating the config file with your domain name as appropriate!).
```conf
listener 1883
allow_anonymous false
password_file /var/snap/mosquitto/common/creds.txt

listener 8883
cafile /var/snap/mosquitto/common/certs/ca.pem
certfile /var/snap/mosquitto/common/certs/fullchain.pem
keyfile /var/snap/mosquitto/common/certs/mosquitto.toddrsharp.com.pem
```



Restart Mosquitto with `sudo snap restart mosquitto`.

And we can now use authentication to send and receive encrypted messages on port `8883`!
```bash
mosquitto_sub -t demo/one -h you.your.com -u $MOSQUITTO_USER -P $MOSQUITTO_PASSWORD -p 8883
mosquitto_pub -t demo/one -h you.your.com -u $MOSQUITTO_USER -P $MOSQUITTO_PASSWORD -p 8883 -m '{"message": 1}'
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f36a4756-d442-4500-9857-a1a615b81c6f/upload_74b601f1607d510c941151432167f3ab.gif)

## Further Reading 

Here are a few links that I found helpful while researching and putting together this post.

- <http://www.steves-internet-guide.com/mqtt-username-password-example/>
- <https://mosquitto.org/documentation/using-the-snap>
- <https://mosquitto.org/blog/2015/12/using-lets-encrypt-certificates-with-mosquitto/>
- <https://github.com/acmesh-official/acme.sh/wiki/How-to-issue-a-cert>

## Summary 

In this post, we launched an "always free" Arm-based VM. Then, we installed Mosquitto for MQTT messaging. Next, we installed .acme.sh and used it to issue a TLS certificate that we used to encrypt and secure our Mosquitto installation. 

<div>

\

</div>
