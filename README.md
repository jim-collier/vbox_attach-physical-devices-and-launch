# VirtualBox: Attach physical device[s], and launch VM

## Problems solved

### Problem 1

You want to run a Linux installation on bare metal, _and_ as a virtual machine guest, under either a Linux, Windows, or MacOS host.

But attaching a physical disk as a raw VMDK is difficult through VirtualBox. Worse, the underlying device mappings change with every reboot or device attach/reattach (even if the /dev names stay the same).

#### Solution

With this script, you can specify one or more raw block devices to map, mount, and start a VM with. (Block devices can be whole disks and/or individual partitions.)

Linux runs great, without complaint, running first as a virtual machine, then a real machine, then back to virtual. (In any order.)

If it's running on real metal, the native graphics drivers will load (e.g. Intel, Nvidia, Nouveau, etc.), and the Guest Additions won't load. If it's running as a virtual machine, the Guest Additions will load, and native graphics drivers won't. (This is handled by the Linux kernel automagically, not by this tool.)

It's truly the best of both worlds.

#### Problem 2

You want fast and reliable native filesystem access to locally attached disks, from an operating system that doesn't support it well if at all. For example:

- Native ZFS filesystem access from within Windows.
- Native Btrfs filesystem access from within Windows, MacOS, or BSD.
- Native NTFS filesystem access from within Linux, BSD, or MacOS.

### Solution

With one of these scripts, you can attach the local disks to the VM as "raw" virtual disks - and even boot form one - but without the performance penalty of virtual disk images.

## Notes

- Running the bash script on MacOS or BSD hosts has not yet been tested.
- VMware (even Player) provides a GUI for mapping raw VMDKs, and does a decent job of not getting confused about their mappings across reboots. But if you've already chosen the mostly FLOSS VirtualBox over commercial VMware, this may not matter too much to you.
