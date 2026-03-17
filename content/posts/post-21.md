---
title: "Spark Java Views Using Thymeleaf - Layouts"
slug: ""
author: "Todd Sharp"
date: 2017-04-05
summary: ""
tags: ["Groovy", "Java", "Spark Java", "Thymeleaf"]
keywords: "spark java, thymeleaf, groovy, layouts, template engine"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/21/banner_52e0d2414f50b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

In the [last post](http://recursive.codes/blog/post/19) we looked at plugging in Thymeleaf into a Spark Java application for view rendering.  The concept was pretty simple: using the Thymeleaf engine, render a view with a map of variables to use as the model.  But in reality, our applications need a bit more complexity.  They need reusable layouts.  In this post we'll take a look at how to handle that with Thymeleaf.  

Reusable layouts include things like headers, footers, scripts and other things like nav menus that are common across the application.  Thymeleaf accommodates these by using what they call "fragments" - reusable blocks of code defined by the `th:fragment` attribute that can be called from your templates using the `th:replace`, `th:insert` or `th:include` attributes.  You can read all about it in their [docs](http://www.thymeleaf.org/doc/tutorials/3.0/usingthymeleaf.html#template-layout), but let's take a look at a practical example below.

To illustrate, let's create three separate fragments, one called `head.html`, one called `nav.html` and the final one called `foot.html`.  I've saved these in `/src/main/groovy/resources/templates/fragments`.  To make it more realistic, I've dropped in Bootstrap since that's what I'd usually do.  Here is the simple code for each:
```html
<!DOCTYPE html>

<html xmlns:th="http://www.thymeleaf.org">

<head th:fragment="head(title)">
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">

    <title th:replace="${title}">Spark Playground</title>

    <!-- Bootstrap core CSS -->
    <link href="/assets/bootstrap/css/bootstrap.min.css" rel="stylesheet">

    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <link href="/assets/bootstrap/css/ie10-viewport-bug-workaround.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <link href="/assets/starter-template.css" rel="stylesheet">

</head>
<body>
</body>

</html>
```
```html
<!DOCTYPE html>

<html xmlns:th="http://www.thymeleaf.org">

<body>
<nav th:fragment="nav(m)" class="navbar navbar-inverse navbar-fixed-top">
    <div class="container">
        <div class="navbar-header">
            <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="false" aria-controls="navbar">
                <span class="sr-only">Toggle navigation</span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
            </button>
            <a class="navbar-brand" href="#">Project name</a>
        </div>
        <div id="navbar" class="collapse navbar-collapse">
            <ul class="nav navbar-nav">
                <li class="active"><a href="#">Home</a></li>
                <li th:each="i : ${m}"><a th:href="@{${i.route}}"><span th:text="${i.title}"></span></a></li>
            </ul>
        </div>
    </div>
</nav>
</body>

</html>
```
```html
<!DOCTYPE html>

<html xmlns:th="http://www.thymeleaf.org">

<body>

<div th:fragment="foot()">
    <!-- Bootstrap core JavaScript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <script src="/assets/jquery/jquery-3.2.0.min.js"></script>
    <script src="/assets/bootstrap/js/bootstrap.min.js"></script>
    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/assets/bootstrap/js/ie10-viewport-bug-workaround.js"></script>
</div>
</body>

</html>
```



Now back in our Bootstrap class, in the main() method, I've created a Groovy closure to grab any 'common' model bits:
```groovy
def commonModel = {
    return [
            menu : [
                    [name: 'home', route: 'hello', title: 'Hello'],
                    [name: 'goodbye', route: 'goodbye', title: 'Goodbye'],
                    [name: 'thymeleaf', route: 'thymeleaf', title: 'Thymeleaf'],
            ]
    ]
}
```



Then I modified the route for `/thymeleaf` to include the `commonModel` in the model I'm using to render that view:
```groovy
get "/thymeleaf", { req, res ->
    def list = []
    10.times {
        list << [id: it, firstName: "Name $it"]
    }
    def model = [name: 'Todd', list: list]
    return engine.render(new ModelAndView(commonModel() << model, "thymeleaf"))
}
```



And now it's just a matter of using the `th:replace` attribute in my view wherever I'd like the fragments rendered:
```html
<!DOCTYPE html SYSTEM "http://www.thymeleaf.org/dtd/xhtml1-strict-thymeleaf-4.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:th="http://www.thymeleaf.org">

<head th:replace="fragments/head :: head(~{::title})">
    <title>Thymeleaf Page</title>
</head>

<body>

<div th:replace="fragments/nav :: nav(${menu})"></div>

<div class="container">
    <div class="starter-template">
        <p>Hello, <span th:text="${name}"></span></p>
        <ul>
            <li th:each="i, status : ${list}">
                Index: <span th:text="${status.index}"></span>
                ID: <span th:text="${i.id}">id</span>
            </li>
        </ul>
    </div>
</div>

<div th:replace="fragments/foot :: foot()"></div>
</body>
</html>
```



Note that since my fragments were not in the `/templates` directory, but a subdirectory called 'fragments', I had to pass the path from `/templates` in the `th:replace` attribute.  Also notice that you can pass model variables to your fragment as I did on line 10.  This is crucial for any layout system as layout bits are rarely purely static.  \
\
Compared to Sitemesh (which is what I'm used to in Grails) I think I'm a fan of the way Thymeleaf handles this.  Something about Sitemesh always felt a little "backwards" (the layout includes the view) so I'm happy to see Thymeleaf approach it in a more "forward" manner (the view includes the layout bits).

Image by [SplitShire](https://pixabay.com/users/SplitShire-364019) from [Pixabay](https://pixabay.com)
