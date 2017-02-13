#!/system/bin/sh

#######################################################################
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#######################################################################

PATH=/sbin:/system/sbin:/system/bin:/system/xbin
export PATH

BBX=/system/xbin/busybox

# Inicio
mount -o remount,rw -t auto /
mount -o remount,rw -t auto /system
mount -t rootfs -o remount,rw rootfs

if [ -f $BBX ]; then
	chown 0:2000 $BBX
	chmod 0755 $BBX
	$BBX --install -s /system/xbin
	ln -s $BBX /sbin/busybox
	ln -s $BBX /system/bin/busybox
	sync
fi

################################################################################
# helper functions to allow Android init like script

function write() {
    echo -n $2 > $1
}

function copy() {
    cat $1 > $2
}

################################################################################




# Enable bus-dcvs
for cpubw in /sys/class/devfreq/*qcom,cpubw* ; do
    write $cpubw/governor "bw_hwmon"
    write $cpubw/polling_interval 50
    write $cpubw/min_freq 1525
    write $cpubw/bw_hwmon/mbps_zones "1525 5195 11863 13763"
    write $cpubw/bw_hwmon/sample_ms 4
    write $cpubw/bw_hwmon/io_percent 34
    write $cpubw/bw_hwmon/hist_memory 20
    write $cpubw/bw_hwmon/hyst_length 10
    write $cpubw/bw_hwmon/low_power_ceil_mbps 0
    write $cpubw/bw_hwmon/low_power_io_percent 34
    write $cpubw/bw_hwmon/low_power_delay 20
    write $cpubw/bw_hwmon/guard_band_mbps 0
    write $cpubw/bw_hwmon/up_scale 250
    write $cpubw/bw_hwmon/idle_mbps 1600
done

for memlat in /sys/class/devfreq/*qcom,memlat-cpu* ; do
    write $memlat/governor "mem_latency"
    write $memlat/polling_interval 10
done

# Enable all LPMs by default
# This will enable C4, D4, D3, E4 and M3 LPMs
write /sys/module/lpm_levels/parameters/sleep_disabled N


echo "[Nebula] Remounted sysfs+sdcard With noatime, nodiratime" | tee /dev/kmsg

# lmk whitelist for common launchers and increase launcher priority
list="com.android.launcher com.google.android.googlequicksearchbox org.adw.launcher org.adwfreak.launcher net.alamoapps.launcher com.anddoes.launcher com.android.lmt com.chrislacy.actionlauncher.pro com.cyanogenmod.trebuchet com.gau.go.launcherex com.gtp.nextlauncher com.miui.mihome2 com.mobint.hololauncher com.mobint.hololauncher.hd com.qihoo360.launcher com.teslacoilsw.launcher com.tsf.shell org.zeam";
while sleep 60; do
  for class in $list; do
    if [ `pgrep $class | head -n 1` ]; then
      launcher=`pgrep $class`;
      echo -17 > /proc/$launcher/oom_adj;
      chmod 100 /proc/$launcher/oom_adj;
      renice -18 $launcher;
    fi;
  done;
  exit;
done&

# wait for systemui and increase its priority
while sleep 3; do
  if [ `$bb pidof com.android.systemui` ]; then
    systemui=`pidof com.android.systemui`;
    renice -18 $systemui;
    echo -17 > /proc/$systemui/oom_adj;
    chmod 100 /proc/$systemui/oom_adj;
    exit;
  fi;
done&

#
# Stop Google Service and restart it on boot
# This removes high CPU load and ram leak!
#


Google_Services_BatteryFix() {
					echo "[Nebula] Killing Google Services" | tee /dev/kmsg
					if [ "$($BBX pidof com.google.android.gms | wc -l)" -eq "1" ]; then
					$BBX kill "$($BBX pidof com.google.android.gms)";
					fi;
					if [ "$($BBX pidof com.google.android.gms.unstable | wc -l)" -eq "1" ]; then
					$BBX kill "$($BBX pidof com.google.android.gms.unstable)";
					fi;
					if [ "$($BBX pidof com.google.android.gms.persistent | wc -l)" -eq "1" ]; then
					$BBX kill "$($BBX pidof com.google.android.gms.persistent)";
					fi;
					if [ "$($BBX pidof com.google.android.gms.wearable | wc -l)" -eq "1" ]; then
					$BBX kill "$($BBX pidof com.google.android.gms.wearable)";
					fi;
					echo "[Nebula] Google Services have been temp killed" | tee /dev/kmsg
					# Google Services battery drain fixer by Alcolawl@xda
					# http://forum.xda-developers.com/google-nexus-5/general/script-google-play-services-battery-t3059585/post59563859
					echo "[Nebula] Google Services Part 2 Fix Start" | tee /dev/kmsg
					pm enable com.google.android.gms/.update.SystemUpdateActivity
					pm enable com.google.android.gms/.update.SystemUpdateService
					pm enable com.google.android.gms/.update.SystemUpdateService$ActiveReceiver
					pm enable com.google.android.gms/.update.SystemUpdateService$Receiver
					pm enable com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver
					pm enable com.google.android.gsf/.update.SystemUpdateActivity
					pm enable com.google.android.gsf/.update.SystemUpdatePanoActivity
					pm enable com.google.android.gsf/.update.SystemUpdateService
					pm enable com.google.android.gsf/.update.SystemUpdateService$Receiver
					pm enable com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver
					echo "[Nebula] Google Services Part 2 Fix End" | tee /dev/kmsg
		}
		
Google_Services_BatteryFix;

# Power Effecient Workqueues (Enable for battery)

write /sys/module/workqueue/parameters/power_efficient 1 
write /sys/module/subsystem_restart/parameters/enable_ramdumps 0
