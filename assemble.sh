as -o boot.o boot.s
ld -o boot.out boot.o -Ttext 0x7c00
objcopy -O binary -j .text boot.out boot.bin
dd if=boot.bin of=boot.img
