---
title: "Turbo Charge the Amazon Q Developer CLI with MCP Servers"
slug: "turbo-charge-the-amazon-q-developer-cli-with-mcp-servers-fl5"
author: "Todd Sharp"
date: 2025-04-30T13:38:52Z
summary: "Recently, I blogged a 4 part series about how the Model Context Protocol (MCP) can provide the..."
tags: ["aws", "mcp", "amazonivs"]
canonical_url: "https://dev.to/aws/turbo-charge-the-amazon-q-developer-cli-with-mcp-servers-fl5"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-sgo84fwap7lz20vzyaji.png"
---

Recently, I blogged a 4 part [series](https://dev.to/recursivecodes/series/31222) about how the Model Context Protocol (MCP) can provide the missing context to your LLM applications. In that series, we created a [custom MCP server](https://dev.to/aws/create-a-custom-mcp-server-for-working-with-aws-services-managing-your-resources-4o3c) that can help you manage your AWS resources. Then we added a [RAG knowledge base and some utilities](https://dev.to/aws/create-a-custom-mcp-server-for-working-with-aws-services-adding-a-rag-knowledge-base-and-utilities-39ea) to the server so that it could have domain-specific knowledge of an AWS service to help us quickly learn and prototype new applications. Lastly, we created a custom MCP client that used the tools exposed by the MCP server to invoke Claude 3.7 Sonnet via Amazon Bedrock. Creating a custom MCP client was a good exercise to learn about MCP and Amazon Bedrock, but in reality our MCP server could be used with *any* client that supports MCP servers. Today we'll look at how to integrate the custom MCP server that we previously created with the Amazon Q Developer CLI.

## Amazon Q Developer

If you have not yet discovered [Amazon Q Developer](https://aws.amazon.com/q/developer/), I encourage you to install it and try it out. Like all good generative-AI powered coding assistants, it can integrate with your favorite IDE and provide invaluable assistance to you while you develop your projects. It also includes the Amazon Q Developer CLI, which is a command line based assistant that you can launch with `q chat` from your favorite terminal. As of yesterday, the [Amazon Q Developer CLI](https://aws.amazon.com/blogs/devops/extend-the-amazon-q-developer-cli-with-mcp/) now supports custom MCP servers. You can refer to the launch blog post for more information about this new feature, but for now lets add our custom Amazon IVS MCP server and try it out!

## Adding a Custom MCP Server to the Amazon Q Developer CLI

First [install Amazon Q](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html?b=cli&p=overview&s=hero) and authenticate with your AWS Builder ID. If you've already got it installed, verify that you're on at least version `1.9.0`.

![Amazon Q Release Notes](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-bgdwix0m4lbrbax0s1ez.png)

Next we will define the MCP server in a file called `mcp.json` in the `~/.aws/amazonq` directory.  In this file we will tell Amazon Q the information it needs to integrate with our MCP server.

```json
{
  "mcpServers": {
    "amazon-ivs-mcp-server": {
      "command": "node",
      "args": ["/projects/demos/ivs-mcp/amazon-ivs-mcp-server-demo/index.js"],
      "env": {
      }
    }
  }
}
```
Within the `mcpServer` object, define an object with the key `amazon-ivs-mcp-server`. This can be whatever name you like, but you should choose something that properly describes the server you are adding. Within this object, enter the `command` (`node`), and the path to the MCP server in the `args` array. Finally, if necessary, define any environment variables in the `env` object. In my case, I've set the environment variables within my session so I do not have to explicitly define them here. 

Finally, launch the Amazon Q Developer CLI with `q chat`. If you have properly configured the Amazon IVS MCP server that we created in this blog series, you will see a list of the available tools at launch.

```md
$ q chat
To learn more about MCP safety, see https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-mcp-security.html
⚠ amazon_ivs_mcp_server has the following warning:
The following tool names are changed:
 - amazon_ivs_mcp_server___get-logging-configuration -> amazon_ivs_mcp_server___getloggingconfiguration
 - amazon_ivs_mcp_server___get-playback-restriction-policy -> amazon_ivs_mcp_server___getplaybackrestrictionpolicy
...more warnings
✓ 1 of 1 mcp servers initialized
```
Don't worry about those ⚠️ warnings, they are just letting us know that Amazon Q has changed the names of the tools to fit its naming convention. The important part is this: `✓ 1 of 1 mcp servers initialized`. We've integrated our MCP server with the Amazon Q Developer CLI! 

## Managing Tools

There are a few commands we can use to manage our tools. Run `/help` to see a list of the available commands in the CLI. Here is a list of the tool related commands that you can run:

```md
/tools        View and manage tools and permissions
  help        Show an explanation for the trust command
  trust       Trust a specific tool or tools for the session
  untrust     Revert a tool or tools to per-request confirmation
  trustall    Trust all tools (equivalent to deprecated /acceptall)
  reset       Reset all tools to default permission levels
```
If a tool is not 'trusted', you will be prompted to 'trust' it when the Amazon Q Developer CLI decides it needs to use a tool. 

## Using the Amazon IVS MCP Server from the Amazon Q Developer CLI

Now we can ask Amazon Q about our Amazon IVS account. For example:

> tell me about the last streaming session on demo-stage

Which results in:

```md
I'll help you find information about the last streaming session on "demo-stage". To do this, I need to first check if this stage exists and then retrieve
its session information.

Let me first list the available IVS Real-Time stages to find the one named "demo-stage":

🛠️  Using tool: list-stages from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running list-stages with the param:
 ⋮  {
 ⋮    "arguments": {},
 ⋮    "name": "list-stages"
 ⋮  }
Allow this action? Use 't' to trust (always allow) this tool for the session. [y/n/t]:
```
When I enter `t` to trust the `list-stages` tool, the tool is invoked. Amazon Q continues invoking tools until it finds the information it needs to respond to my original prompt.

```md
I found the "demo-stage" in the list. Now let me get the stage sessions for this stage to find the last streaming session:

🛠️  Using tool: list-stage-sessions from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running list-stage-sessions with the param:
 ⋮  {
 ⋮    "arguments": {
 ⋮      "arn": "arn:aws:ivs:us-east-1:[redacted]:stage/[redacted]"
 ⋮    },
 ⋮    "name": "list-stage-sessions"
 ⋮  }

🛠️  Using tool: get-stage-session from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running get-stage-session with the param:
 ⋮  {
 ⋮    "arguments": {
 ⋮      "sessionId": "st-[redacted]",
 ⋮      "stageArn": "arn:aws:ivs:us-east-1:[redacted]:stage/[redacted]"
 ⋮    },
 ⋮    "name": "get-stage-session"
 ⋮  }

🛠️  Using tool: list-participants from mcp server amazon_ivs_mcp_server
 ⋮
 ● Running list-participants with the param:
 ⋮  {
 ⋮    "arguments": {
 ⋮      "arn": "arn:aws:ivs:us-east-1:[redacted]:stage/[redacted]",
 ⋮      "sessionId": "st-[redacted]"
 ⋮    },
 ⋮    "name": "list-participants"
 ⋮  }
```

The final response is a nice summary of the stage session:

```md
Based on the information I've gathered, here are the details about the last streaming session on "demo-stage":

## Last Streaming Session Details

- **Stage Name**: demo-stage
- **Session ID**: st-[redacted]
- **Start Time**: April 24, 2025 at 15:50:38 UTC
- **End Time**: April 24, 2025 at 16:55:06 UTC
- **Duration**: Approximately 1 hour and 5 minutes

### Participant Information:
- Total participants: 8
- 6 participants published content during the session
- 1 participant was identified with user ID "[redacted]"
- All participants are now disconnected

The session had multiple participants joining at different times, with the first participant joining at 15:50:37 UTC and the last one joining at 16:41:06 UTC. None of the participants had recording enabled during this session.

This was the most recent session on the demo-stage, which ended about 6 days ago.
```

## Quick Amazon IVS Prototypes with the Amazon Q Developer CLI

Just like our custom MCP client, we can now ask Amazon Q to generate a quick prototype application and it can use our Amazon IVS domain-specific knowledge and tools to help with the task.

> using the latest version of the amazon ivs web broadcast sdk, create a simple prototype application to broadcast to an amazon ivs low-latency channel. within the UI, include input elements for ingest endpoint and stream key, and let the user choose their webcam and mic. refer to the latest documentation as necessary: https://aws.github.io/amazon-ivs-web-broadcast/docs/low-latency-sdk-guides/introduction

Which results in a simple HTML application that can broadcast to an Amazon IVS low-latency channel.

![Low-latency Broadcast Prototype](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-czjuezynvezhdtwdo8wy.png)

## Summary

In this post we learned how to add our own custom MCP server to the Amazon Q Developer CLI. This feature is not limited to your own MCP servers; you can add any trusted MCP server and enhance Amazon Q which makes it an extremely valuable tool for any developer. Download it today and give it a try!
