---
title: "Instance and Resource Principal Authentication With The OCI TypeScript/JavaScript SDK"
slug: "instance-and-resource-principal-authentication-with-the-oci-typescriptjavascript-sdk"
author: "Todd Sharp"
date: 2020-08-11
summary: "In this post, we'll see how to use instance and resource principal authentication with the OCI SDK for TypeScript & JavaScript."
tags: ["Cloud", "Developers", "JavaScript"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/e70ac79f-495a-4087-bf7c-66fc091dd129/banner_chris_panas_0yiy0xajjhq_unsplash.jpg"
---

In June, we launched the Oracle Cloud Infrastructure (OCI) SDK for TypeScript & JavaScript to [enable you to work with all of your favorite cloud APIs](/posts/oci-sdk-for-typescript-is-now-available-heres-how-to-use-it) directly from your TS & JS projects without having to resort to using REST APIs with a complex signing process. There are certainly times when it is preferable to manually sign your requests. For example, maybe you need to make a single call and you want to keep the codebase light you might want to avoid including the entire SDK dependency and sign the request manually (I've [blogged about this before](/posts/resource-principal-auth-with-nodejs-for-easy-oci-rest-api-access-from-your-oracle-functions)). However, there are also times when you need the full power of the SDK included in your projects. In those cases, you can now use both resource and instance principal authentication providers with the TS/JS SDK.

## What is Instance Principal Authentication?

I've talked about instance principal auth many times here on this blog, but if you're new here (where have you been?!) I'll quickly go over it again as a refresher. There are many different ways to authenticate when using the OCI SDKs - for example, you can use your credentials directly in an authentication provider (SimpleAuthenticationDetailsProvider) or you can use a config file located on disk somewhere (ConfigFileAuthenticationDetailsProvider). Both of these solutions require you to provide the SDK with your credentials (either in the form of variables/strings or stored as text on the disk). This is usually not a problem when developing your application because you typically (hopefully) already have a config file on your local disk to work with the OCI CLI. If you were to use one of these auth methods when you deploy your application to a VM in the Oracle Cloud, you now have to manage these sensitive values somehow. This becomes another potential security vulnerability in your infrastructure if it is not properly managed. But, if you think about it, when you are deploying to a VM in the Oracle Cloud, shouldn't that VM know (or have access to) all of the necessary information about your tenancy that it needs to sign and authenticate your SDK calls? Well, it [takes a small bit of configuration to enable it](https://docs.cloud.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm), but that's essentially what instance principal authentication is. The instance itself, when configured properly, uses a certificate that is frequently refreshed to sign the SDK requests so you do not have to worry about providing the credentials.

## What is Resource Principal Authentication?

Resource principal auth, in theory, is very similar to instance principal auth but used for resources that are not instances such as serverless functions. The implementation is slightly different, but the goal is the same - to sign SDK requests from a function deployed to the Oracle Cloud in a way that does not require developer provided credentials. I'm sure you're anxious to read the docs about this, so [here is the link to read more about resource principal auth](https://docs.cloud.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm). 

## Working With Resource Principals

Let's look at an example of using resource principal authentication to utilize the Object Storage API to retrieve the tenancies namespace. The first step is to create our serverless application:
```bash
$ fn create app ts-sdk-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx..."]'
```



Next, create a function using Node:
```bash
$ fn init --runtime node ts-sdk-rp-demo-fn
Creating function at: ./ts-sdk-rp-demo-fn
Function boilerplate generated.
func.yaml created.
```



Now switch to the newly created function directory and run `npm install`:
```bash
$ cd ts-sdk-rp-demo-fn && npm install
```



Oh, we'll also need the `oci-sdk`, so install that too:
```bash
$ npm install oci-sdk
```



Now we can start creating our function. As I covered above, normally we would have to rely on something like a ConfigFileAuthenticationDetailsProvider by using code similar to the snippet below:
```text
const configurationFilePath = "~/.oci/config";
const configProfile = "DEFAULT";
const provider = new common.ConfigFileAuthenticationDetailsProvider(
    configurationFilePath,
    configProfile
);
```



This would require us to include our OCI config file in the Docker image, which means we'd have to include a manual `Dockerfile` in our function. And already we're getting complicated! Let's keep it simple.
```javascript
const provider = common.ResourcePrincipalAuthenticationDetailsProvider.builder();
```



That's much better! No config file dependency, no plain text credentials, no manual `Dockerfile`. The entire function illustrates just how easy it is to use resource principal auth with the TS/JS SDK:
```javascript
const fdk = require('@fnproject/fdk');
const os = require("oci-objectstorage");
const common = require("oci-common");

fdk.handle(async function(input){
    const provider = common.ResourcePrincipalAuthenticationDetailsProvider.builder();

    const client = new os.ObjectStorageClient({
        authenticationDetailsProvider: provider
    });
    client.region = common.Region.US_PHOENIX_1;

    console.log("Getting the namespace...");
    const request = {};
    const response = await client.getNamespace(request);
    return {namespace: response.value}
}, null)
```



Deploy the function:
```bash
$ fn deploy --verbose --app ts-sdk-app
```



And invoke it:
```bash
$ fn invoke ts-sdk-app ts-sdk-rp-demo-fn
```



Which properly returns the namespace:

    

## Working With Instance Principals

Let's take this very basic demo and use instance principal authentication instead. You can certainly turn up a VM to try this out, but I think it would be much easier to run it directly in Cloud Shell since it has Node and NPM installed already and we don't have to make any other changes to try it out. Open Cloud Shell, create a directory, switch to it, run npm init and then install the `oci-sdk`:
```bash
$ cd /tmp && mkdir -p ip-demo && cd /tmp/ip-demo && npm init -y && npm install
$ npm install oci-sdk
```



Now open up a file called `index.js` in your preferred text editor and enter the following:
```javascript
const os = require("oci-objectstorage");
const common = require("oci-common");
(async () => {
    const provider = await new common.InstancePrincipalsAuthenticationDetailsProviderBuilder().build();
    const client = new os.ObjectStorageClient({
        authenticationDetailsProvider: provider
    });
    client.region = common.Region.US_PHOENIX_1;
    console.log("Getting the namespace...");
    const request = {};
    const response = await client.getNamespace(request);
    console.log(response);
})();
```



This code is very similar to the serverless example above, but note the use of `InstancePrincipalsAuthenticationDetailsProviderBuilder` instead of `ResourcePrincipalAuthenticationDetailsProvider`. Save it, and run it to see the expected output:
```bash
$ node index.js 
Getting the namespace...
{ value: ‘idff...i9a' }
```



## Summary

In this post, we looked in depth at instance and resource principals. We learned why they exist and demonstrated a simple use case of each authentication type. If you have any questions, leave a comment below or, as always, connect on Twitter [\@recursivecodes](https://twitter.com/recursivecodes).

Photo by [chris panas](https://unsplash.com/@chrispanas?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
