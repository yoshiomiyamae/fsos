.code16                             # 16bitモードでアセンブルする
.intel_syntax noprefix              # intel方式のアセンブリ
.text
.org        0x0000                  # 0x0000から配置する

.extern WriteString

jmp   abcd

loaderStart:
  lea si, [text123]
  call WriteString

abcd:
  xor bx, bx

text123:  .asciz "test 123456"
