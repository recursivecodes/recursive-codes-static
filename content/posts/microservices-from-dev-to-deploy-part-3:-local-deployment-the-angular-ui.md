---
title: "Microservices From Dev To Deploy, Part 3: Local Deployment & The Angular UI"
slug: "microservices-from-dev-to-deploy,-part-3:-local-deployment-the-angular-ui"
author: "Todd Sharp"
date: 2018-10-09
summary: ""
tags: ["APIs", "Containers, Microservices, APIs", "DevOps", "Developers", "Java", "JavaScript", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/94333321-1992-4796-aae9-e4c27c0f04f1/banner_ocpc_businesssolution_epm_607477457.jpg"
---

In this series, we're taking a look at how microservice applications are built.  In [part 1](/posts/microservices-from-dev-to-deploy-part-1-getting-started-with-helidon) we learned about the new open source framework from Oracle called Helidon and learned how it can be used with both Java and Groovy in either a functional, reactive style or a more traditional Microprofile manner.  [Part 2](/posts/microservices-from-dev-to-deploy,-part-2:-nodeexpress-and-fn-serverless) acknowledged that some dev teams have different strengths and preferences and that one team in our fictional scenario used NodeJS with the ExpressJS framework to develop their microservice.  Yet another team in the scenario chose to use Fn, another awesome Oracle open source technology to add serverless to the application architecture.  Here is an architecture diagram to help you better visualize the overall picture:

![techcorp-architecture-overview](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/94333321-1992-4796-aae9-e4c27c0f04f1/architecture_overview.png)

It may be a contrived and silly scenario, but I think it properly represents the diversity of skills and preferences that are the true reality of many teams that are building software today.  Our ultimate path in this journey is how all of the divergent pieces of this application come together in a deployment on the Oracle Cloud and we're nearly at that point.  But before we get there, let's take a look at how all of these backend services that have been developed come together in a unified frontend.

Before we get started, if you're playing along at home you might want to first make sure you have access to a local Kubernetes cluster.  For testing purposes, I've built my own cluster using a few Raspberry Pi's (following the [instructions here](https://gist.github.com/alexellis/fdbc90de7691a1b9edb545c17da2d975)), but you can get a local testing environment up and running with [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/) pretty quickly.  Don't forget to [install ](https://kubernetes.io/docs/tasks/tools/install-kubectl/)[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), you'll need the command line tools to work with the cluster that you set up.

With the environment set up, let's revisit Chris' team who you might recall from part 1 have built out a weather service backend using Groovy with Helidon SE.  The Gradle 'assemble' task gives them their JAR file for deployment, but Helidon also includes a few other handy features: a docker build file and a Kubernetes yaml template to speed up deploying to a K8S cluster.  When you use the Maven archetype (as Michiko's team did in part 1) the files are automatically copied to the 'target' directory along with the JAR, but since Chris' team is using Groovy with Gradle, they had to make a slight modification to the build script to copy the templates and slightly modify the paths within them.  The build.gradle script they used now includes the following tasks:
``` {.brush: .groovy}
task copyDocker(type:Copy) {
    from "src/main/docker"
    into "build"
    doLast {
        def d = new File( 'build/Dockerfile' )
        def dfile = d.text.replaceAll('\\$\\{project.artifactId\\}', project.name)
        dfile = dfile.replaceAll("COPY ${project.name}", "COPY libs/${project.name}")
        d.write(dfile)
    }
}
task copyK8s(type:Copy) {
    from "src/main/k8s"
    into "build"
    doLast {
        def a = new File( 'build/app.yaml' )
        def afile = a.text.replaceAll('\\$\\{project.artifactId\\}', project.name)
        a.write(afile)
    }
}

copyLibs.dependsOn jar
copyDocker.dependsOn jar
copyK8s.dependsOn jar
assemble.dependsOn copyLibs
assemble.dependsOn copyDocker
assemble.dependsOn copyK8s
```

So now, when Chris' team performs a local build they receive a fully functional Dockerfile and app.yaml file to help them quickly package the service into a Docker container and deploy that container to a Kubernetes cluster.  The process now becomes:

1.  Write Code
2.  Test Code
3.  Build JAR (gradle assemble)
4.  Build Docker Container (docker build / docker tag)
5.  Push To Docker Registry (docker push)
6.  Create Kubernetes Deployment (kubectl create)

Which, if condensed into a quick screencast, looks something like this:

![build-jar-with-helidon-se-and-deploy](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/94333321-1992-4796-aae9-e4c27c0f04f1/build_helidon_0.gif)

When the process is repeated for the rest of the backend services the frontend team led by Ava are now are able to integrate the backend services into the Angular 6 frontend that they have been working on.  They start by specifying the deployed backend base URLs in their environment.ts file.  Angular uses this file to provide a flexible way to manage global application variables that have different values per environment.  For example, an environment.prod.ts file can have it's own set of production specific values that will be substituted when a \`ng build \--prod\` is performed.  The default environment.ts is used if no environment is specified so the team uses that file for development and have set it up with the following values:
``` {.brush: .javascript}
export const environment = {
  production: false,
  stockApiBaseUrl: 'http://192.168.0.160:31002',
  weatherApiBaseUrl: 'http://192.168.0.160:31000',
  quoteApiBaseUrl: 'http://192.168.0.160:31001',
  catApiBaseUrl: 'http://localhost:31004',
};
```

The team then creates services corresponding to each microservice.  Here's the weather.service.ts:
``` {.brush: .javascript}
import {Injectable} from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {environment} from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class WeatherService {

  private baseUrl: string = environment.weatherApiBaseUrl;

  constructor(
    private http: HttpClient,
  ) { }

  getWeatherByCoords(coordinates) {
    return this.http
      .get(`${this.baseUrl}/weather/current/lat/${coordinates.lat}/lon/${coordinates.lon}`);
  }
}
```

And call the services from the view component.
``` {.brush: .javascript}
getWeather() {
  this.weather = null;
  this.weatherLoading = true;

  this.locationService.getLocation().subscribe((result) => {
    const response: any = result;
    const loc: Array<string> = response.loc.split(',');
    const lat: string = loc[0];
    const long: string = loc[1];
    console.log(loc)
    this.weatherService.getWeatherByCoords({lat: lat, lon: long})
      .subscribe(
        (weather) => {
          this.weather = weather;
        },
        (error) => {},
        () => {
          this.weatherLoading = false;
        }
      );
  });
}
```

Once they've completed this for all of the services, the corporate vision of a throwback homepage is starting to look like a reality:

![homepage-ui](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/94333321-1992-4796-aae9-e4c27c0f04f1/homepage_ui.png)

In three posts we've followed **TechCorp**'s journey to developing an internet homepage application from idea, to backend service creation and onto integrating the backend with a modern JavaScript based frontend built with Angular 6.  In the next post of this series we will see how this technologically diverse application can be deployed to Oracle's Cloud.
