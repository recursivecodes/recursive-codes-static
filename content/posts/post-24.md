---
title: "Thymeleaf - Passing Variables From Child To Layout"
slug: ""
author: "Todd Sharp"
date: 2017-04-06
summary: ""
tags: ["Groovy", "Spark Java", "Thymeleaf"]
keywords: "thymeleaf,spark java, groovy, pass variables from child to parent in layout"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24/banner_54e1dc4a4d50b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

Just a quick update after my [last post](http://recursive.codes/blog/post/22) to clarify things a bit.  I mentioned in that post my dismay regarding the inability to pass model variables from the child view to the parent layout - and I shared that concern with the dialect developer [Emanuel](https://twitter.com/u1traq?lang=en) on GitHub.  He quickly wrote back to clarify that it is indeed possible:

> Hi Todd! First of all, nice blog - I came across it the other day when you wrote about using Thymeleaf w/ Spark \
>
> Anyway, as for passing values from child templates up to their parent layouts, it's possible using Thymeleaf's `th:with` attribute processors on any element that's involved in the layout/decoration process, which would be anywhere `layout:decorate` or `layout:fragment` will be found. eg:
>
> Child/content template:\
>
>     <html layout:decorate="your-layout.html" th:with="greeting='Hello!'">
>
> ::: 
> :::
>
> Parent/layout template:\
>
>     <html>
>       ...
>       <p th:with="$"></p> <!-- You'll end up with "Hello!" in here -->
>
> ::: 
> :::
>
> Now, I don't seem to have documented this anywhere, and as someone who takes some pride in writing good docs, I feel a little bad that I've missed this! I *swear* I used to have it somewhere because others have come to me whenever this feature is broken/missing or they couldn't get it to work.

Of course I had to quickly test this out back in my Spark Java application, so I went back to the `thymeleaf-layout.html` view and modified it to pass the menu variable from my model into the layout:

    <html xmlns:layout="http://www.ultraq.net.nz/thymeleaf/layout"
          layout:decorate="~" th:with="nav=$">

Here I'm declaring that in the parent layout there should be a variable called `nav` that contains the value of `menu` from my model.  Now in the layout file (main.html) I can reference the `nav` variable to create my menu:

    <ul class="nav navbar-nav">
        <li th:each="i : $"><a th:href="@}"><span th:text="$"></span></a></li>
    </ul>

And I'm in business!  It's great to see an open source developer so responsive and concerned with proper documentation.  Thymeleaf definitely has potential.\
\

Image by [Larisa-K](https://pixabay.com/users/Larisa-K-1107275) from [Pixabay](https://pixabay.com)
