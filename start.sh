#!/bin/bash
qemu-system-x86_64 $@ -cpu EPYC -bios ~/ovmf-x64/OVMF-pure-efi.fd -machine q35 -serial stdio --no-reboot -smp 2 -m 2048 -usb system.img -drive file=filesystem.ext2,if=none,id=nvm -device nvme,serial=deadbeef,drive=nvm -soundhw pcspk
