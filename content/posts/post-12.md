---
title: "A Closer Look At Sorting Algorithms"
slug: ""
author: "Todd Sharp"
date: 2017-03-27
summary: ""
tags: ["Groovy", "Java"]
keywords: "sorting algorithms,sorting,groovy,java,bubble sort,selection sort, insertion sort, merge sort, quick sort, heap sort"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/12/banner_54e5d4454c56ad14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

As I mentioned in a [previous post](http://recursive.codes/blog/post/3), sorting algorithms typically play a large role in programming interviews.  Those who follow the traditional path into the programming world and obtain a CIS degree are typically exposed to algorithms.  Those among us who follow a less traditional path into this world are less familiar with them.  

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/no-idea.jpg)\

I decided to take a deeper dive into sorting algorithms and implement some of them to see:

1.  How difficult they are to implement\
2.  How performant they are against varying sizes of datasets
3.  How they compare to the native sorting in Java

As usual, I've implemented my code in Groovy.  Let's take a look at some algorithms, shall we?

### Bubble Sort

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/Bubble_sort_animation.gif) 

The first sort I decided to look at is a basic bubble sort.  Wikipedia [defines](https://en.wikipedia.org/wiki/Bubble_sort) it as:

> **Bubble sort**[, sometimes referred to as ]**sinking sort**[, is a simple ][sorting algorithm](https://en.wikipedia.org/wiki/Sorting_algorithm)[ that repeatedly steps through the list to be sorted, compares each pair of adjacent items and ][swaps](https://en.wikipedia.org/wiki/Swap_(computer_science))[ them if they are in the wrong order. The pass through the list is repeated until no swaps are needed, which indicates that the list is sorted. The algorithm, which is a ][comparison sort](https://en.wikipedia.org/wiki/Comparison_sort)[, is named for the way smaller or larger elements "bubble" to the top of the list.]

I've implemented all of the examples in this post as methods on the Java List class itself using metaprogramming.  Here's the bubble sort:
```groovy
List.metaClass.bubbleSort = {
    int size = delegate.size()
    def temp
    int i
    int j
    for (i = 0; i < size; i++) {
        for (j = 1; j < (size - i); j++) {

            if (delegate[j - 1] > delegate[j]) {
                temp = delegate[j - 1]
                delegate[j - 1] = delegate[j]
                delegate[j] = temp
            }
        }
    }
    return delegate
}
```



[Pretty simple.  Loop over each element, then compare each element to every other element and swap them if necessary.  For small datasets the performance is fine, but as we get into larger sets the expense really starts to add up.  How much does it add up?  Well, lets take a look at how it performs against random lists ranging from 1000 elements up to 10,000:]

    bubbleSort 1000 numbers: 262 ms
    bubbleSort 2000 numbers: 246 ms
    bubbleSort 3000 numbers: 383 ms
    bubbleSort 4000 numbers: 597 ms
    bubbleSort 5000 numbers: 917 ms
    bubbleSort 6000 numbers: 1341 ms
    bubbleSort 7000 numbers: 2196 ms
    bubbleSort 8000 numbers: 2223 ms
    bubbleSort 9000 numbers: 2792 ms
    bubbleSort 10000 numbers: 4011 ms

[Ouch.  4 seconds to sort 10,000 numbers.  It's pretty clear why bubble sorts aren't used that often.]\

### Selection Sort

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/Selection_sort_animation.gif)\

Wikipedia [says](https://en.wikipedia.org/wiki/Selection_sort):

> The algorithm divides the input list into two parts: the sublist of items already sorted, which is built up from left to right at the front (left) of the list, and the sublist of items remaining to be sorted that occupy the rest of the list. Initially, the sorted sublist is empty and the unsorted sublist is the entire input list. The algorithm proceeds by finding the smallest (or largest, depending on sorting order) element in the unsorted sublist, exchanging (swapping) it with the leftmost unsorted element (putting it in sorted order), and moving the sublist boundaries one element to the right.

This sort should be more efficient than a bubble sort, as the animation and definition above should illustrate.  Instead of a full nested loop, selection sort only loops over a sublist of non sorted items remaining in the list.  Here's the implementation:
```groovy
List.metaClass.selectionSort = {
    int size = delegate.size()
    def temp
    int mIdx
    int i
    int j
    for (i = 0; i < size; i++) {
        mIdx = i
        for (j = i + 1; j < size; j++) {
            if (delegate[j] < delegate[mIdx]) {
                mIdx = j
            }
        }
        temp = delegate[i]
        delegate[i] = delegate[mIdx]
        delegate[mIdx] = temp
    }
    return delegate
}
```



And the results, which illustrate it as a more efficient sort than the bubble sort:

    selectionSort 1000 numbers: 128 ms
    selectionSort 2000 numbers: 138 ms
    selectionSort 3000 numbers: 281 ms
    selectionSort 4000 numbers: 286 ms
    selectionSort 5000 numbers: 427 ms
    selectionSort 6000 numbers: 594 ms
    selectionSort 7000 numbers: 816 ms
    selectionSort 8000 numbers: 1064 ms
    selectionSort 9000 numbers: 1331 ms
    selectionSort 10000 numbers: 1444 ms

### Insertion Sort

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/Insertion_sort_animation.gif)\
\
Per [wikipedia](https://en.wikipedia.org/wiki/Insertion_sort):\

> Insertion sort [iterates](https://en.wikipedia.org/wiki/Iteration), consuming one input element each repetition, and growing a sorted output list. Each iteration, insertion sort removes one element from the input data, finds the location it belongs within the sorted list, and inserts it there. It repeats until no input elements remain.

The implementation looks like this:\
\
```groovy
List.metaClass.insertionSort = {
    int size = delegate.size()
    def temp
    int i
    int j
    for (i = 1; i < size; i++) {
        for (j = i; j > 0; j--) {
            if (delegate[j] < delegate[j - 1]) {
                temp = delegate[j]
                delegate[j] = delegate[j - 1]
                delegate[j - 1] = temp
            }
        }
    }
    return delegate
}
```



Based on the full nested loop I'd anticipate similar performance to the bubble sort, and if we look at the results we can see that the performance is quite comparable to the bubble sort.  Side note, at this point you should be realizing that all of the sorts we've looked at so are about as useful as a fork in a sugar bowl.

    insertionSort 1000 numbers: 223 ms
    insertionSort 2000 numbers: 291 ms
    insertionSort 3000 numbers: 348 ms
    insertionSort 4000 numbers: 631 ms
    insertionSort 5000 numbers: 995 ms
    insertionSort 6000 numbers: 1404 ms
    insertionSort 7000 numbers: 1827 ms
    insertionSort 8000 numbers: 1764 ms
    insertionSort 9000 numbers: 2375 ms
    insertionSort 10000 numbers: 3325 ms

### Merge Sort

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/Merge_sort_animation.gif)\
\
Now we get into the world of the useful, efficient and performant searches.  Wikipedia [says](https://en.wikipedia.org/wiki/Merge_sort):

> Conceptually, a merge sort works as follows:
>
> 1.  Divide the unsorted list into *n* sublists, each containing 1 element (a list of 1 element is considered sorted).
> 2.  Repeatedly [merge](https://en.wikipedia.org/wiki/Merge_algorithm) sublists to produce new sorted sublists until there is only 1 sublist remaining. This will be the sorted list.

The implementation is trickier, but the performance gains are amazing.  
```groovy
List.metaClass.mergeSort = {
    def ms
    def merge

    merge = { a, l, r ->
        int totElem = l.size() + r.size()
        int i
        int li
        int ri
        i = li = ri = 0

        while (i < totElem) {
            if ((li < l.size()) && (ri < r.size())) {
                if (l[li] < r[ri]) {
                    a[i] = l[li];
                    i++;
                    li++;
                } else {
                    a[i] = r[ri];
                    i++;
                    ri++;
                }
            } else {
                if (li >= l.size()) {
                    while (ri < r.size()) {
                        a[i] = r[ri];
                        i++;
                        ri++;
                    }
                }
                if (ri >= r.size()) {
                    while (li < l.size()) {
                        a[i] = l[li];
                        li++;
                        i++;
                    }
                }
            }
        }
        return a
    }

    ms = { List arr ->
        int q = arr.size() / 2
        List leftArray = []
        (0..q - 1).each {
            leftArray << arr[it]
        }
        List rightArray = []
        (q..arr.size() - 1).each {
            rightArray << arr[it]
        }
        ms.trampoline(leftArray)
        ms.trampoline(rightArray)
        merge(arr, leftArray, rightArray)
    }

    return ms(delegate)
}
```

\

    mergeSort 1000 numbers: 61 ms
    mergeSort 2000 numbers: 15 ms
    mergeSort 3000 numbers: 16 ms
    mergeSort 4000 numbers: 16 ms
    mergeSort 5000 numbers: 16 ms
    mergeSort 6000 numbers: 18 ms
    mergeSort 7000 numbers: 18 ms
    mergeSort 8000 numbers: 16 ms
    mergeSort 9000 numbers: 20 ms
    mergeSort 10000 numbers: 15 ms

We're getting pretty efficient here, can we do better?

### Heap Sort

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/Sorting_heapsort_anim.gif)\
Wikipedia [says](https://en.wikipedia.org/wiki/Heapsort):

> [Heapsort can be thought of as an improved ][selection sort](https://en.wikipedia.org/wiki/Selection_sort)[: like that algorithm, it divides its input into a sorted and an unsorted region, and it iteratively shrinks the unsorted region by extracting the largest element and moving that to the sorted region. The improvement consists of the use of a ][heap](https://en.wikipedia.org/wiki/Heap_(data_structure))[ data structure rather than a linear-time search to find the maximum.]

Like merge sort, the implementation is more complex, but the performance gains over the selection sort on which it improves are impressive.\
\
```groovy
List.metaClass.heapSort = {
    def heapify
    heapify = { hArr, s, i ->
        int largest = i;  // Initialize largest as root
        int l = 2 * i + 1;  // left = 2*i + 1
        int r = 2 * i + 2;  // right = 2*i + 2

        // If left child is larger than root
        if (l < s && hArr[l] > hArr[largest])
            largest = l;

        // If right child is larger than largest so far
        if (r < s && hArr[r] > hArr[largest])
            largest = r;

        // If largest is not root
        if (largest != i) {
            int swap = hArr[i];
            hArr[i] = hArr[largest];
            hArr[largest] = swap;

            // Recursively heapify the affected sub-tree
            heapify.trampoline(hArr, s, largest);
        }
    }

    def s
    s = { arr ->
        int n = arr.size()

        // Build heap (rearrange array)
        for (int i = n / 2 - 1; i >= 0; i--)
            heapify(arr, n, i)

        // One by one extract an element from heap
        for (int i = n - 1; i >= 0; i--) {
            // Move current root to end
            int temp = arr[0]
            arr[0] = arr[i]
            arr[i] = temp

            // call max heapify on the reduced heap
            heapify(arr, i, 0)
        }
    }
    return s(delegate)
}
```



But can it outperform the merge sort?

    heapSort 1000 numbers: 82 ms
    heapSort 2000 numbers: 29 ms
    heapSort 3000 numbers: 24 ms
    heapSort 4000 numbers: 35 ms
    heapSort 5000 numbers: 26 ms
    heapSort 6000 numbers: 24 ms
    heapSort 7000 numbers: 24 ms
    heapSort 8000 numbers: 28 ms
    heapSort 9000 numbers: 19 ms
    heapSort 10000 numbers: 18 ms

\
Not quite.  \

### Quick Sort

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/Sorting_quicksort_anim.gif)\
Wikipedia [says](https://en.wikipedia.org/wiki/Quicksort):\

> Quicksort is a [comparison sort](https://en.wikipedia.org/wiki/Comparison_sort), meaning that it can sort items of any type for which a "less-than" relation (formally, a [total order](https://en.wikipedia.org/wiki/Total_order)) is defined. In efficient implementations it is not a [stable sort](https://en.wikipedia.org/wiki/Stable_sort), meaning that the relative order of equal sort items is not preserved. Quicksort can operate [in-place](https://en.wikipedia.org/wiki/In-place_algorithm) on an array, requiring small additional amounts of [memory](https://en.wikipedia.org/wiki/Main_memory) to perform the sorting.

Quick sort is a fast sort, but it is not "stable".  In fact, it's the sort that Java uses when you call `Array.sort`.  The implementation that I used looked like so:\
\
```groovy
List.metaClass.quickSort = {
    int l = 0
    int h = delegate.size()

    def qs
    qs = { arr, low, high ->
        if (arr == null || arr.size() == 0)
            return

        if (low >= high)
            return

        // pick the pivot
        int middle = low + (high - low) / 2
        int pivot = arr[middle]

        // make left < pivot and right > pivot
        int i = low
        int j = high
        while (i <= j) {
            while (arr[i] < pivot) {
                i++
            }

            while (arr[j] > pivot) {
                j--
            }

            if (i <= j) {
                int temp = arr[i]
                arr[i] = arr[j]
                arr[j] = temp
                i++
                j--
            }
        }

        // recursively sort two sub parts
        if (low < j)
            qs.trampoline(arr, low, j);

        if (high > i)
            qs.trampoline(arr, i, high);
    }
    return qs(delegate, l, h)
}
```



And the performance was the most impressive of all the implementations that I have looked at.

    quickSort 1000 numbers: 56 ms
    quickSort 2000 numbers: 12 ms
    quickSort 3000 numbers: 13 ms
    quickSort 4000 numbers: 13 ms
    quickSort 5000 numbers: 12 ms
    quickSort 6000 numbers: 35 ms
    quickSort 7000 numbers: 16 ms
    quickSort 8000 numbers: 14 ms
    quickSort 9000 numbers: 17 ms
    quickSort 10000 numbers: 12 ms

So that's it, right?  Well, actually no, because we haven't yet compared all of these implementations to the native `sort()` method on `java.util.List`.  So how does the native method perform?

    sort 1000 numbers: 39 ms
    sort 2000 numbers: 11 ms
    sort 3000 numbers: 12 ms
    sort 4000 numbers: 14 ms
    sort 5000 numbers: 11 ms
    sort 6000 numbers: 12 ms
    sort 7000 numbers: 12 ms
    sort 8000 numbers: 13 ms
    sort 9000 numbers: 14 ms
    sort 10000 numbers: 10 ms

Better than all of the implementations that we've looked at.  Of course, I would never assume that I could implement a more efficient sort than the one that the JDK provides.  And that's quite the point - the standard library has grown and evolved over the years.  The people who've contributed to the Java language have been down this road before.  They've given us the best solution out of the box, and unless we're looking at serious edge cases, the default `sort()` method is going to be the best one to use.\
\
The moral of the story is, I trust my standard library until an edge case proves that I shouldn't. And no, I still can't memorize these and whiteboard them.

Image by [cocoparisienne](https://pixabay.com/users/cocoparisienne-127419) from [Pixabay](https://pixabay.com)
