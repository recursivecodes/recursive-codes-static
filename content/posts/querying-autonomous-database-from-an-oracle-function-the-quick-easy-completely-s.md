---
title: "Querying Autonomous Database from an Oracle Function (The Quick, Easy & Completely Secure Way)"
slug: "querying-autonomous-database-from-an-oracle-function-the-quick-easy-completely-secure-way"
author: "Todd Sharp"
date: 2022-03-31
summary: "In this post, we'll look at how to create a secure serverless function in OCI that connects and queries an Autonomous DB instance."
tags: ["Cloud", "Database", "Java", "Micronaut"]
keywords: "micronaut, serverless, java, cloud, oci"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/network-2402637_1280.jpeg"
---

I've written many blog posts about connecting to an Autonomous DB instance in the past. Best practices evolve as tools, services, and frameworks become more mature. In this post, I want to revisit this topic based on the current state of the tools and languages. I'm confident that the method described here represents the most secure way to connect to an Autonomous DB instance, and it's even easier to do than the previous methods that required you to save your Autonomous DB wallet into secrets or an otherwise less-than-ideal manner. The following blog posts are now obsolete as of publishing on this post.

- [Oracle Functions - Connecting To An ATP Database](https://recursive.codes/blog/post/1133)\
- [Oracle Functions - Connecting To An ATP Database Revisited](https://recursive.codes/blog/post/84)
- [Oracle Functions - Connecting To An ATP Database With A Wallet Stored As Secrets](https://recursive.codes/blog/post/1382)

With that out of the way, let's talk about this current approach. We will use the [Micronaut](https://micronaut.io) framework to create a serverless function in this post. Micronaut gives us several advantages. For one, Micronaut has an extensive Oracle Cloud module that provides integrations into the OCI Secrets service to ensure we're not storing our database user credentials in an insecure manner. Additionally, we'll use Micronaut's ability to automatically download our Autonomous DB wallet to avoid the extra steps involved with obtaining that wallet which keeps our code concise and maintainable. Finally, we'll create a native image version of our function with GraalVM to drastically improve the function's cold and hot start times to enable much better runtime performance. This tutorial will walk you through the entire process, but please refer to the [documentation](https://micronaut-projects.github.io/micronaut-oracle-cloud/latest/guide/#functions) if you get stuck or would like to read more. Here are the steps that we'll take in this post:

- [Create Secrets](#Create%20Secrets)
- [Creating the Micronaut Function Application](#%C2%A0%3Cspan%20style=)
  - [Configuring the Application](#Configure%20Application)
  - [Modifying the Function To Query the Database](#Update%20Function%20Body)
  - [Testing the Function](#Test%20the%20Function)
  - [Building & Pushing the Docker Container](#Build%20&%20Push%20Docker%20Container)
- [Creating the Application in OCI](#%C2%A0Creating%20the%20Application%20in%20OCI)
- [Creating the Function in OCI](#%C2%A0Creating%20the%20Function%20in%20OCI)
  - [Invoking the Function](#Invoking%20the%20Function)
  - [Updating the Function](#Updating%20the%20Function)
- [Bonus: Deploying as a Native Image](#Deploy%20as%20Native%20Image)
- [Performance](#Performance)
- [Summary](#Summary)

## Create Secrets 

The Micronaut Oracle Cloud module provides an excellent option for safely and securely storing sensitive stuff. The [docs](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide/#vault) are thorough, so refer to them as needed. I hope you're already familiar with creating secrets in an [OCI vault](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm), so I won't cover that entire process to keep this post on the shorter side. We will need four secrets in a vault for our serverless function: 

1.  `ATP_USER`: the user for your Autonomous DB instance
2.  `ATP_PASSWORD`: the password for your Autonomous DB instance.
3.  `ATP_OCID`: the Autonomous DB instance `OCID`
4.  `ATP_WALLET_PASSWORD`: password to encrypt the keys inside the wallet; must be at least eight characters long and must include at least one letter and either one numeric character or one special character

Name these secrets as shown above since Micronaut will look for secrets with these names to create config variables in our application below.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/19fd331f-12aa-44f7-9158-693b50574d7c/upload_ef7c1b63132790ca2136502479bf6cf0.png)

Once you have created your secrets in your vault, collect the vault OCID and the OCID for your vault's compartment. 

## Creating the Micronaut Function Application 

Next, let's create the Java application for our serverless function. If you are not familiar with Micronaut, don't stress! There isn't much difference between Micronaut and other popular Java frameworks, and this function will serve as a good, gentle introduction to the framework for you! We'll use the Micronaut CLI to create the function, so make sure you have it [installed locally](https://micronaut-projects.github.io/micronaut-starter/latest/guide/#installation).

```bash
$ mn create-function-app atp-auto-wallet-fn --features oracle-function
$ cd atp-auto-wallet-fn
```
If you don't want to install the CLI, another option is to use [Micronaut Launch](https://launch.micronaut.io/) to create the application. If you choose that route, enter the following inputs to generate the app, and then download and unzip it to a local directory.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/0ab183bd-a541-4316-b332-8bbf945ec013/upload_d5f2e42af81b4cb8bfd44b8579320da0.png)

Now that we've generated the Micronaut application let's open it up in our favorite IDE and start configuring it.

### Configuring the Application 

To configure the application, we'll need to change the build script. Open up `build.gradle` and look for the following entries:

```groovy
dockerBuild {
    images = ["[REGION].ocir.io/[TENANCY]/[REPO]/$project.name:$project.version"]
}

dockerBuildNative {
    images = ["[REGION].ocir.io/[TENANCY]/[REPO]/$project.name-native:$project.version"]
}
```
The image path in these blocks defines the location within OCIR (OCI Container Registry), where the Docker image that we will ultimately produce is stored. Substitute the proper values for `[REGION]`, `[TENANCY]` and `[REPO]` but leave the values that use the `$` token notation as they will be populated when we call the task later on. Once I updated them, my entries looked like this:

```groovy
dockerBuild {
    images = ["phx.ocir.io/toddrsharp/atp-auto-wallet/$project.name:$project.version"]
}

dockerBuildNative {
    images = ["phx.ocir.io/toddrsharp/atp-auto-wallet/$project.name-native:$project.version"]
}
```
Next, we'll need to add some dependencies. 

```groovy
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-atp") //1
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-sdk") //2
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-vault") //3
implementation("io.micronaut.sql:micronaut-jdbc-ucp") //4
implementation("com.oracle.database.jdbc:ojdbc11-production:21.1.0.0") //5
```
1.  The Autonomous DB module
2.  The OCI SDK module (required by vault)
3.  The OCI Vault module (used to retrieve and decode secrets)
4.  The UCP module for connection pooling
5.  The OJDBC driver

To use the OCI Vault integration, we need to create a new file at `/src/main/resources/bootstrap.yml`. We need to populate the `OCID` values for our vault and vault compartment that we collected above in this file. I have also entered the path to my local OCI config, my profile, and region so that I can test this function out locally. 

```yaml
micronaut:
  application:
    name: atpAutoWalletFn
  config-client:
    enabled: true
oci:
  vault:
    config:
      enabled: true
    vaults:
      - ocid: ocid1.vault.oc1.phx...
        compartment-ocid: ocid1.compartment.oc1...
    path-to-config: ~/.oci/config
    profile: DEFAULT
    region: US-PHOENIX-1
```
**Note:** There is no need to include your OCI config file in the Docker image! Configure [resource principal authentication](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm) for your tenancy, and the Micronaut module will properly utilize that authentication protocol when you deploy your OCI Function.

Now we must add a datasource to our configuration located at `/src/main/resources/application.yml`. You can copy and paste the config below, assuming you've created the secrets in your vault with the matching names mentioned above. 

```yaml
micronaut:
  application:
    name: atpAutoWalletFn
datasources:
  default:
    dialect: ORACLE
    username: ${ATP_USER}
    password: ${ATP_PASSWORD}
    ocid: ${ATP_OCID}
    walletPassword: ${ATP_WALLET_PASSWORD}
    connection-factory-class-name: oracle.jdbc.pool.OracleDataSource
```
Micronaut will retrieve the secrets from your vault, decode them, and populate the datasource configuration with the proper values at runtime.

### Modifying the Function To Query the Database 

The next step is to change the function itself to query the database. If you open up the main function class (located at `/src/main/java/atp/auto/wallet/fn/Function.java`), your function should look like so:

```java
@Singleton
public class Function extends OciFunction {
    @Inject
    TenancyIdProvider tenantIdProvider;

    @ReflectiveAccess
    public String handleRequest() {
        String tenancyId = tenantIdProvider.getTenancyId();
        return "Your tenancy is: " + tenancyId;
    }
}
```
We can delete the injected `TenancyIdProvider` and the body of the `handleRequest()` method, since we will not need them for our function. To perform our database query, we can inject a `DataSource` bean and use that bean to execute our query in the `handleRequest()` method. A handy helper function to convert the `ResultSet` to a `List` and some serialization with Jackson, and we're able to return a JSON serialized list of `Map` objects from the function. 

```java
@Singleton
public class Function extends OciFunction {
    @Inject
    DataSource dataSource;

    @ReflectiveAccess
    public String handleRequest() throws SQLException, JsonProcessingException {
        Connection conn = dataSource.getConnection();
        Statement statement = conn.createStatement();
        ResultSet resultSet = statement.executeQuery("select id, first_name, last_name from users");
        return new ObjectMapper().writeValueAsString(convertResultSetToList(resultSet));
    }

    private List<HashMap<String,Object>> convertResultSetToList(ResultSet rs) throws SQLException {
        ResultSetMetaData md = rs.getMetaData();
        int columns = md.getColumnCount();
        List<HashMap<String,Object>> list = new ArrayList<HashMap<String,Object>>();
        while (rs.next()) {
            HashMap<String,Object> row = new HashMap<String, Object>(columns);
            for(int i=1; i<=columns; ++i) {
                row.put(md.getColumnName(i),rs.getObject(i));
            }
            list.add(row);
        }
        return list;
    }

}
```
### Testing the Function 

Micronaut was kind enough to create a test for us, which we can extend as needed. We can find the test at `/src/test/java/atp/auto/wallet/fn/FunctionTest.java`. Here's how it looks:

```java
public class FunctionTest {
    @Test
    public void testFunction() {
        FnTestingRule rule = FnTestingRule.createDefault();
        rule.givenEvent().enqueue();
        rule.thenRun(Function.class, "handleRequest");
        String result = rule.getOnlyResult().getBodyAsString();
        assertNotNull(result);
    }
}
```
Since this is just a demo, I'm comfortable simply testing to ensure the invoked function result is not null. Feel free to update your test for your specific business requirements. Next, run the test with:

```bash
$ ./gradlew test
```
And once it is complete, open the report located in `build/reports/tests/test/index.html`. Here is how a successful test report should look.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5e936cb3-355d-4e4d-9794-960c04e1ada5/upload_71c17eaeb0fd9d3d1b7bae8cd410012c.png)

### Building & Pushing the Docker Container 

We're now ready to build a Docker image from our application and push it to our Container Registry. To do that, run the following commands:

```bash
$ ./gradlew dockerBuild
$ ./gradlew dockerPush
```
The output of the `dockerPush` command should look similar to this:

```bash
> Task :dockerPush
Pushing image 'phx.ocir.io/toddrsharp/atp-auto-wallet/atp-auto-wallet-fn:0.1'.
```
The message above tells us that our image is now happily residing in the OCI Container Registry. Now we can move on to creating an 'application' in OCI.

## Creating the Application in OCI 

Oracle Functions require an associated "application" entity in the cloud. Oracle Functions uses the application to share configuration for grouped functions. You can create one via the OCI Console or the CLI. I find the CLI easier, but this does require you to know the proper `OCID` for the subnet that you want to associate with the application. Because I often use the OCI CLI, I have created several environment variables to store often-used values, so I don't have to remember or look them up when I need them. In this case, I plugged in my `OCI_FAAS_SUBNET`  and `OCI_FAAS_COMPARTMENT` environment variables.

```bash
$ oci fn application create \
  --display-name=atp-wallet-demo \
  --subnet-ids='["'$OCI_FAAS_SUBNET'"]' \
  --compartment-id=$OCI_FAAS_COMPARTMENT
```
Your response should look similar to this JSON output.

```json
{
  "data": {
    "compartment-id": "ocid1.compartment.oc1...",
    "config": {},
    "defined-tags": {
      "Oracle-Tags": {
        "CreatedBy": "[redacted]",
        "CreatedOn": "2022-03-29T17:07:43.860Z"
      }
    },
    "display-name": "atp-wallet-demo",
    "freeform-tags": {},
    "id": "ocid1.fnapp.oc1.phx...",
    "image-policy-config": null,
    "lifecycle-state": "ACTIVE",
    "network-security-group-ids": [],
    "subnet-ids": [
      "ocid1.subnet.oc1.phx..."
    ],
    "syslog-url": "",
    "time-created": "2022-03-29T17:07:44.502000+00:00",
    "time-updated": "2022-03-29T17:07:44.502000+00:00",
    "trace-config": {
      "domain-id": "",
      "is-enabled": false
    }
  },
  "etag": "de9758b214f461ac549683b708118fd345378c80f1edd8120288d472817f0934"
}
```
We'll need to use the application ID later, so copy the "id" from the response JSON that uses the format `ocid1.fnapp` and keep it handy.

## Creating the Function in OCI 

Now it's time to create the serverless function in OCI that uses the Docker image that we produced from our Micronaut Application. Again, I am using the CLI. I'm plugging in the OCI application "id" that we just obtained in the previous section. We can name this function whatever we would like. The function should run fine on less memory, but you can't go wrong with granting 2GB of RAM. Finally, make sure that the `--image` argument matches the location to the Docker image in the OCI Container Registry.

```bash
$ oci fn function create \
  --application-id=ocid1.fnapp.oc1.phx... \
  --display-name=atp-auto-wallet-fn \
  --memory-in-mbs=2048 \
  --image=phx.ocir.io/toddrsharp/atp-auto-wallet/atp-auto-wallet-fn:0.1
```
The result of the command above will return another JSON response. That response will look close to this:

```json
{
  "data": {
    "application-id": "ocid1.fnapp.oc1.phx...",
    "compartment-id": "ocid1.compartment.oc1...",
    "config": {},
    "defined-tags": {
      "Oracle-Tags": {
        "CreatedBy": "[redacted]",
        "CreatedOn": "2022-03-29T17:10:35.939Z"
      }
    },
    "display-name": "atp-auto-wallet-fn",
    "freeform-tags": {},
    "id": "ocid1.fnfunc.oc1.phx...",
    "image": "phx.ocir.io/toddrsharp/atp-auto-wallet/atp-auto-wallet-fn:0.13",
    "image-digest": "sha256:e66ab37e888a12e3ec961e4a26a758891afa1b4b6520e0369af44ba933d75290",
    "invoke-endpoint": "https://khenedvczma.us-phoenix-1.functions.oci.oraclecloud.com",
    "lifecycle-state": "ACTIVE",
    "memory-in-mbs": 2048,
    "time-created": "2022-03-29T17:10:36.185000+00:00",
    "time-updated": "2022-03-29T17:10:36.185000+00:00",
    "timeout-in-seconds": 30,
    "trace-config": {
      "is-enabled": false
    }
  },
  "etag": "234ac973ed5753b335f97f18ff2e81c6a9fb578b5d5220196ab2e52acaba09ab"
}
```
We'll need the function "id" (`ocid1.fnfunc...`) in just a moment, so keep it handy.

### Invoking the Function 

We'll use the OCI CLI to invoke the function to ensure that everything is working as expected.

```bash
$ oci fn function invoke \
  --function-id=ocid1.fnfunc.oc1.phx... \
  --body="" \
  --file -
```
Here's an example of the JSON that my function returned from my test invocation (prettified with `jq`):

```json
[
  {
    "LAST_NAME": "Sharp",
    "FIRST_NAME": "Todd",
    "ID": "CE51F8AEFBD6C772E0539914000A4500"
  },
  {
    "LAST_NAME": "Sharp",
    "FIRST_NAME": "Rhonda",
    "ID": "CE51F8AEFBD7C772E0539914000A4500"
  }
]
```
### Updating the Function 

Of course, your function could change over time. When that happens, update the Micronaut application as necessary. When it's time to deploy the updated changes, make sure that you first update the version number in `build.gradle`.

```groovy
version = "0.2"
```
And once you've built and pushed the Docker image, use the OCI CLI to point to the updated image.

```bash
$ oci fn function update \
  --function-id= ocid1.fnfunc.oc1.phx... \
  --image=phx.ocir.io/toddrsharp/atp-auto-wallet/atp-auto-wallet-fn:0.2
```
## Bonus: Deploying as a Native Image 

We can also build and deploy our function as a GraalVM native image as a bonus. This native image will result in improved performance for our function. To do that, we'll have to make a slight modification to the `graalvmNative` block in `build.gradle`. Right now, it should look like the following:

```groovy
graalvmNative {
    binaries.configureEach {
        buildArgs.addAll(
             "-H:+StaticExecutableWithDynamicLibC",
             "-Dfn.handler=atp.auto.wallet.fn.Function::handleRequest",
             "--initialize-at-build-time=atp.auto.wallet.fn"
        )
    }
}
```
We'll need to add an argument to this section for a `reflectionconfig` JSON file. Modify the above block to look like the block below.

```groovy
graalvmNative {
    binaries.configureEach {
        buildArgs.addAll(
             "-H:+StaticExecutableWithDynamicLibC",
             "-Dfn.handler=atp.auto.wallet.fn.Function::handleRequest",
             "--initialize-at-build-time=atp.auto.wallet.fn",
             "-H:ReflectionConfigurationFiles=/home/app/resources/reflectionconfig.json"
        )
    }
}
```
Now create a file located at `/src/main/resources/reflectionconfig.json` and populate it with the JSON below. This file tells GraalVM to enable reflective access for this necessary class.

```json
[{
  "name" : "oracle.security.crypto.cert.ext.ExtKeyUsageExtension",
  "allDeclaredConstructors" : true,
  "allPublicConstructors" : true,
  "allDeclaredFields" : true,
  "allPublicFields" : true,
  "allDeclaredMethods" : true,
  "allPublicMethods" : true
}]
```
**Heads Up!** Soon, it will not be necessary to indicate the reflection config shown above manually. Keep an eye on [this issue](https://github.com/micronaut-projects/micronaut-oracle-cloud/pull/364) for more information.

To build and push the native image, use the following Gradle tasks.

```bash
$ ./gradlew dockerBuildNative
$ ./gradlew dockerPushNative
```
Now update the OCI Function to use the native Docker image.

```bash
$ oci fn function update \
  --function-id= ocid1.fnfunc.oc1.phx... \
  --image=phx.ocir.io/toddrsharp/atp-auto-wallet/atp-auto-wallet-fn-native:0.3
```
And test it by invoking. 

```bash
$ oci fn function invoke \
  --function-id=ocid1.fnfunc.oc1.phx... \
  --body="" \
  --file -
```
## Performance 

GraalVM native images provide significantly improved performance versus running our function on the JVM itself.

I ran some rudimentary tests to compare this function's non-native and native implementations for this demo. Further optimizations are possible, but just by deploying this function as a native image, the cold start time improved by 55%.

```log
#non-native
0.53s user 0.22s system 4% cpu 18.521 total
#native
0.48s user 0.18s system 8% cpu 8.315 total
```
When looking at hot starts, performance was increased by 23%.

```log
#non-native
0.49s user 0.18s system 25% cpu 2.590 total
#native
0.45s user 0.16s system 30% cpu 2.042 total
```
## Summary 

In this post, we created and deployed a Micronaut application as an OCI Function that connects to and queries an Autonomous DB instance. Another option that you might want to consider is integrating with an OCI API Gateway for HTTPS serverless functions. Check out the [Micronaut Oracle Cloud module documentation](https://micronaut-projects.github.io/micronaut-oracle-cloud/latest/guide/#httpFunctions) to learn more about that.

Image by [Bethany Drouin](https://pixabay.com/users/bsdrouin-5016447/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=2402637) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=2402637)
