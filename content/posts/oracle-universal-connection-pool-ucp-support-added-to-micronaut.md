---
title: "Oracle Universal Connection Pool (UCP) Support Added To Micronaut"
slug: "oracle-universal-connection-pool-ucp-support-added-to-micronaut"
author: "Todd Sharp"
date: 2020-04-28
summary: "In this post, we'll look at using Oracle UCP for connection pooling in a Micronaut application."
tags: ["Cloud", "Java"]
keywords: "Java, microservices, Cloud, connection pooling, DB, Database"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3797d72b-91d1-4969-b8c3-65c178c022c1/banner_humphrey_muleba_dyj7rts85fs_unsplash.jpg"
---

The Micronaut framework includes several options for connection pooling since it launched and today there is a new option available for your microservice applications: Oracle Universal Connection Pool (UCP). In this post, I'd like to show you how to use this new feature in your application.

## Add The Dependency

To get started, you must first include the dependency in your `build.gradle` file:
```groovy
runtime("io.micronaut.configuration:micronaut-jdbc-ucp")
```



If you're using Maven:
```xml
<dependency>
    <groupId>io.micronaut.configuration</groupId>
    <artifactId>micronaut-jdbc-ucp</artifactId>
    <scope>runtime</scope>
</dependency>
```



## Configure The Datasource

Next, you'll need to create a datasource in your `application.yaml` file. All of the properties from [`PoolDataSource`](https://docs.oracle.com/en/database/oracle/oracle-database/18/jjuar/oracle/ucp/jdbc/PoolDataSource.html) are valid here and will be passed to the pool instance at runtime. For example:
```yaml
datasources:
  default:
    url: ${DATASOURCE_URL}
    connectionFactoryClassName: oracle.jdbc.pool.OracleDataSource
    username: ${DATASOURCE_USERNAME}
    password: ${DATASOURCE_PASSWORD}
    schema-generate: NONE
    dialect: ORACLE
```



## Create The Service

You're now ready to add a service to query your datasource. If you're using Micronaut Data, you're all ready to go. Otherwise, you can create a service and inject the DataSource:
```java
@Singleton
public class UserService {

private final DataSource dataSource;
    public UserService(DataSource dataSource) {
        this.dataSource = dataSource;
    }
}
```



Add a method to get a connection from the pool, create and execute the query:
```java
@Transactional
public List<HashMap<String,Object>> getUsers() throws SQLException {
    Connection connection = dataSource.getConnection();
    Statement statement = connection.createStatement();
    ResultSet resultSet = statement.executeQuery("select * from users");
    return convertResultSetToList(resultSet);
}
```



And a private helper to convert the ResultSet into a List of HashMap objects:
```java
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
```



## Add Controller Method

The only thing left to do is inject the UserService into our controller and add an endpoint to retrieve the users and return them:
```java
@Get("/users")
public HttpResponse getUsers() throws SQLException {
    return HttpResponse.ok(userService.getUsers());
}
```



## Summary

In this post, we looked at how to utilize the new support for Oracle UCP in Micronaut. For further information, please [check the docs](https://micronaut-projects.github.io/micronaut-sql/latest/guide/#jdbc) or leave a question below!.

Photo by [Humphrey Muleba](https://unsplash.com/@good_citizen?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/pool?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
