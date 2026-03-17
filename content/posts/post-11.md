---
title: "A Groovy Alternative To Java 8 Streams and Collectors"
slug: ""
author: "Todd Sharp"
date: 2017-03-22
summary: "I recently read this article over at DZone about using Java 8 Streams and Collectors to manipulate and perform calculations on a list of integers.  I don't intend to get in a pissing match about which language is better, but my immediate thought was how much easier (and cleaner) it is to perform these tasks in Groovy.  Collections in Groovy have long been a shining example of how Groovy enhances Java with convenience methods for common tasks.  Here's a recreation of all the examples in the DZone"
tags: ["Groovy", "Java"]
keywords: "Groovy, Java, Streams, Collection"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/11/banner_50e6d3424850b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

I recently read [this article](https://dzone.com/articles/using-java-collectors) over at DZone about using Java 8 Streams and Collectors to manipulate and perform calculations on a list of integers.  I don't intend to start an argument over which language is better, but my immediate thought was that it would make a good blog post to show how one might perform these tasks in Groovy.  [Collections in Groovy](http://docs.groovy-lang.org/latest/html/groovy-jdk/java/util/Collection.html) have long been a shining example of how Groovy enhances Java with convenience methods for common tasks.  Here's a recreation of all the examples in the DZone post to show you how easy Groovy makes them:\
\
Let's throw together a List of 100 random integers:\
```groovy
Random random = new Random()
List numbers = (0..100).collect { Math.abs(random.nextInt()) % 100 + 1 }
println 'Random list of 100 integers: ' + numbers
```



Determining the sum and average is quite simple:
```groovy
println 'Computed sum of integers: ' + numbers.sum()
println 'Computed average of integers: ' + numbers.sum() / numbers.size()
```



Though, average isn't a built in method.  So, let's add it using [metaprogramming](http://groovy-lang.org/metaprogramming.html) instead:
```groovy
List.metaClass.average = {
    return delegate.size() ? delegate.sum() / delegate.size() : 0
}
println 'Average using metaClass method: ' + numbers.average()
```



What about min/max?\
```groovy
println 'Minimum number: ' + numbers.min()
println 'Maximum number: ' + numbers.max()
```



There's no built in method to the DZone `summarizingInt()` example, but we can do either: \
```groovy
println 'Summary: ' + [
        count  : numbers.size(),
        sum    : numbers.sum(),
        min    : numbers.min(),
        average: numbers.average(),
        max    : numbers.max(),
]
```



Or, again, add a method via metaprogramming:\
```groovy
List.metaClass.summarizingInt = {
    return [
            count  : delegate.size(),
            sum    : delegate.sum() ?: 0,
            min    : delegate.min() ?: 0,
            average: delegate.average(),
            max    : delegate.max() ?: 0,
    ]
}

println 'Summary using metaClass: ' + numbers.summarizingInt()

def x = []
println 'Summary using metaClass on empty list: ' + x.summarizingInt()
// prints [count:0, sum:0, min:0, average:0, max:0]
```



Partitioning a list?  No problem in Groovy, just use groupBy:\
```groovy
println 'Partitioning a List: ' + numbers.groupBy { it > 50 ? true : false }
// prints: [false:[16, 35, 34...], true:[96, 54, 58...]]
```



Here's the full example in case you'd like to run them all yourself:\
```groovy
Random random = new Random()
List numbers = (0..100).collect { Math.abs(random.nextInt()) % 100 + 1 }
println 'Random list of 100 integers: ' + numbers

println 'Computed sum of integers: ' + numbers.sum()
println 'Computed average of integers: ' + numbers.sum() / numbers.size()

List.metaClass.average = {
    return delegate.size() ? delegate.sum() / delegate.size() : 0
}
println 'Average using metaClass method: ' + numbers.average()

println 'Minimum number: ' + numbers.min()
println 'Maximum number: ' + numbers.max()

println 'Summary: ' + [
        count  : numbers.size(),
        sum    : numbers.sum(),
        min    : numbers.min(),
        average: numbers.average(),
        max    : numbers.max(),
]

List.metaClass.summarizingInt = {
    return [
            count  : delegate.size(),
            sum    : delegate.sum() ?: 0,
            min    : delegate.min() ?: 0,
            average: delegate.average(),
            max    : delegate.max() ?: 0,
    ]
}

println 'Summary using metaClass: ' + numbers.summarizingInt()

def x = []
println 'Summary using metaClass on empty list: ' + x.summarizingInt()
// prints [count:0, sum:0, min:0, average:0, max:0]

println 'Partitioning a List: ' + numbers.groupBy { it > 50 ? true : false }
// prints: [false:[16, 35, 34...], true:[96, 54, 58...]]
```



Image by [romaneau](https://pixabay.com/users/romaneau-834195) from [Pixabay](https://pixabay.com)
