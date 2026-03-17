---
title: "Oracle Cloud Vault as a Secure, Distributed Config Store for your Micronaut Applications"
slug: "oracle-cloud-vault-as-a-secure,-distributed-config-store-for-your-micronaut-applications"
author: "Todd Sharp"
date: 2020-05-06
summary: "In this post, I'll show you how to use an Oracle Cloud Vault as a secure, distributed config store with your Micronaut applications."
tags: ["Cloud", "Cloud Native", "Java"]
keywords: "microservices, secure, Cloud, Cloud Security, Java, container"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8c318ef1-d71d-4253-b66f-d2dc8eea49d5/banner_kristina_flour_bcjdbykwquw_unsplash.jpg"
---

Micronaut is a hugely popular framework in the Java world and it continues to grow in features and adoption. Recently, version 2.0.0.M3 was [released](https://objectcomputing.com/news/2020/04/30/micronaut-20-m3-big-boost-serverless-and-micronaut-launch) which included a number of features, but of note to readers of this blog and users of Oracle Cloud is a feature that I recently contributed which adds support for using Oracle Cloud Vaults as encrypted distributed config stores for your Micronaut applications. This means that you can safely and securely store your configuration variables in your vault and with just a bit of configuration those values are made available in your microservice or serverless application. 

**Hey There! **If you're new to working with secrets and vaults in the Oracle Cloud, here's a perfect guide to getting started: [Protect Your Sensitive Data With Secrets In The Oracle Cloud](null/p/protect-your-sensitive-data-with-secrets-in-the-oracle-cloud). Don't worry, I know the author of that guide. He's pretty cool!

## Dependencies

To get started with this feature, add a few dependencies to your project:
```groovy
implementation("io.micronaut:micronaut-discovery-client")
implementation("io.micronaut.oraclecloud:micronaut-oraclecloud-vault")
implementation("com.oracle.oci.sdk:oci-java-sdk-vault:2.10.0")
implementation("com.oracle.oci.sdk:oci-java-sdk-secrets:2.10.0")
implementation("com.oracle.oci.sdk:oci-java-sdk-common:2.10.0")
```



## Configuration

Next, you'll need to configure your application. For distributed configurations, you'll need to create a `bootstrap.yaml` file in `src/main/resources`.

You're able to supply as many vault IDs as you'd like to your configuration. Each vault will be retrieved and all of the secrets in the vault will be set to a configuration variable in your application using the same name as the vault key. This means that if you have a secret named `FOO` in vault "A" then a config var will be created named `FOO` in your application. Keep in mind, that if you have another secret named `FOO` in vault "B" then the variable created from vault "A" will be overwritten. 

Here's an example configuration file:
```yaml
micronaut:
  application:
    name: vault-test
  config-client:
    enabled: true
oraclecloud:
  vault:
    config:
      enabled: true
    vaults:
      - ocid: ocid1.vault.oc1.phx...
        compartment-ocid: ocid1.compartment.oc1...
    use-instance-principal: false
    path-to-config: ~/.oci/config
    profile: DEFAULT
    region: US-PHOENIX-1
```



Refer to the docs for [details about each configuration property](https://docs.micronaut.io/2.0.0.M3/guide/index.html#io.micronaut.discovery.oraclecloud.vault.config.OracleCloudVaultClientConfiguration), but note that this feature supports either config file-based authentication or instance principal auth. Instance principal authentication is a really easy method to use when deploying your application to the Oracle Cloud.

## Accessing Configuration Variables

You're now ready to go! You can access the config vars in a few different ways. If you create a secret with the name of `SECRET_ONE` in your Oracle Cloud Vault, then it will be available to use in your application like any standard configuration variable:
```java
@Value("${SECRET_ONE}") String secretOne
```



You can also use `@PropertyName`:
```java
@Property(name = "SECRET_ONE") String secretOne
```



Another option is to inject your variables in

Vault retrieved values are always `String`, but you can use `@ConfigurationProperties` on a bean in conjunction with your `application.yml` file to provide properly typed configuration variables.

So if you were to create secrets in your Oracle Cloud Vault like so:

  Name           Value
  -------------- -----------
  SECRET_ONE     Value One
  SECRET_TWO     value two
  SECRET_THREE   true
  SECRET_FOUR    42
  SECRET_FIVE    3.16

And then added the following to your `application.yml` file:
```yaml
secrets:
  one: ${SECRET_ONE}
  two: ${SECRET_TWO}
  three: ${SECRET_THREE}
  four: ${SECRET_FOUR}
  five: ${SECRET_FIVE}
```



You could add a config bean, like so:
```java
@ConfigurationProperties("secrets")
public class Config {
    private String one;
    private String two;
    private boolean three;
    private int four;
    private Double five;

    /* getters/setters removed for brevity */
}
```



You could then inject and use this bean in your application with properly typed values.
```java
@Controller("/hello")
public class HelloController {

    private Config config;

    public HelloController(
            Config config
    ) {
        this.config = config;
    }

    @Get("/")
    public HttpStatus index() {
        return HttpStatus.OK;
    }

    @Get("/secret")
    public HttpResponse getSecret() {
        return HttpResponse.ok(config);
    }
}
```



Calling the `/hello/secret` endpoint would return:
```json
{
  "one": "Value One",
  "two": "value two",
  "three": true,
  "four": 42,
  "five": 3.16
}
```



Another option is to inject your variables into your configuration files which gives you the ability to store things like database passwords and API keys in your vault:
```yaml
datasources:
  default:
    password: ${DB_PASSWORD}
```



This feature is fully documented in the [official framework docs](https://docs.micronaut.io/2.0.0.M3/guide/index.html#distributedConfigurationOracleCloudVault), so give it a shot today. Remember, you can create up to 5000 secrets in a vault absolutely free in your tenancy. This kind of data security is priceless, but when it costs you nothing you literally have no excuse not to keep your passwords, credentials, and API keys completely secure.

If you'd like to see a demo application that utilizes this feature, check out this project on GitHub: [recursivecodes/vault-test](https://github.com/recursivecodes/vault-test).

Photo by [Kristina Flour](https://unsplash.com/@tinaflour?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/secret?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
