---
title: "Spark Java \"Flash\" Scope"
slug: ""
author: "Todd Sharp"
date: 2017-04-18
summary: ""
tags: ["Groovy", "Java", "Spark Java"]
keywords: "spark java, flash scope"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/29/banner_57e5d1444855af14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

One of the handiest features of Grails is the ["flash" scope](http://docs.grails.org/3.1.1/ref/Controllers/flash.html).  The flash scope is "A temporary storage map that stores objects within the session for the next request and the next request only, automatically clearing out the objects held there after the next request completes."  It's a handy way to send messages and errors around when dealing with form posts and redirects.  Since I've been working with Spark Java I've found myself missing this little feature so I decided to throw together my own implementation.  I've added the following closure inside of my `main()` method in my `Bootstrap` class:
```groovy
def flash = { request, key=null, value=null ->
    if( !request.session().attribute('flash') ) request.session().attribute('flash', [:])
    if( !key && !value ) {
        return request.session().attribute('flash')
    }
    if( key && value ) {
        request.session().attribute('flash')[key] =  [requests: 1, value: value]
    }
    return request.session().attribute('flash')[key]?.value
}
```



To manage the lifetime of the scope, I've added the following in my `after()` filter.  It limits the lifetime of any flash scoped variable to 2 requests:  
```groovy
flash(req).each{
    it.value.requests++
    if( it.value.requests > 2 ) {
        flash(req).remove(it.key)
    }
}
```



To read from the scope:

`flash(request, 'key')`

To write to it:

`flash(request, 'key', 'value')`

For convenience the write method also returns the value meaning you can do things like this:
```groovy
def model = [
        post: post,
        tags: tags,
        tagIds: tagIds,
        error: flash(req, 'error', Messages.message('default.errors')),
]
```



To return then entire flash scope:\

`flash(request)`\

Image by [Fotoworkshop4You](https://pixabay.com/users/Fotoworkshop4You-2995268) from [Pixabay](https://pixabay.com)
