---
title: "OCI SDK For TypeScript Is Now Available - Here's How To Use It In Your JavaScript Projects"
slug: "oci-sdk-for-typescript-is-now-available-heres-how-to-use-it"
author: "Todd Sharp"
date: 2020-06-04
summary: "In this post, we'll look at the brand new OCI SDK for TypeScript and how to use it to manage your OCI resources and interact with various services."
tags: ["Cloud", "JavaScript"]
keywords: "Javascript, node.js, OCI, API, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7c1f02ac-abd5-4dd1-9715-ab1d32dc79db/banner_jaclyn_clark_ieqpwqvnr1e_unsplash.jpg"
---

I have blogged quite a bit about our OCI Java SDK in the past. It's easy to use and a very intuitive and consistent SDK that can perform just about any possible task you can imagine when it comes to the Oracle Cloud. But I'm not just a Java developer. I use JavaScript quite a bit too on both the client and the server-side. In fact, when it comes to simple "one-off" scripts, let's be honest it is usually much quicker and easier to throw it together in JS than in Java. That's why I'm so happy to hear that our OCI SDK for TypeScript has been made generally available.

**Note: **Even though it's called the SDK for TypeScript, it can be used in any "vanilla" JavaScript project or TypeScript project on the server.

In this post I'm going to show you some examples of using the TypeScript SDK, but first let me share a few important links that you will want to bookmark if you'll be doing any work with it.

## Important Links

::: intro
- [Official TypeScript SDK Docs](https://docs.cloud.oracle.com/en-us/iaas/Content/API/SDKDocs/typescriptsdk.htm)
- [oci-typescript-sdk on GitHub](https://github.com/oracle/oci-typescript-sdk) (it's open source, file a PR today!)
- [Examples](https://github.com/oracle/oci-typescript-sdk/tree/master/examples) (available for both JavaScript and TypeScript)
- [oci-sdk](https://www.npmjs.com/package/oci-sdk) on NPM

## Using The SDK With JavaScript On The Server

The TypeScript SDK can easily be used in a "vanilla" Node.JS application. To get started, check the examples linked above or create a simple Node project and install the SDK with: 

    npm install oci-sdk

Now pull in some dependencies. In this example, we'll use the Object Storage and the Core modules (see the [full list of services supported](https://docs.cloud.oracle.com/en-us/iaas/Content/API/SDKDocs/typescriptsdk.htm#ServicesSupported)) so we'll need to pull in `oci-objectstorage` and `oci-core` to make calls with the necessary clients. We'll also need `oci-common` and we'll pull in `util` to prettify our output later on.
```javascript
const objectstorage = require('oci-objectstorage')
const core = require('oci-core')
const common = require('oci-common');
const util = require('util');
```



Next, set a few variables to sore our configuration file details and our compartmentId and tenancyName:
```javascript
const configurationFilePath = "~/.oci/config";
const configProfile = "DEFAULT";
const compartmentId = 'ocid1.compartment.oc1...';
const tenancyName = '[my tenancy]';
```



We'll need to create an instance of an authentication provider that we'll have to pass to the clients when we construct them. For this, we'll use a [ConfigFileAuthenticationDetailsProvider](https://docs.cloud.oracle.com/en-us/iaas/tools/typescript/1.0.2/classes/_common_lib_auth_config_file_auth_.configfileauthenticationdetailsprovider.html) from the `oci-common` module.
```javascript
const authProvider = new common.ConfigFileAuthenticationDetailsProvider(
  configurationFilePath,
  configProfile
);
```



Now we can create an instance of the [ComputeClient](https://docs.cloud.oracle.com/en-us/iaas/tools/typescript/1.0.2/classes/_core_lib_client_.computeclient.html), passing our `authProvider`:
```javascript
const coreClient = new core.ComputeClient({  authenticationDetailsProvider: authProvider});
coreClient.region = common.Region.US_PHOENIX_1;
```



Now we can construct a `listInstancesRequest` and call `listInstances` on the client. Since we're using plain JavaScript, the `listInstancesRequest` will just be a simple object containing keys relating to the expected parameters. The call to the client will return a `Promise`, so we can get our results in the `then()` method, collect our instance ID and display name, and log those values.
```javascript
const listInstancesRequest = {
  compartmentId: compartmentId,
};
coreClient.listInstances(listInstancesRequest)
  .then((result) => {
    const ids = result.items.map((i) =>{
      return {
        id: i.id,
        name: i.displayName,
      }
    });
    console.log(ids);
  })
  .catch((e) => {
    console.error(e);
  });
```



If we save and run this script, we'll get output similar to the following:
```json
[
  {
    "id": "ocid1.instance.oc1.phx...",
    "name": "instance-20191202-0932"
  },
  {
    "id": "ocid1.instance.oc1.phx...",
    "name": "instance-20200113-0852"
  }
]
```



The object storage module follows the same patterns, so it's simple to construct an `objectStorageClient` and perform operations like `listBuckets` and `listObjects`.
```javascript
const objectStorageClient = 
      new objectstorage.ObjectStorageClient({
        authenticationDetailsProvider: authProvider
      });
objectStorageClient.region = common.Region.US_PHOENIX_1;
const listObjectsRequest = {
  namespaceName: tenancyName,
  bucketName: 'barn-captures',
  compartmentId: compartmentId,
};
objectStorageClient.listObjects(listObjectsRequest)
  .then((result) => {
    console.log(util.inspect(result, false, null, true));
  })
  .catch((e) => {
    console.error(e);
  });
const listBucketsRequest = {
  namespaceName: tenancyName,
  compartmentId: compartmentId,
};
objectStorageClient.listBuckets(listBucketsRequest)
  .then((result) => {
    console.log(util.inspect(result, false, null, true));
  })
  .catch((e) => {
    console.log(e);
  });
```



If Promises aren't your thing, you can use async/await:
```javascript
(async () => {
  const req = {};
  const ns = await objectStorageClient.getNamespace(req);
  console.log(ns)
})();
```



## Using The SDK With TypeScript On The Server

Another option with the TypeScript SDK is to use it directly with TypeScript scripts. This gives you the added benefit of explicitly typed objects which means your IDE will provide you with plenty of insight into the SDK. Here's an example of using a TypeScript file to grab the namespace from the object storage client. It looks mostly the same, but note the addition of the types for the provider, client, request and response objects.
```typescript
import os = require("oci-objectstorage");
import common = require("oci-common");
const configurationFilePath = "~/.oci/config";
const configProfile = "DEFAULT";

const authProvider: common.ConfigFileAuthenticationDetailsProvider = 
      new common.ConfigFileAuthenticationDetailsProvider(
        configurationFilePath,
        configProfile
      );
const objectStorageClient: os.ObjectStorageClient = 
      new os.ObjectStorageClient({
        authenticationDetailsProvider: authProvider
      });
objectStorageClient.region = common.Region.US_PHOENIX_1;
(async () => {
  const req: os.requests.GetNamespaceRequest = {};
  const ns: os.responses.GetNamespaceResponse = await objectStorageClient.getNamespace(req);
  console.log(ns)
})()
```



## Summary

In this post, we looked at the brand new TypeScript SDK for OCI. We learned how to construct authentication providers, module clients, and requests and how to send those requests to the OCI API via the client instances. If you have any questions or feedback, please leave a comment below or refer to the documentation or GitHub links above. Otherwise, get started integrating this into your Node projects today!

Photo by [Jaclyn Clark](https://unsplash.com/@jaclynclark?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
