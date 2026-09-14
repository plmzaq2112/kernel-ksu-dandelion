#!/usr/bin/env python3
import struct
d = open('/home/a12bbb/android-kernel/stock_boot.img', 'rb').read()
print('size', len(d))
print('magic', d[0:8])
print('kernel_size', struct.unpack_from('<I', d, 8)[0])
print('ramdisk_size', struct.unpack_from('<I', d, 16)[0])
print('second_size', struct.unpack_from('<I', d, 24)[0])
print('page_size', struct.unpack_from('<I', d, 36)[0])
print('hdr_ver', struct.unpack_from('<I', d, 40)[0])
if len(d) > 1660:
    print('dtb_size', struct.unpack_from('<I', d, 1648)[0])
    print('dtb_addr', hex(struct.unpack_from('<Q', d, 1652)[0]))
def align(x, p): return ((x + p - 1) // p) * p
page = struct.unpack_from('<I', d, 36)[0]
ks = struct.unpack_from('<I', d, 8)[0]
rs = struct.unpack_from('<I', d, 16)[0]
off = page + align(ks, page)
print('ramdisk_abs', hex(off), 'ramdisk_first', d[off:off+8])
off = off + align(rs, page)
print('dtb_abs', hex(off), 'dtb_first', d[off:off+8])
off = off + align(struct.unpack_from('<I', d, 24)[0], page)
print('after_dtb', hex(off))
cmd_off, cmd_len = 64, 512
cmd = d[cmd_off:cmd_off + cmd_len].split(b'\x00', 1)[0].decode(errors='replace')
print('cmdline:', cmd)