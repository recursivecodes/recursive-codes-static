---
title: "Brain to the Cloud - Part III - Examining the Relationship Between Brain Activity and Video Game Performance"
slug: "brain-to-the-cloud-part-iii-examining-the-relationship-between-brain-activity-and-video-game-performance"
author: "Todd Sharp"
date: 2022-03-16
summary: "In the final post in this series, we'll look at the results of collecting nearly 21 hours and 150+ games worth of data while wearing the Mind Flex. Is there a relationship between my EEG data and my video game performance? Let's find out!"
tags: ["Brain to the Cloud", "Cloud", "Java", "Micronaut"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/bttc-3-sm.png"
---

In my [last post](https://recursive.codes/blog/post/2108), we looked at the technical aspects of my Brain to the Cloud project including much of the code that was used to collect and analyze the data. In this post, we'll see what the data has to say about my original questions and hypothesis to finally determine if there is any relationship between my brain activity and my video game performance. In addition to this blog post series, check out the [project site](https://bttc.toddrsharp.com) if you'd like to see all of the reports and visualizations that were created during this project. 

- [Video Overview](#Video%20Overview)
- [Interpreting the Results](#Interpreting%20the%20Results)
  - [Game Performance Grouped by Attention](#Game%20Performance%20Grouped%20by%20Attention)
  - [Game Performance Grouped by Meditation](#Game%20Performance%20Grouped%20by%20Meditation)
  - [Game Performance Grouped by Attention to Meditation Ratio](#Game%20Performance%20Grouped%20by%20Attention%20to%20Meditation%20Ratio)
- [Results and Summary](#Summary)
- [Links](#Links)

## Video Overview 

If you would like an entertaining presentation of the material contained in this blog post, you can check out the following YouTube video.

## Interpreting the Results 

I spent approximately 21 hours playing around 150 online multiplayer matches and collected over 12k records of brain data. When I consider my original questions, I feel that I collected enough data to answer most of them. The first question I asked myself was: Can I read my brain data, and if so, is the data valid? And the answer is: YES! Well, to the extent that the Mind Flex provides accurate brain data. That's still somewhat debatable, but I did do some baseline experiments that seemed to indicate *something* to the data. The Mind Flex claims to read your actual brain waves - and it provides values for the individual bands (delta, theta, etc). But those values aren't provided in Hertz as they would be from a medical-grade EEG. Instead, they deliver what they call "ASIC_EEG_POWER_INT" values. Neurosky, the makers of the chip inside the Mind Flex, state these values would typically "typically be reported in units such as Volts-squared per Hz (V\^2/Hz), but since our values have undergone a number of complicated transforms and rescale operations from the original voltage measurements, there is no longer a simple linear correlation to units of Volts." They go on to say that "they are only meaningful compared to each other and to themselves" and that "it would not necessarily be meaningful nor correct to directly compare them to, say, values output by another EEG system. In their currently output form, they are useful as an indication of whether each particular band is increasing or decreasing over time, and how strong each band is relative to the other bands". They also mention that "for display purposes, if you would like to remove the exponential gaps between the bands to make them appear closer to each other, you could display the logarithm of each value, instead of the exponential values themselves." And they're right - it does make the bands appear closer and improves the readability, so that's how I displayed the values in my reports. 

In my opinion, the most useful part of the data provided by the Neurosky chip is the addition of "attention" and "meditation" values. These values are output on a scale of 1-100 and result from some internal calculations based on proprietary algorithms within the microcontroller on the module. Bottom line - it's not a medical-grade EEG but provides data that indicates your general level of attention and calmness. And that's fair enough in my book. It makes life easier when trying to gauge those specific factors. OK, back to my baseline experiments. So for these, I captured my brain data while performing various activities intended to establish the validity of the data and provide a baseline for comparison purposes later on. For example, I tracked my brain data during a somewhat boring work meeting in one experiment. I observed that my average "attention" level was in the mid 40% range, and my average "meditation" or "calmness" level was in the mid 50% range. That's certainly a much higher quantification than e expected based on how much I feel like I'm paying attention during work meetings!

Conversely, I captured my brain data during several actual meditation sessions. I observed a significant decrease in my "attention" levels - low 30% numbers - and a noticeable increase in my "meditation" values - above 70% at times! I also performed a capture while playing various online "memory" type games and observed attention levels in the mid 60% range. Again, there certainly appears to be *something* to this data. It doesn't seem to be "pseudo-random gibberish." 

So, more questions. Can I improve my performance in video games by being super focused and concentrating? If I'm distracted, will I play poorly? Will a "bad game" be visible in my brain activity? These questions are harder to answer. It's difficult to say whether or not I can directly influence my performance by really concentrating. Honestly, maybe I didn't quite think through the questions. It's tough to force yourself to focus while playing a video game. The very act of "trying" to focus, at least for me, is distracting in and of itself. So I can't say if it's possible to improve my performance by concentrating, but I can look at the collected data and see if any patterns appear to support my theory. Before we look at that, let's discuss what factors I decided would indicate "good" performance. Your first thought might be that "wins and losses" would be an excellent factor to judge my performance, but since most of the game modes in Call of Duty (at least the ones that I tend to play the most) are team-based, I don't think that wins and losses are the proper metric to determine my success or failure. Also, my win/loss ratio is pretty garbage. Because I mostly play with random teams instead of with a party, I tend to lose **a lot**. So instead of wins and losses, I decided to look at other factors like my personal kill/death and elimination/death (commonly known as "K/D" and "E/D" ) ratio. I also considered scores and kills per minute and accuracy (how often I hit the intended target). What does the data show? Let's look at some results from a few reports I wrote to combine and analyze the data. As I mentioned earlier, I pulled my Call of Duty stats via some\...undocumented\...API calls to the Activision API. Once I had the game stats, I joined them to my captured brain activity based on the brain and match start/end timestamps. 

### Game Performance Grouped by Attention 

First up - Attention. I grouped my stats based on average attention range - 0-10%, 11-20%, etc. Out of the 20+ hours I tracked, this is the amount of time spent in the various ranges.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f5f5c50-c254-4765-bae3-204611d53dd4/upload_3bff9a1bcc2cb991980d8e478b9ba917.png)

As you can see, I spent no time playing in the 1-20% or 81-100% range, and well over 95% of my time playing in the 31-60% range. Let's throw out the 21-30 and 71-80 ranges since I spent such little time in them. The 61-70 range might even be a little too small of sample size, so it would be with a rather large grain of salt if I did consider it. My hypothesis stated that the more focused I was, the better I would perform. However, if it's believed, the data tells a different story.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/705bd8dc-fd00-4196-957f-602779235fd0/upload_e6b8593b9121500179015f832d174dd6.png)

My K/D and E/D results start low when my attention is low, and increase until they peak at the 41-50% range. They drop in the 51-60% range and grow again in the 61-70% range, but as I said about that range - it's a minimal sample size of 45 minutes, so that could be considered an anomaly, and as I said - grain of salt. This is interesting to me because I hypothesized that there would be a corresponding increase in performance and attention, so this data seems to disprove my hypothesis. In hindsight, this actually makes sense! First-person shooters require attention and focus, but paying **too much** attention can be detrimental. Ask any gamer about what's going on in their brain when they have a perfect match, and they'll tell you that they are "locked-in" mentally, but not hyper visually focused. Instead, they tend to almost "zone out" and let their eyes/ears/brain observe the entire picture. Instead of visually scanning the screen looking for enemies, you tend to do best when you place visual focus on your crosshairs and listen for footsteps. You have to almost intentionally **not** focus on every little detail happening on the screen and let your brain react to the minor changes in the environment that might indicate the presence of an enemy and redirect your crosshairs in reaction to the visual or auditory stimuli. If you explicitly **try** to aim and shoot, you often miss the target. You tend to play best when you're **reactive** instead of **proactive**.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/ab4acf98-1da3-4b40-9ffb-0110affb4fb7/upload_bbc4aa6f69b733f8f8e6b998c6f61eb5.png)

Score per minute data (shown above) shows a similar trend, with a low score per minute for low attention ranges, rising to a peak at 41-50% and falling with increased attention. As does kills per minute:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7754c2e6-053f-4193-9302-e3a810831034/upload_58dd4bd59dd77cde281deacb8e79b86d.png)

Accuracy (shown below) is an odd "W" shaped graph, but the 31-60% range I spent 99% of my time playing follows the same trend. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8fe8cf87-bca9-40ec-b52c-0dd7b77e8ac0/upload_4d9a7deb866d507d59ff65976d225776.png)

So, my best gaming happens when my attention is in the 41-50% range. If I pay more attention, I actually do worse---fascinating stuff.

### Game Performance Grouped by Meditation 

Let's move on to meditation. I didn't state anything in my hypothesis directly related to calmness, though I hypothesized that distractions would lead to poor performance. Is there a relationship between calmness and distraction? When you're distracted, are you not calm? Perhaps, but maybe that's a stretch. Either way, the calmness data is pretty fascinating. I broke out meditation into the same range of groupings. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a22e6178-b87f-467d-8d3e-681cdae05725/upload_c43f9cd437cc73d8fd591307378504e9.png)

As shown above, [I spent all of my time playing in the 41-80% range. 15 minutes in the 71-80% range represents less than a half percent of the time, so I threw that out. ][Interestingly, the data below clearly shows a **decline** in performance when my meditation value, or calmness, increases. I do **better** when I'm **not calm**. This was unexpected, but it makes sense when I think about it! Indeed being calm or relaxed would indicate a decrease in reaction time, and slower reflexes mean I die faster and more often.]

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/491957b0-952d-4034-beb2-4222fe1cc177/upload_c7b0aedd909291a314f22634eab8fb99.png)

My average score follows this trend:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/0fa87fb3-84f7-40f5-8043-57f0bd84e771/upload_966ceee70e340d826088b550fbe34659.png)

As does my score per minute:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/4d28298d-48f6-48a3-966b-b3947b2b097a/upload_e1b52f297c72486eff1f0afcbb6fc89a.png)

As well as kills per minute:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/82e72ca8-2ce0-4a13-a529-6963e7d66f1f/upload_b9efcef78f8c5918ffda1fe85e6c788c.png)

The calmness, or meditation values, seem to reflect reality. Certainly, poor gameplay is not increasing my calmness - there's no way a bad game would make me **calmer**. So I'm going to have to assume that my poor performance is a result of me being too relaxed (or tired). It might be interesting to compare the meditation values to time of day, to see if there is a pattern of increased meditation values and decreased game performance late at night when I'm tired and should be in bed instead of gaming.

### Game Performance Grouped by Attention to Meditation Ratio 

In addition to looking at the impact of attention and meditation on performance, I took another approach and grouped my stats by the ratio of attention to meditation. These were grouped as follows:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/cc8df898-5d01-42bb-a0c0-e89df938a042/upload_546a2adf1671b0e069913aceff21729d.png)

99+% of the stats fell into the .60-1.1 attention to meditation range, so we'll throw out the rest. [My K/D and E/D were best when my average attention (45%) was roughly 70-79% of my meditation (almost 60%) value. ]

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de99bbf0-b910-4634-9e79-bacd24b3a28c/upload_9620705c51bf109273537379a86bd912.png)

I'd like to include the other ranges (shown below) because things get interesting when my attention level is higher than my meditation level. Still, I don't think there is enough data to consider this valid.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6cc8fd60-e7e0-4675-96aa-d438140efb7c/upload_8ff6a44d93934cdde56940007bc470be.png)

Interestingly, my score per minute (below) does not follow the K/D trend, but trends upwards as my attention level approaches the same or higher level as my meditation.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/cffdde16-eb83-4057-9ecf-7bd0db11beba/upload_da5d78191f12e3ccbe6c1072421da0ae.png)

The kills per minute graph (below) mirrors the score per minute graph. You might think that kills equate to score, but score includes other factors like objective captures, assists, non-lethal equipment usage (stun grenades, smoke grenades), and killstreaks. So it's not as direct a relationship as you might think.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5be3b85f-4b05-4458-aabb-5bf359429601/upload_6b4f2f8e8f97dd6d51b6a464dc2d4dd4.png)

I'm not sure how to interpret the data related to the attention to meditation ratio or if that's even a valid approach to looking at it at all. But, I did include it here as an alternative, because I wanted to take an alternative approach to look at things.

## Results and Summary 

So, is there a direct, measurable relationship between superior gaming performance and high levels of attention? Or, are there just too many factors at play? It's hard to say definitively, but there certainly seems to be trends that indicate my performance relates to my brain activity. My game performance is best when my attention and meditation values are moderate. When I pay too much attention or am too calm, my performance decreases. I've spent a lot of time on this project - from the idea phase to the hardware and software builds to the data collection - it's been a passion that has spanned several months. I'm not a neuroscientist, but I've learned a bit about focus, attention, and calmness and how they relate to my video game performance. I've gotten to spend time on things that I'm highly passionate about - hardware tinkering, writing software, and analyzing data in the cloud. Overall, I'd say the project was a huge success. To learn more about this project, check out the links below. If you have any insight that you'd like to share or have an opinion about a different approach or ways to look at the data, leave a comment below.

## Links 

If you'd like to check out the code behind this project, or read about the inspiration, see the following GitHub repos and links. 

- <https://bttc.toddrsharp.com>
- <https://github.com/recursivecodes/brain-to-the-cloud-arduino>
- <https://github.com/recursivecodes/brain-to-the-cloud>
- <https://github.com/kitschpatrol/Brain>
- <https://github.com/plapointe6/EspMQTTClient>
- <http://www.frontiernerds.com/brain-hack>
