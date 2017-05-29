# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Nebula: Custom EAS Kernel By @Eliminater74 For 
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=0
do.fix_pnpmgr=0
do.pnpmgr=1
do.fix_pnpmgr_ramdisk=0
do.eas_support=1
do.boost_scripts=0
do.cmdlinestr=0
do.system_blobs=0
device.name1=htc_pmewl
device.name2=htc_pmeuhl
device.name3=htc_pmewhl
device.name4=htc10
device.name5=htc
} # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel permissions
# set permissions for included ramdisk files
chmod -R 755 $ramdisk
# chmod 644 $ramdisk/sbin/media_profiles.xml
file_getprop() { grep "^$2" "$1" | cut -d= -f2; }

## AnyKernel install
dump_boot;

# begin ramdisk changes

#### Ramdisk Changes For EAS Kernel Only. Stock Based Mostly ####

setcmdline "androidboot.selinux" "permissive"
setcmdline "enforcing" "0"
setcmdline "selinux" "1"

# end ramdisk changes

write_boot;

## end install
# dump_boot

# backup_file <file>

# replace_string <file> <if search string> <original string> <replacement string>

# replace_section <file> <begin search string> <end search string> <replacement string>

# remove_section <file> <begin search string> <end search string>

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>

# replace_line <file> <line replace string> <replacement line>

# remove_line <file> <line match string>

# prepend_file <file> <if search string> <patch file>

# insert_file <file> <if search string> <before|after> <line match string> <patch file>

# append_file <file> <if search string> <patch file>

# replace_file <file> <permissions> <patch file>

# patch_fstab <fstab file> <mount match name> <fs match type> <block|mount|fstype|options|flags> <original string> <replacement string>

# seadd [-Z / -z <domain> | -s <source type>] [-t <target type>] [-c <class>] [-z <domain>] [-p <perm,list>] [-a <type attr>]
# add a new policy rule/domain to the sepolicy

# secheck [-s <source type>] [-c <class>]
# check if a given context label or class exists in the sepolicy

# import_rc <rc file>
# adds an init rc file as an import to init.rc, it will be imported last

# context_set <file path regex> <context>
# use this to set selinux contexts of file paths

# ueventd_set <device node> <permissions> <chown> <chgrp>
# use this to set permissions of /dev nodes

# remove_service <service name>
# this comments out a service entry entirely, as well as commands referencing it

# disable_service <service name>
# this only sets a service to disabled, it won't prevent it from being started manually

# delprop <prop>
# delete a prop from both default.prop and build.prop

# setprop <prop> <value>
# set a prop value in default.prop

# setcmdline <key> <value>
# set a key's value on the boot image's initial command line

# setperm <directory permissions> <file permissions> <directory>
# recursively sets permissions of files & directories

# write_boot
