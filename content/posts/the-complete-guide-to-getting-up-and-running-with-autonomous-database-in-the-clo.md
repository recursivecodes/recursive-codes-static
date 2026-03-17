---
title: "The Complete Guide To Getting Up And Running With Autonomous Database In The Cloud"
slug: "the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud"
author: "Todd Sharp"
date: 2019-07-02
summary: "In this post we'll look at getting an ATP instance up and running that can be used for microservice data persistence and retrieval."
tags: ["Cloud", "Containers, Microservices, APIs", "Database", "Developers"]
keywords: "AUTONOMOUS, Database, microservices"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/banner_2019_06_28_11_35_13.jpg"
---

In our last post, we [configured Kubernetes and Docker to get ready to deploy microservices](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud). In this post, we'll look at another critical piece of the microservices puzzle - the place where our data will be stored. In this series we will focus on using Autonomous Database, specifically Autonomous Transaction Processing to persist and retrieve data to and from our microservices. That might lead you to believe that we're limiting ourselves to traditional 'table' based data, but as you'll see later on there are several options available for more non-traditional storage with ATP. Let's get started with our ATP instance creation. Like the last post, I'll show you how to do things with both the dashboard UI as well as the OCI CLI.

## Creating An Autonomous Database Instance

We'll use an Autonomous Database for our microservices, so we'll need to create an Autonomous Transaction Processing (ATP) instance.

### Creating An ATP Instance Via Dashboard

To create an ATP instance, select 'Autonomous Transaction Processing' from the sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_11_26_43.jpg)

Click on 'Create Autonomous Database', then populate the compartment, display name and database name. Make sure that 'Transaction Processing' is selected.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_11_28_39.jpg)

Make sure that 'serverless' is selected (note, this really just means "managed" as opposed to dedicated and has nothing to do with traditional "serverless") and enter the desired CPU and Storage (the defaults are good for now). If you want the CPU to auto scale then choose 'auto scaling'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_11_29_15.jpg)

Finally, enter an administrator password and make a license choice and click on 'Create Autonomous Database':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_11_29_49.jpg)

When the database instance has been created, go to the instance details page and click on 'DB Connection':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_11_35_13.jpg)

In the DB connection dialog, click on 'Download' to download your ATP wallet. This contains the necessary client credentials to connect to the instance from our running application later on. Store it in a safe place.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_11_36_31.jpg)

### Creating An ATP Instance Via The CLI

To create an ATP instance via the CLI, run:
```bash
oci db autonomous-database create \                                                      
--compartment-id [COMPARTMENT OCID] \
--db-name cloudatp \
--cpu-core-count 1 \
--data-storage-size-in-tbs 1 \
--admin-password StrongPassw0rd \
--db-workload OLTP \
--display-name "Cloud ATP" \
--license-model LICENSE_INCLUDED \
--is-auto-scaling-enabled true \
--is-dedicated false
```



Which returns a result like so:
```json
{
 "data": {
  "additional-database-status": null,
  "autonomous-container-database-id": null,
  "compartment-id": "ocid1.compartment.oc1....",
  "connection-strings": null,
  "cpu-core-count": 1,
  "data-storage-size-in-tbs": 1,
  "db-name": "cloudatp",
  "db-version": null,
  "db-workload": "OLTP",
  "defined-tags": {},
  "display-name": "Cloud ATP",
  "freeform-tags": {},
  "id": "ocid1.autonomousdatabase.oc1.phx...",
  "is-auto-scaling-enabled": true,
  "is-dedicated": false,
  "license-model": "LICENSE_INCLUDED",
  "lifecycle-details": null,
  "lifecycle-state": "PROVISIONING",
  "service-console-url": null,
  "time-created": "2019-06-28T15:45:21.180000+00:00",
  "used-data-storage-size-in-tbs": null,
  "whitelisted-ips": [
   "0.0.0.0/0"
  ]
 },
 "etag": "4f58d742"
}
```



After a few minutes, check the status of the install with the following command. Pass the ID that was returned from the create statement as the -`-autonomous-database-id` attribute:
```bash
oci db autonomous-database get --autonomous-database-id [DB OCID]
```



In the JSON returned from the `get` statement, check for the key `lifecycle-state` and make sure its value is "AVAILABLE" before moving on. Once the ATP instance is available, download the wallet with:
```bash
oci db autonomous-data-warehouse generate-wallet --autonomous-data-warehouse-id [ATP OCID] --password WalletPassw0rd --file ./wallet.zip
```



### Bonus: SQL Developer Web

To quickly run queries on your new ATP instance you can use the SQL Developer Web tool. To access, click on the instance details and click 'Service Console':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_12_09_31.jpg)

On the Service Console page, select 'Administration' in the left sidebar and scroll down and click 'SQL Developer Web':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_12_12_55.jpg)

Enter the admin username and the password that you supplied for the admin user when the instance was created and click 'Sign In':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_12_14_28.jpg)

After logging in, you can select a schema to work within (#1), choose an object to inspect (#2), enter a query to run (#3) and view results (#4) among other things. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b658e045-854f-4b3b-a0e9-a17127894b7e/2019_06_28_12_15_32.jpg)

This is a very nice way to run quick queries that we'll take advantage of throughout this blog series.
