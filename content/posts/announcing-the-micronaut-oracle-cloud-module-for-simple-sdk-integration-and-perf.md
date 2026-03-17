---
title: "Announcing the Micronaut Oracle Cloud Infrastructure Module for Simple SDK Integration and Performant Serverless Functions"
slug: "announcing-the-micronaut-oracle-cloud-module-for-simple-sdk-integration-and-performant-serverless-functions"
author: "Todd Sharp"
date: 2020-09-11
summary: "In this post, we'll talk about a new module to provide powerful integrations between the Micronaut framework and Oracle Cloud. "
tags: ["Cloud", "Cloud Native", "Developers", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5175ee97-1f5e-41df-9cfe-4ade099f14bb/banner_alex_knight_zhlwvfswbda_unsplash.jpg"
---

If you are a member or follower of the Java community, then you likely saw this news a few months ago:

[![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5175ee97-1f5e-41df-9cfe-4ade099f14bb/file_1595520449812.png)](https://twitter.com/oraclelabs/status/1278768631158013956)

\[gist2 id=widgets\]

This is huge news.

If you've read my blogs here, [follow me on Twitter](https://twitter.com/recursivecodes), or [on GitHub](https://github.com/recursivecodes) then you have figured out that I'm a pretty big fan of Micronaut. I won't get into the performance aspect of what makes it so great in this post (and trust me, there is [plenty to talk about regarding performance](https://micronaut.io/blog/2020-04-07-micronaut-vs-quarkus-vs-spring-boot-performance-jdk-14.html)). Instead, I'll focus on a few of the other reasons why I'm such a fan. First off, the framework is well documented and has plenty of modules available to make software development, testing, and deployments easier developers. Maybe you're using [Liquibase](https://micronaut-projects.github.io/micronaut-liquibase/latest/guide/index.html) or [Flyway](https://micronaut-projects.github.io/micronaut-flyway/latest/guide/index.html) to manage database migrations? Perhaps you'd like to [document your microservices with OpenAPI/Swagger](https://micronaut-projects.github.io/micronaut-openapi/latest/guide/index.html)? No problem, that's easy to do with Micronaut. There are new features coming all the time and it's easy to develop and contribute your own integrations to the community. But it's not just developer tool integrations like Liquibase, Flyway, and Open API that make Micronaut great. There are also cloud integrations that you would expect in a framework that calls itself "natively cloud-native". 

There is already great support for Oracle Database and Oracle Cloud Infrastructure in Micronaut.  You can easily connect your application to Oracle Database via OJDBC using [Micronaut Data](https://micronaut-projects.github.io/micronaut-data/latest/guide/index.html), use [Oracle UCP for connection pooling](https://micronaut-projects.github.io/micronaut-data/latest/guide/index.html), detect the [Oracle Cloud Infrastructure environment and retrieve cloud instance metadata](https://docs.micronaut.io/latest/guide/index.html#cloudConfiguration), use [Oracle Cloud Infrastructure vaults as secure, distributed configuration stores](https://docs.micronaut.io/latest/guide/index.html#distributedConfigurationOracleCloudVault) and more. And today, we're announcing the launch of the [Micronaut module for Oracle Cloud Infrastructure](https://github.com/micronaut-projects/micronaut-oracle-cloud).

**Where are the Examples?** All of the code that we'll look at below (and more) can be found in the `docs-examples` directory on GitHub located at <https://github.com/micronaut-projects/micronaut-oracle-cloud/tree/master/docs-examples>

This module provides developers the ability to configure a secure authentication provider (via four different methods), and inject any client from the OCI Java SDK into your Micronaut controllers and services for use as necessary.

## OCI SDK Integration

The first step is to provide credentials that Micronaut will need to construct an authentication provider for the SDK clients. If you have set up the OCI CLI then you'll have a config file with a `DEFAULT` profile for the CLI located at `$USER_HOME/.oci/config`. The easiest way to use this method is to provide the following configuration in your Micronaut `application.yml` file.
```yaml
oci:  
  config:    
    profile: DEFAULT
```



Another option is to provide the necessary information directly via the application.yml file (you might do this in your build pipeline or in conjunction with secret values from your Oracle Cloud vault).
```yaml
oci:
  fingerprint: [String. The private key fingerprint]
  passphrase: [String. The private key passphrase]
  private-key: [String. The contents of your private key. Optionally, pass a path with private-key-file (see below).]
  private-key-file: [String. The path to the private key file (used in place of private-key above)]
  region: [String. Ex: us-phoenix-1]
  tenant-id: [String. The tenancy OCID]
  user-id: [String. The user OCID]
```



The other two possible auth methods involve instance principals (for VMs running in the Oracle Cloud) and resource principals (for serverless functions). The [module guide covers both of these](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide/#instance-principals), so refer to it as applicable.

At this point, Micronaut will handle all of the needed authentication and hand you a client that is ready to use when you inject it into your controllers and services. Here's an example of injecting the ObjectStorage client into a controller:
```java
@Controller("/os")
public class BucketController {
    private final ObjectStorage objectStorage;
    private final TenancyIdProvider tenancyIdProvider;

    public BucketController(
            ObjectStorage objectStorage,
            TenancyIdProvider tenancyIdProvider) {
        this.objectStorage = objectStorage;
        this.tenancyIdProvider = tenancyIdProvider;
    }
}
```



The ObjectStorage client is now available from your controller methods.
```java
@Get("/buckets{/compartmentId}")
public List<String> listBuckets(@PathVariable @Nullable String compartmentId) {
    String compartmentOcid = compartmentId != null ? compartmentId : tenancyIdProvider.getTenancyId();
    GetNamespaceRequest getNamespaceRequest = GetNamespaceRequest.builder()
            .compartmentId(compartmentOcid).build();
    final GetNamespaceResponse namespaceResponse = objectStorage.getNamespace(getNamespaceRequest);
    final ListBucketsRequest.Builder builder = ListBucketsRequest.builder();
    builder.namespaceName(namespaceResponse.getValue());
    builder.compartmentId(compartmentOcid);
    return objectStorage.listBuckets(builder.build())
                    .getItems()
                    .stream()
                    .map(BucketSummary::getName)
                    .collect(Collectors.toList());
}
```



In addition to the standard clients in the OCI SDK, the module provides a complete set of reactive clients that use RxJava to allow you to perform the same operations in a non-blocking manner. Just inject the Rx client variation:
```java
@Controller("/os")
public class BucketController implements BucketOperations {
    private final ObjectStorageRxClient objectStorage;
    private final TenancyIdProvider tenancyIdProvider;

    public BucketController(
            ObjectStorageRxClient objectStorage,
            TenancyIdProvider tenancyIdProvider) { // <1>
        this.objectStorage = objectStorage;
        this.tenancyIdProvider = tenancyIdProvider;
    }
}
```



And use the client in your methods (notice the method now returns a `Single<List<String>>`).
```java
@Get("/buckets{/compartmentId}")
public Single<List<String>> listBuckets(@PathVariable @Nullable String compartmentId) {
    String compartmentOcid = compartmentId != null ? compartmentId : tenancyIdProvider.getTenancyId();
    GetNamespaceRequest getNamespaceRequest = GetNamespaceRequest.builder()
            .compartmentId(compartmentOcid).build();
    return objectStorage.getNamespace(getNamespaceRequest).flatMap(namespaceResponse -> {
        final ListBucketsRequest.Builder builder = ListBucketsRequest.builder();
        builder.namespaceName(namespaceResponse.getValue());
        builder.compartmentId(compartmentOcid);
        return objectStorage.listBuckets(builder.build())
                .map(listBucketsResponse -> listBucketsResponse.getItems()
                        .stream()
                        .map(BucketSummary::getName)
                        .collect(Collectors.toList()));
    });
}
```



## Serverless Functions

In addition to the SDK integration, the module provides support for Micronaut serverless functions. Just configure the dependencies, extend [OciFunction](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/api/io/micronaut/oci/function/OciFunction.html), and include a custom Dockerfile (see [the guide](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide/#functions)) and you'll get all of the power of Micronaut in your serverless functions.

**Hot Tip!** Since they are compiled to native images inside of the Docker container when they are deployed you'll get amazing performance out of your serverless functions. We're talking (unscientifically measured) 600ms cold starts and 250ms warm invocations. 

## HTTP Serverless

This feature is one that I'm really excited about. With this module, you can create Micronaut controllers that perform your application's business logic and point an API Gateway at your serverless function. The module will handle all of the necessary routing to invoke the proper controller method and return the necessary result based on the incoming path and HTTP request method. This allows you to create powerful serverless backends with a minimal amount of effort and code. I have some more advanced demos planned in the near future, but for now, let me give you an example of how this works. I'll show a simple example, but the GitHub repo has a more advanced demo that illustrates the fact that you can easily integrate the OCI SDK into your serverless and http+serverless applications. 

We start off with a controller which has two endpoints. Both are located at `/echo/` but one uses `POST` and the other uses `GET`. 

    @Controller("/test")
    public class TestController ", produces = MediaType.TEXT_PLAIN)
        public String testPost(@PathVariable String name) 
        @Get(uri = "/echo/", produces = MediaType.TEXT_PLAIN)
        public String testGet(@PathVariable String name) 
    }

Next, we include the necessary `Dockerfile` (see [the guide](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide/#httpFunctions) and/or GitHub repo), call `./gradlew buildLayers` and deploy with `fn deploy --app [your app]`. Now we need to set up an API Gateway to expose our function and point incoming calls at it.

First, create an API Gateway by selecting 'Developer Services', then 'API Gateway' from the Oracle Cloud console dashboard.

![API Gateway Menu](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/api-gateway-menu.png)

Click on 'Create Gateway'.

![Create Gateway Button](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/create-gateway.png)

Enter a name for the gateway, choose the compartment it is stored in, and the network and subnet.

![Create Gateway Button](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/gateway-details.png)

When the gateway is 'Active', click 'Deployments', then 'Create Deployment'.

![Create Gateway Button](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/create-deployment-button.png)

Provide a name for the deployment and enter a "Path Prefix". If necessary, configure any Authentication, CORS, or Rate Limiting and click 'Next'.

The path prefix must match the path you used in your controller (IE: `@Controller("/test")`).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5175ee97-1f5e-41df-9cfe-4ade099f14bb/file_1595519527244.png)

On the next tab, enter the route information.

1.  Enter `/` as the Path. This will capture all incoming requests and the Micronaut router will match the incoming path and request method with the proper controller method.

2.  Choose `ANY` for methods. Optionally, choose the necessary methods individually.

3.  Choose 'Oracle Functions' as the type.

4.  Choose the appropriate Oracle Functions application.

5.  Choose the function name that you used. This can be found in your function's `func.yaml` file.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5175ee97-1f5e-41df-9cfe-4ade099f14bb/file_1595519654110.png)

Click 'Next', then review the deployment details and click 'Create'.

![Review Deployment Details](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/deployment-review.png)

Your new deployment will be listed in 'Creating' state.

![Deployment Creating](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/deployment-creating.png)

When your new deployment becomes 'Active', click on the deployment to view the deployment details. Copy the 'Endpoint' - this is the base URL that you'll use for your function invocations.

![Create Gateway Button](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/deployment-details.png)

Test your functions by appending the proper controller path and one of your controller endpoints.

![Create Gateway Button](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/img/deployment-invocation.png)

## Future Plans

There are tons of them, but Graeme probably wouldn't like it if I told you all of them! Keep an eye on Micronaut + Helidon integrations, more work with GraalVM integrations, and much more. As far as this module is concerned, we're working on enhancing [Micronaut Launch](http://micronaut.io/launch/) to provide some support for generating projects that use the `micronaut-oci` module, as well as serverless functions with Dockerfile generation and much more! Also, stay tuned for the Micronaut Gradle plugin which is also coming soon. I'll cover that in another blog post in the near future.

In the meantime, please give the functionality above a try and give us your feedback. Issues can be filed on GitHub, and comments are welcomed via the comments below or on [Twitter](https://twitter.com/micronautfw).

**More Information!** For all the technical details of this module, please [read the full documentation for these integrations](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide).

Photo by [Alex Knight](https://unsplash.com/@agkdesign?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
