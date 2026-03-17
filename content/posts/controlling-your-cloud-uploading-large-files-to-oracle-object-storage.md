---
title: "Controlling Your Cloud - Uploading Large Files To Oracle Object Storage"
slug: "controlling-your-cloud-uploading-large-files-to-oracle-object-storage"
author: "Todd Sharp"
date: 2019-01-02
summary: "A look at using the multipart support for large file uploads in the OCI Object Storage API via the Java SDK."
tags: ["Cloud", "Java", "Open Source"]
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7c5f64f1-11c2-43c3-83ed-63b87ea51051/banner_create_multipart_upload.png"
---

In my [last post](/posts/controlling-your-cloud-a-look-at-the-oracle-cloud-infrastructure-java-sdk), we took an introductory look at working with the Oracle Cloud Infrastructure (OCI) API with the OCI Java SDK.  I mentioned that my initial motivation for digging into the SDK was to handle large file uploads to OCI Object Storage, and in this post, we'll do just that.  

As I mentioned, HTTP wasn't originally meant to handle large file transfers (Hypertext Transfer Protocol).  Rather, file transfers were typically (and often, still) handled via FTP (File Transfer Protocol).  But web developers deal with globally distributed clients and FTP requires server setup, custom desktop clients, different firewall rules and authentication which ultimately means large files end up getting transferred over HTTP/S.  Bit Torrent can be a better solution if the circumstances allow, but distributed files aren't often the case that web developers are dealing with.  Thankfully, many advances in HTTP over the past several years have made large file transfer much easier to deal with, the main advance being [chunked transfer encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding) (known as "chunked" or "multipart" file upload).  You can [read more about Oracle's support for multipart uploading](https://docs.cloud.oracle.com/iaas/Content/Object/Tasks/usingmultipartuploads.htm), but to explain it in the simplest possible way a file is broken up into several pieces ("chunks"), uploaded (at the same time, if necessary), and reassembled into the original file once all of the pieces have been uploaded.

The process to utilize the Java SDK for multipart uploading involves, at a minimum, three steps.  Here's the [JavaDocs for the SDK](https://docs.cloud.oracle.com/iaas/tools/java/latest/) in case you're playing along at home and want more info.

1.  Initiate the multipart upload
2.  Upload the individual file parts
3.  Commit the upload

The SDK provides methods for all of the steps above, as well as a few additional steps for listing existing multipart uploads, etc.  Individual parts can be up to 50 GiB.  The SDK process using the ObjectClient (see the previous post) necessary to complete the three steps above are explained as such:

1.  Call ObjectClient.createMultipartUpload, passing an instance of a CreateMultipartUploadRequest (which contains an instance of CreateMultipartUploadRequestDetails)

To break down step 1, you're just telling the API "Hey, I want to upload a file.  The object name is "foo.jpg" and it's content type is "image/jpeg".  Can you give me an identifier so I can associate different pieces of that file later on?"  And the API will return that to you in the form of a CreateMultipartUploadResponse.  Here's the code:
```groovy
// route handler (Bootstrap.groovy):
post "/oci/upload-create", { req, res ->
    def objectName = req.queryParams("objectName")
    def contentType = req.queryParams("contentType")
    return JsonOutput.toJson( objectService.createMultipartUpload(objectName, contentType) )
}

// service method (ObjectService.groovy):
def createMultipartUpload(objectName, contentType="application/octet-stream") {
    CreateMultipartUploadDetails createMultipartUploadDetails = CreateMultipartUploadDetails.builder()
            .object(objectName)
            .contentType(contentType)
            .build()
    CreateMultipartUploadRequest createMultipartUploadRequest = CreateMultipartUploadRequest.builder()
            .namespaceName(namespaceName)
            .bucketName(bucketName)
            .createMultipartUploadDetails(createMultipartUploadDetails)
            .build()
    return objectClient.createMultipartUpload(createMultipartUploadRequest)
}
```



So to create the upload, I make a call to /oci/upload-create and pass the objectName and contentType param.  I'm invoking it via Postman, but this could just as easily be a fetch() call in the browser:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7c5f64f1-11c2-43c3-83ed-63b87ea51051/create_multipart_upload.png)

So now we've got an upload identifier for further work (see "uploadId", #2 in the image above).  On to step 2 of the process:

2.  Call ObjectClient.uploadPart(), passing an instance of UploadPartRequest (including the uploadId, the objectName, a sequential part number, and the file chunk), which receives an UploadPartResponse.  The response will contain an "ETag" which we'll need to save, along with the part number, to complete the upload later on.

Here's what the code looks like for step 2:
```groovy
//route handler (Bootstrap.groovy):
post "/oci/upload-part", { req, res ->
    req.attribute("org.eclipse.jetty.multipartConfig", new MultipartConfigElement("/tmp"))
    HttpRequestWrapper reqRaw = req.raw()
    InputStream is = reqRaw.getPart("uploadPart").getInputStream()
    def objectName = req.queryParams("objectName")
    def partNum = req.queryParams("partNum").toInteger()
    def uploadId = req.queryParams("uploadId")
    return JsonOutput.toJson( objectService.uploadPart(is, objectName, uploadId, partNum) )
}

//service method (ObjectService.groovy):
def uploadPart(InputStream inputStream, String objectName, String uploadId, int partNum) {
    UploadPartRequest uploadPartRequest = UploadPartRequest.builder()
            .namespaceName(namespaceName)
            .bucketName(bucketName)
            .objectName(objectName)
            .uploadPartBody(inputStream)
            .uploadId(uploadId)
            .uploadPartNum(partNum)
            .build()
    return objectClient.uploadPart(uploadPartRequest)
}
```



And here's an invocation of step 2 in Postman, which was completed once for each part of the file that I chose to upload.  I'll save the ETag values along with each part number for use in the completion step.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7c5f64f1-11c2-43c3-83ed-63b87ea51051/upload_part.png)

Finally, step 3 is to complete the upload.

3.  Call ObjectClient.commitMultipartUpload(), passing an instance of CommitMultipartUploadRequest (which contains the object name, uploadId and an instance of CommitMultipartUploadDetails - which itself contains an array of CommitMultipartUploadPartDetails).

Sounds a bit complicated, but it's really not.  The code tells the story here:
```groovy
//route handler (Bootstrap.groovy):
post "/oci/upload-commit", { req, res ->
    /*
    expects a JSON object in the request body that looks like this:
    {
        uploadId: "",
        objectName: "",
        uploads: [
            {
                partNum: 1,
                ETag: "",
            }
        ]
    }
    */
    Map body = new JsonSlurper().parseText(req.body())
    def details = []
    body.uploads.each { Map file ->
        details << CommitMultipartUploadPartDetails.builder()
                .partNum(file.partNum)
                .etag(file.ETag)
                .build()

    }

    return JsonOutput.toJson( objectService.commitMultipartUpload(body.objectName, body.uploadId, details) )
}

//service method (ObjectService.groovy):
def commitMultipartUpload(String objectName, String uploadId, List<CommitMultipartUploadPartDetails> partDetails) {
    CommitMultipartUploadDetails commitMultipartUploadDetails = CommitMultipartUploadDetails.builder().partsToCommit(partDetails).build()
    CommitMultipartUploadRequest commitMultipartUploadRequest = CommitMultipartUploadRequest.builder()
            .namespaceName(namespaceName)
            .bucketName(bucketName)
            .objectName(objectName)
            .uploadId(uploadId)
            .commitMultipartUploadDetails(commitMultipartUploadDetails)
            .build()
    return objectClient.commitMultipartUpload(commitMultipartUploadRequest)
}
```



When invoked, we get a simple result confirming the completion of the multipart upload commit!  If we head over to our bucket in Object Storage, we can see the file details for the uploaded and reassembled file:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7c5f64f1-11c2-43c3-83ed-63b87ea51051/upload_details.png)

And if we visit the URL via a presigned URL (or directly, if the bucket is public), we can see the image.  In this case, a picture of my dog Moses:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/7c5f64f1-11c2-43c3-83ed-63b87ea51051/dsc00012.JPG)

As I've hopefully illustrated, the Oracle SDK for multipart upload is pretty straightforward to use once it's broken down into the steps required.  There are a number of frontend libraries to assist you with multipart upload once you have the proper backend service in place (in my case, the file was simply broken up using the "split" command on my MacBook).  
