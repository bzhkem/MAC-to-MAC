// SPDX-License-Identifier: GPL
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/genhd.h>
#include <linux/blkdev.h>
#include <linux/hdreg.h>
#include <linux/uaccess.h>
#include <linux/random.h>
#include <linux/string.h>
#include <asm/processor-flags.h>
#include <asm/paravirt.h>

#define SERIAL_LEN 16

static char serial[SERIAL_LEN + 1] = {0};
static char *device = "sda";
module_param(device, charp, 0644);
MODULE_PARM_DESC(device, "Nom du périphérique (ex: sda)");

static struct file_operations *orig_fops = NULL;
static struct file_operations patched_fops;
static struct gendisk *gd = NULL;

static const char charset[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

static void generate_random_serial(char *buf, size_t len) {
    int i;
    u8 rand;
    for (i = 0; i < len; ++i) {
        get_random_bytes(&rand, 1);
        buf[i] = charset[rand % (sizeof(charset) - 1)];
    }
    buf[len] = '\0';
}

static int spoof_ioctl(struct block_device *bdev, fmode_t mode, unsigned int cmd, unsigned long arg) {
    if (cmd == HDIO_GET_IDENTITY) {
        struct hd_driveid id;
        memset(&id, 0, sizeof(id));
        strncpy((char *)id.serial_no, serial, sizeof(id.serial_no) - 1);
        if (copy_to_user((void __user *)arg, &id, sizeof(id)))
            return -EFAULT;
        return 0;
    }

    if (orig_fops && orig_fops->ioctl)
        return orig_fops->ioctl(bdev, mode, cmd, arg);

    return -ENOTTY;
}

static void disable_write_protection(void) {
    write_cr0(read_cr0() & (~X86_CR0_WP));
}

static void enable_write_protection(void) {
    write_cr0(read_cr0() | X86_CR0_WP);
}

static int __init spoof_init(void) {
    int minor;

    generate_random_serial(serial, SERIAL_LEN);

    if (strlen(device) != 3 || strncmp(device, "sd", 2) != 0 || device[2] < 'a' || device[2] > 'z') {
        pr_err("[bzhspoof] Périphérique invalide : %s\n", device);
        return -EINVAL;
    }

    minor = (device[2] - 'a') * 16;
    gd = get_gendisk(MKDEV(8, minor), NULL);
    if (!gd || !gd->fops) {
        pr_err("[bzhspoof] Impossible d'accéder à /dev/%s\n", device);
        return -ENODEV;
    }

    orig_fops = (struct file_operations *)gd->fops;
    memcpy(&patched_fops, orig_fops, sizeof(struct file_operations));
    patched_fops.ioctl = spoof_ioctl;

    disable_write_protection();
    *(struct file_operations **)&gd->fops = &patched_fops;
    enable_write_protection();

    pr_info("[bzhspoof] Spoof activé sur /dev/%s avec serial '%s'\n", device, serial);
    return 0;
}

static void __exit spoof_exit(void) {
    if (gd && orig_fops) {
        disable_write_protection();
        *(struct file_operations **)&gd->fops = orig_fops;
        enable_write_protection();
        pr_info("[bzhspoof] Spoof retiré de /dev/%s\n", device);
    }
}

module_init(spoof_init);
module_exit(spoof_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Bzhkem");
MODULE_DESCRIPTION("Module noyau Linux pour spoof du numéro de série du disque (serial) avec randomisation automatique");
