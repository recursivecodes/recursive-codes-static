---
title: "Create & Host Your Own Dedicated Counter-Strike: Global Offensive (CS:GO) Server for Free (Forever!)"
slug: "create-host-your-own-dedicated-counter-strike:-global-offensive-cs:go-server-for-free-forever"
author: "Todd Sharp"
date: 2021-01-22
summary: "In this post, we'll look at how to create your very own dedicated server for Counter-Strike: Global Offensive and host it for free (forever) in the cloud."
tags: ["Cloud", "Developers"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/banner_muhannad_ajjan_sl2brr1cuvm_unsplash.jpg"
---

Video games have been around for about 50 years, becoming mainstream and more popular as the years and decades have passed since the 1970s. My first experience with video games was on an Atari 2600 back in the early 80's playing classics like *Space Invaders*, *Pac-Man*, and *Pitfall*.  From there, it was on to a Commodore 64 where I'd spend countless hours playing *Jumpman*, *Swiss Family Robinson,* and tons of text-based dungeon classics (so many that I can't even remember most of their names).  I still remember saving money from my very first job - a miserable paper route - to buy the original Nintendo Entertainment System (NES) back in the late '80s. I spent many long days and some late nights with Mario and Link back in my younger years.

Gaming has always been a passion of mine. I've owned a lot of consoles and played countless games in my lifetime, but things drastically changed for me back in the early 2000s. That was when the Sony PlayStation 2 released the "Network Adaptor" which allowed the PlayStation 2 to connect to the internet and gave me the ability to play online multiplayer games for the first time in my life. I'll never forget being able to play *SOCOM U.S. Navy SEALs* with my buddy Danny from the comfort of our own homes. Online multiplayer gaming has grown exponentially since the early days and has even spawned careers for some gamers who record, publish, and stream their adventures online for mass audiences who willingly consume the content. 

From the early days of LAN parties to the modern cloud era, gamers have often desired the ability to host their own servers for multiplayer games. There are many reasons why - from the ability to mod and customize the gameplay experience to the need for improved security or performance. Hosting a dedicated game server gives you the freedom and control that you don't have when using public servers. In this post, I'll show you how to deploy and host your very own game server in the cloud. We'll focus on Counter-Strike: Global Offensive (CS:GO) in this post, but we're going to use [Linux Game Server Managers (LinuxGSM)](https://linuxgsm.com/) so you can use this same process to turn up your own private server for any of [110 different game servers](https://linuxgsm.com/servers/) that are supported by LinuxGSM. The best part is that we'll be doing this all on an always free virtual machine (VM) in the Oracle Cloud, so you'll never have to pay a single dime for your own private, dedicated gaming server!

## Create Account

As I said above, we're going to use an always free (forever - no, really!) VM in the Oracle Cloud to run our CS:GO dedicated server. To get started, we'll need to sign up for a brand new account (if you don't have one yet). Go to [cloud.oracle.com](http://cloud.oracle.com/) and click 'Sign Up'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665612.png)

On the next page, choose your Country/Territory, enter your name and email and then click 'Verify Email'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665619.png)

You'll receive the following email - click on the link to verify your email to continue.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665629.png)

Next, enter (and confirm) your cloud account password, cloud account name and choose a home region. This region will be where your VMs physically reside, so for best ping and latency you should probably choose a region that is geographically close to where you live.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665632.png)

Enter your mailing address and click 'Continue'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665636.png)

Now you'll need to add & verify your mobile number. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665640.png)

Next, you'll need to add a payment method that will be used later on if you decide to opt-in to paid services.  

**Note:** You **will not be charged without upgrading** to a paid account when your 30-day trial ends.** **

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665645.png)

I know you're concerned about being billed - trust me, I am always skeptical of entering my credit card for free services too! But, I promise you that if you follow the instructions below and always make sure that you are selecting resources that are labeled "Always Free Eligible" you will never see a single penny charged to your account. Now we are finally ready to agree to terms and start trial!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665649.png)

**Heads Up!**  It may take a few minutes to configure everything in your Free Tier account. You'll receive an email letting you know when everything is ready for you to log in and move forward!

## Create Virtual Machine

Once your account is created, login to the Oracle Cloud dashboard. We are now ready to create our Virtual Machine (VM) that will be used for our dedicated server. On the dashboard landing page, click 'Create a VM instance'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665652.png)

On the next page, we will enter all of the information needed to create our new VM. First, enter a name for the VM. Next, choose a "compartment". This is basically just a "container" for your VM and other resources to keep them organized. I used a compartment called "demo-compartment" below (it's where I keep all my blog demos) but you can leave it as your "root" compartment. Next, we need to choose an "availability domain". Try choosing "AD 3" because this is usually where the "always free" VMs are available. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665657.png)

Next, click on the 'Change Image' button. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665659.png)

LinuxGSM works with Ubuntu 16.04 LTS, Debian 9, or CentOS 7. Let's choose the Ubuntu 16.04 LTS shape. We can choose the "Minimal" shape to keep the server light.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665665.png)

Next, click on 'Change Shape'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665667.png)

Make sure that 'Virtual Machine' (#1) is selected, choose 'Specialty and Legacy' (#2), and then choose the 'VM.Standard.E2.1.Micro' shape (#3) that is labeled as 'Always Free Eligible'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665673.png)

**Can't Find The Free Shape?** If the "always free eligible" shape is not listed, try the other ADs in your region.

Next, we need to configure networking, so choose 'Create new virtual cloud network' and make sure 'Create new public subnet' is selected. Leave the names, CIDR block, and compartments populated with the default info.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665677.png)

Make sure that 'Assign a public IPv4 address' is chosen (otherwise we won't be able to connect to the server from CS:GO)!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665681.png)

Next, under 'Add SSH keys', select 'Generate SSH key pair' and click on 'Save Private Key' and 'Save Public Key'. You'll want to save these in a directory on your machine as we will need them in just a bit to connect up to the VM securely!

**Note:** If you are comfortable with SSH keys and already have one that you would like to use, feel free to upload it or paste it here. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665686.png)

That is all the info we need to provide to create the VM, so scroll down and click on 'Create'!  You'll be redirected to the VM details page and the VM will be initially in a 'Provisioning' state. After a minute or two, it'll switch to 'Running', and at that point, we can move forward.

## Update Security List & Configure Network

Now we need to configure our Virtual Cloud Network (VCN) to allow traffic into our VM in the cloud. From the VM details page, find a link to the 'Public Subnet' that was created. Click on this link.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665690.png)

On the next page, under Security Lists, click on the link to the Default Security List for the VCN.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665692.png)

On the Security List details page, click on 'Add Ingress Rules'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665695.png)

Create two ingress rules, both from the Source CIDR `0.0.0.0/0` (the entire internet), both for port `27015`. One rule should use the protocol TCP, the other rule will use UDP.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665698.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665702.png)

Save the ingress rules, and now we're ready to connect to the VM to configure the local VM firewall and install the server.

### Connect to the VM

Now we'll need to connect to the running VM in order to configure the local VM firewall and proceed with the server installation. We'll need the public IP of the VM to connect, so copy it from the VM details page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665706.png)

We'll use the command line to connect to the VM using SSH. If you are on a Mac or Linux machine, open a new terminal window and connect with the user `ubuntu` and substitute your VM IP and the path to the private SSH key that you saved earlier to your machine.[]

**Using Windows?** Windows 10 (finally) includes a built-in SSH client as of the Windows 10's Fall Creators Update. If you're on a different version of Windows that doesn't include the built-in SSH client, you'll need to install a third-party client. Search for "Windows SSH Client" in your favorite search engine to download and install a third-party SSH client.

On my Mac, this looks like this:
```bash
$ ssh ubuntu@[my VM IP] -i ~/.ssh/id_oci_demo
```



Next, we'll need to open port `27015` in the VM firewall for both `TCP` and `UDP`. It's necessary to open these ports on the VM just as we did on our VCN above by adding Ingress Rules to our Security List. We can do this on the VM with the following commands:
```bash
$ sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 27015 -j ACCEPT
$ sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 27015 -j ACCEPT
$ sudo netfilter-persistent save
```



Now we can install the server!

## Install CS:GO Server

As I mentioned earlier, LinuxGSM is going to help us install and manage our CS:GO server. The following steps are based on the LinuxGSM documentation for CS:GO, so if you get stuck or things have changed since this blog post was originally published you can always [refer to their docs](https://linuxgsm.com/lgsm/csgoserver/).

### Install Dependencies

We need a few extra packages before we can move forward. Run the following on your VM to install them (remember, we're using Ubuntu 16.04).

[]

Create a Linux user to be used for the `csgoserver`. Make sure that you choose a strong password when prompted.
```bash
$ sudo adduser csgoserver
```



Now download `linuxgsm.sh` and make it executable.
```bash
$ wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh csgoserver
```



### Create Game Server Login Token (GSLT)

When we run the installer, we're going to need to enter a Game Server Login Token (GSLT), so [head over to Steam](https://steamcommunity.com/dev/managegameservers) and create one.

**Note:** The App ID you use to generate the GSLT needs to be 730 even if the server shows an App ID of 740 when you launch it (at least this is what worked for me, YMMV).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665711.png)

Click create, then keep the token shown on the next page handy for the next step below.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665715.png)

Keep this token handy - we'll need it in just a minute.

### Run LinuxGSM CS:GO Installer

Finally, it's time to install the server. Run the script like so:

[]

The installer will run for a bit, prompting you for a bit of info as it goes. The output should look similar to the following (I clipped some content out to keep it readable).
```bash
mkdir: created directory '/home/csgoserver/serverfiles'

Creating log directories
=================================
installing log dir: /home/csgoserver/log...OK
installing LinuxGSM log dir: /home/csgoserver/log/script...OK
creating LinuxGSM log: /home/csgoserver/log/script/csgoserver-script.log...OK
installing console log dir: /home/csgoserver/log/console...OK
creating console log: /home/csgoserver/log/console/csgoserver-console.log...OK
installing game log dir: /home/csgoserver/serverfiles/csgo/logs...OK
creating symlink to game log dir: /home/csgoserver/log/server -> /home/csgoserver/serverfiles/csgo/logs...OK

Checking Dependencies
=================================
curl
wget
ca-certificates
file
bsdmainutils
util-linux
python3
tar
bzip2
gzip
unzip
binutils
bc
jq
tmux
netcat
lib32gcc1
lib32stdc++6
steamcmd
Information! Required dependencies already installed.

Installing SteamCMD
=================================
Information! SteamCMD is already installed...OK

Installing Counter-Strike: Global Offensive Server
=================================
[ START ] Installing csgoserver:
[  0%] Downloading update (0 of 77558 KB)...
[  0%] Downloading update (5424 of 77558 KB)...
[  6%] Downloading update (7318 of 77558 KB)…

[redacted]

Success! App '740' fully installed.
Complete! Installing csgoserver:
```



The installer will ask if the install was successful (confirm there are no errors above) and then proceed with the server configuration.
```bash
Was the install successful? [Y/n] Y

Downloading Counter-Strike: Global Offensive Configs
=================================
default configs from https://github.com/GameServerManagers/Game-Server-Configs
copying server.cfg config file.
'/home/csgoserver/lgsm/config-default/config-game/server.cfg' -> '/home/csgoserver/serverfiles/csgo/cfg/csgoserver.cfg'
changing hostname.
changing rcon/admin password.

Config File Locations
=================================
Game Server Config File: /home/csgoserver/serverfiles/csgo/cfg/csgoserver.cfg
LinuxGSM Config: /home/csgoserver/lgsm/config-lgsm/csgoserver
Documentation: https://docs.linuxgsm.com/configuration/game-server-config


Game Server Login Token
=================================
GSLT is required to run a public Counter-Strike: Global Offensive server
Get more info and a token here:
https://docs.linuxgsm.com/steamcmd/gslt

Enter token below (Can be blank).
```



Enter your GSLT that we created above. Next, the installer should wrap up with:
```bash
LinuxGSM Stats
=================================
Assist LinuxGSM development by sending anonymous stats to developers.
More info: https://docs.linuxgsm.com/configuration/linuxgsm-stats
The following info will be sent:
* game server
* distro
* game server resource usage
* server hardware info
Allow anonymous usage statistics? [Y/n] n
```



The install should complete:
```bash
=================================
Install Complete!

To start server type:
./csgoserver start
```



Start the server!
```bash
csgoserver@csgo:~$ ./csgoserver start
[  OK  ] Starting csgoserver: Applying steamclient.so sdk64 fix: Counter-Strike: Global Offensive
[  OK  ] Starting csgoserver: Applying steamclient.so sdk32 fix: Counter-Strike: Global Offensive
[  OK  ] Starting csgoserver: Applying 730 steam_appid.txt fix: Counter-Strike: Global Offensive
[  OK  ] Starting csgoserver: Applying botprofile.db fix: Counter-Strike: Global Offensive
[  OK  ] Starting csgoserver: Applying valve.rc fix: Counter-Strike: Global Offensive
[  OK  ] Starting csgoserver: LinuxGSM
```



And that is it! Your free-forever CS: GO server is now ready to start hosting your games! From the Steam client (or within CS: GO itself) click on 'Favorites' and then 'Add Server'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/c2bcdccc-42de-44b0-a478-9a386e134f79/file_1611327665718.png)

In the add server dialog, enter the IP of your server and add port `27015`. 

You can [further configure and mod the server as desired](https://developer.valvesoftware.com/wiki/List_of_CS:GO_Cvars), but that is out of the scope of this blog post. Check the LinuxGSM docs for more [info about the server usage](https://linuxgsm.com/lgsm/csgoserver/) on the VM. If you'd like to make sure that your VM is always backed up, check out my older post on [Backing Up Your Always Free VMs In The Oracle Cloud](/posts/backing-up-your-always-free-vms-in-the-oracle-cloud).

## What's Next

Since you still have one more free VM in your account, you can always use the steps above to create another VM and find one of the other 110 supported servers on LinuxGSM and run one of them, or you could consider one of the following projects:

- [How To Setup And Run A Free Minecraft Server In The Cloud](/posts/how-to-setup-and-run-a-free-minecraft-server-in-the-cloud)
- [Launching Your Own Free Private VPN In The Oracle Cloud](/posts/launching-your-own-free-private-vpn-in-the-oracle-cloud)
- [Installing Node-RED In An Always Free VM On Oracle Cloud](/posts/installing-node-red-in-an-always-free-vm-on-oracle-cloud)
- [Stand Up A Free Blog In 15 Minutes With Ghost In The Oracle Cloud](/posts/stand-up-a-free-blog-in-15-minutes-with-ghost-in-the-oracle-cloud)
- [Blast Off To The Cloud: Free Team Chat With Rocket.Chat In The Oracle Cloud](/posts/team-chat-for-free-with-rocketchat-on-the-oracle-cloud)
- [Install & Run Discourse For Free In The Oracle Cloud](/posts/install-run-discourse-for-free-in-the-oracle-cloud)
- [Launching Your First Free Autonomous DB Instance](/posts/launching-your-first-free-autonomous-db-instance)
- [Backing Up Your Always Free VMs In The Oracle Cloud](/posts/backing-up-your-always-free-vms-in-the-oracle-cloud)

If you liked this tutorial, be sure to follow me on Twitter ([\@recursivecodes](https://twitter.com/recursivecodes)). Let me know what you'd like to see next!

Photo by [Muhannad Ajjan](https://unsplash.com/@isword?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

