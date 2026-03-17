---
title: "Publishing To Object Storage From Oracle Streaming Service"
slug: "publishing-to-object-storage-from-oracle-streaming-service"
author: "Todd Sharp"
date: 2019-12-23
summary: "In this post, we'll look at using the Kafka S3 Sink Connector to publish messages from an Oracle Streaming Service (OSS) topic directly to Oracle Object Storage."
tags: ["Cloud", "Containers, Microservices, APIs"]
keywords: "Cloud, Kafka, microservices, OBJECT STORAGE"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/banner_mathyas_kurmann_fb7ynpbt0l8_unsplash.jpg"
---

In my [last post about Oracle Streaming Service (OSS)](/posts/using-kafka-connect-with-oracle-streaming-service-and-autonomous-db) we looked at how to use the Kafka Connect compatibility feature of **OSS** to publish changes from an Autonomous DB instance directly to a stream. In this post, I want to show you something as equally awesome: how to write the contents of your stream directly to an Object Storage (**OS**) bucket. The process will look slightly similar to the process we used in the last post, but there are some notable changes. This time we're going to utilize the Kafka Connect S3 Sink Connector to achieve the desired results. Since Oracle Object Storage has a fully compatible S3 endpoint we can utilize this connector to easily get our stream data into our OCI bucket. The tutorial below will give you all the info you need to make things work, so let's get started.

# Preparing For The S3 Sink Connector

## User Setup

Before we get started, it would be a good idea to create a project directory somewhere on your machine to store some of the miscellaneous bits and bytes that we'll be working with. We'll refer to that directory as `/projects/object-storage-demo` from here on out - just make sure to substitute your own path as necessary.

You'll need a dedicated user with an auth token, a secret key and the proper policies in place. To do this, [follow the steps outlined in this post](/posts/migrate-your-kafka-workloads-to-oracle-cloud-streaming). Once you have your user created we'll enhance that user further as outlined below.

### Generate Secret Key

The streams user will need a "secret key" created. This will give you an "access key" and "secret key" that we'll use for the S3 compatible credentials that the Kafka S3 Sink Connector requires.  In the user details page for your user, click 'Customer Secret Keys' in the sidebar menu and then click 'Generate Secret Key':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/2019_12_20_13_19_16.png)

Name your key and click 'Generate Secret Key'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_aws_compatible_key.png)

Copy the generated key. This is your AWS compatible 'secret key' value. Save this for later use.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_aws_compatible_secret_key.png)

Click Close, then copy the 'Access Key' value. Save this as well.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_aws_compatible_access_key.png)

Before we move on, create a file at `/projects/object-storage-demo/aws_credentials` and populate it as such:
```text
[default]
aws_access_key_id=[generated access key]
aws_secret_access_key=[generated secret key]
```



### Modify Policy

Next, modify the policy that you created earlier for this user to make sure it has access to Object Storage. Add two policies like so:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_object_storage_policy_statements.png)

## Download Dependencies

We'll need to grab the S3 connector, so [download it from Confluent](https://www.confluent.io/hub/confluentinc/kafka-connect-s3) and unzip it so that it resides in your directory at `/projects/object-storage-demo/confluentinc-kafka-connect-s3-5.3.2`.

# Preparing Oracle Streaming Assets

We're going to need a Stream Pool, Stream and Connect Configuration. We'll create each of these below, so head over to the console burger menu and select 'Analytics' -\> 'Streaming'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_streaming_burger.png)

## Create Stream Pool And Stream

From the Streaming page, select 'Stream Pools' and click 'Create Stream Pool'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_stream_pools_sidebar_and_btn.png)

Name the Stream Pool and click 'Create Stream Pool'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_creat_stream_pool.png)

Once the Stream Pool is active, copy the Stream Pool OCID and keep it saved locally for later use. Next, click the 'View Kafka Connection Settings' button.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_stream_pool_connection_settings_btn.png)

Copy the value from bootstrap server. We'll need this later.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_connection_settings_dialog.png)

From the Stream Pool details page, click 'Create Stream'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_stream_pool_details_create_stream_btn.png)

Name the Stream and click 'Create Stream'. Keep the name handy for later use.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_create_stream_2.png)

## Create Connect Configuration

Now click on 'Kafka Connect Configurations' in the sidebar menu and 'Create Kafka Connect Configuration'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_connect_config_sidebar_and_btn.png)

Name the configuration and click 'Create Kafka Connect Configuration'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_connect_config_dialog.png)

From the Connect Config details page, copy the OCID of the Connect Config.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_connect_config_details.png)

# Preparing Object Storage

We'll need to create a bucket that will ultimately contain our messages. Head over to Object Storage via the burger menu.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_object_storage_burger_menu.png)

Click 'Create Bucket' and name your bucket and create it.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_create_bucket.png)

We're now ready to move on to configuring and launching Kafka Connect.

# Configuring And Launching Kafka Connect

We're now ready to launch Kafka Connect and create our S3 Sink Connector publish messages to Object Storage. We're going to use the [Debezium Connect Docker image](https://hub.docker.com/r/debezium/connect) to keep things simple and containerized, but you can certainly use the official Kafka Connect Docker image or the binary version. Before we can launch the Docker image, we'll need to set up a property file that will be used to configure Connect. We'll need some of the values that we collected earlier, so keep those handy. We'll also need our streaming username and our auth token.

Create a file called `/projects/object-storage-demo/connect-distributed.properties` and populate it as such, substituting your actual values wherever you see `<bracketed>` values.
```properties
bootstrap.servers=<bootstrap server from stream pool connection settings>
sasl.mechanism=PLAIN
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<tenancy>/<username>/<stream pool OCID>" password="<auth token>";

producer.sasl.mechanism=PLAIN
producer.security.protocol=SASL_SSL
producer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<tenancy>/<username>/<stream pool OCID>" password="<auth token>";

consumer.sasl.mechanism=PLAIN
consumer.security.protocol=SASL_SSL
consumer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<tenancy>/<username>/<stream pool OCID>" password="<auth token>";

database.history.producer.sasl.mechanism=PLAIN
database.history.producer.security.protocol=SASL_SSL
database.history.producer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<tenancy>/<username>/<stream pool OCID>" password="<auth token>";

database.history.consumer.sasl.mechanism=PLAIN
database.history.consumer.security.protocol=SASL_SSL
database.history.consumer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<tenancy>/<username>/<stream pool OCID>" password="<auth token>";

retries=1
max.in.flight.requests.per.connection=1

config.storage.replication.factor=1
status.storage.replication.factor=1
offset.storage.replication.factor=1

config.storage.partitions=1
status.storage.partitions=1
offset.storage.partitions=1

offset.flush.interval.ms=10000
offset.flush.timeout.ms=5000

key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter=org.apache.kafka.connect.json.JsonConverter
internal.value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false

task.shutdown.graceful.timeout.ms=10000
```



Set an environment variable in your shell for the connect configuration OCID we collected above: 
```bash
export CONFIG_ID=<connect config id>
```



Now run the Docker image with:
```bash
docker run -it --rm --name connect-demo -p 8083:8083 -e GROUP_ID=1 \                                                                                                                                                                                           
    -e BOOTSTRAP_SERVERS="cell-1.streaming.us-phoenix-1.oci.oraclecloud.com:9092" \
    -e CONFIG_STORAGE_TOPIC=$CONFIG_ID-config \
    -e OFFSET_STORAGE_TOPIC=$CONFIG_ID-offset \
    -e STATUS_STORAGE_TOPIC=$CONFIG_ID-status \
    -v $(pwd -L)/connect-distributed.properties:/kafka/config.orig/connect-distributed.properties \
    -v $(pwd -L)/confluentinc-kafka-connect-s3-5.3.2/:/kafka/connect/confluentinc-kafka-connect-s3-5.3.2 \
    -v $(pwd -L)/aws_credentials:/kafka/.aws/credentials \
    debezium/connect:latest
```



Once Kafka Connect is up and running we can create a JSON config file to describe our connector. Create a file at `/projects/object-storage-demo/connector-config.json` and populate as such:
```json
{
 "name": "oss-object-storage-demo",
 "config": {
  "name":"oss-object-storage-demo",
  "connector.class":"io.confluent.connect.s3.S3SinkConnector",
  "tasks.max":"1",
  "topics":"<your stream name>",
  "format.class":"io.confluent.connect.s3.format.json.JsonFormat",
  "storage.class":"io.confluent.connect.s3.storage.S3Storage",
  "flush.size":"1",
  "s3.bucket.name":"<your object storage bucket name>",
  "store.url":"https://<namespace (usually your tenancy name)>.compat.objectstorage.us-phoenix-1.oraclecloud.com",
  "s3.region":"us-phoenix-1"
 }
}
```



Update the `topic`, `s3.bucket.name` and `store.url` as appropriate (you may need to change the region in the URL and s3.region value). If you want more than a single message to end up in the generated file written to Object Storage, update `flush.size` as appropriate. Refer to the [S3 Sink documentation](https://docs.confluent.io/current/connect/kafka-connect-s3/index.html) for further customizations.

Now we can `POST` our config to the REST API to create the source connector:
```bash
curl -iX POST -H "Accept:application/json" -H "Content-Type:application/json" -d @connector-config.json http://localhost:8083/connectors
```



To list all connectors, perform a `GET` request:
```bash
curl -i http://localhost:8083/connectors
```



To delete a connector, perform a `DELETE` request:
```bash
curl -i -X DELETE http://localhost:8083/connectors/[connector-name]
```



# Testing The Integration

At this point we're ready to test things out. You can head over to the stream details page in the OCI console and click 'Produce Test Message' to post a few messages as JSON strings to the topic.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_test_message.png)

You'll notice some action in the Connect Docker console:
```bash
2019-12-20 17:49:58,664 INFO   ||  Starting commit and rotation for topic partition oss-demo-stream-0 with start offset {partition=0=0}   [io.confluent.connect.s3.TopicPartitionWriter]
2019-12-20 17:49:59,127 INFO   ||  Files committed to S3. Target commit offset for oss-demo-stream-0 is 1   [io.confluent.connect.s3.TopicPartitionWriter]
```



Head over to your bucket to see the files written:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/oss_os_bucket_objects.png)

Create a "Pre-Authenticated Request" to download the file and view its contents.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3f0a2482-e613-4708-91bd-57fa08099e74/2019_12_20_14_01_56.png)

# Summary

In this post we created and configured a Stream Pool, Stream and Connect Configuration and used those assets to publish messages from that stream to an Object Storage bucket as files.

Photo by [Mathyas Kurmann](https://unsplash.com/@mathyaskurmann?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/mailbox?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
