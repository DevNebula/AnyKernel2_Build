# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# EDIFY properties
kernel.string=Nebula_HTC10_PME_N
do.devicecheck=1
do.initd=1
do.modules=0
do.cleanup=1
do.fix_pnpmgr=0
do.pnpmgr=0
do.fix_pnpmgr_ramdisk=0
do.boost_scripts=0
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

insert_line init.rc "import /init.nebula.rc" after "import /init.power.rc" "import /init.nebula.rc";


# end ramdisk changes

write_boot;

## end install

