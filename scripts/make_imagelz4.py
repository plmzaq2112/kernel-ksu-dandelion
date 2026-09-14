#!/usr/bin/env python3
import sys, struct, lz4.block

src_path = "/home/a12bbb/android-kernel/out_blossom/arch/arm64/boot/Image"
dst_path = "/home/a12bbb/android-kernel/out_blossom/arch/arm64/boot/Image.lz4"
src = open(src_path, "rb").read()
block = lz4.block.compress(src, store_size=False)
magic = b"\x02\x21\x4c\x18"          # LZ4 legacy magic 0x184C2102
endmark = b"\x00\x00\x00\x00"        # 0x00000000 end mark
size = struct.pack("<Q", len(src))   # 原大小 8字节LE (同 cmd_lz4 的 size_append)
stream = magic + block + endmark + size
open(dst_path, "wb").write(stream)
print("Image", len(src), "->", dst_path, len(stream), "ratio %.2f" % (len(stream)/len(src)))
print("magic:", stream[:4].hex())