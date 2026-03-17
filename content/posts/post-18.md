---
title: "Remote Deployment For IntelliJ IDEA Community Edition"
slug: ""
author: "Todd Sharp"
date: 2017-04-04
summary: ""
tags: ["Groovy On Raspberry Pi"]
keywords: "remote deploy,idea, intellij,ftp,sftp,raspberry pi"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/18/banner_53e6d4414853b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

I've been using IntelliJ IDEA Community Edition on my personal machine to work with some of the demos that I've been using for my series on using Groovy to program on the Raspberry Pi.  One of the features I've missed most from Ultimate Edition is the ability to remotely deploy to the Pi to keep the code in sync.  I've worked around it by using `SCP` every time I change something, but it's a bit tedious to do that every time, so I sought out additional options and found the [Source Sync](https://plugins.jetbrains.com/plugin/7374-source-synchronizer) plugin.  It's pretty easy to [install](https://github.com/fioan89/sourcesync) and so far I've found that it works pretty much identically to the Remote Deploy feature in Ultimate Edition (with the exception that it doesn't provide feedback that it is syncing).  I'll use this plugin going forward so if you plan on following along with the series it would be a good idea to install it!\
\

{{< callout >}}
I should note that I did run across a bug in this plugin and filed an issue on GitHub.  Files in the root directory of your project are not synced.  I've posted a fix in the [GitHub issue](https://github.com/fioan89/sourcesync/issues/43) for those interested in patching it and building the plugin themselves.  
{{< /callout >}}
\

Image by [Sponchia](https://pixabay.com/users/Sponchia-443272) from [Pixabay](https://pixabay.com)
