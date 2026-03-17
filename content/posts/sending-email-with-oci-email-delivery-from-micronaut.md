---
title: "Sending Email With OCI Email Delivery From Micronaut"
slug: "sending-email-with-oci-email-delivery-from-micronaut"
author: "Todd Sharp"
date: 2022-03-18
summary: "In this post, we'll look at the new Micronaut Email module and see how to use it with the OCI email service to send messages from a Java application."
tags: ["Java", "Micronaut"]
keywords: "email, micronaut, oracle cloud infrastructure, oci, java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/mn-oci-email%2Femail-g78afed2a1_1280.png"
---

Email delivery is a critical function of most web applications in the world today. I've managed an email server in the past - and trust me - it's not fun or easy to do for a developer that isn't as familiar with the infrastructure side of things. Thankfully, Oracle Cloud Infrastructure (OCI) offers an [email delivery service](https://docs.oracle.com/en-us/iaas/Content/Email/Concepts/overview.htm) that provides a managed solution for sending high-volume emails without setting up and managing an SMTP server. My favorite Java framework, Micronaut, recently released the Micronaut Email module that supports sending email in your applications. This release inspired me to see what it would take to use OCI email delivery in a Micronaut application. As usual, it's pretty straightforward. So let's see what it takes!

- [Setup OCI Email Delivery](#Setup%20OCI%20Email%20Delivery)
- [Sending Email via OCI Email Delivery in Your Micronaut App](#Sending%20Email%20via%20OCI%20Email%20Delivery%20in%20Your%20Micronaut%20App)
  - [Add Dependencies](#Add%20Dependencies)
  - [Configure Default Sender](#Configure%20Default%20Sender)
  - [Configure MailPropertiesProvider](#%C2%A0%20Configure%20MailPropertiesProvider)
  - [Configure SessionProvider](#Configure%20SessionProvider)
- [Set Credentials Into the Application via Environment Variables](#Set%20Credentials%20Into%20Application%20via%20Environment%20Variables)
  - [Send Email with EmailSender](#Send%20Email%20with%20EmailSender)
    - [Send a Simple Plain Text Email](#Send%20a%20Simple%20Plain%20Text%20Email)
    - [Send a Templated Email](#Send%20a%20Templated%20Email)
    - [Send an Email With an Attachment](#Send%20an%20Email%20With%20an%20Attachment)
- [Summary](#Summary)

## Setup OCI Email Delivery 

If you've not yet configured a user for email delivery, you'll need to take care of that first. Normally, I'd walk you through that process, but in this case, I think the docs do an excellent job of keeping things concise, so I'll link to them here instead. Here are the steps you'll need to take:

- [Generate SMTP Credentials](https://docs.oracle.com/en-us/iaas/Content/Email/Tasks/generatesmtpcredentials.htm)
- [Add an Approved Sender](https://docs.oracle.com/en-us/iaas/Content/Email/Tasks/managingapprovedsenders.htm)
- [Find SMTP Endpoint for Your Region](https://docs.oracle.com/en-us/iaas/Content/Email/Tasks/configuresmtpconnection.htm)

We'll need to collect our username, password, and SMTP endpoint before moving on to the next step.

## Sending Email via OCI Email Delivery in Your Micronaut App 

Now that we have the appropriate credentials and setup complete, we can move on to adding the Micronaut module to our application and configuring it to get ready to send emails.

### Add Dependencies 

We'll need the following dependencies to enable our Micronaut application to send emails. If you don't want to use templates, you could exclude the last two dependencies, but I'm going to include them since I'll be showing how to use templates.

```groovy
implementation("io.micronaut.email:micronaut-email-javamail")
implementation("io.micronaut.email:micronaut-email-template")
implementation("io.micronaut.views:micronaut-views-thymeleaf")
```
 **Tip!** You can choose any of the template engines that are [supported by Micronaut Views](https://micronaut-projects.github.io/micronaut-views/latest/guide/) for email templates!

### Configure Default Sender 

We can specify a default sender for all emails by setting one into our configuration at `/src/main/resources/application.yml`:

```yaml
micronaut:
  application:
    name: mnOciEmail
  email:
    from:
      email: default@email.com
      name: Email User
```
**Note!** The default email sender must be an "approved sender" in the OCI email delivery service!

### Configure MailPropertiesProvider 

Next, we will need to configure a `MailPropertiesProvider`. Creating the provider is accomplished via configuration settings in our `application.yml` file (located at `/src/main/resources`). The necessary configuration to generate the provider is below. Note that we'll set the host value externally in just a bit.

```yaml
javamail:
  properties:
    mail:
      smtp:
        port: 587
        auth: true
        starttls:
          enable: true
        host:
```
### Configure SessionProvider 

A `SessionProvider` is also necessary. For this, we'll create a class that implements `SessionProvider` and within the `session()` method, we'll create and return an instance of `PasswordAuthentication`. We will pass the username and password via the constructor. Again, we'll set those values via external configuration in the next section of this blog post.

```java
@Singleton
public class OciSessionProvider implements SessionProvider {
    private final Properties properties;
    private final String user;
    private final String password;

    public OciSessionProvider(
            MailPropertiesProvider properties,
            @Property(name = "codes.recursive.smtp.user") String user,
            @Property(name = "codes.recursive.smtp.password") String password
    ) {
        this.properties = properties.mailProperties();
        this.user = user;
        this.password = password;
    }
    
    @Override
    @NonNull
    public Session session() {
        return Session.getInstance(properties, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(user, password);
            }
        });
    }
}
```
## Set Credentials Into the Application via Environment Variables 

You *could* hardcode your credentials into your configuration files, but that would be a bad idea. It's so bad that I don't even do that for simple local demos anymore. We must insist on consistently enforcing security practices in our applications. So, if we're not hardcoding them, how can we get them into the app? Well, one way is to set them into Java system properties. Another option is to set them into environment variables. Micronaut can translate a specifically constructed environment variable or system property into the proper configuration value. If you're not familiar with this feature, I suggest that you read about it in the [Application Configuration section](https://docs.micronaut.io/latest/guide/#config) of the docs. So, to pass in the credentials, I set the following environment variables in my IDE:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b68ffbd7-9397-45a1-bc37-eb8e6ad0b057/upload_09e5f98199faa0c3fceb4e5e49d93fa1.png)

### Send Email with EmailSender 

At this point, we're ready to inject the Micronaut `EmailSender` into our application and use it to send email messages. I've created a controller to test this out and inject the `EmailSender` like so:

```java
@Controller("/email")
public class EmailController {

    private final EmailSender emailSender;

    public EmailController(EmailSender emailSender) {
        this.emailSender = emailSender;
    }

}
```
#### Send a Simple Plain Text Email 

To send an email, use the `Email` builder:

```java
@Get(uri="/", produces="text/plain")
public String index() {
    Email.Builder emailBuilder = Email.builder()
            .to("pipar27174@shackvine.com")
            .subject("Basic Micronaut Email Test: " + LocalDateTime.now())
            .body("This is an email");
    emailSender.send(emailBuilder);
    return "Email sent.";
}
```
To test this, hit the `/email` endpoint:

```bash
$ curl localhost:8080/email
Email sent.
```
Checking the inbox where we sent the message will confirm the message delivery.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/adff37bb-2ea8-4096-bbfe-4360d894d569/upload_e9c29987774a6222b7f04c7f041b84f6.png)

#### Send a Templated Email 

To send an email using a Thymeleaf template, create a template at `/src/main/resources/views/email.html` and populate it like so:

```html
<!DOCTYPE html>
<html lang="en" xmlns:th="http://www.thymeleaf.org">
<body>
    <p>
        Hello, <span th:text="${name}"></span>!
    </p>
</body>
```
Create an endpoint:

```java
@Get(uri="/template/{name}", produces="text/plain")
public String template(@PathVariable String name) {
    Map model = CollectionUtils.mapOf("name", name);
    Email.Builder emailBuilder = Email.builder()
            .to("pipar27174@shackvine.com")
            .subject("Micronaut Email Template Test: " + LocalDateTime.now())
            .body(new TemplateBody<>(BodyType.HTML, new ModelAndView<>("email", model)));
    emailSender.send(emailBuilder);
    return "Email sent.";
}
```
Send an email by requesting the `/email/template` endpoint and pass the value for `/` like so: 

```bash
$ curl localhost:8080/email/template/Todd%20Sharp
Email sent.
```
And check the inbox:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/440b0c3a-6689-4f77-a1ce-8feb3de9bbcd/upload_c06d837f61f6c76e6b5df6dc1c37fce9.png)

#### Send an Email With an Attachment 

To send a message with an attachment, create a `POST` endpoint located at `/email/attachment` that consumes a multipart form.

```java
@Post(uri="/attachment", produces="text/plain", consumes = MediaType.MULTIPART_FORM_DATA)
public String attachment(CompletedFileUpload file) throws IOException {
    Email.Builder emailBuilder = Email.builder()
            .to("pipar27174@shackvine.com")
            .subject("Micronaut Email Attachment Test: " + LocalDateTime.now())
            .body("This is an email")
            .attachment(
                    Attachment.builder()
                            .filename(file.getFilename())
                            .contentType(file.getContentType().isPresent() ? file.getContentType().get().toString() : MediaType.APPLICATION_OCTET_STREAM)
                            .content(file.getBytes())
                            .build()
            );
    emailSender.send(emailBuilder);
    return "Email sent.";
}
```
And `POST` a request to the `/email/attachment` endpoint that includes a file:

```bash
$ curl -X POST \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/Users/trsharp/Pictures/demo/apple.jpg" \
  localhost:8080/email/attachment
Email sent.
```
Check the inbox:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/bb000ac5-eb87-4c29-a5a3-151623814317/upload_c6cb57cab84aa6c8921b0c27f24c5dad.png)

## Summary 

This post looked at how to use OCI email delivery in a Micronaut application to send text-based and templated email messages. We also learned how to send emails with attachments with the `EmailSender`. As always, you can refer to the [project on GitHub](https://github.com/recursivecodes/mn-oci-email) for the full source code used in this demo.
