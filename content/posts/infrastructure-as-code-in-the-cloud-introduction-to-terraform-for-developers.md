---
title: " Infrastructure as Code in the Cloud: Introduction to Terraform for Developers"
slug: "infrastructure-as-code-in-the-cloud-introduction-to-terraform-for-developers"
author: "Todd Sharp"
date: 2021-02-26
summary: "In this post, we'll take an introductory look at Infrastructure as Code with Terraform focused on the things developers need to know."
tags: ["Cloud", "Cloud Native"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/da433cde-2a11-48c4-8025-2c461359f284/banner_neda_astani_kwtkd7mhqke_unsplash.jpg"
---

Over the next few blog posts, I'd like to give my developer friends a "stratospheric" view of Terraform to introduce the tool and give some basic understanding of what it is and how it works. My goal here is not to give you a deep dive and there are several reasons for that. First, and most importantly, [Hashicorp has done a fine job of documenting Terraform](https://www.terraform.io/docs/language/index.html) themselves so it would be pointless for me to recreate that documentation here. Secondly, it's my belief that many developers don't necessarily need an in-depth, end-to-end understanding of Terraform. DevOps engineers, of course, will want to be intimately familiar with it. But developers often require just enough working knowledge of such tools to let them feel comfortable utilizing them on the semi-rare occasion that they need to use them. That said, it's my goal here to give you a "15 kilometer" view of Terraform that will intentionally leave out some more detailed information, linking to the documentation as appropriate to give you a reference point for further research.  

Here's the roadmap that I'm going to follow for this series:

- Terraform Intro & Basics (this post)

- Installing Terraform and Running Your First Script

- Getting Started with Terraform on the Oracle Cloud with Resource Manager

- Advanced Terraform on the Oracle Cloud with Resource Manager 

- Integrating Terraform and Resource Manager into your CI/CD Pipeline

## Intro

The purpose of Terraform is to define resources which represent infrastructure objects. The rest of the language exists to make it easier to define resources. Understanding that concept at the outset of our journey makes it easier to understand a lot of things in Terraform and tends to simplify the entire concept (at least to me). 

## Basic Structure & Syntax 

The basics structure of Terraform can be expressed with the following:
```tf
<BLOCK TYPE> "<BLOCK LABEL>" "<BLOCK LABEL>" {
  # Block body
  <IDENTIFIER> = <EXPRESSION> # Argument
}
```



Blocks are containers for content - for example, a resource. They have a block type, zero or more labels, and a body that contains arguments and potentially other blocks. Arguments assign values to names. Block ordering doesn't matter as Terraform considers the relationships between resources to determine the order of operations. In other words, if a compute instance resource needs the ID of a virtual cloud network before it can be created, Terraform understands this and will create the virtual cloud network first. Pretty smart!

Learn More: \[[Overview](https://www.terraform.io/docs/language/index.html), [Configuration Syntax](https://www.terraform.io/docs/language/syntax/configuration.html)\]

## Files

Terraform files (mostly) use the `.tf` extension. There are other options (like JSON), but you probably won't see them often. For convenience and readability, configuration files are often broken into several, purpose driven files. If they're in the same directory, Terraform will manage them all as if they were one big file.

Learn More: \[[File Extensions](https://www.terraform.io/docs/language/files/index.html#file-extension)\]

## Resources

The most important part of Terraform, resources describe infrastructure objects. Compute instances, virtual networks, object storage buckets - all of 'em. They define an item of a given type and give them a local name. 
```tf
resource "oci_core_instance” “compute_instance” { 
  availability_domain = var.instance_availability_domain
  compartment_id = var.compartment_id
  shape = var.instance_shape
}
```



The example above defines a compute instance (`oci_core_instance`) and gives it the local name `my_instance`. It contains 3 required arguments, `availability_domain`, `compartment_id` and `shape`. We'll look deeper at resources in a future post, but for now, get comfortable with the syntax. It'll look similar for other operations with block type being first, and labels following that before the block is opened. Names must start with a letter or underscore, and can only contain letters, digits, underscores and dashes. They need not be quoted, but some find them easier to read when quoted (and your IDE will probably make them look prettier when quoted).

Terraform saves the state of your configuration and will intelligently manage subsequent runs of a given configuration. It's smart about how it manages your objects when you re-run a given configuration - creating objects that don't exist, updating (if necessary) objects that already exist and destroying objects that exist in state but no longer exist in the configuration.

Many resources export attributes, or the data returned as a result of the resource operation. For example, creating a new instance will return a set of attributes that includes the created instance ID, which can be used in other resources or output at the end of the script. Attributes are accessed via dot notation (with brackets for list elements) as you'd expect. To retrieve the ID of the instance created in the code snippet above, you'd use `oci_core_instance.new_instance.id`.

### Meta Arguments

Terraform has several meta-arguments that you'll need to use occasionally. These are usually arguments that modify the behavior of the resource creation in some way. For example, you can add a `count` argument inside your resource block to create multiple infrastructure objects without needing to add an additional resource block (you can also use this argument to conditionally create a resource based on a boolean local variable that sets `count` to `0` if needed, but that's a topic for another post).

Learn More: \[[Resources](https://www.terraform.io/docs/language/resources/syntax.html#resource-blocks), [Behavior](https://www.terraform.io/docs/language/resources/behavior.html), [Count](https://www.terraform.io/docs/language/meta-arguments/count.html)\]

## Data Sources

Data Sources do exactly what they sound like they do - fetch data to be used in other places in your script. Maybe you need to fetch a list of compute images and filter it to find the ID of a specific image by name to use it when creating your instance. For that, you'd use a data source. They look similar to resources - here's an example:
```tf
data "oci_core_images” "images" {
  compartment_id = var.compartment_id
}
```



Where do data sources come from? Providers - and we'll talk about them next.

Learn More: \[[Data Sources](https://www.terraform.io/docs/language/data-sources/index.html)\]

## Providers

Providers are a collection of resource types and data sources that come from a single platform or cloud provider. Terraform automatically installs providers when you initialize a project (more on how to do that later). You can have multiple providers in a project, if necessary.

Here's how a provider looks:
```tf
provider "oci" {
  tenancy_ocid = ""    
  user_ocid = ""
  private_key_path = ""
  private_key_password = ""
  fingerprint = ""
  region = ""
}
```



Learn More: \[[Providers](https://www.terraform.io/docs/language/providers/index.html), [Multiple Providers](https://www.terraform.io/docs/language/providers/configuration.html#alias-multiple-provider-configurations), [Provider Registry](https://registry.terraform.io/browse/providers)\]

## Variables and Outputs

### Input Variables

Terraform supports declared input variables which let your project accept dynamic inputs. You can set the values by passing them in via the Terraform CLI, or by setting environment variables that follow a specific naming convention (beginning with `TF_VAR_`). Variables can be validated (as of version 0.13.0). Later on we'll look at how input variables are managed in the Oracle Cloud, which I think you'll find quite interesting.

Here's a simple variable declaration:
```tf
variable “image_name" {
  type = string
}
```



You can also set defaults:
```tf
variable “image_name" {
  type = string
  default = “my-image"
}
```



Variables are accessed from other blocks using the `var` keyword: `var.image_name`.

### Output Values

Output values give you the ability to print out resource creation results (or whatever information you need) from your project. For example, maybe you want to print out the public IP of a compute instance that was created.
```tf
output "public_ip" {
  description = "Public IPs of compute instance. "
  value = oci_core_instance.compute_instance.public_ip
}
```



Learn More: \[[Variables](https://www.terraform.io/docs/language/values/variables.html), [Variable Type Constraints](https://www.terraform.io/docs/language/values/variables.html#type-constraints), [Variable Validation](https://www.terraform.io/docs/language/values/variables.html#custom-validation-rules), [Output Values](https://www.terraform.io/docs/language/values/outputs.html), [Sensitive Values](https://www.terraform.io/docs/language/expressions/references.html#sensitive-resource-attributes)\]

## Expressions and Functions

Expressions are used to refer to or compute values within a configuration. These range from simple literals to elements exported from data sources (as we saw above). Basic arithmetic, conditional evaluation and built-in functions also can be used in expressions. 

Expressions and functions are one section where you won't want to take a shortcut as they are pretty foundational concepts with Terraform that will impact your daily usage of the tool and language. I strongly recommend reading through the docs on these topics (links just below here).

Learn More: \[[Expressions](https://www.terraform.io/docs/language/expressions/index.html), [Functions](https://www.terraform.io/docs/language/functions/index.html)\]

## Project Structure

Terraform is pretty flexible and the way you structure your projects is largely up to you. Like all things development related, I do recommend that your team develop some standards and stick to them. I like to keep separate files in my projects for different purposes: 

- `variables.tf` or `vars.tf` for variable declarations

- `outputs.tf` for output blocks

- `provider.tf` for provider definitions

- Individual files broken up by infrastructure category. Ex: `core.tf` for compute instances, `functions.tf` for FaaS, etc. Infrastructure files can contain resource and data blocks related to the category that they focus on.

Certainly you and/or your team will find what structure and convention works best. Hopefully this tutorial has given you the basic knowledge that you need to feel comfortable learning more in the future posts in this series. Until next time!

Learn More: \[[Style Conventions](https://www.terraform.io/docs/language/syntax/style.html)\]

## Summary

In this post, we took a look at the basics of Terraform for developers. In the next post, we'll install Terraform and create an run our first script.

Photo by [Neda Astani](https://unsplash.com/@nedaastani?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

