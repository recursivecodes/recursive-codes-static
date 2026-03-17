---
title: "Creating An ATP Instance With The OCI Service Broker"
slug: "creating-an-atp-instance-with-the-oci-service-broker"
author: "Todd Sharp"
date: 2019-06-10
summary: "Learn how to use the OCI service broker for Kubernetes to deploy an Autonomous Transaction Processing DB instance."
tags: ["Cloud", "Containers, Microservices, APIs", "DevOps", "Open Source"]
keywords: "Kubernetes, Cloud, service"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/118074e3-4633-4661-8ebb-0477349fbd2b/banner_2019_06_06_15_11_29.jpg"
---

We recently [announced the release of the OCI Service Broker](https://blogs.oracle.com/cloudnative/announcing-the-oci-service-broker) for Kubernetes, an implementation of the [Open Service Broker API](https://www.openservicebrokerapi.org/) that streamlines the process of provisioning and binding to services that your cloud native applications depend on.

The Kubernetes documentation lays out the following [use case for the Service Catalog API](https://kubernetes.io/docs/concepts/extend-kubernetes/service-catalog/):

An application developer wants to use message queuing as part of their application running in a Kubernetes cluster. However, they do not want to deal with the overhead of setting such a service up and administering it themselves. Fortunately, there is a cloud provider that offers message queuing as a managed service through its service broker.

A cluster operator can setup Service Catalog and use it to communicate with the cloud provider's service broker to provision an instance of the message queuing service and make it available to the application within the Kubernetes cluster. The application developer therefore does not need to be concerned with the implementation details or management of the message queue. The application can simply use it as a service.

Put simply, the Service Catalog API lets you manage services within Kubernetes that are not be deployed within Kubernetes.  Things like messaging queues, object storage and databases can be deployed with a set of Kubernetes configuration files without needing knowledge of the underlying API or tools used to create those instances thus simplifying the deployment and making it portable to virtually any Kubernetes cluster.

The current OCI Service Broker adapters that are available at this time include:

- Autonomous Transaction Processing (ATP)
- Autonomous Data Warehouse (ADW)
- Object Storage
- Streaming

I won't go into too much detail in this post about the feature, as the [introduction post](https://blogs.oracle.com/cloud-infrastructure/introducing-service-broker-for-kubernetes) and [GitHub documentation](https://github.com/oracle/oci-service-broker) do a great job of explaining service brokers and the problems that they solve. Rather, I'll focus on using the OCI Service Broker to provision an ATP instance and deploy a container which has access to the ATP credentials and wallet.  

To get started, you'll first have to [follow the installation instructions on GitHub](https://github.com/oracle/oci-service-broker/tree/master/charts/oci-service-broker/docs). At a high level, the process involves:

1.  Deploy the Kubernetes Service Catalog client to the OKE cluster
2.  Install the `svcat` CLI tool
3.  Deploy the OCI Service Broker
4.  Create a Kubernetes Secret containing OCI credentials
5.  Configure Service Broker with TLS
6.  Configure RBAC (Role Based Access Control) permissions
7.  Register the OCI Service Broker

Once you've installed and registered the service broker, you're ready to use the ATP service plan to provision an ATP instance. I'll go into details below, but the overview of the process looks like so:

1.  Create a Kubernetes secret with a new admin and wallet password (in JSON format)
2.  Create a YAML configuration for the ATP Service Instance
3.  Deploy the Service Instance
4.  Create a YAML config for the ATP Service Binding
5.  Deploy the Service Binding to obtain which results in the creation of a new Kubernetes secret containing the wallet contents
6.  Create a Kubernetes secret for Microservice deployment use containing the admin password and the wallet password (in plain text format)
7.  Create a YAML config for the Microservice deployment which uses an initContainer to decode the wallet secrets (due to a bug which double encodes them) and mounts the wallet contents as a volume

Following that overview, let's take a look at a detailed example. The first thing we'll have to do is make sure that the user we're using with the OCI Service Broker has the proper permissions.  If you're using a user that is a member of the group `devops` then you would make sure that you have a policy in place that looks like this:

    Allow group devops to manage autonomous-database in compartment [COMPARTMENT_NAME]

The next step is to create a secret that will be used to set some passwords during ATP instance creation.  Create a file called `atp-secret.yaml` and populate it similarly to the example below.  The values for password and walletPassword must be in the format of a JSON object as shown in the comments inline below, and must be base64 encoded.  You can use an online tool for the base64 encoding, or use the command line if you're on a Unix system (`echo '' | base64`).
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: atp-secret
data:
  # {"password":"Passw0rd123456"}
  password: [base64 encoded JSON object]
  # {"walletPassword":"WalletPassw0rd13456"}
  walletPassword: [base64 encoded JSON object]
```



Now create the secret via: `kubectl create -f app-secret.yaml`.

Next, create a file called `atp-instance.yaml` and populate as follows (updating the `name, compartmentId, dbName, cpuCount, storageSizeTBs, licenseType` as necessary).  The paremeters are detailed in the full documentation (link below).  Note, we're referring to the previously created secret in this YAML file.
```yaml
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: osb-atp-demo-1
spec:
  clusterServiceClassExternalName: atp-service
  clusterServicePlanExternalName: standard
  parameters:
    name: demo-db-1
    compartmentId: ocid1.compartment.oc1...
    dbName: demodb1
    cpuCount: 1
    storageSizeTBs: 1
    licenseType: BYOL
#    freeFormTags:
#      testtag: demo
#   definedTags:
#     your-tag-namespace:
#       your-defined-key: some_value
  parametersFrom:
    - secretKeyRef:
        name: atp-secret
        key: password
```



Create the instance with: `kubectl create -f atp-instance.yaml`. This will take a bit of time, but in about 15 minutes or less your instance will be up and running. You can check the status via the OCI console UI, or with the command: `svcat get instances` which will return a status of "ready" when the instance has been provisioned.

Now that the instance has been provisioned, we can create a binding.  Create a file called `atp-binding.yaml` and populate it as such:
```yaml
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceBinding
metadata:
  name: atp-demo-binding
spec:
  instanceRef:
    name: osb-atp-demo-1
  parametersFrom:
    - secretKeyRef:
        name: atp-secret
        key: walletPassword
```



Note that we're once again using a value from the initial secret that we created in step 1. Apply the binding with: `kubectl create -f atp-binding.yaml` and check the binding status with `svcat get bindings`, looking again for a status of "ready". Once it's ready, you'll be able to view the secret that was created by the binding via: `kubectl get secrets atp-demo-binding -o yaml` where the secret name matches the '`name`' value used in `atp-binding.yaml`. The secret will look similar to the following output:
```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  creationTimestamp: 2018-09-20T19:54:02Z
  name: atp-demo-binding
  namespace: catalog
  resourceVersion: "116279449"
  selfLink: /api/v1/namespaces/catalog/secrets/atp-demo-binding
  uid: ec556735-bd0e-11e8-9999-0a580aed122c
data:
  cwallet.sso: b2ZoT05nQ..
  ewallet.p12: TE1JSV...
  keystore.jks: L3UzKz...B
  ojdbc.properties: YjNKaFkyeGxMbTVsZ...
  sqlnet.ora: VjBGTVRFVlVYMH...
  tnsnames.ora: L3UzKzdR...
  truststore.jks: L3UzKzdRQ...
  user_name: QURNSU4=
```



This secret contains the contents of your ATP instance wallet and next we'll mount these as a volume inside of the application deployment.  Let's create a final YAML file called `atp-demo.yaml` and populate it like below.  Note, there is currently a bug in the service broker that double encodes the secrets, so it's currently necessary to use an initContainer to get the values properly decoded.
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: atp-demo
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: atp-demo
    spec:
      # The credential files in the secret are base64 encoded twice and hence they need to be decoded for the programs to use them.
      # This decode-creds initContainer takes care of decoding the files and writing them to a shared volume from which db-app container
      # can read them and use it for connecting to ATP.
      initContainers:
      - name: decode-creds
        command:
        - bash
        - -c
        - "for i in `ls -1 /tmp/creds | grep -v user_name`; do cat /tmp/creds/$i  | base64 --decode > /creds/$i; done; ls -l /creds/*;"
        image: oraclelinux:7.4
        volumeMounts:
        - name: creds-raw
          mountPath: /tmp/creds
          readOnly: false
        - name: creds
          mountPath: /creds
      containers:
      # User application that uses credential files to connect to ATP.
      - name: db-app
        image: alpine:3.7
        command: ["tail", "-f", "/dev/null"]
        env:
        # Pass DB ADMIN user name that is part of the secret created by the binding request.
        - name: DB_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: atp-demo-binding
              key: user_name
        # Pass DB ADMIN password. The password is managed by the user and hence not part of the secret created by the binding request.
        # In this example we read the password form secret atp-user-cred that is required to be created by the user.  
        - name: DB_ADMIN_PWD
          valueFrom:
            secretKeyRef:
              name: atp-user-cred
              key: password
        # Pass  Wallet password to enable application to read Oracle wallet. The password is managed by the user and hence not part of the secret created by the binding request.
        # In this example we read the password form secret atp-user-cred that is required to be created by the user.  
        - name: WALLET_PWD
          valueFrom:
            secretKeyRef:
              name: atp-user-cred
              key: walletPassword
        volumeMounts:
        - name: creds
          mountPath: /db-demo/creds
      volumes:
      # Volume for mouting the credentials file from Secret created by binding request.
      - name: creds-raw
        secret:
          secretName: atp-demo-binding
      # Shared Volume in which initContainer will save the decoded credential files and the db-app container reads.
      - name: creds
        emptyDir: {}
```



Here we're just creating a basic alpine linux instance just to test the service instance. Your application deployment would use a Docker image with your application, but the format and premise would be nearly identical to this. Create the deployment with `kubectl create -f atp-demo.yaml` and once the pod is in a "ready" state we can launch a terminal and test things out a bit:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/118074e3-4633-4661-8ebb-0477349fbd2b/2019_06_06_15_11_29.jpg)

Note that we have 3 environment variables available in the instance:  `DB_ADMIN_USER`, `DB_ADMIN_PWD` and `WALLET_PWD`.  We also have a volume available at `/db-demo/creds` containing all of our wallet contents that we need to make a connection to the new ATP instance.

Check out the full [instructions](https://github.com/oracle/oci-service-broker/blob/master/charts/oci-service-broker/docs/atp.md) for more information or background on the ATP service broker. The ability to bind to an existing ATP instance is scheduled as an enhancement to the service broker in the near future, and some other exciting features are planned.
