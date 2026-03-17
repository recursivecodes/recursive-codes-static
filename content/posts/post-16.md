---
title: "Brain Teaser:  Find The Missing Number"
slug: ""
author: "Todd Sharp"
date: 2017-03-29
summary: ""
tags: ["Brain Teasers", "Groovy"]
keywords: "Groovy, interview question, programming interview"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/16/banner_54e5d646425aa414f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

When I first saw this challenge I thought it would be a lot more difficult than it turned out to be.  Here is the challenge:

> Here's a list with numbers from 1-250 in random order, but it's missing one number. How will you find the missed number?

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/wouldnt-say-ive-been-missing-it.jpg)

I generated the list of numbers on the fly each time:
```groovy
// first, create the list 
List listWithNumbersInRandomOrder = (1..250).toList()

// randomize it
Collections.shuffle(listWithNumbersInRandomOrder, new Random(System.nanoTime()))

// remove 1 of the items
Integer removed = listWithNumbersInRandomOrder.remove(0)

// have we removed one?
assert listWithNumbersInRandomOrder.size() == 249
```



But if you'd rather work from a static set, here's a list for you:

    [147, 235, 53, 31, 165, 77, 105, 158, 228, 212, 211, 86, 98, 89, 205, 243, 136, 187, 119, 127, 133, 230, 137, 126, 154, 244, 23, 203, 122, 168, 176, 155, 145, 108, 172, 150, 42, 210, 65, 14, 72, 217, 44, 80, 216, 175, 173, 56, 116, 40, 55, 157, 245, 197, 204, 8, 28, 141, 25, 5, 226, 220, 36, 27, 109, 164, 60, 200, 231, 110, 209, 182, 32, 128, 208, 221, 114, 11, 224, 241, 90, 92, 103, 4, 160, 100, 16, 120, 20, 71, 169, 218, 51, 112, 107, 15, 171, 121, 196, 185, 174, 85, 232, 186, 181, 83, 41, 33, 74, 236, 177, 189, 156, 46, 87, 118, 57, 48, 180, 9, 73, 59, 99, 194, 66, 132, 214, 102, 238, 152, 49, 234, 190, 50, 96, 129, 45, 134, 106, 94, 35, 246, 162, 170, 219, 81, 19, 250, 143, 167, 63, 39, 225, 131, 199, 178, 54, 227, 195, 79, 6, 43, 179, 239, 229, 47, 240, 111, 193, 104, 61, 3, 2, 248, 12, 138, 21, 242, 95, 183, 64, 24, 130, 153, 97, 37, 249, 7, 223, 38, 34, 148, 26, 123, 13, 166, 207, 163, 206, 139, 70, 125, 29, 159, 142, 213, 202, 215, 67, 82, 184, 113, 146, 161, 93, 75, 101, 198, 62, 191, 188, 22, 144, 135, 149, 69, 52, 247, 115, 17, 140, 84, 68, 58, 10, 192, 222, 88, 78, 30, 233, 18, 1, 237, 151, 76, 117, 91, 201]

The brute force method is easy, but we can solve this without the two separate loops required here:

` `[`Integer result = (1..250).sum() - listWithNumbersInRandomOrder.sum()`]` `\

Here's my solution:

\[spoiler label=Show Solution\]\
```groovy
Integer total = (listWithNumbersInRandomOrder.size() + 1) * (listWithNumbersInRandomOrder.size() + 2) / 2
Integer missingNumber = total - listWithNumbersInRandomOrder.sum()
println "Missing number is ${missingNumber}"

// have we found the correct missing number?
assert removed == missingNumber
```

\[/spoiler\]

How would you solve it?

Image by [andibreit](https://pixabay.com/users/andibreit-2748383) from [Pixabay](https://pixabay.com)
