---
title: "Adventures in CI/CD [#3]: Running Tests & Publishing Test Reports"
slug: "adventures-in-cicd-3-running-tests-publishing-test-reports"
author: "Todd Sharp"
date: 2020-04-27
summary: "In this post, we'll create and run some tests in our pipeline and publish our test reports as build artifacts."
tags: ["Cloud", "Containers, Microservices, APIs", "Integration", "Open Source"]
keywords: "Cloud, Test, testing, Continuous Integration, build, git, Java"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/banner_annie_spratt_ordz1m1_q0i_unsplash__1_.jpg"
---

Thanks for joining me back in this series about CI/CD with GitHub Actions where we're learning how to build, test, publish and deploy our microservices applications to the Oracle Cloud. This is the third post in this series that has covered the following topics so far:

- [Adventures In CI/CD \[#1\]: Intro & Getting Started With GitHub Actions](/posts/adventures-in-cicd-1-intro-getting-started-with-github-actions)
- [Adventures in CI/CD \[#2\]: Building & Publishing A JAR](/posts/adventures-in-cicd-2-building-publishing-a-jar)

In this post, we're going to look at tests that are a crucial step to any proper CI/CD workflow. Certainly your application already has a full suite of tests and you're already used to making sure that these all pass before you deploy your application to the theory (or "why") relating to tests should not be new to you. With that in mind, we'll focus on the "how" as it relates to tests in our demo project.

## Preparing Our App For Spock

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134393353.jpeg)

[[NBC Television](https://commons.wikimedia.org/wiki/File:Spock_at_console.jpg) / Public domain]

I'm a big fan of using the popular Spock library for testing as I feel that the expressive nature of the Groovy language makes writing tests easy and reading them even easier. To upgrade our Micronaut application to use Spock, let's add a few dependencies to our `build.gradle` file.
```groovy
testImplementation "io.micronaut:micronaut-inject-groovy:$micronautVersion"
testImplementation("org.spockframework:spock-core") {
    exclude group: "org.codehaus.groovy", module: "groovy-all"
}
testCompile "io.micronaut.test:micronaut-test-spock"
```



And delete the JUnit dependencies since we're not using it anymore:
```groovy
testImplementation "org.junit.jupiter:junit-jupiter-api"
testImplementation "io.micronaut.test:micronaut-test-junit5"
```



Also, delete the following block that tells Gradle to use Unit as the testing platform:
```groovy
// use JUnit 5 platform
test {
    useJUnitPlatform()
}
```



We'll also need the groovy plugin, so add it to our plugins block in our build file.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740937.png)

Finally, update `micronaut-cli.yml` in the project root to change the `testFramework` to 'spock' instead of 'junit':
```yaml
profile: service
defaultPackage: codes.recursive
---
testFramework: spock
sourceLanguage: java
```



## Create A Spock Test

Since Spock uses Groovy, we need to create the proper directory structure in our `src/test` directory to contain our Spock tests.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740943.png)

Within the `src/test/groovy/codes/recursive` directory lets create a base test that our other tests will extend. It won't do much for now, but it'll come in handy later on:
```groovy
package codes.recursive
import io.micronaut.context.ApplicationContext
import spock.lang.AutoCleanup
import spock.lang.Shared
import spock.lang.Specification
class AbstractSpec extends Specification {
    @Shared
    @AutoCleanup
    static ApplicationContext context
    static  {
        context = ApplicationContext.run()
    }
}
```



Next, let's create a test! We don't have any application logic to test just yet, so create a simple `HelloWorldSpec.groovy` and populate it like so:
```groovy
package codes.recursive
import io.micronaut.test.annotation.MicronautTest
@MicronautTest
class HelloWorldSpec extends AbstractSpec {
    def "test hello world"() {
        def foo = 'bar'
        when:
        foo == 'bar'
        then:
        foo.reverse() == 'rab'
    }
}
```



Now we can run the test locally with `./gradlew` test. It should quickly pass and produce a new report at `build/reports/tests/test/index.html` that you can view in your browser locally.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740945.png)

## Add Controller & Test It

Let's add an actual controller to our microservice application so that we can run an actual, meaningful test. This is simple with the Micronaut CLI:
```bash
$ mn create-controller codes.recursive.controller.HelloController
| Rendered template Controller.java to destination src/main/java/codes/recursive/controller/HelloController.java
| Rendered template Spec.groovy to destination src/test/groovy/codes/recursive/controller/HelloControllerSpec.groovy
```



Since we updated the `micronaut-cli.yml` file above Micronaut was kind enough to stub out a Spock test for us as it created our controller. Let's take a quick look at the controller it created.
```java
@Controller("/hello")
public class HelloController {
    @Get("/")
    public HttpStatus index() {
        return HttpStatus.OK;
    }
}
```



Nothing fancy at all, just a method that will return a "`200 OK`" response. What about the test that was generated? Note that the only change I made to the generated test was to extend my `AbstractSpec`.
```groovy
@MicronautTest
class HelloControllerSpec extends AbstractSpec {
    @Shared @Inject
    EmbeddedServer embeddedServer
    @Shared @AutoCleanup @Inject @Client("/")
    RxHttpClient client
    void "test index"() {
        given:
        HttpResponse response = client.toBlocking().exchange("/hello")
        expect:
        response.status == HttpStatus.OK
    }
}
```



The generated spec includes an injected embedded server as well as an `RxHttpClient` that we can use to make requests to our controller. The single test makes a blocking request to the `/hello` endpoint and asserts that the response status is indeed "`200 OK`". Let's run our tests locally again.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740950.png)

All pass. Let's get these running in our build workflow!

## Add Action To Run Tests

I feel both sad and excited to tell you this next part. Excited because it's really simple and quick to run your tests with GitHub Actions and sad because there's not a fancy and clever way to do this. It's just a matter of executing a Gradle command to run the tests:
```yaml
- name: 'Run Tests'
    run: |
      ./gradlew test
```



However, I am going to add this step above the 'Assemble/Publish JAR' steps that we added in our last post because we want our pipeline to fail if our tests are not passing.

## Add Action To Publish Tests

It would be extremely helpful if we publish our test reports so that we can view them offline after our build has run. This will help us troubleshoot failing tests and view the metric data for our tests. We can do this by using the same `upload-artifact` action that we used to publish our JAR file in the last post, so add another step to do this. Take note of the addition of the `if` key to this step definition which allows us to run this step regardless of whether or not the previous steps have completed successfully. If we did not add this, our failed tests would effectively end the pipeline and our test reports would not get published (potentially making it quite difficult to know why the tests failed!).
```yaml
- name: 'Publish Test Report'
    if: always()
    uses: actions/upload-artifact@v2-preview
    with:
      name: 'test-report'
      path: build/reports/tests/test/*
```



If we push this latest change to GitHub, our build will trigger and we can observe the tests running and our reports being published.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740957.png)

We can confirm the published test report:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740959.png)

## When Failure Happens

I know this never happens to you, but sometimes when I write tests I end up getting some failures. Yeah, I know I should be embarrassed! So what would happen in our GitHub workflow if a failed test somehow slipped through the cracks and made it into our build? Well, let's intentionally write one to see what happens. I'll add the following to my `HelloWorldSpec` and push it to the branch I have been working with:
```groovy
def "test failure"() {
    when:
    true == true
    then:
    false == true
}
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740964.png)

As you can see above the failed tests result in the overall build job failure which prevents the creation and publishing of our JAR file, but does not prevent the test report from being published meaning we can download that report to see what went wrong.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/de94c532-8a32-43e0-9879-c40894d7a4f6/upload_1587134740968.png)

## TL;DR

In this post, we added some simple tests to our application and modified our workflow to run those tests and produce artifacts containing the results of the tests. We observed a successful run of the workflow with the tests as well as saw what happened when our tests do not pass.

## Next

In our next post we will jump into deploying our application to a virtual machine in the Oracle Cloud.

## Source Code

For this post can be found at <https://github.com/recursivecodes/cicd-demo/tree/part-3>

Photo by [Annie Spratt](https://unsplash.com/@anniespratt?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/test?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
