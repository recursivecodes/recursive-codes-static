---
title: "Adventures in CI/CD [#8]: Deploying A Microservice With A Tested Persistence Tier In Place"
slug: "adventures-in-cicd-8-deploying-a-microservice-with-a-tested-persistence-tier-in-place"
author: "Todd Sharp"
date: 2020-05-15
summary: "In this post, we'll deploy our microservice with the tested persistence tier in place to our production environment which utilizes Autonomous DB in the cloud."
tags: ["Cloud", "Containers, Microservices, APIs", "Integration", "Java", "Open Source"]
keywords: "Cloud, AUTONOMOUS, DB, Continuous Integration"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8e534310-f9a4-4b73-8b35-46536fe506ea/banner_bill_jelen_lt6ge86vyaa_unsplash.jpg"
---

We have covered a ton of content already in this long series on CI/CD, and now we're ready to look at the next step in our adventure on the path to CI/CD enlightenment. In case you've missed anything, here's what we have covered so far:

- [Adventures In CI/CD \[#1\]: Intro & Getting Started With GitHub Actions](/posts/adventures-in-cicd-1-intro-getting-started-with-github-actions)
- [Adventures in CI/CD \[#2\]: Building & Publishing A JAR](/posts/adventures-in-cicd-2-building-publishing-a-jar)
- [Adventures in CI/CD \[#3\]: Running Tests & Publishing Test Reports](/posts/adventures-in-cicd-3-running-tests-publishing-test-reports)
- [Adventures in CI/CD \[#4\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[OCI CLI Edition\]](/posts/adventures-in-cicd-4-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-oci-cli-edition)
- [Adventures in CI/CD \[#5\]: Deploying A Microservice To The Oracle Cloud With GitHub Actions \[Gradle Plugin Edition\]](/posts/adventures-in-cicd-5-deploying-a-microservice-to-the-oracle-cloud-with-github-actions-gradle-plugin-edition)
- [Adventures in CI/CD \[#6\]: Adding A Persistence Tier To Our Microservice](/posts/adventures-in-cicd-6-adding-a-persistence-tier-to-our-microservice)
- [Adventures in CI/CD \[#7\]: Testing The Persistence Tier With Testcontainers](/posts/adventures-in-cicd-7-testing-the-persistence-tier-with-testcontainers)

In this post, we're going to focus on the changes necessary to deploy our microservice now that we have added a persistence tier and tested it in our pipeline with Testcontainers. Since we used Liquibase to manage our DB migrations, it should be a pretty painless journey to deploy our application to the Oracle Cloud. So far we've got our application tested against Oracle XE both locally and in our pipeline and we're confident that we're ready to deploy our changes to our "production" instance which is currently set up as a VM in the Oracle Cloud. We've yet to configure any database for production yet, so it's time to spin up an instance of Autonomous DB in the cloud. If you're new to Autonomous DB, here's a video to walk you through the process of getting started.

## Autonomous Wallet

Our Autonomous DB connection requires the use of a "wallet" to make a secure connection. You'll need to download your wallet from the Oracle Cloud console. If you're unsure how to do that, here's another tutorial that will show you how to download that:

You can also download your wallet via the CLI if you prefer:
```bash
oci db autonomous-data-warehouse generate-wallet \
    --autonomous-data-warehouse-id [ATP OCID] \
    --password [Wallet Password] \
    --file ./wallet.zip
```



Now that we've downloaded the wallet, we'll need to create GitHub secrets with our wallet file contents so that we can get them into our build and ultimately into our VM so the application can use the wallet to create the secure connection. Let's convert our wallet contents to base64 so we can store them as secrets in GitHub. Here's a quick bash script to help with that (or you can certainly do it manually).
```bash
mkdir /tmp/base64-wallet
for f in /wallet/*
do
   fname=$(basename $f)
   x=$(base64 -i $f -o /tmp/base64-wallet/$fname)
done
```



Create secrets in GitHub for each file and use the `base64` contents as the secret.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8e534310-f9a4-4b73-8b35-46536fe506ea/upload_1587150984951.png)

Next, add a step in our workflow to write our configuration files to our production VM's filesystem (using the `ssh-action` action that we've used in other steps).
```yaml
- name: 'Write Wallet'
  uses: appleboy/ssh-action@master
  with:
    host: ${{ env.INSTANCE_IP }}
    username: opc
    key: ${{ secrets.VM_SSH_PRIVATE_KEY }}
    script: |
      sudo mkdir /wallet
      sudo sh -c 'echo "${{secrets.WALLET_CWALLET}}" | base64 -d >> /wallet/cwallet.sso'
      sudo sh -c 'echo "${{secrets.WALLET_EWALLET}}" | base64 -d >> /wallet/ewallet.p12'
      sudo sh -c 'echo "${{secrets.WALLET_KEYSTORE}}" | base64 -d >> /wallet/keystore.jks'
      sudo sh -c 'echo "${{secrets.WALLET_OJDBC}}" | base64 -d >> /wallet/ojdbc.properties'
      sudo sh -c 'echo "${{secrets.WALLET_SQLNET}}" | base64 -d >> /wallet/sqlnet.ora'
      sudo sh -c 'echo "${{secrets.WALLET_TNSNAMES}}" | base64 -d >> /wallet/tnsnames.ora'
      sudo sh -c 'echo "${{secrets.WALLET_TRUSTSTORE}}" | base64 -d >> /wallet/truststore.jks
```



### Configure Production Datasource

We'll need to add a new configuration file, so create a new file in `src/main/resources` called `application-oraclecloud.yml`. Make sure you use that exact name because Micronaut supports environment detection and is able to detect when your application is running on the Oracle Cloud and will load your environment-specific configuration accordingly. That means that we can specify config variables that only apply to a particular environment. Populate your new `application-oraclecloud.yml` file like so:
```yaml
datasources:
  default:
    url: ${DATASOURCE_URL:`jdbc:oracle:thin:@[TNS NAME]?TNS_ADMIN=/wallet`}
    driverClassName: oracle.jdbc.driver.OracleDriver
    username: ${DATASOURCE_USERNAME:[your username]}
    password: ${DATASOURCE_PASSWORD}
    schema-generate: NONE
    dialect: ORACLE
```



Here you'll have to use your specific TNS name within your URL as the default value (notice the backticks surrounding the URL - these are necessary since it contains colon characters). Also, default the username to your schema user. We'll set the `DATASOURCE_PASSWORD` when we launch the JAR file, but we'll need one more secret in GitHub to contain that value, so create one called `DB_PASSWORD`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8e534310-f9a4-4b73-8b35-46536fe506ea/upload_1587150984954.png)

Finally, modify your 'Start App' step to pass the password value into our app as a system property when we launch the JAR. Micronaut will pick up this value and set it as appropriate.
```yaml
- name: 'Start App'
  uses: appleboy/ssh-action@master
  with:
    host: ${{ env.INSTANCE_IP }}
    username: opc
    key: ${{ secrets.VM_SSH_PRIVATE_KEY }}
    script: |
      sudo mv ~/app/cicd-demo-${{env.VERSION}}-all.jar /app/cicd-demo.jar
      nohup java -DDATASOURCE_PASSWORD=${{secrets.DB_PASSWORD}} -jar /app/cicd-demo.jar > output.$(date --iso).log 2>&1 &
```



After pushing the changes your pipeline job should execute successfully.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/8e534310-f9a4-4b73-8b35-46536fe506ea/upload_1587150984967.png)

If you SSH into the VM and look at the `output` log you should see something similar to the following. Notice that our Liquibase migration has been properly run against our production Autonomous DB instance.
```log
18:47:16.143 [main] INFO  i.m.context.env.DefaultEnvironment - Established active environments: [oraclecloud, cloud]
18:47:25.945 [main] INFO  l.database.core.OracleDatabase - Could not set remarks reporting on OracleDatabase: com.sun.proxy.$Proxy13.setRemarksReporting(boolean)
18:47:26.093 [main] INFO  l.database.core.OracleDatabase - Could not set check compatibility mode on OracleDatabase, assuming not running in any sort of compatibility mode: Cannot read from v$parameter: ORA-00942: table or view does not exist
18:47:26.519 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT COUNT(*) FROM CICD.DATABASECHANGELOGLOCK
18:47:26.553 [main] INFO  liquibase.executor.jvm.JdbcExecutor - CREATE TABLE CICD.DATABASECHANGELOGLOCK (ID INTEGER NOT NULL, LOCKED NUMBER(1) NOT NULL, LOCKGRANTED TIMESTAMP, LOCKEDBY VARCHAR2(255), CONSTRAINT PK_DATABASECHANGELOGLOCK PRIMARY KEY (ID))
18:47:26.584 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT COUNT(*) FROM CICD.DATABASECHANGELOGLOCK
18:47:26.597 [main] INFO  liquibase.executor.jvm.JdbcExecutor - DELETE FROM CICD.DATABASECHANGELOGLOCK
18:47:26.603 [main] INFO  liquibase.executor.jvm.JdbcExecutor - INSERT INTO CICD.DATABASECHANGELOGLOCK (ID, LOCKED) VALUES (1, 0)
18:47:26.720 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT LOCKED FROM CICD.DATABASECHANGELOGLOCK WHERE ID=1 FOR UPDATE
18:47:26.739 [main] INFO  l.lockservice.StandardLockService - Successfully acquired change log lock
18:47:30.553 [main] INFO  l.c.StandardChangeLogHistoryService - Creating database history table with name: CICD.DATABASECHANGELOG
18:47:30.556 [main] INFO  liquibase.executor.jvm.JdbcExecutor - CREATE TABLE CICD.DATABASECHANGELOG (ID VARCHAR2(255) NOT NULL, AUTHOR VARCHAR2(255) NOT NULL, FILENAME VARCHAR2(255) NOT NULL, DATEEXECUTED TIMESTAMP NOT NULL, ORDEREXECUTED INTEGER NOT NULL, EXECTYPE VARCHAR2(10) NOT NULL, MD5SUM VARCHAR2(35), DESCRIPTION VARCHAR2(255), COMMENTS VARCHAR2(255), TAG VARCHAR2(255), LIQUIBASE VARCHAR2(20), CONTEXTS VARCHAR2(255), LABELS VARCHAR2(255), DEPLOYMENT_ID VARCHAR2(10))
18:47:30.581 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT COUNT(*) FROM CICD.DATABASECHANGELOG
18:47:30.587 [main] INFO  l.c.StandardChangeLogHistoryService - Reading from CICD.DATABASECHANGELOG
18:47:30.588 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT * FROM CICD.DATABASECHANGELOG ORDER BY DATEEXECUTED ASC, ORDEREXECUTED ASC
18:47:30.614 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT COUNT(*) FROM CICD.DATABASECHANGELOGLOCK
18:47:30.642 [main] INFO  liquibase.executor.jvm.JdbcExecutor - CREATE TABLE CICD.users (id VARCHAR2(36) NOT NULL, first_name VARCHAR2(75) NOT NULL, last_name VARCHAR2(75) NOT NULL, email VARCHAR2(500), age NUMBER(3, 0) NOT NULL, CONSTRAINT users_pk PRIMARY KEY (id))
18:47:30.669 [main] INFO  liquibase.executor.jvm.JdbcExecutor - COMMENT ON TABLE CICD.users IS 'A table to contain users'
18:47:30.679 [main] INFO  liquibase.changelog.ChangeSet - Table users created
18:47:30.682 [main] INFO  liquibase.changelog.ChangeSet - ChangeSet classpath:db/changelog/01-create-user-table.xml::01::toddrsharp ran successfully in 47ms
18:47:30.684 [main] INFO  liquibase.executor.jvm.JdbcExecutor - SELECT MAX(ORDEREXECUTED) FROM CICD.DATABASECHANGELOG
18:47:30.690 [main] INFO  liquibase.executor.jvm.JdbcExecutor - INSERT INTO CICD.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('01', 'toddrsharp', 'classpath:db/changelog/01-create-user-table.xml', SYSTIMESTAMP, 1, '8:5a6c5b79fbc0d19c65159d6c01f5d4e7', 'createTable tableName=users', '', 'EXECUTED', NULL, NULL, '3.8.8', '6890050619')
18:47:30.719 [main] INFO  l.lockservice.StandardLockService - Successfully released change log lock
18:47:32.079 [main] INFO  io.micronaut.runtime.Micronaut - Startup completed in 16142ms. Server Running: http://localhost:8080
```



You can confirm the deployment with a few cURL commands:
```bash
curl -s \
    -H "Content-Type: application/json” \
    -X POST \
    -d '{"firstName":"todd", "lastName":"sharp", "email":"me@ohmy.com", "age":42}’ \
    http://158.101.18.239:8080/hello/ | jq
```



Which will create and return the new user object.
```json
{
  "id": "09d872c1-7d08-4095-b515-65a2931c58e1",
  "firstName": "todd",
  "lastName": "sharp",
  "age": 42,
  "email": "me@ohmy.com"
}
```



And to retrieve that user by ID:
```bash
curl -s http://158.101.18.239:8080/hello/09d872c1-7d08-4095-b515-65a2931c58e1 | jq
```



Which returns the same user object:
```json
{
  "id": "09d872c1-7d08-4095-b515-65a2931c58e1",
  "firstName": "todd",
  "lastName": "sharp",
  "age": 42,
  "email": "me@ohmy.com"
}
```



## TL;DR

In this post, we created an Autonomous DB instance, downloaded our wallet credentials and modified our GitHub Actions pipeline to write our wallet to our production VM. We then created a production-specific datasource configuration and modified our "Start App" step to pass our DB password to the application when launching it.

## Next

In the next post, we'll switch gears and look at deploying our microservice application as a Docker container.

## Source Code

For this post can be found at <https://github.com/recursivecodes/cicd-demo/tree/part-8>

Photo by [Bill Jelen](https://unsplash.com/@billjelen?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/launch?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
