---
title: "Publishing And Analyzing Custom Application Metrics With The Oracle Cloud Monitoring Service"
slug: "publishing-and-analyzing-custom-application-metrics-with-the-oracle-cloud-monitoring-service"
author: "Todd Sharp"
date: 2020-04-03
summary: "Every application has data that needs to be tracked. In this post, we'll look at how easy it is to persist your custom metrics data with the Java SDK and then slice, dice and analyze that data directly within the Oracle Cloud console!"
tags: ["Cloud", "Containers, Microservices, APIs", "Database", "Java"]
keywords: "Data, Cloud, Java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/banner_isaac_smith_at77q0njnt0_unsplash.jpg"
---

A few weeks ago one of our awesome Product Managers on the database team came to me with an interesting request. He shared a blog post that someone had published that showed an example of using a different cloud provider's serverless offering to retrieve some usage data about an Oracle Database and publish that to the provider's metrics service on a regular basis. The PM asked me how it might be possible to accomplish the same thing in the Oracle Cloud. I was intrigued by the use case and thought it would give me a great opportunity to show off something I haven't talked much about here on the blog - custom metrics. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856557.png)

You might be familiar with Monitoring & Service Metrics (if not, [read all about them here](https://docs.cloud.oracle.com/en-us/iaas/Content/Monitoring/Concepts/monitoringoverview.htm)) which gives you the ability to explore usage statistics for existing services (compute, object storage, etc) and create alarm definitions and much more. This gives you great insight into the utilization and performance of the built-in services on the Oracle Cloud, but what you might not have known is that the Monitoring Service supports custom metrics which allows you to publish your own data to the metrics service that can then be sliced, diced and sautéed into the perfect recipe for your organization's needs.

## Plan Of Action

The article that inspired this little project and blog post suggested that the problem be addressed with a serverless function that is scheduled to run every minute. I know this may be controversial, but in my opinion, that's just not a good use case for serverless and could end up costing you more at the end of the month. If a serverless function never goes "cold" then I think you ought to look at another solution for your problem. For my approach, I decided it would be better to deploy a simple service to a VM in the cloud that will retrieve the DB utilization numbers with a JDBC query and publish the metric data on a scheduled basis every 60 seconds. The nice thing about this approach is that it's something that can potentially even be integrated into an existing service or deployed standalone - it's flexible like that.

## Let's Get Building

How about we walk through some of the code involved in this application to give you an idea of how you might integrate this approach into your existing applications.

**Heads Up!**  We're talking DB metrics here, but the data that you publish can be anything you need it to be with some minor modifications. Keep reading to learn how to publish custom metrics from your applications!

The approach below uses a Micronaut application, but you can certainly use your favorite framework to build this out. It doesn't even have to be a web application - you could simply have an executable JAR and schedule it to be called on a periodic basis with CRON! You could even use Python to write a simple script using the OCI Python SDK if you want - the possibilities are endless and there is an approach that will work for just about any environment you can imagine. 

## DB Metrics Service

The first step in my application is to get the DB metrics for load and storage. The PM that I was working with was kind enough to provide me with the necessary queries to retrieve this data so I created a `DBMetricsService` that would most of the heavy lifting in this application.  The PM gave me separate queries for load & storage data so I created two separate service methods (the full source for this blog post is available on GitHub - see link at the bottom of this post). Here are the two queries I used to gather the data.

### DB Load
```sql
/* DB Load */

WITH rdb_load AS (
    SELECT
        inst_id,
        executions,
        usercalls,
        parses,
        commits,
        rollbacks,
        logons,
        totalphysicalreads,
        totalphysicalwrites,
        phyreadtotalioreqs,
        phywritetotalioreqs
    FROM
        TABLE ( gv$(CURSOR(
            SELECT
                to_number(userenv('INSTANCE')) AS inst_id, SUM(decode(name, 'execute count', value, 0)) executions, SUM(decode(name
                , 'user calls', value, 0)) usercalls, SUM(decode(name, 'parse count (total)', value, 0)) parses, SUM(decode(name,
                'user commits', value, 0)) commits, SUM(decode(name, 'user rollbacks', value, 0)) rollbacks, SUM(decode(name, 'logons cumulative'
                , value, 0)) logons, SUM(decode(name, 'physical read total bytes', value, 0)) totalphysicalreads, SUM(decode(name
                , 'physical write total bytes', value, 0)) totalphysicalwrites, SUM(decode(name, 'physical read total IO requests'
                , value, 0)) phyreadtotalioreqs, SUM(decode(name, 'physical write total IO requests', value, 0)) phywritetotalioreqs
            FROM
                v$sysstat
            WHERE
                con_id = 0
            GROUP BY
                to_number(userenv('INSTANCE'))
        )) )
), rdb_time AS (
    SELECT
        inst_id,
        dbcpu,
        dbtime
    FROM
        TABLE ( gv$(CURSOR(
            SELECT
                to_number(userenv('INSTANCE')) AS inst_id, SUM(decode(stat_name, 'DB CPU', value / 10000, 0)) dbcpu, SUM(decode(stat_name
                , 'DB time', value / 1000000, 0)) dbtime
            FROM
                v$sys_time_model
            WHERE
                con_id = 0
            GROUP BY
                to_number(userenv('INSTANCE'))
        )) )
), user_io AS (
    SELECT
        inst_id,
        useriotime
    FROM
        TABLE ( gv$(CURSOR(
            SELECT
                to_number(userenv('INSTANCE')) AS inst_id, time_waited_fg / 100 AS useriotime
            FROM
                v$system_wait_class
            WHERE
                wait_class = 'User I/O'
                AND con_id = 0
        )) )
)
SELECT
    sum(rdb_load.executions) as executions,
    sum(rdb_load.usercalls) as usercalls,
    sum(rdb_load.parses) as parses,
    sum(rdb_load.commits) as commits,
    sum(rdb_load.rollbacks) as rollbacks,
    sum(rdb_load.logons) as logons,
    sum(rdb_load.totalphysicalreads) as totalphysicalreads,
    sum(rdb_load.totalphysicalwrites) as totalphysicalwrites,
    sum(rdb_load.phyreadtotalioreqs) as phyreadtotalioreqs,
    sum(rdb_load.phywritetotalioreqs) as phywritetotalioreqs,
    sum(rdb_time.dbcpu) as dbcpu,
    sum(rdb_time.dbtime) as dbtime,
    sum(user_io.useriotime) as useriotime
FROM
    rdb_load,
    rdb_time,
    user_io
WHERE
    rdb_load.inst_id = rdb_time.inst_id
    AND rdb_time.inst_id = user_io.inst_id
          
/* DB Storage */
          
WITH tbsp_stats AS (
    SELECT
        SUM(tablespace_space) AS total_tablespace_space,
        SUM(space_used) AS total_space_used
    FROM
        (
            SELECT
                m.tablespace_name,
                t.contents,
                MAX(round((m.tablespace_size) * t.block_size / 1024 / 1024 / 1024, 9)) tablespace_space,
                MAX(round((m.used_space) * t.block_size / 1024 / 1024 / 1024, 9)) space_used,
                MAX(round(m.used_percent, 2)) used_pct
            FROM
                cdb_tablespace_usage_metrics   m,
                cdb_tablespaces                t
            WHERE
                t.tablespace_name = m.tablespace_name
            GROUP BY
                m.tablespace_name,
                t.contents
        )
)
SELECT
    tbsp_stats.total_tablespace_space,
    tbsp_stats.total_space_used,
    tbsp_stats.total_space_used / tbsp_stats.total_tablespace_space AS total_used_pct
FROM
    tbsp_stats
```



I plugged those queries into my `DBMetricsService` and created a simple bean to store the results for each query. I wrapped these in individual service methods named `getDBLoad()` and `getDBStorage()`respectively. 

Here are the bean definitions to give you an idea of what I'm collecting
```java
public class DBLoad {
    private BigDecimal executions;
    private BigDecimal userCalls;
    private BigDecimal parses;
    private BigDecimal commits;
    private BigDecimal rollbacks;
    private BigDecimal logons;
    private BigDecimal totalPhysicalReads;
    private BigDecimal totalPhysicalWrites;
    private BigDecimal phyReadTotalIOReqs;
    private BigDecimal phyWriteTotalIOReqs;
    private BigDecimal dbCpu;
    private BigDecimal dbTime;
    private BigDecimal userIOTime;
}
```
```java
public class DBStorage {
    private BigDecimal totalTablespaceSpace;
    private BigDecimal totalSpaceUsed;
    private BigDecimal totalUsedPct;
}
```



### Publishing The Metrics

Now that I had a way to pull the data that I wanted to publish to the metrics service, it's just a matter of utilizing the OCI SDK to publish the metric data. Obviously this meant I needed to include the OCI Java SDK dependency:
```bash
compile 'com.oracle.oci.sdk:oci-java-sdk-full:1.15.2'
```



#### Preparing To Use The SDK

We're going to take advantage of a really cool feature of the Oracle Cloud to authenticate with the SDK and use an Instance Principal provider. Per the docs:

> The IAM service feature that enables instances to be authorized actors (or principals) to perform actions on service resources. Each compute instance has its own identity, and it authenticates using the certificates that are added to it. These certificates are automatically created, assigned to instances and rotated, preventing the need for you to distribute credentials to your hosts and rotate them.

To use instance principals, we need to first create a dynamic group. I call mine "instance-principals" and my rule applies to all instances in a given compartment.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856576.png)

Now it's a matter of applying the proper policy statements to give the dynamic group permissions.
```bash
allow dynamic-group instance-principals to use metrics in tenancy
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856601.png)

#### Publishing Metrics

In the DBMetricsService constructor, we need to create our MonitoringClient. We'll use the instance principal when running in the Oracle Cloud, otherwise, we'll use a local config file. 

Note: The `MonitoringClient` uses a different endpoint for `POST` operations than most other operations, so we need to specify the proper endpoint when constructing our client (or use the `setEndpoint()`method later on the client). The proper [monitoring endpoints per region and operation are listed here](http://docs.cloud.oracle.com/en-us/iaas/api/#/en/monitoring/20180401/).
```java
BasicAuthenticationDetailsProvider provider;
if( config.getUseInstancePrincipal() ) {
    provider = InstancePrincipalsAuthenticationDetailsProvider.builder().build();
}
else {
    provider = new ConfigFileAuthenticationDetailsProvider(config.getOciConfigPath(), config.getOciProfile());
}
monitoringClient = MonitoringClient.builder()
        .endpoint("https://telemetry-ingestion.us-phoenix-1.oraclecloud.com")
        .build(provider);
```



We need a few variables to publish our metrics. Specifically, we need: 

- The compartment OCID of the compartment in which you'd like to store your metric data

- A namespace name (whatever you'd like - used to group your metrics)

- A unique identifier to your metric data (I used my DB OCID)

- A resource group (whatever you'd like - another sub-level grouping for your metrics)

I stored many of these values in my config bean in my Micronaut app.

Once we have collected that info, we're finally ready to publish metrics!  In my `publishMetrics()`method of the `DBMetricsService`I grab the data and create a list to hold the `MetricDataDetails`:
```java
DBLoad dbLoad = getDBLoad();
DBStorage dbStorage = getDBStorage();
List<MetricDataDetails> metricDataDetailsList = new ArrayList<>();
```



Next, we'll use Micronaut's Bean Introspection to loop over the properties in my beans, construct the data points and metrics data details objects and add each details object to the list of details to be published. We'll do this for both beans, but I'll just show you one since they're almost identical:
```java
for (String loadPropertyName : dbLoadBeanIntrospection.getPropertyNames()) {
    BeanProperty<DBLoad, BigDecimal> loadProp = dbLoadBeanIntrospection.getRequiredProperty(loadPropertyName, BigDecimal.class);
    BigDecimal currentValue = loadProp.get(dbLoad);
    Datapoint loadDp = Datapoint.builder()
            .value(currentValue != null ? currentValue.doubleValue() : 0)
            .timestamp(new Date())
            .build();
    MetricDataDetails loadMetricDataDetails = MetricDataDetails.builder()
            .compartmentId(config.getMetricsCompartmentOcid())
            .namespace(config.getMetricsNamespace())
            .dimensions(Map.of(
                    "dbId", config.getDbOcid()
            ))
            .resourceGroup("db-load")
            .name(loadPropertyName)
            .datapoints(List.of(loadDp))
            .build();
    metricDataDetailsList.add(loadMetricDataDetails);
}
```



Next, we built a `PostMetricDataDetails` object, add the list of details and use the `MonitoringClient` to post the metrics data request.
```java
PostMetricDataDetails postMetricDataDetails = PostMetricDataDetails.builder().metricData(metricDataDetailsList).build();
PostMetricDataRequest postMetricDataRequest = PostMetricDataRequest.builder()
        .postMetricDataDetails(postMetricDataDetails)
        .build();
monitoringClient.postMetricData(postMetricDataRequest);
```



At this point, we can invoke the service method directly to publish our metrics. I added a controller method to test the publishing:
```java
@Get("/test-publish")
public HttpResponse testPublish() throws SQLException {
    dbMetricsService.publishMetrics();
    return HttpResponse.ok();
}
```



But it would make more sense to schedule the invocation so that we can ensure a regular stream of metric data is published on a regular basis. To do this, I created a job in Micronaut and used the `@Scheduled` annotation to invoke the service every 60 seconds.
```java
@Singleton
public class MetricsPublisherJob {
    private static final Logger LOG = LoggerFactory.getLogger(MetricsPublisherJob.class);
    private final DBMetricsService dbMetricsService;
    public MetricsPublisherJob(DBMetricsService dbMetricsService) {
        this.dbMetricsService = dbMetricsService;
    }
    @Scheduled(fixedDelay = "60s")
    void publishMetricsEverySixtySeconds() throws SQLException {
        LOG.info("Publishing metrics...");
        dbMetricsService.publishMetrics();
        LOG.info("Metrics published!");
    }
}
```



## View Our Published Metrics

After deploying and running the application for a bit of time, we can view our metric data in the Oracle Cloud console by going to Monitoring -\> Metrics Explorer in the burger menu.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856607.png)

In the Metrics Explorer, you can play around with constructing your queries to explore your custom metrics as necessary. Here I've created a view to plot out physical reads vs physical writes:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856616.png)

We can also create an Alarm Definition based on these custom metrics. Here's an example of creating an alarm to send us an email when the mean CPU of the instance is greater than 85% for 5 minutes.

Name the alarm, provide a body and severity.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856620.png)

Choose the compartment, namespace, resource group, metric name, interval and statistic.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856626.png)

Apply the alarm rule conditions.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856631.png)

And the destination to publish our alarm when it is breached.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d25c677d-e694-4cb8-a676-a9ed3a0be3a5/upload_1585750856637.png)

## Summary 

In this post, we looked at how to publish and explore custom metrics data from your applications in the Oracle Cloud. 

## Further Reference

- <https://docs.cloud.oracle.com/en-us/iaas/api/#/en/monitoring/20180401/MetricData/PostMetricData>
- <https://docs.cloud.oracle.com/en-us/iaas/tools/java/1.15/>
- <https://docs.cloud.oracle.com/en-us/iaas/tools/java/1.15/com/oracle/bmc/monitoring/MonitoringClient.html>
- <https://docs.cloud.oracle.com/en-us/iaas/tools/java/1.15/com/oracle/bmc/monitoring/model/PostMetricDataDetails.html>

The full source [code for this example is available on GitHub](http://github.com/recursivecodes/oci-custom-metrics).

Photo by [Isaac Smith](https://unsplash.com/@isaacmsmith?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/chart?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
