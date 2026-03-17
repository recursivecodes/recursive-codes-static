---
title: "Spark Java Views With Apache FreeMarker"
slug: ""
author: "Todd Sharp"
date: 2017-04-07
summary: "In the last few posts I took a look at using Thymeleaf for view rendering and templating with Spark Java.  Thymeleaf has it's advantages and disadvantages, but I could see using it in an application without suffering too much grief and having it actually be enjoyable to work with.  I thought I'd take a look at another option for views in Spark Java:  Apache FreeMarker has been around a looooongggg time - since 1999.  Amazingly, it's still under active development (the most recent release was 3/2"
tags: ["Apache FreeMarker", "Groovy", "Java", "Spark Java"]
keywords: "spark java, freemarker, apache freemarker,templating,layout"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/23/banner_55e0d7424a55ae14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

In the [last](http://recursive.codes/blog/post/20) [few](http://recursive.codes/blog/post/21) [posts](http://recursive.codes/blog/post/22) I took a look at using Thymeleaf for view rendering and templating with Spark Java.  Thymeleaf has it's advantages and disadvantages, but I could see using it in an application without suffering too much grief and having it actually be enjoyable to work with.  I thought I'd take a look at another option for views in Spark Java:  Apache FreeMarker. FreeMarker has been around a looooongggg time - since 1999.  Amazingly, it's still under active development (the most recent release was 3/25/17).  Needless to say - it's not legacy, it's aged like a fine wine.\
\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/wine-is-a-solution.jpg)

So can it handle view rendering and templating as well as Thymeleaf?  Let's give it a shot.  As with everything, we need to declare our dependency (no, we're not still talking about wine here):

    compile group: 'com.sparkjava', name: 'spark-template-freemarker', version: '2.5.5'

Next we'll add a new route in the `Broadcast` class just as before:
```groovy
get "/freemarker", { req, res ->
    def list = []
    10.times {
        list << [id: it, firstName: "Name $it"]
    }
    def model = [name: 'Todd', list: list]
    return new FreeMarkerEngine().render(new ModelAndView(commonModel() << model, "freemarker.ftl"))
}
```



Our view files with FreeMarker go in `src/main/groovy/resources/spark/template/freemarker`.  Let's look at a SiteMesh equivalent example since that's what we looked at last with Thymeleaf.  FreeMarker calls their layout templates "macros", so let's create a simple layout template that we'll then apply to our child view.
```ftl
<#macro mainLayout title="Freemarker Layout Template" menu="">

    <!DOCTYPE html>
    <html lang="en" xmlns:layout="http://www.ultraq.net.nz/thymeleaf/layout">
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
        <meta name="description" content="">
        <meta name="author" content="">

        <title>${title}</title>

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
                    <#list menu as i>
                        <li><a href="${i.route}">${i.title}</a></li>
                    </#list>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container">

        <div class="starter-template">
            <#nested/>
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

</#macro>
```



A few things worth nothing with the macro file above.  Starting with line 1:

    <#macro mainLayout title="Freemarker Layout Template" menu="">

The first attribute - `mainLayout` - is how we'll later refer to this macro from the child view.  The second and third attributes - `title` and `menu` - are variables we can pass in from the child.  Title has a default of "Freemarker Layout Template" which will be initialized if nothing is received from the child, and menu has an empty default (it'll be null if empty).

These attributes are now available for our use using the familiar `$` notation.  See line 13, for example, where we use the `$` attribute and line 42-44 where we loop over the `menu` List element to create a dynamic menu with a list passed from the model in the child view.  This is the type of functionality that I'd like to see in Thymeleaf - simple passing of model variables from the child to the layout for dynamic bits.  \

The last item worth mentioning is on line 53:  the `<#nested/>` tag.  This will be replaced with the contents from the child caller.  Speaking of children:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/mom-drinks-wine.jpg)

Ugh\...sorry.  The child template:
```ftl
<#import "main.ftl" as layout />
<@layout.mainLayout "Freemarker Child Page" menu>
    <p>Hello, ${name}</p>
    <ul>
        <#list list as item>
            <li>Index: ${item?index} ID: ${item.id}</li>
        </#list>
    </ul>
</@layout.mainLayout>
```



The child simply imports and applies the layout - passing variables as needed.  Again, any model values can be rendered using the `$` token format.  And that's it, dynamic content in a reusable format.  It doesn't stop there though - like Thymeleaf there is an entire framework available for use.  Directives, expressions, interpolations - formatting (dates, numbers, booleans, etc), conditionals (if/else, switch/case) - anything you could possibly need inside a view is available.  My only gripe is the lack of IDE support with IntelliJ IDEA Community Edition, but that's yet another reason why I need to shell out for a license.\
\

Image by [Julius_Silver](https://pixabay.com/users/Julius_Silver-4371822) from [Pixabay](https://pixabay.com)
