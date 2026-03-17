---
title: "Securely Connecting to Autonomous DB Without a Wallet (Using TLS)"
slug: "securely-connecting-to-autonomous-db-without-a-wallet-using-tls"
author: "Todd Sharp"
date: 2021-10-06
summary: "In this post, we'll look at connecting to an Autonomous DB instance with TLS instead of mTLS in order to securely connect without a wallet."
tags: ["Cloud", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/fly-d-C5pXRFEjq3w-unsplash.jpeg"
---

I talk to a lot of developers in my job as a Developer Advocate. Sometimes they've been using the products in the Oracle Cloud for a long time, and sometimes they have very little (or no) experience with Oracle Cloud. Out of all the developers I've talked to about Autonomous DB (**ADB**), approximately 100% of them have voiced displeasure, general unhappiness, and/or aggravation about using a Wallet to connect to the cloud DB service. In fact, that's probably the only complaint I've really ever heard about the otherwise excellent and easy-to-use ADB. But today - today I have **good news**! Today is the day that we can **connect to Autonomous DB without a wallet**! To celebrate, I've decided to have a conversation with myself to help clarify certain things. Here's a quick overview of the conversation that I had with myself:

- [But How?](#But%20How?)
- [Is TLS Less Secure Than mTLS? ](#Is%20TLS%20Less%20Secure%20Than%20mTLS?%C2%A0)
- [So, It's Less Secure\...](#So,%20It's%20Less%20Secure...)
- [Do I Have to use TLS?](#Do%20I%20Have%20to%20use%20TLS?)
- [Can I Enable Both TLS and mTLS](#Can%20I%20Enable%20both%20TLS%20and%20mTLS)
- [OK, How Do I Enable and Connect With TLS?](#OK,%20How%20Do%20I%20Enable%20and%20Connect%20with%20TLS?)
  - [Enable TLS](#Enable%20TLS)
  - [Disable mTLS](#Disable%20mTLS)
  - [Obtain Connection String](#Obtain%20Connection%20String)
  - [Configure Java Application](#Configure%20Java%20Application)
  - [Launch the Application!](#Launch%20the%20Application!)
- [I Want to Read All the Docs!](#toc_I-Want-to-Read-all-the-Docs-)
- [Summary](#Summary)

## But How? 

I knew you'd ask that question. The answer is\...complicated. Kinda. Before today, ADB used mTLS (mutual TLS) as an extra secure way to establish the client-server connection. mTLS means that both the client and the server have an extra special secret key and they show that key to each other to verify that they are who they say they are. Going forward, you can configure ADB to use TLS instead of mTLS which means that only the server needs the extra special secret key and the client trusts that the server's key is valid. 

## Is TLS Less Secure Than mTLS?  

Maybe. Certainly having both the client and server exchange credentials leaves less chance for invalid or improper connections. But it also requires you to download and install your wallet on the server that is connecting to ADB. This means that if someone can obtain access to the server, they likely have access to the wallet as well. Also, we can mitigate the risk with other security practices as we'll talk about later.

## So, It's Less Secure\... 

I didn't say that! Besides, as I said just a second ago - there are other things we can do to mitigate any potential security risks. For example, to enable TLS on an ADB instance with a public endpoint exposed, you must have an Access Control List (**ACL**) in place. The ACL is an "allow" list that limits access to **only** the IP addresses or Virtual Cloud Networks (VCN) that have been added to it. If you're using a private endpoint that restricts connections, you can also use TLS instead of mTLS. Since traffic outside of the VCN is blocked, you can have confidence that your connection is secured.

## Do I Have to use TLS? 

Of course not. If you're happy using mTLS and a wallet, there is no reason to change anything. TLS connections are opt-in, so you don't have to worry about turning anything off or changing anything. Just keep querying!

## Can I Enable Both TLS and mTLS? 

Sure can! Just enable TLS and disable the mTLS requirement.

## OK, How Do I Enable and Connect With TLS? 

Glad you asked. Let's look at a quick example. This'll use Micronaut because I find it quite easy, but the same concepts apply to any JDBC-based connection. 

### Enable TLS 

Log in to the Oracle Cloud console and select your ADB instance to view the instance details. In the details, find the section titled 'Network' and click on 'Edit' next to 'Access Control List'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/77d75df7-b6b0-4915-868f-6262c57b8353/upload_73cdf68cae82778cbfb851e795789c27.png)

In the 'Edit Access Control List' dialog, choose the type of entry that you'd like to make and enter the appropriate value. You can add entries by IP Address (I added my local IP), CIDR Block (maybe your office has a range of IPs assigned to developers), and VCN (by name or OCID). Add as many as necessary.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3ef3d999-f27a-460d-8330-71e6c64433b6/upload_a0a42b33eb923de108056f6c55ece12a.png)

**Remember!**  The ACL is an "**allow list**", not a "**deny list**". That means it **blocks all traffic except for the exceptions listed**.  

### Disable mTLS 

To use either TLS or mTLS, you must disable the requirement for mTLS. Kinda confusing, but think about it like this: If mTLS is enabled, you can **only** connect with mTLS. If it's disabled, you can connect with **either** mTLS or TLS. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6e75a183-d20d-46cc-ae47-724e09df7455/upload_896354860c1c8917ef9fa8c71d17e464.png)

Now uncheck 'Require mutual TLS (mTLS) authentication' and click 'Save Changes'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/41d5197c-5db3-47ab-a524-955e95b8d488/upload_5c5049a024dc5e8cfbfd9c8dea435a82.png)

### Obtain Connection String 

Since we no longer have a `tnsnames.ora` file that tells the `OJDBC` driver how to connect to ADB, we need to grab a connection string that we can plug into our JDBC URL in the Java app. In the instance details, click on 'DB Connection'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/ae13c013-6731-424b-9163-0dcac8547752/upload_d7b2084943ea3889f789fd1e359a5af0.png)

In the DB connection dialog, under 'Connection Strings', select TLS from the dropdown menu. Then, copy the appropriate Connection String based on your application's requirements.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/6ff437e7-c291-41a7-97d7-d8216fdfd1ce/upload_4917dc554daf8a99390f206b39e603ec.png)

### Configure Java Application 

In my Micronaut application, I set the following values in my configuration file (`application.yml`).
```yaml
datasources:
  default:
    url: jdbc:oracle:thin:@[PASTE CONNECTION STRING]
    driverClassName: oracle.jdbc.driver.OracleDriver
    username: [USERNAME]
    password: [PASSWORD]
    dialect: ORACLE
```



I also made sure I had the latest OJDBC driver per [the docs](https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/connect-jdbc-thin-tls.html#GUID-364DB7F0-6F4F-4C42-9395-4BA4D09F0483) and launched the application. \

### Launch the Application! 

And that's it. That's all the changes I needed to make. No more wallets, no more secrets storing wallet values, no more headaches! Just a secure, encrypted connection between my app and ADB!

## I Want to Read All the Docs! 

Here you go:

- [Update Network Options to Allow TLS or Require Only Mutual TLS (mTLS) Authentication on Autonomous Database](https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/support-tls-mtls-authentication.html#GUID-3F3F1FA4-DD7D-4211-A1D3-A74ED35C0AF5)
- [JDBC Thin Connections with TLS Authentication](https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/connect-jdbc-thin-tls.html#GUID-364DB7F0-6F4F-4C42-9395-4BA4D09F0483)
- [Configuring Network Access with Access Control Rules (ACLs) and Private Endpoints](https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/autonomous-network-access.html#GUID-D2D468C3-CA2D-411E-92BC-E122F795A413)

## Summary 

We made our Java application connect to ADB using TLS instead of mTLS for secure, encrypted communications without a wallet.
