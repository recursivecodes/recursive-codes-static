---
title: "The Numbers Don't Lie: Camping in Call of Duty Works"
slug: "the-numbers-don-t-lie-camping-in-call-of-duty-works"
author: "Todd Sharp"
date: 2022-03-14
summary: "In this post, I'll tell you why camping is a valid strategy in Call of Duty."
tags: ["Gaming"]
keywords: "call of duty, gaming, video games, camping"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/camping%2Fdaan-weijers-pSaEMIiUO84-unsplash.jpeg"
---

I've been a console gamer for a long, long time. Yeah, I know about the jokes - and I've heard them all. Console's suck; real gamers use PCs. Whatever, let's move past that because what I'm about to tell you will probably enrage you even more than my choice of gaming hardware. What might that be, you ask? Well, dear friend, let me tell you: there's nothing wrong with "[camping](https://knowyourmeme.com/memes/camping)." That's right, I said it. Camping works, and I have the data to prove it.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/camping%2Fcamping.jpeg)

If you're still here, let me explain. The past few months, I saved my "Call of Duty" stats to a database for my "[Brain to the Cloud](https://bttc.toddrsharp.com)" project. Side note - if you haven't checked it out yet, you totally should. Once I had the data in my database, I could slice and dice hundreds of different ways to see what interesting trends and patterns showed up in the data. One of the most exciting things that jumped out to me very early on was: the less I move, the better I do. You see, one of the metrics included in the match data that I downloaded from the (unofficial) Call of Duty API is "time spent moving." As soon as I saw this metric, I knew that I had to write a query to group the data on ranges of "time spent moving" to see how I did according to that metric. It turns out the less I move, the better I do.\

Here's my K/D ratio. Some of these ranges have a minimal sample size - I'll exclude those in a bit. But, look at this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/camping%2Ftime_moving_0.png)

From 41-50% to 91-100%, you can see that my K/D ratio steadily declines. Here's that range expanded, and I'll throw in the E/D ratio just to add another metric.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/camping%2Ftime_moving_1.png)

It's almost unreal how much better I do the less I move. As I said earlier, let's consider the sample size.

  ----------- --------------- --------------- -------------------------
  **Range**   **K/D Ratio**   **E/D Ratio**   **Time Played**
  1-10        0               0               \-\--
  11-20       15              16              9 mins
  21-30       0               0               \-\--
  31-40       2.33            2.83            6 mins
  41-50       3.64            4               11 mins
  51-60       2.75            2.88            9 mins
  61-70       2.17            2.41            45 mins
  71-80       1.73            2.05            2 hrs, 54 mins
  81-90       1.25            1.51            15 hrs, 26 mins
  91-100      1.18            1.4             3 days, 18 hrs, 28 mins
  ----------- --------------- --------------- -------------------------

Even if I exclude the ranges where I only played one or two matches (but come on, check out that **gaudy** 16 E/D in the 11-20% range), the data still shows that my K/D and E/D are improved when I spend a portion of the match "posted up" and letting the enemy come to me. Hold on - I already know what you're about to say. "Of course, your K/D and E/D are better when you camp - that's why people don't like you!" And believe me when I tell you that there are plenty of reasons not to like me, but camping in Call of Duty isn't one of them. Still, you probably think that my Win/Loss ratio won't share this trend. And to that, I say: "pfffftt\...you're wrong!" (in the nicest, most respectful way possible).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/camping/time_moving_3.png)

If you're wondering, here's how that looks in tabular form:

  ----------- ---------- ------------ --------------- -------------------------
  **Range**   **Wins**   **Losses**   **W/L Ratio**   **Time Played**
  1-10        0          0            0.00            \-\--
  11-20       1          0            1.00            9 mins
  21-30       0          0            0.00            \-\--
  31-40       0          1            0.00            6 mins
  41-50       1          0            1.00            11 mins
  51-60       1          1            1.00            9 mins
  61-70       2          2            1.00            45 mins
  71-80       16         8            2.00            2 hrs, 54 mins
  81-90       52         50           1.04            15 hrs, 26 mins
  91-100      269        333          0.81            3 days, 18 hrs, 28 mins
  ----------- ---------- ------------ --------------- -------------------------

What about score, score per minute, and kills per minute? Well, that's where the data goes a bit haywire. I do my best in the 61-70% range in those metrics. But then they all drop in the 71-80% range, improve in the 81-90% range and get **way better** in the 91-100% range. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/camping%2Ftime_moving_5.png)

And just so you can see the time spent in each range:

  ----------- --------------- ---------------------- ---------------------- -------------------------
  **Range**   **Avg Score**   **Score Per Minute**   **Kills Per Minute**   **Time Played**
  1-10        0               0                      0                      \-\--
  11-20       1,975           202                    3.06                   9 mins
  21-30       0               0                      0                      \-\--
  31-40       1,714           286                    2.33                   6 mins
  41-50       4,775           418                    3.5                    11 mins
  51-60       1,184           242                    2.25                   9 mins
  61-70       4,260           371                    2.99                   45 mins
  71-80       2,230           306                    2.12                   2 hrs, 54 mins
  81-90       2,928           322                    2.23                   15 hrs, 26 mins
  91-100      3,234           359                    2.41                   3 days, 18 hrs, 28 mins
  ----------- --------------- ---------------------- ---------------------- -------------------------

I've got no real explanation for this one. If anything, I'd say that **maybe** something like 'double xp' could be factoring in here and throwing some ranges off? I've spent the vast majority of my time in the 91-100% range, so maybe it's just a matter of sample size? I'm not sure.

Still, the data proves it - camping is valid, and it works. The less I move, the better my K/D and E/D are, and I win more often. This project has led to some real eye-opening moments like this one, and I had a lot of fun hacking around with the data. It is impressive how seeing the data in a different light can show you things you would never have anticipated. Even if I'm not entirely committed to camping, it does tell me that simply slowing things down a bit will always benefit my stats and my team's ability to win the match.

Photo by [Daan Weijers](https://unsplash.com/@daanweijers?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/video-game-camping?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
