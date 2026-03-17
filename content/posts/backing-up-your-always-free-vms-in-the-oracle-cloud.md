---
title: "Backing Up Your Always Free VMs In The Oracle Cloud"
slug: "backing-up-your-always-free-vms-in-the-oracle-cloud"
author: "Todd Sharp"
date: 2019-12-10
summary: "In this post we will take a look at backing up the boot volumes that are associated with your \"always free\" Oracle Cloud VMs."
tags: ["Cloud"]
keywords: "backup, Cloud, Disaster Recovery"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/365bc6f1-4bc2-46e7-8f3b-8f0a27c5f8cb/banner_sven_van_der_pluijm_htosd0ylxno_unsplash.jpg"
---

I have blogged quite a bit lately about the [always free tier on the Oracle Cloud](https://www.oracle.com/cloud/free/), and if you haven't signed up for your free account yet you should definitely do that.  Why?  Here are a few examples of projects you can deploy on the always free tier:

- [Stand Up A Free Blog In 15 Minutes With Ghost In The Oracle Cloud](/posts/stand-up-a-free-blog-in-15-minutes-with-ghost-in-the-oracle-cloud)
- [Blast Off To The Cloud: Free Team Chat With Rocket.Chat In The Oracle Cloud](/posts/team-chat-for-free-with-rocketchat-on-the-oracle-cloud)
- [Install & Run Discourse For Free In The Oracle Cloud](/posts/install-run-discourse-for-free-in-the-oracle-cloud)
- [Installing Node-RED In An Always Free VM On Oracle Cloud](/posts/installing-node-red-in-an-always-free-vm-on-oracle-cloud)
- [How To Setup And Run A Free Minecraft Server In The Cloud](/posts/how-to-setup-and-run-a-free-minecraft-server-in-the-cloud)

I've had a lot of excellent feedback on the posts above, but the one question that I've heard over and over is "how can I backup my data with the 'always free' tier".  And that's perfectly understandable, because nobody likes to lose data no matter how "small" the project that they are working on is. There are, however, several answers to the question "how can I backup my data" and each of those answers depend on the actual data that we are talking about. But for this blog post I'm going to focus solely on the data contained on the actual boot volume for your always free VMs.

## Boot Volume Backups

Backups of your boot volume (the block volume that contains your OS) in the Oracle Cloud work similarly to many other cloud providers. You can perform full, or incremental backups either manually or based on a custom or Oracle defined [backup policy](https://docs.cloud.oracle.com/iaas/Content/Block/Concepts/blockvolumebackups.htm#policy) (which specifies the type, frequency and retention). With the always free tier, you are allowed to create up to 5 backups of your block volumes, which should give you enough piece of mind to deploy a small workload to the tier and not worry about what might happen if the boot volume were to somehow become corrupted. The unfortunate news is that we can't take advantage of backup policies for the always free tier, but that doesn't mean we can't create a regularly scheduled backup of our boot volume. We just have to get a bit creative!

## Creating A Manual Backup

The first thing we should do is create a manual backup of our boot volume so that we have a base to work from going forward and are familiar with the UI and how to manually create one. Log in to your Oracle Cloud account and head to the sidebar menu and select 'Compute' -\> 'Boot Volumes':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/365bc6f1-4bc2-46e7-8f3b-8f0a27c5f8cb/2019_12_09_12_10_28.png)

Next, find your boot volume and select 'Create Manual Backup':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/365bc6f1-4bc2-46e7-8f3b-8f0a27c5f8cb/2019_12_09_12_11_07.png)

Give your backup a name in the dialog and click 'Create Boot Volume Backup':

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/365bc6f1-4bc2-46e7-8f3b-8f0a27c5f8cb/2019_12_09_12_14_09.png)

After a few minutes, your backup will be created and available:

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/365bc6f1-4bc2-46e7-8f3b-8f0a27c5f8cb/2019_12_09_12_14_48.png)

If you were to ever need to create a new instance from a backup you would need to view the backup details and create a boot volume from the backup. Once the boot volume is created you can launch a new instance from that boot volume.

## Creating A Backup Script

Since we can't use backup policies, we'll have to create a simple script to schedule the backup ourselves. The script will utilize the OCI CLI ([install it if you haven't done so yet](https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm)) and will perform the following tasks:

1.  Get info about the latest backup
2.  Create a new backup
3.  Delete the old backup
4.  Rename the new backup to the original backup name

If the creation of the new backup fails for whatever reason, the script will exit (to avoid deleting an existing backup before a new one is created). Once we create this script, we can schedule it on our local machine using `cron` to run however often we would like. Since it creates a new, full backup every time it runs it is not the most ideal scenario, but it will give you a level of comfort that your VM boot volume is backed up and you won't lose your data in the case of a rare failure. 

So let's take a look at the bash script I've created to perform the work required. This was created on a Mac, but should work on Linux easily (perhaps with minor modifications). As stated above, please make sure you have the OCI CLI installed before trying to run this script. You'll need to plug in a few variable values at the top of the script - the name of your manually created backup from earlier and the name of the OCI CLI profile that you want to use for the CLI calls (leave as `DEFAULT` if applicable). You'll also need [jq installed](https://stedolan.github.io/jq/) on your machine - modify the path to `jq` if necessary in the script (the reason the full path is used is because when the script is run as a `cron` task it will be run as root and the `root` user will not have `jq` on its `PATH`). Also modify the call to source your local profile as necessary on line 1. Again, this is necessary to make sure the script runs properly as a scheduled task.
```bash
#!/usr/bin/env bash
source ~/.zshrc

PROFILE_NAME=DEFAULT
BACKUP_NAME=[your_manual_backup_name]
TMP_BACKUP_NAME=$(date +%Y-%m-%d_%H-%M-%S)

echo "Running at ${TMP_BACKUP_NAME}."
echo "Getting previous backup..."

OUTPUT=$(oci bv boot-volume-backup list --display-name ${BACKUP_NAME} --lifecycle-state AVAILABLE --query "data [0].{bootVolumeId:"boot-volume-id",id:id}" --raw-output --profile ${PROFILE_NAME})
LAST_BACKUP_ID=$(echo $OUTPUT | /usr/local/bin/jq -r '.id')
BOOT_VOLUME_ID=$(echo $OUTPUT | /usr/local/bin/jq -r '.bootVolumeId')

echo "Last backup id: $LAST_BACKUP_ID"
echo "Boot volume id: $BOOT_VOLUME_ID"

echo "Creating new backup..."
NEW_BACKUP_ID=$(oci bv boot-volume-backup create --boot-volume-id ${BOOT_VOLUME_ID} --type FULL --display-name ${TMP_BACKUP_NAME} --wait-for-state AVAILABLE --query "data.id" --raw-output --profile ${PROFILE_NAME})

if [ -z "$NEW_BACKUP_ID" ]
then
    echo "New backup creation failed...Exiting script!"; exit
else
    echo "New backup id: $NEW_BACKUP_ID"
fi

echo "Deleting old backup..."
DELETED_BACKUP=$(oci bv boot-volume-backup delete --force --boot-volume-backup-id ${LAST_BACKUP_ID} --wait-for-state TERMINATED --profile ${PROFILE_NAME})

echo "Renaming temp backup..."
RENAMED_BACKUP=$(oci bv boot-volume-backup update --boot-volume-backup-id ${NEW_BACKUP_ID} --display-name ${BACKUP_NAME} --profile ${PROFILE_NAME})

echo "Backup process complete! Goodbye!"
```



You can run this script manually and you'll get output similar to the following:
```log
Running at 2019-12-09_11-20-00.
Getting previous backup...
Last backup id: ocid1.bootvolumebackup.oc1.iad...
Boot volume id: ocid1.bootvolume.oc1.iad...
Creating new backup...
New backup id: ocid1.bootvolumebackup.oc1.iad...
Deleting last backup...
Renaming temp backup...
Backup process complete! Goodbye!
```



You can now schedule the script execution and rest easy that your always free boot volumes will be backed up on a regular basis!

Photo by [Sven van der Pluijm](https://unsplash.com/@svenson?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/peace-of-mind?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
