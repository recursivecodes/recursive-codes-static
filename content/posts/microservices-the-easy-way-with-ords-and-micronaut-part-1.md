---
title: "Microservices The Easy Way With ORDS And Micronaut - Part 1"
slug: "microservices-the-easy-way-with-ords-and-micronaut-part-1"
author: "Todd Sharp"
date: 2019-07-15
summary: "In this post we'll look at a different approach to writing microservices that doesn't involve any SQL in your application."
tags: ["Cloud", "Containers, Microservices, APIs", "Java"]
keywords: "microservices, Java, container, Kubernetes"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/banner_shiro_hatori_wr_ifjfy4ci_unsplash.jpg"
---

What if I told you you could write a microservice that doesn't use ORM without a single SQL statement in your application code? 

I have to admit, I've been pretty excited to write this next few posts in this microservice blog series. It's not that I haven't been excited about the content so far - I have - but, the next approach that I'll be sharing I fully believe is quite different than any approach being used today. I believe it has great potential to make your microservices very easy to write, manage and deploy and it involves very little SQL code at all (and none in the application itself). To change things up, we're going to use [Micronaut](https://micronaut.io) instead of [Helidon](https://helidon.io). You'll see later on what makes Micronaut a perfect choice for this approach.

If you are new to this blog series, you may want to catch up on some of the previous posts before we dig into the next topic. Here is what we have looked at so far:

- [Intro](/posts/microservices-are-easy "https://blogs.oracle.com/developers/microservices-are-easy")
- [Getting Started With Kubernetes And Docker](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud "https://blogs.oracle.com/developers/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud")
- [Getting Started With Autonomous DB](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud "https://blogs.oracle.com/developers/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud")
- [Building A Helidon Microservice Part 1](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-1)
- [Building A Helidon Microservice Part 2](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-2)
- [Building A Helidon Microservice Part 3](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-3)

At the very least, make sure you've got a Kubernetes cluster, Docker registry and ATP instance ready to go. 

## Intro To ORDS

OK, let's dig in! For this part of the series we're going to utilize something called Oracle REST Data Services (ORDS) to expose our SQL table with secured REST endpoints that can be used to read and write to and from that table. Much has been written about ORDS and it is not a new product, but the ability to utilize ORDS on an Autonomous DB instance is new. If you're looking for a deep dive on ORDS then I highly suggest you check out Jeff Smith's blog as he has a great deal of content on the product including a [complete intro and overview of ORDS on Autonomous DB](https://www.thatjeffsmith.com/archive/2019/06/rest-services-now-available-for-oracle-autonomous-database/). Don't worry, I'll cover some of the same material here that Jeff covers, but it will be more focused on our specific application that we're going to create. 

We're going to recreate the same service - a simple user service - that we created in the Helidon part of this series, but this one will utilize ORDS instead of Hibernate for persistence. To get started, open up SQL Developer Web ([instructions here](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud)) so we can create and configure everything. Right, let's get to it then.

The first thing we need to do here is create our database schema/user. You may have already done so if you've followed the Helidon posts, and if so please note that you'll need two additional `GRANT` statements (`CONNECT` and `RESOURCE`) for this approach.
```sql
CREATE USER usersvc IDENTIFIED BY "STRONGPASSWORD";
GRANT CONNECT, RESOURCE TO usersvc;
GRANT UNLIMITED TABLESPACE TO usersvc;
```



Now we'll create the table. Again, you may have done this already if you followed the previous series of posts. If so, drop that table and re-create it with the following DDL as it is slightly different (but won't negatively affect your previous microservice other than wiping the data you may have already persisted).
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



Now we need to REST enable both the schema and the `users` table. We can do that with the following:
```sql
BEGIN
    /* enable ORDS for schema */
    ORDS.ENABLE_SCHEMA(p_enabled => TRUE,
                       p_schema => 'USERSVC',
                       p_url_mapping_type => 'BASE_PATH',
                       p_url_mapping_pattern => 'usersvc',
                       p_auto_rest_auth => FALSE);
     /* enable ORDS for table */         
    ORDS.ENABLE_OBJECT(p_enabled => TRUE,
                       p_schema => 'USERSVC',
                       p_object => 'USERS',
                       p_object_type => 'TABLE',
                       p_object_alias => 'users',
                       p_auto_rest_auth => FALSE);
    COMMIT;
END;
```



**Note**: The argument `p_auto_rest_auth` being set to `FALSE` means that all unauthenticated requests will return a `401 Unauthorized` meaning we'll have to send credentials with each REST call. Let's create some privileges and register a client so that we can obtain the necessary credentials:
```sql
DECLARE
 l_roles     OWA.VC_ARR;
 l_modules   OWA.VC_ARR;
 l_patterns  OWA.VC_ARR;
BEGIN
 l_roles(1)   := 'SQL Developer';
 l_patterns(1) := '/users/*';
 ORDS.DEFINE_PRIVILEGE(
     p_privilege_name => 'rest_privilege',
     p_roles          => l_roles,
     p_patterns       => l_patterns,
     p_modules        => l_modules,
     p_label          => '',
     p_description    => '',
     p_comments       => NULL);
 COMMIT;

END;
```



Next, create an oauth client associated with the privilege:
```sql
BEGIN
  OAUTH.create_client(
    p_name            => '[Descriptive Name For Client]',
    p_grant_type      => 'client_credentials',
    p_owner           => '[Owner Name]',
    p_description     => '[Client Description]',
    p_support_email   => '[Email Address]',
    p_privilege_names => 'rest_privilege'
  );

  COMMIT;
END
```



Grant the `SQL Developer` role to the client application:
```sql
BEGIN
  OAUTH.grant_client_role(
    p_client_name => 'Rest Client',
    p_role_name   => 'SQL Developer'
  );
  
  COMMIT;
END;
```



You can now grab the `client_id` and `client_secret` with:
```sql
SELECT id, name, client_id, client_secret
FROM   user_ords_clients;
```



The `client_id` and `client_secret` can be used to generate an auth token for REST calls (the application code will handle this for you). To run the microservice, we'll need the `client_id` and `client_secret` set as environment variables to run the application, but we'll handle that later on. For now, save them somewhere and we'll come back to them.

## Checkpoint

At this point we've Auto REST enabled our table and secured it so that it can only be accessed via OAUTH. So what does this mean? Well, out-of-the-box, Auto REST enabling a table will give you endpoints to perform the following actions:

\* GET (by ID)\
\* GET (all - with pagination support)\
\* POST (new record)\
\* PUT (update record)\
\* DELETE (by ID)

In addition to the "out-of-the-box" support for CRUD operations, we can add our own custom services to perform additional operations. For example, if we wanted to return a single user based on their username, we could define a service for that operation like so:
```sql
BEGIN
  ORDS.define_service(
    p_module_name    => 'users',
    p_base_path      => 'users/',
    p_pattern        => 'user/:username',
    p_method         => 'GET',
    p_source_type    => ORDS.source_type_collection_item,
    p_source         => 'SELECT id, first_name, last_name, created_on FROM users WHERE username = :username OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY');
  COMMIT;
END;
```



## Testing Our Endpoints

We can test these out before we start writing our application code. Start by logging in to our Oracle Cloud console and viewing the details of our ATP instance. From the details page, click on 'Service Console':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_13_26.jpg)

Within the service console, click on 'Administration' (#1) and then SQL Developer Web (#2).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_14_15.jpg)

Your SQL Developer Web url should look something like this:

`https://[random chars]-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/``admin/_sdw/?nav=worksheet`

 

From here we can grab out ORDS base URL, so copy everything before `/admin`:

`https://[random chars]-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/`

This is the base URL for our ORDS services. Let's grab an auth token first with a CURL call. We'll need our `client_id` and `client_secret` from earlier:
```bash
curl -i -k \
--user [client_id]:[client_secret] \
--data "grant_type=client_credentials" \
https://[obfuscated]-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/usersvc/oauth/token
```



Which will return a response similar to this:
```bash
HTTP/1.1 200 OK
Date: Mon, 08 Jul 2019 15:21:12 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
X-ORACLE-DMS-ECID: 8b5924e9-98a1-4ae3-8824-580e62445efc-00005a26
X-Frame-Options: SAMEORIGIN
X-ORACLE-DMS-RID: 0

{"access_token":"[token value]","token_type":"bearer","expires_in":3600}
```



This auth token expires in one hour and can now be used to make calls against the REST endpoints. Let's test those out before we move on to the application code. It's easiest to use a tool like Postman so that we can visualize the results. Set the auth token as a "Bearer" token in Postman and try each endpoint.

To get all users (`GET` request to `/ords/usersvc/users/`) returned as an array within the 'items' key. Note, by default you'll only get 25 records. See the next example for how to control pagination.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_30_12.jpg)

To use pagination (`GET` request to `/ords/usersvc/users?limit=2&offset=1`) returns an object containing items and pagination related information:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_12_00_01.jpg)

To get a single user (`GET` request to `/ords/usersvc/users/`) returned as a JSON representation of the user:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_32_54.jpg)

To create a new user (`POST` a JSON representation of the user in a request to `/ords/usersvc/users/`) returns with `201 Created` as a JSON representation of the user:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_40_05.jpg)

To update a user (`PUT` request a JSON representation of the user to `/ords/usersvc/users/`) returns `200 OK`:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_43_04.jpg)

To delete a user (DELETE request to /ords/usersvc/users/) returns 200 OK and the count of rowsDeleted:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/27369676-0e50-4f0b-8bfe-0d3fd61d31a2/2019_07_08_11_45_48.jpg)

## Summary

At this point we have a fully functioning set of REST endpoints that we can use to perform CRUD operations on our user object. In the next few posts we'll create the Micronaut application that interacts with these endpoints, performs validation and exposes them as a Kubernetes deployed microservice.

[Photo by ][Shiro hatori](https://unsplash.com/@shiroscope?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/fast?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
