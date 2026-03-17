---
title: "Brain Teaser:  Split An Array Into Equal Parts"
slug: ""
author: "Todd Sharp"
date: 2017-03-28
summary: "Given an array of integers greater than zero, find if it is possible to split it in two (without reordering the elements), such that the sum of the two resulting arrays is the same.  Print the resulting arrays."
tags: ["Brain Teasers", "Groovy"]
keywords: "split array,groovy,java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/15/banner_55e1dc404254a914f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

Here's another challenge that I came across recently:

> Given an array of integers greater than zero, find if it is possible to split it in two (without reordering the elements), such that the sum of the two resulting arrays is the same. Print the resulting arrays.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/array-meme.jpg)

To clarify, given the array `[1,2,3,3,2,1]` it can it be split into two arrays `[1,2,3]` and `[3,2,1]` where the sum of each is equal.

Here's a set of data to work with:

    List lists = [
            [1,2,3,3,2,1],
            [1,2,3,4,5,6,21],
            [1,90, 50, 30, 5, 3, 2, 1 ],
            [1, 50, 900, 1000 ],
            [500,400,100,777,223,2456,4,39,1,222,78,93,7,100,23,1000,3,20,555,345,64,36,689,100,211,2000],
            [1,2,3],
            [1]
    ]

Here's my solution:

\[spoiler label=Show Solution\][
```groovy
def split = { list ->
    def idx = 0
    def result = []
    list.find { int e ->
        def left = list.subList(0, idx)
        def right = list.subList(idx, list.size())
        if( left.sum() == right.sum() ) {
            result << left << right
            return true // exit closure
        }
        return idx++ == list.size() // continue looping
    }
    return result
}

lists.each {
    println split(it)
}
```

]\[/spoiler\]

Which provides the following result:

\[spoiler label=Show Result\]

    [[1, 2, 3], [3, 2, 1]]
    [[1, 2, 3, 4, 5, 6], [21]]
    [[1, 90], [50, 30, 5, 3, 2, 1]]
    []
    [[500, 400, 100, 777, 223, 2456, 4, 39, 1, 222, 78, 93, 7, 100, 23], [1000, 3, 20, 555, 345, 64, 36, 689, 100, 211, 2000]]
    [[1, 2], [3]]
    []

\[/spoiler\]

How would you solve it differently?

Image by [Franc-Comtois](https://pixabay.com/users/Franc-Comtois-8092567) from [Pixabay](https://pixabay.com)
