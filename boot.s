.code16                             # 16bitモードでアセンブルする
.intel_syntax noprefix              # intel方式のアセンブリ
.org 0x0                            # 0x0から配置する

.global main
main:
  # BS_JmpBoot
  jmp short start                   # EB start:
  nop                               # 90

bootsector:
  # ブートセクタ PBP
  BS_OEMName:      .ascii   "FSOS 1.0"
  BS_BytsPerSec:   .word    0x200
  BPB_SecPerClus:  .byte    1
  BPB_RsvdSecCnt:  .word    1
  BPB_NumFATs:     .byte    1
  BPB_RootEntCnt:  .word    224
  BPB_TotSec16:    .word    2880
  BPB_Media:       .word    9
  BPB_FATSz16:     .word    9
  BPB_SecPerTrk:   .word    9
  BPB_NumHeads:    .word    2
  BPB_HiddSec:     .int     0
  BPB_TotSec32:    .int     0

  BS_DrvNum:       .byte    0
  BS_Reserved1:    .byte    0
  BS_BootSig:      .byte    0x29
  BS_VolID:        .int     0x20161031
  BS_VolLab:       .ascii   "FSOS BOOT  "
  BS_FilSysType:   .ascii   "FAT12   "

.func WriteString                   # 文字列の表示
  WriteString:
    lodsb                           # ds:[si]から1文字読みだす
    or      al, al
    jz      WriteString_done        # alが0(null文字)ならWriteString_doneへジャンプ

    mov     ah, 0x0E                # ファンクションコード
    mov     bh, 0x00                # ページナンバー
    mov     bl, 0x0A                # 黒地に薄緑を指定
    int     0x10                    # ビデオサービス呼び出し

    jmp     WriteString             # WriteStringに戻る

  WriteString_done:
    retw                            # 呼び出し元へ戻る
.endfunc

.func Reboot
  Reboot:
    lea     si, reboot_message      # reboot_messageのアドレスをsiに読み込む
    call    WriteString             # 文字列の表示関数呼び出し
    # mov ah, 0x00 == xor ah, ah
    xor     ah, ah                  # ファンクションコード
    int     0x16                    # キーボードサービス呼び出し
    jmp     0xFFFF:0000             # 再起動
.endfunc

start:
  # 初期化処理
  cli                               # 割込みの無効化
  mov       BS_DrvNum, dl           # 起動トライブ番号の退避 (BIOSがdlに入れてくれる)
  xor       ax, ax                  # ax=0
  mov       ds, ax                  # ds=0
  mov       es, ax                  # es=0
  mov       ss, ax                  # ss=0
  mov       sp, 0x7C00              # spの初期化 (スタックは0x7C00->0x0000の方向に積まれる)
  sti                               # 割込みの有効化

  # OSのブート
  lea       si, loading_message     # loading_messageのアドレスをsiに読み込む
  call      WriteString             # 文字列の表示関数呼び出し

  mov       dl, BS_DrvNum           # BS_DrvNumに退避した値をdlに戻す
  xor       ah, ah                  # ah = 0x00
  int       0x13                    # ディスクサービスの呼び出し
  jc        bootFailure             # cfがセットされている場合はエラー発生

  call      Reboot                  # 再起動

bootFailure:
  # ブート失敗
  lea       si, disk_error_message  # disk_error_messageのアドレスをsiに読み込む
  call      WriteString             # 文字列の表示関数呼び出し
  call      Reboot                  # 再起動

# ------------------------------------------------------------------------------
# Data Section
# ------------------------------------------------------------------------------
loading_message:    .asciz "Loading Famoce Succellion Operating System...\r\n"
disk_error_message: .asciz "Disk error."
reboot_message:     .asciz "Press any key to reboot.\r\n"
# ------------------------------------------------------------------------------

.fill (510-(.-main)), 1, 0        # 残りを510byte目まで0で埋める
BootMagic:  .word   0xAA55        # ブートシグネチャ
