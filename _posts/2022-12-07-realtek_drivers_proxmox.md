---
layout: post
title: Installing Realtek RTL8125B drivers on Proxmox
---

I run my router as an opnsense VM inside Proxmox, and recently upgraded to a new RTL8125B 4x 2.5GbE card. Opnsense was happy with it, but I had quite a bit of jitter and dropped packets.
Because Opnsense gets a virtualised bridge, I needed to update the Realtek drivers in the Proxmox host instead.

Note: my connection to the Proxmox host is over a different connection, and not to the Realtek card in question. I essentially have a secondary management port (Intel-based), so in my case, none of the following instructions drop my SSH connection, I am safe to reboot and re-SSH, etc. If that doesn't apply to you, you should follow these instructions instead: https://github.com/dgparker/RTL8125-proxmox-ve-install-script


## Instructions

```
# Install build dependencies + appropriate linux-headers package
apt install -y dkms build-essential pve-headers-$(uname -r)

# Download the latest r8125 dkms package
curl -s https://api.github.com/repos/awesometic/realtek-r8125-dkms/releases/latest |
  grep "browser_download_url.*amd64.deb" |
  cut -d : -f 2,3 |
  tr -d \" |
  wget -i -

# Install it
dpkg -i realtek-r8125-dkms*.deb

# Blacklist the old driver
echo "blacklist r8169" > /etc/modprobe.d/blacklist-r8169.conf

# Update initramfs
update-initramfs -u

echo "Finished, please reboot now!"
```
