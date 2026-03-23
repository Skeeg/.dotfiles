vbox_stop() {
  local vm="${1:?Usage: vbox_stop <vmname>}"
  touch "/opt/vms/${vm}/.intentional-shutdown"
  vboxmanage controlvm "$vm" acpipowerbutton
}

vbox_start() {
  local vm="${1:?Usage: vbox_start <vmname>}"
  rm -f "/opt/vms/${vm}/.intentional-shutdown"
  sudo systemctl start "vbox-watchdog@${vm}.service"
}
