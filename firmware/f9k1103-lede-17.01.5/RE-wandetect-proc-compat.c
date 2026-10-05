// SPDX-License-Identifier: GPL-2.0
/*
 * F9K1103 target-side compatibility for the Cudy wan_detect procfs ABI.
 *
 * CUDY-FIRST rule:
 *   /sbin/wandetect and all Cudy hotplug/user-space logic remain donor-owned.
 *   This module supplies only the missing kernel-facing procfs contract.
 *
 * Initial scope deliberately does NOT claim automatic DHCP/PPPoE detection
 * parity with Cudy's proprietary wan_detect.ko.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/string.h>
#include <linux/mutex.h>
#include <net/net_namespace.h>

#define RE_WD_MAX 128

struct re_wd_field {
	const char *name;
	char value[RE_WD_MAX];
	struct proc_dir_entry *pde;
	struct mutex lock;
};

static struct proc_dir_entry *re_wd_dir;

static struct re_wd_field re_wd_fields[] = {
	{ .name = "ipaddr",  .value = "" },
	{ .name = "gateway", .value = "" },
	{ .name = "macaddr", .value = "" },
	{ .name = "iface",   .value = "" },
	{ .name = "proto",   .value = "stop" },
	{ .name = "service", .value = "" },
};

static ssize_t re_wd_read(struct file *file, char __user *buf,
			  size_t count, loff_t *ppos)
{
	struct re_wd_field *f = PDE_DATA(file_inode(file));
	char tmp[RE_WD_MAX + 2];
	int len;

	if (!f)
		return -EINVAL;

	mutex_lock(&f->lock);
	len = scnprintf(tmp, sizeof(tmp), "%s\n", f->value);
	mutex_unlock(&f->lock);

	return simple_read_from_buffer(buf, count, ppos, tmp, len);
}

static ssize_t re_wd_write(struct file *file, const char __user *buf,
			   size_t count, loff_t *ppos)
{
	struct re_wd_field *f = PDE_DATA(file_inode(file));
	char tmp[RE_WD_MAX];
	size_t n;

	if (!f)
		return -EINVAL;
	if (!count)
		return 0;

	n = min(count, (size_t)(RE_WD_MAX - 1));
	if (copy_from_user(tmp, buf, n))
		return -EFAULT;
	tmp[n] = '\0';

	/* Match shell echo/cat semantics used by the Cudy donor scripts. */
	strim(tmp);

	mutex_lock(&f->lock);
	strlcpy(f->value, tmp, sizeof(f->value));
	mutex_unlock(&f->lock);

	return count;
}

static const struct file_operations re_wd_fops = {
	.owner = THIS_MODULE,
	.read = re_wd_read,
	.write = re_wd_write,
	.llseek = default_llseek,
};

static int __init re_wd_init(void)
{
	size_t i;

	re_wd_dir = proc_mkdir("wandetect", init_net.proc_net);
	if (!re_wd_dir)
		return -ENOMEM;

	for (i = 0; i < ARRAY_SIZE(re_wd_fields); i++) {
		mutex_init(&re_wd_fields[i].lock);
		re_wd_fields[i].pde = proc_create_data(
			re_wd_fields[i].name, 0644, re_wd_dir,
			&re_wd_fops, &re_wd_fields[i]);
		if (!re_wd_fields[i].pde)
			goto fail;
	}

	pr_info("re_wandetect_compat: Cudy procfs ABI ready; auto-detect not implemented\n");
	return 0;

fail:
	while (i > 0) {
		i--;
		remove_proc_entry(re_wd_fields[i].name, re_wd_dir);
	}
	remove_proc_entry("wandetect", init_net.proc_net);
	re_wd_dir = NULL;
	return -ENOMEM;
}

static void __exit re_wd_exit(void)
{
	size_t i;

	if (!re_wd_dir)
		return;

	for (i = 0; i < ARRAY_SIZE(re_wd_fields); i++)
		remove_proc_entry(re_wd_fields[i].name, re_wd_dir);

	remove_proc_entry("wandetect", init_net.proc_net);
	re_wd_dir = NULL;
}

module_init(re_wd_init);
module_exit(re_wd_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("OpenCudy F9K1103 compatibility");
MODULE_DESCRIPTION("Target-only procfs ABI for unchanged Cudy wan-detect userspace");
