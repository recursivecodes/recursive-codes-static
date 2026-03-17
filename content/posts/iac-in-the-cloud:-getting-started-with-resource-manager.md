---
title: "IaC in the Cloud: Getting Started with Resource Manager"
slug: "iac-in-the-cloud:-getting-started-with-resource-manager"
author: "Todd Sharp"
date: 2021-03-05
summary: "Let's take a look at what it takes to get started running Terraform scripts in the cloud with Oracle Resource Manager."
tags: ["Cloud", "Cloud Native"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/banner_aron_visuals_5wxay7d7yje_unsplash.jpg"
---

Welcome back to this series where we looking at using Terraform to manage our cloud infrastructure. In the first post of this series, we looked at the [very basics of Terraform for developers](/posts/iac-in-the-cloud:-introduction-to-terraform-for-developers). In part two, we [installed Terraform and wrote, planned and applied a script](/posts/iac-in-the-cloud:-installing-terraform-and-running-your-first-script) that created a resource in our Oracle Cloud Infrastructure (OCI) cloud tenancy. In this post, I'd like us to take a look at how our OCI Engineers have integrated Terraform into our cloud via a tool called Resource Manager. 

Since this post is a bit long, here's a quick table of contents:

- [What is OCI Resource Manager](#what-is-oci-resource-manager)
  - [Configuration Source Provider](#configuration-source-provider)
  - [Stacks](#stacks)
  - [Jobs](#jobs)
  - [Drift](#drift)
- [Using Resource Manager](#using-resource-manager)
  - [Create GitHub Repo](#create-github-repo)
  - [Creating Configuration Source Provider](#creating-configuration-source-provider)
  - [Creating a Stack](#creating-a-stack)
  - [Running Jobs](#running-jobs)
- [Summary](#summary)

## What is OCI Resource Manager

Resource Manager is a way to plan and execute Terraform scripts via the cloud. Now, you may ask why this is necessary if Terraform can be executed locally or via a CI/CD pipeline via the Terraform CLI or various plugins. The answer to that question is, as we so often say, "it depends". Certainly there are times when you won't need (or want) to run your Terraform plans from the cloud. But, there are other times where it can be handy and helpful to do so and as you'll see below, Resource Manager has some fancy features that enhance your Terraform projects that will provide a benefit to you and the users who deploy the infrastructure you define. Remember, sometimes we're defining infrastructure in such a way that we intend to distribute that infrastructure definition. That could mean that you need to share it with an internal/external team, or perhaps you're creating an open source project that others will deploy to the Oracle Cloud. Resource Manager has got your back on this - trust me.

**Tip:** When using Resource Manager, the only field necessary in your `provider` block is the given `region` that you are working in. This is because the jobs are securely executed in your tenancy which inherits the permissions and policies of your logged-in user.

We should get a few terms defined up front here to avoid confusion later on. Read more in the [official docs](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm), but here's the high-level:

### Configuration Source Provider

Info related to an external source control system that is used for version control of your Terraform configuration files. These are super helpful because they allow you to build directly from a version control system instead of packaging and manually uploading your stack as a `.zip` file.

### Stacks

A fancy term for a bundle of scripts that'll be executed together as a single plan. These can be uploaded as a `.zip` file, or pulled directly from a configuration source provider.

### Jobs

An execution that runs against a stack; a plan, apply or destroy job.

### Drift

The difference between real-world state and the state as saved by the last executed job on the stack. For example - if you manually change a resource in your tenancy that was created/updated by a Resource Manager job, you've introduced drift into the state. [Drift detection reports](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Tasks/managingstacksandjobs.htm#DriftDetect) are available to help with this. 

Resource Manager is available in the OCI console, through any of our SDKs and via the OCI CLI. 

## Using Resource Manager

To learn about Resource Manager, I think it will be best if we use a project for our configuration and use that project to create a stack and execute our plan/apply jobs. 

### Create GitHub Repo

For this demo, let's store our code in GitHub so that we can take advantage of the OCI configuration source provider to automatically pull our latest Terraform configuration from our repo. This will prevent us from having to zip and upload the stack each time that we want to run it. 

Create a new repository in GitHub at <https://github.com/new>.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445728.png)

Now check out that new repo locally.
```bash
trsharp at ora-recursivecodes-mb in /projects/terraform
$ git clone https://github.com/recursivecodes/oci-resource-manager-demo.git
Cloning into 'oci-resource-manager-demo'...
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
Unpacking objects: 100% (3/3), done.
```



We'll add our configuration files in just a bit.

### Creating Configuration Source Provider

Now let's set up a configuration source provider so that we can build our stack directly from our GitHub project later on. We'll need a 'personal access token' from GitHub, so head to <https://github.com/settings/tokens> and click 'Generate new token'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445735.png)

Name your token and select `read:packages` for the scope.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445745.png)

Click 'Create' and copy the token from the next page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445749.png)

In the OCI console, search for and navigate to "configuration source provider".

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445754.png)

Click 'Create Configuration Source Provider'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445759.png)

In the create dialog, name it (#1), provide an optional description (#2), choose the compartment (#3), select 'GitHub' for type (#4), enter `https://github.com` for the Server URL (#5), and paste your GitHub Personal Access Token (#6). 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445766.png)

The provider is now ready to be used in the next step.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445777.png)

### Creating a Stack

In this step, we're going to create a Terraform script that does some basic resource creation, check that in to our GitHub repo and then create a stack in Resource Manager that pulls from our GitHub repo.

Navigate to the directory where you cloned the GitHub repo that we created above and create a file called `demo.tf`. We'll keep this from getting too complex by just using a single file for this Terraform configuration. First, add the `provider` block. Since this is going to run in the Oracle Cloud, we only need to declare the `region` in our `provider`.
```tf
variable "compartment_ocid" {
    default = "ocid1.compartment.oc1..[redacted]"
}
variable "region" {
    default = "us-phoenix-1"
}

provider "oci" {
  region = var.region
}
```



Next, we'll add a `resource` block that will create an Object Storage bucket for us. We'll add a few variables to store the bucket name and namespace and we'll output the result of the bucket creation. Here's the entire script.
```tf
variable "compartment_ocid" {
    default = "ocid1.compartment.oc1..[redacted]"
}
variable "region" {
    default = "us-phoenix-1"
}
variable "bucket_namespace" {
    default = "toddrsharp"
}
variable "bucket_name" {
    default = "resource_manager_demo_bucket"
}

provider "oci" {
    region = var.region
}

resource "oci_objectstorage_bucket" "create_bucket" {
    # required
    compartment_id = var.compartment_ocid
    name = var.bucket_name
    namespace = var.bucket_namespace

    # optional
    access_type = "NoPublicAccess" # <---- updated from "ObjectRead"
}

output "new_bucket" {
    value = oci_objectstorage_bucket.create_bucket
}
```



Let's add the file to Git, commit and push.
```bash
trsharp at ora-recursivecodes-mb in ~/Projects/terraform/oci-resource-manager-demo (main●)
$ git add demo.tf 

trsharp at ora-recursivecodes-mb in ~/Projects/terraform/oci-resource-manager-demo (main●)
$ git commit -m "initial commit"                                         
[main e2f22f2] initial commit
1 file changed, 26 insertions(+)
create mode 100644 demo.tf

trsharp at ora-recursivecodes-mb in ~/Projects/terraform/oci-resource-manager-demo (main)
$ git push -u origin main  
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 4 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 538 bytes | 538.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To https://github.com/recursivecodes/oci-resource-manager-demo.git
   0f30c39..e2f22f2  main -> main
Branch 'main' set up to track remote branch 'main' from 'origin'.
```



Now let's build the stack. Search for and navigate to 'Stacks' in the OCI console.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445784.png)

Click 'Create Stack'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445788.png)

Choose 'Source Code Control System' as the origin (#1), our GitHub Source Provider (#2), the new project repo (#3) and the main branch (#4). Give the stack a name (#5).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445802.png)

Click 'Next' and the second wizard page verifies that the resources that we're creating don't require variable configuration. If we wanted to, we could require variable name input and we'll look at that later on. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445809.png)

Click 'Next', review the information and click 'Create'. You'll be directed to the Stack details page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445813.png)

Now that our stack is created, let's look at running jobs. 

**Note:** Since we created the stack from our GitHub repository, every job run will first pull the most latest commit from the branch we specified.

### Running Jobs

See that dropdown at the top of the page labeled 'Terraform Actions'?  Click that to reveal the possible actions we can take with our stack at this point.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445817.png)

To run `terraform plan` against this stack, click 'Plan' (#1), to run `terraform apply` click 'Apply' (#2), and to run `terraform destroy` click 'Destroy' (#3).

When running a plan, give it a name and click 'Plan'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445820.png)

After the plan runs, you'll see a success message on the plan details page. Notice the commit hash of the commit used to run this plan.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445824.png)

Observe the Log in the plan details page.
```bash
Initializing provider plugins...
- Finding latest version of hashicorp/oci...
- Installing hashicorp/oci v4.12.0...
- Installed hashicorp/oci v4.12.0 (unauthenticated)
The following providers do not have any version constraints in configuration,
so the latest version was installed.
To prevent automatic upgrades to new major versions that may contain breaking
changes, we recommend adding version constraints in a required_providers block
in your configuration, with the constraint strings suggested below.
*hashicorp/oci: version = "~> 4.12.0"
Terraform has been successfully initialized!
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.
If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.
------------------------------------------------------------------------
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create
Terraform will perform the following actions:
  # oci_objectstorage_bucket.create_bucket will be created
  + resource "oci_objectstorage_bucket" "create_bucket" {
      [removed for brevity]...
    }
Plan: 1 to add, 0 to change, 0 to destroy.
------------------------------------------------------------------------
This plan was saved to: <path hidden>
To perform exactly these actions, run the following command to apply:
    terraform apply "<path hidden>"
```



Back in the stack details, apply the plan.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445828.png)

Observe the Log output on the apply job, and once it's complete you can view the job output.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445833.png)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445838.png)

We can confirm via the Object Storage bucket list page that our new bucket was created.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445857.png)

Finally, to clean up and remove the bucket that was created via our stack, head back to the stack details and create and run a 'destroy' job.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/24e523c6-2b58-4a3b-9b8a-49d995812906/file_1614016445864.png)

The destruction will be confirmed via the log output.
```bash
oci_objectstorage_bucket.create_bucket: Refreshing state... [id=n/toddrsharp/b/resource_manager_demo_bucket]
oci_objectstorage_bucket.create_bucket: Destroying... [id=n/toddrsharp/b/resource_manager_demo_bucket]
oci_objectstorage_bucket.create_bucket: Destruction complete after 2s
```



## Summary

In this post, we learned how to run our Terraform scripts in the Oracle Cloud via Resource Manager. In the next post, we'll look at some ways to make our scripts even more powerful by adding support for variable inputs and validation so that we can distribute and share our Terraform projects or simply improve the UX for our team members who use the scripts. 

Photo by [Aron Visuals](https://unsplash.com/@aronvisuals?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

