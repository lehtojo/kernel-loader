# Kernel

## Getting started
1. Install the following dependencies:
```bash
sudo apt install nasm qemu-system-x86 xorriso grub-common grub-pc mtools clang lld make
```
2. Install or build the [compiler](https://github.com/lehtojo/vivid-2) for the kernel project. Remember to add the compiler (`v1`) to the path.
3. (Optional) Build the actual [kernel](https://github.com/lehtojo/kernel/) and copy the generated `kernel.so` into this project's root folder as `KERNEL.SO`
4. Build the system image and start the virtual machine by executing `./all.sh`

## OVMF
[OVMF](https://github.com/tianocore/tianocore.github.io/wiki/How-to-run-OVMF) is already saved to this repository, but newer versions can be downloaded as follows. [Tianocore](https://github.com/tianocore/tianocore.github.io) offers [prebuilt images](https://www.kraxel.org/repos/):

1. Download `jenkins/edk2/edk2.git-ovmf-x64-...`
2. Unarchive the downloaded file
3. Place `usr/share/edk2.git/ovmf-x64/` folder into your home folder
