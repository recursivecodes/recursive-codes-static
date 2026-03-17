---
title: "Brain Teaser:  Calculate Max Stock Profit"
slug: ""
author: "Todd Sharp"
date: 2017-03-27
summary: "Calculate the max profit from buying and selling stock."
tags: ["Brain Teasers", "Groovy"]
keywords: "groovy,calculate stock profit,brain teaser"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/14/banner_57e3d142425aad14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

I came across an interesting puzzle to solve via [interviewcake](https://www.interviewcake.com/):

> <div>
>
> Suppose we could access yesterday's stock prices as an array, where:
>
> </div>
>
> - The values are the price in dollars of Apple stock.
> - A higher index indicates a later time.
>
> So if the stock cost \$500 at 10:30am and \$550 at 11:00am, then:
>
> stockPricesYesterday\[60\] = 500;
>
> Write an efficient function that takes stockPricesYesterday and returns **the best profit I could have made from 1 purchase and 1 sale of 1 Apple stock yesterday.**
>
> For example:
>
> ::: 
> ``` language-java
> int[] stockPricesYesterday = new int[]{10, 7, 5, 8, 11, 9};
> getMaxProfit(stockPricesYesterday);
> // returns 6 (buying for $5 and selling for $11)
> ```
> :::
>
> No "shorting"---you must buy before you sell. You may not buy *and* sell in the same time step (at least 1 minute must pass).

Thinking through the issue leads me to the following thought process:\
\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/businessman-1106922_640.jpg)\

1.  Loop each 'time of day' slot.
2.  Gather a list of the remaining time slot's prices.
3.  Filter that list to only those greater than the current price.
4.  Get the max of that filtered list.
5.  Subtract the current time slot price from the 'max' future price.
6.  If the result is greater than the previous iteration, set that difference as the new 'max' profit.
7.  Return the 'max' profit.

And here's how that looks in code:
```groovy
List p1 = [10,7,5,8,11,9]
List p2 = [55,42,43,50,43,30,46,50,43]

def maxProfit = { List p->
    Integer profit = 0
    p.eachWithIndex { Integer price, Integer idx ->
        profit = Math.max( profit, p.subList(idx, p.size()).findAll { it >= price }.max() - price )
    }
    return profit
}

def one = maxProfit(p1)
println one
assert one == 6


def two = maxProfit(p2)
println two
assert two == 20
```

\

Feel free to share your solution in the comments below.  I'd love to see how you would solve this problem.

\

Image by [Comfreak](https://pixabay.com/users/Comfreak-51581) from [Pixabay](https://pixabay.com)
