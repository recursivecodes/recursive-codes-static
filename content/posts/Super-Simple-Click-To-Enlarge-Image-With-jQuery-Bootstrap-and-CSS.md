---
title: "Super Simple \"Click To Enlarge Image\" With jQuery, Bootstrap and CSS"
slug: "Super-Simple-Click-To-Enlarge-Image-With-jQuery-Bootstrap-and-CSS"
author: "Todd Sharp"
date: 2020-02-18
summary: "In this post, I'll show you how I added support for \"click to enlarge\" to the images here on my blog."
tags: ["HTML", "JavaScript"]
keywords: "jquery, bootstrap, css, html"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/1260/banner_50e1d047485bb108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

I've been spending a little free time lately showing this blog some love. Over the weekend I created a custom script to syndicate all of my posts from [my work blog](https://blogs.oracle.com/author/todd-sharp) here on my personal blog, just for some cross promotion and to keep my personal blog updated with all of the knowledge and content that I share on that blog. Last night I added another feature that I had been wanting to add for a long time: the ability to view a full size image by clicking on an image in a post. I use Bootstrap for my blog, and typically add `img-responsive` to my images so that they look good on all screens. But sometimes that makes it a bit hard to see what's going on in an image and seeing as how almost all of the images that I share are some sort of screenshot that demos something, that simply wasn't a great user experience.

Creating this feature was really easy. So easy, in fact, that you might think it's strange that I'm blogging about it. Thing is - in an industry that is prone to overengineering - sometimes the simple solutions are the ones worth sharing. Also, I wanted to point out that I'm using jQuery [(]***gasp\...***[) to accomplish it.  Let me know when you're done clutching your pearls, and I'll explain. You see, there's simply nothing wrong with jQuery. In fact, 10+ years in - there is still nothing better at DOM traversal and manipulation. And although we've come a long way since the dark ages of the internet, browsers still aren't fully compatible with one another. So for simple solutions like this - and sometimes things that aren't so simple - I still believe in and trust jQuery. ]Enough pontificating, on to the code. 

It begins with a simple Bootstrap modal dialog:
```html
<div class="modal in" id="viewImg" tabindex="-1" role="dialog" style="display: block;">
  <div class="modal-dialog modal-lg">
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">×</span></button>
        <h4 class="modal-title">View Image</h4>
      </div>
      <div class="modal-body">
        <div id="imgViewer" style="overflow-x: scroll;">
        </div>
      </div>
    </div>
  </div>
</div>
```



I set the `overflow-x` to `scroll` so that the image wouldn't overflow the modal - users can scroll to view the entire details. Next, I listen for clicks on images and set the image in to the modal, remove the `img-responsive` class and show it:
```javascript
$('img').on('click', function(e) {
  $('#imgViewer').html('').append( $(e.currentTarget).clone().removeClass('img-responsive').removeClass('img-thumbnail') )
  $('#viewImg').modal('show')
})
```



The only other bit was to add a bit of text below each image to let the user know that they can click an image to view it full size (because what good is a feature if the user doesn't know it exists). 

{{< callout >}}
**Note: **You must wrap the image in a block element because the img tag does not support child elements.
{{< /callout >}}
```javascript
$('img').each(function(i,e) {
  $(e).wrap('<div class="img-wrapper"></div>')
})
```



Finally, the CSS to add the text:
```css
.img-wrapper::after {
    font-size: 12px;
    content: 'Click Image To View Full Size';
    display: block;
}
```



Update: [Kenny](https://twitter.com/ispykenny) on Twitter pointed out that Macs typically hide the scrollbar when using a trackpad, so I added a bit of CSS to make it visible at all times on the `imgViewer` element.
```css
#imgViewer::-webkit-scrollbar {
    -webkit-appearance: none;
    height: 10px;
}
#imgViewer::-webkit-scrollbar-thumb {
    border-radius: 5px;
    background-color: rgba(0,0,0,.5);
    box-shadow: 0 0 1px rgba(255,255,255,.5);
}
```



And that's all it takes. Here's an example - resize your browser or view on mobile to see how it works.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/test-banner-img.png)

\

Image by [jpeter2](https://pixabay.com/users/jpeter2-697843) from [Pixabay](https://pixabay.com)
