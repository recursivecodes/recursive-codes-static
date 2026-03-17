---
title: "IntelliJ IDEA - Multiple DB Consoles (And Recovering Ones You Didn't Intend To Close)"
slug: ""
author: "Todd Sharp"
date: 2017-05-25
summary: ""
tags: ["IntelliJ IDEA"]
keywords: "idea, sql, console"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/30/banner_5ee2d4414351b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

I use the Database view/plugin in InelliJ IDEA quite often.  It's actually become my "go to" editor for SQL scripts because of it's responsiveness, the fact that it's right there inside my IDE and the code completion and join hints are often times better than the DBMS vendor's offering.  It's pretty easy to open a new console to start writing queries once you've set up a datasource.  You can click the 'SQL Console' icon in the toolbar, or right click on the datasource and choose 'Console':\

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/idea_db_console_1.png)

What some people aren't aware of though is that you can open multiple different consoles against the same datasource by selecting New - Console:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/idea_db_console_2.png)\

The problem is, once you close any console but the first, the rest become lost forever, right?  Not necessarily.  I had accidentally closed a console this morning that I wasn't finished with and needed to recover that query.  I moused over the tab of another console that I had open and noticed that IDEA showed me the full path to where that file was stored:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/idea_db_console_3.png)\

Manually navigating to that path showed me all the other consoles that I'd been working with recently!  It's obviously not fail safe, but in a pinch it's a way to recover scripts that you didn't intend to close.

\

Image by [BkrmadtyaKarki](https://pixabay.com/users/BkrmadtyaKarki-745116) from [Pixabay](https://pixabay.com)
