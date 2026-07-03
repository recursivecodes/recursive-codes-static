---
title: "Dude, You're Gonna Need More Burgers: Understanding Stream Group Capacity"
slug: "dude-youre-gonna-need-more-burgers-understanding-stream-group-capacity"
author: "Todd Sharp"
date: 2026-07-02T18:18:14Z
summary: "Before you can understand minimum, target idle, and maximum capacity for Amazon GameLift Streams, you need to understand the lunch rush at BürgerWürld."
tags: ["gameliftstreams", "aws"]
keywords: "gameliftstreams, aws"
featuredimage: https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260703-101151.png
---

## Clocking In

Picture it - you've just arrived at BürgerWürld for your shift. Your polo shirt is sparkling clean, buttoned up and properly tucked in. Your baseball hat is perfectly positioned atop your tangled, but well-groomed locks. Your khaki slacks and apron are also impeccable. And bonus - you've actually remembered your name tag today! You're slightly new here, and Greg has been showing you the ropes. He's the tall skinny guy who has been here for 6 months so he might as well be called a "grill master" at this point. But Greg doesn't start until 11:30 AM, and your shift started at 10. You're on your own for more than an hour - just as the menu flipped over from breakfast to lunch.

You're slightly nervous, and don't want to mess up, so you throw a dozen frozen patties on the clamshell and drop the lid. Sixty seconds later, the clamshell pops open and a waft of steam and the "aroma" of grade-d beef hits you in the face. You snatch your trusty stainless steel spatula from your apron and slide it onto the slick surface of the griddle and place each beef patty onto a perfectly toasted bun. Like Jackson Pollack, you artfully dress each burger with the prescribed amount of condiments and decorate it with toppings. A quick wrap in crinkly wax paper, and they're resting in their temporary home under the heat lamps a mere few minutes from the moment your shift started. Good to go!

<div style="text-align: center;">
  <img src="https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260703-103810.png" alt="clocking in for duty" />
</div>

Problem is - there's not a single customer in the lobby. The drive thru's empty too. Turns out, there's a bit of a lull between breakfast and lunch. You spend the next hour or so stocking the lettuce, checking on the pickles and tomatoes, and doing a quick sweep and wipe down of the grill area to clean up from the giant mess that the breakfast crew always leaves behind. A few customers wander in and order a burger here and there, but when Greg shows up there are still 9 burgers in the window.

## Greg Arrives

<div style="text-align: center;">
  <img src="https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260703-103846.png" alt="greg." />
</div>

"Sup dude?", Greg says.

"The price of gas!" you snarkily retort. Greg is seemingly unamused at your lame attempt at humor.

Greg rolls his eyes as he tightens the apron strings around his gangly waist. You notice that Greg forgot his name tag today, but the shift supervisor Shelly didn't mention it to him. One of the perks of tenure, you suppose.

Greg glances at the window, noticing the 9 stale burgers. "When'd you make those?" he says, not waiting for your reply. "Rule #1 man - never pre-make a batch of burgers before the lunch rush."

He always seems so proud of the wisdom he imparts. You've also noticed that there are an awful lot of "Rule #1's".

## The Lunch Rush

"Between 10 and 11:45 we make orders on-demand," Greg chirps.

Did he just roll his eyes as he finished that last sentence? There's no time to dwell on Greg's idiosyncrasies as the lunch rush will be starting soon and dozens of hungry customers will be queued in the lobby wanting a fresh, cheesy WünderBürger and chips.

Like a seasoned pro, Greg flips the freezer next to the grill open and grabs a stack of six frozen patties in each hand. He slaps them on the griddle with speed and accuracy, lowers the clamshell and spins to slide the buns into the toaster. You watch in amazement as he masterfully dresses and wraps this batch, getting them into the window with almost uncanny timing right as the lobby doors open and a small crew of construction workers walks in to the restaurant.

<div style="text-align: center;">
  <img src="https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260703-103901.png" alt="super greg" />
</div>

"We're out of onions," Greg exclaims. He scurries to the walk-in and on his way past you, he tells you to throw another batch of burgers onto the grill.

"But, we just..." Greg cuts you off before you can finish the sentence.

"Trust me dude. It's Friday - the dudes that will be remodeling that motel next door just pulled into town. They'll be here any minute."

You shuffle to the tiny flip freezer and grab some burgers. You can't help but shake your head at Greg's expertise. You also notice he uses the word "dude" a lot.

For the next 75 minutes, the cycle continues. As customer orders pour in, you slap more burgers on the grill. Thanks to Greg's wisdom, you seem to slide the burgers into the window just as they're needed. Most of the customers are quite pleased, but a few got a bit angry that they had to wait a few minutes because a bus full of hungry baseball playing teenagers cleaned out the window just before they arrived. Even Greg in his infinite wisdom couldn't have foreseen that one.

## The Freezer is Empty!

At around 1:25 PM, things are mostly calmed down. But Greg knows that a book club always shows up around 1:30 PM and they always order ÜberBürgers. He opens the little freezer next to the grill to get another batch going.

"Dude - we're out of burgers. Go to the walk-in and grab another case," Greg barks at you.

You scurry towards the back of the restaurant, almost slipping on a bit of grease along the way. "Good thing I bought non-slip footwear per the onboarding manual," you say to no one in particular.

"Greg, there aren't any cases left," you shout towards the grill.

<div style="text-align: center;">
  <img src="https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260703-110121.png" alt="out of burgers!" />
</div>

"Dude, they're behind the chips!" he barks back.

Shoving the cases of 'chips' out of the way, you see nothing but more fries. You also wonder why a German themed fast-food chain uses the British slang for french fries, but that thought quickly turns to panic.

"There's none left - I swear!" you tell Greg as you arrive back in the grill area. "How will we handle dinner rush?"

"Dude! I told Shelly two days ago that we needed to order more, dude!" Greg's clearly not happy with the situation.

"Head to the store and buy three cases. That'll get us through dinner, and the truck will be here at 5:00 AM tomorrow," Greg tells you.

## 10 Years Later

You're sitting at your desk, staring at the AWS console in your browser. You're trying to wrap your head around [stream group](https://docs.aws.amazon.com/gameliftstreams/latest/developerguide/stream-groups.html) capacity when provisioning a cloud streaming game with Amazon GameLift Streams when you think back to those days at BürgerWürld. You can't help but realize that Greg has imparted all of the wisdom that you need to understand the concept.

<div style="text-align: center;">
  <img src="https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clipboard-20260703-104209.png" alt="remembering your mentor" />
</div>

## Minimum (Always-On) Capacity

These are the burgers that you make without a known rush. They're in the window, waiting for someone to come and order them. They're paid for - whether someone buys them or not.

## Target Idle Capacity

This is the rotating cycle of burgers during a known rush. You make a dozen - without pending orders - because you know that someone will be walking through that door in the next few minutes. When a few are gone, you replenish the stock because you know the rush will continue for a known period of time. If an unpredictable rush comes in and cleans out your window, the next customer still gets a burger. They just have to wait a bit longer to get one. Once that lunch rush is over, you're back to just a few in the window at a time or completely 'on-demand' burgers.

## Maximum Capacity

You've got a certain amount of burgers in the walk-in. Once they're gone, that's it. It's good because you're not wasteful - you're not keeping more on-hand than you'll use in the next few days. But you're managing costs. In an emergency, you can get more burgers, but as a general rule you only keep a known amount on-hand.

## Cheesy Ending

You can't help but wonder if Greg knows just how much he's influenced your career - in more ways than one! You glance at the clock - noticing that it's almost lunch time. You open up Slack and post a message to your team's channel.

"Who wants to grab a 🍔 for lunch?"
