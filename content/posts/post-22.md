---
title: "Spark Java Views Using Thymeleaf - SiteMesh Like Layouts"
slug: ""
author: "Todd Sharp"
date: 2017-04-06
summary: ""
tags: ["Groovy", "Java", "Spark Java", "Thymeleaf"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/22/banner_57e9d647425bab14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

In the [last post](http://recursive.codes/blog/post/21) we looked at how Thymeleaf handles reusable layouts.  A reddit user enlightened me about an [open source 'dialect'](https://github.com/ultraq/thymeleaf-layout-dialect) for Thymeleaf that makes it behave in a similar manner to SiteMesh.  It's [documented](https://ultraq.github.io/thymeleaf-layout-dialect/) pretty well, but\...

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/clooney.gif)

Yeah, documentation can be boring sometimes, so I thought I'd put together a quick post on how that would look in the Spark Java application I've been working with.  It works well, but it suffers from an inability to pass model variables to the layout template.  That's something that SiteMesh can handle (although in a less-than-elegant manner in my opinion) and in my view it is almost deal breaker.  Something as simple as a nav menu that is common across all pages will ultimately require some dynamic data, and if we're going to need to `th:insert` the fragment on every page, then what are we really gaining by using this style of layout template?  I'll add how I'd think this could be handled at the end of this post, but first let's look at how to implement this dialect in the project.

The first step is to include the dialect, so in `build.gradle`, under `dependencies`, add:\

    compile group: 'nz.net.ultraq.thymeleaf', name: 'thymeleaf-layout-dialect', version: '2.2.1'

Now modify your `Bootstrap.groovy` in the `main()` method to add the dialect.  The rest of the Bootstrap class looks the same as our last post (with the exception of a new/modified route that I've created for this feature called `/thymeleaf-layout`):
```groovy
import nz.net.ultraq.thymeleaf.LayoutDialect
import spark.ModelAndView
import spark.Spark
import spark.template.thymeleaf.ThymeleafTemplateEngine

import static spark.Spark.get

class Bootstrap {
    static void main(String[] args) {
        Spark.staticFileLocation('/static')
        ThymeleafTemplateEngine engine = new ThymeleafTemplateEngine()
        engine.templateEngine.addDialect(new LayoutDialect());

        def commonModel = {
            return [
                    menu : [
                            [name: 'home', route: 'hello', title: 'Hello'],
                            [name: 'goodbye', route: 'goodbye', title: 'Goodbye'],
                            [name: 'thymeleaf', route: 'thymeleaf', title: 'Thymeleaf'],
                            [name: 'javalite', route: 'javalite', title: 'JavaLite'],
                    ]
            ]
        }

        get "/thymeleaf-layout", { req, res ->
            def list = []
            10.times {
                list << [id: it, firstName: "Name $it"]
            }
            def model = [name: 'Todd', list: list]
            return engine.render(new ModelAndView(commonModel() << model, "thymeleaf-layout"))
        }

    }
}
```



Now create the layout itself - similar to how you'd do in SiteMesh:
```html

<!DOCTYPE html>
<html lang="en" xmlns:layout="http://www.ultraq.net.nz/thymeleaf/layout">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
    <meta name="description" content="">
    <meta name="author" content="">

    <title>Starter Template for Bootstrap</title>

    <!-- Bootstrap core CSS -->
    <link href="/assets/bootstrap/css/bootstrap.min.css" rel="stylesheet">

    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <link href="/assets/bootstrap/css/ie10-viewport-bug-workaround.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <link href="/assets/starter-template.css" rel="stylesheet">

</head>

<body>

    <nav class="navbar navbar-inverse navbar-fixed-top">
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
                    <li><a href="#about">About</a></li>
                    <li><a href="#contact">Contact</a></li>
                </ul>
            </div><!--/.nav-collapse -->
        </div>
    </nav>

    <div class="container">

        <div class="starter-template">
            <div layout:fragment="content"></div>
        </div>

    </div><!-- /.container -->

    
    <!-- Bootstrap core JavaScript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <script src="/assets/jquery/jquery-3.2.0.min.js"></script>
    <script src="/assets/bootstrap/js/bootstrap.min.js"></script>
    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/assets/bootstrap/js/ie10-viewport-bug-workaround.js"></script>
</body>
</html>
```



A few items to note in the layout:\

1.  Line 3 - The addition of a `layout` namespace.  The dialect uses it's own namespace instead of the Thymeleaf `th` namespace.
2.  When adding content in the `<head>` element of the 'child' page, by default the 'layout' page `<head>` content will be ***merged***.  This is [configurable](https://ultraq.github.io/thymeleaf-layout-dialect/Configuration.html#head-element-merging).  Any child `<title>` elements will replace the layout `<title>` element, but you can [tweak that behavior](https://ultraq.github.io/thymeleaf-layout-dialect/Examples.html#configuring-your-title) too.
3.  On line 51 we have a `<div layout:fragment="content"></div>`.  This is where what we define in the child layout will end up.  Very SiteMesh-like.

The child page looks like this:
```html
<!DOCTYPE html SYSTEM "http://www.thymeleaf.org/dtd/xhtml1-strict-thymeleaf-4.dtd">
<html xmlns:layout="http://www.ultraq.net.nz/thymeleaf/layout" layout:decorate="~{fragments/main}">

<head>
    <title>Thymeleaf Page</title>
</head>

<body>

    <div layout:fragment="content">
        <p>Hello, <span th:text="${name}"></span></p>
        <ul>
            <li th:each="i, status : ${list}">
                Index: <span th:text="${status.index}"></span>
                ID: <span th:text="${i.id}">id</span>
            </li>
        </ul>
    </div>

</body>
</html>
```



As mentioned above, the `<div layout:fragment="content">` starting on line 10 will be what ends up getting populated in the layout template.  But as I mentioned above, there's no easy way to pass menu content from the child to the layout (that I've found).  Technically, this works in the layout:
```html
<nav class="navbar navbar-inverse navbar-fixed-top">
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
                <li th:each="i : ${menu}"><a th:href="@{${i.route}}"><span th:text="${i.title}"></span></a></li>
            </ul>
        </div>
    </div>
</nav>
```



But that depends on the 'menu' variable to be in the model on every single page.  I'd normally make sure it was, but something about that approach just feels **dirty** to me.  I'd much rather pass the variable from the child to the layout in some manner ([here](https://community.oracle.com/blogs/zarar/2006/01/19/passing-arbitrary-data-between-jsp-pages-and-sitemesh-decorators) is how SiteMesh handles it).  Even that approach feels a little wonky to me, which is why I think I prefer the approach used in my last post, but perhaps I'm missing a feature of this dialect.

Image by [mbll](https://pixabay.com/users/mbll-4127310) from [Pixabay](https://pixabay.com)
