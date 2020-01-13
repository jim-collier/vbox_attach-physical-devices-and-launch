# VirtualBox: Attach physical device[s], and launch VM<!-- omit in toc -->

## Table of contents<!-- omit in toc -->

- [Problems solved](#problems-solved)
	- [Problem 1](#problem-1)
		- [Solution](#solution)
	- [Problem 2](#problem-2)
		- [Solution](#solution-1)
- [Notes](#notes)
- [To-do](#to-do)
	- [Windows CMD version](#windows-cmd-version)
	- [\*nix bash version](#nix-bash-version)

## Problems solved

### Problem 1

You want to run a Linux or BSD installation on bare metal, _and_ as a virtual machine guest under either Windows, MacOS, or different BSD or Linux host.

But attaching a physical disk as a raw VMDK is difficult through VirtualBox. Worse, the underlying device mappings change with every reboot or device attach/reattach (even if the /dev names stay the same).

#### Solution

With this script, you can specify one or more raw block devices to map, mount, and start a VM with. (Block devices can be whole disks and/or individual partitions.)

Linux runs great, without complaint, running first as a virtual machine, then a real machine, then back to virtual. (In any random order.)

- If Linux is running on real metal, the native graphics drivers will load (e.g. Intel, Nvidia, Nouveau, etc.), and the Guest Additions won't load.
- If it's running as a virtual machine, the Guest Additions will load, and native graphics drivers won't.
- All of this is handled by the Linux kernel automagically, not by this tool.

It's truly the best of both worlds.

### Problem 2

You want fast and reliable native filesystem access to locally attached disks, from an operating system that doesn't support that file system well, it at all. For example:

- Native ZFS filesystem from within Windows.
- Native Btrfs filesystem access from within Windows, MacOS, or BSD.
- Native NTFS filesystem access from within Linux, BSD, or MacOS.

#### Solution

With one of these scripts, you can attach the local disks to the VM as "raw" virtual disks - and even boot form one - but without the performance penalty of virtual disk images.

## Notes

- Running the bash script on MacOS or BSD hosts has not yet been tested.
- VMware (even Player) provides a GUI for mapping raw VMDKs, and does a decent job of not getting confused about their mappings across reboots. But if you've already chosen the mostly FLOSS VirtualBox over commercial VMware, this may not matter too much to you.
- This should in theory also work with Solaris, Illumos, and any other Unix/BSD/Linux-like operating system that runs Bash scripts and supports POSIX commands. (But not yet specifically tested and debugged for non-Linux platforms).

## To-do

### Windows CMD version

- [ ] Remove unused boilerplate code
- [ ] Remove reliance on closed-source helper program (oldchoice.exe)
- [ ] Include source code for (or remove reliance on) open-source helper program (sleep.exe)

### \*nix bash version

- [ ] Remove unused boilerplate code
