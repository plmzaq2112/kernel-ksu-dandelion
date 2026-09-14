import struct, sys

src = sys.argv[1]; out = sys.argv[2]
data = bytearray(open(src, "rb").read())
page = struct.unpack_from("<I", data, 36)[0]
hdr = bytearray(data[:page])

# locate actual cmdline region (MTK puts it at ~87-88)
base = hdr.find(b'androidboot.')
if base < 0:
    raise SystemExit("cmdline not found")
base = max(base - 1, 0)
old = hdr[base:base+512].split(b'\0')[0]
new = old + b' androidboot.selinux=permissive androidboot.debuggable=1'
if len(new) > 512:
    raise SystemExit("cmdline overflow")
hdr[base:base+512] = new + b'\0' * (512 - len(new))
data[:page] = hdr
open(out, "wb").write(bytes(data))
print(f"OK  offset={base} cmdline={new.decode()}  -> {out}")