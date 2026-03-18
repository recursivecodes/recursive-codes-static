---
title: "Create a Custom MCP Server for Working with AWS Services - Managing Your Resources"
slug: "create-a-custom-mcp-server-for-working-with-aws-services-managing-your-resources-4o3c"
author: "Todd Sharp"
date: 2025-04-09T13:45:12Z
summary: "In my last post, I showed how the Model Context Protocol (MCP) can help us to create tools to solve..."
tags: ["aws", "amazonivs", "mcp", "genai"]
canonical_url: "https://dev.to/aws/create-a-custom-mcp-server-for-working-with-aws-services-managing-your-resources-4o3c"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-56w0wztrti5j9x5fe0sn.png"
imagecontain: true
---

In my last post, I showed how the Model Context Protocol (MCP) can help us to create tools to solve domain specific problems with amazing results. Although this short series is focused on Amazon Interactive Video Service (Amazon IVS), you should keep in mind that this approach can be applied to create solutions for literally any area of focus. Want to learn more about a different AWS service? No problem ✅! Just change up the tools to use a different AWS SDK! Want to create a server to expose your golf league database that can be used with a client to get deep insight into your golfer's🏌️‍♂️ and matches? Sure thing! Point a custom MCP server at your DB (or use an [off the shelf MCP server](https://github.com/punkpeye/awesome-mcp-servers))!

In this post, we'll look at how I created an MCP Server that knows about the Amazon IVS resources in my account. The server also has access to a simple RAG knowledge base that contains some public IVS documentation scraped from the web, and has a few other tools and utilities to help along the way. Here's a diagram that gives you a high level view of the overall solution, that we'll break it down throughout this post and the next one.

![IVS MCP Arch Overview](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-e36xute9xpxkhiyuuthx.png)

## Creating an MCP Server

There are already plenty of [resources](https://modelcontextprotocol.io/) online to help you learn about creating your first MCP server. This [doc](https://github.com/modelcontextprotocol) gives you a good starting point to find an SDK for your favorite language. For this demo, I'll be using the [TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk) to create the server.

> 💡**Note:** We'll walk through some of the steps to create an IVS MCP Server in this post. The full sample server code for a basic Amazon IVS MCP server can be found at the [bottom of this post](#sample-mcp-server).

The first step to creating our custom Amazon IVS MCP server is to create a project and install the MCP SDK.

```bash
npm init es6 -y
npm install @modelcontextprotocol/sdk
```

Next, create `src/index.js`. In this file, we'll import the SDK and the `stdio` transport and then create the server.

```js
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
const server = new McpServer({
  name: "IVS-MCP-Server",
  version: "1.0.0",
});
```

For this server, we'll use stdio (there is also an option to use HTTP with SSE). Let's create the `StdioServerTransport` and start the server.

```js
const transport = new StdioServerTransport();
await server.connect(transport);
```

At this point, the server is created. It doesn't do anything yet, but it's ready to go. We can test it at any point using the MCP Inspector app by running: `npx @modelcontextprotocol/inspector node src/index.js`. Here's how the inspector looks:

![MCP Inspector](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-eawn5v5q99s9zka3v58f.png)

Clicking 'Connect' will connect to the server, but since we haven't defined any tools or resources yet, it won't be very helpful.

### Creating MCP Server Tools for Amazon IVS

The model context protocol defines a number of different concepts that serve different purposes - from tools and resources to prompts and roots. Again, check the [documentation](https://modelcontextprotocol.io/introduction) to learn about each of these concepts. However, not all clients can utilize every one of these concepts. For this implementation, we'll focus on `tools` because there is great support for tool usage with Amazon Bedrock (as we'll see in a future post) and tools are a great way to retrieve dynamic data. Since we're focusing on Amazon IVS with this server, we'll start by adding a set of tools to retrieve Amazon IVS specific data via the various modules within the AWS SDK for JavaScript (v3).

![MCP Server->IVS](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-n1j4rs5josyztkhc9c9y.png)

First, let's install the Amazon IVS client modules for low-latency, real-time and chat. We will also add a library to convert HTML to Markdown that will be used later on.

```bash
$ npm install @aws-sdk/client-ivs @aws-sdk/client-ivs-realtime @aws-sdk/client-ivschat node-html-markdown
```

Now we can create an instance of the `IvsClient` that will be used in our tools. As usual, hard coding credentials in an application is a terrible idea, so we'll use environment variables to pass in our AWS credentials.

```js
import { IvsClient, ListChannelsCommand } from "@aws-sdk/client-ivs";
import { z } from "zod";

const config = {
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
};

const ivsClient = new IvsClient(config);
```

To define a tool, we can call `server.tool()` on our server. This method accepts a tool name, description, parameter definitions and a callback that is invoked when the tool is called from a client.

> 💡 **Tip:** It's a good idea to give good names and provide accurate important descriptions when working with MCP to give the LLM enough context to determine when it is appropriate to call a specific tool.

Let's create our first tool that can list the Amazon IVS low-latency channels in our AWS account. This tool has three optional input parameters: `nextToken`, `maxResults`, and `name`. Again we focus on providing a good description for each param, so that the LLM can determine when and what to pass if it needs to do so.

```js
server.tool(
  "list-channels",
  "List all of the IVS channels for this account. Returns paginated results with a default max of 10.",
  {
    nextToken: z.string().optional().describe("The token for the next page of results"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
    name: z.string().optional().describe("The name of the channel to search for"),
  },
  async (params) => {
    const input = {};
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    Object.assign(input, params?.name ? { filterByName: params.name } : {});
    const command = new ListChannelsCommand(input);
    const listChannelsResponse = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listChannelsResponse) }],
    };
  },
);
```

Now we can connect with the MCP Inspector and click on 'Tools', then 'List Tools' and select our `list-channels` tool.

![MCP Tool List](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-mzhj6dyuiptjce3u3abw.png)

Enter any values for the optional parameters and click 'Run Tool' to see the results.

![MCP Tool Result](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-z9s3x3smrl5ymn9uizqi.png)

At this point, you might be thinking: "hey, this is just a thin wrapper around an SDK". And you're right. There's nothing really magical 🧙‍♂️🪄 going on here. The only "magic" here is following the protocol. We're just defining our tools and parameters in a standardized way and exposing them via a standardized interface. In a way, it's kinda like SOAP 🧼😂 (see '[The S Stands for Simple](https://www.shlomifish.org/humour/by-others/s-stands-for-simple/)'). Sorry kids, Gen X developer moment there. Back on topic...

It seems simple, but what we've done here is brilliant in its simplicity. When a client knows about this server, we can ask it questions about our _own personal_ data and have it give us insight, find patterns, discover anomalies, find unused resources - the only limitation is our implementation. But I'm getting ahead of myself. For now, this MCP Server needs additional tools to expose other methods of the SDK. For my IVS server, I decided upon the following IVS low-latency specific tools.

- `list-channels`
- `get-channel`
- `batch-get-channels`
- `get-stream`
- `get-recording-configuration`
- `list-stream-sessions`
- `get-stream-session`
- `get-playback-restriction-policy`
- `get-encoder-configuration`
- `get-ingest-configuration`
- `create-channel`
- `list-stream-keys`
- `get-stream-key`
- `get-low-latency-stream-health-metrics`
- `create-ingest-configuration`
- `create-encoder-configuration`

I also added a bunch of tools for real-time stages:

- `create-stage`
- `list-stages`
- `get-stage`
- `list-participants`
- `get-participant`
- `list-stage-sessions`
- `get-stage-session`
- `get-real-time-stage-health-metrics`

And IVS chat:

- `list-rooms`
- `get-room`
- `get-logging-configuration`

As you can see above, I've included tools that can create resources in my Amazon IVS account (`create-channel`, `create-stage`, etc). I'm still not sure if this is a great idea or not. On one hand, it could be easy enough to ask a client that connects to this server to generate the necessary code to create these resources for me and manually run that code. In the end, your use case and requirements will dictate whether or not you decide to include these tools, but I've included them in this server to demonstrate the proof-of-concept. As always, make sure you're fully aware of the impact of using such tools in production and properly secure all of the code that you run.

> 🌟 **Bonus Tip:** If you've installed the [Amazon Q Developer extension in your IDE](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/q-in-IDE-setup.html), start by defining imports for all of the various tool operations that you're looking to create and let it create your tools for you. Once you've defined a single tool, it'll do a great job of using that format and its insight into the imported libraries to define the rest of your tools for you and save you a ton of time!

At this point, if we connect a client with MCP support to our server, we can get valuable insight into our AWS account. For example:

> give me an overview of my ivs channels

```mkd
I see you have multiple IVS channels in your account. Let me provide an overview of these channels:

### Your IVS Channels (First 10):

1. **[channel-1]**
   - Type: STANDARD
   - Latency Mode: LOW
   - Authorization required: No
   - Recording configuration: None

2. \*_[channel-2]_
   - Type: STANDARD
   - Latency Mode: LOW
   - Authorization required: No
   - Recording configuration: None

3. **[channel-3]**
   - Type: STANDARD
   - Latency Mode: LOW
   - Authorization required: No
   - Recording configuration: None
     ... removed for brevity

There appear to be additional channels, as there's a "nextToken" value in the response. Would you like me to fetch the next page of channels for you, or would you like more detailed information about any specific channel?
```

Which is nice, but not much different from calling `list-channels` manually via the SDK. We can go further though, asking it to summarize based on criteria, such as:

> how many channels have a recording configuration attached?

```mkd
After checking all your channels, here's a summary of channels with recording configurations:

## Channels with Recording Configurations: 3

1. **[redacted]**
   - Recording configuration: arn:aws:ivs:us-east-1:[redacted]:recording-configuration/[redacted]

2. **[redacted]**
   - Recording configuration: arn:aws:ivs:us-east-1:[redacted]:recording-configuration/[redacted]

3. **[redacted]**
   - Recording configuration: arn:aws:ivs:us-east-1:[redacted]:recording-configuration/[redacted]

## Total Channels: 13

None of the channels from the second page have recording configurations attached.

Out of your 13 total IVS channels, only 3 channels (approximately 23%) have recording configurations.

Would you like more information about these recording configurations or any other aspects of your IVS channels?
```

Now our client has the ability to get granular and specific data about our IVS account. When we take this further, and combine it with a custom knowledge base, we'll be able to get great insight into our IVS account and ultimately generate prototypes and code to interact with our resources.

### Stream and Stage Health Metrics

![IVS MCP -> CloudWatch](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-ueajt8076j0icac50ayx.png)

Since Amazon IVS logs channel and stage health metrics to CloudWatch, we can also add tools to query that metric data. Since the MCP server has the ability to retrieve stream and stage sessions, we can ultimately use a client to query for details or a summary about specific sessions. For this, we install the CloudWatch SDK.

```bash
npm install @aws-sdk/client-cloudwatch
```

And create a CloudWatch client:

```js
const cloudWatchClient = new CloudWatchClient(config);
```

And create tools to query the metric data that we're after. Here's a tool to get real-time stage metrics for a given period of time (descriptions are truncated to make things easier to read).

```js
server.tool(
  "get-real-time-stage-health-metrics",
  "Get IVS Real-Time stage health metrics",
  {
    arn: z.string().describe("The ARN..."),
    startTime: z
      .number()
      .optional()
      .default(new Date().setHours(new Date().getHours() - 1))
      .describe("The start time..."),
    endTime: z.number().optional().default(Date.now()).describe("The end time..."),
    streamHealthMetrics: z
      .array(z.enum(["Subscribers", "Publishers", "SubscribeBitrate", "DownloadPacketLoss", "DroppedFrames", "PublishBitrate"]))
      .optional()
      .default(["Subscribers", "Publishers", "SubscribeBitrate", "DownloadPacketLoss", "DroppedFrames", "PublishBitrate"])
      .describe("The stage health metrics to retrieve..."),
    period: z.number().optional().default(5).describe("The granularity..."),
  },
  async ({ arn, startTime, endTime, streamHealthMetrics, period }) => {
    startTime = new Date(startTime);
    endTime = new Date(endTime);
    const metricDataQueries = streamHealthMetrics.map((metric) => {
      return {
        Id: metric.toLowerCase(),
        MetricStat: {
          Metric: {
            MetricName: metric,
            Namespace: "AWS/IVSRealTime",
            Dimensions: [{ Name: "Stage", Value: arn.split("/")[1] }],
          },
          Period: period,
          Stat: "Average",
        },
      };
    });
    const getMetricDataInput = {
      StartTime: startTime,
      EndTime: endTime,
      MetricDataQueries: metricDataQueries,
      MaxDatapoints: 100,
    };
    const getMetricDataRequest = new GetMetricDataCommand(getMetricDataInput);
    const getMetricDataResponse = await cloudWatchClient.send(getMetricDataRequest);
    console.error(getMetricDataResponse);
    return {
      content: [{ type: "text", text: JSON.stringify(getMetricDataResponse) }],
    };
  },
);
```

If we used an MCP client to ask about the latest session on a specific real-time stage, we might get output like this:

```mkd
I've successfully retrieved the metrics for the latest session on demo-stage. Now I'll summarize this information for you:

## Summary of Stage Metrics for Latest Session on demo-stage

**Session Details:**

- **Session ID:** st-[redacted]
- **Start Time:** April 2, 2025, 18:11:53 UTC
- **End Time:** April 2, 2025, 19:00:38 UTC
- **Duration:** Approximately 49 minutes

**Key Performance Metrics:**

1. **Participants:**
   - **Publishers:** Consistently around 2 publishers throughout the session
   - **Subscribers:** Maintained around 2 subscribers with occasional fluctuations

2. **Bitrate Performance:**
   - **Publish Bitrate:** Averaged between 900,000 - 1,500,000 bps (0.9-1.5 Mbps)
   - **Subscribe Bitrate:** Averaged between 500,000 - 900,000 bps (0.5-0.9 Mbps)

3. **Quality Indicators:**
   - **Download Packet Loss:** Very minimal, mostly 0% with occasional spikes to 0.1%
   - **Dropped Frames:** Nearly zero throughout the session, with only two minor instances of frame drops

**Overall Assessment:**
The session shows stable performance with consistent publisher and subscriber counts. The bitrate was sufficient for good quality streaming, and the quality indicators suggest excellent network conditions with minimal packet loss and almost no dropped frames. The stage performed well during this 49-minute session with no significant issues detected.
```

## Creating Amazon IVS Resources

So far, we've looked at how to retrieve information about our Amazon IVS resources with a custom server. But we can also add functionality to create new resources if the client decides that the user is prompting them to do so. For example, to create a tool to create a low-latency channel we can create a `create-channel` tool. The descriptions have been truncated here for readability. See the full server example below for the full descriptions.

```js
server.tool(
  "create-channel",
  "Create a new IVS channel",
  {
    name: z.string().optional().describe("The name..."),
    latencyMode: z.enum(["LOW", "NORMAL"]).optional().default("LOW").describe("The latency mode...."),
    type: z.enum(["BASIC", "STANDARD", "ADVANCED_SD", "ADVANCED_HD"]).optional().default("STANDARD").describe("The type..."),
    authorized: z.boolean().optional().default(false).describe("Whether the channel..."),
    recordingConfigurationArn: z.string().optional().describe("The recording config..."),
    insecureIngest: z.boolean().optional().default(false).describe("Whether the channel..."),
    preset: z.enum(["HIGHER_BANDWIDTH_DELIVERY", "CONSTRAINED_BANDWIDTH_DELIVERY"]).optional().describe("Optional transcode..."),
    playbackRestrictionPolicyArn: z.string().optional().describe("The playback..."),
    containerFormat: z.enum(["FRAGMENTED_MP4", "TS"]).optional().default("TS").describe("The content-packaging ..."),
  },
  async ({ name, latencyMode, type, authorized, recordingConfigurationArn, insecureIngest, preset, playbackRestrictionPolicyArn, containerFormat, tags }) => {
    const input = {};
    Object.assign(input, name ? { name } : {});
    Object.assign(input, latencyMode ? { latencyMode } : {});
    Object.assign(input, type ? { type } : {});
    Object.assign(input, authorized ? { authorized } : {});
    Object.assign(input, recordingConfigurationArn ? { recordingConfigurationArn } : {});
    Object.assign(input, insecureIngest ? { insecureIngest } : {});
    Object.assign(input, preset ? { preset } : {});
    Object.assign(input, playbackRestrictionPolicyArn ? { playbackRestrictionPolicyArn } : {});
    Object.assign(input, containerFormat ? { containerFormat } : {});
    Object.assign(input, tags ? { tags } : {});

    const command = new CreateChannelCommand(input);
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);
```

<h2 id="sample-mcp-server">Sample MCP Server</h2>

Here is the full code for a basic Amazon IVS MCP server to help you learn how to get started creating your own custom server. This sample includes querying a Bedrock knowledge base and some additional utility tools which we'll talk about in the next post.

### Sample Server Code

{% details index.js %}

```js
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { NodeHtmlMarkdown } from "node-html-markdown";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { IvsClient, GetChannelCommand, ListChannelsCommand, GetStreamCommand, BatchGetChannelCommand, ListStreamKeysCommand, GetStreamKeyCommand, GetRecordingConfigurationCommand, GetStreamSessionCommand, ListStreamSessionsCommand, GetPlaybackRestrictionPolicyCommand, CreateChannelCommand } from "@aws-sdk/client-ivs";
import { IVSRealTimeClient, ListStagesCommand, GetStageCommand, ListParticipantsCommand, GetParticipantCommand, ListStageSessionsCommand, GetStageSessionCommand, CreateStageCommand, CreateEncoderConfigurationCommand, CreateIngestConfigurationCommand, GetIngestConfigurationCommand, GetEncoderConfigurationCommand } from "@aws-sdk/client-ivs-realtime";
import { CloudWatchClient, GetMetricDataCommand } from "@aws-sdk/client-cloudwatch";
import { IvschatClient, ListRoomsCommand, GetRoomCommand, GetLoggingConfigurationCommand } from "@aws-sdk/client-ivschat";
import { BedrockAgentRuntimeClient, RetrieveCommand } from "@aws-sdk/client-bedrock-agent-runtime";
import { z } from "zod";

const knowledgeBaseId = process.env.RAG_KNOWLEDGEBASE_ID;

const config = {
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
};

const ivsClient = new IvsClient(config);
const ivsRealTimeClient = new IVSRealTimeClient(config);
const ivsChatClient = new IvschatClient(config);
const bedrockAgentRuntimeClient = new BedrockAgentRuntimeClient(config);
const cloudWatchClient = new CloudWatchClient(config);

const server = new McpServer(
  {
    name: "IVS-MCP-Server",
    version: "1.0.0",
  },
  {
    capabilities: {
      logging: {},
    },
  },
);

// IVS Low-Latency Tools

// get-channel
server.tool(
  "get-channel",
  "Get IVS channel information",
  {
    arn: z.string().describe("The ARN of the IVS channel."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetChannelCommand({ arn: decodedArn });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// batch-get-channels
server.tool(
  "batch-get-channels",
  "Get detailed information about a batch of IVS channels. More efficient than calling `get-channel` separately for each channel.",
  {
    arns: z.array(z.string()).describe("The ARNs of the IVS channels."),
  },
  async ({ arns }) => {
    const decodedArns = arns.map((arn) => decodeURIComponent(arn));
    const command = new BatchGetChannelCommand({ arns: decodedArns });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-stream
server.tool(
  "get-stream",
  "Gets information about the active (live) stream on a specified channel including the streamId, health, state, startTime and viewerCount",
  {
    channelArn: z.string().describe("The ARN of the IVS channel."),
  },
  async ({ channelArn }) => {
    const decodedArn = decodeURIComponent(channelArn);
    const command = new GetStreamCommand({ channelArn: decodedArn });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// list-channels
server.tool(
  "list-channels",
  "List all of the IVS channels for this account. Returns paginated results with a default max of 10.",
  {
    nextToken: z.string().optional().describe("The token for the next page of results"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
    name: z.string().optional().describe("The name of the channel to search for"),
  },
  async (params) => {
    const input = {};
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    Object.assign(input, params?.name ? { filterByName: params.name } : {});
    const command = new ListChannelsCommand(input);
    const listChannelsResponse = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listChannelsResponse) }],
    };
  },
);

// get-recording-configuration
server.tool(
  "get-recording-configuration",
  "Get IVS recording configuration information",
  {
    arn: z.string().describe("The ARN of the IVS channel."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetRecordingConfigurationCommand({ arn: decodedArn });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-stream-session
server.tool(
  "get-stream-session",
  "Get IVS stream session information",
  {
    arn: z.string().describe("The ARN of the IVS channel."),
    sessionId: z.string().describe("The ID of the IVS stream session."),
  },
  async ({ arn, sessionId }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetStreamSessionCommand({ arn: decodedArn, id: sessionId });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// list-stream-sessions
server.tool(
  "list-stream-sessions",
  "List all of the IVS stream sessions for an IVS channel. Returns paginated results with a default max of 10.",
  {
    arn: z.string().describe("The ARN of the IVS channel."),
    nextToken: z.string().optional().describe("The token for the next page of results"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
  },
  async (params) => {
    const input = { channelArn: params.arn };
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    const command = new ListStreamSessionsCommand(input);
    const listStreamSessionsResponse = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listStreamSessionsResponse) }],
    };
  },
);

// get-playback-restriction-policy
server.tool(
  "get-playback-restriction-policy",
  "Get IVS playback restriction policy information",
  {
    arn: z.string().describe("The ARN of the IVS channel."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetPlaybackRestrictionPolicyCommand({ arn: decodedArn });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// create-channel
server.tool(
  "create-channel",
  "Create a new IVS channel",
  {
    name: z.string().optional().describe("The name of the channel to create."),
    latencyMode: z.enum(["LOW", "NORMAL"]).optional().default("LOW").describe("The latency mode of the channel to create. (default: LOW)"),
    type: z.enum(["BASIC", "STANDARD", "ADVANCED_SD", "ADVANCED_HD"]).optional().default("STANDARD").describe("The type of the channel to create. (default: BASIC)"),
    authorized: z.boolean().optional().default(false).describe("Whether the channel to create is authorized. (default: false)"),
    recordingConfigurationArn: z.string().optional().describe("The recording configuration ARN of the channel to create."),
    insecureIngest: z.boolean().optional().default(false).describe("Whether the channel to create is insecure ingest. (default: false)"),
    preset: z
      .enum(["HIGHER_BANDWIDTH_DELIVERY", "CONSTRAINED_BANDWIDTH_DELIVERY"])
      .optional()
      // .refine(data => ['ADVANCED_SD', 'ADVANCED_HD'].indexOf(data.type) === -1 || (['ADVANCED_SD', 'ADVANCED_HD'].indexOf(data.type) !== -1 && data.preset), {
      //   message: "Preset is required when type is 'ADVANCED_SD' or 'ADVANCED_HD'.",
      //   path: ['preset'] // Pointing out which field is invalid
      // })
      .describe('Optional transcode preset for the channel. This is selectable only for ADVANCED_HD and ADVANCED_SD channel types. For those channel types, the default preset is HIGHER_BANDWIDTH_DELIVERY. For other channel types (BASIC and STANDARD), preset is the empty string ("").'),
    playbackRestrictionPolicyArn: z.string().optional().describe("The playback restriction policy ARN of the channel to create."),
    containerFormat: z.enum(["FRAGMENTED_MP4", "TS"]).optional().default("TS").describe("The content-packaging format to be used with this channel. (default: TS)"),
  },
  async ({ name, latencyMode, type, authorized, recordingConfigurationArn, insecureIngest, preset, playbackRestrictionPolicyArn, containerFormat, tags }) => {
    const input = {};
    Object.assign(input, name ? { name } : {});
    Object.assign(input, latencyMode ? { latencyMode } : {});
    Object.assign(input, type ? { type } : {});
    Object.assign(input, authorized ? { authorized } : {});
    Object.assign(input, recordingConfigurationArn ? { recordingConfigurationArn } : {});
    Object.assign(input, insecureIngest ? { insecureIngest } : {});
    Object.assign(input, preset ? { preset } : {});
    Object.assign(input, playbackRestrictionPolicyArn ? { playbackRestrictionPolicyArn } : {});
    Object.assign(input, containerFormat ? { containerFormat } : {});
    Object.assign(input, tags ? { tags } : {});

    const command = new CreateChannelCommand(input);
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// list-stream-keys
server.tool(
  "list-stream-keys",
  "List all of the IVS stream keys for an IVS channel. Returns paginated results with a default max of 10.",
  {
    channelArn: z.string().describe("The ARN of the IVS channel."),
  },
  async ({ channelArn }) => {
    const command = new ListStreamKeysCommand({ channelArn });
    const listStreamKeysResponse = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listStreamKeysResponse) }],
    };
  },
);

// get-stream-key
server.tool(
  "get-stream-key",
  "Get IVS stream key information",
  {
    arn: z.string().describe("The ARN of the IVS channel."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetStreamKeyCommand({ arn: decodedArn });
    const response = await ivsClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-encoder-configuration
server.tool(
  "get-encoder-configuration",
  "Get IVS Real-Time encoder configuration information",
  {
    arn: z.string().describe("The ARN of the IVS Real-Time encoder configuration."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetEncoderConfigurationCommand({ arn: decodedArn });
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-ingest-configuration
server.tool(
  "get-ingest-configuration",
  "Get IVS Real-Time ingest configuration information",
  {
    arn: z.string().describe("The ARN of the IVS Real-Time ingest configuration."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetIngestConfigurationCommand({ arn: decodedArn });
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// create-ingest-configuration
server.tool(
  "create-ingest-configuration",
  "Create a new IVS Real-Time ingest configuration",
  {
    name: z.string().describe("The name of the ingest configuration to create."),
    stageArn: z.string().describe("ARN of the stage with which the IngestConfiguration is associated."),
    userId: z.string().optional().describe("Customer-assigned name to help identify the participant using the IngestConfiguration; this can be used to link a participant to a user in the customer’s own systems. This can be any UTF-8 encoded text. This field is exposed to all stage participants and should not be used for personally identifying, confidential, or sensitive information."),
    attributes: z.object({}).optional().describe("Application-provided attributes to store in the IngestConfiguration and attach to a stage. Map keys and values can contain UTF-8 encoded text. The maximum length of this field is 1 KB total. This field is exposed to all stage participants and should not be used for personally identifying, confidential, or sensitive information."),
    ingestProtocol: z.enum(["RTMP", "RTMPS"]).optional().default("RTMPS").describe("Type of ingest protocol that the user employs to broadcast. If this is set to RTMP, insecureIngest must be set to true. Default: RTMPS"),
    insecureIngest: z.boolean().optional().default(false).describe("Whether the stage allows insecure RTMP ingest. This must be set to true, if ingestProtocol is set to RTMP. Default: false."),
    tags: z.object({}).optional().describe("The tags of the ingest configuration to create."),
  },
  async ({ name, tags }) => {
    const input = { name, stageArn };
    Object.assign(input, userId ? { userId } : {});
    Object.assign(input, attributes ? { attributes } : {});
    Object.assign(input, ingestProtocol ? { ingestProtocol } : {});
    Object.assign(input, insecureIngest ? { insecureIngest } : {});
    Object.assign(input, tags ? { tags } : {});
    const command = new CreateIngestConfigurationCommand(input);
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// create-encoder-configuration
server.tool(
  "create-encoder-configuration",
  "Create a new IVS Real-Time encoder configuration",
  {
    name: z.string().describe("The name of the encoder configuration to create."),
    video: z
      .object({
        width: z.number().optional().default(1280).describe("Video-resolution width. This must be an even number. Note that the maximum value is determined by width times height, such that the maximum total pixels is 2073600 (1920x1080 or 1080x1920). Default: 1280."),
        height: z.number().optional().default(720).describe("Video-resolution height. This must be an even number. Note that the maximum value is determined by width times height, such that the maximum total pixels is 2073600 (1920x1080 or 1080x1920). Default: 720."),
        framerate: z.number().optional().default(30).describe("Video frame rate, in fps. Default: 30."),
        bitrate: z.number().optional().default(2500000).describe("Bitrate for generated output, in bps. Default: 2500000."),
      })
      .optional()
      .describe("The video configuration for the encoder configuration."),
    tags: z.object({}).optional().describe("The tags of the encoder configuration to create."),
  },
  async ({ name, tags }) => {
    const input = { name };
    Object.assign(input, video ? { video } : {});
    Object.assign(input, tags ? { tags } : {});
    const command = new CreateEncoderConfigurationCommand(input);
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-low-latency-stream-health-metrics
server.tool(
  "get-low-latency-stream-health-metrics",
  "Get IVS Low-Latency stream health metrics",
  {
    arn: z.string().describe("The ARN of the IVS Low-Latency Channel."),
    startTime: z
      .number()
      .optional()
      .default(new Date().setHours(new Date().getHours() - 1))
      .describe("The start time of the stream health metrics period as a Unix timestamp with milliseconds. If not provided, the start time is 1 hour before the current time. The maximum time range is 1 hour."),
    endTime: z.number().optional().default(Date.now()).describe("The end time of the stream health metrics period as a Unix timestamp with milliseconds. If not provided, the end time is the current time. The maximum time range is 1 hour."),
    streamHealthMetrics: z
      .array(z.enum(["IngestAudioBitrate", "IngestVideoBitrate", "IngestFramerate", "KeyframeInterval", "ConcurrentViews"]))
      .optional()
      .default(["IngestAudioBitrate", "IngestVideoBitrate", "IngestFramerate", "KeyframeInterval", "ConcurrentViews"])
      .describe("The stream health metrics to retrieve. If not provided, the following stream health metrics are returned: IngestAudioBitrate, IngestVideoBitrate, IngestFramerate, KeyframeInterval, ConcurrentViews."),
    period: z.number().optional().default(5).describe("The granularity, in seconds, of the returned data points. For metrics with regular resolution, a period can be as short as one minute (60 seconds) and must be a multiple of 60. For high-resolution metrics that are collected at intervals of less than one minute, the period can be 1, 5, 10, 30, 60, or any multiple of 60. High-resolution metrics are those metrics stored by a PutMetricData call that includes a StorageResolution of 1 second. If the StartTime parameter specifies a time stamp that is greater than 3 hours ago, you must specify the period as follows or no data points in that time range is returned: Start time between 3 hours and 15 days ago - Use a multiple of 60 seconds (1 minute). Start time between 15 and 63 days ago - Use a multiple of 300 seconds (5 minutes). Start time greater than 63 days ago - Use a multiple of 3600 seconds (1 hour)."),
  },
  async ({ arn, startTime, endTime, streamHealthMetrics, period }) => {
    startTime = new Date(startTime);
    endTime = new Date(endTime);
    const metricDataQueries = streamHealthMetrics.map((metric) => {
      return {
        Id: metric.toLowerCase(),
        MetricStat: {
          Metric: {
            MetricName: metric,
            Namespace: "AWS/IVS",
            Dimensions: [{ Name: "Channel", Value: arn.split("/")[1] }],
          },
          Period: period,
          Stat: "Average",
        },
      };
    });
    const getMetricDataInput = {
      StartTime: startTime,
      EndTime: endTime,
      MetricDataQueries: metricDataQueries,
      MaxDatapoints: 100,
    };
    const getMetricDataRequest = new GetMetricDataCommand(getMetricDataInput);
    const getMetricDataResponse = await cloudWatchClient.send(getMetricDataRequest);
    return {
      content: [{ type: "text", text: JSON.stringify(getMetricDataResponse) }],
    };
  },
);

// IVS Real-Time Tools

// create-stage
server.tool(
  "create-stage",
  "Create a new IVS Real-Time stage",
  {
    name: z.string().optional().describe("The name of the stage to create."),
    participantTokenConfigurations: z
      .array(
        z.object({
          userId: z.string().describe("The user ID of the participant token configuration."),
          attributes: z.object({}).optional().describe("The attributes of the participant token configuration."),
          capabilities: z
            .array(z.enum(["SUBSCRIBE", "PUBLISH"]))
            .optional()
            .describe("The capabilities of the participant token configuration."),
        }),
      )
      .optional()
      .describe("The participant token configurations of the stage to create."),
    autoParticipantRecordingConfiguration: z.object({
      storageConfigurationArn: z.string().describe("ARN of the StorageConfiguration resource to use for individual participant recording"),
      mediaTypes: z
        .array(z.enum(["AUDIO_VIDEO", "AUDIO_ONLY", "NONE"]))
        .default("AUDIO_VIDEO")
        .describe("Types of media to be recorded. Default: AUDIO_VIDEO"),
      thumbnailConfiguration: z
        .object({
          targetIntervalSeconds: z.number().optional().default(60).describe("The targeted thumbnail-generation interval in seconds. This is configurable only if recordingMode is INTERVAL. Default: 60."),
          storage: z
            .array(z.enum(["SEQUENTIAL", "LATEST"]))
            .optional()
            .default(["SEQUENTIAL"])
            .describe("Indicates the format in which thumbnails are recorded. SEQUENTIAL records all generated thumbnails in a serial manner, to the media/thumbnails/high directory. LATEST saves the latest thumbnail in media/latest_thumbnail/high/thumb.jpg and overwrites it at the interval specified by targetIntervalSeconds. You can enable both SEQUENTIAL and LATEST. Default: ['SEQUENTIAL']"),
          recordingMode: z.enum(["DISABLED", "INTERVAL"]).optional().default("DISABLED").describe("Thumbnail recording mode. Default: DISABLED."),
        })
        .optional()
        .describe("A complex type that allows you to enable/disable the recording of thumbnails for individual participant recording and modify the interval at which thumbnails are generated for the live session."),
      recordingReconnectWindowSeconds: z.number().optional().default(0).describe("If a stage publisher disconnects and then reconnects within the specified interval, the multiple recordings will be considered a single recording and merged together."),
      hlsConfiguration: z
        .object({
          targetSegmentDurationSeconds: z.number().optional().default(6).describe("Defines the target duration for recorded segments generated when recording a stage participant. Segments may have durations longer than the specified value when needed to ensure each segment begins with a keyframe. Default: 6."),
        })
        .describe("HLS configuration object for individual participant recording"),
    }),
    tags: z.object({}).optional().describe("The tags of the stage to create."),
  },
  async ({ name, participantTokenConfigurations, autoParticipantRecordingConfiguration, tags }) => {
    const input = {};
    Object.assign(input, name ? { name } : {});
    Object.assign(input, participantTokenConfigurations ? { participantTokenConfigurations } : {});
    Object.assign(input, autoParticipantRecordingConfiguration ? { autoParticipantRecordingConfiguration } : {});
    Object.assign(input, tags ? { tags } : {});
    const command = new CreateStageCommand(input);
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// list-stages
server.tool(
  "list-stages",
  "List all of the IVS Real-Time stages for this account. Returns paginated results with a default max of 10.",
  {
    nextToken: z.string().optional().describe("The token for the next page of results"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
  },
  async (params) => {
    const input = {};
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    const command = new ListStagesCommand(input);
    const listStagesResponse = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listStagesResponse) }],
    };
  },
);

// get-stage
server.tool(
  "get-stage",
  "Get IVS Real-Time stage information",
  {
    arn: z.string().describe("The ARN of the IVS Real-Time stage."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetStageCommand({ arn: decodedArn });
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// list-participants
server.tool(
  "list-participants",
  "List all of the IVS Real-Time stage participants for an IVS Real-Time Stage. Returns paginated results with a default max of 10.",
  {
    arn: z.string().describe("The ARN of the IVS Real-Time stage"),
    sessionId: z.string().describe("The ID of the IVS Real-Time stage session"),
    filterByUserId: z.string().optional().describe("The user ID to filter by"),
    filterByPublished: z.boolean().optional().describe("Whether to filter by published participants"),
    filterByState: z.enum(["CONNECTED", "DISCONNECTED"]).optional().describe("The state to filter by"),
    filterByRecordingState: z.enum(["RECORDING", "NOT_RECORDING"]).optional().describe("The recording state to filter by"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
    nextToken: z.string().optional().describe("The token for the next page of results"),
  },
  async (params) => {
    const decodedArn = decodeURIComponent(params.arn);
    const input = { sessionId: params.sessionId, stageArn: decodedArn };
    Object.assign(input, params?.filterByUserId ? { filterByUserId: params.filterByUserId } : {});
    Object.assign(input, params?.filterByPublished ? { filterByPublished: params.filterByPublished } : {});
    Object.assign(input, params?.filterByState ? { filterByState: params.filterByState } : {});
    Object.assign(input, params?.filterByRecordingState ? { filterByRecordingState: params.filterByRecordingState } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});

    const command = new ListParticipantsCommand(input);
    const listParticipantsResponse = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listParticipantsResponse) }],
    };
  },
);

// get-participant
server.tool(
  "get-participant",
  "Get IVS Real-Time stage participant information",
  {
    arn: z.string().describe("The ARN of the IVS Real-Time stage"),
    sessionId: z.string().describe("The ID of the IVS Real-Time stage session"),
    participantId: z.string().describe("The ID of the IVS Real-Time participant"),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetParticipantCommand({ stageArn: decodedArn, sessionId, participantId });
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// list-stage-sessions
server.tool(
  "list-stage-sessions",
  "List all of the IVS Real-Time stage sessions for a stage in this account. Returns paginated results with a default max of 10.",
  {
    arn: z.string().optional().describe("The ARN of the stage to list sessions for"),
    nextToken: z.string().optional().describe("The token for the next page of results"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
  },
  async (params) => {
    const input = { stageArn: params.arn };
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    const command = new ListStageSessionsCommand(input);
    const listStageSessionsResponse = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listStageSessionsResponse) }],
    };
  },
);

// get-stage-session
server.tool(
  "get-stage-session",
  "Get IVS Real-Time stage session information",
  {
    stageArn: z.string().describe("The ARN of the IVS Real-Time stage session."),
    sessionId: z.string().describe("The session ID of the IVS Real-Time stage session."),
  },
  async ({ stageArn, sessionId }) => {
    const decodedArn = decodeURIComponent(stageArn);
    const command = new GetStageSessionCommand({ stageArn: decodedArn, sessionId });
    const response = await ivsRealTimeClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-real-time-stage-health-metrics
server.tool(
  "get-real-time-stage-health-metrics",
  "Get IVS Real-Time stage health metrics",
  {
    arn: z.string().describe("The ARN of the IVS Real-Time Stage."),
    startTime: z
      .number()
      .optional()
      .default(new Date().setHours(new Date().getHours() - 1))
      .describe("The start time of the stage health metrics period as a Unix timestamp with milliseconds. If not provided, the start time is 1 hour before the current time. The maximum time range is 1 hour."),
    endTime: z.number().optional().default(Date.now()).describe("The end time of the stage health metrics period as a Unix timestamp with milliseconds. If not provided, the end time is the current time. The maximum time range is 1 hour."),
    streamHealthMetrics: z
      .array(z.enum(["Subscribers", "Publishers", "SubscribeBitrate", "DownloadPacketLoss", "DroppedFrames", "PublishBitrate"]))
      .optional()
      .default(["Subscribers", "Publishers", "SubscribeBitrate", "DownloadPacketLoss", "DroppedFrames", "PublishBitrate"])
      .describe("The stage health metrics to retrieve. If not provided, the following health metrics are returned: Subscribers, Publishers, SubscribeBitrate, DownloadPacketLoss, DroppedFrames, PublishBitrate"),
    period: z.number().optional().default(5).describe("The granularity, in seconds, of the returned data points. For metrics with regular resolution, a period can be as short as one minute (60 seconds) and must be a multiple of 60. For high-resolution metrics that are collected at intervals of less than one minute, the period can be 1, 5, 10, 30, 60, or any multiple of 60. High-resolution metrics are those metrics stored by a PutMetricData call that includes a StorageResolution of 1 second. If the StartTime parameter specifies a time stamp that is greater than 3 hours ago, you must specify the period as follows or no data points in that time range is returned: Start time between 3 hours and 15 days ago - Use a multiple of 60 seconds (1 minute). Start time between 15 and 63 days ago - Use a multiple of 300 seconds (5 minutes). Start time greater than 63 days ago - Use a multiple of 3600 seconds (1 hour)."),
  },
  async ({ arn, startTime, endTime, streamHealthMetrics, period }) => {
    startTime = new Date(startTime);
    endTime = new Date(endTime);
    const metricDataQueries = streamHealthMetrics.map((metric) => {
      return {
        Id: metric.toLowerCase(),
        MetricStat: {
          Metric: {
            MetricName: metric,
            Namespace: "AWS/IVSRealTime",
            Dimensions: [{ Name: "Stage", Value: arn.split("/")[1] }],
          },
          Period: period,
          Stat: "Average",
        },
      };
    });
    const getMetricDataInput = {
      StartTime: startTime,
      EndTime: endTime,
      MetricDataQueries: metricDataQueries,
      MaxDatapoints: 100,
    };
    const getMetricDataRequest = new GetMetricDataCommand(getMetricDataInput);
    const getMetricDataResponse = await cloudWatchClient.send(getMetricDataRequest);
    return {
      content: [{ type: "text", text: JSON.stringify(getMetricDataResponse) }],
    };
  },
);

// IVS Chat Tools

// list-rooms
server.tool(
  "list-rooms",
  "List all of the IVS Chat rooms for this account. Returns paginated results with a default max of 10.",
  {
    nextToken: z.string().optional().describe("The token for the next page of results"),
    maxResults: z.number().optional().default(10).describe("The maximum number of results to return (default: 10)"),
    name: z.string().optional().describe("The name of the room to search for"),
  },
  async (params) => {
    const input = {};
    Object.assign(input, params?.nextToken && params.nextToken !== "null" ? { nextToken: params.nextToken } : {});
    Object.assign(input, params?.maxResults ? { maxResults: params.maxResults } : {});
    Object.assign(input, params?.name ? { filterByName: params.name } : {});
    const command = new ListRoomsCommand(input);
    const listRoomsResponse = await ivsChatClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(listRoomsResponse) }],
    };
  },
);

// get-room
server.tool(
  "get-room",
  "Get IVS Chat room information",
  {
    arn: z.string().describe("The ARN of the IVS Chat room."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetRoomCommand({ identifier: decodedArn });
    const response = await ivsChatClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// get-logging-configuration
server.tool(
  "get-logging-configuration",
  "Get IVS Chat logging configuration information",
  {
    arn: z.string().describe("The ARN of the IVS Chat logging configuration."),
  },
  async ({ arn }) => {
    const decodedArn = decodeURIComponent(arn);
    const command = new GetLoggingConfigurationCommand({ identifier: decodedArn });
    const response = await ivsChatClient.send(command);
    return {
      content: [{ type: "text", text: JSON.stringify(response) }],
    };
  },
);

// utilities

// get-current-date-time
server.tool("get-current-date-time", "Gets the current date and time", {}, async () => {
  return {
    content: [{ type: "text", text: JSON.stringify(new Date().toISOString()) }],
  };
});

// iso-date-to-unix-timestamp
server.tool(
  "iso-date-to-unix-timestamp",
  "Accepts an array of ISO strings and converts them to Unix Timestamps",
  {
    isoStrings: z.array(z.string()).describe("An array of ISO strings to convert to Unix Timestamps"),
  },
  async ({ isoStrings }) => {
    return {
      content: [{ type: "text", text: JSON.stringify(isoStrings.map((s) => new Date(s).getTime())) }],
    };
  },
);

// Bedrock Knowledgebase Tools

// ivs-knowledgebase-retrieve
if (knowledgeBaseId) {
  server.tool(
    "ivs-knowledgebase-retrieve",
    "Retrieve information from the Amazon IVS Bedrock Knowledgebase for queries specific to the latest Amazon IVS documentation or service information.",
    {
      query: z.string().describe("The query to search the knowledgebase for"),
    },
    async ({ query }) => {
      const input = {
        knowledgeBaseId,
        retrievalQuery: {
          text: query,
        },
        vectorSearchConfiguration: {
          numberOfResults: 5,
          overrideSearchType: "HYBRID",
        },
      };
      const command = new RetrieveCommand(input);
      const response = await bedrockAgentRuntimeClient.send(command);
      return {
        content: [{ type: "text", text: JSON.stringify(response) }],
      };
    },
  );
}

// fetch-url
server.tool(
  "fetch-url",
  "Fetch a URL and return its contents as markdown",
  {
    url: z.string().describe("The URL to fetch"),
  },
  async ({ url }) => {
    const response = await fetch(url);
    const text = await response.text();
    // convert to markdown
    const md = NodeHtmlMarkdown.translate(text);
    return {
      content: [{ type: "text", text: md }],
    };
  },
);

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("🏃 IVS MCP Server running on stdio");

server.server.sendLoggingMessage({
  level: "debug",
  data: "IVS MCP Server running on stdio",
});
```

{% enddetails %}

{% details package.json %}

```js
{
  "name": "amazon-ivs-mcp-server-demo",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "type": "module",
  "private": false,
  "engines": {
    "node": ">= 14.0.0",
    "npm": ">= 6.0.0"
  },
  "homepage": "",
  "repository": {
    "type": "git",
    "url": ""
  },
  "bugs": "",
  "keywords": [],
  "contributors": [],
  "scripts": {
    "build": "",
    "dev": "",
    "test": "",
    "inspect": "npx @modelcontextprotocol/inspector node src/index.js"
  },
  "dependencies": {
    "@aws-sdk/client-bedrock-agent-runtime": "^3.777.0",
    "@aws-sdk/client-cloudwatch": "^3.782.0",
    "@aws-sdk/client-ivs": "^3.772.0",
    "@aws-sdk/client-ivs-realtime": "^3.775.0",
    "@aws-sdk/client-ivschat": "^3.775.0",
    "@modelcontextprotocol/sdk": "^1.7.0",
    "axios": "^1.8.4",
    "node-html-markdown": "^1.3.0"
  },
  "devDependencies": {
    "@types/node": "^22.13.13"
  }
}
```

{% enddetails %}

## Summary

In this post, we learned how to create a custom MCP server that contains a set of tools to help us interact with Amazon IVS resources in our AWS account. In the next post, we'll look at creating a custom RAG knowledge base and expanding our server with additional tools and resources.
