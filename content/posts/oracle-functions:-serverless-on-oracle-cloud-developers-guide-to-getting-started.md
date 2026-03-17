---
title: "Oracle Functions: Serverless On Oracle Cloud - Developer's Guide To Getting Started (Quickly!)"
slug: "oracle-functions:-serverless-on-oracle-cloud-developers-guide-to-getting-started-quickly"
author: "Todd Sharp"
date: 2019-02-08
summary: "An intro to Oracle Functions, our hosted serverless offering.  "
tags: ["Cloud", "Developers", "Java", "JavaScript", "Open Source"]
keywords: "Javascript, Java, serverless, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8dd5fc80-3f55-4e83-9b07-8026959f4271/banner_oci_subscribe_to_region_mov.gif"
---

Back in December, as part of our [larger announcement](https://www.oracle.com/cloud/cloud-native/) about several cloud native services, we [announced a new service offering called Oracle Functions](https://blogs.oracle.com/cloud-infrastructure/announcing-oracle-functions). Oracle Functions can be thought of as Functions as a Service (FaaS), or hosted serverless that utilizes Docker containers for execution.  The offering is built upon the open source [Fn Project](https://fnproject.io/), which itself isn't new, but the ability to quickly deploy your serverless functions and invoke them via Oracle's Cloud makes implementation much easier than it was previously.  This service is currently in Limited Availability ([register here](https://go.oracle.com/LP=78019) if you'd like to give it a try), but recently I have been digging in to the offering and wanted to put together some resources to make things easier for developers looking to get started with serverless on Oracle Cloud. This post will go through the necessary steps to get your tenancy configured and create, deploy and invoke your first application and function with Oracle Functions.

Before getting started you'll need to configure your Oracle Cloud tenancy.  If you're in the Limited Availability trial, make sure your tenancy is subscribed to the Phoenix region because that's currently the only region where Oracle Functions is available.  To check and/or subscribe to this region, see the following GIF:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8dd5fc80-3f55-4e83-9b07-8026959f4271/oci_subscribe_to_region_mov.gif)

Before moving on, if you haven't yet [installed the OCI CLI](https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm), do so now.  And if you haven't, what are you waiting for?  It's really helpful for doing pretty much anything with your tenancy without having to log in to the console.

The rest of the configuration is a multi-step process that can take some time, and since no one likes to waste time on configuration when they could be writing code and deploying functions, I've thrown together a shell script to perform all the necessary configuration steps for you and get your tenancy completely configured to use Oracle Functions. 

Before we get to the script, **please do not simply run this script without reading it over and fully understanding what it does**.  The script makes the following changes/additions to your cloud tenancy:

1.  Creates a dedicated compartment for FaaS
2.  Creates a IAM group for FaaS users
3.  Creates a FaaS user
4.  Creates a user auth token that can be later used for Docker login
5.  Adds the FaaS user to the FaaS group
6.  Creates a group IAM policy
7.  Creates a VCN
8.  Creates 3 Subnets within the VCN
9.  Creates an internet gateway for the VCN
10. Updates the VCN route table to allow internet traffic to hit the internet gateway
11. Updates the VCN default security list to allow traffic on port 80
12. Prints a summary of all credentials that it creates

That's quite a lot of configuration that you'd normally have to manually perform via the console UI.  Using the OCI CLI via this script will get all that done for you in about 30 seconds.  Before I link to the script, let me reiterate, **please read through the script and understand what it does**.  You'll first need to modify (or at least verify) some environment variables on lines 1-20 that contain the names and values for the objects you are creating.

So with all the necessary warnings and disclaimers out of the way, [here's the script](https://gist.github.com/recursivecodes/9d4c3ae2e176933cb2a99dbbf25c34b4).  Download it and make sure it's executable and then run it.  You'll probably see some failures when it attempts to create the VCN because compartment creation takes a bit of time before it's available for use with other objects.  That's expected and OK, which is why I've put in some auto-retry logic around that point.  Other than that, the script will configure your tenancy for Oracle Functions and you'll be ready to move on to the next step.  Here's an example of the output you might see after running the script:
```txt
Created compartment faas-compartment with ID ocid1.compartment.oc1..[redacted]na
Created group faas-group with ID ocid1.group.oc1..[redacted]vq
Created user faas-user with ID ocid1.user.oc1..[redacted]va
Created Auth Token. Remember this token, it can not be retrieved in the future: ew[redacted]et
Added user faas-user to group faas-group
Action completed. Waiting until the resource has entered state: ACTIVE
Created policy faas-demo-policy. Use the command: 'oci iam policy get --policy-id ocid1.policy.oc1..[redacted]sa' if you want to view the policy.
Creating VCN. This may take a few seconds...
ServiceError:
{
    "code": "NotAuthorizedOrNotFound",
    "message": "Authorization failed or requested resource not found.",
    "opc-request-id": "[redacted]",
    "status": 404
}
[create failed, trying again in 10 seconds...]
Created VCN faas-demo-vcn with ID ocid1.vcn.oc1.phx.[redacted]ma
Created subnets: faas-subnet-1, faas-subnet-2, faas-subnet-3
Created internet gateway faas-internet-gateway with ID ocid1.internetgateway.oc1.phx.[redacted]kq
Updated default route table for VCN to allow traffic to internet gateway
Updated default security list to open port 80 for all subnets in VCN

Remember to save the generated auth token:

ew[redacted]et

This token is used for Docker login, with the username [redacted]/faas-user.
Your new compartment ID is ocid1.compartment.oc1..[redacted]na
Your subnet IDs are:

faas-subnet-1: ocid1.subnet.oc1.phx.[redacted]2q
faas-subnet-2: ocid1.subnet.oc1.phx.[redacted]hq
faas-subnet-3:ocid1.subnet.oc1.phx.[redacted]na

Use these subnets for your Fn applications.
Your user ID is: ocid1.user.oc1..[redacted]va
You can use the following profile section to modify your OCI CLI config for use with Fn (you'll need to generate a key and populate the necessary key related items):
[faas]
user=ocid1.user.oc1..[redacted]va
fingerprint=<public-key-fingerprint>
key_file=<private-key-pem-file>
tenancy=[redacted]
region=us-phoenix-1
pass_phrase=<passphrase>
```



Next, create a signing key.  I'll borrow from the quick start guide here:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8dd5fc80-3f55-4e83-9b07-8026959f4271/2019_02_07_09_53_05.png)

If you'd rather skip heading to the console UI in the final step, you can use the OCI CLI to upload your key like so:
``` {.brush: .bash}
oci iam user api-key upload --user-id ocid1.user.oc1..[redacted]ra --key-file <path-to-key-file> --region <home-region>
```

Next, open your OCI CLI config file (\~/.oci/config) in a text editor, paste the profile section that was generated in the script above and populate it with the values from your new signing key.  

At this point we need to make sure you've got Docker installed locally.  I'm sure you do, but if not, head over to the [Docker docs](https://docs.docker.com/) and install it for your particular platform.  Verify your installation with:
``` {.brush: .bash}
docker version
```

While we're here, let's login to Docker using the credentials we generated with the script above:
``` {.brush: .bash}
docker login phx.ocir.io
```

For username, copy the username from the script output (format \<tenancy\>/\<username\>) and the generated auth token will be used as your Docker login password.

Now let's get the Fn CLI installed. Jump to the [Fn project on GitHub](https://github.com/fnproject/cli) where you'll find platform specific instructions on how to do that. To be sure all's good, run:
``` {.brush: .bash}
fn version
```

To see all the available commands with the Fn CLI, refer to the [command reference docs](https://github.com/fnproject/docs/tree/master/cli#fn-command-reference). Good idea to bookmark that one!

Cool, now we're ready to finalize your Fn config.  Again, I'll borrow from the Fn quick start for that step:

Log in to your development environment as a functions developer and:

Create the new Fn Project CLI context by entering:
``` {.brush: .bash}
 fn create context <my-context> --provider oracle
```

Specify that the Fn Project CLI is to use the new context by entering:
``` {.brush: .bash}
 fn use context <my-context>
```

Configure the new context with the OCID of the compartment you want to own deployed functions:
``` {.brush: .bash}
 fn update context oracle.compartment-id <compartment-ocid>
```

Configure the new context with the api-url endpoint to use when calling the Fn Project API by entering:
``` {.brush: .bash}
 fn update context api-url <api-endpoint>
```

For example:
``` {.brush: .bash}
 fn update context api-url https://functions.us-phoenix-1.oraclecloud.com
```

Configure the new context with the address of the Docker registry and repository that you want to use with Oracle Functions by entering:
``` {.brush: .bash}
 fn update context registry <region-code>.ocir.io/<tenancy-name>/<repo-name>
```

For example:
``` {.brush: .bash}
 fn update context registry phx.ocir.io/acme-dev/acme-repo
```

Configure the new context with the name of the profile you've created for use with Oracle Functions by entering:
``` {.brush: .bash}
 fn update context oracle.profile <profile-name>
```

And now we're ready to create an application.  In Oracle Functions, an application is a logical grouping of serverless functions that share a common context of config variables that are available to all functions within the application.  The quick start shows how you use the console UI to create an application, but let's stick to the command line here to keep things moving quickly.  To create an application, run the following:
``` {.brush: .bash}
fn create app faas-demo --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx.[redacted]ma"]'
```

You'll need to pass at least one of your newly created subnet IDs in the JSON array to this call above. For high availability, pass additional subnets. To see your app, run:
``` {.brush: .bash}
fn list apps
```

To create your first function, run the following:
``` {.brush: .bash}
fn init --runtime node faas-demo-func-1
```

Note, I've used NodeJS in this example, but the runtime support is pretty diverse. You can currently choose from go, java8, java9, java, node, python, python3.6, python, python3.7, ruby, kotlin as your runtime. Once your function is generated, you'll see output similar to this:
``` {.brush: .bash}
Creating function at: /faas-demo-func-1
Function boilerplate generated.
func.yaml created.
```

Go ahead and navigate into the new directory and take a look at the generated files. Specifically, the **func.yaml** file which is a metadata definition file that is used by Fn to describe your project, it's triggers, etc. Leave the YAML file for now and open up **func.js** in a text editor. It ought to look something like so:
``` {.brush: .js}
const fdk=require('@fnproject/fdk');

fdk.handle(function(input){
  let name = 'World';
  if (input.name) {
    name = input.name;
  }
  return {'message': 'Hello ' + name}
})
```

Just a simple Hello World, but your function can be as powerful as you need it to be. It can interact with a DB within the same subnet on Oracle Cloud, or utilize object storage, etc. Let's deploy this function and invoke it. To deploy, run this command from the root directory of the function (the place where the YAML file lives). You'll see some similar output:
``` {.brush: .bash}
fn deploy --app faas-demo
Deploying faas-demo-func-1 to app: faas-demo
Bumped to version 0.0.2
Building image phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.2 .
Parts:  [phx.ocir.io [redacted] faas-repo faas-demo-func-1:0.0.2]
Pushing phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.2 to docker registry...The push refers to repository [phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1]
1bf689553076: Pushed
9703c7ab5d87: Pushed
0adc398bfc34: Pushed
0b3e54ee2e85: Pushed
ad77849d4540: Pushed
5bef08742407: Pushed
0.0.2: digest: sha256:94d9590065a319a4bda68e7389b8bab2e8d2eba72bfcbc572baa7ab4bbd858ae size: 1571
Updating function faas-demo-func-1 using image phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.2...
Successfully created function: faas-demo-func-1 with phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.2
```

Fn has compiled our function into a Docker container, pushed the Docker container to the Oracle Docker registry, and at this point our function is ready to invoke. Do that with the following command (where the first argument is the application name and the second is the function name):
``` {.brush: .bash}
fn invoke faas-demo faas-demo-func-1
{"message":"Hello World"}%
```

The first invocation will take a bit of time since Fn has to pull the Docker container and spin it up, but subsequent runs will be quick. This isn't the only way to invoke your function; you can also use HTTP endpoints via a signed request, but that's a topic for another blog post.

Now let's add some config vars to the application:
``` {.brush: .bash}
fn update app faas-demo --config defaultName=Person
```

As mentioned above, config is shared amongst all functions in an application. To access a config var from a function, grab it from the environment variables. Let's update our Node function to grab the config var, deploy it and invoke it:
``` {.brush: .js}
const fdk=require('@fnproject/fdk');

fdk.handle(function(input){
  let name = process.env.defaultName || 'World';
  if (input.name) {
    name = input.name;
  }
  return {'message': 'Hello ' + name}
})
```
``` {.brush: .bash}
$ fn deploy --app faas-demo
Deploying faas-demo-func-1 to app: faas-demo
Bumped to version 0.0.3
Building image phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.3 .
Parts:  [phx.ocir.io [redacted] faas-repo faas-demo-func-1:0.0.3]
Pushing phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.3 to docker registry...The push refers to repository [phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1]
7762ea1ed77f: Pushed
1b0d385392d8: Pushed
0adc398bfc34: Layer already exists
0b3e54ee2e85: Layer already exists
ad77849d4540: Layer already exists
5bef08742407: Layer already exists
0.0.3: digest: sha256:c6537183b5b9a7bc2df8a0898fd18e5f73914be115984ea8e102474ccb4126da size: 1571
Updating function faas-demo-func-1 using image phx.ocir.io/[redacted]/faas-repo/faas-demo-func-1:0.0.3...

$ fn invoke faas-demo faas-demo-func-1
{"message":"Hello Person"}%
```

So that's the basics on getting started quickly developing serverless functions with Oracle Functions. The Fn project has much more to offer and I encourage you to read more about it. If you're interested in taking a deeper look, make sure to [sign up for access](https://go.oracle.com/LP=78019) to the Limited Availability program.
