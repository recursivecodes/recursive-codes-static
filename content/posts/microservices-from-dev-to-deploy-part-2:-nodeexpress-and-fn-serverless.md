---
title: "Microservices From Dev To Deploy, Part 2: Node/Express and Fn Serverless"
slug: "microservices-from-dev-to-deploy,-part-2:-nodeexpress-and-fn-serverless"
author: "Todd Sharp"
date: 2018-10-05
summary: "The second part in a short series that looks at the \"how\" of microservices.  In this post we look at creating a simple microservice with Express and a serverless function using Java and Fn."
tags: ["Containers, Microservices, APIs", "DevOps", "Developers", "Java", "JavaScript", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a6c1deba-12fe-4561-ac17-363c0ccefd6d/banner_ocpc_businessrole_developer_502197407.jpg"
---

<div>

In our [last post](/posts/microservices-from-dev-to-deploy-part-1-getting-started-with-helidon), we were introduced to a fictional company called **TechCorp** run by an entrepreneur named Lydia whose goal it is to bring back the world back to the glory days of the internet homepage. Lydia's global team of remarkable developers are implementing her vision with a microservice architecture and we learned about Chris and Michiko who have teams in London and Tokyo.  These teams built out a weather and quote service using [Helidon](https://helidon.io/), a microservice framework by Oracle.  Chris' team used Helidon SE with Groovy and Michiko's team chose Java with Helidon MP.  In this post, we'll look at Murielle and her Bangalore crew who are building a stock service using NodeJS with Express and Dominic and the Melbourne squad who have the envious task of building out a random cat image service with Java Oracle [Fn](https://fnproject.io/) (a serverless technology).

</div>

<div>

It's clear Helidon makes both functional and Microprofile style services straight-forward to implement.  But, despite what I personally may have thought 5 years ago it is getting impossible to ignore that NodeJS has exploded in popularity.  Stack Overflow's most [recent survey](https://insights.stackoverflow.com/survey/2018#technology) shows over 69% of respondents selecting JavaScript as the "Most Popular Technology" among Programming, Scripting and Markup Languages and Node comes in atop the "Framework" category with greater than 49% of the respondents preferring it.  It's a given that people are using JavaScript on the frontend and it's more and more likely that they are taking advantage of it on the backend, so it's no surprise that Murielle's team decided to use Node with Express to build out the stock service.  

</div>

<div>

 

</div>

<div>

We won't dive too deep into the Express plumbing for this service, but let's have a quick look at the method to retrieve the stock quote:

</div>
``` {.brush: .javascript}
var express = require('express');
var router = express.Router();
var config = require('config');
var fetch = require("node-fetch");

/* GET stock quote */
/* jshint ignore:start */
router.get('/quote/:symbol', async (req, res, next) => {
  const symbol = req.param('symbol');
  const url = `${config.get("api.baseUrl")}/?function=GLOBAL_QUOTE&symbol=${symbol}&apikey=${config.get("api.apiKey")}`;

  try {
    const response = await fetch(url);
    const json = await response.json();
    res.send(json);
  } catch (error) {
    res.send(JSON.stringify(error));
  }

});
/* jshint ignore:end */
module.exports = router;
```

<div>

Using fetch (in an async manner), this method calls the stock quote API and passes along the symbol that it received via the URL parameters and returns the stock quote as a JSON string to the consumer.  Here's how that might look when we hit the service locally:

</div>

<div>

![stock-service-response](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/a6c1deba-12fe-4561-ac17-363c0ccefd6d/stock_response.png)

</div>

<div>

Murielle's team can expand the service in the future to provide historical data, cryptocurrency lookups, or whatever the business needs demand, but for now it provides a current quote based on the symbol it receives.  The team creates a Dockerfile and Kubernetes config file for deployment which we'll take a look at in the future.

</div>

<div>

 

</div>

<div>

Dominic's team down in Melbourne has been doing a lot of work with serverless technologies.  Since they've been tasked with a priority feature -- random cat images -- they feel that serverless is the way to go do deliver this feature and set about using [Fn](https://fnproject.io/) to build the service.  It might seem out of place to consider serverless in a microservice architecture, but it undoubtedly has a place and fulfills the stated goals of the microservice approach:  flexible, scalable, focused and rapidly deployable.  Dominic's team has done all the [research](https://developer.oracle.com/opensource/serverless-with-fn-project) on serverless and Fn and is ready to get to work, so the developers [installed a local Fn server](https://fnproject.io/tutorials/install/) and followed the [quickstart](https://fnproject.io/tutorials/JavaFDKIntroduction/) for Java to scaffold out a function.

</div>

<div>

 

</div>

<div>

Once the project was ready to go Dominic's team modified the func.yaml file to set up some configuration for the project, notably the apiBaseUrl and apiKey:

</div>
``` {.brush: .plain}
schema_version: 20180708
name: cat-svc
version: 0.0.47
runtime: java
build_image: fnproject/fn-java-fdk-build:jdk9-1.0.70
run_image: fnproject/fn-java-fdk:jdk9-1.0.70
cmd: codes.recursive.cat.CatFunction::handleRequest
format: http
config:
  apiBaseUrl: https://api.thecatapi.com/v1
  apiKey: [redacted]
triggers:
- name: cat
  type: http
  source: /random
```

<div>

The CatFunction class is basic.  A setUp() method, annotated with \@FnConfiguration gives access to the function context which contains the config info from the YAML file and initializes the variables for the function.  Then the handleRequest() method makes the HTTP call, again using a client library called Unirest, and returns the JSON containing the link to the crucial cat image.  

</div>
``` {.brush: .java}
public class CatFunction {

    private String apiBaseUrl;
    private String apiKey;

    @FnConfiguration
    public void setUp(RuntimeContext ctx) {
        apiBaseUrl = ctx.getConfigurationByKey("apiBaseUrl").orElse("");
        apiKey = ctx.getConfigurationByKey("apiKey").orElse("");
    }

    public OutputEvent handleRequest(String input) throws UnirestException {
        String url = apiBaseUrl + "/images/search?format=json";
        HttpResponse<JsonNode> response = Unirest
                .get(url)
                .header("Content-Type", "application/json")
                .header("x-api-key", apiKey)
                .asJson();
        OutputEvent out = OutputEvent.fromBytes(
                response.getBody().toString().getBytes(),
                OutputEvent.Status.Success,
                "application/json"
        );
        return out;
    }
}
```

<div>

To test the function, the team deploys the function locally with:

</div>
``` {.brush: .plain}
fn deploy --app cat-svc –local
```

<div>

And tests that it is working:

</div>
``` {.brush: .plain}
curl -i \
-H "Content-Type: application/json" \
http://localhost:8080/t/cat-svc/random
```

<div>

Which produces:

</div>
``` {.brush: .plain}
HTTP/1.1 200 OK
Content-Length: 112
Content-Type: application/json
Fn_call_id: 01CRGBAH56NG8G00RZJ0000001
Xxx-Fxlb-Wait: 502.0941ms
Date: Fri, 28 Sep 2018 15:04:05 GMT

[{"id":"ci","categories":[],"url":"https://24.media.tumblr.com/tumblr_lz8xmo6xYV1r0mbi6o1_500.jpg","breeds":[]}]
```

<div>

Success!  Dominic's team created the cat service before lunch and spent the rest of the day looking at random cat pictures.

</div>

<div>

 

</div>

<div>

Now that all 4 teams have implemented their respective services using various technologies, you might be asking yourself why it was necessary to implement such trivial services on the backend instead of calling the third-party APIs directly from the front end.  There are several reasons but let's take a look at just a few of them:

</div>

<div>

 

</div>

<div>

One reason to implement this functionality via a server-based backend is that third-party APIs can be unreliable and/or rate limited.  By proxying the API through their own backend, the teams are able to take advantage of caching and rate limiting of their own design to prevent the demand on the third-party API and get around potential downtime or rate limiting for a service that they have limited or no control over.  

</div>

<div>

 

</div>

<div>

Secondly, the teams are given the luxury of controlling the data before it's sent to the client.  If it is allowed within the API terms and the business needs require them to supplement the data with other third-party or user data they can reduce the client CPU, memory, and bandwidth demands by augmenting or modifying the data before it even gets to the client.

</div>

<div>

 

</div>

<div>

Finally, CORS restrictions in the browser can be circumvented by calling the API from the server (and if you've ever had CORS block your HTTP calls in the browser you can definitely appreciate this!).

</div>

<div>

 

</div>

<div>

**TechCorp** has now completed the initial microservice development sprint of their project.  In the next post, we'll look at how these 4 services can be deployed to a local Kubernetes cluster and we'll also dig into the Angular front end of the application.

</div>

<div>

 

</div>
