---
title: "Interacting With Your Oracle On-Prem and Autonomous DB Instances From Node-RED"
slug: "interacting-with-your-oracle-on-prem-and-autonomous-db-instances-from-node-red"
author: "Todd Sharp"
date: 2021-03-10
summary: "In this post, we'll look at connecting up to your on-prem and Autonmous DB instances in the cloud from Node-RED via a few different approaches."
tags: ["Cloud", "Developers"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/banner_elti_meshau_2s2f2exmbhw_unsplash.jpg"
---

Node-RED is a programming tool that allows you to wire together devices and APIs to help you automate, monitor and analyze data without having to write much code at all. I've used it for various projects in the past, and it's always fun to discover new ways to integrate it into my tinkering - especially IoT projects. Recently, I wanted to persist some sensor data that I was publishing to an MQTT topic into my Autonomous DB instance in the Oracle Cloud, so I created a new "flow" in Node-RED and tested out a few different approaches. In this post, we'll look at each approach to give you a few different options the next time you are looking to connect to Oracle DB from Node-RED.

**Free Stuff!** If you are new to Oracle Cloud, you should know that everything we're about to discuss is able to run on "always free" resources in the Oracle Cloud. That's right, completely free - forever!  If you'd like to learn more, please check out the following blog posts:  [Installing Node-RED In An Always Free VM On Oracle Cloud](/posts/installing-node-red-in-an-always-free-vm-on-oracle-cloud) & [Launching Your First Free Autonomous DB Instance](/posts/launching-your-first-free-autonomous-db-instance)

## Persisting Data from Node-RED via Oracle REST Data Services

My first thought for persisting my IoT sensor data in my recent project was to utilize Oracle REST Data Services (ORDS). I've talked about ORDS before, but as a reminder it's a handy way to expose a set of REST endpoints to persist and retrieve data from a table in your schema via familiar HTTP calls (GET, POST, PUT, etc). I won't go into details about how to enable ORDS in this post (here's [another blog post that covers that topic](/posts/microservices-the-easy-way-with-ords-and-micronaut-part-1)), but I'll assume that you've created a table and enabled ORDS on it already. Once that's done, there are two steps to persistence. First, we'll need to establish an OAuth token to be used for authenticating our subsequent calls. Second, we make the calls themselves passing along our OAuth token. 

First, drag an `inject` node onto your flow.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069059.png)

Double click the inject node and set it to run immediately and then once every 60 minutes.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069069.png)

Next, drag a function node onto the flow. We'll use this node to format the request.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069078.png)

Use the function node to modify the `msg` object to include the `Content-Type` header and set the payload as shown below.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069083.png)

Now, add an `http-request` node to the flow.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069091.png)

Edit the request node to make a `POST` request to your `/oauth/token` endpoint using basic authentication and passing your client id and client secret as the username/password.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874143031.png)

Now add a debug node and a change node after the http request.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069108.png)

For the change node, we're going to set the returned token into the 'flow' scope so that it can be used from other parts of our flow.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069111.png)

Deploy the flow and observe the OAuth token request in the debug console.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069116.png)

Confirm that the flow variable was set in the 'context' panel.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069119.png)

Now we can add another portion of our flow to listen for incoming messages on an MQTT topic, format the message for ORDS and persist via ORDS.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069123.png)

The MQTT node:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069126.png)

Formatting the HTTP request object (note that the `reading` column in my table is a JSON column, so I can store the JSON object directly for flexibility). Also note that I'm passing the token that we stored in the flow as my auth header.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069129.png)

The request:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069133.png)

Once deployed, we can observe that each time a message is received on the MQTT topic it is persisted to my instance via HTTP request with ORDS!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069140.png)

## Persisting Data from Node-RED via the Oracle DB Custom Node

ORDS is awesome, but, it would be **really awesome** if we could natively connect to our instance from Node-RED. Luckily, there's a way to do just that via the `node-red-contrib-oracledb-mod` custom node (available [here](https://flows.nodered.org/node/node-red-contrib-oracledb-mod)). To use this node, you must install it on your Node-RED server and you must have the [Oracle Instant Client installed and configured](https://github.com/oracle/node-oracledb/blob/master/INSTALL.md#instructions) as well. Once the installations are complete, there are two different ways to connect to your DB - a "classic" connection using a URL, username and password as well as connecting with a TNS Name from a `tnsnames.ora` file (like those found in the Autonomous DB wallet). If you'd like to use a TNS name connection (and you must for Autonomous DB), download your wallet and place it in the `/network/admin` subdirectory of the directory where you installed the Instant Client.

### "Classic" Connections

Let's first look at connecting up to an Oracle DB instance in the "classic" style. Drag an inject node, an Oracle DB node and a debug node to your flow and connect them like so.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069143.png)

Double click the Oracle Node to edit. You'll first have to set up a server, so click the 'pencil' icon.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069147.png)

To configure your server, enter a name for your connection (#1), choose "classic" as the connection type (#2), enter the path to the directory where you installed the Instant Client (#3), enter your server IP/host (#4), port (#5) and DB name (#6). Then click on the Security tab (#7).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069152.png)

Enter your credentials in the security tab.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069155.png)

Once you've configured the server connection, head back to the Oracle node and enter the query that you'd like to run.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069158.png)

Click 'Done' and deploy your flow. Test it out by clicking on the inject node. Notice that results are returned in batches of no more than 100 records.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069203.gif)

### Connecting With a TNS Name From a `tnsnames.ora` File 

To connect your Autonomous DB instance, make sure your wallet is unzipped in the `/network/admin` subdirectory of the directory that you installed the Instant Client in. Also make sure you update the `sqlnet.ora` file with the updated path. Then create a new connection, this time a 'TNS Name' type connection and enter the TNS name that you'd like to use.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069208.png)

Enter your query as before, deploy, and invoke.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069213.png)

Note the debug results.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3717402b-dca3-4505-b009-bb53c3d6295f/file_1614874069216.png)

## Summary

In this post, we covered several approaches to interacting with your Oracle DB (both on-prem and in the cloud) from Node-RED. If you have any questions or feedback, please let me know by adding a comment below. Happy building and coding!

Photo by [Elti Meshau](https://unsplash.com/@eltimeshau?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/red?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

