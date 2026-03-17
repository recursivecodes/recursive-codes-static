---
title: "Deploying A Micronaut Microservice To The Cloud"
slug: "deploying-a-micronaut-microservice-to-the-cloud"
author: "Todd Sharp"
date: 2019-04-23
summary: "Get started with deploying your first Micronaut application to the Oracle Cloud in less than 30 minutes. "
tags: ["Cloud", "Developers", "Java", "Open Source"]
keywords: "Java, Cloud, microservices, deployment"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/banner_2019_04_23_10_05_59.jpg"
---

So you've finally done it. You created a shiny new microservice. You've written tests that pass, ran it locally and everything works great. Now it's time to deploy and you're ready to jump to the cloud. That may seem intimidating, but honestly there's no need to worry. Deploying your Micronaut application to the Oracle Cloud is really quite easy and there are several options to chose from. In this post I'll show you a few of those options and by the time you're done reading it you'll be ready to get your app up and running.

If you haven't yet created an application, feel free to check out my last post and use that code to [create a simple app that uses GORM to interact with an Oracle ATP instance](/posts/creating-a-microservice-with-micronaut-gorm-and-oracle-atp).  Once you've created your Micronaut application you'll need to create a runnable JAR file. For this blog post I'll assume you followed my blog post and any assets that I refer to will reflect that assumption. With Micronaut creating a runnable JAR is as easy as using `./gradlew assemble` or `./mvnw package` (depending on which build automation tool your project uses). Creating the artifact will take a bit longer than you're probably used to if you haven't used Micronaut before. That's because Micronaut precompiles all necessary metadata for Dependency Injection so that it can minimize/reduce runtime reflection to obtain that metadata. Once your task completes you will have a runnable JAR file in the `build/libs` directory of your project. You can launch your application locally by running `java -jar /path/to/your.jar`. So to launch the JAR created from the previous blog post, I set some environment variables and run:
```bash
java -jar \                                                                                                                                                                    ✹master
-Doracle.net.tns_admin="/wallet" \
-Djavax.net.ssl.trustStore="/wallet/truststore.jks" \
-Djavax.net.ssl.trustStorePassword=${TRUSTSTORE_PASSWORD} \
-Djavax.net.ssl.keyStore="/wallet/keystore.jks" \
-Djavax.net.ssl.keyStorePassword=${KEYSTORE_PASSWORD} \
-Doracle.net.ssl_server_dn_match=true \
-Doracle.net.ssl_version="1.2" \
-DdataSource.username=${ORACLE_USERNAME} \
-DdataSource.password=${ORACLE_PASSWORD} \
-DdataSource.url=${DB_URL} \
-XX:+UnlockExperimentalVMOptions \
-XX:+UseCGroupMemoryLimitForHeap \
-Dcom.sun.management.jmxremote \
-noverify \
build/libs/micronaut-atp-demo-0.1.jar
```



Which results in the application running locally:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_30_33.jpg)

So far, pretty easy. But we want to do more than launch a JAR file locally. We want to run it in the cloud, so let's see what that takes. The first method I want to look at is more of a "traditional" approach: launching a simple compute instance and deploying the JAR file.

### Creating A Virtual Network

If this is your first time creating a compute instance you'll need to set up virtual networking.  If you have a network ready to go, skip down to "Creating An Instance" below. 

Your instance needs to be associated with a virtual network in the Oracle Cloud. Virtual cloud networks (hereafter referred to as VCNs) can be pretty complicated, but as a developer you need to know enough about them to make sure that your app is secure and accessible from the internet. To get started creating a VCN, either click "Create a virtual cloud network" from the dashboard:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_41_02.jpg)

Or select "Networking" -\> "Virtual Cloud Networks" from the sidebar menu and then click "Create Virtual Cloud Network" on the VCN overview page:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_43_11.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_43_41.jpg)

In the "Create Virtual Cloud Network" dialog, populate a name and choose the option "Create Virtual Cloud Network Plus Related Resources" and click "Create Virtual Cloud Network" at the bottom of the dialog:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_47_44.jpg)

The "related resources" here refers to the necessary Internet Gateways, Route Table, Subnets and related Security Lists for the network. The security list by default will allow SSH, but not much else, so we'll edit that once the VCN is created.  When everything is complete, you'll receive confirmation:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_48_55.jpg)

Close the dialog and back on the VCN overview page, click on the name of the new VCN to view details:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_49_58.jpg)

On the details page for the VCN, choose a subnet and click on the Security List to view it:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_51_14.jpg)

On the Security List details page, click on "Edit All Rules":

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_53_16.jpg)

And add a new rule that will expose port 8080 (the port that our Micronaut application will run on) to the internet:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_56_02.jpg)

Make sure to save the rules and close out. This VCN is now ready to be associated with an instance running our Micronaut application.

### Creating An Instance

To get started with an Oracle Cloud compute instance log in to the cloud dashboard and either select "Create a VM instance":

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_33_23.jpg)

Or choose "Compute" -\> "Instances" from the sidebar and click "Create Instance" on the Instance overview page:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_34_00.jpg)

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_36_54.jpg)

In the "Create Instance" dialog you'll need to populate a few values and make some selections. It seems like a long form, but there aren't many changes necessary from the default values for our simple use case. The first part of the form requires us to name the instance, select an Availability Domain, OS and instance type:

 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_58_37.jpg)

The next section asks for the instance shape and boot volume configuration, both of which I leave as the default. At this point I select a public key that I can use later on to SSH in to the machine:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_59_16.jpg)

Finally, select the a VCN that is internet accessible with port 8080 open:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_09_59_52.jpg)

Click "Create" and you'll be taken to the instance details page where you'll notice the instance in a "Provisioning" state.  Once the instance has been provisioned, take note of the public IP address:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_10_05_59.jpg)

### Deploying Your Application To The New Instance

Using the instance public IP address, SSH in via the private key associated with the public key used to create the instance:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_10_07_30.jpg)

We're almost ready to deploy our application, we just need a few things.  First, we need a JDK.  I like to use [SDKMAN](https://sdkman.io/install) for that, so I first install SDKMAN, then use it to install the JDK with `sdk install java 8.0.212-zulu` and confirm the installation:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_10_46_23.jpg)

We'll also need to open port 8080 on the instance firewall so that our instance will allow the traffic:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_10_17_42.jpg)

We can now upload our instance with SCP:
```bash
$ scp -i ~/.ssh/id_oci_demo -r ~/Projects/scratch/micronaut/demo/build/libs/micronaut-atp-demo-0.1.jar opc@129.146.XXX.XXX:
$ scp -i ~/.ssh/id_oci_demo -r ~/Projects/scratch/micronaut/demo/*.sh opc@129.146.XXX.XXX:
$ scp -i ~/.ssh/id_oci_demo -r /wallet opc@129.146.XXX.XXX:
```



I've copied the JAR file, my Oracle ATP wallet and 2 simple scripts to help me out. The first script sets some environment variables:
```bash
export TRUSTSTORE_PASSWORD=[password]
export KEYSTORE_PASSWORD=[password]
export ORACLE_PASSWORD=[password]
export ORACLE_USERNAME=[user]
export DB_URL=jdbc:oracle:thin:@barnevents_low?TNS_ADMIN=/wallet
```



The second script is what we'll use to launch the application:
```bash
java -jar \                                                                                                                                                                    ✹master
-Doracle.net.tns_admin="/wallet" \
-Djavax.net.ssl.trustStore="/wallet/truststore.jks" \
-Djavax.net.ssl.trustStorePassword=${TRUSTSTORE_PASSWORD} \
-Djavax.net.ssl.keyStore="/wallet/keystore.jks" \
-Djavax.net.ssl.keyStorePassword=${KEYSTORE_PASSWORD} \
-Doracle.net.ssl_server_dn_match=true \
-Doracle.net.ssl_version="1.2" \
-DdataSource.username=${ORACLE_USERNAME} \
-DdataSource.password=${ORACLE_PASSWORD} \
-DdataSource.url=${DB_URL} \
-XX:+UnlockExperimentalVMOptions \
-XX:+UseCGroupMemoryLimitForHeap \
-Dcom.sun.management.jmxremote \
-noverify \
micronaut-atp-demo-0.1.jar
```



Next, move the wallet directory from the user home directory to the root with `sudo mv wallet/ /wallet` and source the environment variables with ` . ./env.sh`. Now run the application with `./run.sh`:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_10_49_55.jpg)

And hit the public IP in your browser to confirm the app is running and returning data as expected!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b6d8393b-75e8-4381-96c7-a0b593ff9ee1/2019_04_23_10_49_04.jpg)

You've just deployed your Micronaut application to the Oracle Cloud! Of course, a manual VM install is just one method for deployment and isn't very maintainable long term for many applications, so in future posts we'll look at some other options for deploying that fit in the modern application development cycle.
