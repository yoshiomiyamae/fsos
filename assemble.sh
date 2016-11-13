as -o boot.o boot.s
ld -o boot.out boot.o -Ttext 0x7c00
objcopy -O binary -j .text boot.out boot.bin
dd if=/dev/zero of=boot.img bs=1024 count=1440
mkdosfs boot.img
dd if=boot.bin of=boot.img conv=notrunc

as -o kernel.o kernel.s
ld -o kernel.out kernel.o
objcopy -O binary -j .text kernel.out kernel.bin
dd if=kernel.bin of=KERNEL.IMG

sudo mount boot.img /mnt/vfd
sudo cp README.md /mnt/vfd
sudo cp KERNEL.IMG /mnt/vfd
sudo umount /mnt/vfd
