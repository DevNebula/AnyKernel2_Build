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

insert_line init.rc "import /init.nebula.rc" after "import /init.power.rc" "import /init.nebula.rc";
insert_line init.rc "    mkdir /dev/stune/background" after "    mount cgroup none /dev/stune schedtune" "    mkdir /dev/stune/background"
insert_line init.rc "    mkdir /dev/stune/top-app" after "    mkdir /dev/stune/foreground" "    mkdir /dev/stune/top-app"
insert_line init.rc "    chown system system /dev/stune/background" after "    chown system system /dev/stune" "    chown system system /dev/stune/background"
insert_line init.rc "    chown system system /dev/stune/top-app" after "    chown system system /dev/stune/foreground" "    chown system system /dev/stune/top-app"
insert_line init.rc "    chown system system /dev/stune/background/tasks" after "    chown system system /dev/stune/tasks" "    chown system system /dev/stune/background/tasks"
insert_line init.rc "    chown system system /dev/stune/top-app/tasks" after "    chown system system /dev/stune/foreground/tasks" "    chown system system /dev/stune/top-app/tasks"
insert_line init.rc "    chmod 0664 /dev/stune/background/tasks" after "    chmod 0664 /dev/stune/tasks" "    chmod 0664 /dev/stune/background/tasks"
insert_line init.rc "    chmod 0664 /dev/stune/top-app/tasks" after "    chmod 0664 /dev/stune/foreground/tasks" "    chmod 0664 /dev/stune/top-app/tasks"
insert_line init.rc "    seclabel u:r:init:s0" before "    class main" "    seclabel u:r:init:s0"
insert_line init.rc "    seclabel u:r:init:s0" after "service usbdiag_init  /system/bin/sh /init.usbdiag.sh" "    seclabel u:r:init:s0"
insert_line init.power.rc "    seclabel u:r:init:s0" after "service setfps /system/bin/sh /system/etc/setfps.sh" "    seclabel u:r:init:s0"
insert_line init.power.rc "    seclabel u:r:init:s0" after "service setFOTA /system/bin/sh /system/etc/setFOTAfreq.sh" "    seclabel u:r:init:s0"

remove_section init.power.rc "#CPUSET" "top-app/cpus";
remove_section init.power.rc "# init PnPMgr node" "200";
remove_section init.power.rc "property:init.svc.thermal-engine=stopped" "/sys/power/pnpmgr/cluster/little/cpu3/thermal_freq";
remove_section init.power.rc "service pnpmgr" "root";
remove_section init.power.rc "thermal-engine=stopped" "little/cpu3/thermal_freq"
remove_section init.rc "# Reload policy from /data/security if present." "setprop selinux.reload_policy 1"

replace_line init.zygote64_32.rc "    writepid /dev/cpuset/foreground/tasks /sys/fs/cgroup/stune/foreground/tasks" "    writepid /dev/cpuset/foreground/tasks /dev/stune/foreground/tasks"
replace_line init.zygote32.rc "    writepid /dev/cpuset/foreground/tasks /dev/stune/foreground/tasks" "    writepid /dev/cpuset/foreground/tasks"
### Stop texfat from starting at this level ###
remove_line init.htc.storage.exfat.rc "    insmod /system/lib/modules/texfat.ko"

if [ -f init.qcom.power.rc ]; then
	mv init.qcom.power.rc init.qcom.power.rc.bak
fi;

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

# write_boot
