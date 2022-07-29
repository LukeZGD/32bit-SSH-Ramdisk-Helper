# SSH Ramdisk maker and loader for 32-bit devices

## There's no warranty provided!

- Fork for 32-bit device support only
- Modified to work on macOS, Linux, and Windows MSYS2

## How to use:
Making the ramdisk:
```
./Ramdisk_Maker.sh -d <device> -i <version>
```
Put the device in pwned dfu (or kdfu) and:
```
./Ramdisk_Loader.sh -d <device>
```
### It should work with all 32-bit limera1n/checkm8 devices

# Credits/Thanks to
- @Ralph0045 for SSH ramdisk maker and loader
- @iH8sn0w for iBoot32Patcher </br>
- msftguy for ssh-rd </br>
- @daytonhasty for Odysseus and kairos </br>
- @mcg29_ for compare script </br>
- @Jakeashacks for rootlessjb </br>
- @tihmstar for partialzipbrowser </br>
- @xerub for img4lib </br>
- @tihmstar for libfragmentzip, partialZipBrowser and tsschecker
