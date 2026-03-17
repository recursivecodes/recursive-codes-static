---
title: "Launch & Persist JSON Documents In The Cloud In 10 Minutes Or Less With Autonomous JSON Database "
slug: "launch-persist-json-documents-in-the-cloud-in-10-minutes-or-less-with-autonomous-json-database"
author: "Todd Sharp"
date: 2020-08-13
summary: "In this post, we'll create our first Autonomous JSON Database instance, our first JSON collection and some basic CRUD operations all without leaving the browser."
tags: ["Cloud", "Database"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9ad00ab1-8037-4876-bc38-95c87ca165f5/banner_susan_yin_yqhhlcs9hto_unsplash.jpg"
---

This morning at the [Developer Live event](https://developer.oracle.com/developer-live/database/#agenda), our Executive Vice President Juan Loaiza announced the launch of Autonomous JSON Database (AJD). This is [an exciting announcement](https://blogs.oracle.com/jsondb/autonomous-json-database) because it represents the very first time we are offering a dedicated solution for JSON document collection persistence in the Oracle Cloud. It symbolizes our commitment to offering developers solutions that fit their needs and solves the problems they face when developing microservices and applications instead of trying to convince them to use a tool that might not be the best fit for them. Of course, like all good solutions, it is scalable and adaptable which means that it can transform into a full-blown Autonomous Transaction Processing database if your needs dictate that in the future. But of course, if you know me then you have likely come to this blog post to learn how to quickly get started using AJD, so let's take a look at how to use it. I promise that you'll be able to get an instance launched and data persisted quickly, so let's not waste any more time and get into the good stuff!

In this post, I'll show you how to create a brand new instance, connect up to it, create a collection and insert, query, and remove data from that collection. We'll do all of these things in less than 10 minutes and all without leaving your browser. 

To get started, log in to your Oracle Cloud console. From any page in the console, click on the 'Cloud Shell' icon in the header of the page to launch a new Cloud Shell.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9ad00ab1-8037-4876-bc38-95c87ca165f5/file_1597068198590.png)

Your Cloud Shell instance will take a minute or two to launch the first time, but once it launches it will remain open and ready as you navigate around the console. While you're waiting for the Cloud Shell to launch, collect the compartment OCID that you'd like to work with. That's all that we will need before we start creating our instance and performing persistence operations in it.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9ad00ab1-8037-4876-bc38-95c87ca165f5/file_1597068439625.png)

Once you have that OCID, start by running the following CLI command in Cloud Shell to launch the instance.

One of the (many) awesome things about Cloud Shell is that it comes with the OCI CLI pre-installed and configured so you can immediately start working with it in your tenancy without having to spend time on installation and configuration!

Create the instance, substituting your compartment OCID and a strong password of your choosing. We'll capture the JSON response so that we can grab information from it later on.
```bash
$ export ATP=$(oci db autonomous-database create \
    --db-workload AJD \
    --compartment-id [YOUR COMPARTMENT OCID] \
    --admin-password Str0ngPassword_ \
    --cpu-core-count 1 \
    --data-storage-size-in-tbs 1 \
    --db-name testdb \
    --display-name testdb \
    --wait-for-state AVAILABLE)
```



Note the new value (**AJD**) for launching an Autonomous JSON Database in the command above.

It will take a few minutes for your AJD instance to be created and provisioned. Next, we'll grab the newly created instance's OCID and store it in a variable.
```bash
$ export ATP_ID=$(echo $ATP | jq '.data.id' --raw-output)
```



We'll need to download our wallet to make a connection, so let's do that. Enter your own path and password instead of using mine!
```bash
$ oci db autonomous-database generate-wallet \
    --autonomous-database-id $ATP_ID \
    --file /home/todd_sharp/wallet.zip \
    --password Str0ngPassword_
```



We're already ready to connect to our instance. You might be wondering how we're going to do that from Cloud Shell? Well, last week we quietly rolled out a new tool added in the form of SQLcl. We'll use that tool to connect and do some basic CRUD operations. Let's get to it.

Launch SQLcl:
```bash
$ sql /nolog
```



Point the tool at our wallet.
```bash
SQL> set cloudconfig /home/todd_sharp/wallet.zip
```



Connect with the admin user (enter the password when prompted).
```bash
SQL> connect admin@testdb_high
```



**Note:** The next steps are purely optional. If you're just testing things out, feel free to skip them. But if you're planning on working a bit further and connecting up to an application, use these steps to create a schema.

Optionally, create a user and connect with that user. Enter your own username and password for this user.
```bash
SQL> CREATE USER sodauser IDENTIFIED BY "Str0ngPassword_";
SQL> GRANT CONNECT, RESOURCE TO sodauser;
SQL> GRANT UNLIMITED TABLESPACE TO sodauser;
SQL> connect sodauser@testdb_high
Password? (**********?) ***************
```



## Checkpoint

In just a few minutes we've created and connected to our AJD instance and we're ready to create a collection and perform some CRUD operations. You may be a bit confused right now - wondering how we are going to persist JSON documents in an Autonomous instance. The answer, of course, is SODA. 

> *Simple Oracle Document Access* (SODA) is a set of NoSQL-style APIs that let you create and store collections of documents (in particular JSON) in Oracle Database, retrieve them, and query them, without needing to know Structured Query Language (SQL) or how the documents are stored in the database.

There are a number of SODA implementations which means you can work with it natively from your new and existing microservices:

- [SODA for Java](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/java/index.html)
- [SODA for Node.JS](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/nodejs/index.html)
- [SODA for Python](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/python/index.html)
- [SODA for REST](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/rest/index.html)
- [SODA for C](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/c/)
- [SODA for PL/SQL](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/plsql/)

There's one other option for SODA, and that's the SQLcl console that we're already connected to our instance with. Let's work through a full CRUD example very quickly below. You can always refer to the [SQLcl documentation for SODA](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/20.2/sqcug/working-sqlcl.html#GUID-4C621A1E-5826-4CBE-A0C2-7DCADD612380) later if you get stuck.

## JSON CRUD In 5 Minutes

To create a collection:
```bash
SQL> soda create testcollection
Successfully created collection: testcollection
```



List all collections:
```bash
SQL> soda list
List of collections:
testcollection
```



Insert a few docs into a collection:
```bash
SQL> soda insert testcollection {"name": "todd", "is_cool": true, "age": 43}
Json String inserted successfully.
SQL> soda insert testcollection {"name": "dominic", "is_cool": true, "age": 13}
Json String inserted successfully.
SQL> commit;
Commit complete.
```



Get all documents from a collection:
```bash
SQL> soda get testcollection -all
        KEY                                             Created On
        3FC9160AE62F415996725B199A357FBA                2020-08-04T18:22:36.777638000Z
        470FDF6EF0ED4CF585C63F2CA9B92CA0                2020-08-04T18:25:59.789898000Z
 2 rows selected.
```



Get a document by key:
```bash
SQL> soda get testcollection -k 3FC9160AE62F415996725B199A357FBA
Key:             3FC9160AE62F415996725B199A357FBA
Content:         {"name":"todd","is_cool":true,"age":43}
-----------------------------------------
 1 row selected.
```



Search with query by example (QBE):
```bash
SQL> soda get testcollection -f {"age":{"$lt":40}}
Key:             470FDF6EF0ED4CF585C63F2CA9B92CA0
Content:         {"name":"dominic","is_cool":true,"age":13}
-----------------------------------------
 1 row selected.
```



Count docs in collection:
```bash
SQL> soda count testcollection
 2 rows selected.
```



Count docs with QBE:
```bash
SQL> soda count testcollection {"age":{"$lt":40}}
 1 row selected.
```



Replace (update) an existing doc:
```bash
SQL> soda replace testcollection 3FC9160AE62F415996725B199A357FBA {"name": "todd", "is_cool": false, "age": 43}
3FC9160AE62F415996725B199A357FBA
Json String replaced successfully.
SQL> commit;
Commit complete.
```



Confirm the replacement:
```bash
SQL> soda get testcollection -k 3FC9160AE62F415996725B199A357FBA
Key:             3FC9160AE62F415996725B199A357FBA
Content:         {"name":"todd","is_cool":false,"age":43}
-----------------------------------------
 1 row selected.
```



Remove (delete) a document:
```bash
SQL> soda remove testcollection -k 3FC9160AE62F415996725B199A357FBA
Successfully removed 1 record.
```



View the table behind the JSON collection:
```bash
SQL> describe testcollection;
            Name       Null?             Type 
________________ ___________ ________________ 
ID               NOT NULL    VARCHAR2(255)    
CREATED_ON       NOT NULL    TIMESTAMP(6)     
LAST_MODIFIED    NOT NULL    TIMESTAMP(6)     
VERSION          NOT NULL    VARCHAR2(255)    
JSON_DOCUMENT                BLOB
```



Use "vanilla" SQL to query the data (treating the JSON fields as columns):
```bash
SQL> select 
  2  tc.id, tc.created_on, tc.last_modified,
  3  tc.json_document.name, tc.json_document.age
  4  from testcollection tc;
                                 ID                         CREATED_ON                      LAST_MODIFIED       NAME    AGE 
___________________________________ __________________________________ __________________________________ __________ ______ 
DBBA0A6CF5AB4093A0819A53CDE3CD99    05-AUG-20 11.15.50.638289000 PM    05-AUG-20 11.15.50.638289000 PM    todd       43     
B464467C808C4CFBA6C0EBD76CF5A73E    05-AUG-20 11.15.57.787655000 PM    05-AUG-20 11.15.57.787655000 PM    dominic    13
```



JSON fields can also be used in your WHERE clause:
```bash
SQL> select 
  2  tc.id, tc.created_on, tc.last_modified,
  3  tc.json_document.name, tc.json_document.age
  4  from testcollection tc
  5  where tc.json_document.name = 'todd'; 
                                 ID                         CREATED_ON                      LAST_MODIFIED    NAME    AGE 
___________________________________ __________________________________ __________________________________ _______ ______ 
DBBA0A6CF5AB4093A0819A53CDE3CD99    05-AUG-20 11.15.50.638289000 PM    05-AUG-20 11.15.50.638289000 PM    todd    43
```



If you want to view the JSON document as a string, use `json_serialize()`:
```bash
SQL> select 
  2  json_serialize(tc.json_document) as json
  3  from testcollection tc
  4  where tc.json_document.name = 'todd';
                                      JSON 
__________________________________________ 
{"name":"todd","is_cool":true,"age":43}
```



That's all it takes to create a JSON collection and insert, update and delete JSON documents to and from that collection. You're now ready to integrate your AJD instance into your new and existing microservices for full JSON document collection persistence in the Oracle Cloud.

## Bonus: Create & Test a Node.JS App in Cloud Shell!

Since we're here, we might as well test out one of the SODA client libraries, so let's create a basic Node.JS application in Cloud Shell to work with our collection. Node and NPM are already installed, so we can create a directory and an application straight away at this point. But before we do that, let's do a tiny bit of admin work. We'll need our wallet unzipped and we have to set an environment variable to the location where we unzipped it. We'll also need to update the `sqlnet.ora` file to point at our wallet directory. We can accomplish all of this like so (again, update the path to the proper path for your Cloud Shell home directory):
```bash
$ unzip wallet.zip -d /home/todd_sharp/wallet
$ export TNS_ADMIN=/home/todd_sharp/wallet
$ sed -i 's/?\/network\/admin/\/home\/todd_sharp\/wallet/g' /home/todd_sharp/wallet/sqlnet.ora
```



Create a directory for the project and switch to it:
```bash
$ mkdir node-soda && cd node-soda
```



Create a new project and install `oracledb`:
```bash
$ npm init && npm install && npm i oracledb
This utility will walk you through creating a package.json file.

# install output removed for brevity 

> oracledb@5.0.0 install /home/todd_sharp/node-soda/node_modules/oracledb
> node package/install.js

# install output removed for brevity 

added 1 package and audited 1 package in 0.809s
found 0 vulnerabilities
```



Install the `instantclient` into your project directory and set the `LD_LIBRARY_PATH`:
```bash
mkdir -p /opt/oracle && cd /opt/oracle
wget https://download.oracle.com/otn_software/linux/instantclient/19800/instantclient-basiclite-linux.x64-19.8.0.0.0dbru.zip
unzip instantclient-basiclite-linux.x64-19.8.0.0.0dbru.zip
rm instantclient-basiclite-linux.x64-19.8.0.0.0dbru.zip
export LD_LIBRARY_PATH=`pwd`/instantclient_19_8:$LD_LIBRARY_PATH
```



Set some env vars:
```bash
$ export DB_USER=sodauser
$ export DB_PASSWORD=Str0ngPassword_
$ export CONNECT_STRING=dbdemo_low
```

In the project root, create and edit your `index.js` file (or whatever you chose for your entry point):
```javascript
const oracledb = require('oracledb');
oracledb.outFormat = oracledb.OBJECT;
oracledb.fetchAsString = [oracledb.CLOB];
oracledb.autoCommit = true;
(async () => {
        console.log(‘Create pool...');
        await oracledb.createPool({
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            connectString: process.env.CONNECT_STRING,
        });
        console.log('Get connection...');
        const connection = await oracledb.getConnection();
  
        console.log('Get SODA DB...');
        const soda = connection.getSodaDatabase();
  
        console.log('Get collection...');
        const collection = await soda.createCollection('testcollection');
  
        console.log('Insert doc...');
        const entry = await collection.insertOneAndGet({name: 'ava', is_cool: true, age: 14});
        console.log({id: entry.key, created_on: entry.createdOn});
  
        console.log('Get new doc...');
        const doc = await collection.find().key(entry.key).getOne();
        console.log(doc.getContent());
  
        console.log('Close connection...');
        connection.close();
  
        console.log('Close pool...');
        try {
            await oracledb.getPool().close(10);
            console.log('Pool closed');
        } catch(err) {
            console.error(err);
        }
})();
```



Save, close, and run it with:
```bash
$ node index.js
```



Should produce output similar to this:
```bash
Creating pool...
Get connection...
Get SODA DB...
Get collection...
Insert doc...
{ id: 'F25C4D41FB514F0ABF62DB76C0AAA99D',
  created_on: '2020-08-06T02:23:43.944593Z' }
Get new doc...
{ name: 'ava', is_cool: true, age: 14 }
Close connection...
Close pool...
Pool closed
```



We can log back in with SQLcl and take a look at our collection to see what happened:
```bash
SQL> soda get testcollection -all
        KEY                                             Created On
        03414EC292344FD8BFED22DCE165801E                2020-08-06T02:20:31.716147000Z
        80A0568D85FD4F8EBF954CE5E33D9150                2020-08-06T02:21:02.524842000Z
        F25C4D41FB514F0ABF62DB76C0AAA99D                2020-08-06T02:23:43.944593000Z
 3 rows selected.
```



We can see that we now have 3 records and the newest record's ID matches the ID that we inserted with Node.JS. Let's get the newest one by ID and confirm that the content matches the content we persisted with Node.JS:
```bash
​​​​​​​SQL> soda get testcollection -k F25C4D41FB514F0ABF62DB76C0AAA99D
Key:             F25C4D41FB514F0ABF62DB76C0AAA99D
Content:         {"name":"ava","is_cool":true,"age":14}
-----------------------------------------
 1 row selected.
```



In just 5 more minutes, we created a Node.JS application to persist JSON documents in our AJD instance and confirmed those operations with SQLcl. 

## Summary & Cleanup

If you'd like to destroy the test instance of Autonomous JSON Database that we created above, run the following:
```bash
$ oci db autonomous-database delete --autonomous-database-id $ATP_ID
```



In this post, we learned about Autonomous JSON Database (AJD), created an AJD instance, and performed CRUD operations using SQLcl and a basic Node.JS application from within Cloud Shell. To learn more about AJD, please refer to the documentation:

Read more about AJD here:

- <https://docs.oracle.com/en/cloud/paas/autonomous-json-database/ajdug/autonomous-json-database.html>

Photo by [Susan Yin](https://unsplash.com/@syinq?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/collection?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
