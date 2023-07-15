---
layout: post
title: Running Hifiberry OS with an IQaudIO DAC+
---

[HifiberryOS](https://www.hifiberry.com/hifiberryos/) is a small, functional OS that supports multiple audio sources (Bluetooth, Spotify, Airplay, etc) and has a great looking web interface to control it. However, the only officially supported hardware is Hifiberry's own DACs (which is reasonable).

However, when I was looking for a DAC for my Raspberry Pi earlier this year, Hifiberry's products were either obscenely overpriced here in Australia, or simply out of stock. I decided to settle on the next available option, an IQaudIO DAC+.

Unfortunately, I was disappointed when I flashed HifiberryOS to my Pi's SD card and it immediately got stuck in a boot loop. In summary, HifiberryOS's scripts (and OS build) are quite locked to Hifiberry devices, so this post outlines what you need to do in order to get a third-party DAC running.

1. Write HifiberryOS to the SD card. Don't take the SD card out yet!
2. `cd` to the `boot` partition of the SD card (the one with the FAT filesystem, and `config.txt` inside it), and run the following script:

    ```bash
    #!/bin/bash

    # By default, HifiberryOS has their own dtoverlay specified in config.txt. Remove it and add the iqaudio-dacplus one instead.
    echo "Updating dtoverlays in bootloader config"
    sed -i .bak '/hifiberry/d' config.txt
    sed -i .bak '/i2c-gpio/d' config.txt
    echo "dtoverlay=iqaudio-dacplus" >> config.txt

    # We also need the binary dtoverlay in some cases, so add it just in case (although I think it should be available on the DACs EEPROM in most cases).
    echo "Downloading dtoverlay blob"
    curl -O "https://github.com/raspberrypi/firmware/raw/master/boot/overlays/iqaudio-dacplus.dtbo" > overlays/iqaudio-dacplus.dtbo

    touch noreboot
    touch ssh

    echo "Done!"
    ```
3. This should let you boot and go through the setup flow. After you have finished setting up HifiberryOS, ssh into it and run the following script.
   Note that you'll need to update the `raspberrypi/firmware` commit hash in the script to be the correct commit for the Linux kernel version that you're running (you can check your kernel version with `uname -r`). You can do this by going to the [raspberrypi/firmware Github commits page](https://github.com/raspberrypi/firmware/commits/master), looking for a commit labelled "kernel: bump to X.YY.ZZ" (where X.YY.ZZ is your kernel version), and copying that commit hash.

    ```bash
    #!/bin/bash

    # hifiberry-detect is a service that searches for a Hifiberry HAT and writes the appropriate dtoverlay into /boot/config.txt. Disable this since we don't have a Hifiberry.
    echo "Removing hifiberry-detect service"
    systemctl stop hifiberry-detect
    systemctl disable hifiberry-detect
    rm /usr/lib/systemd/system/hifiberry-detect.service

    # Run this again, because hifiberry-detect will have written it after we booted.
    echo "Dropping hifiberry dtoverlays"
    mount -o remount,rw /boot
    sed -i '/hifiberry/d' /boot/config.txt

    # Download and depmod the kernel modules
    # This commit corresponds to version 5.15.78; you'll need to find the correct commit as explained above.
    echo "Downloading kernel modules"
    VERSION="5.15.78-v7l"
    curl -L "https://github.com/raspberrypi/firmware/raw/6cbf00359959cf7381f4e3773037c7d5573d94b2/modules/$VERSION%2B/kernel/sound/soc/bcm/snd-soc-iqaudio-dac.ko.xz" > "/lib/modules/$VERSION/kernel/sound/soc/bcm/snd-soc-iqaudio-dac.ko.xz"
    unxz "/lib/modules/$VERSION/kernel/sound/soc/bcm/snd-soc-iqaudio-dac.ko.xz"
    echo "Installing kernel modules"
    depmod
    modprobe snd-soc-iqaudio-dac

    # There are a bunch of calls to `aplay -L` etc that try to find a Hifiberry device. We replace those greps with "IQaudIO" instead, so that it matches our DAC. Replace this with your own necessary string, if you have some other third-party DAC.
    echo "Updating references to hifiberry devices in hifiberry packages"
    sed -i 's/grep hifiberry/grep IQaudIO/g' /opt/hifiberry/bin/reconfigure-players

    # pause-all is triggered whenever changing tracks; it needs a lookup for the sound card to detect active players, so we need to update it here too
    sed -i 's/grep -i hifiberry/grep -i IQaudIO/g' /opt/hifiberry/bin/pause-all

    # `check_dsp` function was broken on my install for some reason (I'm not sure why, when it should theoretically just return "false" for "no DSP HAT detected"), so I disabled it.
    sed -i 's/check_dsp() {/check_dsp() {\
    return/g' /opt/hifiberry/bin/reconfigure-players
    # dsptoolkit was also failing, so disable it too.
    mv /bin/dsptoolkit /bin/dsptoolkit2
    touch /bin/dsptoolkit
    chmod +x /bin/dsptoolkit

    # Write the new settings, and then reboot.
    echo "Reconfiguring players"
    /opt/hifiberry/bin/reconfigure-players

    echo "Done! Rebooting in 10 seconds..."
    sleep 10
    reboot
    ```
4. Congratulations! Hopefully, you have HifiberryOS working with an IQaudIO DAC 🙂
