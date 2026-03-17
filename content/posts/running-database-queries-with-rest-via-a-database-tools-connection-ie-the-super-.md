---
title: "Running Database Queries With REST via a Database Tools Connection (IE: The Super Easy Way)"
slug: "running-database-queries-with-rest-via-a-database-tools-connection-ie-the-super-easy-way"
author: "Todd Sharp"
date: 2021-11-22
summary: "In this post, we'll use the super-secret SQL Worksheet endpoint with a Database Tools Connection OCID for REST based queries."
tags: ["APIs", "Cloud", "Database", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/sunset-ge34c14c06_1280.jpeg"
---

I recently blogged about a [brand-new service in the Oracle Cloud - Database Tools](https://recursive.codes/blog/post/2066). It's a safe, secure way to store your database credentials in the cloud and use them in your application or to connect to other services in the cloud like SQL Worksheets and SQLcl in Cloud Shell. If you haven't read that post, you definitely should do that. If you did read it, maybe you gave it a try and discovered that it is super helpful and easy! If you're especially curious, maybe you opened up the Developer Tools console in your browser while using a SQL Worksheet to see what's going on under the covers and noticed that your query statements are posted to a special endpoint that requires nothing more than a signed request to a URL that contains the DB Tools OCID to run the query against the specified connection. In this post, we're going to get creative and take advantage of that endpoint to run some queries.

We'll start by opening up a SQL worksheet and running a basic query. But before we do that, open up the Developer Tools in your browser and go to the 'Network' tab to make sure it is capturing requests.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/77ef30cc-ed0e-4f33-8a3d-6d6d3bfd5dbb/upload_eb4f8250ac5e91c2897f1f6653f60d87.png)

Nothing complicated here. Just a basic query to prove that we're connected to the database and can run a simple query. Now, let's take a look at the HTTP call in the network tab to see what's going on.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/457b2500-8935-4b3a-9756-80ba97cf0228/upload_41c5e49b2de9c8e31e336a0bd161d7ca.png)

It's a basic HTTP request to an endpoint that uses the following format:

`https://sql.dbtools.us-phoenix-1.oci.oraclecloud.com/20201005/ords/ocid1.databasetoolsconnection.oc1.phx.../_/sql`

The only 'variables' in this URL are the region ('`us-phoenix-1`') and the DB Tools Connection OCID, so we should be able to work with this! We can see an `authorization` header that contains the signature required for making REST calls to any OCI endpoint. The process for [signing a request is outlined in the docs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm), but don't worry, we're not going to be signing the request manually (although you absolutely could if you wanted to). Finally, take a look at the request body.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9ab5fa8c-b549-4455-af1e-98df8c6c45bc/upload_332326790caef93e334d727766538b6b.png)

Very Interesting! The request payload is an object/map that contains 4 keys: `binds`, `limit`, `offset`, and `statementText`. This looks like something that we can work with!

## Running a Query via the OCI CLI 

You've got the OCI CLI [installed](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cliconcepts.htm), right? Cool. Let's take a look at the [CLI Reference documentation for dbtools](https://docs.oracle.com/en-us/iaas/tools/oci-cli/3.3.0/oci_cli_docs/cmdref/dbtools.html) and see how to run a query. Oh, wait. It's not documented there. That's OK - we can make this work. How? By making a [raw request](https://docs.oracle.com/en-us/iaas/tools/oci-cli/3.3.0/oci_cli_docs/cmdref/raw-request.html)! Let's recreate the basic query above with the CLI and pipe it to JQ to pretty-print the results.
```bash
$ oci raw-request \
    --region phx \
    --http-method POST \
    --request-body '{ "statementText": "select sysdate from dual;" }' \
    --target-uri "https://sql.dbtools.us-phoenix-1.oci.oraclecloud.com/20201005/ords/ocid1.databasetoolsconnection.oc1.phx.../_/sql" | jq
```



Which should give us something similar to this:
```json
{
  "data": {
    "env": {
      "defaultTimeZone": "UTC"
    },
    "items": [
      {
        "response": [],
        "result": 0,
        "resultSet": {
          "count": 1,
          "hasMore": false,
          "items": [
            {
              "sysdate": "2021-11-17T16:33:19Z"
            }
          ],
          "limit": 10000,
          "metadata": [
            {
              "columnName": "SYSDATE",
              "columnTypeName": "DATE",
              "isNullable": 1,
              "jsonColumnName": "sysdate",
              "precision": 0,
              "scale": 0
            }
          ],
          "offset": 0
        },
        "statementId": 1,
        "statementPos": {
          "endLine": 1,
          "startLine": 1
        },
        "statementText": "select sysdate from dual",
        "statementType": "query"
      }
    ]
  },
  "headers": {
    "Connection": "keep-alive",
    "Content-Length": "434",
    "Content-Type": "application/json",
    "Date": "Wed, 17 Nov 2021 16:33:19 GMT",
    "X-Frame-Options": "SAMEORIGIN",
    "opc-request-id": "[redacted]"
  },
  "status": "200 OK"
}
```



Whoa! That worked! We get all kinds of metadata back, and inside that result is our query result:
```json
[
  {
    "sysdate": "2021-11-17T16:34:15Z"
  }
]
```



Fantastic! We can even get paginated results by passing `offset` and `limit` in the request body.
```bash
$ oci raw-request \
    --region phx \
    --http-method POST \
    --request-body '{ "offset": 10, "limit": 10, "statementText": "select * from (select ROWNUM from dual connect by level <= 1000);" }' \
    --target-uri "https://sql.dbtools.us-phoenix-1.oci.oraclecloud.com/20201005/ords/ocid1.databasetoolsconnection.oc1.phx.../_/sql" \
    | jq '.data.items[].resultSet.items'
```



Which gives us:
```json
[
  {
    "rownum": 11
  },
  {
    "rownum": 12
  },
  {
    "rownum": 13
  },
  {
    "rownum": 14
  },
  {
    "rownum": 15
  },
  {
    "rownum": 16
  },
  {
    "rownum": 17
  },
  {
    "rownum": 18
  },
  {
    "rownum": 19
  },
  {
    "rownum": 20
  }
]
```



What about bind variables? Just pass them as a list of objects (each containing a `name` for the bind variable, the `data_type`, and the `value`).
```bash
$ oci raw-request \
    --region phx \
    --http-method POST \
    --request-body '{ "statementText": "select :NAME as NAME from dual;", "binds": [{"name": "NAME", "data_type": "VARCHAR2", "value": "Todd Sharp"}] }' \
    --target-uri "https://sql.dbtools.us-phoenix-1.oci.oraclecloud.com/20201005/ords/ocid1.databasetoolsconnection.oc1.phx.../_/sql" \
    | jq '.data.items[].resultSet.items'
[
  {
    "name": "Todd Sharp"
  }
]
```



So we've established that it's fairly straightforward to use this endpoint - as long as the request is properly signed. So how might we use this from an SDK then? 

## Running a Query via the OCI Java SDK 

The good news is that most of the OCI SDKs include a method to sign a raw request to an OCI REST Endpoint. We'll look at the Java SDK below, but if you use Python or Node then you should check the SDK docs for a similar method. To get started, add a dependency for the OCI Java SDK 'common' module.
```groovy
implementation 'com.oracle.oci.sdk:oci-java-sdk-common:2.8.1'
```



Now let's create a `DatabaseToolsQueryRunner` class and in the constructor create an instance of the `BasicAuthenticationDetailsProvider` and a `RequestSigner` ([javadoc](https://docs.oracle.com/en-us/iaas/tools/java/2.9.0/)).
```java
public class DatabaseToolsQueryRunner {
    private final String connectionOcid;
    private final RequestSigner requestSigner;

    public DatabaseToolsQueryRunner(String connectionOcid) throws IOException {
        this.connectionOcid = connectionOcid;
        BasicAuthenticationDetailsProvider provider = new ConfigFileAuthenticationDetailsProvider("DEFAULT");
        this.requestSigner = DefaultRequestSigner.createRequestSigner(provider);
    }
}
```



Create a run() method that will accept the SQL string.
```java
public String run(String sql) throws IOException {}
```



Now we'll construct the URL, set some necessary variables, create and serialize the request body, and sign the request.
```java
String urlPath = "https://sql.dbtools.us-phoenix-1.oci.oraclecloud.com/20201005/ords/" + connectionOcid + "/_/sql";
URI uri = URI.create(urlPath);
String method = "POST";
Map<String, String> body = Map.of("statementText", sql);
String requestBody = new ObjectMapper().writeValueAsString(body);
Map<String, List<String>> headers = Collections.emptyMap();
Map<String, String> request = requestSigner.signRequest(uri, method, headers, requestBody);
```



Next, we'll use HttpURLConnection to construct the request and set the headers.
```java
URL url = new URL(urlPath);
HttpURLConnection connection = (HttpURLConnection) url.openConnection();
connection.setRequestMethod(method);
connection.setDoInput(true);
request.keySet()
        .forEach( key ->
                connection.setRequestProperty(key, request.get(key))
        );
```



Set the request body.
```java
connection.setDoOutput(true);
try(OutputStream os = connection.getOutputStream()) {
    byte[] input = requestBody.getBytes(StandardCharsets.UTF_8);
    os.write(input, 0, input.length);
}
```



And then read the response and clean things up.
```java
InputStreamReader inputStreamReader = new InputStreamReader(connection.getInputStream());
BufferedReader in = new BufferedReader(inputStreamReader);
String inputLine;
StringBuffer content = new StringBuffer();
while ((inputLine = in.readLine()) != null) {
    content.append(inputLine);
}
in.close();
connection.disconnect();
return content.toString();
```



Now we can create an instance of our query runner class (passing in the connection OCID) and run a query!
```java
DatabaseToolsQueryRunner databaseToolsQueryRunner = new DatabaseToolsQueryRunner(args[0]);
String queryResponse1 = databaseToolsQueryRunner.run("select sysdate from dual;");
Map result1 = mapper.readValue(queryResponse1, Map.class);
System.out.println(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(result1));
```



If all went well, we'll get the following output:
```log
{
  "env" : {
    "defaultTimeZone" : "UTC"
  },
  "items" : [ {
    "statementId" : 1,
    "statementType" : "query",
    "statementPos" : {
      "startLine" : 1,
      "endLine" : 1
    },
    "statementText" : "select sysdate from dual",
    "resultSet" : {
      "metadata" : [ {
        "columnName" : "SYSDATE",
        "jsonColumnName" : "sysdate",
        "columnTypeName" : "DATE",
        "precision" : 0,
        "scale" : 0,
        "isNullable" : 1
      } ],
      "items" : [ {
        "sysdate" : "2021-11-17T17:12:13Z"
      } ],
      "hasMore" : false,
      "limit" : 10000,
      "offset" : 0,
      "count" : 1
    },
    "response" : [ ],
    "result" : 0
  } ]
}
```



Nice!! What about pagination? Just change the method signature to:
```java
public String run(String sql, int offset, int limit) throws IOException { }
```



And pass them in the request body:
```java
Map<String, Object> body = Map.of("statementText", sql, "offset", offset, "limit", limit);
```



And call it:
```java
String queryResponse2 = databaseToolsQueryRunner.run("select ROWNUM from dual connect by level <= 1000;", 10, 10);
Map result2 = mapper.readValue(queryResponse2, Map.class);
System.out.println(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(result2));
```



Which produces:
```log
{
  "env" : {
    "defaultTimeZone" : "UTC"
  },
  "items" : [ {
    "statementId" : 1,
    "statementType" : "query",
    "statementPos" : {
      "startLine" : 1,
      "endLine" : 1
    },
    "statementText" : "select ROWNUM from dual connect by level <= 1000",
    "resultSet" : {
      "metadata" : [ {
        "columnName" : "ROWNUM",
        "jsonColumnName" : "rownum",
        "columnTypeName" : "NUMBER",
        "precision" : 0,
        "scale" : -127,
        "isNullable" : 1
      } ],
      "items" : [ {
        "rownum" : 11
      }, {
        "rownum" : 12
      }, {
        "rownum" : 13
      }, {
        "rownum" : 14
      }, {
        "rownum" : 15
      }, {
        "rownum" : 16
      }, {
        "rownum" : 17
      }, {
        "rownum" : 18
      }, {
        "rownum" : 19
      }, {
        "rownum" : 20
      } ],
      "hasMore" : true,
      "limit" : 10,
      "offset" : 10,
      "count" : 10
    },
    "response" : [ ],
    "result" : 0
  } ]
}
```



Same thing goes for bind variables. 
```java
public String run(String sql, List<Map<String, String>> bindVars) throws IOException { }
```



And the request body:
```java
Map<String, Object> body = Map.of("statementText", sql, "binds", bindVars);
```



And call it:
```java
String queryResponse3 = databaseToolsQueryRunner.run(
        "select :NAME as NAME from dual;", 
        List.of(
                Map.of("name", "NAME", "data_type", "VARCHAR2", "value", "Todd Sharp")
            )
        );
Map result3 = mapper.readValue(queryResponse3, Map.class);
System.out.println(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(result3));
```



Which gives us:
```log
{
  "env" : {
    "defaultTimeZone" : "UTC"
  },
  "items" : [ {
    "statementId" : 1,
    "statementType" : "query",
    "statementPos" : {
      "startLine" : 1,
      "endLine" : 1
    },
    "statementText" : "select :NAME as NAME from dual",
    "binds" : [ {
      "name" : "NAME",
      "data_type" : "VARCHAR2",
      "value" : "Todd Sharp"
    } ],
    "resultSet" : {
      "metadata" : [ {
        "columnName" : "NAME",
        "jsonColumnName" : "name",
        "columnTypeName" : "VARCHAR2",
        "precision" : 128,
        "scale" : 0,
        "isNullable" : 1
      } ],
      "items" : [ {
        "name" : "Todd Sharp"
      } ],
      "hasMore" : false,
      "limit" : 10000,
      "offset" : 0,
      "count" : 1
    },
    "response" : [ ],
    "result" : 0
  } ]
}
```



## Summary 

If you don't mind me saying so, this has to be one of the coolest blog posts I've written in quite a while. Using Database Tools Connections in this manner to execute queries against a database is secure and powerful. It doesn't require a whole lot of external dependencies and uses simple REST calls instead of complex datasources and connection pools. This method can open up all kinds of opportunities for interacting with your database from clients that might not otherwise be able to easily interact (such as IoT devices or languages without official support). If you want to see [more examples, check out this Gist from Kris Rice](https://gist.github.com/krisrice/8e30fe477c84122efb6aef5ac4935cad) (which uses Jersey instead of the `HttpURLConnection` class and includes more awesome stuff like exporting to custom formats like XML, CSV, JSON, etc) or refer to the [documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/19.1/aelig/rest-enabled-sql-service.html#GUID-BA9F9457-ED3A-48A4-828A-CC8CBEA9A2AB). 

<div>

\

</div>

<div>

\

</div>

\

<div>

\

</div>
