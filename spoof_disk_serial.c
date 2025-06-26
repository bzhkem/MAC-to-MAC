// SPDX-License-Identifier: GPL
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/blkdev.h>
#include <linux/genhd.h>
#include <linux/fs.h>
#include <linux/hdreg.h>
#include <linux/string.h>

static char *serial = "KERNELSPOOF1234";
static char *device = "sda";
module_param(serial, charp, 0644);
MODULE_PARM_DESC(serial, "Fake serial");
module_param(device, charp, 0644);
MODULE_PARM_DESC(device, "Block device name (e.g. sda, sdb)");

static struct file_operations *orig_fops = NULL;
static struct file_operations new_fops;
static int spoofed = 0;

static int spoof_ioctl(struct block_device *bdev, fmode_t mode, unsigned int cmd, unsigned long arg)
{
    if (cmd == HDIO_GET_IDENTITY) {
        struct hd_driveid id;
        memset(&id, 0, sizeof(id));
        strncpy((char *)id.serial_no, serial, sizeof(id.serial_no)-1);
        if (copy_to_user((void __user *)arg, &id, sizeof(id)))
            return -EFAULT;
        return 0;
    }
    return orig_fops->ioctl(bdev, mode, cmd, arg);
}

static int __init spoof_init(void)
{
    struct gendisk *gd;
    int minor = 0;

    if (device && strlen(device) == 3 && device[0]=='s' && device[1]=='d' && device[2]>='a' && device[2]<='z')
        minor = (device[2]-'a')*16;

    gd = get_gendisk(MKDEV(8, minor), NULL);
    if (!gd || !gd->fops) {
        pr_err("Could not get gendisk for /dev/%s\n", device);
        return -ENODEV;
    }
    if (!gd->fops->ioctl) {
        pr_err("Device /dev/%s has no ioctl handler\n", device);
        return -EINVAL;
    }

    memcpy(&new_fops, gd->fops, sizeof(new_fops));
    new_fops.ioctl = spoof_ioctl;
    orig_fops = (struct file_operations *)gd->fops;
    gd->fops = &new_fops;
    spoofed = 1;
    pr_info("[disk-serial-spoofer] Spoofed /dev/%s serial as: %s\n", device, serial);
    return 0;
}

static void __exit spoof_exit(void)
{
    struct gendisk *gd;
    int minor = 0;

    if (device && strlen(device) == 3 && device[0]=='s' && device[1]=='d' && device[2]>='a' && device[2]<='z')
        minor = (device[2]-'a')*16;

    if (spoofed) {
        gd = get_gendisk(MKDEV(8, minor), NULL);
        if (gd && orig_fops)
            gd->fops = orig_fops;
        pr_info("[disk-serial-spoofer] Restored original fops for /dev/%s\n", device);
    }
}

module_init(spoof_init);
module_exit(spoof_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("YourName");
MODULE_DESCRIPTION("Disk Serial Kernel Spoofer with Menu");
