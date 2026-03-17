---
title: "The Complete Guide To Getting Up And Running With Docker And Kubernetes On The Oracle Cloud"
slug: "the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud"
author: "Todd Sharp"
date: 2019-07-01
summary: "A comprehensive guide to getting your Oracle Cloud tenancy ready for microservices deployment."
tags: ["Cloud", "Containers, Microservices, APIs", "Developers"]
keywords: "container, microservices, Cloud, Kubernetes, IAM"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/banner_image10.png"
---

In [my last post we defined the term "microservice"](/posts/microservices-are-easy) and looked at some of the reasons you might choose to implement a microservice approach to building your application's API. Before we dive too deep into code, I wanted to begin this series by showing how to prep your Oracle Cloud environment for your future microservice implementation. With that in mind, let's get started in creating a Kubernetes cluster and getting a Docker registry ready to go for our application. You've no doubt heard of Kubernetes, and you might be a bit intimidated by it if you haven't had much experience with it. We'll keep things simple for the purposes of this series though and use it as a way to deploy and expose our services as Docker containers.

## Setting Up A Compartment

First up, let's create a compartment in our Oracle Cloud console. Compartments are simply a way to group our infrastructure and services so we can keep items related to this particular project separate from the rest of our services that we consume on the Oracle Cloud.

Note: there are typically several ways to create service instances and resources on the Oracle Cloud. When possible, I'll show you how to create them via the console dashboard as well as via the [OCI CLI](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/cliconcepts.htm).

### Create Compartment Via Dashboard

To create a compartment via the dashboard, select Identity -\> Compartments from the console sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image1.png)

From the Compartment list page, click on 'Create Compartment' and populate the Create Compartment dialog like so:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image2.png)

### Create Compartment Via CLI

To create a compartment via the CLI, run:
```bash
oci iam compartment create --compartment-id [OCID of ‘root’ compartment] --name cloud-native-microservices --description "A compartment for cloud native microservices" --region us-ashburn-1
```



You must specify your "home" region when using the IAM service in the OCI CLI. You should receive a result that looks like so:
```json
{
  "data": {
    "compartment-id": "ocid1.compartment.oc1….",
    "defined-tags": {},
    "description": "A compartment for cloud native microservices",
    "freeform-tags": {},
    "id": "ocid1.compartment.oc1….",
    "inactive-status": null,
    "is-accessible": null,
    "lifecycle-state": "ACTIVE",
    "name": "cloud-native-microservices",
    "time-created": "2019-06-20T17:17:11.410000+00:00"
  },
  "etag": "30a1041f2265d4dc73e6b5d215fbe0567878671a"
}
```



To view a list of all compartments, run:
```bash
oci iam compartment list --compartment-id [OCID of ‘root’ compartment] –all
```



## Creating A Kubernetes Cluster (OKE)

Next, we'll need to create a Kubernetes cluster. This will be where we ultimately deploy our microservices.

### Create Cluster Via Dashboard

From the console sidebar menu, select Developer Services -\> Container Clusters (OKE):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image3.png)

Before you begin, it's very important that you read the documentation to [make sure your environment and development machine are prepared to work with Kubernetes](https://docs.cloud.oracle.com/iaas/Content/ContEng/Concepts/contengprerequisites.htm). You'll need to create the necessary policies before you create your cluster and make sure that you have [kubectl set up locally to manage your cluster](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

From the Cluster list page, first make sure that our newly created compartment is selected in the left-hand menu, then click 'Create Cluster'. Let's break this dialog down into a few steps:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image4.png)

In this screenshot, note a few items:

1.  The name of the cluster (must be 32 chars or less)
2.  Kubernetes version (choose the most recent version)
3.  Quick Create
4.  A summary of the VCN actions that will be taken

I strongly recommend that you choose the 'Quick Create' option which will create the necessary VCN, and subnets required for networking. You can choose 'Custom Create' if you'd like to connect your cluster to an existing, manually created VCN, but for most clusters the 'Quick Create' option should be sufficient.

Next, let's look at the rest of the dialog:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image5.png)

In this section we'll specify details related to our cluster's node pool. We'll choose the shape of the VMs used in our node pool (#1), the amount of nodes to be created in each subnet (#2, this can be changed later on), input an SSH public key (#3) which needs a bastion host (#4) in order to access the private nodes, and choose to enable the Kubernetes dashboard as well as Helm. Once you've populate these items, click 'Create' and you'll be taken to a dialog which reports progress as resources are created.

Once complete, the dialog should look similar to this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image6.png)\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image7.png)

Click 'Close' on this dialog you'll be taken directly to the cluster details page, which will report that the cluster is currently in a 'Creating' state.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image8.png)

Creating the cluster will take about 5 minutes, after which the cluster state will switch to 'Active' and the node pool instances will begin creating. Once all of the instances in the cluster become 'active' the cluster is ready to go:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image9.png)

To set up your local machine to interact with the newly created cluster, click on 'Access Kubeconfig' on the cluster details page:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image10.png)

Follow the instructions in the dialog to create your local `kubeconfig`:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image11.png)

After you've finished setting up the `kubeconfig`, run a few commands to confirm that your cluster is up and running.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image12.png)\
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image13.png)

Your cluster is now ready to go!

### Creating A Cluster Via CLI

I don't recommend using the CLI to create your OKE cluster, as the 'Quick Create' options available via the console dashboard are not an option via the CLI at this time. This means that the VCN and subnets must also be manually created via the CLI. You can certainly do this, and if you would like to do so please refer to the [OKE](https://docs.cloud.oracle.com/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/ce.html) and [Networking](https://docs.cloud.oracle.com/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/network.html) CLI documentation.

## Setting Up Docker (OCIR)

To deploy Docker containers to your newly created Kubernetes cluster, you'll need to set up your Docker registry (OCIR) and a dedicated user. If you don't have Docker installed on your development machine, you'll need to do that first. Refer to the [Docker install docs](https://docs.docker.com/install/) for specific instructions.

### Creating A Docker User Via Console

To create a dedicated user for OCIR, select Identity -\> Users from the console sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image14.png)

Click 'Create User' and populate the user name (#1), a description (#2) and the user's email address (#3):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image15.png)

Now visit the details page for this new user and click 'Auth Tokens' in the left sidebar menu. Generate and save a new Auth Token:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image16.png)

Next, create a group for Docker users by clicking on 'Groups' in the Identity sidebar and then clicking 'Create Group':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image17.png)

Click on the newly created group, click 'Add User To Group', then select the docker user to assign it to the docker group:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image18.png)

Next click 'Policies' in the sidebar, then 'Create Policy' to assign a registry policy for the newly created group:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image19.png)

### Creating A Docker User Via CLI

To create a Docker user via the CLI, run:
```bash
oci iam user create --name docker-user --description "A user for OCIR" --region us-ashburn-1 --compartment-id [OCID of ‘root’ compartment]
```



You'll receive a response similar to this:
```json
{
 "data": {
  "capabilities": {
   "can-use-api-keys": true,
   "can-use-auth-tokens": true,
   "can-use-console-password": true,
   "can-use-customer-secret-keys": true,
   "can-use-smtp-credentials": true
  },
  "compartment-id": "ocid1.tenancy.oc1",
  "defined-tags": {},
  "description": "A user for OCIR",
  "email": null,
  "external-identifier": null,
  "freeform-tags": {},
  "id": "ocid1.user.oc1",
  "identity-provider-id": null,
  "inactive-status": null,
  "is-mfa-activated": false,
  "lifecycle-state": "ACTIVE",
  "name": "docker-user",
  "time-created": "2019-06-20T18:38:40.876000+00:00"
 },
 "etag": "d6ae74447bb30a87f016ea7c11a5d407b7e2a1ca"
}
```



To generate an auth token via the CLI, run:
```bash
oci iam auth-token create --user-id [OCID of new user] --description "auth token for docker-user" --region us-ashburn-1
```



The 'token' value of the response will be the password that you'll use when logging in with Docker, so remember this value:
```json
{
 "data": {
  "description": "auth token for docker-user",
  "id": "ocid1.credential.oc1",
  "inactive-status": null,
  "lifecycle-state": "ACTIVE",
  "time-created": "2019-06-20T18:41:41.366000+00:00",
  "time-expires": null,
  "token": "[Token String]",
  "user-id": "ocid1.user.oc1"
 },
 "etag": "779ccf45a83cad9b6ebf8bcea0d4eb42bbbaecf5"
}
```



To create a group via the CLI, run:
```bash
oci iam group create --name docker-users --description "A group for Docker users" --region us-ashburn-1 --compartment-id [OCID of ‘root’ compartment]
```



Which will return a result similar to:
```json
{
 "data": {
  "compartment-id": "ocid1.tenancy.oc1 ",
  "defined-tags": {},
  "description": "A group for Docker users",
  "freeform-tags": {},
  "id": "ocid1.group.oc1",
  "inactive-status": null,
  "lifecycle-state": "ACTIVE",
  "name": "docker-users",
  "time-created": "2019-06-20T19:00:11.840000+00:00"
 },
 "etag": "3286c1c43f318a87b0987876d357e894b51da6e0"
}
```



To add the docker user to the docker-users group, run:
```bash
oci iam group add-user --group-id [group OCID] --user-id [user OCID] --region us-ashburn-1
```



To create a group policy, run:
```bash
oci iam policy create --name docker-user-policy --description "A policy for the docker users group" --statements '["allow group docker-users to manage repos in tenancy"]' --region us-ashburn-1 --compartment-id [OCID of ‘root’ compartment]
```



### Login To Docker

Now we're ready to test out logging in with Docker. The URL used for docker login will be in the form \[region\].ocir.io ([dependent on the region](https://docs.cloud.oracle.com/iaas/Content/Registry/Concepts/registryprerequisites.htm#Availab) that you'd like to use with OCIR), your Docker username will be \[tenancy\]/\[user\] and your password will be the auth token that we just generated. So, assuming a tenancy named 'toddrsharp', I'd login to Docker like so:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image20.png)

Before we move forward, let's create a Docker repo.

### Creating A Docker Repo in OCIR

Select Developer Services -\> Registry (OCIR) from the console sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image21.png)

From the Registry page, click 'Create Repository', enter a repo name and choose 'private' for access:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image22.png)

Click on the newly created repo to view details:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image23.png)

We can now test pushing a container to this repo with:
```bash
$ docker pull hello-world
$ docker tag hello-world phx.ocir.io/toddrsharp/hello-world-repo/hello-world:latest
$ docker push phx.ocir.io/toddrsharp/hello-world-repo/hello-world:latest
```



Which should result in a successful push:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image24.png)

Verify the container has been pushed to the registry via the console dashboard:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7843c7d8-5236-46a7-b324-eced099c6761/image25.png)

You're now set up to use OCIR as a Docker Registry!

## Summary

In this post we looked at creating a compartment, launching a Kubernetes cluster and configuring OCIR (Docker Registry) to get ready for our microservice deployment. In the next post we'll talk about some microservice data management patterns and start writing some code.
