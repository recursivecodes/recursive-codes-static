---
title: "Automatic Autonomous Wallet Download & Configuration with Micronaut"
slug: "automatic-autonomous-wallet-download-configuration-with-micronaut"
author: "Todd Sharp"
date: 2021-03-04
summary: "In this post, we'll look at how to configure a Micronaut application to connect to an Autonomous DB instance securely by automatically downloading your wallet credentials via OCI SDK integrations."
tags: ["Cloud", "Developers", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1904b413-6382-444c-b5bc-dfaad99de49f/banner_almos_bechtold_aj_mou1fus8_unsplash.jpg"
---

Back in September, we [announced the Micronaut Oracle Cloud Infrastructure module](/posts/announcing-the-micronaut-oracle-cloud-module-for-simple-sdk-integration-and-performant-serverless-functions) to help developers easily integrate with the OCI SDK as well as use Micronaut for their serverless Oracle Functions. Today, I'm super excited to tell you about an enhancement to that module that is guaranteed to make your life easier and your application more secure when it's time to connect your Micronaut applications with Autonomous Database - automatic wallet download. That's right, you no longer have to manually download your wallet and worry about how to distribute it with your application. Just configure your application to use the OCI SDK module, provide your Autonomous DB OCID, DB username and password and Micronaut will download the wallet, store it in memory, and handle creating your connect string and connecting to the DB. Let's look at a quick example.

## Configure Micronaut OCI Module

To get started, include a dependency on the module in your `build.gradle`:
```groovy
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-sdk")
```



Now determine [which type of auth provider](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide/#authentication) you'll use. Since I have the OCI CLI configured locally, I use a `ConfigFileAuthenticationDetailsProvider`, so I add the following to my `src/main/resources/application.yml` file.
```yaml
oci:
  config:
    profile: DEFAULT
```



When I deploy to the cloud, I use a `InstancePrincipalsAuthenticationDetailsProvider` by creating a file called `src/main/resources/application-oraclecloud.yml` which Micronaut is intelligent enough to use once I deploy to the Oracle Cloud.
```yaml
oci: 
  config: 
    instance-principal: 
      enabled: true
```



Next, add a dependency on the ATP module:
```groovy
runtime("io.micronaut.oraclecloud:micronaut-oraclecloud-atp:1.2.1”)
```



And don't forget your OJDBC drivers:
```groovy
implementation(enforcedPlatform("com.oracle.database.jdbc:ojdbc-bom:21.1.0.0"))
implementation("com.oracle.database.jdbc:ojdbc8”)
```



And something for connection pooling:
```groovy
implementation("io.micronaut.sql:micronaut-jdbc-hikari”)
```



Finally, add a datasource. As mentioned above, you'll need to provide the OCID for your DB, a schema user and password and a strong password that will be used to encrypt the keys in your wallet.
```yaml
datasources: 
    default: 
        ocid: ocid1.autonomousdatabase.oc1..... 
        walletPassword: micronaut.1 
        username: foo 
        password: bar
```



That's it! Now start your app and you should notice an entry in the console output when the connection is configured:
```out
08:52:59.591 [main] TRACE i.m.o.a.j.h.HikariPoolConfigurationListener - Retrieving Oracle Wallet for DataSource [default]
08:48:05.740 [main] INFO  i.m.o.a.j.OracleWalletArchiveProvider - Using default serviceAlias: demodb_high
```



## Summary

In this post, we looked at how to configure a Micronaut application to securely connect to an Autonomous DB instance by automatically downloading, storing and configuring a wallet. To read more about this feature, [please refer to the Micronaut documentation](https://micronaut-projects.github.io/micronaut-oracle-cloud/snapshot/guide/#autonomousDatabase).

Photo by [Almos Bechtold](https://unsplash.com/@almosbech?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/magic-wallet?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

