#!/bin/bash
dd if=/dev/zero of=system.img bs=1M count=64
mformat -i system.img -F ::
mmd -i system.img ::/EFI
mmd -i system.img ::/EFI/BOOT
mcopy -i system.img BOOTX64.EFI ::/EFI/BOOT
mcopy -i system.img KERNEL.SO ::/EFI/BOOT
mcopy -i system.img FONT.BMP ::/EFI/BOOT
mcopy -i system.img FONT.FNT ::/EFI/BOOT
