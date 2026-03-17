---
title: "Oracle Functions - Connecting To An ATP Database Revisited"
slug: "oracle-functions-connecting-to-an-atp-database-revisited"
author: "Todd Sharp"
date: 2020-02-11
summary: "In this post, we'll take a look at how to connect up your Oracle Function to your Autonomous DB instance to query and persist data from your serverless function."
tags: ["Cloud", "Java"]
keywords: "serverless, Java, Cloud, AUTONOMOUS"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/eb72d7cd-0766-4b99-a2ad-b21ea4460cef/banner_sippakorn_yamkasikorn_1j0h3m7i0ms_unsplash.jpg"
---

Last August, I blogged about [how to connect up your Oracle Function serverless functions to your Autonomous DB instance](/posts/oracle-functions-connecting-to-an-atp-database). Since that post was published a few things have happened to make this process quite a bit easier, so I wanted to put together an updated version of that post to show you the latest recommended method for getting data in and out of your cloud DB instances from your serverless functions.

**Heads Up!** This process is currently the recommended approach for connecting to your ATP instance from a serverless function, but is certainly subject to change. This post will be updated or superseded if things change again! 

Here's how we'll tackle this challenge:

1.  Download ATP Wallet 
2.  Upload wallet to a **Private Bucket **in Object Storage
3.  Configure Resource Principals for Oracle Functions
4.  Create function, including OCI SDK and OJDBC drivers
5.  Download wallet to function container at runtime
6.  Use wallet for connection 

If you'd like to see a complete example, the [full code for this blog post is available on GitHub](https://github.com/recursivecodes/oci-adb-jdbc-java)

## Download Wallet

So let's get started walking through the process. The first step is to download your ATP wallet. You can do this via the console dashboard:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/eb72d7cd-0766-4b99-a2ad-b21ea4460cef/2020_02_10_14_58_16.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/eb72d7cd-0766-4b99-a2ad-b21ea4460cef/2020_02_10_14_58_33.png)

Or you can use the OCI CLI to download the wallet:
```bash
oci db autonomous-data-warehouse generate-wallet \
--autonomous-data-warehouse-id ocid1.autonomousdatabase.oc1.phx... \
--password Str0ngPa$$word1 \
--file /projects/fn/oci-adb-jdbc-java/wallet.zip
```



## Upload Wallet Contents To Object Storage

Now that you've got a local copy of your wallet, create a **private** **bucket** in Object Storage, unzip the wallet and upload each file from the wallet into the **private bucket.**

**Note**: Did I mention that the bucket should be private?

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/eb72d7cd-0766-4b99-a2ad-b21ea4460cef/2020_02_10_14_57_16.png)

## Configure Dynamic Group

We're going to take advantage of Resource Principals for our function so that we do not have to include any OCI credentials in order to use the OCI SDK. To do this, you'll need a **Dynamic Group**. I like to create one for the compartment that I use for all of my functions. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/eb72d7cd-0766-4b99-a2ad-b21ea4460cef/2020_02_10_14_56_27.png)

Next, assign a policy to the dynamic group so that it is able to read the bucket where your wallet files are stored.

 ![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/eb72d7cd-0766-4b99-a2ad-b21ea4460cef/2020_02_10_15_00_40.png)

## Create Application & Function

Now let's create an application for our function and create the function itself:
```bash
fn create app oci-adb-jdbc-java-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx..."]'
fn init --runtime java oci-adb-jdbc-java
cd oci-adb-jdbc-java
```



Add some configuration to the application, substituting your values as appropriate. Of course, It's a better idea to use KMS to encrypt your password than to store it in a config variable in plain text. You can [use the Oracle Cloud KMS service instead to keep your passwords encrypted](/posts/oracle-functions-using-key-management-to-encrypt-and-decrypt-configuration-variables).
```bash
fn config app oci-adb-jdbc-java-app DB_PASSWORD [password]
fn config app oci-adb-jdbc-java-app DB_URL jdbc:oracle:thin:\@[tns name]\?TNS_ADMIN=/tmp/wallet 
fn config app oci-adb-jdbc-java-app DB_USER [user]
fn config app oci-adb-jdbc-java-app NAMESPACE [name]
fn config app oci-adb-jdbc-java-app BUCKET_NAME [name]
```



**Warning**: Do not modify the path to `TNS_ADMIN` in the DB_URL config variable. This is the location within the Docker container that the wallet files will be downloaded to.

Now, open up your `pom.xml` file and add our dependencies:
```xml
<dependency>
    <groupId>com.oracle.ojdbc</groupId>
    <artifactId>ojdbc8</artifactId>
    <version>19.3.0.0</version>
</dependency>
<dependency>
    <groupId>com.oracle.oci.sdk</groupId>
    <artifactId>oci-java-sdk-full</artifactId>
    <version>1.12.5</version>
</dependency>
<dependency>
    <groupId>javax.activation</groupId>
    <artifactId>activation</artifactId>
    <version>1.1.1</version>
</dependency>
```



Open up `func.yaml` and add a few values for timeouts and memory to the existing config:
```yaml
memory: 1024
timeout: 120
```



## Write Function Code

Now that our setup and configuration is complete, let's move on to the code itself. Open up the `HelloFunction.java` file that was created with your application.

Let's declare some variables for use in our class:
```java
private PoolDataSource poolDataSource;

private final File walletDir = new File("/tmp", "wallet");
private final String namespace = System.getenv().get("NAMESPACE");
private final String bucketName = System.getenv().get("BUCKET_NAME");
private final String dbUser = System.getenv().get("DB_USER");
private final String dbPassword = System.getenv().get("DB_PASSWORD");
private final String dbUrl = System.getenv().get("DB_URL");

final static String CONN_FACTORY_CLASS_NAME="oracle.jdbc.pool.OracleDataSource";
```



Now, add a constructor. Here is where we will set up our pool datasource that will allow us to use connection pooling for our queries. This datasource (and the downloaded wallet) will live across invocations, making things quicker for "warm" invocations.
```java
public HelloFunction() {
    poolDataSource = PoolDataSourceFactory.getPoolDataSource();
    try {
        poolDataSource.setConnectionFactoryClassName(CONN_FACTORY_CLASS_NAME);
        poolDataSource.setURL(dbUrl);
        poolDataSource.setUser(dbUser);
        poolDataSource.setPassword(dbPassword);
        poolDataSource.setConnectionPoolName("UCP_POOL");
    }
    catch (SQLException e) {
        e.printStackTrace();
    }
}
```



Inside of our `handleRequest()` function, the first thing we'll do is check for a wallet and download it if it does not yet exist in the container:
```java
if( needWalletDownload() ) {
    System.out.println("Start wallet download...");
    downloadWallet();
    System.out.println("End wallet download!");
}
```



The `needWalletDownload()` function is just as simple as you'd expect it to be:
```java
private Boolean needWalletDownload() {
    if( walletDir.exists() ) {
        System.out.println("Wallet exists, don't download it again...");
        return false;
    }
    else {
        System.out.println("Didn't find a wallet, let's download one...");
        walletDir.mkdirs();
        return true;
    }
}
```



And here's the `downloadWallet()` method. As I mentioned earlier, we're using a Resource Principal as our auth provider. Here's how this function works:

- Create an Object Storage client
- List all objects in Wallet Bucket
- Loop over objects, downloading each object into the container's /tmp/wallet directory

Pretty simple! Here's the code:
```java
private void downloadWallet() {
    // Use Resource Principal
    final ResourcePrincipalAuthenticationDetailsProvider provider =
            ResourcePrincipalAuthenticationDetailsProvider.builder().build();

    ObjectStorage client = new ObjectStorageClient(provider);
    client.setRegion(Region.US_PHOENIX_1);

    System.out.println("Retrieving a list of all objects in /" + namespace + "/" + bucketName + "...");
    // List all objects in wallet bucket
    ListObjectsRequest listObjectsRequest = ListObjectsRequest.builder()
            .namespaceName(namespace)
            .bucketName(bucketName)
            .build();
    ListObjectsResponse listObjectsResponse = client.listObjects(listObjectsRequest);
    System.out.println("List retrieved. Starting download of each object...");

    // Iterate over each wallet file, downloading it to the Function's Docker container
    listObjectsResponse.getListObjects().getObjects().stream().forEach(objectSummary -> {
        System.out.println("Downloading wallet file: [" + objectSummary.getName() + "]");

        GetObjectRequest objectRequest = GetObjectRequest.builder()
                .namespaceName(namespace)
                .bucketName(bucketName)
                .objectName(objectSummary.getName())
                .build();
        GetObjectResponse objectResponse = client.getObject(objectRequest);

        try {
            File f = new File(walletDir + "/" + objectSummary.getName());
            FileUtils.copyToFile( objectResponse.getInputStream(), f );
            System.out.println("Stored wallet file: " + f.getAbsolutePath());
        } catch (IOException e) {
            e.printStackTrace();
        }
    });
}
```



And back in the `handleRequest()`, it's now just a matter of grabbing a connection, creating our statement and executing the query:
```java
Connection conn = poolDataSource.getConnection();
conn.setAutoCommit(false);

Statement statement = conn.createStatement();
ResultSet resultSet = statement.executeQuery("select * from employees");
List<HashMap<String, Object>> recordList = convertResultSetToList(resultSet);
System.out.println( new ObjectMapper().writeValueAsString(recordList) );
System.out.println("***");

conn.close();
```



## Deploy & Test Function

Once you've put it all together, invoke your function with:
```bash
fn deploy --app oci-adb-jdbc-java-app
fn invoke oci-adb-jdbc-java-app oci-adb-jdbc-java
```



If you've set up logging, you can take a look at the output:
```log
Feb 11 11:29:45   Setting up pool data source
Feb 11 11:29:45   Pool data source setup...
Feb 11 11:29:45   Didn't find a wallet, let's download one...
Feb 11 11:29:45   Start wallet download...
Feb 11 11:29:45   SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
Feb 11 11:29:45   SLF4J: Defaulting to no-operation (NOP) logger implementation
Feb 11 11:29:45   SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
Feb 11 11:29:47   Retrieving a list of all objects in /toddrsharp/wallet...
Feb 11 11:29:49   List retrieved. Starting download of each object...
Feb 11 11:29:49   Downloading wallet file: [cwallet.sso]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/cwallet.sso
Feb 11 11:29:49   Downloading wallet file: [ewallet.p12]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/ewallet.p12
Feb 11 11:29:49   Downloading wallet file: [keystore.jks]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/keystore.jks
Feb 11 11:29:49   Downloading wallet file: [ojdbc.properties]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/ojdbc.properties
Feb 11 11:29:49   Downloading wallet file: [sqlnet.ora]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/sqlnet.ora
Feb 11 11:29:49   Downloading wallet file: [tnsnames.ora]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/tnsnames.ora
Feb 11 11:29:49   Downloading wallet file: [truststore.jks]
Feb 11 11:29:49   Stored wallet file: /tmp/wallet/truststore.jks
Feb 11 11:29:49   End wallet download!
Feb 11 11:29:52   [{"EMP_NAME":"abhishek","EMP_EMAIL":"a@b.com","EMP_DEPT":"Support Operationz"},{"EMP_NAME":"user1","EMP_EMAIL":"a@a.com","EMP_DEPT":"dept1"},{"EMP_NAME":"user2","EMP_EMAIL":"b@b.com","EMP_DEPT":"dept2"},{"EMP_NAME":"Bob Smith","EMP_EMAIL":"bob@nowhere.com","EMP_DEPT":"HR"},{"EMP_NAME":"ironman","EMP_EMAIL":"tony@starkindustries.co.uk","EMP_DEPT":"logisticz"},{"EMP_NAME":"ironman","EMP_EMAIL":"tony@starkindustries.com","EMP_DEPT":"logistics"}]
```



The "cold start" invocation will take a few extra seconds to download the wallet and configure the connection pool, but subsequent invocations will be lightning quick!

## Summary

That's what it takes to connect to your Autonomous DB instance from your Oracle Function. If you're unsure how it all comes together, [take a look at the full example on GitHub](https://github.com/recursivecodes/oci-adb-jdbc-java).

If you'd like to see a complete example, the [full code for this blog post is available on GitHub](https://github.com/recursivecodes/oci-adb-jdbc-java)

Photo by [sippakorn yamkasikorn](https://unsplash.com/@sippakorn?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/thumbs-up?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
