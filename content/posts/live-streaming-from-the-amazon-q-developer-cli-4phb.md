---
title: "Live Streaming From the Amazon Q Developer CLI"
slug: "live-streaming-from-the-amazon-q-developer-cli-4phb"
author: "Todd Sharp"
date: 2025-05-01T15:51:08Z
summary: "I've blogged recently about building your own Model Context Protocol (MCP) server and client to help..."
tags: ["aws", "mcp", "amazonivs", "ai"]
canonical_url: "https://dev.to/aws/live-streaming-from-the-amazon-q-developer-cli-4phb"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-gz9ajxehu6ciu65eryzm.png"
---

I've blogged recently about building your own Model Context Protocol (MCP) [server and client](https://dev.to/recursivecodes/series/31222) to help manage your Amazon Interactive Video Service (Amazon IVS) resources (or, any AWS service!). We also saw how to [turbo charge](https://dev.to/aws/turbo-charge-the-amazon-q-developer-cli-with-mcp-servers-fl5) 🏎️ the Amazon Q Developer CLI with the custom MCP server that we created in the previous series. Today I want to talk about another tool 🛠️ you can put in your live streaming developer toolbox 🧰. In this post we'll look at a way to actually start a live stream test broadcast directly from the Amazon Q Developer CLI.

## Wait, What 🤯?

Yes, you read that correctly 😍! In this post we're going to add a way to start a test broadcast to an Amazon IVS real-time stage with Amazon Q. Since we've built a custom MCP server and given Amazon Q access to all those tools, it's much easier to get started prototyping live streaming applications. As your building new applications, you often need to test things out. What better way to test a live streaming application than to start a simple test stream?

## Adding a WebRTC Test Tool

Broadcast to a WebRTC endpoint from the command line has always been notoriously difficult. There's a WHIP plugin for gStreamer, but you have to install Rust and compile it yourself. And after that pain, you actually have to construct a gStreamer pipeline which can be equally painful. Thankfully my co-worker Kostya Vasilyev - one of the amazing engineers on the Amazon IVS video team - has created an open-source project in his free time called `srtc` (which stands for "simple" WebRTC [[repo](https://github.com/kmansoft/srtc/)]). This amazing project includes a sample implementation that runs from the command line and can broadcast H264 video to a WHIP endpoint like the kind supported by Amazon IVS real-time stages. This means that we can compile the command line demo and use the resulting binary (which is less than 1MB!) to broadcast to a stage with a very simple command from the terminal. No convoluted and time consuming plugin compiling, no third-party dependencies (except OpenSSL, which you've most likely already got installed), no messy pipelines!

To get started, visit the `srtc` repo and follow the instructions in the `README.md` to compile the `cmdline_demo`. Rename the compiled binary to `srtc` and make it executable with `chmod +x srtc`. To avoid licensing and third-party dependencies, `srtc` publishes raw H264, so you will have to convert your videos to raw H264, but this is easy to do with FFMPEG. Plus, you only have to do this once (and `srtc` includes a sample `.h264` that you can use. Here's how to convert an `.mp4` to `.h264` if you want to use your own video instead of the sample included in the repo:

```bash
ffmpeg -i /path/to/a.mp4 \
  -c:v libx264 \
  -profile:v baseline \
  -level 3.0 \
  -preset medium \
  -an \
  -f h264 \
  test.h264
```

## Starting a Test Stream with Amazon Q 🎥

Once you've got the compiled binary, you can run it directly from the command line. You don't really need Amazon Q for that, but it would require you to look up a stage ARN and create a participant token. Since the custom Amazon IVS MCP server can easily do that, we can just ask Amazon Q to run a test broadcast for us!

![Amazon Q Invoking srtc](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-yh2k4zhmz999qnnx0qwx.png)

> 💡**Tip**: The Amazon Q Developer CLI already has access to the AWS CLI, so you don't *need* to use the Amazon IVS MCP Server, but since it includes so many other helpful tools, why wouldn't you?

Let's prompt Amazon Q to start a test stream with `srtc`:

> using the tool called 'srtc' located at /path/to/srtc start a test stream to Amazon IVS. run '--help' to determine the necessary parameters. generate a participant token for 'demo-stage' and use the whip endpoint https://global.whip.live-video.net. there is a file called 'test.h264' in that directory that you can use. use screen to run the command in the background.

```md
I'll help you start a test stream to Amazon IVS using the srtc tool with screen to run it in the background.

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command:
/path/to/srtc -h

Usage: /path/to/srtc [options]
Options:
  -f, --file <path>    Path to H.264 file (default: sintel.h264)
  -u, --url <url>      WHIP server URL (default: http://localhost:8080/whip)
  -t, --token <token>  WHIP authorization token
  -h, --help           Show this help message
 ⋮
 ● Completed in 0.26s

🛠️  Using tool: list-stages (trusted) from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running list-stages with the param:
 ⋮  {
 ⋮    "arguments": {},
 ⋮    "name": "list-stages"
 ⋮  }
 ⋮
 ● Completed in 0.204s

🛠️  Using tool: create-stage-participant-token (trusted) from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running create-stage-participant-token with the param:
 ⋮  {
 ⋮    "arguments": {
 ⋮      "capabilities": [
 ⋮        "PUBLISH",
 ⋮        "SUBSCRIBE"
 ⋮      ],
 ⋮      "duration": 60,
 ⋮      "stageArn": "arn:aws:ivs:us-east-1:[redacted]:stage/[redacted]",
 ⋮      "userId": "srtc-test-user"
 ⋮    },
 ⋮    "name": "create-stage-participant-token"
 ⋮  }
 ⋮
 ● Completed in 0.85s

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command:
cd /path/to/srtc && ls -la test.h264

-rw-r--r--  1 shartodd  staff  16674002 Apr 30 14:33 test.h264

 ⋮
 ● Completed in 0.28s

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command: which screen

/usr/bin/screen

 ⋮
 ● Completed in 0.29s

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command:
cd /path/to/srtc && screen -dmS srtc-test /path/to/srtc -f test.h264 -u https://global.whip.live-video.net -t eyJhbGciOiJ[redacted] && echo "Started srtc in screen session named 'srtc-test'"

Started srtc in screen session named 'srtc-test'

 ⋮
 ● Completed in 0.235s

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command: screen -ls

There is a screen on:
	78126.srtc-test	(Detached)
1 Socket in /var/folders/gg/wkf00k7d60z26pxcv3s4_tlr0000gr/T/.screen.

 ⋮
 ● Completed in 0.20s

I've successfully started a test stream to Amazon IVS using the srtc tool in a screen session. Here's what I did:

1. First, I checked the help information for the srtc tool to understand the required parameters.
2. I found the demo-stage in the list of available stages with ARN: arn:aws:ivs:us-east-1:[redacted]:stage/[redacted].
3. I generated a participant token for the demo-stage with both PUBLISH and SUBSCRIBE capabilities, valid for 60 minutes.
4. I verified that the test.h264 file exists in the specified directory.
5. I confirmed that screen is available on your system.
6. I started the srtc tool in a detached screen session named 'srtc-test' with the following parameters:

* File: test.h264
* URL: https://global.whip.live-video.net
* Token: The participant token generated for the demo-stage

The screen session is now running in the background with the name 'srtc-test' and session ID 78126. The srtc tool is streaming the test.h264 file to your
Amazon IVS Real-Time stage.

To manage this screen session later, you can use these commands:
- To list all screen sessions: screen -ls
- To reattach to the session: screen -r srtc-test
- To terminate the session: screen -X -S srtc-test quit

The stream will continue running in the background until you manually stop it.
```

If we head over to the AWS Console and check the details for `demo-stage`, we can confirm that the test video is being broadcasted!

![Test Subscribe](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-eyivd2299t0qsgrv74y8.png)

To stop the broadcast we can manually run the commands that Amazon Q suggested, or ask it to run the command for us.

```md
I'll stop the test stream that's running in the screen session for you.

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command:
screen -X -S srtc-test quit
 ⋮
 ● Completed in 0.33s

🛠️  Using tool: execute_bash (trusted)
 ⋮
 ● I will run the following shell command: screen -ls
No Sockets found in /var/folders/gg/wkf00k7d60z26pxcv3s4_tlr0000gr/T/.screen.
 ⋮
 ● Completed in 0.28s

I've successfully stopped the test stream. The screen session named 'srtc-test' has been terminated, and the srtc tool is no longer streaming to Amazon IVS.

I verified that there are no more screen sessions running on your system. The test broadcast to the demo-stage has been completely stopped.
```
## Adding Test Broadcast to a Custom MCP Server

Again, this isn't 100% necessary, but I do like the fact that we can wrap the necessary logic in a few MCP server tools and let the server handle the token generation and starting the stream. Here is a diagram to help you visualize how this approach is different from the one we discussed above.

![srtc mcp overview](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-s793m6igu6seqfsjcy99.png)

## Adding Server Tools

To broadcast a test stream from Amazon Q, we'll add two tools to the custom MCP server that we created in the previous series. We'll need to pass the path to `srtc` into the server as an environment variable. This path can be set in your terminal, or hardcoded into the `mcp.json` configuration (see my [last post](https://dev.to/aws/turbo-charge-the-amazon-q-developer-cli-with-mcp-servers-fl5) for how to do that).

```js
const testBroadcastPath = process.env.TEST_BROADCAST_PATH;
if (testBroadcastPath) {
  // broadcast-test-stream-to-stage
  server.tool(
    "broadcast-test-stream-to-stage",
    "Initiate a test stream broadcast to a stage",
    {
      stageArn: z.string().describe('ARN of the stage to which this token is scoped.'),
    },
    async ({
      stageArn,
    }) => {
      // get a participant token for the stage
      const userId = "test-user";
      const attributes = {};
      const capabilities = ["PUBLISH", "SUBSCRIBE"];
      const duration = 720;
      const input = { stageArn, userId, attributes, capabilities, duration };
      const command = new CreateParticipantTokenCommand(input);
      const response = await ivsRealTimeClient.send(command);
      let srtcProcess;
      let pid;
      try {
        srtcProcess = spawn(`${testBroadcastPath}/srtc`, [
          '-f',
          `${testBroadcastPath}/test.h264`,
          '-u',
          'https://global.whip.live-video.net',
          '-t',
          response.participantToken.token
        ], { detached: true, stdio: 'ignore' });
        pid = srtcProcess.pid;
        srtcProcess.unref();
      }
      catch (e) {
        console.error(e);
      }
      return {
        content: [{ type: "text", text: JSON.stringify({ started: true, pid }) }]
      };
    }
  );

  // stop-broadcast-test-stream-to-stage
  server.tool(
    "stop-broadcast-test-stream-to-stage",
    "Stops the test stream broadcast to a stage",
    {
      pid: z.string().describe('The pid of the test stream process.')
    },
    async ({ pid }) => {
      try {
        spawn('kill', ['-9', pid], { shell: true });
      }
      catch (e) {
        console.error(e);
      }
      return {
        content: [{ type: "text", text: JSON.stringify({ stopped: true }) }]
      };
    }
  );
}
```

## Live Streaming from the Amazon Q CLI!

Now we can just ask Amazon Q to start a test stream on 'demo-stage'.

> lets broadcast a test stream to 'demo-stage'

```md
I'll help you broadcast a test stream to a stage named 'demo-stage'. First, let's check if this stage exists in your AWS IVS account.


🛠️  Using tool: list-stages from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running list-stages with the param:
 ⋮  {
 ⋮    "arguments": {},
 ⋮    "name": "list-stages"
 ⋮  }
 ⋮
 ● Completed in 0.248s


I found a stage named 'demo-stage' in your AWS IVS account. Let's broadcast a test stream to it.

🛠️  Using tool: broadcast-test-stream-to-stage from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running broadcast-test-stream-to-stage with the param:
 ⋮  {
 ⋮    "arguments": {
 ⋮      "stageArn": "arn:aws:ivs:us-east-1:[redacated]:stage/[redacated]"
 ⋮    },
 ⋮    "name": "broadcast-test-stream-to-stage"
 ⋮  }
 ⋮
 ● Completed in 0.117s

Great! I've successfully started broadcasting a test stream to the 'demo-stage'. Here's what I did:

1. Found the stage named 'demo-stage' in your AWS IVS account
2. Started broadcasting a test stream to the stage

The test stream is now running with process ID 55960.

To stop the test stream when you're done, let me know and I can help you terminate it.
```

## Summary

In this post, we examined several ways to start a broadcast on an Amazon IVS real-time stage to help you test your live streaming applications. 

Have you embraced generative-AI tools in your development workflow? Let me know in the comments below!