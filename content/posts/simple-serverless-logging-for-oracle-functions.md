---
title: "Simple Serverless Logging For Oracle Functions"
slug: "simple-serverless-logging-for-oracle-functions"
author: "Todd Sharp"
date: 2020-06-17
summary: "In this post, we'll look at the available options for logging output from your serverless Oracle Functions."
tags: ["Cloud", "Java", "Open Source"]
keywords: "serverless, logging, debugging"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/banner_sven_scheuermeier_jnu5eivnyge_unsplash.jpg"
---

Working with serverless functions represents a new way of thinking for many developers. Dealing with stateless functions, for example, can be a challenge to developers who may be used to stateful applications. Another major challenge when creating and deploying serverless functions is the lack of insight into the running function in production. I know from experience that it can sometimes feel like throwing your code over a wall into the abyss.  When working with Oracle Functions (our FaaS hosted offering built on the Fn project) how many times have you deployed and invoked your function only to receive the dreaded response:

***Error invoking function. status: 502 message: function failed***

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/not_helpful.gif)

Yeah, that can be really frustrating. I've had many people contact me via email and Slack after trying unsuccessfully to debug a deployed function and ask if I had any advice on how to debug their functions and each time I've recommended that they implement a logging policy for their serverless application. You might not have even known this existed, but today we're going to take a deep dive so get ready to learn all you ever wanted to about serverless function logging!

## Serverless Logging

By default, when you create an application in the Oracle Cloud to group your serverless functions, your logging policy is set to "none". It doesn't matter if you create your function via the CLI or the console dashboard, it always defaults to none. This is fair - you wouldn't want to incur charges for logging to object storage and there's no way of knowing where to log to, so a default of "none" is the most logical choice.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/file_1592407230478.png)

## Logging To Object Storage

Going without any logging policy is certainly brave, but you probably need a plan in place to debug when things invariably go sideways. The [official docs](https://docs.cloud.oracle.com/en-us/iaas/Content/Functions/Tasks/functionstroubleshooting.htm#InvokingafunctionreturnsaFunctionInvokeSyslogUnavailablemessageanda502error) have [plenty to say](https://docs.cloud.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsexportingfunctionlogfiles.htm) about logging to Object Storage. I'll assume you've read those docs and have the proper policies in place if you need them. To enable this option, and I know you're going to be one step ahead of me here, but to enable it, just select 'Log To Object Storage'.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/file_1592407711562.png)

This **technically** works, and for production functions, I would say it is an acceptable option. But it can be kind of slow (some users have reported it takes up to 15 minutes for the debug output to get logged to Object Storage) so for realtime debugging it's not an option.

## Logging To Papertrail

The third option, logging to a third-party provider via a 'SYSLOGURL' is also covered in the docs. They specifically call out [Papertrail](https://papertrail.com) which is an excellent and easy to use application. You sign up for an account (there are free options) and configure an endpoint.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/file_1592408379320.png)

Then paste your Papertrail URL in as the SYSLOGURL for your functions application.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/file_1592408433221.png)

Papertrail has a nice UI that provides your log output in near real-time. They also have a number of filters, search capabilities and archiving for older log events.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/file_1592408865356.png)

It's a great option - probably the best of the three options provided above, but there's another option for logging that I didn't realize until last week.

## Homemade Socket Server

I was having a conversation with someone internally at Oracle where I introduced him to Papertrail and he asked me if I had a paid account for the service. I told him that I used the free account because 50MB a month is more than enough for my demo usages. But something hit me as I was looking at the console dashboard for one of my functions (and I'm not really sure why it took me so long to figure this out, but that's OK). I was looking at the Papertrail endpoint - `tcp://...` - when it hit me.

> "Hey, that's just a socket server. I can create one of those in like 50 lines of Java! I wonder if that would work?"

About an hour later, I had scratched together a simple socket server and tested it out with some functions enough to prove that it certainly was possible, and it might be even better than using a third-party like Papertrail. I decided to take a few more days to clean things up and make a proper project out of it, and the end result of that work is [now available on GitHub](https://github.com/recursivecodes/simple-socket-fn-logger). I plan on blogging a bit more about some of the code behind the project because I think it's really cool that I'm able to create 4 [different distributions](https://github.com/recursivecodes/simple-socket-fn-logger/releases) from the same codebase: a JAR file that can be run on any Java 11 JVM, a Linux native image, a Mac OS native image and a Windows executable. For now, let's look at the Java code and how the server can be run from the JAR distribution.

### Using The Server

If you're not interested in compiling it yourself, you can simply run the pre-compiled JAR by downloading it from the GitHub release page and running the following command in your favorite terminal:
```bash
$ java -jar simple-socket-fn-logger-1.0.0-all.jar
```



Once it's running, you can use your public IP and the default port of `30000` as your SYSLOGURL! 
```bash
$ fn update app syslog-demo-app --syslog-url tcp://[your public IP]:[socket server port]
```



![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/9f911b70-4a7f-4834-907f-e294361d8ff4/2020_06_17_12_29_18__1_.gif)

**Note:  **You'll need to make sure that your firewall is properly exposing the socket server port in order to receive the incoming messages. This could be your home router if you are running locally, or a VCN security list or VM firewall.

### How It Works

As I said, the code behind this tool is quite simple. It's just a Java application with a static void main that establishes the socket server and contains an infinite loop waiting for incoming connections. Once a new connection is established, it creates a new thread to handle logging the input from the connection.
```java
public static void main(String[] args) throws IOException {
    Logger logger = LoggerFactory.getLogger(Main.class);
    int port = Integer.parseInt( System.getProperty("port", "30000") );
    socketServer = new ServerSocket(port);
    logger.info("Listening on localhost:{}...", port);
    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
        logger.info("Server shutting down. Goodbye...");
        try {
            socketServer.close();
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }));
    //noinspection InfiniteLoopStatement
    while(true) {
        Socket socket = socketServer.accept();
        Runnable messageHandler = new MessageHandler(socket);
        new Thread(messageHandler).start();
    }
}
```



The `MessageHandler` class implements `Runnable` and handles the logging of the incoming data. The only dependency in the project is on a library to parse the Syslog formatted data.
```java
public class MessageHandler implements Runnable {
    private final Socket clientSocket;
    private final SyslogParser parser = new SyslogParserBuilder().build();
    private final Logger logger = LoggerFactory.getLogger(Main.class);
    public MessageHandler(Socket clientSocket) {
        this.clientSocket = clientSocket;
    }
    public void run() {
        BufferedReader reader = null;
        try {
            reader = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
        } catch (IOException e) {
            e.printStackTrace();
        }
        String incomingMsg;
        try{
            while( (incomingMsg = reader.readLine()) != null ) {
                Map<String, Object> result = parser.parseLine(incomingMsg);
                logger.info( result.get("syslog.message").toString() );
            }
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }
}
```



We're outputting just the incoming message text, but the incoming message contains a lot of additional information. The `MessageHandler` class can easily be extended to log this data to an Autonomous DB instance or send notifications based on the severity or message contents. Here's an example of the message object:
```json
{
    "syslog.header.appName": "app_id=ocid1.fnapp.oc1.phx...,fn_id=ocid1.fnfunc.oc1.phx...",
    "syslog.header.version": "1",
    "syslog.header.hostName": "runner-00001700e5f9",
    "syslog.header.facility": "1",
    "syslog.header.msgId": "app_id=ocid1.fnapp.oc1.phx...,fn_id=ocid1.fnfunc.oc1.phx...",
    "syslog.header.timestamp": "2020-06-15T14:46:35Z",
    "syslog.message": "Error in function: ReferenceError: foo is not defined",
    "syslog.header.pri": "11",
    "syslog.header.procId": "8",
    "syslog.header.severity": "3"
}
```



## Next Steps

Feel free to download the tool and use it locally - or fork the project, modify it to persist the log data, and run it on a VM in the Oracle Cloud! 

**Heads Up!! **If you're running the tool locally, you must remove the SYSLOGURL from your functions application when you are not running the server, otherwise, your functions will return ***Error invoking function. status: 502 message: Syslog endpoint unavailable***!

For more information, check the README on GitHub. Leave a comment below if you have any questions.

The full code from this blog post can be found on GitHub: <https://github.com/recursivecodes/simple-socket-fn-logger>

Photo by [Sven Scheuermeier](https://unsplash.com/@sveninho?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](/?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
