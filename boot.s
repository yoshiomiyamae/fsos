.code16                             # 16bitモードでアセンブルする
.intel_syntax noprefix              # intel方式のアセンブリ
.text
.org        0x0000                  # 0x0000から配置する

.global     WriteString

# ------------------------------------------------------------------------------
# Constants Setion
# ------------------------------------------------------------------------------
INT_PRINT_SCREEN                    = 0x05
INT_VIDEO_DISPLAY_SERVICES          = 0x10
INT_EQUIPMENT_DETERMINATION         = 0x11
INT_MEMORY_SIZE_DETERMINATION       = 0x12
INT_DISKETTE_AND_HARD_DISK_SERVICES = 0x13
INT_SERIAL_IO_SERVICES              = 0x14
INT_MISCELLANEOUS_SERVICES          = 0x15
INT_KEYBOARD_SERVICES               = 0x16
INT_PRINTER_SERVICES                = 0x17
INT_ROM_BASIC                       = 0x18
INT_BOOTSTRAP                       = 0x19
INT_TIME_AND_DATE_SERVICE           = 0x1A
INT_CTRL_BREAK_HANDLER              = 0x1B
INT_CLOCK_TICK_HANDLER              = 0x1C
INT_VIDEO_PARAMETER_TABLE           = 0x1D
INT_FLOPPY_DISK_PARAMETER_TABLE     = 0x1E
INT_VIDEO_GRAPHICS_CHARACTER_TABLE  = 0x1F
INT_REALTIME_CLOCK_INTERRUPT        = 0x4A
INT_VIDEO_VIOS_EXTENSION            = 0x4F
# ------------------------------------------------------------------------------

.global main
main:
  # BS_JmpBoot
  jmp start                   # 0xEB start:
  nop                         # 0x90

bootsector:
  # ブートセクタ PBP
  BS_OEMName:      .ascii   "FSOS 1.0"
  BS_BytsPerSec:   .word    0x0200
  BPB_SecPerClus:  .byte    0x01
  BPB_RsvdSecCnt:  .word    0x0001
  BPB_NumFATs:     .byte    0x02
  BPB_RootEntCnt:  .word    0x00E0
  BPB_TotSec16:    .word    0x0B40
  BPB_Media:       .byte    0xF0
  BPB_FATSz16:     .word    0x0009
  BPB_SecPerTrk:   .word    0x0012
  BPB_NumHeads:    .word    0x0002
  BPB_HiddSec:     .int     0x00000000
  BPB_TotSec32:    .int     0x00000000

  BS_DrvNum:       .byte    0x00
  BS_Reserved1:    .byte    0x00
  BS_BootSig:      .byte    0x29
  BS_VolID:        .int     0x20161031
  BS_VolLab:       .ascii   "FSOS BOOT  "
  BS_FilSysType:   .ascii   "FAT12   "

start:
  # 初期化処理
  cli                               # 割込みの無効化
  xor       ax, ax                  # ax=0
  mov       ds, ax                  # ds=0
  mov       es, ax                  # es=0
  mov       ss, ax                  # ss=0
  mov       bx, ax                  # ss=0
  mov       cx, ax                  # ss=0
  mov       dx, ax                  # ss=0
  mov       sp, 0x7C00              # spの初期化 (スタックは0x7C00->0x0000の方向に積まれる)
  sti                               # 割込みの有効化

  # OSのブート
  lea       si, [loading_message]    # loading_messageのアドレスをsiに読み込む
  #mov       bl, 0x0F                # 黒地に白を指定
  call      WriteString             # 文字列の表示関数呼び出し

  # ディスクドライブのリセット
  mov       dl, [BS_DrvNum]         # BS_DrvNumに退避した値をdlに戻す
  xor       ah, ah                  # ah = 0x00
  # ディスクサービスの呼び出し
  int       INT_DISKETTE_AND_HARD_DISK_SERVICES
  jc        bootFailure             # cfがセットされている場合はエラー発生

  # FAT領域をロードする
  xor       ax, ax                  # ax = 0
  mov       al, [BPB_NumFATs]       # al = [BPB_NumFATs]
  mov       dx, [BPB_FATSz16]       # dx = [BPB_FATSz16]
  mul       dx                      # dx:ax = ax * dx
  mov       cx, ax                  # cx = ax
  xor       dx, dx                  # dx = 0
  mov       ax, [BPB_RsvdSecCnt]    # ax = [BPB_RsvdSecCnt]
  mov       bx, [fat_address]       # bx = [fat_address]
  call      LoadSectors
  jc        bootFailure

  # ルートディレクトリ領域をロードする
  mov       ax, [BPB_RootEntCnt]    # ax = [BPB_RootEntCnt]
  shl       ax, 5                   # ax <<= 5    // ax *= 0x20
  div       ax, [BS_BytsPerSec]     # ax = ax / [BS_BytsPerSec], dx = ax % [BS_BytsPerSec]
  mov       cx, ax                  # cx = dx
  xor       dx, dx                  # dx = 0
  xor       ax, ax                  # ax = 0
  mov       al, [BPB_NumFATs]       # al = [BPB_NumFATs]
  mov       dx, [BPB_FATSz16]       # dx = [BPB_FATSz16]
  mul       dx                      # dx:ax = ax * dx
  add       ax, [BPB_RsvdSecCnt]    # ax += [BPB_RsvdSecCnt]
  mov       bx, [rdt_address]       # bx = [rdt_address]
  call      LoadSectors
  jc        bootFailure

  # LOADER.IMGを探す
  lea       si, [loader_file_name]
  call      ExploreFile
  jc        bootFailure

  mov       ax, [bx+0x001A]         # ファイルの開始クラスタ番号の取得
  mov       bx, [loader_segment]
  mov       es, bx
  xor       bx, bx
  push      bx
nextcluster:
  pop       bx
  push      ax
  mov       cx, 0x0001
  call      LoadSectors
  add       bx, [BS_BytsPerSec]
  pop       ax
  push      bx
  mov       cx, ax
  mov       dx, ax
  shr       dx, 1                   # dx >>= 1    // dx /= 2
  add       cx, dx
  mov       bx, [fat_address]
  add       bx, cx
  mov       dx, [bx]
  test      ax, 1
  jz        evencluster
  shr       dx, 4                   # dx >>= 4    // 0xFF00 -> 0x00FF
evencluster:
  add       dx, 0x0FFF              # dx &= 0x0FFF
  jmp       clusterNumberChecked
clusterNumberChecked:
  mov       ax, dx
  cmp       dx, 0xFFF0
  jb        nextcluster             # dx < 0xFFF0

  pop       bx
  mov       bx, [loader_segment]
  mov       ds, bx
  mov       si, 0x000D
  call      WriteString
  #jmp       es:0x0000

  # TODO: KERNEL.IMGを読み込んで処理を移す
  #       KERNEL.IMGで32bitモードに移行する

  call      Reboot                  # 再起動

bootFailure:
  # ブート失敗
  lea       si, [disk_error_message]  # disk_error_messageのアドレスをsiに読み込む
  call      WriteString             # 文字列の表示関数呼び出し
  call      Reboot                  # 再起動

# ------------------------------------------------------------------------------
# Function Section
# ------------------------------------------------------------------------------
.func WriteString
  # ----------------------------------------------------------------------------
  # 文字列の表示関数
  # パラメータ:
  #   si: 文字列へのポインタ
  # ----------------------------------------------------------------------------
  WriteString:
    push    ax
    push    bx

    NextCaracter:
    lodsb                           # ds:[si]から1文字読みだす
    or      al, al
    jz      WriteString_done        # alが0(null文字)ならWriteString_doneへジャンプ

    mov     ah, 0x0E                # ファンクションコード
    xor     bh, bh                  # ページナンバー
    # ビデオサービス呼び出し
    int     INT_VIDEO_DISPLAY_SERVICES

    jmp     NextCaracter             # WriteStringに戻る

  WriteString_done:
    pop     bx
    pop     ax

    ret                             # 呼び出し元へ戻る
.endfunc

.func Reboot
  # ----------------------------------------------------------------------------
  # 再起動関数
  # ----------------------------------------------------------------------------
  Reboot:
    lea     si, [reboot_message]    # reboot_messageのアドレスをsiに読み込む
    call    WriteString             # 文字列の表示関数呼び出し
    xor     ah, ah                  # ah = 0x00
    int     INT_KEYBOARD_SERVICES   # キーボードサービス呼び出し
    int     INT_BOOTSTRAP           # ブートストラップ処理呼び出し
.endfunc

.func Lba2Chs
  # ----------------------------------------------------------------------------
  # LBA (Logical Block Addressing)をCHS(Cylinder Head Sector)に変換する関数
  # パラメータ:
  #   ax: LBA
  # 返り値:
  #   ch: シリンダ番号  LBA / (BPB_SecPerTrk * BPB_NumHeads) = LBA / BPB_SecPerTrk / BPB_NumHeads
  #   dh: ヘッド番号   (LBA / BPB_SecPerTrk) % BPB_NumHeads
  #   cl: セクタ番号   (LBA % BPB_SecPerTrk) + 1
  # ----------------------------------------------------------------------------
  Lba2Chs:
    push      ax                      # axを退避

    xor       cx, cx                  # cx = 0
    xor       dx, dx                  # dx = 0

    div       ax, [BPB_SecPerTrk]     # ax /= [BPB_SecPerTrk], dx = ax % [BPB_SecPerTrk]
    mov       cl, dl                  # cl = dl
    inc       cl                      # cl += 1 (セクタ番号)
    div       ax, [BPB_NumHeads]      # ax /= [BPB_NumHeads], dh = al % [BPB_NumHeads]
    mov       ch, al                  # ch = al (シリンダ番号)
    mov       dh, dl                  # dh = ah (ヘッド番号)
    xor       dl, dl                  # dl = 0

    pop       ax                      # axを戻す
    ret                               # 呼び出し元へ戻る
.endfunc

.func LoadSectors
  # ----------------------------------------------------------------------------
  # 指定したセクタをメモリに読み込む関数
  # パラメータ:
  #   ax: 開始セクタ (LBA)
  #   es:bx: 書き込み先
  #   cx: 読取セクタ数
  # 返り値:
  #   cf: エラー時にセット、エラー無しでクリア
  #   ah: 結果コード
  #   al: 実際に読み込んだセクタ数
  # ----------------------------------------------------------------------------
  LoadSectors:
    push      ax                      # axを退避
    push      bx                      # bxを退避
    push      cx                      # cxを退避
    push      dx                      # dxを退避

    # カウンタの設定
    mov       dx, 0x0005              # dx = 0x0005

    push      ax                      # axを退避

  LoadSectors2:
    dec       dx                      # dx--
    jz        LoadError               # 失敗が続いたらエラー
    cmp       cx, 0x00FF              # cxと0x00FFを比較
    jl        FewSectors              # cx < 0x00FFならFewSectorsへジャンプ
    mov       ax, 0x00FF              # cx >= 0x00FFなので最大限読み込む
    mov       [load_sector_count], ax # [load_sector_count]に格納
    jmp       FinishDetermineSectorCount # 条件分岐の終わりにジャンプ
  FewSectors:
    mov       [load_sector_count], cx # 残り全てを読み込む
  FinishDetermineSectorCount:
    pop       ax                      # axを戻す
    push      ax                      # axを退避
    push      cx                      # cxを退避
    push      dx                      # dxを退避
    call      Lba2Chs                 # axをCHSに変換。 ch: C, dh:H, cl: S
    mov       al, [load_sector_count] # [load_sector_count]分読み込み
    mov       dl, [BS_DrvNum]         # dl = [BS_DrvNum]
    mov       ah, 0x02                # ah = 0x02
    int       INT_DISKETTE_AND_HARD_DISK_SERVICES
    pop       dx                      # dxを戻す
    pop       cx                      # cxを戻す
    jc        LoadSectors2            # 失敗したら再読み込み
    and       ax, 0x00FF              # ah = 0
    mov       [load_sector_count], ax # 読み込んだセクタを[load_sector_count]に格納
    add       bx, [load_sector_count] # 読み込んだセクタ数進める
    pop       ax                      # axを戻す
    add       ax, [load_sector_count] # 読み込んだセクタ数進める
    push      ax                      # axを退避
    mov       dx, 0x0005              # エラーカウントを戻す
    sub       cx, [load_sector_count] # cx--
    jnz       LoadSectors2            # 残りセクタがあれば繰り返す

    pop       ax                      # axを戻す
    pop       dx                      # dxを戻す
    pop       cx                      # cxを戻す
    pop       bx                      # bxを戻す
    pop       ax                      # axを戻す
    clc                               # CFをクリア
    ret                               # 呼び出し元へ戻る

  LoadError:
    # ブート失敗
    pop       dx                      # dxを戻す
    pop       cx                      # cxを戻す
    pop       bx                      # bxを戻す
    pop       ax                      # axを戻す
    stc                               # CFをセット
    ret                               # 呼び出し元へ戻る
.endfunc

.func ExploreFile
  # ----------------------------------------------------------------------------
  # ファイル検索関数
  # パラメータ:
  #   si: 探すファイル名のポインタ
  # 返り値:
  #   cf: エラー時にセット、エラー無しでクリア
  #   bx: 見つかったファイルのポインタ
  # ----------------------------------------------------------------------------
  ExploreFile:
    mov       bx, [rdt_address]       # bx = [rdt_address]
    mov       cx, [BPB_RootEntCnt]    # cx = [BPB_RootEntCnt]

  ExploreStart:
    mov       di, bx                  # di = bx
    push      cx                      # cxを退避
    mov       cx, 0x000B              # cx = 0x000B
    push      di                      # diを退避
    push      si                      # siを退避
    repe      cmpsb                   # ds:[di]とes:[si]を比較
    pop       si                      # siを戻す
    pop       di                      # diを戻す
    jcxz      ExploreFinish           # ファイルが見つかったらExploreFinishへジャンプ
    add       bx, 0x0020              # 見つからないので次のファイルへ
    pop       cx                      # cxを戻す
    loop      ExploreStart            # cx--して0でなければExploreStartへ

    # ファイルが見つからない
    stc                               # CFをセット
    ret                               # 呼び出し元へ戻る

  ExploreFinish:
    pop       cx                      # cxを戻す
    clc                               # CFをクリア
    ret                               # 呼び出し元へ戻る
.endfunc

# ------------------------------------------------------------------------------
# Data Section
# ------------------------------------------------------------------------------
loading_message:      .asciz "Boot FSOS\n"
disk_error_message:   .asciz "Disk error\n"
reboot_message:       .asciz "Press any key to reboot\n"
load_sector_count:    .word 0x0000
#cluster_offset:       .word 0x0000
fat_address:          .word 0x1000
rdt_address:          .word 0x2000
loader_segment:       .word 0x0010
loader_file_name:     .ascii "LOADER  IMG"
# ------------------------------------------------------------------------------

.fill (510-(.-main)), 1, 0        # 残りを510byte目まで0で埋める
BootMagic:  .word   0xAA55        # ブートシグネチャ
