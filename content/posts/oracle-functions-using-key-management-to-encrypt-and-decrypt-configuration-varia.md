---
title: "Oracle Functions: Using Key Management To Encrypt And Decrypt Configuration Variables"
slug: "oracle-functions-using-key-management-to-encrypt-and-decrypt-configuration-variables"
author: "Todd Sharp"
date: 2019-08-16
summary: "In this post, I'll show you how to use Oracle Key Management to encrypt and decrypt configuration values to keep your serverless Oracle Functions secure."
tags: ["Cloud", "Containers, Microservices, APIs", "Java"]
keywords: "serverless, encryption, Cloud, Cloud Security, Security"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3787ccf0-ceb3-41b8-bef8-fca2916c0eac/banner_silas_kohler_c1p4whhqbjm_unsplash.jpg"
---

I've covered quite a few different topics related to Oracle Functions recently on this blog, but today I'll cover what probably should have been the first post in this series. In my previous posts, I showed you how to set configuration variables for your applications and functions, but I have yet to show you how to keep those variables secure. In this post, we'll look at using Key Management in your Oracle Cloud tenancy to encrypt and decrypt your configuration to do just that. 

Since this process involves multiple steps, I thought it would be helpful to give you an outline of the steps that we're going to take:

- Create a KMS vault
- Create a Master Encryption Key
- Generate a Data Encryption Key (DEK) from the Master Encryption Key
- Use the DEK `plaintext` return value to encrypt the `sensitive value` (offline)
- Store the encrypted `sensitive value` as a config variable in the serverless application
- Store the DEK `ciphertext` and the `initVector` used to encrypt the `sensitive value` as Function config variables
- Within the function, decrypt the DEK `ciphertext` back into `plaintext` using the OCID and Cryptographic Endpoint by invoking the OCI KMS SDK
- Decrypt the `sensitive value` using the decrypted DEK `plaintext` and the `initVector`

The `sensitive value` referred to in the outline above can be anything that you need to be encrypted. Database passwords, API keys, etc - it doesn't matter what it is, it's just a placeholder that refers to any value that needs to be stored encrypted and not in plain text in an Oracle Function configuration variable.

I know it sounds like a lot of steps, but it's really not as hard as it might sound and these steps won't take you long to complete if you follow along. And, let's be honest, security is the most important thing when it comes to our applications and functions.

## Before We Get Started

We're going to utilize resource principals within our Oracle Function. This means that we won't have to include OCI configuration files to use the [OCI SDK](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/sdks.htm), but does require that we have created a dynamic group within the tenancy which has the proper policies to allow us to interact with the KMS API.

First, create a 'Dynamic Group' and set the 'rules' similarly to this (use the OCID of the compartment where you are deploying your functions):

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3787ccf0-ceb3-41b8-bef8-fca2916c0eac/2019_08_15_15_51_36.jpg)

You can read more about dynamic groups and [using Resource Principals with Oracle Functions](/posts/oracle-functions-connecting-to-atp-with-a-wallet-stored-as-secrets/) in the documentation. The next step is to create a policy for the dynamic group that allows the group to manage `keys`, `vaults` and `key-delegate` - again, refer to the [documentation on setting policies](https://docs.cloud.oracle.com/iaas/Content/Identity/Concepts/commonpolicies.htm#sec-admins-manage-vaults-keys) to make sure you fully understand the policies that you are applying.

## Create Application And Function

Now, create a serverless application (substitute a valid subnet OCID):

[`fn create app --annotation oracle.com/oci/subnetIds='["ocid1.subnet.oc1.phx..."]' fn-kms`]

And a function:

`fn init --runtime java fn-kms-demo`

## Dependencies

We'll need to add a dependency to the `pom.xml` file for the KMS SDK: 
```xml
<dependency>
    <groupId>com.oracle.oci.sdk</groupId>
    <artifactId>oci-java-sdk-keymanagement</artifactId>
    <version>1.6.0</version>
</dependency>
```



If you're using Java 11, manually include the `javax.activation-api`:
```xml
<dependency>
    <groupId>javax.activation</groupId>
    <artifactId>javax.activation-api</artifactId>
    <version>1.2.0</version>
</dependency>
```



## Dockerfile

We'll need to create our own `Dockerfile` because we're depending on environment variables. The only difference in this `Dockerfile` from what is executed by default when deploying a function is that we're skipping running our tests during the Docker build. We have to do this because there is currently no way to pass environment variables to the Docker build context when deploying our function. You can use the example below:
```text
FROM fnproject/fn-java-fdk-build:jdk11-1.0.98 as build-stage
WORKDIR /function
ENV MAVEN_OPTS -Dhttp.proxyHost= -Dhttp.proxyPort= -Dhttps.proxyHost= -Dhttps.proxyPort= -Dhttp.nonProxyHosts= -Dmaven.repo.local=/usr/share/maven/ref/repository

ADD pom.xml /function/pom.xml
RUN ["mvn", "package", "dependency:copy-dependencies", "-DincludeScope=runtime", "-DskipTests=true", "-Dmdep.prependGroupId=true", "-DoutputDirectory=target", "--fail-never"]

ADD src /function/src

RUN ["mvn", "package", "-DskipTests=true"]
FROM fnproject/fn-java-fdk:jre11-1.0.98
WORKDIR /function
COPY --from=build-stage /function/target/*.jar /function/app/

CMD ["codes.recursive.KmsDemoFunction::handleRequest"]
```



Be sure to manually run your tests before deploying your function!

## Create Vault And Master Encryption Key

In the OCI console sidebar, under 'Governance and Administration', select 'Security' → 'Key Management':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3787ccf0-ceb3-41b8-bef8-fca2916c0eac/2019_08_14_16_00_26.jpg)

Click on 'Create Vault' and enter the vault details:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3787ccf0-ceb3-41b8-bef8-fca2916c0eac/2019_08_14_15_43_50.jpg)

After the vault is created, click on the vault name to view the vault details. Within the vault details, click on 'Create Key' to create a new Master Encryption Key and populate the dialog:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/3787ccf0-ceb3-41b8-bef8-fca2916c0eac/2019_08_14_15_59_54.jpg)

Copy the OCID of the Master Encryption Key and the 'Cryptographic Endpoint' from the vault. We'll use this to create a Data Encryption Key (DEK) for our DB password.

## Create Data Encryption Key (DEK)

Create the Data Encryption Key (DEK) via the OCI CLI like so:
```bash
oci kms crypto generate-data-encryption-key \
--key-id ocid1.key.oc1.phx.... \
--include-plaintext-key true \
--key-shape "{"algorithm": "AES", "length": 16}" \
--endpoint [Cryptographic Endpoint]
```



Keep the `ciphertext` and `plaintext` values returned from the `generate-data-encryption-key` call handy, we'll need them in a minute.

Example DEK `ciphertext`:

`I...[random chars]...​AAAAAA==`

Store the ciphertext as a config var with the application:

`fn config app fn-kms DEK_CIPHERTEXT I...[random chars]...​AAAAAA==`

Example DEK `plaintext`:

`0…​[random chars]...=`

## Encrypt Password

In this step we're encrypting the password offline, not within the function. The function will decrypt the value later on when it's running. Encrypt the password using the DEK in a standalone Java program. Below is a sample that you could potentially use.

**Note**: Plug in your DEK `plaintext` value and choose a random 16 byte string for the `initVector`. We'll store the `initVector` as a config var so we can use it when decrypting later on.
```java
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.util.Base64;


class Main {
    private static String key = "0...=="; //DEK plaintext value
    private static String initVector = "abcdefghijklmnop"; //must be 16 bytes

    public static void main(String[] args) {
        System.out.println(encrypt("hunter2"));
    }

    public static String encrypt(String value) {
        try {
            IvParameterSpec iv = new IvParameterSpec(initVector.getBytes("UTF-8"));
            SecretKeySpec skeySpec = new SecretKeySpec(key.getBytes("UTF-8"), "AES");

            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5PADDING");
            cipher.init(Cipher.ENCRYPT_MODE, skeySpec, iv);

            byte[] encrypted = cipher.doFinal(value.getBytes());
            return Base64.getEncoder().encodeToString(encrypted);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
        return null;
    }
}
```



Store the random 16 byte `initVector` string as a config var with the application:

`fn config app fn-kms INIT_VECTOR_STRING [Random 16 byte string]`

Copy the output of the above program. This is our encrypted password. Set this as a config var in the application:

`fn config app fn-kms ENCRYPTED_PASSWORD N...==`

Finally, set the Master Encryption Key OCID and the Cryptographic Endpoint as config vars for the application:

`fn config app fn-kms KEY_OCID ocid1.key.oc1.phx...`\
`fn config app fn-kms ENDPOINT https://...-crypto.kms.us-phoenix-1.oraclecloud.com`

## Serverless Function

We can now modify our serverless function to decrypt the encrypted password. Here's what that looks like:
```java
package codes.recursive;

import com.oracle.bmc.auth.AbstractAuthenticationDetailsProvider;
import com.oracle.bmc.auth.ConfigFileAuthenticationDetailsProvider;
import com.oracle.bmc.auth.ResourcePrincipalAuthenticationDetailsProvider;
import com.oracle.bmc.keymanagement.KmsCryptoClient;
import com.oracle.bmc.keymanagement.model.DecryptDataDetails;
import com.oracle.bmc.keymanagement.requests.DecryptRequest;
import com.oracle.bmc.keymanagement.responses.DecryptResponse;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.util.Base64;
import java.util.Map;

public class KmsDemoFunction {

    private final String initVector;

    public KmsDemoFunction() {
        this.initVector = System.getenv().get("INIT_VECTOR_STRING");
    }

    public Map<String, String> decryptSensitiveValue() throws IOException {
        Boolean useResourcePrincipal = Boolean.valueOf(System.getenv().getOrDefault("USE_RESOURCE_PRINCIPAL", "true"));
        String encryptedPassword = System.getenv().get("ENCRYPTED_PASSWORD");
        String cipherTextDEK = System.getenv().get("DEK_CIPHERTEXT");
        String endpoint = System.getenv().get("ENDPOINT");
        String keyOcid = System.getenv().get("KEY_OCID");

        /*
        * when deployed, we can use a ResourcePrincipalAuthenticationDetailsProvider
        * for our the auth provider.
        * locally, we'll use a ConfigFileAuthenticationDetailsProvider
        */
        AbstractAuthenticationDetailsProvider provider = null;
        if( useResourcePrincipal ) {
            provider = ResourcePrincipalAuthenticationDetailsProvider.builder().build();
        }
        else {
            provider = new ConfigFileAuthenticationDetailsProvider("/.oci/config", "DEFAULT");
        }

        KmsCryptoClient cryptoClient = KmsCryptoClient.builder().endpoint(endpoint).build(provider);
        DecryptDataDetails decryptDataDetails = DecryptDataDetails.builder().keyId(keyOcid).ciphertext(cipherTextDEK).build();
        DecryptRequest decryptRequest = DecryptRequest.builder().decryptDataDetails(decryptDataDetails).build();
        DecryptResponse decryptResponse = cryptoClient.decrypt(decryptRequest);
        String decryptedDEK = decryptResponse.getDecryptedData().getPlaintext();

        String decryptedPassword = decrypt(encryptedPassword, decryptedDEK);

        /*
        * returning the decrypted password for demo
        * purposes only. in your production function,
        * obviously you should not do this.
        */
        return Map.of(
                "decryptedPassword",
                decryptedPassword
        );
    }

    private String decrypt(String encrypted, String key) {
        try {
            IvParameterSpec iv = new IvParameterSpec(initVector.getBytes("UTF-8"));
            SecretKeySpec skeySpec = new SecretKeySpec(key.getBytes("UTF-8"), "AES");

            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5PADDING");
            cipher.init(Cipher.DECRYPT_MODE, skeySpec, iv);
            byte[] original = cipher.doFinal(Base64.getDecoder().decode(encrypted));
            return new String(original);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
        return null;
    }
}
```



## Testing

As stated above, you'll need to manually test the function.

Before you can test this function locally, you'll seed to set some environment variables. See `env.sh` in the root of the GitHub project for the variables that need to be set (or copy from below). All of these values are obtained by following the steps above (note they all match up to the config vars you have already set for the application).
```bash
#!/usr/bin/env bash

export ENCRYPTED_PASSWORD=
export INIT_VECTOR_STRING=
export KEY_OCID=
export DEK_CIPHERTEXT=
export ENDPOINT=
export USE_RESOURCE_PRINCIPAL=false
```



After setting the necessary environment variables, write a unit test:
```java
package codes.recursive;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fnproject.fn.testing.*;
import org.junit.*;

import java.io.IOException;
import java.util.Map;

import static org.junit.Assert.*;

public class KmsDemoFunctionTest {

    @Rule
    public final FnTestingRule testing = FnTestingRule.createDefault();

    @Test
    public void shouldDecryptPassword() throws IOException {
        testing.givenEvent().enqueue();
        testing.thenRun(KmsDemoFunction.class, "decryptSensitiveValue");

        FnResult result = testing.getOnlyResult();
        System.out.println(result.getBodyAsString());
        Map<String, String> resultMap = new ObjectMapper().readValue(result.getBodyAsString(), Map.class);
        assertEquals("hunter2", resultMap.get("decryptedPassword"));
    }

}
```



## Deploying

To deploy the function, run:

`fn deploy --app fn-kms`

To invoke:

`fn invoke fn-kms fn-kms-demo`

Which will return the decrypted password:

``

## Summary

In this post, we used OCI KMS to create a vault and a Master Encryption Key. We used that Master Encryption Key to create a Data Encryption Key (DEK) and used that DEK to encrypt our sensitive value and then stored that encrypted sensitive value in our serverless function's configuration. Then we accessed the encrypted sensitive value from our deployed function and decrypted it so that it could be used in our function.

## Additional Reading

Feel free to check out my other posts on Oracle Functions:

- [Getting Started](/posts/oracle-functions:-serverless-on-oracle-cloud-developers-guide-to-getting-started-quickly)
- [Connecting A Serverless Function to Autonomous DB with Java](/posts/oracle-functions-connecting-to-an-atp-database)
- [Connecting A Serverless Function to Autonomous DB with Node.JS](/posts/oracle-functions-connecting-to-atp-with-nodejs)
- [Invoking A Serverless Function with OCI Java SDK](/posts/oracle-functions-invoking-functions-with-the-oci-sdk)
- [An Easier Way To Work With Autonomous DB](/posts/oracle-functions-an-easier-way-to-talk-to-your-autonomous-database)
- [Invoking Functions With Cloud Events](/posts/oracle-functions-invoking-functions-automatically-with-cloud-events)

The code used in this demo is available for your reference on GitHub at <https://github.com/recursivecodes/fn-kms-demo>.

[Photo by ][Silas Köhler](https://unsplash.com/@silas_crioco?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/key?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
