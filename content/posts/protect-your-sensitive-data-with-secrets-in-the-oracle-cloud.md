---
title: "Protect Your Sensitive Data With Secrets In The Oracle Cloud"
slug: "protect-your-sensitive-data-with-secrets-in-the-oracle-cloud"
author: "Todd Sharp"
date: 2020-04-01
summary: "In this post, we'll look at how to create a secret in the Oracle Cloud that can be used to store sensitive data for your serverless functions and applications."
tags: ["Cloud", "Containers, Microservices, APIs", "Java"]
keywords: "Cloud, Cloud Security, keystore"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/banner_ben_white_4bs9ksdjsdc_unsplash.jpg"
---

<div>

It's no secret that every developer should be aware of the need to protect sensitive information such as passwords and API keys when building and deploying applications in the cloud.  One of the steps that you should always take to protect these sensitive items is to make sure they are stored in an encrypted manner and are only able to be decrypted by the function or application that uses them. Today we make that task much easier with the launch of Secrets as part of our current Key Management offering on the Oracle Cloud. In this post, I'll show you how to get started creating your first secret.

</div>

<div>

Here is a general overview of the steps we'll take in this post:

</div>

- Create Policy
- Create A Vault\*
- Create A Key\*
- Create Secret(s)
- Create A Serverless Function That Retrieves & Decrypts The Secret

\*If Necessary

<div>

Let's jump right into it!

</div>

## Create Policy

<div>

In order to work with secrets, you'll need a user that is in a group that has the following policies:

</div>

<div>
```bash
allow group faas-group to manage secret-family in tenancy
allow group faas-group to manage vaults in tenancy
allow group faas-group to manage keys in tenancy
```



</div>

<div>

You'll also need to apply the following service level policies:

</div>

<div>
```bash
allow service VaultSecret to use vaults in tenancy
allow service VaultSecret to use keys in tenancy
```



</div>

## Create Vault

<div>

The next step is to create a vault if you don't have one already created. From the burger menu, select 'Security' -\> 'Key Management'. On the vault list page, click 'Create Vault'.

</div>

<div>

 

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306866.png)

</div>

<div>

In the 'Create Vault' dialog, name your vault. If necessary, check 'Make It A Virtual Private Vault' (click 'Learn more' if you need to understand more about virtual private. Vaults).  Next, click create.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306873.png)

</div>

<div>

Your vault will initially be in a 'Creating' state.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306879.png)

</div>

<div>

As soon as it is 'Active' you can view the vault details.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306882.png)

</div>

## Create Key

<div>

Now we'll need to create a Key that will be used to encrypt our secrets. On the vault details page, click 'Keys' in the sidebar menu and then click 'Create Key'.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306886.png)

</div>

<div>

In the 'Create Key' dialog, name your key and choose the key shape algorithm and length.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306890.png)

</div>

<div>

Once your key is in an 'Active' state, move on to creating your secret(s).

</div>

## Create Secret

<div>

Next, click 'Secrets' in the sidebar and click 'Create Secret'.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306893.png)

</div>

<div>

Name your secret, enter a description, and choose the encryption key. At this point, you have two choices. You can enter your key as plain text and have the console base64 encode it for you, or you can choose base64 and enter an encoded value for your secret. For this demo, choose 'Plain Text' and enter 'hunter2' as the secret contents.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306896.png)

</div>

<div>

If you prefer working with the CLI, you can also create your secrets via the OCI CLI.  You'll need the OCID of your vault, key and compartment to do so. Here's an example of creating a secret in a vault encrypted by my demo-key containing the base64 encoded string "hunter2":

</div>

<div>
```bash
$ oci vault secret create-base64 \
        --compartment-id ocid1.compartment.oc1... \
        --secret-name TEST_1 \
        --vault-id ocid1.vault.oc1... \
        --key-id ocid1.key.oc1... \
        --region us-phoenix-1 \
        --secret-content-content aHVudGVyMg==
```



Once your secret has been created, copy the OCID of the secret and keep it handy for later.

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306900.png)

</div>

## Create A Serverless Function That Retrieves & Decrypts The Secret

<div>

Now let's create a serverless application and function that will retrieve our password.

</div>

<div>

**Note**! This could be a regular microservice using Java or any language that the OCI SDK supports.

Create the serverless application:
```bash
$ fn create app kms-secret-demo-app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1...”]’
```



</div>

<div>

Next, create the function. If you're new to serverless functions on the Oracle Cloud, check out the following videos:

</div>

- [Getting Your Tenancy Ready For Serverless On The Oracle Cloud](https://www.youtube.com/watch?v=9hu1L7ptuog)
- [Creating Your First Serverless Function On The Oracle Cloud](https://www.youtube.com/watch?v=LCDDH4q6TsA)

<div>

Create your function:
```bash
$ fn init --runtime java kms-secret-demo-fn
```



Set the secret OCID into the configuration:

</div>

<div>
```bash
$ fn config app kms-secret-demo-app SECRET_ID ocid1.vaultsecret.oc1.phx..
```



We'll need to use the OCI SDK, so add the following dependencies:
```xml
<dependency>
    <groupId>com.oracle.oci.sdk</groupId>
    <artifactId>oci-java-sdk-vault</artifactId>
    <version>1.15.3</version>
</dependency>
<dependency>
    <groupId>com.oracle.oci.sdk</groupId>
    <artifactId>oci-java-sdk-secrets</artifactId>
    <version>1.15.3</version>
</dependency>
<dependency>
    <groupId>com.oracle.oci.sdk</groupId>
    <artifactId>oci-java-sdk-common</artifactId>
    <version>1.15.3</version>
</dependency>
```



If you're using anything above Java 8, don't forget the following dependency.
```xml
<dependency>
    <groupId>com.sun.activation</groupId>
    <artifactId>jakarta.activation</artifactId>
    <version>1.2.1</version>
</dependency>
```



<div>

We're going to use Resource Principal authentication in our function to work with the secret service, so make sure that you have a dynamic group and the proper policies in place. To do this, first create a dynamic group. I like to include all resources within a specific compartment in my dynamic group, so the definition would look like so:
```bash
ALL{resource.type='fnfunc', resource.compartment.id='ocid1.compartment.xxxxx'}
```



Next, give the proper policies to the dynamic group (you can apply this at the tenancy or compartment level):
```bash
allow dynamic-group functions-dynamic-group to read secret-family in tenancy
```



Now let's move on to the function handler. I've renamed my package and class here to be more appropriate. The first thing that we'll need to do is declare some variables for use in our class. We'll need the `secretId` and a `secretsClient`. If you're running the app locally, be sure to set an environment variable.

</div>

<div>
```java
private final String secretId = System.getenv("SECRET_ID");
private SecretsClient secretsClient;
```



</div>

<div>

Next, let's add a constructor and initialize the `provider` and `secretsClient`. We'll use a `ResourcePrincipalAuthenticationDetailsProvider` if we're running  on the Oracle Cloud, otherwise we'll use a `ConfigFileAuthenticationDetailsProvider` when running locally.

</div>

<div>
```java
public SecretDemo() {
    String version = System.getenv("OCI_RESOURCE_PRINCIPAL_VERSION");
    BasicAuthenticationDetailsProvider provider = null;
    if( version != null ) {
        provider = ResourcePrincipalAuthenticationDetailsProvider.builder().build();
    }
    else {
      try {
            provider = new ConfigFileAuthenticationDetailsProvider("~/.oci/config", "DEFAULT");
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }
    secretsClient = new SecretsClient(provider);
    secretsClient.setRegion(Region.US_PHOENIX_1);
}
```



</div>

<div>

Now we'll create a function that can be used to retrieve our decrypted password value that we created earlier and decode it.

</div>
```java
private String getSecretValue(String secretOcid) throws IOException {

    // create get secret bundle request
    GetSecretBundleRequest getSecretBundleRequest = GetSecretBundleRequest
            .builder()
            .secretId(secretOcid)
            .stage(GetSecretBundleRequest.Stage.Current)
            .build();

    // get the secret
    GetSecretBundleResponse getSecretBundleResponse = secretsClient.
            getSecretBundle(getSecretBundleRequest);

    // get the bundle content details
    Base64SecretBundleContentDetails base64SecretBundleContentDetails =
            (Base64SecretBundleContentDetails) getSecretBundleResponse.
                    getSecretBundle().getSecretBundleContent();

    // decode the encoded secret
    byte[] secretValueDecoded = Base64.decodeBase64(base64SecretBundleContentDetails.getContent());
    return new String(secretValueDecoded);
}
```



Finally, create the `handleRequest()` method that is invoked when our function is called. We'll return the decoded and decrypted fake password here for demo purposes, but certainly you'd never do this in a real application, right?  RIGHT??

<div>
```java
public String  handleRequest() throws IOException {
    return getSecretValue(secretId);
}
```



</div>

<div>

How about a test to make sure everything is working as we'd expect?
```java
@Test
public void shouldReturnDecodedSecret() {
    testing.givenEvent().enqueue();
    testing.thenRun(SecretDemo.class, "handleRequest");
    FnResult result = testing.getOnlyResult();
    assertEquals("hunter2", result.getBodyAsString());
}
```



Which quickly passes!

</div>

<div>

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/37adcd2f-061d-4ece-8060-da79479b3b95/upload_1585746306905.png)

</div>

<div>

Now comment out the test contents (since the test depends on external variables that will cause the Docker build to fail):

</div>
```java
@Test
public void shouldReturnDecodedSecret() {    
  /*    
  testing.givenEvent().enqueue();    
  testing.thenRun(SecretDemo.class, "handleRequest");    
  FnResult result = testing.getOnlyResult();    
  assertEquals("hunter2", result.getBodyAsString());    
  */
}
```



Deploy the function.
```bash
$ fn deploy --app kms-secret-demo-app
```



<div>

And invoke it.

</div>
```bash
$ fn invoke kms-secret-demo-app kms-secret-demo-fnhunter2
```



## Summary

<div>

I hope you can see just how easy it is to work with secrets on the Oracle Cloud. In my next post, I will show you how to take secrets to the next step and use them to store and retrieve your Autonomous DB wallet files for use in your functions and applications!

</div>

<div>

View the [source for this blog post on GitHub](http://github.com/recursivecodes/kms-secret-demo-fn).

Photo by [Ben White](https://unsplash.com/@benwhitephotography?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/secret?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

</div>

</div>
