---
title: "Building Cross Platform Native Images With GraalVM"
slug: "building-cross-platform-native-images-with-graalvm"
author: "Todd Sharp"
date: 2020-07-10
summary: "In this post, we'll look at how to create a native image for every OS from a single Java codebase by using GraalVM."
tags: ["Cloud", "Java"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/04abc99d-f6b6-4b3a-9662-d8507b26c06a/banner_apple_158063_1280.png"
---

A few weeks ago, I blogged about a [utility that I created that helps you debug your serverless functions in the Oracle Cloud](null/p/simple-serverless-logging-for-oracle-functions). The code behind that project is pretty simple and my previous blog post explains how to create the socket server utility, but I failed to cover what is actually the more exciting part of that project in my opinion: creating cross-platform native image releases of the project that can be used on any OS. 

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/04abc99d-f6b6-4b3a-9662-d8507b26c06a/file_1594307472551.png)

In this post, I'll show you exactly how this is done, and by the time we're finished here, you'll have all the tools that you need to create a native image from your Java code for each of the three major operating systems.

**But How?? **You may have played around with GraalVM to generate native images and realized that the image can only be used on the same OS that it was generated on. For example, an image created on a Mac can't be used on a Linux machine. So how can we easily create images for operating systems other than the one we're developing are app on?  Read on to find out!

## Creating The JAR That Will Be Used To Generate The Native Image

Before we can create our native image, we'll need a JAR file from our Java code. In this case, I'll be showing you my CI/CD workflow from my GitHub Actions pipeline, but these steps can certainly be modified for whatever build tool your organization uses assuming it supports running the build the OS that you specify. Our overall build will have several "jobs" involved and the first one will be to create our JAR file. 

**But I Don't Use Java!  **That's OK! GraalVM native images can be created from just about any JVM language: Scala, Clojure, Kotlin, and even Groovy (with some extra work). Read [the docs](https://www.graalvm.org/docs/reference-manual/native-image/) for more info!

We'll run this job on an Ubuntu runner - though it doesn't matter for this step which OS you use for the VM runner.
```yaml
build-jar-job:
    name: 'Build JAR'
    runs-on: ubuntu-latest
    steps:
```



To get started, we'll check out the code, make sure that the runner is configured for Java 11 and then build our JAR:
```yaml
- name: 'Checkout'
  uses: actions/checkout@v2

- name: 'Setup Java 11'
  uses: actions/setup-java@v1
  with:
    java-version: 11

- name: 'Build JAR'
  run: |
    ./gradlew shadowJar
```



Not bad so far. Next, let's grab the version number from our Gradle properties and "publish" the JAR. In this context, publishing the JAR will result in an artifact being attached to our build that can be downloaded later on. This is not a proper (or public) "release", just an artifact of the build.
```yaml
- name: 'Get Version Number'
  run: |
    echo "::set-env name=VERSION::$(./gradlew properties -q | grep "version:" | awk '{print $2}')"

- name: 'Publish JAR'
  uses: actions/upload-artifact@v2-preview
  with:
    name: 'simple-socket-fn-logger-${{env.VERSION}}-all.jar'
    path: build/libs/*-all.jar
```



Now we'll handle the actual "release" part. This is how we get a proper tagged release (like the ones you see in the screenshot above) that can be downloaded by anyone on GitHub. Notice the conditional logic - this allows me to prevent the release unless it's an actual tagged release (allowing me to test the build without making a true release).
```yaml
- name: 'Create Release'
  if: contains(github.ref, 'v')
  id: create_release
  uses: actions/create-release@v1
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
  with:
    tag_name: ${{github.ref}}
    release_name: Release ${{github.ref}}
    body: |
      Initial release
    draft: false
    prerelease: false
```



We've **created** a release, but we haven't yet uploaded any assets to the release. Let's do that now, adding our JAR file to the tagged release.
```yaml
- name: 'Upload Release Asset'
  if: contains(github.ref, 'v')
  id: upload-release-asset
  uses: actions/upload-release-asset@v1
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
  with:
    upload_url: ${{steps.create_release.outputs.upload_url}}
    asset_path: build/libs/simple-socket-fn-logger-${{env.VERSION}}-all.jar
    asset_name: simple-socket-fn-logger-${{env.VERSION}}-all.jar
    asset_content_type: application/java-archive
```



Now we've got a public release and our additional jobs can download the published artifact and use it. But wait, since these jobs don't share any context we'll need to publish our release URL so they can know where they need to upload their assets to as well!
```yaml
- name: 'Write Upload URL To File'
  if: contains(github.ref, 'v')
  run: |
    echo "${{steps.create_release.outputs.upload_url}}" > upload_url.txt

- name: 'Publish Upload URL'
  if: contains(github.ref, 'v')
  uses: actions/upload-artifact@v2-preview
  with:
    name: 'upload_url.txt'
    path: 'upload_url.txt'
```



Excellent. We're ready to create our native images!

## Creating The Linux Image

Right, so now we can add a job to create our Linux native image using the GraalVM native image tool. We'll need to depend on the previous job so that this job doesn't run until that one is finished (after all, you can't create a native image if the JAR hasn't been published). Also, since we're creating a Linux image, we'll run it on an Ubuntu runner.
```yaml
build-linux-image:
  needs: [build-jar-job]
  name: 'Build Linux Image'
  runs-on: ubuntu-latest
  steps:
```



Checkout the code again (we'll need it to grab our version number) and set up Java 11:
```yaml
- name: 'Checkout'
  uses: actions/checkout@v2'

- name: 'Setup Java 11'
  uses: actions/setup-java@v1
  with:
    java-version: 11
```



Now we'll need to setup GraalVM and then add the `native-image` plugin. Luckily, there's an [awesome GitHub Action that we can use to help with getting Graal setup](https://github.com/marketplace/actions/setup-graalvm-environment) and once that's done we can use `gu` to install the plugin.
```yaml
- name: 'Setup GraalVM Environment'
  uses: DeLaGuardo/setup-graalvm@2.0
  with:
    graalvm-version: '20.1.0.java11'

- name: 'Install Native Image Plugin'
  run: |
    gu install native-image
```



Now we'll grab our version number again, download the previously published JAR artifact, and the release URL text file and set the release URL into an environment variable.
```yaml
- name: 'Get Version Number'
  run: |
    echo "::set-env name=VERSION::$(./gradlew properties -q | grep "version:" | awk '{print $2}')"

- name: 'Get JAR Artifact'
  uses: actions/download-artifact@v2-preview
  with:
    name: 'simple-socket-fn-logger-${{env.VERSION}}-all.jar'

- name: 'Download Release URL'
  if: contains(github.ref, 'v')
  uses: actions/download-artifact@v2-preview
  with:
    name: 'upload_url.txt'

- name: 'Set Upload URL Env Var'
  if: contains(github.ref, 'v')
  run: |
    echo "::set-env name=UPLOAD_URL::$(cat upload_url.txt)"
```



And now for the image creation magic. We use the native image tool with a few flags and we pass it our JAR file to use to create the image.
```yaml
- name: 'Build Linux Image'
        run: |
          native-image --no-server --no-fallback -H:ReflectionConfigurationResources=reflection-config.json -H:IncludeResources=logback.xml --allow-incomplete-classpath -jar simple-socket-fn-logger-${{env.VERSION}}-all.jar
```



Finally, we publish the image and release it (if necessary):
```yaml
- name: 'Publish Linux Image'
  if: success()
  uses: actions/upload-artifact@v2-preview
  with:
    name: 'simple-socket-fn-logger-${{env.VERSION}}-linux'
    path: 'simple-socket-fn-logger-${{env.VERSION}}-all'

- name: 'Upload Linux Image Asset'
  if: success() && contains(github.ref, 'v')
  id: upload-release-asset
  uses: actions/upload-release-asset@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    upload_url: ${{ env.UPLOAD_URL }}
    asset_name: 'simple-socket-fn-logger-${{env.VERSION}}-linux'
    asset_path: 'simple-socket-fn-logger-${{env.VERSION}}-all'
    asset_content_type: application/octet-stream
```



## Creating The macOS Image

The next step in our cross-platform compatible campaign is to create a native image that works on macOS. Luckily, GitHub Actions offers us a macOS runner that we can use for that purpose. Here's the entire job to create the macOS native image:
```yaml
build-macos-image:
  needs: [build-jar-job]
  name: 'Build macOS Image'
  runs-on: macOS-latest
  steps:
    - name: 'Checkout'
      uses: actions/checkout@v2
    - name: 'Setup Java 11'
      uses: actions/setup-java@v1
      with:
        java-version: 11
    - name: 'Setup GraalVM Environment'
      uses: DeLaGuardo/setup-graalvm@2.0
      with:
        graalvm-version: '20.1.0.java11'
    - name: 'Install Native Image Plugin'
      run: |
        gu install native-image
    - name: 'Get Version Number'
      run: |
        echo "::set-env name=VERSION::$(./gradlew properties -q | grep "version:" | awk '{print $2}')"
    - name: 'Get JAR Artifact'
      uses: actions/download-artifact@v2-preview
      with:
        name: 'simple-socket-fn-logger-${{env.VERSION}}-all.jar'
    - name: 'Get Release URL'
      if: contains(github.ref, 'v')
      uses: actions/download-artifact@v2-preview
      with:
        name: 'upload_url.txt'
    - name: 'Get Upload URL'
      if: contains(github.ref, 'v')
      run: |
        echo "::set-env name=UPLOAD_URL::$(cat upload_url.txt)"
    - name: 'Build Mac OS Image'
      run: |
        native-image --no-server --no-fallback -H:ReflectionConfigurationResources=reflection-config.json -H:IncludeResources=logback.xml --allow-incomplete-classpath -jar simple-socket-fn-logger-${{env.VERSION}}-all.jar
    - name: 'Publish Mac OS Image'
      if: success() && contains(github.ref, 'v')
      uses: actions/upload-artifact@v2-preview
      with:
        name: 'simple-socket-fn-logger-${{env.VERSION}}-macOS'
        path: 'simple-socket-fn-logger-${{env.VERSION}}-all'
    - name: 'Upload Mac OS Image Asset'
      if: success()
      id: upload-release-asset
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ env.UPLOAD_URL }}
        asset_name: 'simple-socket-fn-logger-${{env.VERSION}}-macOS'
        asset_path: 'simple-socket-fn-logger-${{env.VERSION}}-all'
        asset_content_type: application/octet-stream
```



If you look through this code you'll notice that it looks **very **similar to the steps that we took to create the Linux image above. In fact, the **only **difference here is the runner and a few references to the OS that are used as a "label" for the assets and artifacts and step names. If you're like me, you're starting to smell some code that is in desperate need of refactoring to avoid repeating itself. Let's fix this problem!

## Creating The Linux & macOS Image

GitHub Actions gives us the ability to use a build matrix to run the same steps based on multiple variables such as the runner OS and any other dependent variables.
```yaml
build-non-windows-image:
    name: 'Build Non-Windows Image'
    needs: [build-jar-job]
    strategy:
      matrix:
        os: ['ubuntu-latest', 'macos-latest']
        include:
          - os: 'ubuntu-latest'
            label: 'linux'
          - os: 'macos-latest'
            label: 'mac'
    runs-on: ${{matrix.os}}
```



Now when we run the build, this step will run twice - one for each OS in our matrix.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/04abc99d-f6b6-4b3a-9662-d8507b26c06a/file_1594312393613.png)

Now our steps, with some slight modification to use the proper label as necessary.
```yaml
steps:
      - name: 'Checkout'
        uses: actions/checkout@v2
      - name: 'Setup Java 11'
        uses: actions/setup-java@v1
        with:
          java-version: 11
      - name: 'Setup GraalVM Environment'
        uses: DeLaGuardo/setup-graalvm@2.0
        with:
          graalvm-version: '20.1.0.java11'
      - name: 'Install Native Image Plugin'
        run: |
          gu install native-image
      - name: 'Get Version Number'
        run: |
          echo "::set-env name=VERSION::$(./gradlew properties -q | grep "version:" | awk '{print $2}')"
      - name: 'Get JAR Artifact'
        uses: actions/download-artifact@v2-preview
        with:
          name: 'simple-socket-fn-logger-${{env.VERSION}}-all.jar'
      - name: 'Get Release URL'
        if: contains(github.ref, 'v')
        uses: actions/download-artifact@v2-preview
        with:
          name: 'upload_url.txt'
      - name: 'Get Upload URL'
        if: contains(github.ref, 'v')
        run: |
          echo "::set-env name=UPLOAD_URL::$(cat upload_url.txt)"
      - name: 'Build Native Image'
        run: |
          native-image --no-server --no-fallback -H:ReflectionConfigurationResources=reflection-config.json -H:IncludeResources=logback.xml --allow-incomplete-classpath -jar simple-socket-fn-logger-${{env.VERSION}}-all.jar
      - name: 'Publish Native Image'
        if: success()
        uses: actions/upload-artifact@v2-preview
        with:
          name: 'simple-socket-fn-logger-${{env.VERSION}}-${{matrix.label}}'
          path: 'simple-socket-fn-logger-${{env.VERSION}}-all'
      - name: 'Release Native Image Asset'
        if: success() && contains(github.ref, 'v')
        id: upload-release-asset
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        with:
          upload_url: ${{env.UPLOAD_URL}}
          asset_name: 'simple-socket-fn-logger-${{env.VERSION}}-${{matrix.label}}'
          asset_path: 'simple-socket-fn-logger-${{env.VERSION}}-all'
          asset_content_type: application/octet-stream
```



Notice, for example, the use of the `$}` and `$}` tokens which are substituted as appropriate.

## Creating The Windows Image

When it comes to creating a Windows image, things are a little different. And to be honest, it's been a few years since I've used Windows so I found it a little more difficult. I actually lucked into finding a [really good example in a Micronaut repo on GitHub](https://github.com/micronaut-projects/micronaut-starter/blob/6d0ae45ca262f3b76003e3b225217fcbeec55714/.github/workflows/mn-windows-snapshot.yml) and just about everything you see below is a direct copy of that workflow since I'm not very experienced with PowerShell. Since the process for the Windows image is fundamentally different (using PowerShell vs. Bash commands) I added the Windows image creation as it's own job in the pipeline. Here's what the entire job looks like for Windows, but it follows the same exact process as the Linux and macOS job above.
```yaml
build-windows-image:
  needs: [build-jar-job]
  name: 'Build Windows Image'
  runs-on: windows-latest
  steps:
    - name: 'Checkout'
      uses: actions/checkout@v1
    - name: 'Download GraalVM'
      run: |
        Invoke-RestMethod -Uri https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-20.1.0/graalvm-ce-java11-windows-amd64-20.1.0.zip -OutFile 'graal.zip'
    - name: 'Install GraalVM'
      run: |
        Expand-Archive -path 'graal.zip' -destinationpath '.'
    - name: 'Install Native Image'
      run: |
        graalvm-ce-java11-20.1.0\bin\gu.cmd install native-image
    - name: 'Set up Visual C Build Tools Workload for Visual Studio 2017 Build Tools'
      run: |
        choco install visualstudio2017-workload-vctools
    - name: 'Get Version Number'
      run: |
        echo "::set-env name=VERSION::$(./gradlew properties -q | grep "version:" | awk '{print $2}')"
      shell: bash
    - name: 'Get JAR Artifact'
      uses: actions/download-artifact@v2-preview
      with:
        name: 'simple-socket-fn-logger-${{env.VERSION}}-all.jar'
    - name: 'Build Native Image'
      shell: cmd
      env:
        JAVA_HOME: ./graalvm-ce-java11-20.1.0
      run: |
        call "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
        ./graalvm-ce-java11-20.1.0/bin/native-image --no-server --no-fallback -H:ReflectionConfigurationResources=reflection-config.json -H:IncludeResources=logback.xml -H:Name=simple-socket-fn-logger-${{env.VERSION}}-all --allow-incomplete-classpath -jar simple-socket-fn-logger-${{env.VERSION}}-all.jar
    - name: 'Get Release URL'
      if: contains(github.ref, 'v')
      uses: actions/download-artifact@v2-preview
      with:
        name: 'upload_url.txt'
    - name: 'Get Upload URL'
      if: contains(github.ref, 'v')
      run: |
        echo "::set-env name=UPLOAD_URL::$(cat upload_url.txt)"
      shell: bash
    - name: 'Publish Windows Image'
      if: success()
      uses: actions/upload-artifact@v2-preview
      with:
        name: 'simple-socket-fn-logger-${{env.VERSION}}-windows.exe'
        path: 'simple-socket-fn-logger-${{env.VERSION}}-all.exe'
    - name: 'Release Windows Image Asset'
      if: success() && contains(github.ref, 'v')
      id: upload-release-asset
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
      with:
        upload_url: ${{env.UPLOAD_URL}}
        asset_name: 'simple-socket-fn-logger-${{env.VERSION}}-windows.exe'
        asset_path: 'simple-socket-fn-logger-${{env.VERSION}}-all.exe'
        asset_content_type: application/octet-stream
```



The end result is a published artifact and, if tagged, a released Windows executable.

## Summary

In this post, we learned how to take a single JAR file from a Java project and create three distinct executable files with GitHub Actions that can be run on Windows, Linux, and macOS using GraalVM's native-image plugin. If you would like to learn more about GraalVM, including its support for polyglot applications and the performant JIT compiler, [check the documentation](https://www.graalvm.org/docs/). And as always, leave a comment below if you have any questions! 

**Where's The Code? **If you're interested in seeing the complete code from this blog post, check out the repository on GitHub: <https://github.com/recursivecodes/simple-socket-fn-logger>. Specifically, the entire workflow YAML configuration is available here: <https://github.com/recursivecodes/simple-socket-fn-logger/blob/master/.github/workflows/simple-socket-fn-logger.yaml>

Image by [OpenClipart-Vectors](https://pixabay.com/users/OpenClipart-Vectors-30363/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=158063) from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=image&utm_content=158063)
