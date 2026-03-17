---
title: "Adventures in CI/CD [#9]: Deploying A Microservice As A Docker Container"
slug: "adventures-in-cicd-9:-deploying-a-microservice-as-a-docker-container"
author: "Todd Sharp"
date: 2020-05-18
summary: "In this post, we'll deploy our microservice as a Docker container and store the Docker image in OCIR."
tags: ["Cloud", "Containers, Microservices, APIs", "Integration", "Java", "Open Source"]
keywords: "container, Continuous Integration, Cloud, microservices, DB"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d59426f7-45cf-479b-8a32-8f710c3b0c69/banner_walter_sturn__qc_plqigag_unsplash.jpg"
---

Welcome to the penultimate post in this continuous journey about continuous integration and continuous deployment. So far in this blog series, we have gone over a copious amount of topics related to building and automated testing and deploying of a microservice using many popular tools in the Java and open-source ecosystem. Here's what we have covered so far.

- [Adventures In CI/CD \[#1\]: Intro & Getting Started With GitHub Actions](/posts/adventures-in-cicd-1-intro-getting-started-with-github-actions)
- [Adventures in CI/CD \[#2\]: Building & Publishing A JAR](/posts/adventures-in-cicd-2-building-publishing-a-jar)
- [Adventures in CI/CD \[#3\]: Running Tests & Publishing Test Reports](/posts/adventures-in-cicd-3-running-tests-publishing-test-reports)
- [Adventures in CI/CD \[#4\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[OCI CLI Edition\]](/posts/adventures-in-cicd-4-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-oci-cli-edition)
- [Adventures in CI/CD \[#5\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[Gradle Plugin Edition\]](/posts/adventures-in-cicd-5-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-gradle-plugin-edition)
- [Adventures in CI/CD \[#6\]: Adding A Persistence Tier To Our Microservice](/posts/adventures-in-cicd-6-adding-a-persistence-tier-to-our-microservice)
- [Adventures in CI/CD \[#7\]: Testing The Persistence Tier With Testcontainers](/posts/adventures-in-cicd-7-testing-the-persistence-tier-with-testcontainers)
- [Adventures in CI/CD \[#8\]: Deploying A Microservice With A Tested Persistence Tier In Place](/posts/adventures-in-cicd-8-deploying-a-microservice-with-a-tested-persistence-tier-in-place)

Honestly, there is not much left to talk about as it relates to the basics of continuous integration and deployment of microservices. There is however one more topic that we would be remiss to not mention and that is building and deploying our microservice as a Docker container onto a Kubernetes Cluster. It's not terribly complicated to do this, but we'll break this last topic up into two separate blog posts. In this post, we'll focus on building our Docker container.

### The Dockerfile

If you've followed along with this series, you may or may not have noticed that way back in part one when we generated our Micronaut application there was a file named `Dockerfile` created in the root of the project. Let's open that up and take a look at it. It should look very similar to this (unless you've used a different name for your project):
```text
FROM adoptopenjdk/openjdk11-openj9:jdk-11.0.1.13-alpine-slim
COPY build/libs/cicd-demo-*-all.jar cicd-demo.jar
EXPOSE 8080
CMD java -Dcom.sun.management.jmxremote -noverify ${JAVA_OPTS} -jar cicd-demo.jar
```



### Preparing To Build The Docker Image

We're going to need a Docker Registry to store our Docker images. You can use Docker Hub if you'd like, but a great option for hosting Docker Images in the Oracle Cloud is the Oracle Cloud Infrastructure Registry (OCIR). If you have not yet configured OCIR for your tenancy, do so now before we move forward.

**Tip**!  Check out [The Complete Guide To Getting Up And Running With Docker And Kubernetes On The Oracle Cloud](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud) for help getting prepared for Docker & Kubernetes! 

### Building The Docker Image

If we were to have built and run this `Dockerfile` way back before we added our dependencies it would have worked just fine. But since our DB connection requires a wallet for our Autonomous DB connection we'd have a problem if we tried to run it right now. Let's make one simple modification to it to `COPY` in our wallet directory.
```text
FROM adoptopenjdk/openjdk11-openj9:jdk-11.0.1.13-alpine-slim
COPY build/libs/cicd-demo-*-all.jar cicd-demo.jar
COPY wallet /wallet
EXPOSE 8080
CMD java -Dcom.sun.management.jmxremote -noverify ${JAVA_OPTS} -jar cicd-demo.jar
```



This will copy the wallet contents from the root of our project into our Docker container. You can drop your wallet into the root of the project and give it a shot.

Note: Do not check your wallet into version control. Make sure you add an entry to your `.gitignore` file to prevent accidental check-in!

To build our image, first make sure your JAR file is built locally with `./gradlew assemble` and then run:
```bash
$ docker build -t phx.ocir.io/[your repo]/cicd-demo/cicd-demo:latest .
```



### Running The Docker Build Locally

To test it out locally, export your configuration variables:
```bash
$ export DATASOURCE_URL=jdbc:oracle:thin:@192.168.86.26:1521/XEPDB1
$ export DATASOURCE_USERNAME=system   
$ export DATASOURCE_PASSWORD=Str0ngPa$$word 
$ export MICRONAUT_ENVIRONMENTS=dev
```



Take note of the URL above - you must use a local IP address instead of 'localhost' inside the Docker container!

Run it with:
```bash
$ docker run \
    --env MICRONAUT_ENVIRONMENTS \
    --env DATASOURCE_URL \
    --env DATASOURCE_USERNAME \
    --env DATASOURCE_PASSWORD \
    -p 8080:8080 \
    phx.ocir.io/toddrsharp/cicd-demo/cicd-demo:latest
```



### Modifying The Build

Now that we've changed our `Dockerfile` and tested that it builds properly, we need to modify our GitHub Actions workflow to automate these tasks and then push the resulting Docker image to our OCIR repo. The first step is to modify to write out our Wallet to disk in the runner VM so when we run our Docker build it can be copied in. If you've followed along with this series, you should already have secrets in your GitHub repo for the wallet files, so modify the step we added before to write our configuration files to also write our wallet files to the runner's workspace directory:
```yaml
- name: 'Write Config & Key Files'
  run: |
    mkdir ~/.oci
    echo "[DEFAULT]" >> ~/.oci/config
    echo "user=${{secrets.OCI_USER_OCID}}" >> ~/.oci/config
    echo "fingerprint=${{secrets.OCI_FINGERPRINT}}" >> ~/.oci/config
    echo "pass_phrase=${{secrets.OCI_PASSPHRASE}}" >> ~/.oci/config
    echo "region=${{secrets.OCI_REGION}}" >> ~/.oci/config
    echo "tenancy=${{secrets.OCI_TENANCY_OCID}}" >> ~/.oci/config
    echo "key_file=~/.oci/key.pem" >> ~/.oci/config
    echo "${{secrets.OCI_KEY_FILE}}" >> ~/.oci/key.pem
    echo "${{secrets.VM_SSH_PUB_KEY}}" >> /home/runner/.oci/id_vm.pub
    sudo mkdir /home/runner/work/cicd-demo/cicd-demo/wallet
    sudo sh -c  'echo "${{secrets.WALLET_CWALLET}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/cwallet.sso'
    sudo sh -c  'echo "${{secrets.WALLET_EWALLET}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/ewallet.p12'
    sudo sh -c  'echo "${{secrets.WALLET_KEYSTORE}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/keystore.jks'
    sudo sh -c  'echo "${{secrets.WALLET_OJDBC}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/ojdbc.properties'
    sudo sh -c  'echo "${{secrets.WALLET_SQLNET}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/sqlnet.ora'
    sudo sh -c  'echo "${{secrets.WALLET_TNSNAMES}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/tnsnames.ora'
    sudo sh -c  'echo "${{secrets.WALLET_TRUSTSTORE}}" | base64 -d >> /home/runner/work/cicd-demo/cicd-demo/wallet/truststore.jks'
```



Next create two more secrets in GitHub, one for our `OCIR_USERNAME` (in the tenancy/username format) and one for the token called `OCIR_PASSWORD`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d59426f7-45cf-479b-8a32-8f710c3b0c69/upload_1587152358043.png)

**Hint**: If you don't have a need for anything related to deploying to a VM and would only like to deploy to Docker, you can remove all of the previous steps related to that deployment now.

Next, add a step to login to OCIR. This step will use the `actions-hub/docker/login@master` action to perform the login. Substitute your appropriate URL if you are not using the PHX region!
```yaml
- name: 'Login To OCIR'
  uses: actions-hub/docker/login@master
  env:
    DOCKER_USERNAME: ${{ secrets.OCIR_USERNAME }}
    DOCKER_PASSWORD: ${{ secrets.OCIR_PASSWORD }}
    DOCKER_REGISTRY_URL: phx.ocir.io
```



Now let's do the same docker build command that we tested locally from our pipeline:
```yaml
- name: 'Docker Build'
  run: docker build -t phx.ocir.io/toddrsharp/cicd-demo/cicd-demo:latest .
```



And finally, push that image to OCIR:
```yaml
- name: 'Docker Push'
  uses: actions-hub/docker@master
  with:
    args: push phx.ocir.io/toddrsharp/cicd-demo/cicd-demo:latest
```



Observe your build on GitHub and it should complete successfully:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d59426f7-45cf-479b-8a32-8f710c3b0c69/upload_1587152358053.png)

And we can confirm this by checking our OCIR registry:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/d59426f7-45cf-479b-8a32-8f710c3b0c69/upload_1587152358063.png)

## TL;DR

In this post, we modified our GitHub Actions workflow to build a Docker image that contains our microservice and pushed that image to our OCIR registry.

## Next

In the next post, we'll deploy our microservice Docker image to a Kubernetes cluster in the Oracle Cloud.

## Source Code

For this post can be found at <https://github.com/recursivecodes/cicd-demo/tree/part-9>

Photo by [Walter Sturn](https://unsplash.com/@walter46?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/cloud-mountain?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
