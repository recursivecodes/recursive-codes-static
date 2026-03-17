---
title: "Oracle Functions: An Easier Way To Talk To Your Autonomous Database"
slug: "oracle-functions-an-easier-way-to-talk-to-your-autonomous-database"
author: "Todd Sharp"
date: 2019-08-06
summary: "In this post we'll look at an easier way to get data in and out of your Autonomous DB from your Oracle Functions."
tags: ["Cloud", "Containers, Microservices, APIs", "Developers", "Java"]
keywords: "serverless, Database, Java, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/56f076de-3fa8-4d53-a310-dea0833a095e/banner_spring_fed_images_ckydtiyd_mw_unsplash.jpg"
---

 

Last week I posted about [connecting your Oracle Functions to your Autonomous DB](/posts/oracle-functions-connecting-to-an-atp-database) instance to query and persist data. That post involved creating a custom Dockerfile and ensuring that your ATP wallet was included in the Docker image that is used to deploy and invoke your serverless function and there are certainly times where that may be necessary, but there's an easier way to talk to your Autonomous DB and we'll look at that method in this post.

If you're new to Autonomous DB, check out my [Complete Guide To Getting Up And Running With Autonomous DB In The Cloud](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud)

In this method we'll utilize Oracle REST Data Services (ORDS) to get some data out of a simple user table in my ATP instance. I [covered ORDS in great detail in my microservices series](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-1), but if you missed those posts we'll take another look at how to enable ORDS and then create a simple serverless function to call ORDS and retrieve some data. 

## Enabling ORDS

The first step is to REST enable the schema in which we're going to be working with. That can be accomplished with the following query, so open up your favorite query editor, CLI tool or [SQL Developer Web](https://www.thatjeffsmith.com/archive/2018/05/announcing-oracle-sql-developer-web/) and run the following:
```sql
BEGIN
    /* enable ORDS for schema */
    ORDS.ENABLE_SCHEMA(p_enabled => TRUE,
                       p_schema => 'USERSVC',
                       p_url_mapping_type => 'BASE_PATH',
                       p_url_mapping_pattern => 'usersvc',
                       p_auto_rest_auth => TRUE);
    COMMIT;
END;
```



**Note**: The argument `p_auto_rest_auth` being set to `TRUE` will protect your `/metadata-catalog` endpoint from being exposed.

Let's create the necessary privileges so that we'll be able to generate an auth token for our calls:
```sql
DECLARE
 l_roles     OWA.VC_ARR;
 l_modules   OWA.VC_ARR;
 l_patterns  OWA.VC_ARR;
BEGIN
 l_roles(1)   := 'SQL Developer';
 l_patterns(1) := '/users/*';
 ORDS.DEFINE_PRIVILEGE(
     p_privilege_name => 'rest_privilege',
     p_roles          => l_roles,
     p_patterns       => l_patterns,
     p_modules        => l_modules,
     p_label          => '',
     p_description    => '',
     p_comments       => NULL);
 COMMIT;

END;
```



Create an OAUTH client associated with the privilege:
```sql
BEGIN
  OAUTH.create_client(
    p_name            => '[Descriptive Name For Client]',
    p_grant_type      => 'client_credentials',
    p_owner           => '[Owner Name]',
    p_description     => '[Client Description]',
    p_support_email   => '[Email Address]',
    p_privilege_names => 'rest_privilege'
  );

  COMMIT;
END;
```



Grant the `SQL Developer` role to the client application:
```sql
BEGIN
  OAUTH.grant_client_role(
    p_client_name => 'Rest Client',
    p_role_name   => 'SQL Developer'
  );
  COMMIT;
END;
```



We can now grab the `client_id` and `client_secret` with:
```sql
SELECT id, name, client_id, client_secret
FROM   user_ords_clients;
```



The `client_id`​ and `client_secret` can be used to generate an auth token for REST calls (we'll look at this in a bit). At this point, our schema is REST enabled and we have everything set up to authenticate our calls, but we haven't actually exposed any tables yet. We could certainly Auto-REST enable an entire table which would give us a full set of REST endpoints for CRUD on the table:
```sql
BEGIN
  ORDS.enable_object(
    p_enabled         => TRUE,
    p_schema          => 'USERSVC',
    p_object          => 'USERS',
    p_object_type     => 'TABLE',
    p_object_alias    => 'users',
    p_auto_rest_auth  => FALSE);
  COMMIT;
END;
```



But in this example, let's just create a single endpoint to retrieve a single user by username:
```sql
BEGIN
  ORDS.define_service(
    p_module_name    => 'users',
    p_base_path      => 'users/',
    p_pattern        => 'user/:username',
    p_method         => 'GET',
    p_source_type    => ORDS.source_type_collection_item,
    p_source         => 'SELECT id, first_name, last_name, created_on FROM users WHERE username = :username OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY');
  COMMIT;
END;
```



Right, so now we can set up our Oracle Function to hit this REST endpoint and retrieve a user. We'll need our ORDS base URL, so log in to your Oracle Cloud dashboard and view the details of your ATP instance. On the details page, click 'Service Console':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/56f076de-3fa8-4d53-a310-dea0833a095e/2019_07_08_11_13_26.jpg)

In the Service Console, click 'Development' and then 'SQL Developer Web':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/56f076de-3fa8-4d53-a310-dea0833a095e/2019_08_02_10_24_08.jpg)

Your SQL Developer Web url should look something like this:

`https://[random chars]-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/admin/_sdw/?nav=worksheet`\
 \
From here we can grab out ORDS base URL, so copy everything before /admin:

`https://[random chars]-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/`

This is the base URL for our ORDS services.

## Creating A Serverless Function

If you're familiar with Oracle Functions, feel free to skip this step. If you're new to Oracle Functions, the first thing we'll need to do is create an 'application' to contain our functions:
```bash
fn create app \
--annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx..."]' \
ords-demo
```



You'll need to pass in a valid subnet ID. I typically create a VCN for all my serverless functions and choose one of the subnets within that VCN. If necessary, check out the docs on how to create a VCN in Oracle Cloud Infrastructure.

**Bonus Tip**: Sign up for an account on papertrailapp.com and set up a log destination. Then update your function with `fn update app ords-demo --syslog-url tcp://logs3.papertrailapp.com:53136` so that you can log your function's console output to the event viewer in papertrail!

We'll need to set a few config variables for our function to get our `client_id` and `client_secret` into our function. We can do this with `fn config app [app name] [config key] [config value]`:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/56f076de-3fa8-4d53-a310-dea0833a095e/2019_08_02_10_41_27.jpg)

**Note: **You should always encrypt any configuration variables that contain sensitive information. Check my [guide to using Key Management](/posts/oracle-functions-using-key-management-to-encrypt-and-decrypt-configuration-variables) in OCI to learn how!

Now create the function:

`fn init --runtime java ords-demo-fn`

Open up the generated project in your favorite IDE and take a look at the `HelloFunction.java` class. Let's set our base URL and create a private function to grab our auth token. Note that our application config variables are available as environment properties here:
```java
public class HelloFunction {

    private final String ordsBaseUrl = "https://hvg9nd7xibsaegv-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/usersvc";
    private final HttpClient httpClient = HttpClient.newHttpClient();

    public String handleRequest(String input) {
        String name = (input == null || input.isEmpty()) ? "world"  : input;
        return "Hello, " + name + "!";
    }

    private String getAuthToken() {
        String authToken = "";
        try {
            Map<String, String> env = System.getenv();
            for (String envName : env.keySet()) {
                System.out.format("%s=%s%n", envName, env.get(envName));
            }
            String clientId = System.getenv().get("clientId");
            String clientSecret = System.getenv().get("clientSecret");
            String authString =  clientId + ":" + clientSecret;
            String authEncoded = "Basic " + Base64.getEncoder().encodeToString(authString.getBytes());
            HttpRequest request = HttpRequest.newBuilder(new URI(this.ordsBaseUrl + "/oauth/token"))
                    .header("Authorization", authEncoded)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString("grant_type=client_credentials"))
                    .build();
            HttpResponse<String> response = this.httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            String responseBody = response.body();
            ObjectMapper mapper = new ObjectMapper();
            TypeReference<HashMap<String, String>> typeRef = new TypeReference<HashMap<String, String>>() {};
            HashMap<String, String> result = mapper.readValue(responseBody, typeRef);
            authToken = result.get("access_token");
        }
        catch (URISyntaxException | IOException | InterruptedException e) {
            e.printStackTrace();
        }
        return authToken;
    }
}
```



We've set up an `HttpClient`, a variable containing our ORDS base URL and created a function that we can use to generate an auth token. Now let's add a static inner class to represent our user:
```java
public class HelloFunction {

    private final String ordsBaseUrl = "https://hvg9nd7xibsaegv-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/usersvc";
    private final HttpClient httpClient = HttpClient.newHttpClient();

    public static class User {
        public String id;
        public String username;
        @JsonAlias("first_name")
        public String firstName;
        @JsonAlias("last_name")
        public String lastName;
        @JsonAlias("created_on")
        public Date createdOn;
        @JsonIgnore
        public List links;
    }

    /* removed other functions for brevity */
}
```



The Oracle Functions Java FDK includes Jackson, so we can annotate our User class with `@JsonAlias` to map certain elements in the ORDS JSON response to a property in our response object and use `@JsonIgnore` to prevent certain properties from being included in the response.  Make sure you include the dependency in your `pom.xml`:
```xml
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
    <version>2.9.9</version>
    <scope>compile</scope>
</dependency>
```



Finally, we can implement our `handleRequest` method and make the call to ORDS to retrieve our user by username, serialize the response as a `User` object and return it.  Here's how the entire class looks once fully implemented:
```java
package com.example.fn;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.*;

public class HelloFunction {

    private final String ordsBaseUrl = "https://hvg9nd7xibsaegv-demodb.adb.us-phoenix-1.oraclecloudapps.com/ords/usersvc";
    private final HttpClient httpClient = HttpClient.newHttpClient();

    public static class User {
        public String id;
        public String username;
        @JsonAlias("first_name")
        public String firstName;
        @JsonAlias("last_name")
        public String lastName;
        @JsonAlias("created_on")
        public Date createdOn;
        @JsonIgnore
        public List links;
    }

    public User handleRequest(String username) {
        User user = null;
        try {
            HttpRequest request = HttpRequest.newBuilder( new URI( this.ordsBaseUrl + "/users/user/" + username ) )
                    .header("Authorization", "Bearer " + getAuthToken())
                    .GET()
                    .build();
            HttpResponse<String> response = this.httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if( response.statusCode() == HttpURLConnection.HTTP_NOT_FOUND ) {
                System.out.println("User with username " + username + " not found!");
            }
            else {
                user = new ObjectMapper().readValue(response.body(), User.class);
            }
        }
        catch (URISyntaxException | IOException | InterruptedException e) {
            e.printStackTrace();
        }
        return user;
    }

    private String getAuthToken() {
        String authToken = "";
        try {
            Map<String, String> env = System.getenv();
            for (String envName : env.keySet()) {
                System.out.format("%s=%s%n", envName, env.get(envName));
            }
            String clientId = System.getenv().get("clientId");
            String clientSecret = System.getenv().get("clientSecret");
            String authString =  clientId + ":" + clientSecret;
            String authEncoded = "Basic " + Base64.getEncoder().encodeToString(authString.getBytes());
            HttpRequest request = HttpRequest.newBuilder(new URI(this.ordsBaseUrl + "/oauth/token"))
                    .header("Authorization", authEncoded)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString("grant_type=client_credentials"))
                    .build();
            HttpResponse<String> response = this.httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            String responseBody = response.body();
            ObjectMapper mapper = new ObjectMapper();
            TypeReference<HashMap<String, String>> typeRef = new TypeReference<HashMap<String, String>>() {};
            HashMap<String, String> result = mapper.readValue(responseBody, typeRef);
            authToken = result.get("access_token");
        }
        catch (URISyntaxException | IOException | InterruptedException e) {
            e.printStackTrace();
        }
        return authToken;
    }
}
```



## Testing The Function

Let's write a simple test to make sure that our function works as expected. I've hardcoded my expected JSON response here, yours would be different. You'll need to set a `clientId` and `clientSecret`as environment variables in your shell before running the tests so that the proper values get utilized.
```java
package com.example.fn;

import com.fnproject.fn.testing.FnResult;
import com.fnproject.fn.testing.FnTestingRule;
import org.junit.Rule;
import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class HelloFunctionTest {

    @Rule
    public final FnTestingRule testing = FnTestingRule.createDefault();

    @Test
    public void shouldReturnUser() {
        testing.givenEvent().withBody("tsharp").enqueue();
        testing.thenRun(HelloFunction.class, "handleRequest");

        FnResult result = testing.getOnlyResult();
        assertEquals("{"id":"8C561D58E856DD25E0532010000AF462","username":"tsharp","firstName":"todd","lastName":"sharp","createdOn":1561649500385}", result.getBodyAsString());
    }

}
```



## Deploying The Function

When we use the Fn CLI to deploy our function to the cloud it will run our unit tests as part of the build process. Since we've manually run our test and ensured that it passed and we're dependent on the config variables being set into our environment for our test to run we're going to drop our own `Dockerfile` into the root of the project that will skip running the tests as part of the build process (side note: I'm working with our PMs and engineers to make this process easier in the future).[ 
```text
FROM fnproject/fn-java-fdk-build:jdk11-1.0.98 as build-stage
WORKDIR /function
ENV MAVEN_OPTS -Dhttp.proxyHost= -Dhttp.proxyPort= -Dhttps.proxyHost= -Dhttps.proxyPort= -Dhttp.nonProxyHosts= -Dmaven.repo.local=/usr/share/maven/ref/repository

ADD pom.xml /function/pom.xml
RUN ["mvn", "package", "dependency:copy-dependencies", "-DincludeScope=runtime", "-DskipTests=true", "-Dmdep.prependGroupId=true", "-DoutputDirectory=target", "--fail-never"]

ADD src /function/src

RUN ["mvn", "package", "-DskipTests=true"]
FROM fnproject/fn-java-fdk:jre11-1.0.98
WORKDIR /function
COPY --from=build-stage /function/target/*.jar /function/app/

CMD ["com.example.fn.HelloFunction::handleRequest"]
```
The only change to the standard `Dockerfile` used with this function is the addition of `-DskipTests=true` to the `RUN` command for the final build. Now we can deploy our function to the cloud with `fn deploy --app ords-demo`.

## Invoking The Function

At this point our function is able to be invoked by running `fn invoke ords-demo ords-demo-fn,` but we'll want to pass our username into the function, so run `echo "tsharp" | fn invoke ords-demo ords-demo-fn` and we'll receive the user response:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/56f076de-3fa8-4d53-a310-dea0833a095e/2019_08_02_13_48_35.jpg)

## Summary

In this post we looked at how to enable ORDS for a schema in our Autonomous DB instance, secure ORDS with a privilege and create an auth client and credentials that we can use to authenticate our HTTP calls to the REST endpoints. We used those credentials from our serverless function to make an HTTP call to our custom ORDS endpoint and serialized the result as a Java POJO and returned that result from our function call.

[Photo by ][Spring Fed Images](https://unsplash.com/@spring_fed_images?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/rest?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
