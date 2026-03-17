---
title: "Cloud Cost Cutting: Autoscaling Your Dev/QA Environments"
slug: "cloud-cost-cutting:-autoscaling-your-devqa-environments"
author: "Todd Sharp"
date: 2020-06-23
summary: "In this post, we'll look at scaling your VMs and DB instances on the Oracle Cloud."
tags: ["Cloud"]
keywords: "Cloud, Scale Up"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/banner_jason_dent_xytkiywkmeo_unsplash.jpg"
---

I've worked on many software projects over the last 16 years, and one thing that each of those projects had in common was the existence of an environment used exclusively for demos or testing. You can call it whatever you like: dev, demo, test, QA (you might even have more than one) but the fact is that you likely have environments in the cloud that exist outside of production for testing or demo purposes. This makes sense, but paying for them to be up and running outside of the hours that you need them up and running does not. In this post, I want to show you several options for scaling your environments with tools available in the Oracle Cloud as well as one option that is a bit more flexible and works outside of the Oracle Cloud. 

Before we dig in, you may be asking yourself why this post and why now?  Those are both valid questions, so let me answer them quickly.

## Why Autoscale?

You're no doubt familiar with the concept of autoscaling, and it's certainly not new on the Oracle Cloud. Your workloads (both VM and DB) can easily scale based on metrics/demand. We're not going to look at metrics based autoscaling today, rather we're going to look at schedule-based autoscaling since this is a brand new service enhancement that was just recently released. You might have seen [the blog post announcing it](https://blogs.oracle.com/cloud-infrastructure/announcing-general-availability-of-compute-autoscaling-v2) recently or even caught it on Twitter (like [my buddy Guillermo's feed](https://twitter.com/IaaSgeek/status/1274055690181578753?cxt=HHwWgsC01cy5ra4jAAAA), which you should totally follow if you don't already). The [official docs are super helpful](https://docs.cloud.oracle.com/en-us/iaas/Content/Compute/Tasks/autoscalinginstancepools.htm#time) and you should read up on them later on, but I'll show you everything you need to get started today in this post.

## Why Now?

Well, why not?  But truthfully, the reason I was motivated to dig into this topic and write this blog post was the other recent announcement: [per-second billing for compute and autonomous DB](https://blogs.oracle.com/cloud-infrastructure/announcing-per-second-billing-for-compute-and-autonomous-database). Like I said earlier, why pay to run a QA server when no one is working on it?  Will there be exceptions? Sure, absolutely. And you can deal with those as needed, but generally, you will likely have a set schedule that you need your QA instances up and running, and paying for them to run outside that window is spending money that could likely be used on better things for your project or team. 

**Are you crazy? **Possibly, but I don't see what that has to do with this blog post. Look, I'm a developer advocate - which means I advocate for developers. And helping them save money is one of the ways I can do that. 

## Schedule Based Autoscaling

Let's get to it. Say you have an instance that runs your shiny microservice. Doesn't matter what it is, but you want it to be available between 8 AM and 5 PM Eastern Time. This service runs on a compute VM in the Oracle Cloud. Let's look at how to set up a schedule based autoscale for our hypothetical VM based service. Here's an outline of the steps we'll need to take:

1.  Create a VM and configure microservice
2.  Create a custom image from the configured VM
3.  Create an instance based on the custom image
4.  Create an instance configuration from the VM running the custom image
5.  Create an instance pool based on the instance configuration
6.  Create an autoscaling configuration based on the instance pool

I know that sounds like a lot of steps, but I promise it won't take long to complete the process. There is plenty written on this blog about steps one and two, so we'll start with step 3 to keep things brief.

### Create An Instance Based On The Custom Image

If you're new to creating custom images, here's a quick primer:

Remember that custom images are essentially a deep copy of the instance that was used to create it. Any software that was installed on the original VM will be installed on the instance created from the custom image. That includes our microservice. So, assuming that we created a custom image called "demo-qa-env-custom-image" from our demo-qa-env VM, create a new VM based on that image.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921335825.png)

### Create An Instance Configuration From The VM Running The Custom Image

When the new VM is created (confirm the source custom image as shown in #1 below), click 'More Actions' and select 'Create Instance Configuration' (#2).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921433724.png)

Name your Instance Configuration and click 'Create'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921631680.png)

### Create An Instance Pool Based On The Instance Configuration

From the Instance Configuration details page, click 'Create Instance Pool'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921675140.png)

Populate the Instance Pool details. For our use case, the 'Number of Instances' will be set to zero since we plan to use our scheduled Autoscale Configuration to manage the pool size.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921773843.png)

Select the proper AD, compartment, VCN, and subnet and then click 'Create Instance Pool'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921812442.png)

### Create An Autoscaling Configuration Based On The Instance Pool

From the Instance Pool details page, select 'More Actions' and then click 'Create Autoscaling Configuration'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921904016.png)

Creating the Autoscaling Config is done with a simple wizard. In step 1, choose the compartment, name it and select the proper instance pool (it should be pre-selected if you came from the instance pool details page).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592921981263.png)

In step 2, select 'Schedule-based Autoscaling'. Now we'll create two Autoscaling policies. The first will be run at 7:45 AM ET and will scale the pool up to a single instance. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592922066982.png)

**Note:** The policy form expects times to be specified in UTC!

Now create another policy to scale down to zero every night at 5:15 PM ET. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592922188546.png)

Click 'Create Autoscaling Configuration' and you're all set. 

### The Next Day\...

If you were to check your instance pool the following morning and view the 'Work Requests', you'll see that our Autoscaling Configuration initiated a Work Request at 11:45 AM UTC as expected.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592922443164.png)

I added an endpoint to my microservice to cache a timestamp when the application server started up, and if I hit my newly turned up QA instance in the browser I can see that the service started up just a few minutes after the VM work request was initiated.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592922579165.png)

## We Have A Few Issues\...

Schedule based autoscaling is powerful and gives you a way to accommodate anticipated peak demand. And using schedule-based autoscaling in our scenario does work. It solves the problem of preventing unnecessary billed hours, but now we have a new problem. Each time a new VM is created (every morning) we'll get a new public IP. We could solve that by throwing our instance pool behind a load balancer, but that may be overkill for a simple QA environment.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592922668688.png)

The other issue at this point is that we still haven't addressed the Autonomous DB instance behind our microservice. After all, if our application isn't running then why should the DB behind it be running and incurring costs? 

Let's look at another way to solve this problem that might fit into your current CI/CD workflow and solves the issue of getting a new public IP every morning. The outline for this process looks like this:

1.  Create a VM and configure microservice
2.  Create CI/CD workflows to start and stop the VMs and DB instance

Much fewer steps involved here, and this solution is pretty flexible. Again we'll assume that step 1 has already been completed and start with step 2.

### Create CI/CD Workflows To Start And Stop VM And DB Instances

We'll use GitHub Actions, but you could easily modify this to work with whatever tool you use. We'll create two workflows in our `.github/workflows` directory: `start-qa-workflow.yaml` and `stop-qa-workflow.yaml`. The start workflow begins with the workflow name and an "on" section where we specify the workflow trigger - in this case, a schedule.
```yaml
name: start-qa
on:
  schedule:
    - cron:  '45 11 * * 1-5'
```



Our start job, like the one we created in our Autoscaling Configuration, will run at 11:45 AM UTC on Monday-Friday. Next, create an environment variable to hold our VM instance name and define our job:
```yaml
env:
  INSTANCE_NAME: demo-qa-env
jobs:
  start-qa-job:
    name: 'Start QA Job'
    runs-on: ubuntu-latest

    steps:
```



The first this we need to do is install the OCI CLI in our GitHub runner VM. I've set the necessary CLI config values into my repo's secrets beforehand.
```yaml
- name: 'Write Config & Key Files'
  run: |
    mkdir ~/.oci
    echo "[DEFAULT]" >> ~/.oci/config
    echo "user=${{secrets.OCI_USER_OCID}}" >> ~/.oci/config
    echo "fingerprint=${{secrets.OCI_FINGERPRINT}}" >> ~/.oci/config
    echo "pass_phrase=${{secrets.OCI_PASSPHRASE}}" >> ~/.oci/config
    echo "region=${{secrets.OCI_REGION}}" >> ~/.oci/config
    echo "tenancy=${{secrets.OCI_TENANCY_OCID}}" >> ~/.oci/config
    echo "key_file=~/.oci/key.pem" >> ~/.oci/config
    echo "${{secrets.OCI_KEY_FILE}}" >> ~/.oci/key.pem

- name: 'Install OCI CLI'
  run: |
    curl -L -O https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
    chmod +x install.sh
    ./install.sh --accept-all-defaults
    echo "::add-path::/home/runner/bin"
    exec -l $SHELL

- name: 'Fix Config File Permissions'
  run: |
    oci setup repair-file-permissions --file /home/runner/.oci/config
    oci setup repair-file-permissions --file /home/runner/.oci/key.pem
```



Now that the CLI is installed, we can check if our DB is in a 'STOPPED' state and if so we can start it. I've set the DB OCID as a secret in the repo. 
```yaml
- name: 'Check Running DB Instance'
  run: |
    echo "::set-env name=DB_STATE::$( \
        oci db autonomous-database get \
        --autonomous-database-id ${{ secrets.AUTONOMOUS_DB_OCID }} \
        --query "data."lifecycle-state"" \
        --raw-output \
    )"
- name: 'Start DB'
  if: ${{env.DB_STATE == 'STOPPED'}}
  run: |
    oci db autonomous-database start \
      --autonomous-database-id  ${{ secrets.AUTONOMOUS_DB_OCID }} \
      --wait-for-state AVAILABLE
```



**Note**: We're waiting for the DB state to be 'AVAILABLE' or our microservice might have connection failures if it starts up before the DB is available!

Next, we check to see if the microservice VM is running, and if not we issue the proper CLI command to start it up. Again, the instance OCID is stored as a secret.
```yaml
- name: 'Check Running VM Instance'
  run: |
    echo "::set-env name=INSTANCE_OCID::$( \
     oci compute instance list \
     --lifecycle-state STOPPED \
     --compartment-id ${{secrets.VM_COMPARTMENT_OCID}} \
     --display-name ${{env.INSTANCE_NAME}} \
     --query "data [0].id" \
     --raw-output \
    )"
- name: 'Start VM'
  if: ${{env.INSTANCE_OCID}}
  run: |
    oci compute instance action \
      --action start \
      --instance-id ${{ env.INSTANCE_OCID }}
```



The nice thing about this workflow is that we're reusing the existing VM instance and just turning it on and off every day. That means our public IP address doesn't change. Here's a look at a successful run from this morning on this job:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f5157c00-263a-4a64-825d-622aa4fcf662/file_1592923922969.png)

The stop workflow is almost identical, except that it does the exact opposite of the start workflow.
```yaml
- name: 'Check Running DB Instance'
  run: |
    echo "::set-env name=DB_STATE::$( \
        oci db autonomous-database get \
        --autonomous-database-id ${{ secrets.AUTONOMOUS_DB_OCID }} \
        --query "data."lifecycle-state"" \
        --raw-output \
    )"
- name: 'Stop DB'
  if: ${{env.DB_STATE == 'AVAILABLE'}}
  run: |
    oci db autonomous-database stop \
      --autonomous-database-id  ${{ secrets.AUTONOMOUS_DB_OCID }}
- name: 'Check Running VM Instance'
  run: |
    echo "::set-env name=INSTANCE_OCID::$( \
     oci compute instance list \
     --lifecycle-state RUNNING \
     --compartment-id ${{secrets.VM_COMPARTMENT_OCID}} \
     --display-name ${{env.INSTANCE_NAME}} \
     --query "data [0].id" \
     --raw-output \
    )"
- name: 'Stop VM'
  if: ${{env.INSTANCE_OCID}}
  run: |
    oci compute instance action \
      --action stop \
      --instance-id ${{ env.INSTANCE_OCID }}
```



## Summary

In this post, we looked at two approaches to cutting your cloud bill by turning off instances via scheduled jobs when they are not in use.

Photo by [Jason Dent](https://unsplash.com/@jdent?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](/s/photos/scale?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
