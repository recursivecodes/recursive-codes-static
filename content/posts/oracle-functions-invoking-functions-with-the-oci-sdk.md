---
title: "Oracle Functions - Invoking Functions With The OCI SDK"
slug: "oracle-functions-invoking-functions-with-the-oci-sdk"
author: "Todd Sharp"
date: 2019-08-05
summary: "In this post we'll look at invoking Oracle Functions via the Java SDK."
tags: ["Cloud", "Developers", "Java"]
keywords: "serverless, Java, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/00b3bbd7-20d6-4080-9318-fb27db72d56f/banner_pukpik_i9f_gt_ol0a_unsplash.jpg"
---

In my last few posts we took a look at how to create serverless functions which interact with an Autonomous Transaction Processing (ATP) instance - [first with Java](/posts/oracle-functions-connecting-to-an-atp-database), [then with Node](/posts/oracle-functions-connecting-to-atp-with-nodejs). We invoked those functions using the Fn CLI, which was handy for testing, but obviously not so helpful when it comes to integrating these functions into our microservice applications. There are in fact several ways to invoke Oracle Functions, but in this post we'll focus on calling them via the OCI Java SDK.

To get started, we'll need to include the OCI Java SDK in our project. I'm using Gradle this time, so my dependency looks like so (notice line 6):
```groovy
dependencies {
    localGroovyConf localGroovy()
    compile 'org.codehaus.groovy:groovy-all:3.0.0-alpha-3'
    compile group: 'org.slf4j', name: 'slf4j-api', version: '1.7.26'
    compile group: 'ch.qos.logback', name: 'logback-classic', version: '1.2.3'
    compile group: 'com.oracle.oci.sdk', name: 'oci-java-sdk-full', version: '1.5.14'
}
```



To invoke our function, we'll need to know two things:  the function 'invokeEndpoint' and the function OCID. There's an easy way to grab both of these using the Fn CLI by calling '`fn inspect`': 
```bash
$ fn inspect function fn-atp-node-json fn-atp-node-json-read
```



Which will result in output similar to this:
```json
{
        "annotations": {
                "fnproject.io/fn/invokeEndpoint": "https://xicciwch3fq.us-phoenix-1.functions.oci.oraclecloud.com/20181201/functions/ocid1.fnfunc..../actions/invoke",
                "oracle.com/oci/compartmentId": "ocid1.compartment...."
        },
        "app_id": "ocid1.fnapp....",
        "created_at": "2019-04-02T14:15:47.129Z",
        "id": "ocid1.fnfunc....",
        "idle_timeout": 30,
        "image": "phx.ocir.io/toddrsharp/faas/fn-atp-node-json-read:0.0.91",
        "memory": 256,
        "name": "fn-atp-node-json-read",
        "timeout": 120,
        "updated_at": "2019-04-02T14:31:37.054Z"
}
```



Using the example above, The endpoint variable would be: `https://xicciwch3fq.us-phoenix-1.functions.oci.oraclecloud.com` and the function OCID would be the value within the "id" attribute (`ocid1.fnfunc....`). Now that we have these two values, we can invoke our function with the OCI SDK. The examples below will show invoking a few of the Node.JS serverless functions that persist JSON data as shown in my last post. 

First, let's set some variables for our endpoint and function ID, create an `AuthenticationDetailsProvider` and generate a JSON payload to be sent to the insert function. These examples will use Groovy, but this should look extremely familiar to Java and could very easily be ported to Java with minimal effort:
```groovy
String endpoint = "https://xicciwch3fq.us-phoenix-1.functions.oci.oraclecloud.com"
String insertId = "ocid1.fnfunc.oc1.us-phoenix-1..."
String readId = "ocid1.fnfunc.oc1.us-phoenix-1..."
String payload = JsonOutput.toJson([isCool: true, createdOn: new Date()])
AuthenticationDetailsProvider authProvider = new ConfigFileAuthenticationDetailsProvider('DEFAULT')
```



We have two options for invoking the functions via the SDK: synchronous or asynchronous. First, let's look at invoking them synchronously. We'll do that by creating a `FunctionsInvokeClient` which accepts our `AuthenticationDetailsProvider` instance. `FunctionsInvokeClient` implements `AutoCloseable`, so we'll use Groovy's `withCloseable` to make sure things are cleaned up when we're done. The `withCloseable` closure will receive the client as its only argument and we can use that from within the closure.

To break down the code below, we'll do the following steps:

1.  Set the client endpoint to our function's invokeEndpoint
2.  Invoke the 'read' function to establish the initial size of our dataset
3.  Invoke the 'insert' function to insert a new record
4.  Invoke the 'read' function to retrieve the dataset and visualize our newly inserted record
```groovy
new FunctionsInvokeClient(authProvider).withCloseable { FunctionsInvokeClient client ->

    client.setEndpoint(endpoint)

    LOGGER.info("Initial read to establish record count...");
    InvokeFunctionRequest readSizeRequest = InvokeFunctionRequest.builder().functionId(readId)
            .invokeFunctionBody(StreamUtils.createByteArrayInputStream()).build()

    InvokeFunctionResponse readSizeResponse = client.invokeFunction(readSizeRequest)
    List parsedSizeResponse = new JsonSlurper().parse(readSizeResponse.getInputStream())
    LOGGER.info("Before insert there are currently ${parsedSizeResponse.size()} records in the table...");


    LOGGER.info("Invoking normal insert with Sync Client...");
    InvokeFunctionRequest insertRequest = InvokeFunctionRequest.builder().functionId(insertId)
            .invokeFunctionBody(StreamUtils.createByteArrayInputStream(payload.getBytes())).build()

    InvokeFunctionResponse insertResponse = client.invokeFunction(insertRequest)
    String insertResponseText = insertResponse.getInputStream().getText("UTF-8");
    Map parsedInsertResponse = new JsonSlurper().parseText(insertResponseText)
    System.out.println(parsedInsertResponse);
    LOGGER.info("Received response from insert invocation: ${insertResponseText}");

    LOGGER.info("Secondary read to establish record count...");
    InvokeFunctionRequest readRequest = InvokeFunctionRequest.builder().functionId(readId)
            .invokeFunctionBody(StreamUtils.createByteArrayInputStream()).build()

    InvokeFunctionResponse readResponse = client.invokeFunction(readRequest)
    String readResponseString = readResponse.getInputStream().getText("UTF-8")
    List parsedResponse = new JsonSlurper().parseText(readResponseString)
    System.out.println(parsedResponse);
    LOGGER.info("After insert there are now ${parsedResponse.size()} records in the table...");
}
```



Which results in the following output:
```log
10:57:00.499 [main] INFO com.oracle.bmc.functions.FunctionsInvokeClient - Setting endpoint to https://xicciwch3fq.us-phoenix-1.functions.oci.oraclecloud.com
10:57:00.530 [main] INFO codes.recursive.Main - Initial read to establish record count...
10:57:00.568 [main] DEBUG com.oracle.bmc.http.internal.RestClient - Generated request ID: 632C1FD289144269BB73886C67914A1C
10:57:00.910 [main] INFO com.oracle.bmc.ClientRuntime - Using SDK: Oracle-JavaSDK/1.4.1-preview1-SNAPSHOT
10:57:00.910 [main] INFO com.oracle.bmc.ClientRuntime - User agent set to: Oracle-JavaSDK/1.4.1-preview1-SNAPSHOT (Mac OS X/10.14.4; Java/1.8.0_201; Java HotSpot(TM) 64-Bit Server VM/25.201-b09)
10:57:01.587 [main] INFO codes.recursive.Main - Before insert there are currently 0 records in the table...
10:57:01.587 [main] INFO codes.recursive.Main - Invoking normal insert with Sync Client...
10:57:01.592 [main] DEBUG com.oracle.bmc.http.internal.RestClient - Generated request ID: FA72157DC85D47DABDDC21AD5A41BDB0
[insert:[rowsAffected:1], complete:true]
10:57:02.405 [main] INFO codes.recursive.Main - Received response from insert invocation: {"insert":{"rowsAffected":1},"complete":true}
10:57:02.406 [main] INFO codes.recursive.Main - Secondary read to establish record count...
10:57:02.406 [main] DEBUG com.oracle.bmc.http.internal.RestClient - Generated request ID: 4E517F4A46EE46849F9B99098B3FE299
[[id:74, capturedAt:2019-06-12T14:57:03.000Z, data:[fromSDK:true, on:2019-06-12T14:56:59+0000]]]
10:57:02.658 [main] INFO codes.recursive.Main - After insert there are now 1 records in the table...
```



To invoke the functions asynchronously is nearly identical, but we now use the `FunctionsInvokeAsyncClient` and the `invokeFunction` methods now receive an instance of `AsyncHandler` to handle the response. 
```groovy
new FunctionsInvokeAsyncClient(authProvider).withCloseable { asyncClient ->
    asyncClient.setEndpoint(endpoint)

    LOGGER.info("Initial read to establish record count...");
    AsyncHandler<InvokeFunctionRequest, InvokeFunctionResponse> readSizeRequestHandler = new AsyncHandler() {
        @Override
        void onSuccess(Object request, Object response) {
            List parsedSizeResponse = new JsonSlurper().parse(response.getInputStream())
            LOGGER.info("Before slow insert there are currently ${parsedSizeResponse.size()} records in the table...");
        }

        @Override
        void onError(Object request, Throwable error) {
            LOGGER.error "Error: ${error.message}"
        }
    }
    InvokeFunctionRequest readSizeRequest = InvokeFunctionRequest.builder().functionId(readId)
            .invokeFunctionBody(StreamUtils.createByteArrayInputStream()).build()
    asyncClient.invokeFunction(readSizeRequest, readSizeRequestHandler)

    AsyncHandler<InvokeFunctionRequest, InvokeFunctionResponse> readRequestHandler = new AsyncHandler() {
        @Override
        void onSuccess(Object request, Object response) {
            String readResponseString = response.getInputStream().getText("UTF-8")
            List parsedResponse = new JsonSlurper().parseText(readResponseString)
            LOGGER.info("After slow insert there are now ${parsedResponse.size()} records in the table...");
        }

        @Override
        void onError(Object request, Throwable error) {
            LOGGER.error "Error: ${error.message}"
        }
    }

    LOGGER.info("Invoking slow insert with Async Client...");
    AsyncHandler<InvokeFunctionRequest, InvokeFunctionResponse> insertAsyncHandler = new AsyncHandler() {
        @Override
        void onSuccess(Object request, Object response) {
            LOGGER.info("Received **slow response** from insert invocation: ${response.getInputStream().getText("UTF-8")}");

            LOGGER.info("Secondary read to establish record count...");

            InvokeFunctionRequest readRequest = InvokeFunctionRequest.builder().functionId(readId)
                    .invokeFunctionBody(StreamUtils.createByteArrayInputStream()).build()
            asyncClient.invokeFunction(readRequest, readRequestHandler)
        }
        @Override
        void onError(Object request, Throwable error) {
            LOGGER.error "Error: ${error.message}"
        }
    }

    InvokeFunctionRequest insertRequest = InvokeFunctionRequest.builder().functionId(slowInsertId)
            .invokeFunctionBody(StreamUtils.createByteArrayInputStream(payload.getBytes())).build()
    asyncClient.invokeFunction(insertRequest, insertAsyncHandler)

    LOGGER.info("Keeping thread alive so insert response is logged. Waiting 10 seconds...");
    sleep(10000)

}
```



The async invocation produces the following output. Take note of the order and timestamps on the logging output:
```log
11:08:38.019 [main] INFO codes.recursive.Main - Initial read to establish record count...
11:08:38.073 [main] DEBUG com.oracle.bmc.http.internal.RestClient - Generated request ID: D89086DE0F09469891996EAAD718224D
11:08:38.353 [main] INFO codes.recursive.Main - Invoking slow insert with Async Client...
11:08:38.361 [main] DEBUG com.oracle.bmc.http.internal.RestClient - Generated request ID: 7AE5A846B076443680805070DF9C68B8
11:08:38.362 [main] INFO codes.recursive.Main - Keeping thread alive so insert response is logged. Waiting 10 seconds...
11:08:38.478 [jersey-client-async-executor-1] INFO com.oracle.bmc.ClientRuntime - Using SDK: Oracle-JavaSDK/1.4.1-preview1-SNAPSHOT
11:08:38.478 [jersey-client-async-executor-1] INFO com.oracle.bmc.ClientRuntime - User agent set to: Oracle-JavaSDK/1.4.1-preview1-SNAPSHOT (Mac OS X/10.14.4; Java/1.8.0_201; Java HotSpot(TM) 64-Bit Server VM/25.201-b09)
11:08:40.096 [jersey-client-async-executor-0] INFO codes.recursive.Main - Before slow insert there are currently 1 records in the table...
11:08:45.667 [jersey-client-async-executor-1] INFO codes.recursive.Main - Received **slow response** from insert invocation: {"insert":{"rowsAffected":1},"complete":true}
11:08:45.667 [jersey-client-async-executor-1] INFO codes.recursive.Main - Secondary read to establish record count...
11:08:45.668 [jersey-client-async-executor-1] DEBUG com.oracle.bmc.http.internal.RestClient - Generated request ID: 992267E372FD4BB69B6E2662DB348314
11:08:45.908 [jersey-client-async-executor-2] INFO codes.recursive.Main - After slow insert there are now 2 records in the table...
11:08:48.372 [main] INFO codes.recursive.Main - Goodbye
```



Using the SDK and the Fn CLI is not the only way to invoke Oracle Functions from your application. You can also call the invokeEndpoint directly, but you'll need to [sign the HTTP request](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/signingrequests.htm) as you would any other REST call to the OCI API.

[Photo by ][Pukpik](https://unsplash.com/@pukapika?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/java?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
