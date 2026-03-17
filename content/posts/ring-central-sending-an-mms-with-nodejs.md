---
title: "Ring Central - Sending an MMS With Node.JS"
slug: "ring-central-sending-an-mms-with-nodejs"
author: "Todd Sharp"
date: 2020-02-21
summary: ""
tags: ["APIs"]
keywords: "java, mms, sms, api"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1310/banner_57e8d44b4c5bac14f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

I previously showed you how to [create and send an SMS using Ring Central](https://recursive.codes/blog/post/1280)and Node.JS, but in this post I want to show you how to send an MMS. It's pretty similar to the previous example, but there are a few differences that I wanted to point out.

{{< callout >}}
Note: There is a combined limit of 1.5M bytes for all attachments and a limit of 10 attachments for any request.
{{< /callout >}}
The full process is well [documented on their developer portal](https://developers.ringcentral.com/guide/messaging/sms/sending-images). The first step is to pull in the modules and create an instance of the SDK object and platform:
```javascript
const SDK = require('ringcentral')
const FormData = require('form-data')
const rcsdk = new SDK({
  server: "server_url", appKey: "client_id", appSecret: "client_secret"
})
const platform = rcsdk.platform()
```



Next, login to the platform (using your own credentials):
```javascript
platform.login({
  username: "username", extension: "extension_number", password: "password"
}).then(response => {
  
}).catch(e => {
  console.error(e)
})
```



Now in the login callback, create the MMS body, construct a new FormData object that includes the file that you want to post to the MMS recipient and post the form!
```javascript
const body = {
    from: { phoneNumber: "username" },
    to: [ { phoneNumber: "recipient_number" } ],
    text: 'Hello world'
}
const formData = new FormData()
file = {filename: 'request.json', contentType: 'application/json'};
formData.append('json',
              Buffer.from(JSON.stringify(body)),
              {filename: 'request.json', contentType: 'application/json'})
formData.append('attachment',
              require('fs').createReadStream('./test.jpg'))
platform.post('/account/~/extension/~/sms', formData)
    .then(response => {
        console.log('MMS sent: ' + response.json().id)
    })
    .catch(e => {
        console.error(e)
    })
```



And that's all it takes to send an MMS with Java and Ring Central!

Image by [cocoparisienne](https://pixabay.com/users/cocoparisienne-127419) from [Pixabay](https://pixabay.com)
