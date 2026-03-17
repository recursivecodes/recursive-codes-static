---
title: "Automated Generation For OCI IAM Policies"
slug: "automated-generation-for-oci-iam-policies"
author: "Todd Sharp"
date: 2019-01-10
summary: "This post discusses the initial release of a command line based tool to generate IAM policies for OCI."
tags: ["Cloud", "Developers"]
keywords: "OCI, Cloud, IAM, Oracle Cloud, Oracle Cloud Infrastructure, Groovy, Policy, Security, security policies"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/23005b0e-de4f-4c5e-84d8-3da8102af3b7/banner_2019_01_10_10_37_52.png"
---

As a cloud developer evangelist here at Oracle, I often find myself playing around with one or more of our services or offerings on the Oracle Cloud.  This of course means I end up working quite a bit in the [Identity and Access Management (IAM)](https://docs.cloud.oracle.com/iaas/Content/Identity/Concepts/overview.htm) section of the OCI Compute Console.  It's a pretty straightforward concept, and likely familiar if you've worked with any other cloud provider.  I won't give a full overview here about IAM as it's been covered plenty already and the documentation is concise and easy to understand.  But one task that always ends up taking me a bit longer to accomplish than I'd like it to is [IAM policy generation](https://docs.cloud.oracle.com/iaas/Content/Identity/Concepts/policygetstarted.htm).  The policy syntax in OCI is as follows:

**Allow \<subject\> to \<verb\> \<resource-type\> in \<location\> where \<conditions\>**

Which seems pretty easy to follow - and it is.  The issue that I often have though is actually remembering the values to plug in for the variable sections of the policy.  Trying to remember the exact group name, or available verbs and resource types, as well as the exact compartment name that I want the policy to apply to is troublesome and usually ends up with me opening two or three tabs to look up exact spellings and case and then flipping over to the docs to get the verb and resource type just right.  So, I decided to do something to make my life a little easier when it comes to policy generation and figured that I'd share it with others in case I'm not the only one who struggles with this.  

So, born out of my frustration and laziness, I present a simple project to help you generate IAM policies for OCI.  The tool is intended to be run from the command line and prompts you to make selections for each variable.  It gives you choices of available options based on actual values from your OCI account.  For example, if you choose to create a policy targeting a specific group, the tool gives you a list of your groups to choose from.  Same with verbs and resource types - the tool has a list of them built in and lets you choose which ones you are targeting instead of referring to the IAM policy documentation each time.  Here's a video demo of the tool in action:

The code itself isn't a masterpiece - there's hardcoded values for verbs and resource types because those aren't exposed via the OCI CLI or SDK in anyway.  But it works, and makes policy generation a bit less painful.  The code behind the tool is located on [GitHub](https://github.com/recursivecodes/oci-policy-generator), so feel free to submit a pull request to keep the tool up to date or enhance it in any way.  It's written in Groovy and can be run as a Groovy script, or via java -jar.  If you'd rather just get your hands on the binary and try it out, grab the [latest release](https://github.com/recursivecodes/oci-policy-generator/releases) and give it a shot.

The tool uses the OCI CLI behind the scenes to query the OCI API as necessary.  You'll need to make sure the [OCI CLI](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/cliconcepts.htm) is installed and configured on your machine before you generate a policy.  I decided to use the CLI as opposed to the SDK in order to minimize external dependencies and keep the project as light as possible while still providing value.  Besides, the OCI CLI is pretty awesome and if you work with the Oracle Cloud you should definitely have it installed and be familiar with it.

Please check out the tool and as always, feel free to comment below if you have any questions or feedback.
