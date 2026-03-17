---
title: "Adventures in CI/CD [#5]: Deploying A Microservice To The Oracle Cloud With GitHub Actions [Gradle Plugin Edition]"
slug: "adventures-in-cicd-5-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-gradle-plugin-edition"
author: "Todd Sharp"
date: 2020-05-04
summary: "In this post, we'll revisit our microservice deployment and see how we can accomplish the same goal by using the OCI Gradle plugin."
tags: ["Cloud", "Containers, Microservices, APIs", "Integration", "Open Source"]
keywords: "git, Cloud, Continuous Integration, Java, microservices"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f8f63384-522c-4eb5-890b-28a8e60a6f3a/banner_dylan_mcleod_4zqvu9dyvsk_unsplash.jpg"
---

We've made it to post number five in this series, and I have to say that I'm having more fun than I should be allowed to have playing around with CI/CD and deploying microservices to the Oracle Cloud. I have learned a ton putting this series together and I truly hope you are enjoying it and finding it useful. To recap, here's what we've done so far:

- [Adventures In CI/CD \[#1\]: Intro & Getting Started With GitHub Actions](/posts/adventures-in-cicd-1-intro-getting-started-with-github-actions)
- [Adventures in CI/CD \[#2\]: Building & Publishing A JAR](/posts/adventures-in-cicd-2-building-publishing-a-jar)
- [Adventures in CI/CD \[#3\]: Running Tests & Publishing Test Reports](/posts/adventures-in-cicd-3-running-tests-publishing-test-reports)
- [Adventures in CI/CD \[#4\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[OCI CLI Edition\]](/posts/adventures-in-cicd-4-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-oci-cli-edition)

For brevity and to prevent repeating myself I will assume you have at least read the last post in this series so if you have not yet done so, please do that before continuing. In that last post we used the OCI CLI to create our instance but this time we're going to switch our application to use the [OCI Java SDK Gradle plugin](http://kordamp.org/oci-gradle-plugin) by my esteemed colleague [Andres Almiray](https://blogs.oracle.com/author/e475065c-7c0f-4efc-98f4-7d6d0212138d). You'll need many of the secrets from the previous post created in your repo, so if you haven't created them yet then you might want to do that now.

## Configure Gradle

First we will need to add the OCI Gradle plugin to our `build.gradle` file in the `plugins` block:
```groovy
id 'org.kordamp.gradle.base' version '0.33.0'
id 'org.kordamp.gradle.oci' version '0.4.0'
```



Since the plugin utilizes the OCI Java SDK which depends on `javax.activation` we'll need to add a `buildscript` dependency:
```groovy
buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath 'com.sun.activation:jakarta.activation:1.2.2'
    }
}
```



Next, we'll register a new task in our build that we can later invoke from our build pipeline. We'll pass in the necessary variables from the pipeline, so register the task like so in your `build.gradle`:
```groovy
/* default project properties to keep intellij from annoying me with warnings */
if(! hasProperty("publicKeyFile")){
    ext.publicKeyFile=""
}
if(! hasProperty("userDataFile")){
    ext.userDataFile=""
}
def step01 = tasks.register('step01', org.kordamp.gradle.plugin.oci.tasks.instance.SetupInstanceTask) {
    verbose       = true
    image         = 'java-11-custom-image'
    shape         = 'VM.Standard2.1'
    publicKeyFile = file("${project.publicKeyFile}")
    userDataFile  = file("${project.userDataFile}")
}
```



This task will utilize the [SetupInstanceTask](http://kordamp.org/oci-gradle-plugin/#setupInstance) method of the plugin and as I said above we will be able to pass additional variables in when we execute the task later on. Let's move to our workflow YAML file and remove the references to the OCI CLI that we added in the last post in this series. Remove the following:
```yaml
- name: 'Install OCI CLI'
  run: |
    curl -L -O https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
    chmod +x install.sh
    ./install.sh --accept-all-defaults
    echo "::add-path::/home/runner/bin"
    exec -l $SHELL
- name: 'Fix Config File Permissions'
  run: |
    oci setup repair-file-permissions --file /home/runner/.oci/config
    oci setup repair-file-permissions --file /home/runner/.oci/key.pem
- name: 'Check Existing Instance'
  run: |
    echo "::set-env name=INSTANCE_OCID::$( \
      oci compute instance list \
      --lifecycle-state RUNNING \
      --compartment-id ${{secrets.VM_COMPARTMENT_OCID}} \
      --display-name cicd-demo \
      --query "data [0].id" \
      --raw-output \
    )"
- name: 'Create Instance'
  if: ${{!env.INSTANCE_OCID}}
  run: |
    echo "::set-env name=INSTANCE_OCID::$( \
      oci compute instance launch \
        --compartment-id ${{secrets.VM_COMPARTMENT_OCID}} \
        --availability-domain ${{secrets.VM_AVAILABILITY_DOMAIN}} \
        --shape ${{secrets.VM_SHAPE}} \
        --assign-public-ip true \
        --display-name cicd-demo \
        --image-id ${{secrets.VM_CUSTOM_IMAGE_OCID}} \
        --ssh-authorized-keys-file /home/runner/.oci/id_vm.pub \
        --subnet-id ${{secrets.VM_SUBNET_OCID}} \
        --wait-for-state RUNNING \
        --query "data.id" \
        --raw-output \
    )"
- name: 'Get Instance IP'
  run: |
    echo "::set-env name=INSTANCE_IP::$( \
      oci compute instance list-vnics \
      --instance-id ${{env.INSTANCE_OCID}} \
      --query 'data [0]."public-ip"' \
      --raw-output \
    )"
```



We'll still need our OCI config file as it will be used for authentication by the Gradle plugin, so leave that step in and add another command at the end of it to create a blank cloud-init file. We won't populate it for now, but if you wanted to further customize your newly launched instance you could certainly populate this shell script (or have a version checked in to your GitHub repo that you could copy over).
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
    touch /home/runner/cloud-init.sh
```



Now let's add a step to use Gradle to invoke the task that we registered above. Note that the create instance task will also create all of the necessary VCN infrastructure to support the instance.
```yaml
- name: 'Create Instance'
  run: |
    ./gradlew --stacktrace step01 \
      -Doci.compartment.id=${{secrets.VM_COMPARTMENT_OCID}} \
      -Doci.instance.name=cicddemo2 \
      -PpublicKeyFile=/home/runner/.oci/id_vm.pub
      -PuserDataFile=/home/runner/cloud-init.sh
```



This step will complete successfully regardless of whether or not the instance exists beforehand so we don't have to worry about checking that our instance already exists before we invoke it. It will also write out a properties file containing relevant data about the instance that we can use to get information like our instance's public IP so we've eliminated yet another call to the CLI/SDK. That said, let's add a step to our workflow to read the properties file and retrieve the instance IP as well as the security list ID so we can add an ingress rule for the app that our microservice runs on.
```yaml
- name: 'Get Instance IP'
  run: |
    more build/oci/instance/cicdgradle.properties
    function prop {
     grep "${1}" build/oci/instance/cicdgradle.properties|cut -d'=' -f2
    }
    export SEC_LIST_ID=$(prop 'vcn.security-list.id')
    export IP=$(prop 'instance.public-ip.0')
    echo "::set-env name=SECURITY_LIST_ID::$SEC_LIST_ID"
    echo "::set-env name=INSTANCE_IP::$IP"
```



Now we can add the ingress rule using the `addIngressSecurityRule` task that the OCI Gradle plugin provides.
```yaml
- name: 'Add Ingress Rule'
  run: |
    ./gradlew addIngressSecurityRule \
      --destination-port=8080 \
      --security-list-id=${{env.SECURITY_LIST_ID}}
```



From here on out the build continues as it did in the previous post. We can stop the app, push the JAR and start the app with the following steps:
```yaml
- name: 'Stop App'
  uses: appleboy/ssh-action@master
  with:
    host: ${{ env.INSTANCE_IP }}
    username: opc
    key: ${{ secrets.VM_SSH_PRIVATE_KEY }}
    script: |
      pid=`ps aux | grep "[c]icd-demo.jar" | awk '{print $2}'`
      if [ "$pid" == "" ]; then
        echo "Process not found"
      else
        kill -9 $pid
      fi
      sudo mkdir -p /app
- name: 'Push JAR'
  uses: appleboy/scp-action@master
  with:
    host: ${{ env.INSTANCE_IP }}
    username: opc
    key: ${{ secrets.VM_SSH_PRIVATE_KEY }}
    source: "build/libs/cicd-demo-${{env.VERSION}}-all.jar"
    target: "app"
    strip_components: 2
- name: 'Start App'
  uses: appleboy/ssh-action@master
  with:
    host: ${{ env.INSTANCE_IP }}
    username: opc
    key: ${{ secrets.VM_SSH_PRIVATE_KEY }}
    script: |
      sudo mv ~/app/cicd-demo-${{env.VERSION}}-all.jar /app/cicd-demo.jar
      nohup java -jar /app/cicd-demo.jar > output.$(date --iso).log 2>&1 &
```



Once we commit and push our refactored build we can observe the workflow execution in GitHub Actions:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f8f63384-522c-4eb5-890b-28a8e60a6f3a/upload_1587146759643.png)

And we can confirm the application has been deployed on the new instance:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f8f63384-522c-4eb5-890b-28a8e60a6f3a/upload_1587146759650.png)

## TL;DR

In this post, we refactored our microservice deployment to utilize the OCI Gradle Plugin to create our instance instead of using the OCI CLI. This presents an alternative option if you prefer to use Gradle but accomplishes the same end goal - deploying our microservice application on a VM in the Oracle Cloud.

## Next

I know it feels like we have covered a whole lot of content so far in this series, but trust me when I say we're only about halfway done with what I plan on covering. Next up we're going to spend a few posts going into some more "advanced" topics. The first thing we'll look at is adding some database interactions to our microservice because a simple "hello, world" can only teach us so much. And since working with the database involves schema changes, we'll also look at database migrations in a future post. There is lots more to come even after those topics, so stick around and thank you for reading!

## Source Code

For this post can be found at <https://github.com/recursivecodes/cicd-demo/tree/part-5>

Photo by [Dylan McLeod](https://unsplash.com/@dillby777?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/ship?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
