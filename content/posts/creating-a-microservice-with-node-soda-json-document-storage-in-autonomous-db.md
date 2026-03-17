---
title: "Creating A Microservice With Node & SODA - JSON Document Storage In Autonomous DB"
slug: "creating-a-microservice-with-node-soda-json-document-storage-in-autonomous-db"
author: "Todd Sharp"
date: 2019-07-23
summary: "In this post we'll look at how to create a microservice that persists JSON documents in Oracle Autonomous DB using Node.JS and SODA."
tags: ["Cloud", "Containers, Microservices, APIs", "JavaScript"]
keywords: "microservices, Javascript, node.js"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/733f4cf8-8409-48ee-b5ba-1d12bc2a17c4/banner_wade_austin_ellis_evcukbdewss_unsplash.jpg"
---

We've been on a long and interesting journey with microservices in this blog series and have covered a lot of topics. In this post we'll take a look at something slightly different - storing JSON documents. There are tons of options when it comes to storing JSON document collections - some more popular than others. I'm certainly not here to discuss the merits of other options or discount their popularity, rather I'd like to show you an alternative to the more popular options and present a few reasons why it might be beneficial to your application to consider them.We'll look at using your Oracle Autonomous DB instance to store JSON documents using the [Simple Oracle Data Access (SODA) APIs](https://docs.oracle.com/en/database/oracle/oracle-database/18/adsdi/overview-soda.html#GUID-BE42F8D3-B86B-43B4-B2A3-5760A4DF79FB). SODA is a set of NoSQL-like APIs that let you persist, retrieve and query JSON document collections with Oracle DB. There are [several implementations available to choose from](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/index.html): Java, Node.JS, Python, C, and PL/SQL - as well as a REST implementation that can be used with any language/platform. For a change of pace, we'll use the Node SDK in this example.

If you haven't been following this series you might want to consider reading the first few posts to get up to speed if you plan on trying this example:

Intro posts:

- [Intro](/posts/microservices-are-easy "https://blogs.oracle.com/developers/microservices-are-easy")
- [Getting Started With Kubernetes And Docker](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud "https://blogs.oracle.com/developers/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud")
- [Getting Started With Autonomous DB](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud "https://blogs.oracle.com/developers/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud")

## Getting Started

In this post we're going to build a "post" service for a simple social media type service that allows users to submit content (text, links, images, videos) to the application. The "user" service that would be deployed with this application could be either of the user services that we created in the previous posts. Links to those blog posts can be found at the bottom of this post if you want to check those out. We'll use the ExpressJS framework to make things easy. Start out by scaffolding the application with the express CLI:

`express --no-view post-svc` 

This gives you a basic application structure to get started with. Let's grab some dependencies next. Run the following command to install them (we'll cover what some of them are used for later on):

`npm install @hapi/joi aws-sdk cors express-async-handler express-fileupload uuid oracledb`

Yeah, you read that right. We'll be using the aws-sdk within our application even though we're deploying to the Oracle Cloud. Since there isn't currently an Oracle Cloud SDK for Node, we'll take advantage of the fact that Oracle Cloud's object storage service exposes a fully compatible S3 endpoint and use the AWS SDK to upload objects. More on that later on.

We won't need to create any tables for our JSON document collection, but we will need to create a schema/user. Run the following as an admin user to do that (note the special 'soda_app' privilege we're granting here):
```sql
CREATE USER postsvc IDENTIFIED BY "STRONGPASSWORD";

GRANT create session TO postsvc;
GRANT create table TO postsvc;
GRANT create view TO postsvc;
GRANT create any trigger TO postsvc;
GRANT create any procedure TO postsvc;
GRANT create sequence TO postsvc;
GRANT create synonym TO postsvc;
GRANT soda_app TO postsvc;

GRANT UNLIMITED TABLESPACE TO postsvc;
```



We're going to need our Oracle ATP wallet (check [this post for how to generate/download the wallet](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud)). Create a directory in the project root called `build-resource/` and place a copy of your ATP wallet at `build-recource/wallet/`. You'll also want to create an object storage user and bucket in your Oracle Cloud tenancy and [generate an access token and secret key](https://docs.cloud.oracle.com/iaas/Content/Identity/Tasks/managingcredentials.htm#Working2). We'll need to set some environment variables, so I like to create a file called env.sh in my build-resource directory to handle setting all of them so I can source that file when working with the project. That file usually looks like this:
```bash
#!/usr/bin/env bash

export DB_USER=[your schema user]
export DB_PASSWORD=[your schema password]
export CONNECT_STRING=[your connect string - ex: demodb_low]
export POST_COLLECTION=post_collection
export ACCESS_TOKEN=[your object storage user access token]
export SECRET_KEY=[your object storage user secret key]
export REGION=[your object storage region - ex: us-phoenix-1]
export STORAGE_TENANCY=[your OCI tenancy name]
export BUCKET=[your object storage bucket name - ex: cloud-native-microservice-posts]
```



Source the `env.sh` file to set these variables into your session.

To test and deploy our application we're going to utilize Docker. This will keep everything nice and compartmentalized in the container and prevent us from installing dependencies on our local machine. The `Dockerfile` is not complicated, so create one in the root that looks like so:
```text
FROM oraclelinux:7-slim

RUN yum -y install oracle-release-el7 oracle-nodejs-release-el7 && \
    yum-config-manager --disable ol7_developer_EPEL && \
    yum -y install oracle-instantclient19.3-basiclite nodejs && \
    rm -rf /var/cache/yum

COPY build-resource/wallet/* /usr/lib/oracle/19.3/client64/lib/network/admin/

WORKDIR /app
ADD . /app/
RUN npm install
ENTRYPOINT ["npm", "start"]
```



We're using Oracle Linux for the base image, installing some dependencies (notably the Oracle DB instant client), copying our wallet into the image and our application source code, installing our app with NPM and then starting the app in our entry point. At this point we can build and run the application to make sure we've got everything set up properly:
```bash
docker build -t post-svc .
docker run post-svc
```



Confirm that the application responds at http://localhost:3000.

Now let's rename the stock 'user' routes that Express gives us in the `routes/` directory to `posts.js` (make sure to update any other references in the application, such as in the `app.js` file). The `posts.js` route file will be where all of our endpoints are defined for the post service.

## The Post Service

Before we define our endpoints, let's create a service that we will use for our persistence and query operations. Create a new directory called `service/` in the root of the project and create a file within that directory called `post-service.js`.  The post service will be a class that creates our default connection pool and performs our database operations. Start out by importing some dependencies, setting some options on the `oracledb` object and creating an `init()` method to handle the connection pool creation:
```javascript
const oracledb = require('oracledb');
const uuidv4 = require('uuid/v4');

oracledb.outFormat = oracledb.OBJECT;
oracledb.fetchAsString = [oracledb.CLOB];
oracledb.autoCommit = true;

module.exports = class PostService {

    constructor(){ }

    static async init() {
        console.log('Creating connection pool...')
        await oracledb.createPool({
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
            connectString: process.env.CONNECT_STRING,
        });
        console.log('Connection pool created')
        return new PostService();
    }

    async closePool() {
        console.log('Closing connection pool...');
        try {
            await oracledb.getPool().close(10);
            console.log('Pool closed');
        } catch(err) {
            console.error(err);
        }
    }
}
```



Now modify `app.js` to create our service object and set it into the application so that we can retrieve it later on from our route controller. I'll include the whole file contents here, but take note of the additions we made on lines 5, 25-27 and 30-33.
```javascript
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const PostService = require('./service/post-service');
const ObjectService = require('./service/object-service');
const config = require('./config/config.js');

const indexRouter = require('./routes/index');
const postRouter = require('./routes/posts');
const fileUpload = require('express-fileupload');

const app = express();

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

app.use(fileUpload());
app.use('/', indexRouter);
app.use('/post', postRouter);

PostService.init().then((postService) => {
    app.set('postService', postService);
});
app.set('objectService', new ObjectService(config));

process.on('exit', function() {
    app.get('postService').closePool();
    console.log('goodbye...');
});

module.exports = app;
```



Now let's add a `save()` method. Here's where we'll see the simplicity of SODA in action. The save method accepts a JavaScript Object, grabs a connection to Oracle DB, and grabs the 'soda' database object. We use the soda object `createCollection()` method which will create the collection in the database if none exists, or return an existing collection by the name we specify - either way, we get the collection back that can be used going forward. To persist our 'post' JS object, we simply call `postCollection.insertOneAndGet()` which does just what it says on the tin: inserts the object and returns it to us. That's it. Our JSON document is stored in our collection.
```javascript
async save(post) {
    let connection, newPost, result;

    try {
        connection = await oracledb.getConnection();
        const soda = connection.getSodaDatabase();
        const postCollection = await soda.createCollection(process.env.POST_COLLECTION);
        /*
            insertOneAndGet() does not return the doc
            for performance reasons
            see: http://oracle.github.io/node-oracledb/doc/api.html#sodacollinsertoneandget
        */
        newPost = await postCollection.insertOneAndGet(post);
        result = {
            id: newPost.key,
            createdOn: newPost.createdOn,
            lastModified: newPost.lastModified,
        };
    }
    catch(err) {
        console.error(err);
    }
    finally {
        if (connection) {
            try {
                await connection.close();
            }
            catch(err) {
                console.error(err);
            }
        }
    }

    return result;
}
```



Updating is almost identical to saving a new object, the only difference being that we first retrieve the object and then call `replaceOneAndGet()`:
```javascript
async update(id, post) {
    let connection, result;

    try {
        connection = await oracledb.getConnection();
        const soda = connection.getSodaDatabase();
        const postCollection = await soda.createCollection(process.env.POST_COLLECTION);
        post = await postCollection.find().key(id).replaceOneAndGet(post);
        result = {
            id: post.key,
            createdOn: post.createdOn,
            lastModified: post.lastModified,
        };
    }
    catch(err) {
        console.error(err);
    }
    finally {
        if (connection) {
            try {
                await connection.close();
            }
            catch(err) {
                console.error(err);
            }
        }
    }

    return result;
}
```



To get a post by ID, we use `find().key(id).getOne()`:
```javascript
async getById(postId) {
    let connection, post, result;

    try {
        connection = await oracledb.getConnection();

        const soda = connection.getSodaDatabase();
        const postCollection = await soda.createCollection(process.env.POST_COLLECTION);
        post = await postCollection.find().key(postId).getOne();
        result = {
            id: post.key,
            createdOn: post.createdOn,
            lastModified: post.lastModified,
            document: post.getContent(),
        };

    }
    catch(err) {
        console.error(err);
    }
    finally {
        if (connection) {
            try {
                await connection.close();
            }
            catch(err) {
                console.error(err);
            }
        }
    }

    return result;
}
```



To delete a post by ID, we use `find().key(id).remove()`:
```javascript
async deleteById(postId) {
    let connection;
    let removed = false;

    try {
        connection = await oracledb.getConnection();

        const soda = connection.getSodaDatabase();
        const postCollection = await soda.createCollection(process.env.POST_COLLECTION);
        removed = await postCollection.find().key(postId).remove();

    }
    catch(err) {
        console.error(err);
    }
    finally {
        if (connection) {
            try {
                await connection.close();
            }
            catch(err) {
                console.error(err);
            }
        }
    }
    return removed;
}
```



We can also query by example to find posts by elements contained within the JSON document itself. For example, we can query by the userId key within our post JSON like so:
```javascript
async getByUserId(userId, offset, max) {
    let connection;
    const result = [];

    try {
        connection = await oracledb.getConnection();

        const soda = connection.getSodaDatabase();
        const postCollection = await soda.createCollection(process.env.POST_COLLECTION);
        let posts;
        let filter = {
            "$query": {"userId": userId},
            "$orderby": [
                {
                    "path": "postedOn",
                    "order": "desc",
                }
            ]
        };
        if( offset && max ) {
            posts = await postCollection.find().filter(filter).skip(+offset).limit(+max).getDocuments();
        }
        else {
            posts = await postCollection.find().filter(filter).getDocuments();
        }
        posts.forEach(function(element) {
            result.push( {
                id: element.key,
                createdOn: element.createdOn,
                lastModified: element.lastModified,
                document: element.getContent(),
            } );
        });
    }
    catch(err) {
        console.error(err);
    }
    finally {
        if (connection) {
            try {
                await connection.close();
            }
            catch(err) {
                console.error(err);
            }
        }
    }
    return result;
}
```



The full [documentation for using SODA with Node](https://oracle.github.io/node-oracledb/doc/api.html) contains many more methods that can be used in addition to those shown above.

## Object Storage Service

With our CRUD methods implemented, we can now create an `object-service.js` class that we'll use to upload items to object storage in our application. As I stated earlier, we're using the AWS SDK for this operation:
```javascript
const AWS = require('aws-sdk');
const uuidv4 = require('uuid/v4');

module.exports = class ObjectService{

    constructor(config) {

        // update the client config
        AWS.config.update({
            region: config.storageRegion,
            credentials: new AWS.Credentials(config.accessToken, config.secretKey),
            s3ForcePathStyle: true,
        });
        // set the Object Storage endpoint
        AWS.config.s3 = { endpoint: `${config.storageUrl}` };

        this.s3 = new AWS.S3({
            params: { Bucket: config.storageBucket }
        });
    }

    async upload(object, mime) {
        return await this.s3.upload({
            Key: uuidv4(),
            Body: object,
            ContentType: mime,
        }).promise();
    }

}
```



And that's all we need to do to upload objects to our Oracle Cloud object storage bucket. We could expand this service to implement other features as needed, simply refer to the AWS Node documentation for the necessary methods.

## Validation

Now let's add some validation for our posts objects because even though we're using JSON document storage, we'd still like to implement some validation rules on the objects that we are persisting. Create a file called `model/post-schema.js`:
```javascript
const Joi = require('@hapi/joi');

const schema = Joi.object().keys({
    userId: Joi.string().alphanum().required(),
    title: Joi.string().max(300).required(),
    type: Joi.string().allow('text', 'link', 'image', 'video').required(),
    content: Joi.string().max(2000),
    postedOn: Joi.date().default(Date.now, 'postedOn timestamp').required(),
});

const options = {
    "abortEarly": false,
    "allowUnknown": true,
};

module.exports = {
    schema: schema,
    options: options,
};
```



We're using [Joi from hapi.js](https://github.com/hapijs/joi) for our validation, and we'll call this schema in our route controller to ensure our post objects are valid before persisting.

## Updating The Router

Head back to our routes/post.js file and add our endpoints that will call our post service. This is a pretty standard REST implementation with the only notable items being the file uploads that use the object service if a file has been uploaded and the addition of the `cors()` and `asyncHandler()` middleware
```javascript
const express = require('express');
const router = express.Router();
const cors = require('cors');
const asyncHandler = require('express-async-handler')
const postSchema = require('../model/post-schema');

router.get('/', cors(), asyncHandler( async (req, res, next) => {
  res.send( { "health": "OK", "at": new Date() } );
}));

router.post('/', cors(), asyncHandler( async (req, res, next) => {
  const post = JSON.parse(req.body.post);
  const valid = postSchema.schema.validate( post, postSchema.options );
  if( valid.error ) {
    res.status(400).send( valid.error.details );
  }
  else {
    let file = req.files ? req.files.upload : null;
    if( file ) {
      const uploadResult = await res.app.get('objectService').upload(file.data, file.mimetype);
      post.key = uploadResult.key;
    }
    res.status(201).send( await res.app.get('postService').save(post) );
  }
}));

router.put('/:id', cors(), asyncHandler( async (req, res, next) => {
  const post = JSON.parse(req.body.post);
  const valid = postSchema.schema.validate( post, postSchema.options );
  if( valid.error ) {
    res.status(400).send( valid.error.details );
  }
  else {
    // no files accepted on update
    res.status(200).send( await res.app.get('postService').update(req.params.id, JSON.parse(req.body.post)) );
  }
}));

router.get('/:id', cors(), asyncHandler( async (req, res, next) => {
  res.send( await res.app.get('postService').getById(req.params.id) );
}));

router.get('/user/:id', cors(), asyncHandler( async (req, res, next) => {
  res.send( await res.app.get('postService').getByUserId(req.params.id) );
}));

router.get('/user/:id/:offset/:max', cors(), asyncHandler( async (req, res, next) => {
  res.send( await res.app.get('postService').getByUserId(req.params.id, req.params.offset, req.params.max) );
}));

router.delete('/:id', cors(), asyncHandler( async (req, res, next) => {
  const deleted = await res.app.get('postService').deleteById(req.params.id);
  res.status(deleted.count == 1 ? 204 : 404).end();
}));


module.exports = router;
```



## Testing Endpoints

At this point we are ready to test our endpoints. Build and run the Docker container and use test them out via cURL:

This service will persist social media "posts" as JSON documents. The general document format is as follows:
```json
{
  "userId": "[String]",
  "title": "[String]",
  "type": "[String - one of: text, image, link, video]",
  "key": "[Optional - String]", 
  "content": "[Optional - String]",
  "postedOn": "[Date]"
}
```



Save a new post (image/video - returns \`201 Created\`):
```bash
curl -iX POST http://localhost:3000/post -F 'post={"userId":"8C561D58E856DD25E0532010000AF462", "title": "Hello", "type": "image", "postedOn": "2019-07-16T15:57:17"}' -F 'upload=@./build-resource/oracle_cloud.jpg'
HTTP/1.1 100 Continue
HTTP/1.1 201 Created
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 128
ETag: W/"80-GnZIOrxd8Lt1Zq1fRMs+zbzNT6k"
Date: Wed, 17 Jul 2019 01:24:50 GMT
Connection: keep-alive
{"id":"D0724C30A9804F85BFCADAC86DCC4F90","createdOn":"2019-07-17T01:24:52.475825Z","lastModified":"2019-07-17T01:24:52.475825Z"}
```



Save a new post (text/link - returns \`201 Created\`):
```bash
curl -iX POST http://localhost:3000/post -F 'post={"userId":"8C561D58E856DD25E0532010000AF462", "title": "Hello", "type": "text", "content": "hi", "postedOn": "2019-07-16T15:57:17"}' -F 'upload=@./post1.json'
HTTP/1.1 100 Continue
HTTP/1.1 201 Created
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 128
ETag: W/"80-GnZIOrxd8Lt1Zq1fRMs+zbzNT6k"
Date: Wed, 17 Jul 2019 01:24:50 GMT
Connection: keep-alive
{"id":"D0724C30A9804F85BFCADAC86DCC4F90","createdOn":"2019-07-17T01:24:52.475825Z","lastModified":"2019-07-17T01:24:52.475825Z"}
```



Save a new post with invalid data (returns \`400 Bad Request\`):
```bash
curl -iX POST http://localhost:3000/post -F 'post={"userId":"", "title": "", "type": "foo", "postedOn": "asdf"}'
HTTP/1.1 100 Continue
HTTP/1.1 400 Bad Request
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 666
ETag: W/"29a-SLEkJP0Cv1ai5ufY8tVHBsLPNt0"
Date: Thu, 18 Jul 2019 13:25:39 GMT
Connection: keep-alive
[{"message":""userId" is not allowed to be empty","path":["userId"],"type":"any.empty","context":{"value":"","invalids":[""],"key":"userId","label":"userId"}},{"message":""userId" must only contain alpha-numeric characters","path":["userId"],"type":"string.alphanum","context":{"value":"","key":"userId","label":"userId"}},{"message":""title" is not allowed to be empty","path":["title"],"type":"any.empty","context":{"value":"","invalids":[""],"key":"title","label":"title"}},{"message":""postedOn" must be a number of milliseconds or valid date string","path":["postedOn"],"type":"date.base","context":{"value":"asdf","key":"postedOn","label":"postedOn"}}]
```



Update an existing post (returns \`200 OK\`:
```bash
curl -iX PUT http://localhost:3000/post/D0724C30A9804F85BFCADAC86DCC4F90 -F 'post={"userId":"8C561D58E856DD25E0532010000AF462", "title": "Hello", "type": "text", "content": "hi, world", "postedOn": "2019-07-16T15:57:17"}'
HTTP/1.1 100 Continue
HTTP/1.1 200 OK
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 128
ETag: W/"80-50Ex5F4jwyiOTwJ8vVkRcFbiMEw"
Date: Wed, 17 Jul 2019 01:26:03 GMT
Connection: keep-alive
{"id":"D0724C30A9804F85BFCADAC86DCC4F90","createdOn":"2019-07-17T01:24:52.475825Z","lastModified":"2019-07-17T01:26:04.999894Z"}
```



Update an existing post with invalid data (returns \`400 Bad Request\`):
```bash
curl -iX PUT http://localhost:3000/post/D0724C30A9804F85BFCADAC86DCC4F90 -F 'post={"userId":"8C561D58E856DD25E0532010000AF462", "title": "", "type": "text", "content": "hi, world", "postedOn": "2019-07-16T15:57:17"}'
HTTP/1.1 100 Continue
HTTP/1.1 400 Bad Request
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 157
ETag: W/"9d-tLFV/E5pYY5/tXZV1iUIonhM1Ms"
Date: Thu, 18 Jul 2019 13:30:21 GMT
Connection: keep-alive
[{"message":""title" is not allowed to be empty","path":["title"],"type":"any.empty","context":{"value":"","invalids":[""],"key":"title","label":"title"}}]
```



Get a post by ID:
```bash
curl -iX GET http://localhost:3000/post/11D60176464F4FD9BFD625FB79730575  
HTTP/1.1 200 OK
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 272
ETag: W/"110-sl//10GolzZQt8TGgiprUaqBbWQ"
Date: Tue, 16 Jul 2019 20:13:08 GMT
Connection: keep-alive
{"id":"11D60176464F4FD9BFD625FB79730575","createdOn":"2019-07-16T20:09:26.174380Z","lastModified":"2019-07-16T20:11:00.330014Z","document":{"userId":"8C561D58E856DD25E0532010000AF462","title":"Hello","type":"text","content":"Hello World","postedOn":"2019-07-16T15:57:17"}}
```



Get all posts by user ID:
```bash
curl -iX GET http://localhost:3000/post/user/8C561D58E856DD25E0532010000AF462
HTTP/1.1 200 OK
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 1109
ETag: W/"455-A/bZ8d3i4xDiu0hpl7DwwBhUuCY"
Date: Tue, 16 Jul 2019 20:32:02 GMT
Connection: keep-alive
[{"id":"11D60176464F4FD9BFD625FB79730575","createdOn":"2019-07-16T20:09:26.174380Z","lastModified":"2019-07-16T20:11:00.330014Z","document":{"userId":"8C561D58E856DD25E0532010000AF462","title":"Hello","type":"text","content":"Hello World","postedOn":"2019-07-16T15:57:17"}},{"id":"8D648568F1144F8FBF50D06274B397A9","createdOn":"2019-07-16T20:05:23.400850Z","lastModified":"2019-07-16T20:07:49.205996Z","document":{"userId":"8C561D58E856DD25E0532010000AF462","title":"Hello","type":"text","content":"Hello World","postedOn":"2019-07-16T15:57:17"}},{"id":"E42FF88A25AC4F52BF2A891123A6414D","createdOn":"2019-07-16T20:00:23.096193Z","lastModified":"2019-07-16T20:00:23.096193Z","document":{"userId":"8C561D58E856DD25E0532010000AF462","title":"Hello","type":"text","content":"hi","postedOn":"2019-07-16T15:57:17","updatedOn":"2019-07-16T15:57:17"}},{"id":"294331C941774F17BF1871A8D80EB2E1","createdOn":"2019-07-16T20:03:17.748867Z","lastModified":"2019-07-16T20:03:17.748867Z","document":{"userId":"8C561D58E856DD25E0532010000AF462","title":"Hello","type":"text","content":"hi","postedOn":"2019-07-16T15:57:17"}}]
```



Get posts by user ID (paginated):
```bash
curl -iX GET http://localhost:3000/post/user/8C561D58E856DD25E0532010000AF462/0/1
HTTP/1.1 200 OK
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 274
ETag: W/"112-2WSahnJdgkVk/jjAPKnaIUQkFxc"
Date: Tue, 16 Jul 2019 20:29:01 GMT
Connection: keep-alive
[{"id":"11D60176464F4FD9BFD625FB79730575","createdOn":"2019-07-16T20:09:26.174380Z","lastModified":"2019-07-16T20:11:00.330014Z","document":{"userId":"8C561D58E856DD25E0532010000AF462","title":"Hello","type":"text","content":"Hello World","postedOn":"2019-07-16T15:57:17"}}]
```



Delete a post:
```bash
curl -iX DELETE http://localhost:3000/post/E42FF88A25AC4F52BF2A891123A6414D
HTTP/1.1 204 No Content
X-Powered-By: Express
Access-Control-Allow-Origin: *
Date: Tue, 16 Jul 2019 20:37:43 GMT
Connection: keep-alive
```



Delete a post that does not exist:
```bash
curl -iX DELETE http://localhost:3000/post/E42FF88A25AC4F52BF2A891123A6414D
HTTP/1.1 404 Not Found
X-Powered-By: Express
Access-Control-Allow-Origin: *
Date: Tue, 16 Jul 2019 20:37:45 GMT
Connection: keep-alive
Content-Length: 0
```



## Deploying

You can push this service to your OCIR Docker Registry:
```text
docker build -t [region].ocir.io/[tenancy]/cloud-native-microservice/post-svc .
docker push [region].ocir.io/[tenancy]/cloud-native-microservice/post-svc
```



Refer to this [app.yaml file for an example that can be used](https://github.com/cloud-native-microservices/post-svc-node-soda/blob/master/app.yaml) to deploy to your OKE Kubernetes cluster.

## Summary

In this post we created a microservice that persists JSON documents in a collection within our Autonomous Transaction Processing (ATP) database in Oracle Cloud. We added support for object upload in that service and deployed it in a Docker container on Kubernetes. 

## Reference

If you'd like to catch up on the previous posts in this series, please refer to the links below.

Helidon And Hibernate:

- [Building A Helidon Microservice Part 1](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-1)
- [Building A Helidon Microservice Part 2](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-2)
- [Building A Helidon Microservice Part 3](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-3)

ORDS With Micronaut:

- [Microservices The Easy Way With ORDS And Micronaut - Part 1](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-1)
- [Microservices The Easy Way With ORDS And Micronaut - Part 2](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-2)
- [Microservices The Easy Way With ORDS And Micronaut - Part 3](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-3)

The full source for this example can be found on GitHub: <https://github.com/cloud-native-microservices/post-svc-node-soda> 

[Photo by ][Wade Austin Ellis](https://unsplash.com/@wadeaustinellis?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/collections/4937220/drink?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
