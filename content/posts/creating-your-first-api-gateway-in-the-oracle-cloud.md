---
title: "Creating Your First API Gateway In The Oracle Cloud"
slug: "creating-your-first-api-gateway-in-the-oracle-cloud"
author: "Todd Sharp"
date: 2019-11-22
summary: "In this post, we'll look at getting started with the Oracle API Gateway including the necessary cloud networking configuration, creating and deploying a simple serverless function and creating a gateway and deployment to front that serverless function."
tags: ["Cloud", "Containers, Microservices, APIs"]
keywords: "API, APIs, Cloud, microservices, serverless, Gateway"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/banner_masaaki_komori__we0bqqewbo_unsplash.jpg"
---

Microservices and serverless are more popular than ever with teams around the globe adopting these patterns and architectures at an extremely high rate. However, the first thing that many teams find out when working with microservices and serverless at scale is that you soon end up with a pretty complex series of endpoints that need to be managed for your front end and mobile APIs. For that reason, many teams adopt an API Gateway to simplify the backend and act as a "single point of entry" for all clients. API Gateways also give you the ability to easily implement things like rate limiting, CORS and authentication in your architecture since you can address those at the gateway level instead of the individual function or service.

In this post we will take a look at one of the newest offerings in the Oracle Cloud - API Gateway.

We'll do the following things:

- [Create and deploy a "hello world" serverless function](#create-fn)
- [Create a subnet suitable for our API gateway](#create-subnet)
- [Create a dynamic group and apply the necessary policies for API gateway](#identity)
- [Create the gateway](#create-gw)
- [Deploy a spec to the gateway](#deploy)
- [Test the gateway](#test)

## Create and deploy a "hello world" serverless function 

I've blogged about Oracle Functions in the past: [Getting Started (Quickly)](/posts/oracle-functions:-serverless-on-oracle-cloud-developers-guide-to-getting-started-quickly). The [documentation is very helpful](https://docs.cloud.oracle.com/iaas/Content/Functions/Concepts/functionsoverview.htm) and there are [plenty of other resources available](https://www.oracle.com/cloud/cloud-native/functions/) to help you learn how to work with our hosted serverless option, so I won't go into how to set up your environment for serverless in this blog post. Please refer to those links if you need help and we'll move forward assuming you are familiar with Oracle Functions. 

Let's create a simple serverless application and function and then deploy that function. The contents of this function don't matter at this time, we're just going to use the function to test out our gateway later on so we'll leave the "hello world" in the scaffolded function as is. The runtime doesn't matter much either here - it can be anything that is supported by Oracle Functions and the [Fn Project](https://fnproject.io/).

fn create app gw-hello-world-app \--annotation oracle.com/oci/subnetIds='\["ocid1.subnet.oc1.phx\..."\]'\
Successfully created app:  gw-hello-world-app
```text
$ fn create app gw-hello-world-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx..."]'
Successfully created app:  gw-hello-world-app

$ fn init --runtime node gw-hello-world-fn
Creating function at: /gw-hello-world-fn
Function boilerplate generated.
func.yaml created.

$ cd gw-hello-world-fn

$ fn deploy --app gw-hello-world-app                                                                              
Deploying gw-hello-world-fn to app: gw-hello-world-app
Bumped to version 0.0.3
Building image phx.ocir.io/toddrsharp/faas/gw-hello-world-fn:0.0.3 .........
Parts:  [phx.ocir.io toddrsharp faas gw-hello-world-fn:0.0.3]
Pushing phx.ocir.io/toddrsharp/faas/gw-hello-world-fn:0.0.3 to docker registry...The push refers to repository [phx.ocir.io/toddrsharp/faas/gw-hello-world-fn]
643fe44f12a4: Pushed
b279f8214e6b: Pushed
0adc398bfc34: Pushed
0b3e54ee2e85: Pushed
ad77849d4540: Pushed
5bef08742407: Pushed
0.0.3: digest: sha256:e16e74ce194d85a9658177f7637484aded9764e981e395dfcbcac2d018687cac size: 1571
Updating function gw-hello-world-fn using image phx.ocir.io/toddrsharp/faas/gw-hello-world-fn:0.0.3...
Successfully created function: gw-hello-world-fn with phx.ocir.io/toddrsharp/faas/gw-hello-world-fn:0.0.3
```



We can invoke this function with the `fn` CLI at this point:
```bash
$ fn invoke gw-hello-world-app gw-hello-world-fn
{"message":"Hello World"}
```



But we can't invoke the function directly via HTTP(s) without signing the request or using the OCI SDK. Try inspecting the function to get the invoke endpoint:
```bash
$ fn inspect gw-hello-world-app gw-hello-world-fn
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/fn_inspect.jpg)

**Note**! Copy the `id` from the `fn inspect` call. This is the function OCID and we'll need it later!

Trying to invoke will end up returning a `401 Unauthorized`:
```bash
$ curl -i -X GET https://[redacted].us-phoenix-1.functions.oci.oraclecloud.com/20181201/functions/ocid1.fnfunc.oc1.phx..../actions/invoke
HTTP/1.1 401 Unauthorized
Date: Fri, 22 Nov 2019 14:24:33 GMT
Content-Type: application/json
Content-Length: 57
Connection: keep-alive
Opc-Request-Id: /01DT9R03K21BT1A2RZJ0005QSH/01DT9R03K21BT1A2RZJ0005QSJ
Www-Authenticate: Signature headers="date (request-target) host"

{"code":"NotAuthenticated","message":"Not authenticated"}
```



But once we put our serverless function behind our gateway we can invoke it via HTTPS. Let's move on!

## Create a subnet suitable for our API gateway 

We'll need a regional subnet for our API gateway that has an ingress rule for HTTPS traffic, so let's create one now within an existing VCN. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_create_subnet_1.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_create_subnet_2.jpg)

Now edit the chosen security list to add in ingress rule for port 443:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_ingress_rule.jpg)

All done. On to security\...

## Create a dynamic group and apply the necessary policies for API gateway 

The API gateway uses dynamic groups to manage access in your tenancy so we will need to create a new dynamic group and set some policies. We'll need the compartment OCID for the compartment that we're going to create our gateway within, so hit Identity -\> Compartments and copy the OCID that you are planning to use. Next, create a new dynamic group with the following definition (substituting the proper compartment OCID):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/api_gw_dg.jpg)

Now we'll need to create a policy that is specific to your tenancy and the newly created dynamic group. You'll need to substitute your own group name and compartment name as appropriate:
```text
allow dynamic-group [your dynamic group] to use functions-family in compartment [your compartment name]
```



For reference, here's how those statements look in my tenancy:
```text
allow dynamic-group api-gw-group to use functions-family in compartment faas-compartment
```



**Update**: You can now skip the dynamic group creation by changing your policy definition like so:
```bash
ALLOW any-user to use functions-family in compartment [your compartment name]
where 
ALL { request.principal.type= 'ApiGateway' , 
      request.resource.compartment.id = [your compartment ocid]
}
```



Now, let's create the gateway!

## Create the gateway 

To create the gateway, first select 'API Gateway' under 'Developer Services' in the sidebar menu:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_sidebar.jpg)

Click 'Create Gateway' and populate the dialog, making sure to choose the regional subnet that we created earlier.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/create_api_gw.jpg)

The gateway will initially be in a 'Creating' state.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_creating.jpg)

After a minute or so, the gateway will be 'Active'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_created_active.jpg)

## Deploy a spec to the gateway 

Before we can create a deployment we will need to craft a deployment spec file in JSON format to define our endpoints. Make sure you have the [function OCID from above handy](#function-ocid). Now, create a file called `spec.json` in the root of your function and populate it as follows (substitute your function OCID):
```json
{
 "routes": [
  {
   "path": "/hello",
   "methods": [
    "GET"
   ],
   "backend": {
    "type": "ORACLE_FUNCTIONS_BACKEND",
    "functionId": "ocid1.fnfunc.oc1.phx..."
   }
  }
 ]
}
```



There'll be a handy way to define your endpoints via console UI later on, but for now in the LA period we must define our endpoints via manual JSON.

Next, click 'Deployments' in the sidebar of the gateway details page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_sidebar_menu.jpg)

Then click 'Deploy API'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/deploy_api_btn.jpg)

Name the deployment, choose our `spec.json` that we created and enter a path prefix.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_deployment_dialog.jpg)

Click 'Deploy' and after a few moments your deployment is complete.

## Test the gateway 

On the gateway details page, take note of the endpoint.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1b08affb-951a-4d9e-90bf-8e139dfd4d9c/gw_endpoint.jpg)

To test your function, copy the endpoint and append the path that we defined in the `spec.json` file and give it a shot!
```bash
$ curl -i -X GET https://[redacted].apigateway.us-phoenix-1.oci.customer-oci.com/v1/hello
HTTP/1.1 200 OK
Date: Fri, 22 Nov 2019 15:04:11 GMT
Content-Type: application/json
Connection: keep-alive
Content-Length: 25
Server: Oracle API Gateway
Strict-Transport-Security: max-age=31536000
X-XSS-Protection: 1; mode=block
X-Frame-Options: sameorigin
X-Content-Type-Options: nosniff
opc-request-id: /429E9723BB6BED8DB8D237876894DDF6/3E4A5D8760D59242A98AB8A91E2B0107

{"message":"Hello World"}
```



This is just the beginning of what can be done with API Gateways. You can extend your deployment spec with additional functions, HTTP endpoints (on the Oracle Cloud or external), rate limiting, authentication and much more. 

Photo by [Masaaki Komori](https://unsplash.com/@gaspanik?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/gate?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
