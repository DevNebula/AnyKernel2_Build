## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;

cmdline=$split_img/boot.img-cmdline
default_prop=$ramdisk/default.prop
build_prop=/system/build.prop
ueventd=$ramdisk/ueventd.rc
sepolicy=$ramdisk/sepolicy
file_contexts=$ramdisk/file_contexts
seinject=$bin/sepolicy-inject
# default Android API to KitKat, use policy check to determine actual version
android_api=19

found_prop=false
[ -f "$default_prop" ] && found_prop=true

found_build_prop=false
[ -f "$build_prop" ] && found_build_prop=true

found_ueventd=false
[ -f "$ueventd" ] && found_ueventd=true

found_sepolicy=false
[ -f "$sepolicy" ] && found_sepolicy=true

found_file_contexts=false
[ -f "$file_contexts" ] && found_file_contexts=true

if $found_sepolicy && [ -x "$seinject" ]; then
	if   "$seinject" -e -c filesystem -P "$sepolicy" &&
	   ! "$seinject-N" -e -c filesystem -P "$sepolicy"
	then
		# Android 7.0+ (Nougat)
		android_api=24
		seinject="$seinject-N"
	elif "$seinject" -e -s gatekeeper_service -P "$sepolicy"
	then
		# Android 6.0 (Marshmallow)
		android_api=23
	elif "$seinject" -e -c service_manager -P "$sepolicy"
	then
		# Android 5.1 (Lollipop MR1)
		android_api=21
	fi
fi

chmod -R 755 $bin;
mkdir -p $ramdisk $split_img;

if [ "$is_slot_device" == 1 ]; then
  slot=$(getprop ro.boot.slot_suffix 2>/dev/null);
  test ! "$slot" && slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2);
  test "$slot" && block=$block$slot;
  if [ $? != 0 -o ! -e "$block" ]; then
    ui_print " "; ui_print "Unable to determine active boot slot. Aborting..."; exit 1;
  fi;
fi;

OUTFD=/proc/self/fd/$1;

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

# contains <string> <substring>
contains() { test "${1#*$2}" != "$1" && return 0 || return 1; }

# dump boot and extract ramdisk
dump_boot() {
  if [ ! -e "$(echo $block | cut -d\  -f1)" ]; then
    ui_print " "; ui_print "Invalid partition. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/nanddump" ]; then
    $bin/nanddump -f /tmp/anykernel/boot.img $block;
  else
    dd if=$block of=/tmp/anykernel/boot.img;
  fi;
  if [ -f "$bin/unpackelf" -a "$($bin/unpackelf -i /tmp/anykernel/boot.img -h -q 2>/dev/null; echo $?)" == 0 ]; then
    $bin/unpackelf -i /tmp/anykernel/boot.img -o $split_img;
    mv -f $split_img/boot.img-ramdisk.cpio.gz $split_img/boot.img-ramdisk.gz;
  elif [ -f "$bin/dumpimage" ]; then
    $bin/dumpimage -l /tmp/anykernel/boot.img;
    $bin/dumpimage -l /tmp/anykernel/boot.img > $split_img/boot.img-header;
    grep "Name:" $split_img/boot.img-header | cut -c15- > $split_img/boot.img-name;
    grep "Type:" $split_img/boot.img-header | cut -c15- | cut -d\  -f1 > $split_img/boot.img-arch;
    grep "Type:" $split_img/boot.img-header | cut -c15- | cut -d\  -f2 > $split_img/boot.img-os;
    grep "Type:" $split_img/boot.img-header | cut -c15- | cut -d\  -f3 | cut -d- -f1 > $split_img/boot.img-type;
    grep "Type:" $split_img/boot.img-header | cut -d\( -f2 | cut -d\) -f1 | cut -d\  -f1 | cut -d- -f1 > $split_img/boot.img-comp;
    grep "Address:" $split_img/boot.img-header | cut -c15- > $split_img/boot.img-addr;
    grep "Point:" $split_img/boot.img-header | cut -c15- > $split_img/boot.img-ep;
    $bin/dumpimage -i /tmp/anykernel/boot.img -p 0 $split_img/boot.img-zImage;
    test $? != 0 && dumpfail=1;
    if [ "$(cat $split_img/boot.img-type)" == "Multi" ]; then
      $bin/dumpimage -i /tmp/anykernel/boot.img -p 1 $split_img/boot.img-ramdisk.gz;
    else
      dumpfail=1;
    fi;
  elif [ -f "$bin/pxa1088-unpackbootimg" ]; then
    $bin/pxa1088-unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  else
    $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  fi;
  if [ $? != 0 -o "$dumpfail" ]; then
    ui_print " "; ui_print "Dumping/splitting image failed. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/mkmtkhdr" ]; then
    dd bs=512 skip=1 conv=notrunc if=$split_img/boot.img-ramdisk.gz of=$split_img/temprd;
    mv -f $split_img/temprd $split_img/boot.img-ramdisk.gz;
  fi;
  if [ -f "$bin/unpackelf" -a -f "$split_img/boot.img-dtb" ]; then
    case $(od -ta -An -N4 $split_img/boot.img-dtb | sed -e 's/del //' -e 's/   //g') in
      QCDT|ELF) ;;
      *) gzip $split_img/boot.img-zImage;
         mv -f $split_img/boot.img-zImage.gz $split_img/boot.img-zImage;
         cat $split_img/boot.img-dtb >> $split_img/boot.img-zImage;
         rm -f $split_img/boot.img-dtb;;
    esac;
  fi;
  mv -f $ramdisk /tmp/anykernel/rdtmp;
  mkdir -p $ramdisk;
  cd $ramdisk;
  gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;
  if [ $? != 0 -o -z "$(ls $ramdisk)" ]; then
    ui_print " "; ui_print "Unpacking ramdisk failed. Aborting..."; exit 1;
  fi;
  cp -af /tmp/anykernel/rdtmp/* $ramdisk;
}

# repack ramdisk then build and write image
write_boot() {
  cd $split_img;
  if [ -f "$bin/mkimage" ]; then
    name=`cat *-name`;
    arch=`cat *-arch`;
    os=`cat *-os`;
    type=`cat *-type`;
    comp=`cat *-comp`;
    test "$comp" == "uncompressed" && comp=none;
    addr=`cat *-addr`;
    ep=`cat *-ep`;
  else
    if [ -f *-cmdline ]; then
      cmdline=`cat *-cmdline`;
    fi;
    if [ -f *-board ]; then
      board=`cat *-board`;
    fi;
    base=`cat *-base`;
    pagesize=`cat *-pagesize`;
    kerneloff=`cat *-kerneloff`;
    ramdiskoff=`cat *-ramdiskoff`;
    if [ -f *-tagsoff ]; then
      tagsoff=`cat *-tagsoff`;
    fi;
    if [ -f *-osversion ]; then
      osver=`cat *-osversion`;
    fi;
    if [ -f *-oslevel ]; then
      oslvl=`cat *-oslevel`;
    fi;
    if [ -f *-second ]; then
      second=`ls *-second`;
      second="--second $split_img/$second";
      secondoff=`cat *-secondoff`;
      secondoff="--second_offset $secondoff";
    fi;
    if [ -f *-hash ]; then
      hash=`cat *-hash`;
      hash="--hash $hash";
    fi;
    if [ -f *-unknown ]; then
      unknown=`cat *-unknown`;
    fi;
  fi;
  for i in zImage zImage-dtb zImage.gz-dtb Image.gz Image Image-dtb Image.gz-dtb Image.bz2 Image.bz2-dtb Image.lzo Image.lzo-dtb Image.lzma Image.lzma-dtb Image.xz Image.xz-dtb Image.lz4 Image.lz4-dtb Image.fit; do
    if [ -f /tmp/anykernel/$i ]; then
      kernel=/tmp/anykernel/$i;
      break;
    fi;
  done;
  if [ ! "$kernel" ]; then
    kernel=`ls *-zImage`;
    kernel=$split_img/$kernel;
  fi;
  for i in dtb dt.img; do
    if [ -f /tmp/anykernel/$i ]; then
      dtb="--dt /tmp/anykernel/$i";
      break;
    fi;
  done;
  if [ ! "$dtb" -a -f *-dtb ]; then
    dtb=`ls *-dtb`;
    dtb="--dt $split_img/$dtb";
  fi;
  if [ -f "$bin/mkbootfs" ]; then
    $bin/mkbootfs $ramdisk | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  else
    cd $ramdisk;
    find . | cpio -H newc -o | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  fi;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Repacking ramdisk failed. Aborting..."; exit 1;
  fi;
  cd /tmp/anykernel;
  if [ -f "$bin/mkmtkhdr" ]; then
    $bin/mkmtkhdr --rootfs ramdisk-new.cpio.gz;
    mv -f ramdisk-new.cpio.gz-mtk ramdisk-new.cpio.gz;
    case $kernel in
      $split_img/*) ;;
      *) $bin/mkmtkhdr --kernel $kernel; kernel=$kernel-mtk;;
    esac;
  fi;
  if [ -f "$bin/mkimage" ]; then
    $bin/mkimage -A $arch -O $os -T $type -C $comp -a $addr -e $ep -n "$name" -d $kernel:$ramdisk boot-new.img;
  elif [ -f "$bin/pxa1088-mkbootimg" ]; then
    $bin/pxa1088-mkbootimg --kernel $kernel --ramdisk ramdisk-new.cpio.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset "$tagsoff" --unknown $unknown $dtb --output boot-new.img;
  else
    $bin/mkbootimg --kernel $kernel --ramdisk ramdisk-new.cpio.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" $hash $dtb --output boot-new.img;
  fi;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Repacking image failed. Aborting..."; exit 1;
  elif [ `wc -c < boot-new.img` -gt `wc -c < boot.img` ]; then
    ui_print " "; ui_print "New image larger than boot partition. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/futility" -a -d "$bin/chromeos" ]; then
    $bin/futility vbutil_kernel --pack boot-new-signed.img --keyblock $bin/chromeos/kernel.keyblock --signprivate $bin/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz boot-new.img --bootloader $bin/chromeos/empty --config $bin/chromeos/empty --arch arm --flags 0x1;
    if [ $? != 0 ]; then
      ui_print " "; ui_print "Signing image failed. Aborting..."; exit 1;
    fi;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ -f "$bin/blobpack" ]; then
    printf '-SIGNED-BY-SIGNBLOB-\00\00\00\00\00\00\00\00' > boot-new-signed.img;
    $bin/blobpack tempblob LNX boot-new.img;
    cat tempblob >> boot-new-signed.img;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ -f "/data/custom_boot_image_patch.sh" ]; then
    ash /data/custom_boot_image_patch.sh /tmp/anykernel/boot-new.img;
    if [ $? != 0 ]; then
      ui_print " "; ui_print "User script execution failed. Aborting..."; exit 1;
    fi;
  fi;
  if [ "$(strings /tmp/anykernel/boot.img | grep SEANDROIDENFORCE )" ]; then
    printf 'SEANDROIDENFORCE' >> /tmp/anykernel/boot-new.img;
  fi;
  if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
    $bin/flash_erase $block 0 0;
    $bin/nandwrite -p $block /tmp/anykernel/boot-new.img;
  else
    dd if=/dev/zero of=$block 2>/dev/null;
    dd if=/tmp/anykernel/boot-new.img of=$block;
  fi;
}

# backup_file <file>
backup_file() { test ! -f $1~ && cp $1 $1~; }

# replace_string <file> <if search string> <original string> <replacement string>
replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
      sed -i "s;${3};${4};" $1;
  fi;
}

# replace_section <file> <begin search string> <end search string> <replacement string>
replace_section() {
  begin=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
  for end in `grep -n "$3" $1 | cut -d: -f1`; do
    if [ "$begin" -lt "$end" ]; then
      sed -i "/${2//\//\\/}/,/${3//\//\\/}/d" $1;
      sed -i "${begin}s;^;${4}\n;" $1;
      break;
    fi;
  done;
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  begin=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
  for end in `grep -n "$3" $1 | cut -d: -f1`; do
    if [ "$begin" -lt "$end" ]; then
      sed -i "/${2//\//\\/}/,/${3//\//\\/}/d" $1;
      break;
    fi;
  done;
}

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>
insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    if [ "$(wc -l $1 | cut -d\  -f1)" -le "$line" ]; then
      echo "$5" >> $1;
    else
      sed -i "${line}s;^;${5}\n;" $1;
    fi;
  fi;
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

# remove_line <file> <line match string>
remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# insert_file <file> <if search string> <before|after> <line match string> <patch file>
insert_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

# patch_fstab <fstab file> <mount match name> <fs match type> <block|mount|fstype|options|flags> <original string> <replacement string>
patch_fstab() {
  entry=$(grep "$2" $1 | grep "$3");
  if [ -z "$(echo "$entry" | grep "$6")" ]; then
    case $4 in
      block) part=$(echo "$entry" | awk '{ print $1 }');;
      mount) part=$(echo "$entry" | awk '{ print $2 }');;
      fstype) part=$(echo "$entry" | awk '{ print $3 }');;
      options) part=$(echo "$entry" | awk '{ print $4 }');;
      flags) part=$(echo "$entry" | awk '{ print $5 }');;
    esac;
    newentry=$(echo "$entry" | sed "s;${part};${6};");
    sed -i "s;${entry};${newentry};" $1;
  fi;
}

# patch_cmdline <cmdline match string> [<replacement string>]
patch_cmdline() {
  cmdfile=`ls $split_img/*-cmdline`;
  if [ -z "$(grep "$1" $cmdfile)" ]; then
    cmdtmp=`cat $cmdfile`;
    echo "$cmdtmp $1" > $cmdfile;
  else
    match=$(grep -o "$1.*$" $cmdfile | cut -d\  -f1);
    sed -i -e "s;${match};${2};" -e 's;  ; ;' -e 's;[ \t]*$;;' $cmdfile;
  fi;
}

# patch_prop <prop file> <prop name> <new prop value>
patch_prop() {
  if [ -z "$(grep "^$2=" $1)" ]; then
    echo -ne "\n$2=$3\n" >> $1;
  else
    line=`grep -n "^$2=" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}s;.*;${2}=${3};" $1;
  fi;
}

# setperm <directory permissions> <file permissions> <directory>
# recursively sets permissions of files & directories
setperm() {
	find "$3" -type d -exec chmod "$1" {} \;
	find "$3" -type f -exec chmod "$2" {} \;
}

# setcmdline <key> <value>
# set a key's value on the boot image's initial command line
setcmdline() {
	[ -f "$cmdline" ] || touch "$cmdline"
	grep -q "\b$1=" "$cmdline" && sed -i "s|\b$1=.*\b|$1=$2|g" "$cmdline" && return
	sed -i "1 s/$/ $1=$2/" "$cmdline"
}

# setprop <prop> <value>
# set a prop value in default.prop
setprop() {
	$found_prop || return
	if grep -q "^[[:space:]]*$1[[:space:]]*=" "$default_prop"; then
		sed -i "s/^[[:space:]]*$1[[:space:]]*=.*$/$1=$2/g" "$default_prop"
	else
		echo "$1=$2" >> "$default_prop"
	fi
}

# delprop <prop>
# delete a prop from both default.prop and build.prop
delprop() {
	$found_prop && sed -i "/^[[:space:]]*$1[[:space:]]*=/d" "$default_prop"
	$found_build_prop && sed -i "/^[[:space:]]*$1[[:space:]]*=/d" "$build_prop"
}


# disable_service <service name>
# this only sets a service to disabled, it won't prevent it from being started manually
disable_service() {
	for rc in "$ramdisk"/*.rc; do
		grep -q "^[[:space:]]*service[[:space:]]\+$1\b" "$rc" || continue
		echo "Found service $1 in $rc"
		awk -vsc_name="$1" '
			$1 == "service" || $1 == "on" { in_sc = 0 }
			in_sc && $1 == "disabled" { next }
			{ print }
			$1 == "service" && $2 == sc_name {
				print "    disabled"
				in_sc = 1
			}
		' "$rc" > "$rc-"
		replace_file "$rc" "$rc-"
	done
}

# remove_service <service name>
# this comments out a service entry entirely, as well as commands referencing it
remove_service() {
	for rc in "$ramdisk"/*.rc; do
		grep -q "^[[:space:]]*\(service\|start\|stop\|restart\)[[:space:]]\+$1\b" "$rc" || continue
		echo "Found service $1 in $rc"
		awk -vsc_name="$1" '
			!NF || $1 ~ /^#/ { print; next }
			$1 == "service" || $1 == "on" { in_sc = 0 }
			$1 == "service" && $2 == sc_name { in_sc = 1 }
			in_sc || ($2 == sc_name && ($1 == "start" || $1 == "stop" || $1 == "restart")) { printf "#" }
			{ print }
		' "$rc" > "$rc-"
		replace_file "$rc" "$rc-"
	done
}

# ueventd_set <device node> <permissions> <chown> <chgrp>
# use this to set permissions of /dev nodes
ueventd_set() {
	$found_ueventd || return
	awk -vdev="$1" -vperm="$2" -vuser="$3" -vgroup="$4" '
		function pdev() {
			printf "%-25s %-6s %-10s %s\n", dev, perm, user, group
			set = 1
		}
		$1 == dev && !set { pdev() }
		$1 == dev { next }
		{ print }
		END { if (!set) pdev() }
	' "$ueventd" > "$ueventd-"
	replace_file "$ueventd" "$ueventd-"
}

# context_set <file path regex> <context>
# use this to set selinux contexts of file paths
context_set() {
	$found_file_contexts || return
	awk -vfile="$1" -vcontext="$2" '
		function pfcon() {
			printf "%-48s %s\n", file, context
			set = 1
		}
		$1 == file && !set { pfcon() }
		$1 == file { next }
		{ print }
		END { if (!set) pfcon() }
	' "$file_contexts" > "$file_contexts-"
	replace_file "$file_contexts" "$file_contexts-"
}

# import_rc <rc file>
# adds an init rc file as an import to init.rc, it will be imported last
import_rc() {
	insert_after_last "$ramdisk/init.rc" "import .*\.rc" "import /$1"
}

# secheck [-s <source type>] [-c <class>]
# check if a given context label or class exists in the sepolicy
secheck() {
	$found_sepolicy || return
	"$seinject" -e -P "$sepolicy" "$@" 2> /dev/null
}

# seadd [-Z / -z <domain> | -s <source type>] [-t <target type>] [-c <class>] [-z <domain>] [-p <perm,list>] [-a <type attr>]
# add a new policy rule/domain to the sepolicy
seadd() {
	$found_sepolicy || return
	"$seinject" -P "$sepolicy" "$@"
}

## end methods

