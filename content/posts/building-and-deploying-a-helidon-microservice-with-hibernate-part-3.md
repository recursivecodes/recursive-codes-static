---
title: "Building And Deploying A Helidon Microservice With Hibernate Part 3"
slug: "building-and-deploying-a-helidon-microservice-with-hibernate-part-3"
author: "Todd Sharp"
date: 2019-07-09
summary: "In this post we'll deploy our new microservice to the Oracle Cloud!"
tags: ["Cloud", "Containers, Microservices, APIs", "Developers", "Java"]
keywords: "Cloud, microservices, Java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/banner_photo_nic_co_uk_nic_ppy_j4h0h80_unsplash.jpg"
---

We've taken quite a journey in this blog series so far - from getting our cloud tenancy ready for our microservice deployment, to writing our first microservice application using Helidon. In this post we'll finally get our microservice deployed to the Oracle Cloud, but if you're new to the series then you might want to catch up on where we've been so far.

- [The Complete Guide To Getting Up And Running With Docker And Kubernetes On The Oracle Cloud](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud) 
- [The Complete Guide To Getting Up And Running With Autonomous Database In The Cloud](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud)
- [Building And Deploying A Helidon Microservice With Hibernate Part 1](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-1)
- [Building And Deploying A Helidon Microservice With Hibernate Part 2](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-2)

The first step in deploying our microservice to the Oracle Cloud is to build a Docker image containing our application and push that image to our OCIR Docker Registry that we configured previously. When we scaffolded the Helidon application from the Maven archetype you may or may not have noticed, but Helidon gave us a `Dockerfile` and `app.yaml` out of the box that looked similar to this:
```text
# 1st stage, build the app
FROM maven:3.5.4-jdk-9 as build

WORKDIR /helidon

# Create a first layer to cache the "Maven World" in the local repository.
# Incremental docker builds will always resume after that, unless you update
# the pom
ADD pom.xml .
RUN mvn package -DskipTests

# Do the Maven build!
# Incremental docker builds will resume here when you change sources
ADD src src
RUN mvn package -DskipTests
RUN echo "done!"

# 2nd stage, build the runtime image
FROM openjdk:8-jre-slim
WORKDIR /helidon

# Copy the binary built in the 1st stage
COPY --from=build /helidon/target/user-svc.jar ./
COPY --from=build /helidon/target/libs ./libs

CMD ["java", "-jar", "user-svc.jar"]

EXPOSE 8080
```



If we had made no changes to the application we could have used that `Dockerfile` to build and push an image, but since we've made some changes we'll need to modify it a bit to work with our application. We're going to add and install the OJDBC dependencies locally so they can be included in our build. The other modification we'll need to make is to ensure that our wallet files make it into the container (alternatively we could mount these as a volume, but since this is more of a "beginner" series I want to keep things as simple as possible) and modify the CMD so that our configuration values get set properly when we launch the JAR.

The modified `Dockerfile` looks like this:
```text
# 1st stage, build the app
FROM maven:3.5.4-jdk-9 as build

WORKDIR /helidon

ENV MAVEN_OPTS -Dhttp.proxyHost= -Dhttp.proxyPort= -Dhttps.proxyHost= -Dhttps.proxyPort= -Dhttp.nonProxyHosts= -Dmaven.repo.local=/usr/share/maven/ref/repository
ADD pom.xml .
ADD build-resource/libs/* /helidon/build-resource/libs/

RUN ["mvn", "install:install-file", "-Dfile=/helidon/build-resource/libs/ojdbc8.jar", "-DgroupId=com.oracle.jdbc", "-DartifactId=ojdbc8", "-Dversion=18.3.0.0", "-Dpackaging=jar"]
RUN ["mvn", "install:install-file", "-Dfile=/helidon/build-resource/libs/oraclepki.jar", "-DgroupId=com.oracle.jdbc", "-DartifactId=oraclepki", "-Dversion=18.3.0.0", "-Dpackaging=jar"]
RUN ["mvn", "install:install-file", "-Dfile=/helidon/build-resource/libs/osdt_core.jar", "-DgroupId=com.oracle.jdbc", "-DartifactId=osdt_core", "-Dversion=18.3.0.0", "-Dpackaging=jar"]
RUN ["mvn", "install:install-file", "-Dfile=/helidon/build-resource/libs/osdt_cert.jar", "-DgroupId=com.oracle.jdbc", "-DartifactId=osdt_cert", "-Dversion=18.3.0.0", "-Dpackaging=jar"]

ADD src src
RUN mvn package -DskipTests

# 2nd stage, build the runtime image
FROM openjdk:8-jre-slim
WORKDIR /helidon

# Copy the binary built in the 1st stage
COPY --from=build /helidon/target/user-svc.jar ./
COPY --from=build /helidon/target/libs ./libs
RUN mkdir wallet
COPY /build-resource/wallet/* ./wallet/

EXPOSE 8080

CMD ["sh", "-c", "java -jar -Ddatasource.username=$DB_USER -Ddatasource.password=$DB_PASSWORD -Ddatasource.url=$DB_URL -Doracle.net.wallet_location=/helidon/wallet -Doracle.net.authentication_services="(TCPS)" -Doracle.net.tns_admin=/helidon/wallet -Djavax.net.ssl.trustStore=/helidon/wallet/cwallet.sso -Djavax.net.ssl.trustStoreType=SSO -Djavax.net.ssl.keyStore=/helidon/wallet/cwallet.sso -Djavax.net.ssl.keyStoreType=SSO -Doracle.net.ssl_server_dn_match=true -Doracle.net.ssl_version=1.2 user-svc.jar"]
```



You can now build the image with:

[`docker build -t phx.ocir.io/toddrsharp/cloud-native-microservice/user-svc-helidon:latest .`]

This command tags the newly built image with the proper format for pushing to our OCIR registry. Note that I'm using the Phoenix region - if you're using a different region then your URL will change. Remember that the OCIR URL format works like so:

`[region].ocir.io/[tenancy]/[repository-name]/[docker-image-name]:[tag]`

We can run this image locally with:
```bash
docker run \                                                                                                                                                                      
--env DB_USER=[username] \
--env DB_URL="jdbc:oracle:thin:@[tnsname]?TNS_ADMIN=/helidon/wallet" \
--env DB_PASSWORD=[password] \
-p 8080:8080 \
-t phx.ocir.io/toddrsharp/cloud-native-microservice/user-svc-helidon:latest
```



The app is now up and running in a local Docker container just as it did when we ran the JAR file locally in the last post. Stop the local container and let's move on to pushing the image to our OCIR registry. That's pretty simple too:

`docker push phx.ocir.io/toddrsharp/cloud-native-microservice/user-svc-helidon:latest` 

We can confirm the image in the OCIR dashboard:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_12_19_33.jpg)

Let's move on to deploying the Docker image in our Kubernetes cluster. We'll need two Kubernetes secrets created for our deployment. One for our Docker registry credentials so that Kubernetes can authenticate when pulling the image, and another that contains our application credentials so that we can pass them into our Docker container when the app is deployed instead of hard coding them in the Dockerfile.

Create the registry credentials secret like so (the password in this secret is **not** Base64 encoded):
```bash
kubectl create secret docker-registry regcred \
--docker-server=[region].ocir.io \
--docker-username=[tenancy]/[docker user] \
--docker-password="[docker auth token]" \
--docker-email=[docker email (if set when creating user)]
```



Now for the application secrets, create a filed called secret.yaml and populate it as follows (using your own Base64 encoded values):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: user-svc-helidon-secrets
data:
  dbUser: [base64 encoded username]
  dbPassword: [base64 encoded password]
  dbUrl: [base64 encoded URL]
---
```



To create the secret in the cluster, run:

`kubectl create -f secret.yaml`

We can now modify the `app.yaml` file to complete our Kubernetes deployment. We'll modify a few things from the generated file, but it's a pretty simple format. Note that we need to override the Docker container's CMD with our own here to make sure that the values from our secret are properly used when starting the container. Otherwise, what we're doing here is creating a Kubernetes service to expose our service on the cluster and a deployment that represents our Docker container. We tell Kubernetes the location where the image is (in OCIR), point the config to our secrets and put in some placeholders that will be replaced with the secret values when the image is deployed.

Here's my modified `app.yaml`:
```yaml
kind: Service
apiVersion: v1
metadata:
  name: user-svc-helidon
  labels:
    app: user-svc-helidon
spec:
  type: LoadBalancer
  selector:
    app: user-svc-helidon
  ports:
  - port: 8080
    targetPort: 8080
    name: http
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: user-svc-helidon
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: user-svc-helidon
        version: v1
    spec:
      containers:
      - name: user-svc-helidon
        image: phx.ocir.io/toddrsharp/cloud-native-microservice/user-svc-helidon:latest
        command: ["java", "-jar"]
        args:
        - "-Doracle.net.wallet_location=/helidon/wallet"
        - "-Doracle.net.authentication_services=(TCPS)"
        - "-Doracle.net.tns_admin=/helidon/wallet"
        - "-Djavax.net.ssl.trustStore=/helidon/wallet/cwallet.sso"
        - "-Djavax.net.ssl.trustStoreType=SSO"
        - "-Djavax.net.ssl.keyStore=/helidon/wallet/cwallet.sso"
        - "-Djavax.net.ssl.keyStoreType=SSO"
        - "-Doracle.net.ssl_server_dn_match=true"
        - "-Doracle.net.ssl_version=1.2"
        - "-Ddatasource.username=$(DB_USER)"
        - "-Ddatasource.password=$(DB_PASSWORD)"
        - "-Ddatasource.url=$(DB_URL)"
        - "user-svc.jar"
        env:
          - name: DB_USER
            valueFrom:
              secretKeyRef:
                name: user-svc-helidon-secrets
                key: dbUser
          - name: DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: user-svc-helidon-secrets
                key: dbPassword
          - name: DB_URL
            valueFrom:
              secretKeyRef:
                name: user-svc-helidon-secrets
                key: dbUrl
        imagePullPolicy: Always
        ports:
          - containerPort: 8080
      imagePullSecrets:
      - name: regcred
---
```



Which we can deploy with:

`kubectl create -f app.yaml`

And verify the deployment with:

`kubectl get deployments`

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_11_06.jpg)

Verify the pod was created:

`kubectl get pods`

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_12_32.jpg)

Finally, verify the service was created and assigned an IP address (this will take a minute or two to complete for new services):

`kubectl get services`

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_12_54.jpg)

Let's try making a request to see if everything works:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_18_57.jpg)

Unfortunately, we've got an error! To figure out what's going on let's take a look at the pod logs:

`kubectl logs user-svc-helidon-69688b4fd6-l5gqt` 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_21_40.jpg)

It looks like our code used a Java 9 feature, but we deployed the application in a Docker image based on Java 8. It's a simple fix, just modify the Dockerfile to use the `openjdk:9-jre-slim` runtime image, rebuild the Docker image and push it again. To redeploy our app we do not have to create the deployment again, simply delete the existing pod and a new pod will be pulled using the latest image from OCIR:

`kubectl delete pod user-svc-helidon-69688b4fd6-l5gqt`

Now if we try our request again, everything should be good to go!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_25_452222.jpg)

And listing users should give us a proper response (assuming we've created users in the DB already) confirming that our connection to ATP is solid:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/2688e360-fe2e-4686-886a-89653f0f6ad1/2019_07_01_13_28_55.jpg)

And that's it!  In this series, we've prepared our Oracle Cloud tenancy for microservices and written and deployed our first service. In future posts I'm going to examine some other interesting options for creating microservices to make life a little easier on the code side of things.

[Photo by ][photo-nic.co.uk nic](https://unsplash.com/@chiro?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/happy?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
