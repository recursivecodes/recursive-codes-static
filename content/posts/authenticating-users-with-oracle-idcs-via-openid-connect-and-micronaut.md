---
title: "Authenticating Users with Oracle IDCS via OpenId Connect and Micronaut "
slug: "authenticating-users-with-oracle-idcs-via-openid-connect-and-micronaut"
author: "Todd Sharp"
date: 2021-04-21
summary: "In this post, we'll look at using IDCS with OpenId Connect as an authentication system. We'll also create a simple Micronaut application to test it out!"
tags: ["Cloud", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/banner_the_door_3560740_1280.jpeg"
---

Security is the most important aspect of your web application. Fortunately, there are tools available to help make life much easier when dealing with things like securing endpoints to authenticated users and integrating with third-party authentication systems. One of the more popular methods for authorization these days is OpenId Connect. OpenID Connect extends the OAuth 2.0 protocol to add a simple authentication and identity layer that sits on top of OAuth 2.0. You can use OpenID Connect when you want your cloud-based applications to get identity information, retrieve details about the authentication event (such as when, where, and how the authentication occurred), and allow federated single sign-on (SSO). If you're using Oracle Identity Cloud Service (IDCS) then adding support to your applications for [federated SSO via OpenId Connect](https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/usingopenidconnect.html) is an option that you might want to consider. In this post, we'll take a look at using IDCS and OpenId Connect to add SSO to a Micronaut application. All it takes is a bit of prep work, a few dependencies, and some minor config and code updates and you'll have it up and running in no time. Let's do it!

{{< callout >}}
**For More Information:** Micronaut Security is a vast module that provides so much more than we're going to cover in this post. Make sure to [read all about it in the documentation](https://micronaut-projects.github.io/micronaut-security/latest/guide/) when you need to integrate it into your application.
{{< /callout >}}
Here's what we'll cover in this post. Feel free to jump around as necessary!

- [Create User(s) and Application](#create-users-and-application)
  - [Create User](#create-user)
  - [Obtain the Federation's Base URL](#obtain-the-federations-base-url)
  - [Create an Application](#create-an-application)
    - [Activate the Application](#activate-the-application)
  - [Enable Public Access for the Signing Certificate](#enable-public-access-for-the-signing-certificate)
- [Create Micronaut Application](#create-micronaut-application)
  - [Modify Application Configuration](#modify-application-configuration)
    - [Set Environment Variables](#set-environment-variables)
  - [Create the Controller](#create-controller)
  - [Create the View](#create-the-view)
  - [Test the Application](#test-the-application)
- [Summary](#summary)

## Create User(s) and Application

The first thing we'll need to do for this demo is to create at least one user and an application that will help us configure endpoints and obtain the necessary client credentials. 

### Create User

Let's create a user in our federation using the Oracle Cloud console. You can use the burger menu to find 'Federation' under 'Identity', or search for it in the search box in the top nav menu like this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147281.png)

On the Federation list page, click on the federation that you'd like to work with. The default federation in your tenancy will be called 'OracleIdentityCloudService' and will likely be the only one listed (unless you've added another identity provider).

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147292.png)

On the federation details page, in the User list, click 'Create User'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147301.png)

Populate a username, email (and confirm), first and last name, and optionally add a telephone number.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147312.png)

The new user will receive an email once the creation is complete. The email will look similar to the one below and will contain two links. Click on the link in the email that prompts you to set a new password.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147332.png)

Set the new password, making sure to meet all of the password requirements as listed.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147337.png)

Once the password is set, head back to the email and click on the other link to sign in to the tenancy as the new user. Make sure the tenant name is correct, and click on 'Continue' to use the `oracleidentitycloudservice` provider.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147340.png)

Enter the new user's username and the password that you have set for that user.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147343.png)

The first time that you log in, you'll be prompted to set recovery info for the account. It's always a good idea to do so, so set a recovery email, phone number, and set up your security questions.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147347.png)

### Obtain the Federation's Base URL

Now that the test user is created, log out from that account and log back in with your administrator user. Head back to the Identity Provider Details page.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147350.png)

In the provider details, find the 'Oracle Identity Cloud Service Console' entry, and grab the base of the Console URL (without the path information). See screenshot below.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147354.png)

Keep this handy, we'll use this later on in our Micronaut application as the `OAUTH_ISSUER`. Next, click on the link to head over to the Oracle Identity Cloud Service Console.

### Create an Application

We need to create a client application that will grant us our client credentials. In the Oracle Identity Cloud Service Console, click 'Create Application':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147357.png)

Choose 'Confidential Application'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147361.png)

In the first page of the create application wizard, enter a name and description. The rest of the information in this tab is optional and does not affect the application configuration in any way.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147365.png)

Click Next to head to the client registration step. This step is where we'll register our client application. For this demo, choose 'Client Credentials' and 'Authorization Code' as the 'Allowed Grant Types', and then check the 'Allow non-HTTPS URLs' box. Enter the 'Redirect URL', 'Logout URL', and 'Post Logout Redirect URL' as shown below.

{{< callout >}}
**Important! **Obviously the 'Allow non-HTTPS URLs' checkbox should only be selected when working with a development environment. When you create your production application, you'll certainly be using HTTPs to secure your endpoints!
{{< /callout >}}
![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147368.png)

Scroll down a bit, and add a few roles. You'll want to select 'Audit Administrator' and 'Me' from the dialog.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147370.png)

Don't forget 'Me'. Heh.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147373.png)

That's all the config we need to do for our application, so click next until you hit the final step and click 'Finish'. When you finish creating the application, collect the 'Client ID' and 'Client Secret'. We'll use these in our Micronaut application as the `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` respectively.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147376.png)

#### Activate the Application

\[info\]

**Don't Forget!** After the application is created, you must click on 'Activate' to make sure the application is ready to go!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147379.png)

### Enable Public Access for the Signing Certificate

Micronaut needs to be able to download the signing certificate in order to validate the JWT. By default, this certificate requires an authenticated request, but we can change that so that Micronaut is able to download the cert with an unauthenticated request. Before leaving IDCS, go to the burger menu, Settings, then Default Settings.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147383.png)

Allow access to the signing certificate by unauthorized users so Micronaut can download it to validate the JWT.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147386.png)

## Create Micronaut Application

Next, we'll create a demo Micronaut application to test out the authentication. Head over to [Micronaut Launch](https://launch.micronaut.io) and bootstrap a new application. Be sure to add the features `security-jwt`, `security-oauth2`, `security-session`, and `views-thymeleaf`.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147390.png)

### Modify Application Configuration

Download the generated zip, extract it and open it in your favorite IDE. Open up `src/main/resources/application.yml` and edit it to look like so. Make sure to change the key `default` to `oci` so that Micronaut generates the proper URLs.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147393.png)

Here's the code from the above screenshot for your copy/paste pleasure.
```yaml
micronaut:
  application:
    name: openIdConnectOciDemo
  security:
    authentication: idtoken
    oauth2:
      clients:
        oci:
          client-id: ${OAUTH_CLIENT_ID}
          client-secret: ${OAUTH_CLIENT_SECRET}
          openid:
            issuer: ${OAUTH_ISSUER}
    endpoints:
      logout:
        enabled: true
        get-allowed: true
```



#### Set Environment Variables

Of course, we don't want to hardcode our credentials in the config file, so we're going to pass them into the application via environment variables. One way to do that locally is to create a run/debug config in our IDE. Populate the values from the client id, client secret, and IDCS base URL that we collected earlier.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147396.png)

### Create the Controller 

Next, create a controller with the following command.
```bash
$ mn create-controller codes.recursive.controller.Page
```



We're going to create three endpoints for this application: one for `index`, `secure`, and `error`. Open up the new controller and populate it as such. Note the `@Secured` annotation which lets us secure individual endpoints with separate security rules. This gives us granular control over which endpoint a user is allowed to access based on their current authentication status.

{{< callout >}}
**Note:** You can also annotate the controller class itself with a default `@Secured` annotation that will apply to all methods. The class annotation can be overridden at the method level. Refer to the [documentation](https://micronaut-projects.github.io/micronaut-security/latest/guide/#secured) for more.
{{< /callout >}}
```java
@Controller("/")
public class PageController {

    @Secured(SecurityRule.IS_ANONYMOUS)
    @View("home")
    @Get(uri="/")
    public Map<String, Object> index() {
        return new HashMap<>();
    }

    @Secured(SecurityRule.IS_AUTHENTICATED)
    @Get("/secure")
    public Map<String, Object> secured() {
        return CollectionUtils.mapOf("secured", true);
    }

    @Secured(SecurityRule.IS_ANONYMOUS)
    @Get("/error")
    public Map<String, Object> error() {
        return CollectionUtils.mapOf("error", true);
    }
}
```



### Create the View

Now let's create the home view that will be used to allow the user to authenticate and list the user information available to us from the JWT token returned from IDCS. Create the file at `src/main/resources/views/home.html` and populate it as such.
```html
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <title>Micronaut - OCI IDCS Example</title>
</head>
<body>
<h1>Micronaut - OCI IDCS Example</h1>

<h2 th:if="${security}">Username: <span th:text="${security.attributes.get('user_displayname')}"></span></h2>
<h2 th:unless="${security}">Username: Anonymous</h2>

<nav>
    <ul>
        <li th:unless="${security}"><a href="/oauth/login/oci">Enter</a></li>
        <li th:if="${security}"><a href="/logout">Logout</a></li>
    </ul>
</nav>
<div th:if="${security}">
    <h2>User Information:</h2>
    <ul>
        <li>user_tz: <span th:text="${security.attributes.get('user_tz')}"></span></li>
        <li>at_hash: <span th:text="${security.attributes.get('at_hash')}"></span></li>
        <li>sub: <span th:text="${security.attributes.get('sub')}"></span></li>
        <li>user_locale: <span th:text="${security.attributes.get('user_locale')}"></span></li>
        <li>idp_name: <span th:text="${security.attributes.get('idp_name')}"></span></li>
        <li>idp_guid: <span th:text="${security.attributes.get('idp_guid')}"></span></li>
        <li>amr: <span th:text="${security.attributes.get('amr')}"></span></li>
        <li>iss: <span th:text="${security.attributes.get('iss')}"></span></li>
        <li>user_tenantname: <span th:text="${security.attributes.get('user_tenantname')}"></span></li>
        <li>client_id: <span th:text="${security.attributes.get('client_id')}"></span></li>
        <li>authn_strength: <span th:text="${security.attributes.get('authn_strength')}"></span></li>
        <li>azp: <span th:text="${security.attributes.get('azp')}"></span></li>
        <li>auth_time: <span th:text="${security.attributes.get('auth_time')}"></span></li>
        <li>client_tenantname: <span th:text="${security.attributes.get('client_tenantname')}"></span></li>
        <li>user_lang: <span th:text="${security.attributes.get('user_lang')}"></span></li>
        <li>exp: <span th:text="${security.attributes.get('exp')}"></span></li>
        <li>iat: <span th:text="${security.attributes.get('iat')}"></span></li>
        <li>client_name: <span th:text="${security.attributes.get('client_name')}"></span></li>
        <li>client_guid: <span th:text="${security.attributes.get('client_guid')}"></span></li>
        <li>idp_type: <span th:text="${security.attributes.get('idp_type')}"></span></li>
        <li>tenant: <span th:text="${security.attributes.get('tenant')}"></span></li>
        <li>jti: <span th:text="${security.attributes.get('jti')}"></span></li>
        <li>user_displayname: <span th:text="${security.attributes.get('user_displayname')}"></span></li>
        <li>sub_mappingattr: <span th:text="${security.attributes.get('sub_mappingattr')}"></span></li>
        <li>primTenant: <span th:text="${security.attributes.get('primTenant')}"></span></li>
        <li>tok_type: <span th:text="${security.attributes.get('tok_type')}"></span></li>
        <li>nonce: <span th:text="${security.attributes.get('nonce')}"></span></li>
        <li>ca_guid: <span th:text="${security.attributes.get('ca_guid')}"></span></li>
        <li>aud: <span th:text="${security.attributes.get('aud')}"></span></li>
        <li>user_id: <span th:text="${security.attributes.get('user_id')}"></span></li>
        <li>tenant_iss: <span th:text="${security.attributes.get('tenant_iss')}"></span></li>
    </ul>
</div>
</body>
</html>
```



For a [description of each attribute, see the IDCS docs](https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/SupportedTokens.html).

### Test the Application

Launch the application locally and try to visit [`http://localhost:8080/secure`](http://localhost:8080/secure) - you'll be redirected to the `index` (homepage) since we marked that endpoint as `@Secured` and we're not yet logged in. On the homepage, click on 'Enter' and you will be redirected to your tenancy sign-in page. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147399.png)

Sign in with the user that we created above. On the next screen, grant access to the application.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147402.png)

After authenticating, you'll be redirected to the homepage. Detailed information about your logged-in user is displayed.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147407.png)

Now you can visit `http://localhost:8080/secure` and notice that you'll be granted access!

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/f98749d3-f060-4444-a2f1-c94351891eb2/file_1618929147410.png)

## Summary

In this post, we created a federated user, IDCS application, and a Micronaut application that delegates authentication to IDCS via OpenId Connect. The application displays information retrieved from the JWT that IDCS returns to the application and uses `@Secured` to secure an endpoint until the user is authenticated.

**Code! **If you'd like to check out the Micronaut code used in this post, check it out on GitHub: <https://github.com/recursivecodes/open-id-connect-oci-demo>

Image by [pasja1000](https://pixabay.com/users/pasja1000-6355831/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3560740) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=3560740) 

