---
title: "Getting Your Feet Wet With OCI Streams"
slug: "getting-your-feet-wet-with-oci-streams"
author: "Todd Sharp"
date: 2019-03-14
summary: "A tutorial for getting started working with Oracle Cloud Infrastructure Streaming which is a new service for consuming and producing high-volume streams of data."
tags: ["Cloud", "Developers", "Java"]
keywords: "Streams, Java, Groovy, Cloud, OCI"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b2710025-0900-4f3e-b0f1-4067fe8067d1/banner_2019_03_14_11_13_42.png"
---

Back in December [we announced](https://blogs.oracle.com/cloud-infrastructure/announcing-oracle-cloud-infrastructure-streaming) the development of a new service on Oracle Cloud Infrastructure called Streaming.  The announcement, [product page](http://cloud.oracle.com/en_US/streaming) and [documentation](https://docs.cloud.oracle.com/iaas/Content/Streaming/Concepts/streamingoverview.htm) have a ton of use cases and information on **why** you might use Streaming in your applications, so let's take a look at the **how**.  The OCI Console allows you to create streams and test them out via the UI dashboard, but here's a simple example of how to both publish and subscribe to a stream in code via the OCI [Java SDK](https://github.com/oracle/oci-java-sdk).

First you'll need to create a stream.  You can do that via the SDK, but it's pretty easy to do via the OCI Console.  From the sidebar menu, select Analytics - Streaming and you'll see a list of existing streams in your tenancy and selected compartment.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b2710025-0900-4f3e-b0f1-4067fe8067d1/2019_03_14_11_13_42.png)

Click 'Create Stream' and populate the dialog with the information requested:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b2710025-0900-4f3e-b0f1-4067fe8067d1/2019_03_14_11_21_05.png)

After your stream has been created you can view the Stream Details page, which looks like this:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/b2710025-0900-4f3e-b0f1-4067fe8067d1/2019_03_14_11_23_41.png)

As I mentioned above, you can test out stream publishing by clicking 'Produce Test Message' and populating the message and then test receiving by refreshing the list of 'Recent Messages' on the bottom of the Stream Details page.

To get started working with this stream in code, download the Java SDK (link above) and make sure it's on your classpath.  After you've got the SDK ready to go, create an instance of a [StreamClient](https://docs.cloud.oracle.com/iaas/tools/java/latest/com/oracle/bmc/streaming/StreamClient.html) which will allow you to make both 'put' and 'get' style requests.  Producing a message to the stream looks like so:
```groovy
ConfigFileAuthenticationDetailsProvider provider =  new ConfigFileAuthenticationDetailsProvider('/path/to/.oci/config', 'DEFAULT')
StreamClient client = new StreamClient(provider)
String key = 'Key'
String msg = 'Message'

PutMessagesDetails putMessageDetails = PutMessagesDetails.builder()
    .messages([
        PutMessagesDetailsEntry.builder()
            .key(key.getBytes(Charset.forName("UTF-8")))
            .value(msg.getBytes(Charset.forName("UTF-8")))
            .build()
    ])
    .build()
PutMessagesRequest putMessageRequest = PutMessagesRequest.builder()
    .streamId(this.streamId)
    .putMessagesDetails(putMessageDetails)
    .build()
client.putMessages(putMessageRequest)
```



Reading the stream requires you to work with a [Cursor](https://docs.cloud.oracle.com/iaas/tools/java/latest/com/oracle/bmc/streaming/model/Cursor.html).  I like to work with group cursors, because they handle auto committing so I don't have to manually commit the cursor, and here's how you'd create a group cursor and use it to get the stream messages.  In my application I have it in a loop and reassign the cursor that is returned from the call to client.getMessages() so that the cursor always remains open and active.
```groovy
ConfigFileAuthenticationDetailsProvider provider =  new ConfigFileAuthenticationDetailsProvider('/path/to/.oci/config', 'DEFAULT')
StreamClient client = new StreamClient(provider)
AtomicBoolean closed = new AtomicBoolean(false)

CreateGroupCursorDetails cursorDetails = CreateGroupCursorDetails.builder(
        .type(CreateGroupCursorDetails.Type.TrimHorizon)
        .commitOnGet(true)
        .groupName(this.groupName)
        .build()
CreateGroupCursorRequest groupCursorRequest = CreateGroupCursorRequest.builder()
        .streamId(streamId)
        .createGroupCursorDetails(cursorDetails)
        .build()

CreateGroupCursorResponse cursorResponse = this.client.createGroupCursor(groupCursorRequest)

GetMessagesRequest getRequest = GetMessagesRequest.builder()
        .cursor(cursorResponse.cursor.value)
        .streamId(this.streamId)
        .build()

while(!closed.get()) {
    def getResult = this.client.getMessages(getRequest)
    getResult.items.each { Message record ->
        def msg = new String(record.value, "UTF-8")
    }
    getRequest.cursor = getResult.opcNextCursor
    sleep(500)
}
```



And that's what it takes to create a stream, produce a message and read the messages from the stream.  It's not a difficult feature to implement and the performance is comparable to Apache Kafka in my observations, but it's nice to have a native OCI offering that integrates well into my application.  There are also future integration plans for upcoming OCI services that will eventually allow you to publish to a stream, so stay tuned for that.
