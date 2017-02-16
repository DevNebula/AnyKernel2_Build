# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# EDIFY properties
kernel.string=Nebula_HTC10_PME_N
do.devicecheck=1
do.initd=1
do.kernel=0
do.modules=0
do.cleanup=1
do.fix_pnpmgr=0
do.pnpmgr=0
do.fix_pnpmgr_ramdisk=0
do.eas_support=0
do.boost_scripts=0
do.aptxhd=1
do.cmdlinestr=0
do.system_blobs=0
device.name1=htc_pmewl
device.name2=htc_pmeuhl
device.name3=htc_pmewhl
device.name4=htc10
device.name5=htc

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

# write_boot
