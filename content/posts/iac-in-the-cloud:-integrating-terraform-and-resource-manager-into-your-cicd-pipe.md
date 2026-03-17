---
title: "IaC in the Cloud: Integrating Terraform and Resource Manager into your CI/CD Pipeline - Building Natively"
slug: "iac-in-the-cloud:-integrating-terraform-and-resource-manager-into-your-cicd-pipeline-building-natively"
author: "Todd Sharp"
date: 2021-03-19
summary: "In the final post in this series, we'll build our infrastructure in our CI/CD pipeline with the native Terraform CLI."
tags: ["Cloud", "Cloud Native"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8a6acc7d-3c67-4a11-8cb5-64383eeb33f5/banner_pete_gontier_4fqmiaj7_3u_unsplash.jpg"
---

Welcome to the final post in this series about using Terraform to manage infrastructure in the Oracle Cloud. In the last post, we looked at how to use the OCI CLI in our GitHub Actions pipeline to execute our Terraform scripts via creating stacks and jobs with Resource Manager. In this post, we'll simplify the concept and make it a bit more portable by using native Terraform in our GitHub Actions pipeline. You'll lose a bit of the power and flexibility of Resource Manager, but if you're just looking to simply build and maintain your infrastructure, this solution is perfectly great for you!

If you've missed the previous posts in this series, here is a list to catch up:

- [Infrastructure as Code in the Cloud: Introduction to Terraform for Developers](/posts/iac-in-the-cloud:-introduction-to-terraform-for-developers)

- [Infrastructure as Code in the Cloud: Installing Terraform and Running Your First Script](/posts/iac-in-the-cloud:-installing-terraform-and-running-your-first-script)

- [Infrastructure as Code in the Cloud: Getting Started with Resource Manager](/posts/iac-in-the-cloud:-getting-started-with-resource-manager)

- [Infrastructure as Code in the Cloud: Advanced Terraform on the Oracle Cloud with Resource Manager](/posts/iac-in-the-cloud:-advanced-terraform-on-the-oracle-cloud-with-resource-manager)

- [Infrastructure as Code in the Cloud: Integrating Terraform and Resource Manager into your CI/CD Pipeline - Release Assets](/posts/iac-in-the-cloud:-integrating-terraform-and-resource-manager-into-your-cicd-pipeline-release-assets)

- [Infrastructure as Code in the Cloud: Integrating Terraform and Resource Manager into your CI/CD Pipeline - Building With the OCI CLI](/posts/iac-in-the-cloud:-integrating-terraform-and-resource-manager-into-your-cicd-pipeline-building-with-the-oci-cli)

## Building Infrastructure From Your Pipeline

Just like in our last post, we'll need some secret values so that we can execute our Terraform scripts from our CI/CD pipeline. Set some secrets for the following values from your tenancy. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8a6acc7d-3c67-4a11-8cb5-64383eeb33f5/file_1614019141314.png)

### Running With Terraform

Using the OCI CLI to build our Terraform scripts via Resource Manager is nice, but if you remember from our last post, it wasn't exactly a quick process since we had to install the CLI and all of the Terraform script execution happened in our cloud tenancy instead of on the pipeline/build server. Let's see if we can improve the build times (and reduce a bit of the build script complexity) by executing our scripts natively in the pipeline. 

We'll start by defining our pipeline as we did before in a file called `build.yaml`. 

**Note:** Like before, we'll use the same GitHub project, but again branched:  https://github.com/recursivecodes/oci-resource-manager-demo/tree/github-actions-tf

We've defined our environment variables again, but this time we prefixed them with `TF_VAR_` which, if you remember back to an earlier post in this series, is a special prefix that Terraform will pick up on and set our script variables accordingly. Next, checkout the code and configure the [Hashicorp "setup-terraform" plugin](https://github.com/marketplace/actions/hashicorp-setup-terraform) which will install Terraform in our build environment.
```yaml
- uses: actions/checkout@v2
- uses: hashicorp/setup-terraform@v1
```



That's all the config we need. Now we can run our scripts directly via the Terraform CLI as we did earlier in this series when we ran them manually on our own machine. Add steps to initialize Terraform and validate our script(s):
```yaml
- name: 'Init Terraform'
  id: init
  run: terraform init

- name: 'Validate Terraform'
  id: validate
  run: terraform validate
```



Then run `terraform plan` and `terraform apply`.
```yaml
- name: 'Terraform Plan'
  id: plan
  run: terraform plan
  continue-on-error: false

- name: 'Terraform Apply'
  id: apply
  run: terraform apply -auto-approve
```



Check in and push the build and once again the pipeline will be executed automatically. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8a6acc7d-3c67-4a11-8cb5-64383eeb33f5/file_1614019141324.png)

But this time, we get a much faster execution - from 3 minutes 17 seconds down to 13 total seconds. 

## Summary

In this post, we looked at executing our Terraform scripts to build our infrastructure in our CI/CD pipeline using the native Terraform CLI. 

## Series Summary

In this series, we have focused on Infrastructure as Code. From the very basic intro to Terraform for developers, to integrating our solution into our CI/CD pipeline we have dug deep into every aspect of automating our infrastructure and hopefully you have learned the basics and benefits of using using this solution in your cloud native applications. As always, please feel free to provide me your feedback and check me out on [Twitter](https://twitter.com/recursivecodes).

Photo by [Pete Gontier](https://unsplash.com/@integerpoet?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

