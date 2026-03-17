---
title: "Easy and Secure Oracle Database Connections With Database Tools"
slug: "easy-and-secure-oracle-database-connections-with-database-tools"
author: "Todd Sharp"
date: 2021-11-17
summary: "In this post, we'll look at the brand new Database Tools service in the Oracle Cloud. We'll see how to store our DB connection info securely in the cloud and how to use them later on."
tags: ["APIs", "Cloud", "Java", "Micronaut", "Oracle"]
keywords: "database,cloud,oracle,java,micronaut"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/hunter-haley-s8OO2-t-HmQ-unsplash.jpeg"
---

There's a brand new tool in town, and it's ready to make your life a whole lot easier if you work with Oracle DB in the cloud. It's called "Database Tools", and despite the rather boring sounding name, I can assure you that this service is super, extra, magnificently awesome! If you're a doc reader, [have at 'em](https://docs.oracle.com/en-us/iaas/Content/Database-Tools/dbtools_topic-overview.htm). But if you're like me - an adventurer who jumps in head first - then let's take a deep dive into Database Tools and see how to use them!

For your navigational pleasure, here is a Table of Contents:

- [What Does It Do?](#What%20Does%20It%20Do?)
- [How?](#How?)
- [Create a Vault](#Create%20Vault)
  - [Create Key](#Create%20Key)
- [Create a Connection With Database Tools](#Create%20Connection)
- [Using the Connection](#Use%20Connection)
  - [Launching a SQL Worksheet](#Launch%20SQL%20Worksheet)
  - [Launching SQLcl in Cloud Shell](#Launch%20SQLcl%20in%20Cloud%20Shell)
- [Connecting and Querying Autonomous DB From Java](#Connect%20and%20Query%20Autonomous%20DB%20From%20Java)
  - [Dependencies](#Dependencies)
  - [Retrieving Database Connection Info](#Retrieve%20Database%20Connection%20Info)
  - [Creating a Datasource and Querying It](#Create%20Datasource%20and%20Query%20It)
- [Summary](#Summary)

## What Does It Do? 

Database Tools lets you create "Connections" to existing databases. These connections are a way to store all of the credentials that you need to connect to that database in a safe, secure place in the cloud. Why? Because security is important! Storing credentials offline can be a security risk and when you create a connection in the Oracle Cloud you can be assured that your credentials are encrypted and safe. Additionally, once they are created they can then be used to connect to other services in the Oracle Cloud like SQL Worksheets and SQLcl in the Cloud Shell without having to type a single username or password (and without downloading a wallet!).\

## How? 

Keep reading!

## Create a Vault 

Before we create a connection, we'll need to create (or make sure we already have) a 'Vault' in the Oracle Cloud. To do this, search for 'Vault' and select 'Vault' under 'Services'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/dc53c44e-50c8-487d-b198-59ac48942a84/upload_cc0668ab4ebd9037015d38db6268edd3.png)

Click 'Create Vault' on the Vault list page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7e9f8306-6a13-48da-8a1c-377fb9209c6c/upload_815256d2d3d3f66031a5cc84c06fe424.png)

Name it.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/021bf208-3e0c-4244-b432-92ba58c05f6c/upload_148022bdc8bc90fd94c24318da1a9201.png)

Click 'Create' and wait a few minutes (security is paramount, but not always fast). 

### Create Key 

Once the vault is created, click on 'Create Key' Under 'Master Encryption Keys' in the vault details.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f18f4678-1bbe-494d-817a-ea3bcdc325e6/upload_5c057b5a1514459e928a3458ab66d272.png)

In the key details dialog, name it (#1), choose 'RSA\...' (the key must be asymmetric - #2), and a Key Shape of '2048 bits'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/90c4411d-212c-4359-b091-856ab2a014ef/upload_31b430b42807e69bb48fa98f67e089d9.png)

## Create a Connection With Database Tools 

When the vault is ready, search for 'database tools' and select 'Connections'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/75ea7d88-36c5-4bfa-b466-e00c71d6cc21/upload_4cb7068aca331b52a964ec2d75f31005.png)

Click 'Create Connection'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/fde93464-2fae-43bf-94ad-189f98959dad/upload_c5385e800da2ae66713bc9ba27055e74.png)

Name it (#1), select the compartment used to store it (#2), choose 'Select Database' (#3 - since we're planning on using this with Autonomous DB), choose 'Autonomous Database' (#4), choose the DB's compartment (#5), enter the 'User Name' (#6), and click 'Create Password Secret' (#7).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1093604a-72b3-4c1d-a16c-4719d57d11ba/upload_0f4a5a932d8b56d9879682f875f235ba.png)

In the 'Create Password Secret' dialog, name the secret, choose the vault and encryption key, and enter/confirm the password.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b0152411-9164-416d-97dc-1a301283a3a1/upload_fcb15d02b7cf0897eb7c55ac1c59d414.png)

Uncheck 'Network Connectivity via Private Endpoint' (unless you intend to use a private endpoint).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/77833005-5b8d-4509-ab92-02b6839f107f/upload_735c9ac256e2c8bdc0efab5c8a58f3a8.png)

On step 2, select 'SSO Wallet' under 'Wallet Format'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9af5ab91-b4f0-47a3-8390-47ab04f8350f/upload_cb766a1c8a833069212d26c97091100e.png)

Click 'Create Wallet Content Secret' and then name your secret (#1), choose the vault to store it in (#2), the key to use to encrypt the secret (#3), and select 'Retrieve regional auto login wallet from Autonomous Database' to have the secret generated automatically for you (how nice!).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/cced2c1e-7eda-437e-82c1-67332b6e5d81/upload_0a33b91dcefe80fd15188259fd6a6337.png)

Click 'Create' and in just a few moments your Database Connection is ready to use!

## Using the Connection 

Now we can use the connection! On the connection details page, you can click either 'SQL Worksheet' or 'Launch SQLcl' to use the connection immediately.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a6fb68a4-36f5-4e12-b4c9-4004c1a903dd/upload_e6ef04679b4047f490ad9f8ae55aa73f.png)

### Launching a SQL Worksheet 

SQL Worksheet is a lightweight version of SQL Developer Web that allows you to save, load, and run simple queries against a connection. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/42934085-1f20-4d46-9834-7b5b69594516/upload_6dc3e90ae15b60c271105dfd7372e70d.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/17a703c9-cf10-4c69-9954-a984885d4e62/upload_9c9977c69403bb84159d2f9205338f46.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/60899ff4-054b-4cd5-b8cf-17069a0ccc7e/upload_4c8d8523ece7082b6e2a3fe374da2bad.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7cf39cb1-2ae5-4074-b0a9-b296fc286363/upload_60b2a0161c93c008844d88454fb17107.png)

### Launching SQLcl in Cloud Shell 

If your preference is command lines, clicking 'Launch SQLcl' will open Cloud Shell and automatically configure and connect to the database you specified in the connection. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/19c78076-1ece-492a-aa5b-d2b3eed05d25/upload_505d556cbb513428e16e32e3888e6766.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/59f5994c-83f1-44b7-a00f-f04345f638e1/upload_231355253f9b1831308f21d4550eaedf.png)

## Connecting and Querying Autonomous DB From Java 

In cooler news for developers, Database Tools Connections can be retrieved via the OCI Java SDK. This means no storing credentials in code or environment variables or manually creating vault secrets for each and storing the OCIDs for each vault secret. You just need the OCID of the Database Tools Connection and the SDK does the rest! Let's look at an example using Java to retrieve the connection and use it to query Autonomous DB.

### Dependencies 

First, you'll need some dependencies. We need a few modules from the OCI Java SDK (to retrieve the connection and the secret content).
```groovy
implementation 'com.oracle.oci.sdk:oci-java-sdk-common:2.8.1'
implementation 'com.oracle.oci.sdk:oci-java-sdk-databasetools:2.8.1'
implementation 'com.oracle.oci.sdk:oci-java-sdk-secrets:2.8.1'
```



And we'll need the OJDBC driver:
```groovy
implementation("com.oracle.database.jdbc:ojdbc11-production:21.1.0.0")
```



### Retrieving Database Connection Info 

Next, create a class. I'm calling mine `Demo.java`. We'll need to pass in the OCID of the connection that we created earlier, and in the constructor, we'll set up a few clients to make calls to the SDK.
```java
public class Demo {

    private final String connectionId;
    DatabaseToolsClient databaseToolsClient;
    SecretsClient secretsClient;

    public Demo(String connectionId) throws IOException {
        this.connectionId = connectionId;
        AbstractAuthenticationDetailsProvider provider = new ConfigFileAuthenticationDetailsProvider("DEFAULT");
        databaseToolsClient = DatabaseToolsClient.builder().build(provider);
        secretsClient = SecretsClient.builder().build(provider);
    }
}
```



Instead of returning the secrets directly, the SDK will return OCIDs pointing to the secret in the vault. Once the content is retrieved, we'll need to decode them from Base64, so create an instance of the `Base64.Decoder`.
```java
/* for decoding secrets after they are retrieved */
Base64.Decoder decoder = Base64.getDecoder();
```



Now we can construct a request to get the `DatabaseToolsConnection` and use the client to send the request.
```java
/* get database tools connection */
GetDatabaseToolsConnectionRequest connectionRequest =
        GetDatabaseToolsConnectionRequest.builder()
        .databaseToolsConnectionId(connectionId)
        .build();
GetDatabaseToolsConnectionResponse connectionResponse = databaseToolsClient
        .getDatabaseToolsConnection(connectionRequest);
DatabaseToolsConnectionOracleDatabase databaseToolsConnection =
        (DatabaseToolsConnectionOracleDatabase) connectionResponse
        .getDatabaseToolsConnection();
```



Grab the connect string and username:
```java
/* get connect string from dbtools connection */
String connectionString = databaseToolsConnection.getConnectionString();
System.out.printf("Connection String: %s %n", connectionString);

/* get username from dbtools connection */
String username = databaseToolsConnection.getUserName();
System.out.printf("Username: %s %n", username);
```



If you're interested, grab the KeyStore type:
```java
List<DatabaseToolsKeyStore> keyStores = databaseToolsConnection.getKeyStores();
KeyStoreType keyStoreType = keyStores.get(0).getKeyStoreType();
System.out.printf("KeyStore Type: %s %n", keyStoreType);
```



Next, grab the KeyStore secret contents OCID and make a request via the `SecretsClient` to retrieve the content and decode it.
```java
DatabaseToolsKeyStoreContentSecretId keyStoreSecretId =
        (DatabaseToolsKeyStoreContentSecretId) keyStores
        .get(0)
        .getKeyStoreContent();
String keyStoreContentSecretId = keyStoreSecretId.getSecretId();
GetSecretBundleRequest keyStoreContentRequest = GetSecretBundleRequest
        .builder()
        .secretId(keyStoreContentSecretId)
        .build();
GetSecretBundleResponse keyStoreContentResponse = secretsClient
        .getSecretBundle(keyStoreContentRequest);
Base64SecretBundleContentDetails keyStoreSecretContent =
        (Base64SecretBundleContentDetails) keyStoreContentResponse
        .getSecretBundle()
        .getSecretBundleContent();
String keyStoreSecret = keyStoreSecretContent.getContent();
byte[] keyStoreSecretBytes = decoder.decode(keyStoreSecret);
```



Similarly, grab the DB password secret OCID, construct a request, retrieve the secret and decode it.
```java
DatabaseToolsUserPasswordSecretId passwordSecretId =
        (DatabaseToolsUserPasswordSecretId) databaseToolsConnection
        .getUserPassword();
GetSecretBundleRequest passwordSecretBundleRequest =
        GetSecretBundleRequest.builder()
        .secretId(passwordSecretId.getSecretId())
        .build();
GetSecretBundleResponse passwordSecretBundleResponse = secretsClient
        .getSecretBundle(passwordSecretBundleRequest);
Base64SecretBundleContentDetails passwordSecretBundleContent =
        (Base64SecretBundleContentDetails) passwordSecretBundleResponse
        .getSecretBundle()
        .getSecretBundleContent();
byte[] decodedBytes = decoder.decode(passwordSecretBundleContent.getContent());
String password = new String(decodedBytes);
System.out.printf("Password: %s %n", password);
```



### Creating a Datasource and Querying It 

Now we can start creating our datasource. First, create a `Properties` object to store the username and password and construct the URL from the connect string.
```java
/* create datasource properties */
Properties info = new Properties();
info.put(OracleConnection.CONNECTION_PROPERTY_USER_NAME, username);
info.put(OracleConnection.CONNECTION_PROPERTY_PASSWORD, password);

String dbUrl = "jdbc:oracle:thin:@" + connectionString;
```



Now we can create an "in-memory" wallet from the decoded bytes of our SSO secret contents and create an SSL context that we'll set on our `DataSource` in just a bit. Huge credit to Simon for his [examples on GitHub](https://github.com/nomisvai/oracle-in-memory-wallet-samples)!
```java
/* create "in-memory" wallet */
TrustManagerFactory trustManagerFactory =
        TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
KeyManagerFactory keyManagerFactory =
        KeyManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
KeyStore keyStore = KeyStore.getInstance("SSO", new OraclePKIProvider());
keyStore.load(new ByteArrayInputStream(keyStoreSecretBytes), null);
keyManagerFactory.init(keyStore, null);
trustManagerFactory.init(keyStore);
SSLContext sslContext = SSLContext.getInstance("SSL");
sslContext.init(
        keyManagerFactory.getKeyManagers(),
        trustManagerFactory.getTrustManagers(),
        null);
```



Create the `OracleDataSource`, set the SSL context, URL, and connection properties.
```java
/* create datasource */
OracleDataSource datasource = new OracleDataSource();
datasource.setSSLContext(sslContext);
datasource.setURL(dbUrl);
datasource.setConnectionProperties(info);
```



Finally, create a Connection and execute a query. 
```java
/* get connection and execute query */
Connection connection = datasource.getConnection();
Statement statement = connection.createStatement();
ResultSet resultSet = statement.executeQuery("select sysdate from dual");
resultSet.next();
Date d = resultSet.getDate(1);
System.out.printf("Current Date from DB: %tc", d);
```



If all goes well, your output should look similar to the following when you use this class.
```log
Connection String: (description= (...[redacted]) 
Username: [redacted] 
KeyStore Type: Sso 
Password: [redacted] 
Current Date from DB: Wed Nov 10 14:28:31 EST 2021
```



## Summary 

In this post, we learned about the new Database Tools available in the Oracle Cloud Console. We created a connection and used that connection to launch a SQL Worksheet, and Cloud Shell instance with SQLcl. We then looked at how to download the connection info with the OCI Java SDK and use the info in the connection to create an in-memory wallet and datasource to query Autonomous DB. If you'd like to see this example in its entirety, [check it out on GitHub](https://gist.github.com/9f1e41fbc018bf4c8bed1636731766d1).

Photo by [Hunter Haley](https://unsplash.com/@hnhmarketing?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
