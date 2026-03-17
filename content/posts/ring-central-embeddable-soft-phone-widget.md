---
title: "Ring Central - Embeddable Soft Phone Widget"
slug: "ring-central-embeddable-soft-phone-widget"
author: "Todd Sharp"
date: 2020-02-21
summary: ""
tags: ["APIs"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1304/banner_57e8d7414c53a814f6da8c7dda793679173edfe056576c4870267fd69449c15fbf_1280.jpg"
---

In addition to APIs for voice, sms, chat and much more, Ring Central offers a really easy to use widget for making soft calls from within any application. This makes it really easy to add voice calling features to an intranet (or really any) application.

It's really easy to use, and can be done with JavaScript or an \<iframe\>:
```javascript
<script>
  (function() {
    var rcs = document.createElement("script");
    rcs.src = "https://ringcentral.github.io/ringcentral-embeddable/adapter.js";
    var rcs0 = document.getElementsByTagName("script")[0];
    rcs0.parentNode.insertBefore(rcs, rcs0);
  })();
</script>
```
```html
<iframe width="300" height="500" allow="microphone" src="https://ringcentral.github.io/ringcentral-embeddable/app.html">
</iframe>
```



Learn more [here](https://developers.ringcentral.com/embeddable-voice.html) or in the [docs](https://ringcentral.github.io/ringcentral-embeddable/)!

Image by [sasint](https://pixabay.com/users/sasint-3639875) from [Pixabay](https://pixabay.com)
