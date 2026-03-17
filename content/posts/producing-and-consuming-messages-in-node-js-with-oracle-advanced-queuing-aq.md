---
title: "Producing and Consuming Messages in Node.JS with Oracle Advanced Queuing (AQ)"
slug: "producing-and-consuming-messages-in-node-js-with-oracle-advanced-queuing-aq"
author: "Todd Sharp"
date: 2021-11-19
summary: "In this post, we'll create a simple Node.JS application that interacts with an Oracle AQ queue to send and receive messages."
tags: ["Messaging", "Node"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/nature-g8469e93a3_1280.jpeg"
---

If you've been following my blog posts lately, you may have noticed that I've been focusing a bit on messaging. We talked a while back about using [Oracle Advanced Queuing (AQ) with Micronaut](https://blogs.oracle.com/developers/post/enterprise-messaging-via-oracle-advanced-queuing-with-autonomous-db-micronaut) in a Java application, and more recently we looked at how to [interact with AQ via REST APIs](https://blogs.oracle.com/developers/post/send-and-receive-messages-via-rest-with-advanced-queuing-and-ords). But there's another way to work with AQ natively that we haven't looked at yet - and that method is to use the `oracledb` module with Node.JS. I certainly don't have to tell you about the popularity of Node, and using it to interact with AQ is very straightforward. So let's dig in and create an Express application that can enqueue and dequeue messages. We're going to build on this example going forward, so stay tuned for some exciting follow-up posts in the near future. If you get stuck at any point or want to dig further into this functionality, check out the [documentation on using AQ with the Node oracledb module](https://oracle.github.io/node-oracledb/doc/api.html#aq).

In this post, we're going to perform the following tasks:

- [Create Queue](#Create%20Queue)
- [Create Application](#toc_Create-Application)
- [Create Service](#Create%20Service)
  - [Add Enqueue (Single) Method](#Add%20Enqueue%20(Single)%20Method)
  - [Add Dequeue (Single) Method](#Add%20Dequeue%20(Single)%20Method)
  - [Add Dequeue (Many) Method](#Add%20Dequeue%20(Many)%20Method)
- [Initialize the Queue Service](#Initialize%20the%20Queue%20Service)
- [Add HTTP Endpoints to Queue/Dequeue](#Add%20HTTP%20Endpoints%20to%20Queue/Dequeue)
  - [Add Enqueue Endpoint](#Add%20Enqueue%20Endpoint)
  - [Add Dequeue (Single) Endpoint](#Add%20Dequeue%20(Single)%20Endpoint)
  - [Add Dequeue (Many) Endpoint](#Add%20Dequeue%20(Many)%20Endpoint)
  - [Bonus: Dequeue Messages in a Stream!](#Bonus:%20Dequeue%20Messages%20in%20a%20Stream!)
- [Summary](#Summary)

**Reminder!** AQ is included at **no charge** in Autonomous DB. Also, you can turn up 2 free Autonomous DB instances in the Oracle Cloud "**always free**" tier, so running this demo (or using this code in production) will *cost you absolutely nothing*!!

## Create Queue 

The first thing we need to do is make sure that we have a user with the proper permissions and roles. If this is your first time working with AQ, open a SQL editor and run the following as the `admin` user.
```sql
CREATE USER aqdemouser IDENTIFIED BY "AStr0ngPassw3rd!";
GRANT connect TO aqdemouser;
GRANT unlimited tablespace TO aqdemouser;
GRANT aq_administrator_role, aq_user_role TO aqdemouser;
GRANT EXECUTE ON DBMS_AQ TO aqdemouser;
```
```sql
// is this necessary for CQN subscriptions?
GRANT EXECUTE ON DBMS_CQ_NOTIFICATION TO aqdemouser;
GRANT CHANGE NOTIFICATION TO aqdemouser;
```



Next, open a new SQL editor and connect as the newly created `aqdemouser` user. We will need to create a queue table, a queue, and then start the queue. Our queue name will be [`AQDEMOUSER.MQTT_BRIDGE_QUEUE` (we'll need to use this later on in our JavaScript code, so keep it handy).]
```sql
BEGIN
  DBMS_AQADM.CREATE_QUEUE_TABLE(
    QUEUE_TABLE        =>  'AQDEMOUSER.MQTT_BRIDGE_TBL',
    QUEUE_PAYLOAD_TYPE =>  'RAW');

  DBMS_AQADM.CREATE_QUEUE(
    QUEUE_NAME         =>  'AQDEMOUSER.MQTT_BRIDGE_QUEUE',
    QUEUE_TABLE        =>  'AQDEMOUSER.MQTT_BRIDGE_TBL');

  DBMS_AQADM.START_QUEUE(
    QUEUE_NAME         => 'AQDEMOUSER.MQTT_BRIDGE_QUEUE');
END;
/
```



At this point, the queue is ready to `enqueue` (send) and `dequeue` (receive) messages. If you feel like testing the queue to make sure it's working as expected, run the following.

Enqueue a JSON string as a message:
```sql
DECLARE
    l_enqueue_options     dbms_aq.enqueue_options_t;
    l_message_properties  dbms_aq.message_properties_t;
    l_message_handle      raw(16);
    l_event_msg           raw(32767);
BEGIN
    l_event_msg := utl_raw.cast_to_raw('{"name": "Todd", "id": 9}');
    dbms_aq.enqueue(queue_name => 'AQDEMOUSER.MQTT_BRIDGE_QUEUE',
                   enqueue_options => l_enqueue_options,
                   message_properties => l_message_properties,
                   payload => l_event_msg,
                   msgid => l_message_handle);

    COMMIT;
END;
/
```



Which should return:

`PL/SQL procedure successfully completed.`

Dequeue the JSON string message, parse the object, and retrieve an element from the JSON object:
```sql
SET SERVEROUTPUT ON
DECLARE
    l_dequeue_options     dbms_aq.dequeue_options_t;
    l_message_properties  dbms_aq.message_properties_t;
    l_message_handle      raw(16);
    l_event_msg           raw(32767);
    msg_text              varchar2(32767);
    obj                   json_object_t;
BEGIN
    dbms_aq.dequeue(queue_name => 'AQDEMOUSER.MQTT_BRIDGE_QUEUE',
                   dequeue_options => l_dequeue_options,
                   message_properties => l_message_properties,
                   payload => l_event_msg,
                   msgid => l_message_handle);

    msg_text := utl_raw.cast_to_varchar2(l_event_msg);
    /* print the raw message */
    dbms_output.put_line(msg_text);
    /* parse the JSON object */
    obj := json_object_t.parse(msg_text);
    /* print an element from the JSON object */
    dbms_output.put_line(obj.get_String('name'));
    COMMIT;
END;
/
```



Which returns:
```sql
{"name": "Todd", "id": 9}
Todd
PL/SQL procedure successfully completed.
```



How long did that take, 2 minutes? Not bad, eh?

## Create Application 

Let's create an Express application to work with our demo queue. That'll give us the ability to expose some HTTP endpoints for enqueuing and dequeuing messages. Of course, messaging might normally happen "behind the scenes" in a microservice (or monolith) in response to user actions or other business rules. But for this demo, it gives us a nice way to test out the queue. Run the following command to quickly scaffold out an Express application (this assumes you have the [Express application generator](https://expressjs.com/en/starter/generator.html) installed). We'll also install the `oracledb` and (optionally) the `debug` module (for pretty debug messages) while we're at it.
```bash
express mqtt-aq-demo
npm install oracledb debug
```



The application will eventually need some sensitive values (username, password, etc) to connect to the queue. Let's use `dotenv` so that we can store those credentials in environment variables.
```bash
npm install dotenv
```



Now we can create a file called `.env` in the project root, and populate our credentials. 

**Heads Up!** To use the Node `oracledb` module, you need to configure it just a bit (you'll need an Instant Client and your Autonomous DB wallet). There's a [handy doc online that walks you through installing the module](https://oracle.github.io/node-oracledb/INSTALL.html) depending on your Operating System. Make sure you've done that first, and then use the paths to your instant client and wallet in your `.env` file below.
```text
DB_USER=aqdemouser
DB_PASSWORD=AStr0ngPassw3rd!
CONNECT_STRING=demodb_low
QUEUE_NAME=AQDEMOADMIN.MQTT_BRIDGE_QUEUE
INSTANT_CLIENT_PATH=/projects/resources/instantclient_19_3 
WALLET_PATH=/projects/resources/Wallet_demodb
```



**Connect String?** If you're not sure where this comes from, it's a [predefined string](https://docs.oracle.com/en/cloud/paas/atp-cloud/atpgs/autonomous-connect-database-service-names.html#GUID-9747539B-FD46-44F1-8FF8-F5AC650F15BE) that uses the format \[dbname\]\_\[type\]. You can choose the \[type\] based on the level of performance and concurrency required for your application. A list of these values can be found in the `tnsnames.ora` file inside your wallet.

Let's move on to creating a service class that will encapsulate all of our queuing activities. We'll be able to inject this service into our router (and other places in the application) later on.

## Create Service 

The `QueueService` is a basic class that will encapsulate our DB work related to our queue. As such, we'll need to include the `oracledb` module and store our credentials in the class for use from the methods that we'll add in just a bit. Create the class, and add an `init()` method (we'll pass the values in later on when we instantiate this class).
```javascript
const oracledb = require('oracledb');
const debug = require('debug')('queue-service'); //optional

class QueueService {

    init(instantClientPath, walletPath, queueName, dbUser, dbPassword, connectString) {
        this.queueName = queueName;
        this.dbUser = dbUser;
        this.dbPassword = dbPassword;
        this.connectString = connectString;
        oracledb.initOracleClient({
            libDir: instantClientPath,
            configDir: walletPath,
        });
        this.pool = null;
        this.eventsPool = null;
    };

}

module.exports = new QueueService();
```



We're going to use a lot of async/await code in this class in order to prevent having to litter the class with a bunch of callbacks. It'll also be handy to add a "helper" method to retrieve a connection pool so that we don't have to do that in each method, so let's add an async method called `getPool()` to the `QueueService`.
```javascript
async getPool() {
    if (!this.pool) {
        this.pool = await oracledb.createPool({
            user: this.dbUser,
            password: this.dbPassword,
            connectString: this.connectString,
        });
    }
    return this.pool;
};
```



And since we want to make sure things are cleaned up when we are done, add a method to close it.
```javascript
async closePool() {
    return this.pool ? await getPool.close() : true;
};
```



### Add Enqueue (Single) Method 

We'll want to add a method that will enable us to produce a single message into the queue. To do this, we need to get the connection pool (`this.getPool()`), grab a connection to the DB from that pool (`pool.getConnection()`), and then get our queue from the connection (`connection.getQueue(this.queueName)`). Once we have the queue, we can produce a message (`queue.enqOne()`), passing it a string that contains the message (in this case, an object that is converted to a JSON string). Then we commit the transaction (`connection.commit()`) and close the connection (`connection.close()`).
```javascript
async enqueueOne(msg) {
    const pool = await this.getPool();
    const connection = await pool.getConnection();
    const queue = await connection.getQueue(this.queueName);
    let response;
    try {
        response = await queue.enqOne(JSON.stringify(msg));
    }
    catch(e) {
        debug(`Error enqueuing: '${e}'`);
    }
    finally {
        await connection.commit();
        await connection.close();
    }
    return response;
};
```



We can also enqueue an array of messages all at once if we need to by using the `queue.enqMany()` method. For more information on this, refer to the [documentation](https://oracle.github.io/node-oracledb/doc/api.html#aqqueuemethodenqmany).

### Add Dequeue (Single) Method 

Next, let's add a method to dequeue a single message. The process here is similar to enqueuing - get the pool, a connection, the queue, call `queue.deqOne()`, commit and close. Notice that we're setting a value of [`oracledb.AQ_DEQ_NO_WAIT`  ]into our queue's options via `queue.deqOptions.wait`. If we didn't set this option, the queue would wait for an available message before returning, which is not what we want for this demo.
```javascript
async dequeueOne() {
    const pool = await this.getPool();
    const connection = await pool.getConnection();
    const queue = await connection.getQueue(this.queueName);
    queue.deqOptions.wait = oracledb.AQ_DEQ_NO_WAIT;
    let msg = {};
    try {
        msg = await queue.deqOne();
    }
    catch(e) {
        debug(`Error dequeuing: '${e}'`);
    }
    finally {
        await connection.commit();
        await connection.close();
    }
    return msg;
};
```



### Add Dequeue (Many) Method 

Just as with enqueuing, we can dequeue multiple messages at the same time. Let's add a method to dequeue an array of messages. It's almost identical to the `dequeueOne()` method above, except that we're calling `deqMany()` on the queue instead of `deqOne()`. Note that we can limit the number of messages dequeued with each call by passing an integer to the `deqMany()` method.
```javascript
async dequeueMany(howMany) {
    const pool = await this.getPool();
    const connection = await pool.getConnection();
    const queue = await connection.getQueue(this.queueName);
    queue.deqOptions.wait = oracledb.AQ_DEQ_NO_WAIT;
    let msg;
    try {
        msg = await queue.deqMany(howMany);
    }
    catch(e) {
        debug(`Error dequeuing: '${e}'`);
    }
    finally {
        await connection.commit();
        await connection.close();
    }
    return msg;
};
```



And that does it for the `QueueService`. It's ready to do its work.

## Initialize the Queue Service 

Before we can use the `QueueService`, we need to set our credentials into it. Recall that we have our credentials set as environment variables, so we just need to pass them in at runtime to the service via the `init()` method. Open up the `app.js` file and do that like so:
```javascript
const queueService = require('./services/QueueService');
queueService.init(
	process.env.INSTANT_CLIENT_PATH,
	process.env.WALLET_PATH,
	process.env.QUEUE_NAME, 
	process.env.DB_USER, 
	process.env.DB_PASSWORD, 
	process.env.CONNECT_STRING
);
```



While we're here, let's make sure that we properly close the pool when the app shuts down.
```javascript
const queueService = require('./services/QueueService');
queueService.init(
	process.env.INSTANT_CLIENT_PATH,
	process.env.WALLET_PATH,
	process.env.QUEUE_NAME, 
	process.env.DB_USER, 
	process.env.DB_PASSWORD, 
	process.env.CONNECT_STRING
);
```



## Add HTTP Endpoints to Queue/Dequeue 

So our app is configured, and our service is created and initialized. Now we can expose a few endpoints to let us interact! In `index.js`, inject the initialized `QueueService`.
```javascript
const queueService = require('../services/QueueService');
```



### Add Enqueue Endpoint 

Create an endpoint to POST a message to the queue.
```javascript
router.post('/enqueue', async function (req, res, next) {
    const response = await queueService.enqueueOne(req.body);
    res.status(201);
    res.json(response);
});
```



We can test this by POSTing a few messages via cURL:
```bash
$ curl -X POST localhost:3000/enqueue -H "Content-Type: application/json" -d '{"test": "message", "message": 1}'
$ curl -X POST localhost:3000/enqueue -H "Content-Type: application/json" -d '{"test": "message", "message": 2}'
$ curl -X POST localhost:3000/enqueue -H "Content-Type: application/json" -d '{"test": "message", "message": 3}'
```



If you want, add `-i` to the cURL request to view the response headers (confirming the `201` status response):
```bash
HTTP/1.1 201 Created
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Date: Wed, 22 Sep 2021 14:58:47 GMT
Connection: keep-alive
Keep-Alive: timeout=5
Content-Length: 0
```



### Add Dequeue (Single) Endpoint 

Create an endpoint to GET a single message.
```javascript
router.get('/dequeueOne', async function (req, res, next) {
    const msg = await queueService.dequeueOne();
    if (msg && msg.payload) {
        res.json(JSON.parse(msg.payload.toString()));
    } else {
        res.json({});
    }
});
```



A quick cURL to test it:
```bash
$ curl -s localhost:3000/dequeueOne | jq
{
  "test": "message",
  "message": 1
}
```



### Add Dequeue (Many) Endpoint 

Add endpoint to GET an array of messages:
```javascript
router.get('/dequeueMany', async function (req, res, next) {
    const msg = await queueService.dequeueMany(25);
    if (msg) {
        const response = msg;
        const msgs = [];
        response.forEach((aqMessage, idx) => {
            msgs.push(JSON.parse(aqMessage.payload.toString()))
        });
        res.json(msgs);
    } else {
        res.json([]);
    }
});
```



Another test to confirm that we get an array back (containing the remaining 2 enqueued messages):
```bash
$ curl -s localhost:3000/dequeueMany | jq
[
  {
    "test": "message",
    "message": 2
  },
  {
    "test": "message",
    "message": 3
  }
]
```



### Bonus: Dequeue Messages in a Stream! 

As a special added bonus, we can also add a `/dequeueStream` endpoint that uses Server-Sent Events to return a constant stream of messages. Here we simply create an interval that tries to dequeue a single message every second. If a message exists, we write it to the open stream. When the client disconnects, we clear the interval and call `res.end()`.
```javascript
router.get('/dequeueStream', async function (req, res, next) {
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();
    res.write('retry: 1000\n\n');
    const interval = setInterval(async () => {
        const msg = await queueService.dequeueOne();
        if (msg && msg.payload) {
            res.write(`data: ${msg.payload.toString()}\n\n`);
        } else {
            res.write(`data: {}\n\n`);
        }
    }, 1000);

    res.on('close', () => {
        clearInterval(interval);
        setTimeout(() => res.end(), 500)
    });
});
```



We can also test this in cURL. Open a request like so and observe it for a few seconds.
```bash
$ curl -s localhost:3000/dequeueStream
retry: 1000

data: {}

data: {}

data: {}

data: {}
```



Notice that there is no data coming through (because there are no pending messages in the queue). Now open a separate cURL window and try posting a few messages:
```bash
$ curl -X POST localhost:3000/enqueue -H "Content-Type: application/json" -d '{"test": "stream", "message": 1}'
$ curl -X POST localhost:3000/enqueue -H "Content-Type: application/json" -d '{"test": "stream", "message": 2}'
```



Observe the stream and you'll notice the incoming messages!
```bash
data: {"test":"stream","message":1}

data: {}

data: {"test":"stream","message":2}

data: {}
```



## Summary 

In this post, we created an AQ queue and an Express application that produces and consumes messages from that queue. Stay tuned for future posts where we'll look at building upon this application to allow it to act as a "bridge" between AQ and other messaging protocols.

Image by [jplenio](https://pixabay.com/users/jplenio-7645255/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3082832) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3082832)
