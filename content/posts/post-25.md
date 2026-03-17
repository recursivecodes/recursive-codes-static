---
title: "JavaLite ActiveJDBC For ORM In Spark Java"
slug: ""
author: "Todd Sharp"
date: 2017-04-07
summary: "I've spent a lot of time on the blog lately talking about views in Spark Java applications.  Rightfully so, as Views are the Turkey in any MVC sandwich (look at it...it's right there in the middle!!).  Spark Java provides the crusty Controller slice of bread via routes in our Bootstrap class.  So the only thing left is to take a look at the other slice - the Model."
tags: ["ActiveJDBC", "Groovy", "Java", "JavaLite", "Spark Java"]
keywords: "spark java ORM, javalite, activejdbc, groovy, lightweight ORM"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/25/banner_54e2dc464e51a814f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

I've spent a lot of time on the blog lately talking about views in Spark Java applications.  Rightfully so, as *Views* are the Turkey in any *MVC* sandwich (look at it\...it's right there in the middle!!).  Spark Java provides the crusty *Controller* slice of bread via routes in our Bootstrap class.  So the only thing left is to take a look at the other slice of bread - the *Model*.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/sudo-sandwich.png)

Instead of going with most Java developer's first instinct, *Hibernate* (for the record, I'm a huge fan), I decided to find a lightweight alternative.  Spark Java is all about lightweight, so I found it only fitting to dip my toes into the pool and find something other than Hibernate.  Enter [ActiveJDBC from JavaLite](http://javalite.io/documentation).  

I've only just begun looking at it, but it was pretty easy to get started with my Spark Java application.  Step 1, as usual, is to declare our dependencies:\
```groovy
compile group: 'mysql', name: 'mysql-connector-java', version: '5.1.36'
compile group: 'org.javalite', name: 'activejdbc', version: '1.4.13'
compile group: 'org.javalite', name: 'activejdbc-instrumentation', version: '1.4.13'
```



ActiveJDBC uses 'instrumentation' to manipulate our POJO domain classes (POGOs in my case) to make things like `Domain.where()` possible.  Those familiar with GORM may know that Grails uses metaprogramming to do this - but with ActiveJDBC it's accomplished with instrumentation.  The Gradle instrumentation plugin (added to `build.gradle` with `apply plugin: 'org.javalite.activejdbc'`) handles this automatically for us, so include that plugin and pretend like you don't even know it's happening during your builds.

I've chosen to use MySQL, so I've created a schema locally called `sparkplayground`.  Next step is to jump over to our `Bootstrap` class, inside the `main()` method, to do a bit of configuration.  Spark Java gives us a `before()` and `after()` methods to perform actions\... honestly\...is there any way to finish this sentence without being redundant?  So, we need to establish our [DB connection](http://javalite.io/database_connection_management).  In my simple example, I'll open the connection in the `before()` method and close it in the `after()`, passing credentials inline - but typical applications will handle credentials via a property file (see [documentation](http://javalite.io/database_connection_management#multiple-environments-property-file-method)).  Here's how those look:
```groovy
before "/*", { req, res ->
    Base.open("com.mysql.jdbc.Driver", "jdbc:mysql://localhost:3306/sparkplayground?serverTimezone=EST&useSSL=false&nullNamePatternMatchesAll=true", "user", "password");
}

after "/*", { req, res ->
    Base.close()
}
```



Now how about a domain class that ActiveJDBC will recognize:
```groovy
package codes.recursive.domain

import org.javalite.activejdbc.Model
import org.javalite.activejdbc.annotations.Table

@Table("users")
class User extends Model {}
```



Why no properties?  Well, ActiveJDBC infers DB schema parameters from a database. This means you do not have to provide it in code.  At first that bothered me.  It still kinda bothers me, but, it is what it is.  It does mean that our DB columns dictate our property names on the class.  Also, there's no direct access to the properties via getters (or implicit getters in the case of Groovy). You can, however, use [wrappers](http://javalite.io/setters_and_getters) (which seems like a perfect use case for missing method metaprogramming in Groovy - but that's another blog post perhaps).  I don't think it's a deal breaker for me, just a new paradigm to live with if I chose to move forward with using ActiveJDBC.  And what would programming be without differing APIs between all the frameworks we use? 

Anyhow, here's the DDL statement that I used to create the table:\
```sql
create table users (
      id int NOT NULL auto_increment,
      firstName VARCHAR(56),
      lastName VARCHAR(56),
      PRIMARY KEY (id)
);
```



{{< callout >}}
Note:  JavaLite has a Maven plugin to handle DB migrations creatively named [DB migrator](http://javalite.io/database_migrations).
{{< /callout >}}
Now that our domain is modeled, let's look at some CRUD and retrieval.  I created a new route for the application called `/javalite`.
```groovy
get "/javalite", { req, res ->
    def model = [:]

    // create a new user
    User u = new User()
    u.fromMap([firstName: 'Todd', lastName: 'Sharp'])
    u.saveIt()
            
    def users = User.findAll()
    model << [users: users.collect { it.attributes }]
    
    return engine.render(new ModelAndView(commonModel() << model, "javalite"))
}
```



To persist a new `User` I create a new instance of the `User` domain class and populate it.  I could use the `put(property, value)` method, but I prefer passing a map to the `fromMap()` method.  After I save the user with the `saveIt()` method, I retrieve a list of users with `User.findAll()`.  This gets us a `List` of `User` objects.  For ease of use in my model, I `collect` that list (triggering the query to execute), grabbing the '`attributes`' to get a `List` of `Map`s containing all the `User` properties.  Once into the view, I dump the result into a table:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/javalite.jpg)

And that's basic CRUD and retrieval with ActiveJDBC in a Spark Java application.\
\
To summarize - there are a few things that seem odd from someone used to working with Hibernate.  There is no concept of sessions like with Hibernate, so queries aren't run until the data is accessed.  All the usual ORM features seem to be there.  Validation, pagination, relationships, transactions, polymorphic associations - all available.  It's a framework worth a further look.

Image by [JillWellington](https://pixabay.com/users/JillWellington-334088) from [Pixabay](https://pixabay.com)
