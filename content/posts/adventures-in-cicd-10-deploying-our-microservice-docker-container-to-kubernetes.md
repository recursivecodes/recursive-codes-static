---
title: "Adventures in CI/CD [#10]: Deploying Our Microservice Docker Container To Kubernetes"
slug: "adventures-in-cicd-10-deploying-our-microservice-docker-container-to-kubernetes"
author: "Todd Sharp"
date: 2020-05-22
summary: "In our final post in this epic series about CI/CD and the Oracle Cloud, we wrap things up by deploying our microservice Docker container to an OKE Kubernetes cluster."
tags: ["Cloud", "Containers, Microservices, APIs", "Integration", "Java", "Open Source"]
keywords: "Cloud, Kubernetes, Continuous Integration, Java, git"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2de8163e-174f-4466-b53b-bd822f96c304/banner_joshua_earle_ice__bo2vws_unsplash.jpg"
---

Welcome to the final entry in this series where we have taken a ground-up approach to build, test and deploy a microservice to the cloud in an automated manner. Here's what we have covered so far in this series:

- [Adventures In CI/CD \[#1\]: Intro & Getting Started With GitHub Actions](/posts/adventures-in-cicd-1-intro-getting-started-with-github-actions)
- [Adventures in CI/CD \[#2\]: Building & Publishing A JAR](/posts/adventures-in-cicd-2-building-publishing-a-jar)
- [Adventures in CI/CD \[#3\]: Running Tests & Publishing Test Reports](/posts/adventures-in-cicd-3-running-tests-publishing-test-reports)
- [Adventures in CI/CD \[#4\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[OCI CLI Edition\]](/posts/adventures-in-cicd-4-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-oci-cli-edition)
- [Adventures in CI/CD \[#5\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[Gradle Plugin Edition\]](/posts/adventures-in-cicd-5-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-gradle-plugin-edition)
- [Adventures in CI/CD \[#6\]: Adding A Persistence Tier To Our Microservice](/posts/adventures-in-cicd-6-adding-a-persistence-tier-to-our-microservice)
- [Adventures in CI/CD \[#7\]: Testing The Persistence Tier With Testcontainers](/posts/adventures-in-cicd-7-testing-the-persistence-tier-with-testcontainers)
- [Adventures in CI/CD \[#8\]: Deploying A Microservice With A Tested Persistence Tier In Place](/posts/adventures-in-cicd-8-deploying-a-microservice-with-a-tested-persistence-tier-in-place)
- [Adventures in CI/CD \[#9\]: Deploying A Microservice As A Docker Container](https://recursive.codes/blog/post/1422)

In this final post, we're going to deploy our Docker container that contains our microservice application to a Kubernetes cluster in the Oracle Cloud. It's not a complicated task, but it does have some noteworthy things to keep in mind, so let's dig in!

You probably already have a Kubernetes cluster configured in your cloud environment, but if not here are a few resources to help you get one up and running quickly.

**Tip!**  Check out [The Complete Guide To Getting Up And Running With Docker And Kubernetes On The Oracle Cloud](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud) for help getting prepared for Docker & Kubernetes! 

## Create A Service Account

Before we can use `kubectl` in our pipeline, we need to configure a service account on our Kubernetes cluster so that our GitHub Actions pipeline has the proper authority to issue commands to our cluster.  There is a [helpful guide in our online docs](https://docs.cloud.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengaddingserviceaccttoken.htm), but we'll walk through the steps needed to configure this below. We're going to create a service account that has a non-expiring token that can execute commands from the pipeline. 

### Step 1

Create the service account that uses the name `cicd-demo` and a cluster role binding for that service account.
```bash
$ kubectl -n kube-system create serviceaccount cicd-demo
$ kubectl create clusterrolebinding cicd-demo-binding --clusterrole=cluster-admin --serviceaccount=kube-system:cicd-demo
```



### Step 2

Grab the name of the token that was created for the service account, then get the token.
```bash
$ TOKENNAME=`kubectl -n kube-system get serviceaccount/cicd-demo -o jsonpath='{.secrets[0].name}'`
$ TOKEN=`kubectl -n kube-system get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`
```



### Step 3

On your local machine, add the service account and token to your local config file by executing.
```bash
$ kubectl config set-credentials cicd-demo --token=$TOKEN
```



### Step 4

**Note:** Do not skip this step, it is crucial!

Set the current context to be the service account user we created in step 1. You can change this later on, but it is important that this is done before step 5.
```bash
$ kubectl config set-context --current --user=cicd-demo
```



### Step 5

Export a `base64` representation of your local `kube config` and copy to your clipboard.
```bash
$ more ~/.kube/config | base64 | pbcopy
```



### Step 6

Create a GitHub secret containing the base64 representation of your config.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2de8163e-174f-4466-b53b-bd822f96c304/upload_1587153267093.png)

We can now start using the kubectl [GitHub Action](https://github.com/marketplace/actions/kubernetes-cli-kubectl) in our pipeline to work with our OKE cluster!

## Create Kubernetes Deployment Configuration

The first thing we're going to need to create is a deployment configuration for our microservice. This involves two things: an `app.yaml` to define our deployment and the associated service and a `secret` containing our DB password. If you've been following along with this series you know that we've already got that secret in our GitHub repository (we created it in part 8) so we just need to create our secret in our cluster from that value.

### Create A Secret

Let's add a step to our build to create the secret. We can do this directly via `kubectl` without writing a config file, so add a step to do that.
```yaml
- name: 'Create Password Secret'
  uses: steebchen/kubectl@master
  env:
    KUBE_CONFIG_DATA: ${{ secrets.OKE_KUBE_CONFIG }}
  with:
    args: "create secret generic cicd-demo-secrets --from-literal=dbPassword='${{secrets.OKE_DB_PASSWORD}}' --save-config --dry-run -o yaml | kubectl apply -f -"
```



### Create Deployment YAML

Next, create a file at `k8s/app.yaml` relative to your project root and populate it with the service and deployment definition. Make sure that the `image` value points to the proper location where your Docker image is being stored (see part 9). Notice that we're using an `imagePullPolicy` of `Always` which means regardless of your tag on your Docker image, Kubernetes will always pull a new version instead of using a locally cached image. If you're new to Kubernetes, make sure you [create a secret containing your registry credentials](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) and use that as your `imagePullSecrets` value.

Notice also the values we're passing as environment variables to the deployment. The URL and username for our DB connection are passed as literal strings and the password is pulled from the secret that we just created.
```yaml
kind: Service
apiVersion: v1
metadata:
  name: cicd-demo
  labels:
    app: cicd-demo
spec:
  type: LoadBalancer
  selector:
    app: cicd-demo
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: cicd-demo
  labels:
    app: cicd-demo
    version: v1
spec:
  selector:
    matchLabels:
      app: cicd-demo
  replicas: 1
  template:
    metadata:
      labels:
        app: cicd-demo
        version: v1
    spec:
      containers:
      - name: cicd-demo
        image: phx.ocir.io/toddrsharp/cicd-demo/cicd-demo:latest
        env:
        - name: DATASOURCE_URL
          value: jdbc:oracle:thin:@[TNS NAME]?TNS_ADMIN=/wallet
        - name: DATASOURCE_USERNAME
          value: [DB Username]
        - name: DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: cicd-demo-secrets
              key: dbPassword
        imagePullPolicy: Always
        ports:
          - containerPort: 8080
      imagePullSecrets:
        - name: regcred
---
```



### Add Deployment Step

Now let's add a step to our pipeline to perform the deployment.
```yaml
- name: 'Deploy To Kubernetes'
  uses: steebchen/kubectl@master
  env:
    KUBE_CONFIG_DATA: ${{ secrets.OKE_KUBE_CONFIG }}
  with:
    args: '"apply -f ./k8s/app.yaml"'
```



### Kill Existing Pod

Finally, add a step to grab the most recent Pod in this deployment and kill it. This will ensure that our deployment is running the latest and greatest Docker image that was pushed to OCIR during this build.
```yaml
- name: 'Kill Pod'
  uses: steebchen/kubectl@master
  env:
    KUBE_CONFIG_DATA: ${{ secrets.OKE_KUBE_CONFIG }}
  with:
    args: '"delete pod $(kubectl get pod -l app=cicd-demo -o jsonpath="{.items[0].metadata.name}")"'
```



## The Final Build

Once we commit and push our latest changes we can observe the final build in this blog series and confirm that it completed successfully.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2de8163e-174f-4466-b53b-bd822f96c304/upload_1587153267130.png)

We can then view our pod logs in the Kubernetes dashboard to confirm Liquibase executed and our application has started up.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2de8163e-174f-4466-b53b-bd822f96c304/upload_1587153267144.png)

Now grab the newly created service IP address:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2de8163e-174f-4466-b53b-bd822f96c304/upload_1587153267150.png)

And confirm by POSTing a new user:
```bash
$ curl -s \
    -H "Content-Type: application/json” \
    -X POST \
    -d '{"firstName":"todd", "lastName":"sharp", "email":"me@ohmy.com", "age":42}’    
    http://129.146.214.93:/hello/ | jq
{
  "id": "bfcb6c09-46c0-40ec-bad6-ab826635f6e5",
  "firstName": "todd",
  "lastName": "sharp",
  "age": 42,
  "email": "me@ohmy.com"
}
```



## TL;DR

We've deployed our microservice as a Docker container in our OKE Kubernetes cluster!

## Next

Unfortunately, our pilgrimage into the expansive, electrifying universe of continuous integration and continuous deployment has come to a sorrowful conclusion. I hope you have learned everything you possibly wanted to about automated deployments and have picked up some valuable tools that can make your application deployment rapid and painless when working with the Oracle Cloud.

If you have any feedback or would like to connect with me to suggest future content ideas or discuss anything Oracle Cloud or development related, feel free to connect with me on [Twitter](https://twitter.com/recursivecodes) or [YouTube](https://youtube.com/c/recursivecodes). Thank you for reading!

## Source Code

For this post can be found at <https://github.com/recursivecodes/cicd-demo/tree/part-10>

Photo by [Joshua Earle](https://unsplash.com/@joshuaearle?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/sunset?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
