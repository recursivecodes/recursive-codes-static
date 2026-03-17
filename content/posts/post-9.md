---
title: "Beginners Guide To Linux"
slug: ""
author: "Todd Sharp"
date: 2017-03-20
summary: "Curious about getting into Raspberry Pi or just Linux in general but you're not sure where to start?  This post is for you.  It's not intended to be a comprehensive guide, rather a gentle intro into the Linux world.  I'm not a Linux expert, but I know from experience that it can be an intimidating platform to get started in.  I want this post to show you what you need to know to get started with Linux."
tags: ["Linux", "Raspberry Pi"]
keywords: "Beginners Guide To Linux, Linux, Getting Started With Linux, Linux Intro, Raspberry Pi Intro, Raspbian, First Time Using Linux, Windows 10 Alternatives, Debian, Kali Linux, Ubuntu"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9/banner_54e0dd434a55ae14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

Curious about getting into Raspberry Pi or just Linux in general but you're not sure where to start?  This post is for you.  It's not intended to be a comprehensive guide, rather a gentle intro into the Linux world.  I'm not a Linux expert, but I know from experience that it can be an intimidating platform to get started in.  I want this post to show you what you need to know to get started with Linux.

My dad bought us our first PC in around 1990.  We'd had a Commodore 64 before that, but this was our first Windows based machine.  I loved it, but I'm pretty sure I made Dad nervous with how fearlessly I clicked and navigated around everything.  I was curious to learn about this thing and I wasn't afraid to tweak settings or click on something I probably shouldn't have.  A whole new world had been opened to me and I wanted to "drink from the firehose" and learn as much as I could.  I've been using Windows on a daily basis ever since.  Needless to say, I've been a Windows user a long time.  

\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/windoze-3.png)

Eventually I got into programming.  My experience with Windows continued to serve me well for a long time, but every now and again I'd have to deal with a bit of Linux.  And, I have to be brutally honest here, it terrified me.  I couldn't even fathom using a command line for copying a simple file, let alone installing an application server and deploying a web app!  It continued to terrify me for years, but each and every time I used it a tiny little bit of me got more comfortable with it.  A few years later and I started to realize: "hey, this ain't so bad, I actually kinda ***like this***"!\

Around that point I decided that I'd like to learn a bit more about Linux, and that was one of the motivating factors for deciding to get into programming and building projects with the Raspberry Pi.  About a month ago when I decided to build and launch this blog I took an even bigger step:  I installed Debian Jessie on my Dell Studio XPS.  Now I'm a full time Linux user on my personal projects and I'm really enjoying it.  Granted, it'll take years for me to reach the level of proficiency that I am at with Windows, but it's a skill that looks great on a resume and anything that keeps me learning new things about computing is a Great Thing™ in my book.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/powered-by-linux.png)

So I decided to put together a quick guide/cheat sheet for those of you who may be new to Linux (maybe you're just getting into Raspberry Pi yourself).  There are plenty of cheat sheets out there, and most may be more comprehensive and detailed, but I hope this guide will get you familiar with Linux at a basic, bare bones level.  Some of the definitions I use may not be textbook, but I intend to use easy to understand (and commonly used/accepted) definitions for some terms.  Feel free to offer corrections and I'll keep the post updated if I've made any glaring mistakes.

### Distributions

Different "versions" of the Linux operating system are called distributions (or "distros").  There are lots of them.  The Raspberry Pi uses a distribution called Raspbian which is based on one of earliest distros called Debian.  You've heard of the Android OS for mobile phones, right?  Android is a Linux distribution.  The wireless router in your house right now is running some flavor of Linux.  If you're a fan of Mr. Robot, you've probably heard of Kali Linux, a popular distro used for digital forensics and penetration testing.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/fsociety.jpg) 

### Desktop Environments

Unlike Windows and OS X, Linux offers many different "[desktop environments](https://en.wikipedia.org/wiki/Desktop_environment)" - basically the GUI that lets you interact with the OS using familiar windows and your good old keyboard and mouse (and potentially touch screen).  PIXEL is the desktop environment used on the Raspberry Pi.  There are tons of choices here (see [this list](https://en.wikipedia.org/wiki/Desktop_environment#Gallery) for starters) and it all boils down to personal preference.  I'm using KDE on my Dell and I like it a lot, but if I ever feel like switching to something like GNOME, I can do that by simply logging out and choosing a new desktop environment to use.  It should be noted that, at least in my opinion, Linux desktop environments have come a **long **way from the early Linux GUIs.  

### Terminal 

In the Linux world, the "terminal" is the equivalent of the Windows command prompt.  It's a textual interface to enter commands, navigate the file system and perform tasks on the Linux machine.  You'll probably end up using the terminal a lot to install software on your Linux machine.  There are several different "[package managers](https://en.wikipedia.org/wiki/Package_manager)" used on Linux - "yum" and "apt-get" are ones you'll probably see and hear of quite often.  Sometimes people use different words for the terminal like 'console', or 'shell' - [this is a good explanation](http://askubuntu.com/a/506628) of all those different terms.  There are many different versions of terminals depending on your distribution or personal preference, but all of them will allow you to perform the same tasks.  When in a terminal session, CTRL+C will break out of most running processes.

### Elevated Privileges

Linux is much more strict (and by default, secure) than Windows.  Your user will have limited rights to perform certain tasks.  Often you'll have to elevate your privileges to perform a certain task.  If you are granted permission to do so (via an entry in the `sudoers` file - see `man sudoers`) you can execute a command with elevated privileges by putting `sudo` before your command.  Read more about sudo [here](https://en.wikipedia.org/wiki/Sudo).  If you're wondering, sudo originally stood for 'superuser do'.  Another option you may need to invoke is "[switch user](https://en.wikipedia.org/wiki/Su_(Unix))" or just `su` by calling `sudo su` or just `su`.  The difference between `sudo` and `su` is that `sudo` allows you to perform the action as your own user, with your own password while `su` grants you the permission of another user (typically the 'root' user) and requires the superuser password.  Read more on the difference if you're interested [here](https://www.howtogeek.com/111479/htg-explains-whats-the-difference-between-sudo-su/).

### man  

The Linux command `man` is used to get a '[manual](https://en.wikipedia.org/wiki/Man_page)' (or user guide) for a specific piece of software.  Many programs and Linux commands have detailed user guides accessible by typing `man [command name] `in a terminal window.  Most man pages use `more` ([reference](https://en.wikipedia.org/wiki/More_(command))) or `less` ([reference](https://en.wikipedia.org/wiki/Less_(Unix))) to view the manual page.  In more or less you navigate through a file using SPACE to move forward one page or 'b' to move backwards one page.  Hit 'q' to quit.  To learn more about more and less, try `man more` or `man less`.  Whew, that's a mouthful.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/less-is-more.jpg)\
Not really, less is less and more is more.

### SSH

SSH ([Secure Shell](https://en.wikipedia.org/wiki/Secure_Shell)) is the term most commonly used for "remoting in" to a Linux machine and manipulating/performing tasks via the command line.  You can SSH into a machine with a username and password, or via a private key file.  To SSH into a machine, you must have an SSH compatible client.  On Linux, any terminal window will do.  Same goes with any terminal in OS X.  Windows (pre version 10) has no built in support for SSH, but there are several third party programs that'll do the trick.  Check out PuTTY and Cygwin if you need a good Windows SSH client.

### Commonly used commands

This section is going to be a rapid fire dump of some commonly used commands.  If you're brand new to the command line you can use this as a quick reference or intro to some of the things you can do.  Many commands have 'switches' or arguments that you can pass to them to alter the task performed in some way.  Arguments are passed after the command and preceded by a dash "-a" or two dashes "\--all".  To learn more about a command, always remember that `man` exists to help you out.

### How do I list the contents of a directory?

Use the `ls` command.  Commonly used arguments are "-la", the "-l" switch uses a "long" (detailed) list format, the "-a" switch includes hidden files (those beginning with a ".").\

### How do I navigate to a different directory?

Use `cd` (change directory) and enter the path to the directory you would like to move to.  Paths that begin with a forward slash ("/" - the Linux path delimiter) are absolute paths.  That means they begin from the top of the directory tree.  Paths that don't have a leading forward slash are relative - they begin at the folder you're currently in.   You can pass a full path instead of stepping through one level at a time.  If you're in `/home` and you want to go to a folder three levels deeper you'd use something like `cd projects/scratch/foo`.

### What directory am I in right now?

`pwd` (present working directory) will tell you where you're at.\

### How do I create a directory:

`mkdir [dirname]` will create a new subdirectory in the current directory.

### How do I create a file: 

`touch [filename.extension]` will create a new file in the current directory.\

### How do I change permissions on a file or folder?

`chown` (change owner), `chgrp` (change group) and `chmod` (change permissions) are the three commands to remember when it comes to changing file/folder permissions and ownershipt.  Managing file permissions via Terminal can be a tricky thing to wrap your head around and I could spend a full blog post explaining them, but for now you should know that these commands exist and you should spend time [learning about file permissions](https://www.linux.com/learn/understanding-linux-file-permissions).  If all else fails you can manager permissions (to an extent) via the GUI in your desktop environment by right clicking on a file/folder and selecting Properties - Permissions.  

### Edit a simple text file:

There are several built in text editors that can be used within a terminal session.  My favorite is [nano](https://en.wikipedia.org/wiki/GNU_nano) (launched by typing `nano [filename]`).  It has simple controls that are listed on the bottom of the editor.  Hardcore nerds prefer Vim (launched with the command `vi`).  I just entered Vim while writing this blog post and it took me about 2 minutes to simply exit Vim.  That's why I don't use Vim.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/vim-joke.png)\

### How do I move, copy or rename a file?

`mv [source] [destination]` can be used to **move** a file from one directory to another.  If the destination directory is the same as the source then the file will be renamed.  `cp [source] [destination]` is used to copy a file from a source to a destination.\

### How do I delete a file?

`rm [filename]` (remove) will delete a file.

### How do I delete a directory?

`rm -rf [directory]` will remove a directory (the -r switch is for 'recursive' and the -f switch is to 'force' the deletion and not ask for confirmation).

### How do I find a certain item in a long list of text or the result of a command like 'ls'?

This might be getting into a bit more advanced territory, but I think it's worth noting in a beginners guide that `grep` exists.  It's best illustrated via example, so imagine a directory structure like so:

    drwxr-xr-x 2 toddsharp toddsharp 4096 Mar 18 18:19 .
    drwxr-xr-x 4 toddsharp toddsharp 4096 Mar 18 17:52 ..
    -rw-r--r-- 1 root      root         0 Mar 18 18:19 bar.txt
    -rw-r--r-- 1 root      root         0 Mar 18 18:19 food.txt
    -rw-r--r-- 1 root      root         0 Mar 18 18:19 foo.txt

Let's say I wanted to find all the files in this directory that begin with the string "foo".  One way of doing this would be to "pipe" the result of the `ls` command to `grep` and pass a "regular expression" that I want to search for.  In Linux, to redirect the result of a command you use the "pipe" character `|` which is why you'll often hear "pipe" used in this context.

`ls -la | grep 'foo*'`

Would result in:

    -rw-r--r-- 1 root      root         0 Mar 18 18:19 food.txt
    -rw-r--r-- 1 root      root         0 Mar 18 18:19 foo.txt

Read more on `grep` [here](https://en.wikipedia.org/wiki/Grep).

### Are there other ways to search for a file?

Of course! You can use `find`.  Here's a [thorough article](https://www.howtogeek.com/112674/how-to-find-files-and-folders-in-linux-using-the-command-line/) for more details, but `find` is another way to search for a file like the previous `grep` example. The first argument passed to find is the path at which to start looking.  A dot (".") is the current directory, while "/" would search from root.  The next argument is the name of the file, but find requires us to "escape" the wildcard (\*) so to reproduce the previous example we'd do:

`find . -name foo\*`\

### How can I copy a file from one Linux machine to another?

Secure copy, or `scp` is a bit beyond the scope of a beginner article, but know it exists and [read more](https://en.wikipedia.org/wiki/Secure_copy) on it when you need to.  You can use `scp` to copy from/to Linux machines, but to use Windows to copy to/from a Linux machine you need PuTTY or [WinSCP](https://winscp.net/eng/download.php).

### Can I remotely control my Linux machine?

There are several remote control options available on Linux, the most popular of which is [VNC](https://www.realvnc.com/download/vnc/) which stands for [virutal network computing](https://en.wikipedia.org/wiki/Virtual_Network_Computing).  To use VNC, the machine that you'd like to control must have a VNC "server" installed and the machine on which you connect from must have a VNC "client" or viewer.  There are VNC viewers available for all major operating systems - you can easily remote into a Linux machine from a Windows machine.  Raspberry Pi has a VNC server installed by default (but it must be enabled via the Raspberry Pi configuration menu).  \

### What is the best way to get started with Linux?

A good way to try out Linux is to create a bootable USB drive containing a Linux image and play around with it a bit!  Ubuntu is a popular distribution (with a very nice default desktop environment).  Follow the directions [here](https://www.ubuntu.com/download/desktop/create-a-usb-stick-on-windows).  [PIXEL for PC and Mac](https://www.raspberrypi.org/blog/pixel-pc-mac/) is another great way to try Linux, especially if you plan on getting into Raspberry Pi.  If you're a little more technically savvy, install Linux in a VM on your Windows machine and give it a spin.\
\
Of course you can always download a distribution and install it onto an old laptop.  It's typically less resource intensive than Windows so you can get a few more years life out of an old machine you'd have otherwise thrown away!

Image by [12019](https://pixabay.com/users/12019-12019) from [Pixabay](https://pixabay.com)
