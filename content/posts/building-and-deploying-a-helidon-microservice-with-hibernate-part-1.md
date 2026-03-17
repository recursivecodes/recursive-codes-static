---
title: "Building And Deploying A Helidon Microservice With Hibernate Part 1"
slug: "building-and-deploying-a-helidon-microservice-with-hibernate-part-1"
author: "Todd Sharp"
date: 2019-07-03
summary: "In this post we'll build and deploy our first cloud native microservice using Helidon."
tags: ["Cloud", "Containers, Microservices, APIs", "Developers"]
keywords: "microservices, Kubernetes, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/106b0ebc-e062-4876-90f8-e544f4fb1d3f/banner_joshua_earle_dwheufds6kq_unsplash.jpg"
---

In the last few posts of our microservice journey we [created a compartment, launched a Kubernetes cluster and set our tenancy up for a Docker](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud) user and registry and [created an Autonomous DB instance](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud) that we can use for data persistence. In this post we will start to take a look at writing some actual microservice code. I want to reiterate that each application has unique requirements that should be evaluated before you choose to implement any solution and so the choices that I make in this blog series might be different than the choices your organization will make. The important questions to ask yourself are:

- Are microservices the right tool for the job?
- Will this solve my problems in a maintainable way?
- Can our budget afford the cost of implementing this solution?

These are important questions to ask yourself, because introducing a new way of thinking can bring up issues that are difficult to resolve later on.

## Microservice Patterns

Before we dive into the code, let's start by defining a few patterns for microservice data management. The easiest patterns to digest when it comes to microservices are the shared database and database (or schema) per service patterns so let's start with those patterns.

## Shared Database

In monoliths, our data is usually stored in a single relational database. This made life easy when it came to persistence and querying -- we could write queries that utilized joins and we could use ACID transactions to enforce data consistency. The shared database microservice pattern states that a single database is shared by multiple services which can freely query across tables using joins to retrieve data and utilize transactions to modify data in a reliable way that enforces consistency. That makes this pattern less difficult to comprehend for new developers, however it introduces challenges as our API becomes more complex. Schema changes now have to be coordinated with developers of other services because adding columns, changing default values and other operations could potentially break services that might access that same table. Also, long running transactions have the potential to block other services by holding locks on shared tables. Lastly, this pattern assumes that all services will persist their data in a traditional relational table and eliminates the possibility of utilizing NoSQL documents or Graph DB's for persistence (there are workarounds here, which we'll see a bit later on).

## Database (or Schema) Per Service

The database (or schema) per service pattern addresses some of the shortcomings of the shared database pattern. Each service gets its own database which essentially means the database is part of the implementation of that service. Schema changes now won't impact other services. This doesn't necessarily have to result in a database server for each service. Often times it can be represented by individual tables per service (as long as there are users and permissions bound to each table which restrict access by other services), or even as a unique schema within a database instance for each service. Using database per service means that each service is free to use the type of database that is best suited to their needs.  Of course, there are some downsides to this pattern. Transactions are now difficult to manage. Referential integrity can't be enforced as easily. Queries that join data can be difficult, if not impossible.

## Enough Already, Show Me The Code!

I've done a lot of talking so far in this series about what microservices are and why you might use them, but it's always best to look at code to understand these theories so let's finally do that. For this series, we'll build out an API for a simple social media style application in several parts. This gives us the opportunity to utilize some different microservice patterns as well as various features in the cloud and should present some interesting problems that we'll need to address.

## Building A User Service

### Description

This service utilizes [Helidon MP](https://helidon.io) with Hibernate to persist users to a `user` table in an Oracle ATP instance. To get started, we can utilize the Heldon Maven archetype which will scaffold out some files and structure for our service. Here's the command (you can modify the path to your liking, or leave it as is):
```bash
mvn archetype:generate -DinteractiveMode=false \
    -DarchetypeGroupId=io.helidon.archetypes \
    -DarchetypeArtifactId=helidon-quickstart-mp \
    -DarchetypeVersion=1.1.1 \
    -DgroupId=codes.recursive \
    -DartifactId=user-svc \
    -Dpackage=codes.recursive.cnms.user
```



Before we modify or look at the generated code, let's create our schema user for this microservice. You'll need to connect to your running ATP instance as admin to run the next query. Using [SQL Developer Web as shown in the last post in this series](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud) would be an easy way to run it. Once you're ready, run the following (making sure to modify the password to something strong):
```sql
CREATE USER usersvc IDENTIFIED BY "STRONGPASSW0RD";
GRANT CONNECT, RESOURCE TO usersvc;
GRANT UNLIMITED TABLESPACE TO usersvc;
```



If you're using SQL Developer Web, you'll need to ensure that the admin user enables each schema that you would like to use with the following command:
```sql
BEGIN
 ords_admin.enable_schema(
  p_enabled => TRUE,
  p_schema => 'SCHEMA-NAME',
  p_url_mapping_type => 'BASE_PATH',
  p_url_mapping_pattern => 'schema-alias',
  p_auto_rest_auth => NULL
 );
 commit;
END;
```



For the command above, the placeholder values should be substituted as follows:

- `SCHEMA-NAME` is the database schema name in all-uppercase.
- `schema-alias` is an alias for the schema name that will appear in the URL the user will use to access SQL Developer Web. Oracle recommends that you do not use the schema name itself as a security measure to keep the schema name from being exposed.

After enabling user access, the ADMIN user needs to provide the enabled user with their URL to access SQL Developer Web. This URL is the same as the URL the ADMIN user enters to access SQL Developer Web, but with the `admin/` segment of the URL replaced by `schema-alias/`.

From here on out, we'll use the `usersvc` user, so log out of SQL Developer Web (or whatever tool you're using) and log in with the new username and password that we just created at the proper URL per the instructions above. Once logged in with the `usersvc` user, run the following to create a table for the microservice:

<div>
```sql
CREATE TABLE users(
  "ID" VARCHAR2(32 BYTE) DEFAULT ON NULL SYS_GUID(), 
  "FIRST_NAME" VARCHAR2(50 BYTE) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "LAST_NAME" VARCHAR2(50 BYTE) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "USERNAME" VARCHAR2(50 BYTE) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "CREATED_ON" TIMESTAMP (6) DEFAULT ON NULL CURRENT_TIMESTAMP, 
  CONSTRAINT "USER_PK" PRIMARY KEY ("ID")
);
```



</div>

Next, we'll need to grab some dependencies. Create a folder called `/build-resource` in the root of the project and add a subdirectory called `/libs`. We'll need to grab the following JAR files so that our project can use the OJDBC driver to talk to our ATP instance:

- ojdbc8.jar
- oraclepki.jar
- osdt_cert.jar
- osdt_core.jar

[Download the JARs from Oracle](https://www.oracle.com/technetwork/database/application-development/jdbc/downloads/index.html) and place them in `/build-resource/libs`.  We also need to publish these to our local Maven repo so that when we run the application locally they'll be properly resolved. The following commands should help you out with that:
```bash
mvn install:install-file -Dfile=/path/to/ojdbc8.jar -DgroupId=com.oracle.jdbc -DartifactId=ojdbc8 -Dversion=18.3.0.0 -Dpackaging=jar
mvn install:install-file -Dfile=/path/to/oraclepki.jar -DgroupId=com.oracle.jdbc -DartifactId=oraclepki -Dversion=18.3.0.0 -Dpackaging=jar
mvn install:install-file -Dfile=/path/to/osdt_core.jar -DgroupId=com.oracle.jdbc -DartifactId=osdt_core -Dversion=18.3.0.0 -Dpackaging=jar
mvn install:install-file -Dfile=/path/to/osdt_cert.jar -DgroupId=com.oracle.jdbc -DartifactId=osdt_cert -Dversion=18.3.0.0 -Dpackaging=jar
```



Next, modify your pom.xml file to include all of the necessary dependencies for JPA, Hibernate, Jackson and the OJDBC JARs.  Add the following entries to the dependencies section:
```xml
<dependency>
    <groupId>org.eclipse.persistence</groupId>
    <artifactId>javax.persistence</artifactId>
    <version>2.2.0</version>
</dependency>
<dependency>
    <groupId>org.hibernate</groupId>
    <artifactId>hibernate-entitymanager</artifactId>
    <version>5.4.3.Final</version>
</dependency>
<dependency>
    <groupId>org.hibernate</groupId>
    <artifactId>hibernate-validator</artifactId>
    <version>5.4.3.Final</version>
</dependency>
<dependency>
    <groupId>javax.el</groupId>
    <artifactId>el-api</artifactId>
    <version>2.2</version>
</dependency>
<dependency>
    <groupId>org.glassfish.web</groupId>
    <artifactId>javax.el</artifactId>
    <version>RELEASE</version>
</dependency>
<dependency>
    <groupId>com.oracle.jdbc</groupId>
    <artifactId>ojdbc8</artifactId>
    <version>18.3.0.0</version>
</dependency>
<dependency>
    <groupId>com.oracle.jdbc</groupId>
    <artifactId>oraclepki</artifactId>
    <version>18.3.0.0</version>
</dependency>
<dependency>
    <groupId>com.oracle.jdbc</groupId>
    <artifactId>osdt_core</artifactId>
    <version>18.3.0.0</version>
</dependency>
<dependency>
    <groupId>com.oracle.jdbc</groupId>
    <artifactId>osdt_cert</artifactId>
    <version>18.3.0.0</version>
</dependency>
<dependency>
    <groupId>org.glassfish.jersey.media</groupId>
    <artifactId>jersey-media-json-jackson</artifactId>
    <version>2.28</version>
</dependency>
```



We'll need to add a Hibernate persistence config, so create a file under `/src/main/resources/META-INF` called `persistence.xml` and populate it like so:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<persistence xmlns="http://java.sun.com/xml/ns/persistence"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://java.sun.com/xml/ns/persistence
             http://java.sun.com/xml/ns/persistence/persistence_2_0.xsd"
             version="2.0">

    <persistence-unit name="UserPU">
        <provider>org.hibernate.jpa.HibernatePersistenceProvider</provider>
        <properties>
            <property name="hibernate.connection.driver_class" value="oracle.jdbc.OracleDriver" />
            <property name="hibernate.archive.autodetection" value="class" />
            <property name="hibernate.show_sql" value="true" />
            <property name="hibernate.dialect" value="org.hibernate.dialect.Oracle12cDialect" />
            <property name="hibernate.format_sql" value="true" />
            <property name="hbm2ddl.auto" value="validate" />
        </properties>
    </persistence-unit>
</persistence>
```



While you're in that directory, modify `microprofile-config.properties` like so:
```properties
# Application properties.
datasource.username=
datasource.password=
datasource.url=

# Microprofile server properties
server.port=8080
server.host=0.0.0.0
```



Now that we have all of our prerequisite configuration complete we can move on to the application code.  Locate the generated `GreetApplication.java` file. You can either modify it, or delete it and replace it with a new file, but ultimately we want to end up with a `UserApplication.java` that contains the following code:
```java
package codes.recursive.cnms.user;

import java.util.Set;

import javax.enterprise.context.ApplicationScoped;
import javax.ws.rs.ApplicationPath;
import javax.ws.rs.core.Application;

import io.helidon.common.CollectionsHelper;
import org.glassfish.jersey.jackson.JacksonFeature;

/**
 * Simple Application that managers users.
 */
@ApplicationScoped
@ApplicationPath("/")
public class UserApplication extends Application {

    @Override
    public Set<Class<?>> getClasses() {
        return CollectionsHelper.setOf(
                UserResource.class,
                JacksonFeature.class
        );
    }

}
```



Use the same process (modify or replace) for `GreetingProvider` to end up with a `UserProvider` that looks like so:
```java
package codes.recursive.cnms.user;

import java.util.concurrent.atomic.AtomicReference;

import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;

import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Provider for user config.
 */
@ApplicationScoped
public class UserProvider {
    private final AtomicReference<String> dbUser = new AtomicReference<>();
    private final AtomicReference<String> dbPassword = new AtomicReference<>();
    private final AtomicReference<String> dbUrl = new AtomicReference<>();

    /**
     * Create a new user provider, reading the message from configuration.
     *
     * @param dbUser
     * @param dbPassword
     * @param dbUrl
     */
    @Inject
    public UserProvider(
            @ConfigProperty(name = "datasource.username") String dbUser,
            @ConfigProperty(name = "datasource.password") String dbPassword,
            @ConfigProperty(name = "datasource.url") String dbUrl
    ) {
        this.dbUser.set(dbUser);
        this.dbPassword.set(dbPassword);
        this.dbUrl.set(dbUrl);
    }

    String getDbUser() { return dbUser.get(); }
    String getDbPassword() { return dbPassword.get(); }
    String getDbUrl() { return dbUrl.get(); }

    void setDbUser(String dbUser) { this.dbUser.set(dbUser); }
    void setDbPassword(String dbPassword) { this.dbPassword.set(dbPassword); }
    void setDbUrl(String dbUrl) { this.dbUrl.set(dbUrl); }
}
```



The `UserProvider` class will contain our populated configuration values when we run the application. At this point, we're ready to start writing the real logic of our microservice. In the next post in this series we'll take a deep dive into that code and get our service running and deployed on the Oracle Cloud.

[Photo by ][Joshua Earle](https://unsplash.com/@joshuaearle?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/man-cloud?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
