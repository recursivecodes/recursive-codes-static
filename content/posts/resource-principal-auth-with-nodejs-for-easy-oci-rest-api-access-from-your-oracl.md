---
title: "Resource Principal Auth With Node.JS For Easy OCI REST API Access From Your Oracle Functions"
slug: "resource-principal-auth-with-nodejs-for-easy-oci-rest-api-access-from-your-oracle-functions"
author: "Todd Sharp"
date: 2020-05-25
summary: "In this post, we'll look at using Resource Principal authentication to interact with the OCI REST APIs with Node.JS"
tags: ["Cloud", "JavaScript"]
keywords: "serverless, node.js, OCI, API"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/23e3b1d0-3643-42ac-bc93-2f7967607017/banner_aleks_marinkovic_nsb50df_ml0_unsplash.jpg"
---

The first rule of serverless is to keep your functions light and simple. Part of keeping a function light is avoiding unnecessary external dependencies such as SDKs. But what happens when you need to communicate with an external service or perform some other task that would normally require a dependency on the Oracle Cloud Infrastructure (OCI) SDK? Or, what happens when there isn't an SDK option available for you at the moment (as is currently the case with Node.JS)? Luckily, there's another option: the [OCI REST APIs](https://docs.cloud.oracle.com/en-us/iaas/api/). Just about anything that you can do with any of our SDKs can be done via the OCI REST APIs and as an added bonus, you don't need to include too much extra weight to your functions to get it done. 

Normally, you'd use your OCI credentials to [sign your requests to the OCI REST endpoints](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm). I'll admit, it can be a tricky process at first, but once you get comfortable with it you'll find it rather easy to do. However, in the case of a serverless function, there is not an easy way to get your credentials into the function environment (Docker container) so we're left looking at other options. That's why our brilliant engineers have given us the ability to use Resource Principal (RP) authentication and have added support to most of our SDKs for RP auth. See [the docs for how to configure RP auth for your functions](https://docs.cloud.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm), but the basic premise is that you need to create a dynamic group and assign the appropriate IAM policies to that dynamic group. Once that's done, the function can utilize RP auth via the normal SDKs. 

**But Wait! **Didn't you just say above that we're trying to keep our function light and avoid including an SDK? How can we use Resource Principal authentication if we're using the REST endpoints and not an SDK?

That's a fantastic question! The answer is: we'll manually sign our requests to the REST endpoints with our Resource Principal credentials instead of including our own credentials in the function. The process is outlined below and it's based heavily on the [Node.JS request signing example in our documentation](https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm#NodeJS). Let's Get Started!

## Create Serverless Application

New to serverless on the Oracle Cloud? These two videos will help you get started: [Serverless On Oracle Cloud Getting Your Tenancy Configured For Oracle Functions](https://www.youtube.com/watch?v=9hu1L7ptuog) & [Creating Your First Serverless Function On The Oracle Cloud](https://www.youtube.com/watch?v=LCDDH4q6TsA).

First, create your serverless application. You can do this via the OCI Console Dashboard, or via the CLI:
```bash
$ fn create app rp-demo-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx..."]'
```



## Create Function

Next, create a function:
```bash
$ fn init --runtime node rp-demo-fn
```



## Add Dependencies

We're not **completely** dependency-free here, but we're close. Add two small packages:
```bash
$ npm install http-signature jssha
```



## Populate Function

Here's where the good stuff happens. Our scaffolded function is a basic "hello world", so let's modify it to make a request to the OCI REST API for Object Storage to return a list of buckets in a compartment. We'll pass a few arguments into the function in a JSON object, so add a single argument to the function to accommodate:
```javascript
fdk.handle( function(requestDetails) {} )
```



When RP auth is enabled for a function, there will be a series of environment variables available from within the function. We're concerned with two of those variables to help us sign our request, the first of which is `OCI_RESOURCE_PRINCIPAL_RPST` which contains the path on the machine to a file containing the Remote Principal Session Token (RPST). This is token is formatted as a JWT and contains claims that identify the tenancy and compartment that the function resides within. We'll ultimately parse the RPST to retrieve those claims and use the RPST to sign the request later on, but for now, just read the token into a variable:
```javascript
const sessionTokenFilePath = process.env.OCI_RESOURCE_PRINCIPAL_RPST
const rpst = fs.readFileSync(sessionTokenFilePath, {encoding: 'utf8'})
```



Next, parse the claims from the token and grab and store the tenancy ID:
```javascript
const payload = rpst.split('.')[1]
const buff = Buffer.from(payload, 'base64')
const payloadDecoded = buff.toString('ascii')
const claims = JSON.parse(payloadDecoded)
/* get tenancy id from claims */
const tenancyId = claims.res_tenant
```



The other environment variable we are concerned with is called `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM` and it contains the path to a private key that we'll also use to sign our request. Grab the path and read the file:
```javascript
/* get the RP private key */
const privateKeyPath = process.env.OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM
const privateKey = fs.readFileSync(privateKeyPath, 'ascii')
```



To sign the request, we need to construct a "`keyId`". We need to format it in a certain manner so the OCI endpoint recognizes that we're using a session token containing the RPST.
```javascript
/*
*  set the keyId used to sign the request
*  the format here is the literal string 'ST$'
*  followed by the entire contents of the RPST
*/
const keyId = `ST$${rpst}`​​​​​​​
```



Now, the `sign()` method that has been modified from the documentation mentioned above. The difference here is that we're using the formatted RPST as our keyId and using the provided private key.
```javascript
/*
*  a function used to sign the request
*  based mostly on
*  https://docs.cloud.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm#NodeJS
*/
function sign(request, options) {
  const headersToSign = [
    "host",
    "date",
    "(request-target)"
  ];
  const methodsThatRequireExtraHeaders = ["POST", "PUT"];
  if (methodsThatRequireExtraHeaders.indexOf(request.method.toUpperCase()) !== -1) {
    options.body = options.body || "";
    const shaObj = new jsSHA("SHA-256", "TEXT");
    shaObj.update(options.body);
    request.setHeader("Content-Length", options.body.length);
    request.setHeader("x-content-sha256", shaObj.getHash('B64'));
    headersToSign = headersToSign.concat([
      "content-type",
      "content-length",
      "x-content-sha256"
    ]);
  }
  httpSignature.sign(request, {
    key: options.privateKey,
    keyId: keyId,
    headers: headersToSign
  });
  const newAuthHeaderValue = request.getHeader("Authorization").replace("Signature ", "Signature version="1",");
  request.setHeader("Authorization", newAuthHeaderValue);
}
```



Finally, we can return a Promise that contains our signed HTTPS request to the Object Storage endpoint.
```javascript
/* return a promise that contains the REST API call */
return new Promise((resolve, reject) => {
  /* the domain/path for the REST endpoint */
  const requestOptions = {
    host: 'objectstorage.us-phoenix-1.oraclecloud.com',
    path: `/n/${encodeURIComponent(requestDetails.namespace)}/b/?compartmentId=${encodeURIComponent(requestDetails.compartmentId)}`,
  };
  /* the request itself */
  const request = https.request(requestOptions, (res) => {
    let data = ''
    res.on('data', (chunk) => {
      data += chunk
    });
    res.on('end', () => {
      resolve(JSON.parse(data))
    });
    res.on('error', (e) => {
      console.error(e)
      reject(JSON.parse(e))
    });
  })
  /* sign the request using the private key, tenancy id and the keyId (see above) */
  sign(request, {
    privateKey: privateKey,
    tenancyId: tenancyId,
    keyId: keyId,
  })
  request.end()
})
​​​​​
```



## Deploy The Function

Pretty easy, just do:
```bash
$ fn deploy --verbose --app rp-demo-app
```



## Invoke The Function

We'll use the `fn` CLI to invoke it and pass the expected JSON object in:
```bash
echo '{"namespace": "[your object storage namespace]", "compartmentId": "ocid1.compartment.oc1..."}' | fn invoke rp-demo-app rp-demo-fn | jq
```



And we'll get back the array of objects containing our Object Storage buckets!
```json
[
 {
  "namespace": "toddrsharp",
  "name": "test",
  "compartmentId": "ocid1.compartment.oc1...",
  "createdBy": "ocid1.saml2idp.oc1...",
  "timeCreated": "2018-11-08T16:45:27.456Z",
  "etag": "53ad7ee5-a855-471b-9c08-2eea5096e20c",
  "freeformTags": null,
  "definedTags": null
 },
 {
  "namespace": "toddrsharp",
  "name": "custom-images",
  "compartmentId": "ocid1.compartment.oc1...",
  "createdBy": "ocid1.saml2idp.oc1...",
  "timeCreated": "2019-10-24T17:52:47.425Z",
  "etag": "00c17467-2ac3-4257-aef0-a619aa4cab2b",
  "freeformTags": null,
  "definedTags": null
 }
]
```



## Summary

We kept our function light and called an OCI REST endpoint to get the data we needed in a simple manner. 

**Need More?** The full source for this blog post is available, as always, on GitHub at: <https://github.com/recursivecodes/rp-demo-fn>

Photo by [Aleks Marinkovic](https://unsplash.com/@baronmarinkovic?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

## 
