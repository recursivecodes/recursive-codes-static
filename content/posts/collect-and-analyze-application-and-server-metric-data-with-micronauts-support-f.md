---
title: "Collect and Analyze Application and Server Metric Data with Micronaut's Support for OCI Monitoring"
slug: "collect-and-analyze-application-and-server-metric-data-with-micronauts-support-for-oci-monitoring"
author: "Todd Sharp"
date: 2021-03-30
summary: "In this post, we'll look at how you can report and analyze application and server metrics from your Micronaut application directly into OCI Monitoring."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2f1e4e35-9395-42cc-b108-623696a96b42/banner_miguel_a_amutio_lbkye0xlu3e_unsplash.jpg"
---

The Micronaut team over in Oracle Labs have been hard at work on a number of impressive features and framework improvements and they're moving so fast that I can hardly keep up with all the awesomeness. A few weeks ago an update was released on the Micronaut module for Oracle Cloud and I blogged about the [automatic wallet download and configuration for Autonomous DB connections](/posts/automatic-autonomous-wallet-download-configuration-with-micronaut) from Micronaut, but there was another feature in that release that I didn't have a chance to blog about at the time: support for [Micrometer Support for OCI Monitoring](https://micronaut-projects.github.io/micronaut-oracle-cloud/latest/guide/#micrometer). This powerful feature uses [Micronaut's support for Micrometer](https://micronaut-projects.github.io/micronaut-micrometer/latest/guide) to let your applications report an abundance of valuable server and application insight directly into OCI monitoring where it can be sliced and diced as your team sees fit. You can even create alarms and send notifications based on the metrics collected. Best of all - it's really simple to use and requires nothing but a bit of configuration in your application. Let me show you how!

## Configuring Your App

As I stated just a second ago, it's really just a matter of configuring your application to collect and report these metrics to OCI monitoring. If you are creating a new app from scratch, make sure to add the `oracle-cloud-sdk` feature.
```bash
$ mn create-app --build=gradle --jdk=11 --lang=java --test=junit --features=oracle-cloud-sdk codes.recursive.oci-monitoring
```



Next, as with any feature in the OCI Module, you must configure an [auth provider](https://micronaut-projects.github.io/micronaut-oracle-cloud/latest/guide/#authentication). On my `localhost`, I just use a config file provider.
```yaml
oci:
  config:
    profile: DEFAULT
```



Of course, when I deploy to OCI I usually use an instance principal, so my configuration for that looks like so:
```yaml
oci: 
  config: 
    instance-principal:
      enabled: true
```



**Note:** Naming the configuration file with the special suffix `-oraclecloud` will ensure that this config file gets automatically picked up and used when deployed to OCI thanks to Micronaut's automatic environment detection feature.

Next, add dependencies for `micronaut-oraclecloud-micrometer`, the OCI Monitoring SDK and the standard Micronaut Micrometer dependencies
```groovy
implementation "com.oracle.oci.sdk:oci-java-sdk-monitoring”
compile "io.micronaut.micrometer:micronaut-micrometer-core"
compile "io.micronaut.micrometer:micronaut-micrometer-registry-statsd"
compile "io.micronaut:micronaut-management”
runtime("io.micronaut.oraclecloud:micronaut-oraclecloud-micrometer”)
```



Now we just modify `src/main/resources/application.yml` to configure Micrometer. The `namespace` and `resourceGroup` will be how you find your metrics in the OCI console later on. 
```yaml
micronaut:
  application:
    name: ociMonitoring
  metrics:
    enabled: true
    export:
      oraclecloud:
        enabled: true
        namespace: mn_oci_metrics_demo
        resourceGroup: demo_resource_group
        compartmentId: ${OCI_DEMO_COMPARTMENT}
```



When the application is launched, it will now start reporting metrics to OCI monitoring!

## View Metrics

By default, your application and server metrics are reported every 60 seconds (this is configurable). After the application has been running a short while, you can now check the Metrics Explorer in the OCI console to view the data.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2f1e4e35-9395-42cc-b108-623696a96b42/file_1617030087153.png)

Choose the metric namespace (#1) and resource group (#2) that you entered in your config and then select the metric (#3), interval (#4), and statistic (#5).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2f1e4e35-9395-42cc-b108-623696a96b42/file_1617030056051.png)

For example, a simple look at incoming HTTP requests.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2f1e4e35-9395-42cc-b108-623696a96b42/file_1617030056060.png)

Or memory used:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2f1e4e35-9395-42cc-b108-623696a96b42/file_1617030056064.png)

Or CPU usage:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2f1e4e35-9395-42cc-b108-623696a96b42/file_1617030056070.png)

There are a surprisingly high amount of metrics that are reported. Everything from JVM stats, to system metrics like process uptime and system load. You can also enable metrics for Hibernate, JDBC connection pools, or even [create your own custom metrics](https://micronaut-projects.github.io/micronaut-micrometer/latest/guide/#_adding_custom_metrics). See [docs](https://micronaut-projects.github.io/micronaut-micrometer/latest/guide/#metricsConcepts) for more info.

## Summary

In this post, we looked at how to configure your Micronaut application to report application and server metrics to the OCI monitoring service. We also looked at how to view the collected data in the OCI console. 

Photo by [Miguel A. Amutio](https://unsplash.com/@amutiomi?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/collections/3497526/metrics-and-meauserments?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

