---
title: "Create a Custom MCP Client To Learn and Manage Your AWS Services and Resources"
slug: "create-a-custom-mcp-client-to-learn-and-manage-your-aws-services-and-resources-2omc"
author: "Todd Sharp"
date: 2025-04-09T14:03:37Z
summary: "In the last few posts, we've learned how to create a custom MCP server that has deep knowledge of our..."
tags: ["aws", "amazonivs", "mcp", "genai"]
canonical_url: "https://dev.to/aws/create-a-custom-mcp-client-to-learn-and-manage-your-aws-services-and-resources-2omc"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-rpl8qck84a2c9pwulqlp.png"
---

In the last few posts, we've learned how to create a custom MCP server that has deep knowledge of our Amazon Interactive Video Service (Amazon IVS) resources. The server exposes many tools to retrieve information about our low-latency channels, real-time streams and chat rooms. It also has access to query a custom RAG knowledge base that contains Amazon IVS documentation, so it knows how to answer specific code-related questions regarding Amazon IVS and can even fetch URLs directly from the web. A very powerful server indeed! But we've not yet created a way to interact with this server, so in this post we'll create a custom MCP client that can use the tools exposed by our MCP server. The client will invoke Claude 3.7 via the Amazon Bedrock Converse API. When we invoke Claude via Bedrock, we'll tell it the tools that it can use to answer our prompts and it'll automatically decide the best tool (if any) to use to respond.

As a reminder, here is an overview of the entire architecture that we've been discussing throughout this series.

![IVS MCP Arch Overview](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-e36xute9xpxkhiyuuthx.png)

At the very least, our client will accept user input via `stdio`, and pass that input as a prompt to Claude via Amazon Bedrock. What happens next depends largely on what Claude responds. If it can answer the prompt without using a tool, it will. Or, it'll decide that it needs to invoke a tool and will let us know which tool it wants to use and what parameters it wants to send to that tool. Our client code is responsible for handling this part of the interaction. If Bedrock returns a `stopReason` of `tool_use`, our client calls the tool on our MCP server and adds the tool response to our message context and sends that back to Bedrock. Bedrock might be happy with this, or it might decide to use another tool. The client must manage this back and forth until a `stopReason` of `end_turn` is received. As you can imagine, it's a good idea to limit this back-and-forth interaction to a maximum amount of turns to avoid an infinite loop!

## Creating the MCP Client

We'll again use the `@modelcontextprotocol/sdk` library for our MCP client. To start, create a new project and install the SDK.

> 💡 **Note:** We'll walk through some basic client code below. The full sample client implementation is available for reference at the [bottom of this post](#sample-mcp-client).

```bash
npm init es6 -y
npm install @modelcontextprotocol/sdk
```
Import the client and stdio transport modules.

```js
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
```

Now we can create the transport, client, and connect the client to the server via the transport. Notice that we're using the `node` command, and passing the path to our custom MCP server. We're also passing our environment variables so that we don't have to hardcode our credentials and knowledge base ID.

```js
const ivsTransport = new StdioClientTransport({
  command: "node",
  args: ["../ivs-mcp-server/src/index.js"],
  env: {
    ...process.env,
    RAG_KNOWLEDGEBASE_ID: process.env.RAG_KNOWLEDGEBASE_ID,
    AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
    AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,
    AWS_REGION: process.env.AWS_REGION || 'us-east-1',
  }
});

const ivsClient = new Client(
  {
    name: "IVS-MCP-Client",
    version: "1.0.0"
  },
  {
    capabilities: {
      prompts: {},
      resources: {},
      tools: {}
    }
  }
);

await ivsClient.connect(ivsTransport);
```

### Adding the Bedrock Converse API

We'll need the Bedrock Converse API to send the user prompts to the LLM, so let's install that and create a client.

```bash
npm install @aws-sdk/client-bedrock-runtime
```
```js
import { 
  BedrockRuntimeClient, 
  ConverseCommand 
} from '@aws-sdk/client-bedrock-runtime';

const bedrockRuntimeClient = new BedrockRuntimeClient({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});
```

Now we can create a function that will invoke Claude 3.7 via the Converse API. Note, I've set `topP` to `0.1` and `temperature` to `0.2` here, but you can tweak these values for what works best for you.

```js
const MODEL_ID = "us.anthropic.claude-3-7-sonnet-20250219-v1:0";
const bedrockConverse = async (messages) => {
  const inferenceConfig = {
    topP: 0.1,
    temperature: 0.2,
  };
  const input = {
    modelId: MODEL_ID,
    messages,
    inferenceConfig,
    toolConfig: toolsToBedrockSchema(availableTools),
    system: [
      {
        text: `Your specialty is Amazon Interactive Video Service (Amazon IVS). 
        Wherever possible, take advantage of the tools available to you to help users 
        learn as much as possible about Amazon IVS. 
        If you are asked to generate or evaluate code, you can query IVS 
        knowledge base tool to query for the latest documentation. 
        Since IVS is a newer service, with new versions being published often, 
        reinforce your knowledge by directly fetching the latest version of any 
        documentation returned from the knowledge base.
        If you are asked to edit a file, first summarize your changes and ask the user 
        to confirm them before writing or editing any file on the filesystem.`
      }
    ],
  };
  const converseRequest = new ConverseCommand(input);
  let converseResponse;
  try {
    converseResponse = await bedrockRuntimeClient.send(converseRequest);
  }
  catch (error) {
    if (error.name == 'ThrottlingException') {
      console.log(`🛑 Bedrock API Call Throttled. Trying again after 60 second cooldown...`);
      await sleep(60000);
      return await bedrockConverse(messages);
    }
    else {
      console.error(error);
    }
  }
  return converseResponse;
};
```
There are a few things to note in this function. First, notice that we've included a thorough system prompt which is always a good idea. Next, we've got a try/catch that will accommodate any API throttling exceptions and retry the converse after a cooldown period. You might not need this in your client, but my account has a lower quota than most public accounts so I had to include this to avoid interruption of a nice flow with an error. Also notice that we're passing a `toolConfig` as part of our input parameters. The `toolConfig` uses `toolsToBedrockSchema(availableTools)` to get a list of the tools. First, lets see how to get the `availableTools`:

```js
const availableTools = {ivs: await ivsClient.listTools()};
```
Really easy - just ask the client to list the tools on the server!

Now let's look at `toolsToBedrockSchema()`, which loops over the availableTools and converts them from the format returned by our MCP server into the format that Bedrock expects. It's a slight change, but if we don't pass it properly then Bedrock won't be able to use our tools!

```js
const toolsToBedrockSchema = (availableTools) => {
  const tools = [];
  Object.keys(availableTools).forEach((server) => {
    tools.push(availableTools[server].tools.map(tool => {
      let props = {};
      Object.keys(tool.inputSchema.properties).forEach(prop => {
        props[prop] = {
          "type": tool.inputSchema.properties[prop].type,
          "description": tool.inputSchema.properties[prop]?.description || prop,
        };
      });
      return {
        "toolSpec": {
          "name": tool.name,
          "description": tool?.description || tool.name,
          "inputSchema": {
            "json": {
              "type": tool.inputSchema.type,
              "properties": props,
              "required": tool.inputSchema.required || []
            }
          }
        }
      };
    }));
  });
  return {
    tools: tools.flat()
  };
};
```
### Handling A User Prompt

In order to accept a user prompt, our client needs to expose a way for user's to enter that prompt.

```js
import readline from 'node:readline';

let userInput = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  historySize: 50,
  prompt: '> ',
});

userInput.on('line', async (prompt) => {
  await handlePrompt(prompt);
  userInput.prompt();
};
```

Next we define an array to store our session context, and define `handlePrompt()` and `handleResponse()` functions.

```js
let sessionMessages = [];
const handleResponse = async (response) => {
  let ret = { keepGoing: false, response };
  if (response.stopReason === 'end_turn') {
    console.log('\n' + response?.output?.message?.content[0]?.text + '\n');
  };
  if (response.stopReason === 'tool_use') {
    let processedResponse;
    processedResponse = await useTool(response);
    sessionMessages.push(processedResponse.output.message);
    ret = { keepGoing: true, response: processedResponse };
  }
  return ret;
};

const handlePrompt = async (prompt) => {
  sessionMessages.push({
    role: "user",
    content: [{ text: prompt }],
  });
  let response = await bedrockConverse(sessionMessages);
  sessionMessages.push(response.output.message);
  
  let looping = true;
  while (looping) {
    const processedResponse = await handleResponse(response);
    looping = processedResponse.keepGoing;
    response = processedResponse.response;
  };
};
```

Now we need to create the `useTool()` function to call the server tool if Bedrock decides that is the appropriate thing to do. We push the tool response into our session context and then call Bedrock again with the updated context so that it can decide the next appropriate action.

```js
const useTool = async (response) => {
  const toolInfo = item.toolUse;
  console.log(`🔨 Calling MCP Server tool '${toolInfo.name}' with input '${JSON.stringify(toolInfo?.input).substring(0, 250)}'...`);
  await callTool(toolInfo);
  console.log(`🔎 Sending MCP Server's '${toolInfo.name}' response to Bedrock...`);
  return await bedrockConverse(sessionMessages);
};

const callTool = async (toolInfo) => {
  try {
    const toolName = toolInfo.name;
    const toolArgs = toolInfo.input;
    const toolUseId = toolInfo.toolUseId;
    const client = findClient(toolName);
    const result = await client.callTool({
      name: toolName,
      arguments: toolArgs
    });
    sessionMessages.push({
      role: "user",
      content: [
        {
          toolResult: {
            ...result,
            toolUseId: toolUseId,
          }
        }
      ]
    });
    return sessionMessages;
  }
  catch (error) {
    console.error('Error handling tool call:', error);
    return [`[Error calling tool ${toolInfo?.name || 'unknown'}: ${error.message}]`];
  }
};
```

At this point, we've created a basic MCP client that accepts user prompts and interacts with Claude via Bedrock which has insight into our MCP server tools.

## Adding Another MCP Server

Did you notice that when we declared `availableTools` above we used an object? This choice was intentional and enables us to add additional tools ⚒️ from other MCP servers into our toolbox 🧰. For example, we could use this client to ask for help in creating a simple prototype to broadcast to Amazon IVS, but we'd end up getting a pretty decent sized chunk of text back that includes the necessary code. Wouldn't it be handier to use a set of tools to interact with our file system so that the client could write the file directly to disk for us? Of course it would! Let's create another server, this time using the `@modelcontextprotocol/server-filesystem` MCP server.

```js
const fileSystemTransport = new StdioClientTransport({
  command: "npx",
  args: [
    "-y",
    "@modelcontextprotocol/server-filesystem",
    "/path/to/projects",
  ],
});

const fileSystemClient = new Client(
  {
    name: "Filesystem-Client",
    version: "1.0.0"
  },
  {
    capabilities: {
      prompts: {},
      resources: {},
      tools: {}
    }
  }
);

await fileSystemClient.connect(fileSystemTransport);
```

This server requires us to pass an allow list of directories that we want to give access to. This prevents potentially unwanted file system interactions. In the example above, I'm passing `/path/to/projects` which means that this directory (and its subdirectories) are the only directories that the MCP server has access to.

Now we can add this server's tools to our `availableTools`:

```js
const availableTools = {
  ivs: (await ivsClient.listTools()),
  filesystem: (await fileSystemClient.listTools())
};
```

And a `findClient()` method to search for the appropriate client to use when Bedrock wants to use a tool. 

```js
const findClient = (toolName) => {
  let client;
  Object.keys(availableTools).forEach((label) => {
    const tool = availableTools[label].tools.find(tool => tool.name === toolName);
    if (tool) client = clients[label];
  });
  return client;
};
```

This could get tricky if multiple servers have identically named tools, so keep an eye out for this possibility. I fully expect this limitation to be overcome in the future, once the MCP client project matures a bit.

## MCP Client Flow

It might help to visualize the flow with of a few prompts within the client to understand the back and forth between the server, Bedrock, and the client. 

![Client Prompt to Bedrock](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-2twxxzs93zth8yvh5jcn.png)
<hr/>
![Client Calls Server](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-dfs5qt3k81v3dyyexz1n.png)
<hr/>
![Client Sends Tool Reply to Bedrock](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7nt2nsrv8ckb102rcygn.png)
<hr/>
![Client Calls Server Again](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-tcn2xunzx9qh91fi1k0u.png)
<hr/>
![Client Sends Next Tool Reply to Bedrock](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-7wdtwvpgzr7rgfdpp0zh.png)
<hr/>
![Client Snarkily Calls One More Time](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-f282l2nza1gdieraarpu.png)
<hr/>
![Bedrock Summary](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/devto-cmus3kastr50fiou81rk.png)

<h2 id="sample-mcp-client">Sample MCP Client</h2>

Here is the full sample code for this demo Amazon IVS MCP client that works with the MCP server that we created in part 2 of this series.

### Environment Variables

To run this demo, you'll need to set the following environment variables.

- `AWS_REGION`: AWS region for Bedrock and Amazon IVS services
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `ALLOWED_DIRS`: Comma-separated list of directories the filesystem tool can access (ex: `export ALLOWED_DIRS="/path/to/project,/another/path/to/project"` )
- `MODEL_ID`: Bedrock model ID (defaults to Claude 3.7 Sonnet: `us.anthropic.claude-3-7-sonnet-20250219-v1:0`)
- `RAG_KNOWLEDGEBASE_ID`: (Optional) ID for an Amazon IVS RAG knowledge base (**Note:** This should be an ID like `AB1ABCD1AA`, not the ARN!)
- `IVS_SERVER_PATH`: Path to the custom Amazon IVS MCP Server on your local machine (required)


{% details package.json %}
```json
{
  "name": "amazon-ivs-mcp-client-demo",
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
    "dev": "",
    "test": ""
  },
  "dependencies": {
    "@aws-sdk/client-bedrock-runtime": "^3.774.0",
    "@modelcontextprotocol/sdk": "^1.7.0"
  }
}
```
{% enddetails %}

{% details banner.txt %}
```txt
Amazon IVS MCP Client
```
{% enddetails %}

{% details index.js %}
```js
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { BedrockRuntimeClient, ConverseCommand } from '@aws-sdk/client-bedrock-runtime';
import readline from 'node:readline';
import util from 'node:util';
import fs from 'node:fs';

const banner = fs.readFileSync('banner.txt', 'utf8');
const printBanner = () => {
  const red = '\x1b[31m';
  const reset = '\x1b[0m';
  console.log(`\n${red}${banner}${reset}\n`);
};
printBanner();

const MAX_TURNS = 75;
let currentTurn = 0;

const IVS_SERVER_PATH = process.env.IVS_SERVER_PATH;
if (!IVS_SERVER_PATH) {
  throw new Error('IVS_SERVER_PATH environment variable is not set. This variable must point to the custom IVS MCP Server on this machine!');
}
if (!fs.existsSync(IVS_SERVER_PATH)) {
  throw new Error(`IVS_SERVER_PATH environment variable is set to ${IVS_SERVER_PATH} but this path does not exist!`);
}

const VERBOSE = process.env.VERBOSE?.toLowerCase() === 'true' || false;

// a list of allowed dirs for the Filesystem MCP server
// ex: ALLOWED_DIRS="/path/to/dir,/another/dir"
const allowedDirs = process.env.ALLOWED_DIRS.split(',');
const MODEL_ID = process.env.MODEL_ID || 'us.anthropic.claude-3-7-sonnet-20250219-v1:0';
const bedrockRuntimeClient = new BedrockRuntimeClient({
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

let sessionMessages = [];
let sessionUsage = [];

const ivsTransport = new StdioClientTransport({
  command: "node",
  args: [IVS_SERVER_PATH],
  env: {
    ...process.env,
    RAG_KNOWLEDGEBASE_ID: process.env.RAG_KNOWLEDGEBASE_ID,
    AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
    AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,
    AWS_REGION: process.env.AWS_REGION,
  }
});

const ivsClient = new Client(
  {
    name: "IVS-MCP-Client",
    version: "1.0.0"
  },
  {
    capabilities: {
      prompts: {},
      resources: {},
      tools: {}
    }
  }
);

await ivsClient.connect(ivsTransport);

const fileSystemTransport = new StdioClientTransport({
  command: "npx",
  args: [
    "-y",
    "@modelcontextprotocol/server-filesystem",
    ...allowedDirs,
  ],
});

const fileSystemClient = new Client(
  {
    name: "Filesystem-Client",
    version: "1.0.0"
  },
  {
    capabilities: {
      prompts: {},
      resources: {},
      tools: {}
    }
  }
);

await fileSystemClient.connect(fileSystemTransport);

const availableTools = {
  ivs: (await ivsClient.listTools()),
  filesystem: (await fileSystemClient.listTools())
};
const clients = {
  ivs: ivsClient,
  filesystem: fileSystemClient
};

const sleep = (ms) => {
  return new Promise(resolve => setTimeout(resolve, ms));
};

const startThinking = () => {
  const characters = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  const cursorEsc = {
    hide: '\u001B[?25l',
    show: '\u001B[?25h',
  };
  process.stdout.write(cursorEsc.hide);

  let i = 0;
  const timer = setInterval(function () {
    process.stdout.write('\r' + characters[i++] + ' Thinking...');
    i = i >= characters.length ? 0 : i;
  }, 150);

  return () => {
    clearInterval(timer);
    process.stdout.write('\r');
    process.stdout.write(cursorEsc.show);
    process.stdout.write('\n');
  };
};

const bedrockConverse = async (messages) => {
  const stopThinking = startThinking();
  const inferenceConfig = {
    topP: 0.1,
    temperature: 0.2,
  };
  const input = {
    modelId: MODEL_ID,
    messages,
    inferenceConfig,
    toolConfig: toolsToBedrockSchema(availableTools),
    system: [
      {
        text: `Your specialty is Amazon Interactive Video Service (Amazon IVS). 
        Wherever possible, take advantage of the tools available to you to help users 
        learn as much as possible about Amazon IVS. 
        If you are asked to generate or evaluate code, you can query IVS 
        knowledge base tool to query for the latest documentation. 
        Since IVS is a newer service, with new versions being published often, 
        reinforce your knowledge by directly fetching the latest version of any 
        documentation returned from the knowledge base.
        If you are asked to edit a file, first summarize your changes and ask the user 
        to confirm them before writing or editing any file on the filesystem.`
      }
    ],
  };
  const converseRequest = new ConverseCommand(input);
  let converseResponse;
  try {
    converseResponse = await bedrockRuntimeClient.send(converseRequest);
  }
  catch (error) {
    stopThinking();
    if (error.name == 'ThrottlingException') {
      console.log(`🛑 Bedrock API Call Throttled. Trying again after 60 second cooldown...`);
      await sleep(60000);
      return await bedrockConverse(messages);
    }
    else {
      console.error(error);
    }
  }
  stopThinking();
  return converseResponse;
};

const toolsToBedrockSchema = (availableTools) => {
  const tools = [];
  Object.keys(availableTools).forEach((server) => {
    tools.push(availableTools[server].tools.map(tool => {
      let props = {};
      Object.keys(tool.inputSchema.properties).forEach(prop => {
        props[prop] = {
          "type": tool.inputSchema.properties[prop].type,
          "description": tool.inputSchema.properties[prop]?.description || prop,
        };
      });
      return {
        "toolSpec": {
          "name": tool.name,
          "description": tool?.description || tool.name,
          "inputSchema": {
            "json": {
              "type": tool.inputSchema.type,
              "properties": props,
              "required": tool.inputSchema.required || []
            }
          }
        }
      };
    }));
  });
  return {
    tools: tools.flat()
  };
};

const findClient = (toolName) => {
  let client;
  Object.keys(availableTools).forEach((label) => {
    const tool = availableTools[label].tools.find(tool => tool.name === toolName);
    if (tool) client = clients[label];
  });
  return client;
};

const useTool = async (response) => {
  const item = response.output.message.content.find(item => Object.keys(item).indexOf('toolUse') > -1);
  const toolInfo = item.toolUse;
  console.log(`🔨 Calling MCP Server tool '${toolInfo.name}' ${VERBOSE ? 'with input: ' : ''}`);
  if (VERBOSE) {
    console.log(util.inspect(toolInfo?.input, {
      showHidden: false,
      depth: 20,
      colors: true,
    }));
  }
  await callTool(toolInfo);
  console.log(`🔎 Sending MCP Server's '${toolInfo.name}' response to Bedrock...`);
  return await bedrockConverse(sessionMessages);
};

const callTool = async (toolInfo) => {
  try {
    const toolName = toolInfo.name;
    const client = findClient(toolName);
    const result = await client.callTool({ name: toolName, arguments: toolInfo.input });
    sessionMessages.push({
      role: "user",
      content: [{ toolResult: { ...result, toolUseId: toolInfo.toolUseId } }]
    });
    return sessionMessages;
  }
  catch (error) {
    console.error('Error handling tool call:', error);
    return [`[Error calling tool ${toolInfo?.name || 'unknown'}: ${error.message}]`];
  }
};

const handleResponse = async (response) => {
  let ret = { isFinished: true, response };
  if (VERBOSE) {
    console.log(util.inspect(response, {
      showHidden: false,
      depth: 20,
      colors: true,
    }));
  }
  if (response?.output?.message?.content[0]?.text) {
    // bedrock output
    console.log('\n🟢 ' + response?.output?.message?.content[0]?.text + '\n');
  };
  if (response.stopReason === 'tool_use') {
    response = await useTool(response);
    sessionMessages.push(response.output.message);
    ret = { isFinished: false, response };
  }
  return ret;
};

const handlePrompt = async (prompt) => {
  sessionMessages.push({
    role: "user",
    content: [{ text: prompt }],
  });
  let response = await bedrockConverse(sessionMessages);
  updateUsage(response?.usage);
  sessionMessages.push(response.output.message);
  let isFinished = false;
  currentTurn = 0;
  while (!isFinished) {
    currentTurn++;
    const processedResponse = await handleResponse(response);
    isFinished = processedResponse.isFinished;
    response = processedResponse.response;
    updateUsage(response?.usage);
    if (response.stopReason === 'tool_use' && currentTurn >= MAX_TURNS && !isFinished) {
      console.log(`🚨 Reached max turns (${MAX_TURNS}). Let's stop here...`);
      const item = response.output.message.content.find(item => Object.keys(item).indexOf('toolUse') > -1);
      sessionMessages.push({
        role: "user",
        content: [
          {
            toolResult: {
              toolUseId: item.toolUse.toolUseId,
              content: [{
                text: 'Reached the maximum number of turns. Provide a detailed summary of your progress so far.',
              }]
            }
          }
        ]
      });
      response = await bedrockConverse(sessionMessages);
      if (response?.output?.message?.content[0]?.text === undefined) {
        console.log(`⚠️  Bedrock response was empty. Trying again...`);
        sessionMessages.push({
          role: 'user',
          content: [{
            text: 'Reached the maximum number of turns. Provide a detailed summary of your progress so far.'
          }]
        });
        response = await bedrockConverse(sessionMessages);
      }
      await handleResponse(response);
      isFinished = true;
    }
  };
};

const updateUsage = (usage) => {
  if (!usage) return;
  sessionUsage.push(usage);
};

const getSessionUsage = () => {
  return sessionUsage.reduce((acc, cur) => {
    acc.inputTokens += cur.inputTokens;
    acc.outputTokens += cur.outputTokens;
    acc.totalTokens += cur.totalTokens;
    return acc;
  }, { inputTokens: 0, outputTokens: 0, totalTokens: 0 });
};

const printUsage = (label = true) => {
  console.log(`📈 ${label ? 'Current Session Usage: ' : ''}${util.inspect(getSessionUsage(), { colors: true, depth: null })}`);
};

const init = () => {
  console.log(`\n❓ Ask a question, or try the following commands: clear-context, session-usage. Use 'quit' to exit.\n`);

  let userInput = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    historySize: 50,
    prompt: '\x1b[34m> \x1b[0m',
  });
  userInput.on('line', async (prompt) => {
    switch (prompt) {
      case 'help':
        console.log(`❓ Ask a question, or try the following commands: clear-context, session-usage. Use 'quit' to exit.`);
        break;
      case 'quit':
      case 'exit':
        console.log(`✌️ Thanks for using the IVS MCP Client.`);
        printUsage();
        process.exit(0);
        break;
      case 'clear-context':
      case 'clear':
        sessionMessages = [];
        console.log('🧹 Session context window cleared.');
        console.log('⭐️ Let\'s start over!');
        break;
      case 'session-usage':
      case 'usage':
        printUsage();
        break;
      default:
        await handlePrompt(prompt);
        break;
    }
    userInput.prompt();
  });
  userInput.on('SIGINT', () => {
    console.log(`\n✌️ Thanks for using the IVS MCP Client.`);
    printUsage();
    process.exit(0);
  });
  userInput.prompt();
};

init();
```
{% enddetails %}

## Summary

This concludes our short journey into using MCP clients and servers to learn more about our Amazon IVS resources. As you can see, the Model Context Protocol gives us the ability to provide missing data and context to our LLM client applications. This means our applications can help us learn about our data in new ways, and even help us quickly prototype new applications for technologies that existing foundation models are less familiar with like Amazon IVS. How will you be using MCP in your applications?