---
title: "Using Mongo APIs with Micronaut Data to Persist and Query Data with Autonomous DB"
slug: "using-mongo-apis-with-micronaut-data-to-persist-and-query-data-with-autonomous-db"
author: "Todd Sharp"
date: 2022-02-15
summary: "In this post, we'll learn how to use the Mongo support in Micronaut Data to persist and query an Autonomous DB instance in Oracle Cloud."
tags: ["Java", "Micronaut"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1905.i126.005_programmer%20work.jpg"
---

A bit of exciting news dropped that you may have missed. We announced the release of the [Oracle Database API for MongoDB](https://blogs.oracle.com/database/post/mongodb-api), which gives developers the ability to persist and query data into Oracle Database via Mongo APIs. This announcement means that we can take our existing codebase (often with no changes at all) and point it at a new endpoint and have it "just work." Why does this matter? For starters, it gives developers who are less familiar with Oracle DB (or SQL/relational databases) the ability to migrate their application to Oracle Autonomous DB in a seamless manner. If nothing changes with the persistence tier code, migrating is easier. Why bother? That's a fair question. The answer lies in remaining flexible and providing additional features as your application grows. Since this feature will store our data as a JSON object in a relational database, we can still interact with it via the familiar Mongo APIs, but we gain the ability to interact with it via SQL. Meaning we can write queries that join our JSON data with relational data, graph data, and just about anything else that is possible to store in Oracle DB. And it's not just existing applications. If you prefer Mongo APIs (or frameworks that support Mongo), you can write a brand new application from scratch and point it at your Autonomous DB instance. This feature is a big deal.

So now that you know that it's possible let's dig into the feature and see how we might write an application to use it. I'm fond of the [Micronaut](https://micronaut.io) Java framework, and the engineering team recently updated the Micronaut Data module to support MongoDB. As you might expect, it works perfectly with Autonomous DB, so let's see how it's done by writing a quick app!

- [Provision Database and Obtain Connection String](#Provision%20Database%20and%20Obtain%20Connection%20String)
  - [Sign Up for an "Always Free" Account](#Sign%20Up%20for%20an%20)
  - [Launch Instance](#Launch%20Instance)
- [Connect with Mongo Shell](#Connect%20with%20Mongo%20Shell)
  - [Create New Application User](#Create%20New%20Application%20User)
- [Create Micronaut Application](#Create%20Micronaut%20Application)
  - [Add Config](#Add%20Config)
  - [Enable Logging](#Enable%20Logging)
  - [Create Entity and Repository](#Create%20Entity%20and%20Repository)
  - [Create Controller](#Create%20Controller)
  - [Run Application](#Run%20Application)
    - [Create Document](#Create%20Document)
    - [Update Document](#Update%20Document)
    - [List Documents](#List%20Documents)
    - [Get Document By Id](#Get%20Document%20By%20ID)
    - [Delete Document](#Delete%20Document)
    - [Console Log](#Console%20Log)
- [Query Database](#Query%20Database)
- [Summary](#Summary)

## Provision Database and Obtain Connection String 

If you've already got an existing Autonomous Transaction Processing (ATP) or Autonomous JSON (AJD) instance, skip on to the next section!

### Sign Up for an "Always Free" Account 

I suppose some of you may be new to Oracle Cloud. If that's the case, I should tell you that you can use this feature completely free (forever) on the Oracle Cloud "always free" tier ([more info and sign up here](https://www.oracle.com/cloud/free)). Once you've signed up, [install the OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm). The CLI will make working with your cloud account more straightforward, and we'll use it to provision a new DB instance in just a minute.

### Launch Instance 

You could launch your instance via the cloud console, but it's easy to do with the OCI CLI like so:
```bash
$ export AJD=$(oci db autonomous-database create \
    --db-workload [AJD or OLTP]  \
    --compartment-id [YOUR_COMPARTMENT_ID] \
    --admin-password Str0ngPassword_ \
    --cpu-core-count 1 \
    --data-storage-size-in-tbs 1 \
    --db-name demoajd \
    --display-name demo-ajd \
    --license-model LICENSE_INCLUDED \
    --wait-for-state AVAILABLE)
```



Note that we're capturing the JSON response with the command above and setting it into an environment variable in our terminal. Once the instance creation is complete, we'll use a [tool called jq](https://stedolan.github.io/jq/) to craft our Mongo connect string. The mongo URL will use the same base URL as all other connection URLs (I've asked our engineers to add the Mongo connection URL to the CLI response). Let's grab the APEX URL and extract the domain name like so:
```bash
$ echo $AJD | jq '.data."connection-urls"."apex-url"' --raw-output | awk -F/ '{print $3}'
```



This should print something like `HVG9ND7XIBSAEGV-DEMOAJD.adb.us-phoenix-1.oraclecloudapps.com`, which we can plug into the following format:

[mongodb://admin:\[pass\]@\[domain name\]:27017/admin?authMechanism=PLAIN&authSource=\$external&ssl=true&retryWrites=false&loadBalanced=true]

Another option is to visit the Service Console and copy the Mongo connection string. You can visit the service console via the URL returned from our call to create the instance:
```bash
$ echo $AJD | jq '.data."service-console-url"' --raw-output
```



Click on 'Development' in the Service Console and copy the connection string.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2a0326e6-5058-4928-9206-83e74d9bf111/upload_8642ec3f20e1198a1a01b24153120cb7.png)

## Connect with Mongo Shell 

Now let's connect up to the new instance with `mongosh`.
```bash
$ mongosh mongodb://admin:[pass]@HVG9ND7XIBSAEGV-DEMOAJD.adb.us-phoenix-1.oraclecloudapps.com:27017/admin\?authMechanism=PLAIN\&authSource=\$external\&ssl=true\&retryWrites=false\&loadBalanced=true
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/ad71540f-2587-4911-9003-a07661504770/upload_96a565d10909ddedc727a5612e7cfca1.png)

### Create New Application User 

That worked! Now let's create an application database/user. We'll also need to create a collection since Mongo won't create the database until data is stored. We can do this via `mongosh` with:
```bash
> use mnajd
> db.new_collection.insert({ some_key: "some_value" })
```



These commands will create a new schema in Oracle DB behind the scenes, but as you might have realized, the user hasn't gotten a password assigned yet and doesn't have any privileges granted. The easiest way to do this is to visit the web-based SQL Developer and issue a few commands. First, let's head back to the console and grab the URL for SQL Developer Web:
```bash
$ echo $AJD | jq '.data."connection-urls"."sql-dev-web-url"' --raw-output
```



Now login via the admin credentials that you specified when creating the instance.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/251846ef-86ed-47a4-8949-b293fa37c6b7/upload_adbb37504e492b6d3c3dca8bedadb56c.png)

Click on 'SQL':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3cea93ee-dd6c-4ae4-83d9-543923761f54/upload_579ff07e95c0ec3604caf7e0450183bc.png)

And run the following SQL commands (using a strong password, please!).
```sql
ALTER USER mnajd identified by "Str0ngPassword";
GRANT CONNECT, RESOURCE, SODA_APP TO mnajd;
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/caebda80-f94b-4610-bf04-67d68c0170bf/upload_ba2587b99dfd0b85e6efde59a8e34238.png)

We can now connect up via `mongosh` with the new user (notice that we also changed `/admin` in the path to the schema name `/mnajd`).
```bash
$ mongosh mongodb://mnajd:[pass]@HVG9ND7XIBSAEGV-DEMOAJD.adb.us-phoenix-1.oraclecloudapps.com:27017/mnajd\?authMechanism=PLAIN\&authSource=\$external\&ssl=true\&retryWrites=false\&loadBalanced=true
```



Once connected, we can query as usual.
```bash
[direct: mongos] mnajd> show dbs
mnajd  344 kB
[direct: mongos] mnajd> show collections
new_collection
```



## Create Micronaut Application 

At this point, we're able to use pretty much any SDK that works with MongoDB. I've personally tested it with Mongoose and a few other frameworks, and everything works as expected. But since Micronaut recently added [support for MongoDB to Micronaut Data](https://micronaut-projects.github.io/micronaut-data/snapshot/guide/#mongo), I figured it would be a perfect demo for this post to wire up a simple Micronaut application that uses the MongoDB support to persist and query data from an Autonomous DB instance. 
```bash
$ mn create-app --build=gradle --jdk=11 --lang=java --test=spock codes.recursive.oci-atp-mongo
```



Add a few dependencies to `build.gradle`. We'll need the annotation processor. We'll have to manually bring in `micronaut-serde-bson:1.0.0-M6` (usually a dependency that Micronaut brings in for us, but we need version `1.0.0-M6` to get past a known bug for now). We'll also need the MongoDB driver, as on line 6 below.
```groovy
annotationProcessor("io.micronaut.data:micronaut-data-document-processor:3.3.0-M1")
implementation("io.micronaut.serde:micronaut-serde-bson:1.0.0-M6")
implementation("io.micronaut.data:micronaut-data-mongodb:3.3.0-M1") {
    exclude module:'micronaut-inject-java'
}
implementation("org.mongodb:mongodb-driver-sync")
```



It's not mandatory, but I like to add Project Lombok since it makes life easier by generating getters/setters, and constructor methods for my entities. If you add it, do so before any other `annotationProcessor` dependencies.
```groovy
compileOnly 'org.projectlombok:lombok:1.18.12'
annotationProcessor "org.projectlombok:lombok:1.18.12"
```



 Next, we'll need to set up the datasource. Open up `/src/main/java/resources/application.yml` and populate the datasource like so:

### Add Config 
```yaml
mongodb:
  uri: ${MONGODB_URI}
```



We can pass in the URI that we obtained in the previous section of this blog post to this configuration at runtime by either setting an environment variable named `MONGODB_URI` or pass it in as a system property with `-DMONGODB_URI`. 

### Enable Logging 

If you'd like to see the queries that Micronaut generates behind the scenes, or need help with debugging, enable logging by adding the following logger to `/src/main/resources/logback.xml`. Add this value just below (but outside of) the `<root>` node.
```xml
<logger name="io.micronaut.data.query" level="trace" />
```



### Create Entity and Repository 

We need to create an entity that will represent the JSON document that we would like to persist. There are only a few strict rules here. One - we must annotate the class with `@MappedEntity` so Micronaut knows that it needs to manage it. Secondly, we need to assign an ID property to serve as the record identifier. [The default ID generation type for MongoDB uses `ObjectId` as an ID. But, I prefer to use `String` since it gives you a literal value that can query the object later on. Thirdly, if we want the ID to be automatically assigned, we need to annotate it with `@GeneratedValue`. Otherwise, Micronaut will expect us to assign an ID manually before we `save()` the entity. Finally, if we want to use automatically assigned UUIDs for our ID property, we can annotate them with `@AutoPopulated`. Other than these "rules" (which you can [read more about here](https://micronaut-projects.github.io/micronaut-data/snapshot/guide/#mongoAnnotations)), we're free to add as many properties of whatever type we need to construct our entity. Here's what a minimal `Movie` class might look like:]

To enable persistence, we need to create a repository interface that is annotated with `@MongoRepository` and extends `CrudRepository`.
```java
@MongoRepository
public interface MovieRepository extends CrudRepository<Movie, String> {
    @Executable
    Movie findByTitle(String title);
}
```



### Create Controller 

We're now at a point where we can create a controller to expose a few endpoints for basic CRUD operations. Let's create our `MovieController` and add those endpoints.
```java
@Controller("/movie")
public class MovieController {

    private final MovieRepository movieRepository;

    public MovieController(MovieRepository movieRepository) {
        this.movieRepository = movieRepository;
    }

    @Get()
    public HttpResponse getMovies() {
        return HttpResponse.ok(
                movieRepository.findAll()
        );
    }

    @Get(uri = "/{movieId}")
    public HttpResponse getMovie(String movieId) {
        return HttpResponse.ok( movieRepository.findById(movieId) );
    }

    @Get(uri = "/title/{movieTitle}")
    public HttpResponse getMovieByTitle(String movieTitle) {
        return HttpResponse.ok( movieRepository.findByTitle(movieTitle) );
    }

    @Post()
    public HttpResponse saveMovie(@Body Movie movie) {
        movieRepository.save(movie);
        return HttpResponse.created(movie);
    }

    @Put()
    public HttpResponse updateMovie(@Body Movie movie) {
        movieRepository.update(movie);
        return HttpResponse.noContent();
    }

    @Delete("/{movieId}")
    public HttpResponse deleteMovie(String movieId) {
        movieRepository.deleteById(movieId);
        return HttpResponse.noContent();
    }
}
```



### Run Application 

We can now start the application and issue a few HTTP requests to the CRUD endpoints via `cURL`. 

#### Create Document 
```bash
$ curl -i -X POST \
  -H "Content-Type: application/json" \
  --data-raw '
    {
      "title": "Back to the Future",
      "description": "Eighties teenager Marty McFly is accidentally sent back in time to 1955, inadvertently disrupting his parents''' first meeting and attracting his mother'''s romantic interest. Marty must repair the damage to history by rekindling his parents''' romance and - with the help of his eccentric inventor friend Doc Brown - return to 1985.",
      "rating": 83,
      "runtimeMinutes": 126,
      "releasedOn": "07/03/1985"
    }' \
  localhost:8080/movie
```



Sample return value:
```bash
HTTP/1.1 201 Created
date: Mon, 14 Feb 2022 14:20:18 GMT
Content-Type: application/json
content-length: 465
connection: keep-alive

{"id":"620a6521ca65e72ff82ef9ba","title":"Back to the Future","description":"Eighties teenager Marty McFly is accidentally sent back in time to 1955, inadvertently disrupting his parents' first meeting and attracting his mother's romantic interest. Marty must repair the damage to history by rekindling his parents' romance and - with the help of his eccentric inventor friend Doc Brown - return to 1985.","rating":83,"runtimeMinutes":126,"releasedOn":"07/03/1985"}
```



#### Update Document 
```bash
$ curl -i -X PUT \
  -H "Content-Type: application/json" \
  --data-raw '
    {
      "id": "620a6521ca65e72ff82ef9ba",
      "title": "Back to the Future",
      "description": "Eighties teenager Marty McFly is accidentally sent back in time to 1955, inadvertently disrupting his parents''' first meeting and attracting his mother'''s romantic interest. Marty must repair the damage to history by rekindling his parents''' romance and - with the help of his eccentric inventor friend Doc Brown - return to 1985.",
      "rating": 83,
      "runtimeMinutes": 116,
      "releasedOn": "07/03/1985"
    }' \
  localhost:8080/movie
```



Sample output:
```bash
HTTP/1.1 204 No Content
date: Mon, 14 Feb 2022 14:23:22 GMT
connection: keep-alive
```



#### List Documents 
```bash
$ curl localhost:8080/movie | jq
```



Sample output:
```bash
HTTP/1.1 200 OK
date: Wed, 26 Jan 2022 19:19:29 GMT
Content-Type: application/json
content-length: 199
connection: keep-alive

[
  {
    "id": "620a6521ca65e72ff82ef9ba",
    "title": "Back to the Future",
    "description": "Eighties teenager Marty McFly is accidentally sent back in time to 1955, inadvertently disrupting his parents' first meeting and attracting his mother's romantic interest. Marty must repair the damage to history by rekindling his parents' romance and - with the help of his eccentric inventor friend Doc Brown - return to 1985.",
    "rating": 83,
    "runtimeMinutes": 116,
    "releasedOn": "07/03/1985"
  }
]
```



#### Get Document By Id 
```bash
$ curl localhost:8080/movie/620a6521ca65e72ff82ef9ba | jq
```



Sample output:
```bash
HTTP/1.1 200 OK
date: Wed, 26 Jan 2022 19:19:00 GMT
Content-Type: application/json
content-length: 65
connection: keep-alive

{
  "id": "620a6521ca65e72ff82ef9ba",
  "title": "Back to the Future",
  "description": "Eighties teenager Marty McFly is accidentally sent back in time to 1955, inadvertently disrupting his parents' first meeting and attracting his mother's romantic interest. Marty must repair the damage to history by rekindling his parents' romance and - with the help of his eccentric inventor friend Doc Brown - return to 1985.",
  "rating": 83,
  "runtimeMinutes": 116,
  "releasedOn": "07/03/1985"
}
```



#### Delete Document 
```bash
$ curl -i -X DELETE localhost:8080/movie/61f19db7c83ba32b4ca5a468
```



Sample output:
```bash
HTTP/1.1 204 No Content
date: Mon, 14 Feb 2022 14:25:54 GMT
connection: keep-alive
```



#### Console Log 

Here's how the console might look for the operations above. Since we enabled `trace` logging for the queries, we can see the corresponding Mongo SDK methods (`insertOne`, `replaceOne`, `find`, and `deleteMany`) that Micronaut Data used to perform the requested operations.
```log
09:19:55.037 [main] INFO  io.micronaut.runtime.Micronaut - Startup completed in 1457ms. Server Running: http://localhost:8080
09:20:16.212 [default-nioEventLoopGroup-1-2] INFO  org.mongodb.driver.cluster - Cluster created with settings {hosts=[hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016], mode=SINGLE, requiredClusterType=UNKNOWN, serverSelectionTimeout='30000 ms'}
09:20:16.312 [default-nioEventLoopGroup-1-2] INFO  org.mongodb.driver.cluster - Cluster description not yet available. Waiting for 30000 ms before timing out
09:20:17.072 [cluster-rtt-ClusterId{value='620a6520ca65e72ff82ef9b9', description='null'}-hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016] INFO  org.mongodb.driver.connection - Opened connection [connectionId{localValue:2}] to hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016
09:20:17.072 [cluster-ClusterId{value='620a6520ca65e72ff82ef9b9', description='null'}-hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016] INFO  org.mongodb.driver.connection - Opened connection [connectionId{localValue:1}] to hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016
09:20:17.072 [cluster-ClusterId{value='620a6520ca65e72ff82ef9b9', description='null'}-hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016] INFO  org.mongodb.driver.cluster - Monitor thread successfully connected to server with description ServerDescription{address=hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016, type=SHARD_ROUTER, state=CONNECTED, ok=true, minWireVersion=0, maxWireVersion=8, maxDocumentSize=16777216, logicalSessionTimeoutMinutes=30, roundTripTimeNanos=474102273}
09:20:17.104 [default-nioEventLoopGroup-1-2] DEBUG io.micronaut.data.query - Executing Mongo 'insertOne' with entity: Movie(id=null, title=Back to the Future, description=Eighties teenager Marty McFly is accidentally sent back in time to 1955, inadvertently disrupting his parents' first meeting and attracting his mother's romantic interest. Marty must repair the damage to history by rekindling his parents' romance and - with the help of his eccentric inventor friend Doc Brown - return to 1985., rating=83, runtimeMinutes=126, releasedOn=1985-07-03)
09:20:18.404 [default-nioEventLoopGroup-1-2] INFO  org.mongodb.driver.connection - Opened connection [connectionId{localValue:3}] to hvg9nd7xibsaegv-demoajd.adb.us-phoenix-1.oraclecloudapps.com:27016
09:23:22.208 [default-nioEventLoopGroup-1-4] DEBUG io.micronaut.data.query - Executing Mongo 'replaceOne' with filter: {"_id": {"$oid": "620a6521ca65e72ff82ef9ba"}}
09:24:23.631 [default-nioEventLoopGroup-1-7] DEBUG io.micronaut.data.query - Executing Mongo 'find' with filter: {} skip: 0 limit: 0
09:24:44.246 [default-nioEventLoopGroup-1-8] DEBUG io.micronaut.data.query - Executing Mongo 'find' with filter: {"_id": {"$eq": {"$oid": "620a6521ca65e72ff82ef9ba"}}}
09:25:37.419 [default-nioEventLoopGroup-1-9] DEBUG io.micronaut.data.query - Executing Mongo 'deleteMany' with filter: {"_id": {"$eq": {"$oid": "620a6521ca65e72ff82ef9ba"}}}
```



## Query Database 

The cool part of this is that Micronaut Data stored our data in Oracle DB in a traditional relational style table/row format, which means that we can continue to interact with it via the Mongo SDK or query it with traditional SQL as necessary. Let's run a query against the movie table:
```sql
select *
from movie;
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3354afcf-7764-4b31-98d0-cb487cfb65e9/upload_a3ef54aeb10ed60c81c7382d9191e2f1.png)

SQL Developer returned our JSON document as a binary large object by default. That's not very helpful, so let's serialize the `BLOB` to `JSON`.
```sql
select 
    id,
    json_serialize(data)
from movie;
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8e55fa6c-f7be-49cc-9cfd-3d1ad87a28d0/upload_f132d12c825e957e123ae076f30cfa0a.png)

That's a bit more helpful in that now we can visualize the JSON data. But it might be better to extract the individual JSON key/value elements into distinct columns. This way, we can return the data in a resultset and join/filter/aggregate as necessary.
```sql
select 
    id,
    m.data.title,
    m.data.description,
    m.data.runtimeMinutes,
    m.data.rating
from movie m;
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b1f70991-d730-4678-8e0d-cf5f0b434afb/upload_8ae821551c1f7354570dfd8a97a75dd9.png)

Now that's heavy!

## Summary 

In this post, we looked at how to enable Mongo support for an Autonomous DB instance and use that support from Micronaut to persist and query data with Mongo APIs. If you'd like to view the code used in this post, [check it out on GitHub](https://github.com/recursivecodes/mn-atp-mongo)!
