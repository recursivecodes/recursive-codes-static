---
title: "Reliably Requesting REST Results Right From Your SQL Scripts"
slug: "reliably-requesting-rest-results-right-from-your-sql-scripts"
author: "Todd Sharp"
date: 2020-08-19
summary: "In this post, we'll look at calling REST APIs from your SQL scripts. You might be surprised what is possible!"
tags: ["Cloud", "Database"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/banner_nathan_anderson_i9ibl2ko1ms_unsplash.jpg"
---

I recently blogged a [comprehensive guide to invoking serverless functions in the Oracle Cloud](/posts/the-complete-guide-to-invoking-serverless-oracle-functions). I was quite sure that I had included every possible method for invoking them when I published that article, but a few days later it dawned on me that I had missed one. Granted, it may be more of an edge case than a common way you might want to invoke your serverless function, but I want to highlight this method here in this blog post because this method can be used to invoke additional REST APIs (some of which might come as a surprise to you).

## Calling Oracle Cloud REST APIs

### Create Credentials

**Note! **Your credentials are stored in an encrypted format in the database.

Before we can make our call to the OCI REST API to invoke our serverless function, we must first store our credentials that will be used to authenticate our REST call. To do this, we'll use the [`DBMS_CLOUD.CREATE_CREDENTIALS`](https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/dbms-cloud.html#GUID-2AE20E5B-3485-4A1C-BD0B-6B5BF93E97A5) function. We only have to do this once and to use the credentials later on we'll refer to the `credential_name` which the script will use to securely retrieve and decrypt our stored credentials.

**Not Setup Yet? **The credentials we're using here are the same credentials that you use on your local machine for the OCI CLI. If you haven't yet set up the OCI CLI, see the [instructions here](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/devguidesetupprereq.htm). The `DBMS_CLOUD.CREATE_CREDENTIALS` function does not support PEM keys with passphrases.

To create our credentials, we can run the following:
```sql
BEGIN
dbms_cloud.create_credential (
    credential_name => 'OCI_KEY_CRED',
    user_ocid => 'ocid1.user.oc1...',
    tenancy_ocid => 'ocid1.tenancy.oc1...',
    private_key => 'Mgv...j+',
    fingerprint => '6b:..:02'
);
END;
```



The `private_key` value above is just the key content without any of the header/footer (without any line wraps). The rest of the data is as it would be in your `~/.oci/config` file. If for some reason you need to delete a credential, you can do so by name:
```sql
BEGIN
    dbms_cloud.DROP_CREDENTIAL('OCI_KEY_CRED');
END;
```



### Invoke Serverless Function

In order to make our REST call from our script, we'll utilize the [`DBMS_CLOUD.SEND_REQUEST`](https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/dbms-cloud-rest.html#GUID-B063870D-6C1F-4F33-B354-885B73C81D37) function. This would look like so:
```sql
dbms_cloud.send_request(
    credential_name => credential_name,
    uri => invoke_endpoint_base_url || '/20181201/functions/' || function_id || '/actions/invoke',
    method => dbms_cloud.METHOD_POST,
    body => UTL_RAW.cast_to_raw(payload)
);
```



The `SEND_REQUEST` function expects a `credential_name`, the API URI, a HTTP request method and (optionally) a `headers` and `body` parameter (both of which are expected to be a JSON_OBJECT) and returns an object of type `DBMS_CLOUD_TYPES.RESP`. The `RESP` object contains the response headers, text, and status code. The [`DMBS_CLOUD` package contains various functions](https://docs.oracle.com/en/cloud/paas/autonomous-database/adbsa/dbms-cloud-subprograms.html) to help us retrieve the values from the `RESP` object. We'll use `DBMS_CLOUD.GET_RESPONSE` to get the response which will be a JSON string. For convenience, let's wrap this up in a function.
```sql
CREATE OR REPLACE FUNCTION invoke_hello_world( 
    invoke_endpoint_base_url IN VARCHAR2,
    function_id IN VARCHAR, 
    credential_name IN VARCHAR2,
    payload IN CLOB
) RETURN CLOB 
AS 
    resp dbms_cloud_types.RESP;
BEGIN
    resp := dbms_cloud.send_request(
        credential_name => credential_name,
        uri => invoke_endpoint_base_url || '/20181201/functions/' || function_id || '/actions/invoke',
        method => dbms_cloud.METHOD_POST,
        body => UTL_RAW.cast_to_raw(payload)
    );
    RETURN dbms_cloud.get_response_text(resp);
END invoke_hello_world;
```



This serverless function is a simple "hello world" that expects a JSON object containing a single key - the name of the person to say hello to. We can call our SQL function like so:
```sql
select invoke_hello_world(
    'https://[redacted].us-phoenix-1.functions.oci.oraclecloud.com',
    'ocid1.fnfunc.oc1.phx...',
    'OCI_KEY_CRED',
    json_object('name' value 'todd')
) as message
from dual;
```



Which gives us the JSON response from the serverless invocation.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597779643075.png)

### Parse Function Result JSON

Having the JSON string is nice, but what if we wanted to do something further with the response. Say we wanted to join the data returned to us with another table or return the data as a resultset? We can take advantage of the [`JSON_TABLE`](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/JSON_TABLE.html#GUID-3C8E63B5-0B94-4E86-A2D3-3D4831B67C62) function to help us out with that.
```sql
select jt.*
from json_table( 
    invoke_hello_world(
        'https://[redacted].us-phoenix-1.functions.oci.oraclecloud.com',
        'ocid1.fnfunc.oc1.phx...',
        'OCI_KEY_CRED',
        json_object('name' value 'todd')
    ), '$'
    COLUMNS(
        message VARCHAR2(500) PATH '$.message'
    )
) as jt;
```



Which gives us:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597779825523.png)

Nice!

## Endless Possibilities

Now that we've seen how to invoke a serverless function with `SEND_REQUEST`, it's easy to see that this method can be used to call **any** [REST endpoint in the Oracle Cloud](https://docs.cloud.oracle.com/en-us/iaas/api/).

### List OCI Instances

Here's an example of getting a list of compute instances in a given compartment.
```sql
CREATE OR REPLACE FUNCTION list_oci_instances (
    compartment_id IN VARCHAR2, 
    region IN VARCHAR2,
    credential_name IN VARCHAR2
) RETURN CLOB 
AS 
    resp dbms_cloud_types.RESP;
    instance_list CLOB;
BEGIN
    resp := dbms_cloud.send_request(
        credential_name => credential_name,
        uri => 'https://iaas.' || region || '.oraclecloud.com/20160918/instances/?compartmentId=' || compartment_id,
        method => dbms_cloud.METHOD_GET);
    instance_list := dbms_cloud.get_response_text(resp);    
    RETURN instance_list;
END list_oci_instances;
```



Called like so:
```sql
select list_oci_instances(
    'ocid1.compartment.oc1...', 
    'us-phoenix-1', 
    'OCI_KEY_CRED'
) 
from dual;
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597779980669.png)

Parsed with `JSON_TABLE`:   
```sql
select jt.*
from json_table( 
    list_oci_instances(
        'ocid1.compartment.oc1...', 
        'us-phoenix-1', 
        'OCI_KEY_CRED'
    ), '$[*]'
    COLUMNS(
        ocid VARCHAR2(500) PATH '$.id',
        image_id VARCHAR2(500) PATH '$.imageId',
        region VARCHAR2(500) PATH '$.region',
        shape VARCHAR2(500) PATH '$.shape',
        display_name VARCHAR2(500) PATH '$.displayName',
        lifecycle_state VARCHAR2(500) PATH '$.lifecycleState'
    )
) as jt;
```



Which produces:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597780092352.png)

As I mentioned above, this method can be used to invoke literally any OCI REST API.

![Scary Movie Shawn Wayans GIF - ScaryMovie ShawnWayans ButWaitTheresMore GIFs](https://media1.tenor.com/images/f546606012a62774ec98a73444cce347/tenor.gif?itemid=14263131)

## Calling AWS REST APIs

Yes, you read that right. Not only can you use the `DBMS_CLOUD` package to store OCI credentials and invoke OCI REST APIs, but you can also use it to store AWS credentials and invoke AWS REST APIs. There are a lot of clients who utilize a "multi-cloud" strategy, so it makes perfect sense to support invoking REST APIs for some of the more popular cloud providers in the industry. The process is mostly identical to the method we used above, with some slight but notable differences.  

### Create AWS Credentials

The first difference is the way we create our credentials for AWS. This is [outlined in the documentation](https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/dbms-cloud.html#GUID-742FC365-AA09-48A8-922C-1987795CF36A), but the key here is that there is an overloaded version of `CREATE_CREDENTIAL` that accepts a `credential_name`, `username` and `password`. For AWS, the username is your access key ID and the password is your secret access key (refer to the AWS documentation if you are not familiar with these two items). This looks something like so:
```sql
BEGIN
dbms_cloud.create_credential (
    credential_name => 'AWS_CRED',
    username => 'A..Q',
    password => 'T..kJ'
);
END;
```



### List S3 Buckets

The function that we create follows the same format as above, but points at the appropriate AWS REST endpoint. Here we have a function to list all of the S3 buckets for an account:
```sql
CREATE OR REPLACE FUNCTION aws_list_buckets( 
    credential_name IN VARCHAR2,
    region IN CLOB
) RETURN CLOB 
AS 
    resp dbms_cloud_types.RESP;
BEGIN
    resp := dbms_cloud.send_request(
        credential_name => credential_name,
        uri => 'https://s3.' || region || '.amazonaws.com/',
        method => dbms_cloud.METHOD_GET
    );
    RETURN dbms_cloud.get_response_text(resp);
END aws_list_buckets;
```



Which we can call like so:
```sql
select aws_list_buckets('AWS_CRED', 'us-east-1') as message
from dual;
```



Since Amazon thinks we are still in 1999, we can only receive XML back from the S3 REST API.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597781343611.png)

But that's perfectly OK because we can use `XMLTABLE` to work with XML:
```sql
SELECT xt.bucket_name, to_utc_timestamp_tz( xt.creation_date ) creation_date
FROM XMLTABLE(
    xmlnamespaces(default 'http://s3.amazonaws.com/doc/2006-03-01/'), 
    '/ListAllMyBucketsResult/Buckets/Bucket'
    PASSING XMLTYPE.createXML( 
        aws_list_buckets('AWS_CRED', 'us-east-1') 
    )
    COLUMNS 
        bucket_name VARCHAR2(100) PATH 'Name',
        creation_date VARCHAR2(100) PATH 'CreationDate'
) xt
order by xt.creation_date asc;
```



Which gives us:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597781433860.png)

Excellent!

## Calling Azure REST APIs

We're not done yet! We can also work with Azure to list "containers" (buckets).

### Create Azure Credentials

For Azure, the username is your Azure storage account name and the password is an Azure storage account access key.
```sql
BEGINdbms_cloud.create_credential (    credential_name => 'AZURE_CRED',    username => 'recursivecodes',    password => 'Xi..==');END;
```



### List Azure Storage Containers

The function:
```sql
CREATE OR REPLACE FUNCTION azure_list_containers( 
    credential_name IN VARCHAR2,
    account_name IN VARCHAR2
) RETURN CLOB 
AS 
    resp dbms_cloud_types.RESP;
BEGIN
    resp := dbms_cloud.send_request(
        credential_name => credential_name,
        uri => 'https://' || account_name || '.blob.core.windows.net/?comp=list',
        method => dbms_cloud.METHOD_GET);
    RETURN dbms_cloud.get_response_text(resp);
END azure_list_containers;
```



The call:
```sql
select azure_list_containers('AZURE_CRED', 'recursivecodes') as containers
from dual;
```



The proof that Microsoft also believes we are still stuck in the previous millennium:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597781692180.png)

The query to parse the XML into a usable format:
```sql
SELECT xt.container_name, to_timestamp_tz( xt.last_modified, 'DY, DD MON YYYY HH24:MI:SS TZR') as container_last_modified
FROM XMLTABLE('/EnumerationResults/Containers/Container'
    PASSING XMLTYPE.createXML( 
        azure_list_containers('AZURE_CRED', 'recursivecodes') 
    )
    COLUMNS 
        container_name VARCHAR2(100) PATH 'Name',
        last_modified VARCHAR2(100) PATH 'Properties/Last-Modified'
) xt
order by container_last_modified desc;
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/5b1c1b8f-45c8-49c2-8da0-54a05d7ee2ed/file_1597781765659.png)

## Summary

In this post, we looked at how to request REST results for an OCI tenancy with DBMS_CLOUD.SEND_REQUEST in your PL/SQL scripts. We also saw how that method can be utilized to call the REST APIs for your external cloud providers such as Microsoft Azure and Amazon Web Services.

Photo by [Nathan Anderson](https://unsplash.com/@nathananderson?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
