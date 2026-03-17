---
title: "Back To The Database - Part 3: Publishing Database Changes To A Stream"
slug: "back-to-the-database-part-3-publishing-database-changes-to-a-stream"
author: "Todd Sharp"
date: 2020-03-19
summary: "In the final entry to this critically acclaimed and award winning trilogy, we'll examine using triggers to publish changes from our database to a stream so that other services can know when our data changes!"
tags: ["Cloud", "Containers, Microservices, APIs", "Database"]
keywords: "DB, Database, Streams, microservices, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/71b992e7-0877-4c29-83be-e9b326abdc54/banner_1024px_back_to_the_future_the_ride_at_universal_studios_japan_2.jpg"
---

In the last post, we talked at great length about [consuming a stream in your Autonomous DB instance and using the messages in that stream to insert, update and delete records in a table in your DB](/posts/back-to-the-database-part-2-persisting-data-from-a-stream). I highly suggest you read that post first if you haven't read it yet, as we'll build quite a bit on the foundation that we laid in that post. 

Now that you're all caught up, let's talk about the other part of this amazing drawing of mine - the "source" side. Meaning, we'll publish the changes from a table in our DB to a stream that can be consumed by another service in our architecture. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/71b992e7-0877-4c29-83be-e9b326abdc54/upload_1584367061264.png)

When would you want to do this? Quite often it turns out! Imagine you run an e-commerce site. You can easily imagine that you'd have a number of different services on the backend - two of which might be an "order" service and a "shipment" service. When a new record is inserted into your order table, your shipment service probably needs to know about that. This is often referred to as "event sourcing" in the microservice world, but it's certainly not exclusive to microservices (Chris Richardson has a good [article about event sourcing that you should check out](https://microservices.io/patterns/data/event-sourcing.html)). Any system that has proper separation of concerns will need a way to communicate changes when more than one piece of the architecture has a need to know. Here's a diagram of how this is typically accomplished:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/71b992e7-0877-4c29-83be-e9b326abdc54/upload_1584367061307.png)

Following the theme of this series, we're going to improve this design by using the database to capture any changes to our table and broadcast them to a stream using Oracle Streaming Service with the `DBMS_CLOUD` package. Instead of our order service broadcasting the change to our message queue, we'll eliminate a potential point of failure and simplify our architecture by letting the DB announce the changes itself.  Here's another horribly drawn representation of this improved flow:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/71b992e7-0877-4c29-83be-e9b326abdc54/upload_1584367061385.png)

If you read my last post, the concept of using the DB to interact with our cloud based stream should be somewhat familiar by now.  If you are new to working with RDBMS you may be asking yourself how we will be able to capture the changes. We'll accomplish that by using triggers!

## What Are Triggers?

Again, my apologies to the vets among the crowd, but since I want to make sure that those who may be new to working with RDBMS are up to speed, I'd like to take a minute to define what a trigger is. Feel free to skip to the next section if you're familiar with triggers. Now, our [documentation does a very thorough job of explaining them,](https://docs.oracle.com/database/121/LNPLS/triggers.htm#GUID-3CD2CC67-5AC2-4DD5-B7D3-12E5FAE082C9) but let me break it down a bit more. 

A trigger is somewhat similar to a stored procedure, in that it can be stored in the database and invoked repeatedly. They differ from stored procedures because you can enable or disable them. Also, you can't manually invoke them. When a trigger is enabled, it fires automatically. You can define a trigger on many items in the database - a table, view or even the database itself. For our use case, we'll define it on our table which means it's a DML trigger.

Whoa\...there's a potentially new term: DML\...

`DML` is an abbreviation that stands for Data Manipulation Language. It's used to refer to objects that can be manipulated or statements that access, modify or retrieve data. `INSERT` statements, `UPDATE` statements, `DELETE`s - these are all examples of `DML`. `DDL` stands for Data Definition Language and is used to refer to statements that define or create objects in the database. `CREATE` or `ALTER` statements, for example.

When creating your trigger, you can define the time period in the transaction life cycle that you want the trigger to fire (`BEFORE` or `AFTER`), the context of that life cycle (`ROW` or `STATEMENT`) and the type(s) of transaction that you are listening for (`INSERT`, `UPDATE` \[potentially limited to a specific column or columns\], `DELETE`). You can combine timing points, contexts and types to create what is called a compound DML trigger. The docs have a really good example of a simple trigger that combines these concepts into an easy to understand the statement.
```sql
CREATE OR REPLACE TRIGGER t
  BEFORE
    INSERT OR
    UPDATE OF salary, department_id OR
    DELETE
  ON employees
BEGIN
  CASE
    WHEN INSERTING THEN
      DBMS_OUTPUT.PUT_LINE('Inserting');
    WHEN UPDATING('salary') THEN
      DBMS_OUTPUT.PUT_LINE('Updating salary');
    WHEN UPDATING('department_id') THEN
      DBMS_OUTPUT.PUT_LINE('Updating department ID');
    WHEN DELETING THEN
      DBMS_OUTPUT.PUT_LINE('Deleting');
  END CASE;
END;
/
```



In the statement above we define the trigger named t that will fire `BEFORE` a row has an `INSERT` or when an `UPDATE` statement affects the salary or department_id columns or a row has a `DELETE` occur. The action is passed to the body using the constants `INSERTING`, `UPDATING` and `DELETING` so we can determine the type of transaction that is occurring and we can take the appropriate action.

One final thing to know for now about triggers is that there is are two special variables (`NEW` and `OLD`) referred to as **pseudo records** that are available inside of the trigger body. These can be used to grab the values of the row-level changes both before and after the trigger is fired. You'll see that these are crucial to our use case below.

## Create A Stream

Before we create our trigger, we'll need a new stream to work with. Here's a quick walkthrough on how to do that.

 

This time create a stream called 'atp-oss-source', grab the OCID and the region in which you created it and keep those bits handy for later on.

## Creating A Trigger To Publish Changes To A Stream

Now that you're up to speed on what triggers are and how you create them, let's look at creating a trigger that will publish inserts, updates and deletes to a new table that we will create. What table? Glad you asked! Let's create that now:
```sql
CREATE TABLE TEST
(
    ID NUMBER(10,0) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    USERNAME VARCHAR2(50) NOT NULL,
    FIRST_NAME VARCHAR2(50) NOT NULL,
    MIDDLE_NAME VARCHAR2(50),
    LAST_NAME VARCHAR2(50) NOT NULL,
    AGE NUMBER(5,0) DEFAULT 0 NOT NULL,
    CREATED_ON TIMESTAMP(9) NOT NULL,
    CONSTRAINT TEST_PK PRIMARY KEY ( ID )
    ENABLE
);
```



Just a very simple table - nothing special here. We're going to create the trigger in just a second, but first we need to make sure that we have a credential created in our database for use with `DBMS_CLOUD`. If you followed along with the last post, you should be good to go. If you skipped that one, here's a reminder:

We create the credential by [calling the CREATE_CREDENTIAL function](https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/dbms-cloud.html#GUID-2AE20E5B-3485-4A1C-BD0B-6B5BF93E97A5) in the `DBMS_CLOUD` package! If you've got the OCI CLI installed, you'll know where to get these values. If not, [stop what you're doing and install it now](https://docs.cloud.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)!
```sql
BEGIN
DBMS_CLOUD.CREATE_CREDENTIAL (
       credential_name => 'OCI_KEY_CRED',
       user_ocid       => 'ocid1.user.oc1...',
       tenancy_ocid    => 'ocid1.tenancy.oc1...',
       private_key     => ‘MFFEowIBWWKERWEA4E...j',
       fingerprint     => ‘7c: … :09'
);
END;
/
```



Excellent. Let's create that trigger!
```sql
CREATE OR REPLACE TRIGGER test_tbl_trg
    AFTER
    INSERT OR UPDATE OR DELETE
    ON test
    FOR EACH ROW    
DECLARE
    region VARCHAR(20) := 'us-phoenix-1';
    stream_id VARCHAR2(100) := 'ocid1.stream.oc1.phx....';
    transaction_type VARCHAR2(10);
    message_details_json VARCHAR2(2000);
    response DBMS_CLOUD_TYPES.resp;
    response_text VARCHAR2(4000);
    error_message VARCHAR2(8000);
BEGIN
    transaction_type := CASE  
        WHEN INSERTING then 'INSERT'
        WHEN UPDATING THEN 'UPDATE'
        WHEN DELETING THEN 'DELETE'
    END;
EXCEPTION
    WHEN OTHERS
    THEN
        dbms_output.put_line(SQLERRM);
END;
/
```



Let's break it down. We're creating a trigger that will fire `AFTER` each `ROW INSERT`, `UPDATE` & `DELETE`. We're declaring two variables that you'll need to populate - the `region` and `stream_id` (remember above when I said you would need those!) and several other variables that we'll use as we populate the body of the trigger where we'll take our action(s). In the body (right after `BEGIN`) the first thing we do is check the constants to determine which action has triggered this invocation and set a string value accordingly (we'll pass this in our JSON event to the stream later on). 

The next step is to craft our JSON message containing the data that was mutated and publish that message up to our stream. A few things below might seem a bit tricky, so let me explain first. The [REST endpoint](https://docs.cloud.oracle.com/en-us/iaas/api/#/en/streaming/20180418/Message/PutMessages) expects a JSON object containing the [PutMessageDetails request](https://docs.cloud.oracle.com/en-us/iaas/api/#/en/streaming/20180418/datatypes/PutMessagesDetails). Also note that the "`value`" for each [message](https://docs.cloud.oracle.com/en-us/iaas/api/#/en/streaming/20180418/datatypes/PutMessagesDetailsEntry) must be a Base64 encoded byte array. Finally, take a look at the documentation for [DBMS_CLOUD.SEND_REQUEST](https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/dbms-cloud-rest.html#GUID-E038D42F-009E-477D-96E7-60944A510474) which shows that the body of the request needs to be encoded as `RAW`. That sounds like a lot of weird layers to the request, but it's not difficult to achieve the necessary format with a few function calls. 

Let's move on to populating the body of the trigger. The end goal of this is to `POST` a `PutMessageDetails` request to the stream that follows this format:
```json
{
  "messages":
  [
    {
      "key": null,
      "value": "VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wZWQgb3ZlciB0aGUgbGF6eSBkb2cu"
    }
  ]
}
```



To do this, we'll create a `JSON_OBJECT` that has a `JSON_ARRAY` of messages. Within each message we will indicate the type of transaction (our transaction_type variable that we populated already) and include an '`oldObj`' which shows the previous state of the record before mutation and a '`newObj`' which shows the new state. We'll use the pseudo records `OLD` and `NEW` to populate the states respectively. Publishing these messages will give our downstream subscribing services the ability to know when a dependent object changes and understand exactly what about it changed.
```sql
message_details_json := json_object(
                'messages' value json_array(
                    json_object(
                        'key' value null,
                        'value' value replace (replace (utl_raw.cast_to_varchar2(
                            utl_encode.base64_encode(
                                utl_raw.cast_to_raw(
                                        json_object(
                                        'type' value transaction_type,
                                        'newObj' value json_object(
                                            'id' value :new.id,
                                            'username' value :new.username,
                                            'first_name' value :new.first_name,
                                            'middle_name' value :new.middle_name,
                                            'last_name' value :new.last_name,
                                            'age' value :new.age,
                                            'created_on' value :new.created_on
                                        ),
                                        'oldObj' value json_object(
                                            'id' value :old.id,
                                            'username' value :old.username,
                                            'first_name' value :old.first_name,
                                            'middle_name' value :old.middle_name,
                                            'last_name' value :old.last_name,
                                            'age' value :old.age,
                                            'created_on' value :old.created_on
                                        )
                                    )
                                )
                            )
                        ), chr (13), ''), chr (10), '')   
                    )
                )
            );
```



The only thing left to do is publish the message to the REST endpoint and close the connection.
```sql
response := DBMS_CLOUD.send_request(
        credential_name => 'OCI_KEY_CRED',
        uri => 'https://streaming.' || region || '.oci.oraclecloud.com/20180418/streams/' || stream_id || '/messages',
        method => DBMS_CLOUD.METHOD_POST,
        body => utl_raw.cast_to_raw(message_details_json)
      );
UTL_HTTP.CLOSE_PERSISTENT_CONNS();     
response_text := DBMS_CLOUD.get_response_text(response);
```

 

And just to be thorough, here's the entire trigger definition:
```sql
SET SERVEROUTPUT ON
CREATE OR REPLACE TRIGGER test_tbl_trg
    AFTER
    INSERT OR UPDATE OR DELETE
    ON test
    FOR EACH ROW    
DECLARE
    region VARCHAR(20) := 'us-phoenix-1';
    stream_id VARCHAR2(100) := 'ocid1.stream.oc1.phx.amaaa...a';
    transaction_type VARCHAR2(10);
    message_details_json VARCHAR2(2000);
    response DBMS_CLOUD_TYPES.resp;
    response_text VARCHAR2(4000);
    error_message VARCHAR2(8000);
BEGIN
    transaction_type := CASE  
        WHEN INSERTING then 'INSERT'
        WHEN UPDATING THEN 'UPDATE'
        WHEN DELETING THEN 'DELETE'
    END;
    message_details_json := json_object(
                    'messages' value json_array(
                        json_object(
                            'key' value null,
                            'value' value replace (replace (utl_raw.cast_to_varchar2(
                                utl_encode.base64_encode(
                                    utl_raw.cast_to_raw(
                                            json_object(
                                            'type' value transaction_type,
                                            'newObj' value json_object(
                                                'id' value :new.id,
                                                'username' value :new.username,
                                                'first_name' value :new.first_name,
                                                'middle_name' value :new.middle_name,
                                                'last_name' value :new.last_name,
                                                'age' value :new.age,
                                                'created_on' value :new.created_on
                                            ),
                                            'oldObj' value json_object(
                                                'id' value :old.id,
                                                'username' value :old.username,
                                                'first_name' value :old.first_name,
                                                'middle_name' value :old.middle_name,
                                                'last_name' value :old.last_name,
                                                'age' value :old.age,
                                                'created_on' value :old.created_on
                                            )
                                        )
                                    )
                                )
                            ), chr (13), ''), chr (10), '')   
                        )
                    )
                );
    response := DBMS_CLOUD.send_request(
            credential_name => 'OCI_KEY_CRED',
            uri => 'https://streaming.' || region || '.oci.oraclecloud.com/20180418/streams/' || stream_id || '/messages',
            method => DBMS_CLOUD.METHOD_POST,
            body => utl_raw.cast_to_raw(message_details_json)
          );
    UTL_HTTP.CLOSE_PERSISTENT_CONNS();     
    response_text := DBMS_CLOUD.get_response_text(response);     
EXCEPTION
    WHEN OTHERS
    THEN
        dbms_output.put_line(SQLERRM);
END;
/
```



At this point, you can run a few queries to insert, update and delete data:
```sql
INSERT INTO TEST (age, created_on, first_name, last_name, middle_name, username)
    VALUES( 43, sysdate, 'todd', 'sharp', 'raymond', 'todd');
    
UPDATE TEST
SET username = 'recursivecodes'
WHERE username = 'todd';

DELETE FROM TEST WHERE username = 'recursivecodes';
```



Then hop over to your stream in the console dashboard and click 'Load Messages'. If you ran the three statements above, you'd see three messages:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/71b992e7-0877-4c29-83be-e9b326abdc54/upload_1584367061390.png)

Hover your mouse over the value to view details. I'll paste the three individual messages below so you can see what each look like:

### Insert:
```json
{
  "type": "INSERT",
  "newObj": {
    "id": 245,
    "username": "todd",
    "first_name": "todd",
    "middle_name": "raymond",
    "last_name": "sharp",
    "age": 43,
    "created_on": "2020-03-12T16:53:44"
  },
  "oldObj": {
    "id": null,
    "username": null,
    "first_name": null,
    "middle_name": null,
    "last_name": null,
    "age": null,
    "created_on": null
  }
}
```



### Update:
```json
{
  "type": "UPDATE",
  "newObj": {
    "id": 245,
    "username": "recursivecodes",
    "first_name": "todd",
    "middle_name": "raymond",
    "last_name": "sharp",
    "age": 43,
    "created_on": "2020-03-12T16:53:44"
  },
  "oldObj": {
    "id": 245,
    "username": "todd",
    "first_name": "todd",
    "middle_name": "raymond",
    "last_name": "sharp",
    "age": 43,
    "created_on": "2020-03-12T16:53:44"
  }
}
```



### Delete:
```json
{
  "type": "DELETE",
  "newObj": {
    "id": null,
    "username": null,
    "first_name": null,
    "middle_name": null,
    "last_name": null,
    "age": null,
    "created_on": null
  },
  "oldObj": {
    "id": 245,
    "username": "recursivecodes",
    "first_name": "todd",
    "middle_name": "raymond",
    "last_name": "sharp",
    "age": 43,
    "created_on": "2020-03-12T16:53:44"
  }
}
```



## Summary

To wrap up this series, I hope that these last few posts have challenged you to reconsider the power and flexibility of the good old RDBMS. We've moved so much of our business logic out of the DB and into our application layer that we've forgotten about the power and flexibility available to us. On top of that, the RDBMS - especially Oracle/Autonomous DB has grown up quite a bit over the past few years. As you can see, it's easy to interact with cloud APIs directly from your DB code. And we haven't even begun to look at the enhancements related to storing JSON documents and collections directly in the relational DB which brings an entirely new and extremely powerful new tool to our services. If you have any questions, please feel free to leave them below or contact me on [Twitter](https://twitter.com/recursivecodes) or [YouTube](http://youtube.com/c/recursivecodes). If you're interested in seeing more content like this, please let me know!

[Jeremy Thompson from United States of America](https://commons.wikimedia.org/wiki/File:Back_to_the_Future_The_Ride_at_Universal_Studios_Japan_2.jpg "via Wikimedia Commons") / [CC BY](https://creativecommons.org/licenses/by/2.0)

Edit me\...
