#!/usr/bin/env python3
import struct
src = open('/home/a12bbb/android-kernel/stock_boot.img', 'rb').read()
out = open('/home/a12bbb/android-kernel/boot-4.19.275-stock.img', 'rb').read()
kgz = open('/home/a12bbb/android-kernel/out/arch/arm64/boot/Image.gz', 'rb').read()
page = struct.unpack_from('<I', src, 36)[0]
def al(x): return ((x + page - 1) // page) * page
ks = struct.unpack_from('<I', out, 8)[0]
rs = struct.unpack_from('<I', src, 16)[0]
dt = struct.unpack_from('<I', src, 1648)[0]

print('out kernel_size field:', ks, '== len(Image.gz)?', ks == len(kgz))
koff = page
print('kernel section == Image.gz:', out[koff:koff+ks] == kgz)

roff = koff + al(ks)
print('ramdisk section == src:', out[roff:roff+rs] == src[page+al(struct.unpack_from('<I',src,8)[0]):][:rs])
doff = roff + al(rs)
s_doff = page + al(struct.unpack_from('<I', src, 8)[0]) + al(rs)
print('dtb section == src:', out[doff:doff+dt] == src[s_doff:s_doff+dt])

cmd = out[64:64+512].split(b'\x00',1)[0].decode(errors='replace')
print('cmdline:', cmd)
print('magic:', out[0:9])
print('out size:', len(out), 'src size:', len(src))