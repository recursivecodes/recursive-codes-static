---
title: "Create a Custom MCP Server for Working with AWS Services - Adding a RAG Knowledge Base and Utilities"
slug: "create-a-custom-mcp-server-for-working-with-aws-services-adding-a-rag-knowledge-base-and-utilities-39ea"
author: "Todd Sharp"
date: 2025-04-09T14:03:32Z
summary: "In the last post, we built a custom server that uses the Model Context Protocol (MCP) to expose tools..."
tags: ["aws", "amazonivs", "mcp", "genai"]
canonical_url: "https://dev.to/aws/create-a-custom-mcp-server-for-working-with-aws-services-adding-a-rag-knowledge-base-and-utilities-39ea"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7cyumgv8p7bkaxr6038o.png"
---

In the last post, we built a custom server that uses the Model Context Protocol (MCP) to expose tools that give LLM clients direct insight into the Amazon Interactive Video Service (Amazon IVS) resources in an AWS account. The server also has the ability to get health and metric data on our Amazon IVS resources via CloudWatch. This gives us the ability to get deep insight and perform custom queries into our environment, setting us up for great success when it comes to managing our Amazon IVS resources.

Having an MCP server with insight into our resources is amazing, but we can make this server even more powerful by giving it some documentation and contextual knowledge about Amazon IVS as a service. In this post, we're going to add some additional tools to that MCP server to add that knowledge as well as some other helpful utilities. Don't worry, we'll get to building an MCP client in the future. For now, let's supercharge this server so that our client will have all the tools that it needs to help us build amazing Amazon IVS prototypes and demos.

## Adding RAG Support to Our MCP Server

![IVS MCP->Bedrock RAG](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-f1w42yvcueyyu4hh6u5v.png)

With the popularity and rise of MCP, some have wondered if it meant the death of Retrieval Augmented Generation. However, this couldn't be further from the truth. Like MCP, RAG is a valuable tool that can be an additional source of domain-specific data that an LLM might not otherwise be aware of. To add RAG functionality to our IVS MCP server, we'll create a Knowledge Base in Amazon Bedrock and populate it with some Amazon IVS documentation.

### Creating the Knowledge Base

We could use the AWS CLI, or other methods to create the knowledge base, but I prefer to use the console since it takes care of creating the necessary data store and IAM roles for us.

First, head to the Amazon Bedrock console and click 'Create' and select 'Knowledge Base with vector store'.

![Create KB](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zwlq2e06gtoxwv0ecqza.png)

Name it, and choose or create a new service role.

![Name KB](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-mk6lx7djxh51j3ksstxa.png)

Choose 'Web Crawler' as the data source and click 'Next'.

![KB Datasource](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-fkh43d504hfbx5qk4lh4.png)

On the next step, give the data source a name and optional description.

![KB Data source name](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-3ekheod8vbxxmv5aiwck.png)

Now we can define up to 9 URLs for the data source to crawl that will be used to populate the data source.

![Image description](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-wx74rd74ypv9hmg9fml1.png)

Here's the list of the URLs that I used. I focused on official documentation sources for Amazon IVS, as well as all of the blog posts here on dev.to tagged with 'amazonivs'.

```md
https://dev.to/t/amazonivs
https://aws.github.io/amazon-ivs-web-broadcast/
https://docs.aws.amazon.com/ivs/latest/LowLatencyUserGuide/
https://docs.aws.amazon.com/ivs/latest/RealTimeUserGuide/
```

Choose the best settings for your use case in the 'Sync Scope' section, but pay attention to 'Exclude patterns'. Your mileage may vary, but I found that excluding PDFs and RSS feeds provided better results for my knowledge base. I used the pattern `(.*.pdf|.*.rss)` to exclude these. In my testing, letting it crawl these would end up confuse the client later on because it would often return results from the 'index' page of the PDF instead of from the documentation body.

For 'Content chunking and parsing', again choose the best options for your use case. I found the default options to work fine for me.

On the next step of the wizard, choose an 'Embeddings model'. This is the model that is used to convert the crawled data to vector data. The `Titan Embeddings G1 - Text v1.2` model worked great for me.

![Embeddings model](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-zvcqitdz5yipmozeemb2.png)

Finally, choose or create a vector database that will be used to store, update and manage the embeddings. I chose to create a new one with Amazon OpenSearch Serverless.

![Vector database](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rbf4vrekirb3fpj27w7n.png)

Click 'Next', review the settings, and click 'Create Knowledge Base'. At this point, the necessary roles and databases will be created. Once they're ready, you can 'Sync' your data source which should take about 15 minutes. After the data source is synced, we're ready to integrate the knowledge base into our MCP server!

### Creating a Knowledge Base Retrieval Tool

With a RAG knowledge base created and synced up, we can create a tool in our MCP server to retrieve data based on a query. We'll use the Amazon Bedrock Agent Runtime for this, so install that module and create a client.

```bash
npm install @aws-sdk/client-bedrock-agent-runtime
```

```js
import { BedrockAgentRuntimeClient, RetrieveCommand } from "@aws-sdk/client-bedrock-agent-runtime";

const bedrockAgentRuntimeClient = new BedrockAgentRuntimeClient(config);
```

Next, add a server tool.

```js
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
```

That's it! Now that we've exposed a tool, our client can query this knowledge base whenever it feels that it needs additional documentation regarding Amazon IVS.

## Adding Miscellaneous Tools to the MCP Server

One of my favorite parts of MCP servers is the ability to provide utilities and tools. Beyond domain specific knowledge, we can provide clients with tools to help our LLM with things that it is normally not that great at handling. Things like math and date handling. For example, if you were to use a client with the MCP server that we've created and asked it to tell you how long ago a specific IVS channel was created, it might give you a surprising answer and tell you that the channel was created in the future! This is because the model has no direct knowledge of the current date and time. We can easily solve this by creating a tool to return the current date and time. Then, when we expose that tool to a client, it'll know how to get that information!

```js
server.tool("get-current-date-time", "Gets the current date and time", {}, async () => {
  return {
    content: [{ type: "text", text: JSON.stringify(new Date().toISOString()) }],
  };
});
```

Simple, but beautiful 😍!

Another really helpful tool to add is just as simple, but just as powerful. We've built a great knowledge base of Amazon IVS documentation that has a ton of helpful info in it, but there could still be additional data that the LLM needs to respond to a specific prompt. For this, we can create another basic tool to fetch a specific URL from the internet.

```js
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
```

Once we expose this, the client can choose to fetch a specific URL based on what it retrieves from the knowledge base. We can even ask it to fetch a specific URL to use if we need to provide context outside of the scope of our knowledge base.

## Summary

In this post, we created a RAG knowledge base and added the ability to query that knowledge base from our MCP server. We also created some additional helpful tools and utilities to round out our server. There is certainly a conversation to be had about separation of concerns, which might be outside of the scope of this blog series. For example, maybe our general utilities would be better off in their own server so that we can reuse them across multiple clients? As we'll see in the next post when we create a custom MCP client to interact with this server, there is no limitation to the amount of servers that a client can interact with, so there is no benefit to consolidating functionality like we've done here (other than keeping things simple for now).
