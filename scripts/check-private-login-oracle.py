"""Read-only original CDUtil public identity comparison. Private stdin only.

No network, original-process access, files containing credentials, or key output.
The only executed original function is UnScrambleKey on the pinned binary.
"""
import sys, json, hashlib, struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'backups/research-python'))
import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RIP

def check():
    private = bytearray(sys.stdin.buffer.read(16385))
    try:
        if len(private) > 16384:
            raise ValueError()
        request = json.loads(private)
        key = request.pop('key').encode('ascii')
        expected = request.pop('expectedPublicSha256')
        if request or len(key) != 41 or len(expected) != 64:
            raise ValueError()
        image = (root.parent / 'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
        digest = hashlib.sha256(image).hexdigest()
        if digest != '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a':
            raise ValueError()
        pe = pefile.PE(data=image)
        cpu = Uc(UC_ARCH_X86, UC_MODE_64)
        base = pe.OPTIONAL_HEADER.ImageBase
        cpu.mem_map(base, (pe.OPTIONAL_HEADER.SizeOfImage + 4095) & ~4095)
        cpu.mem_write(base, pe.get_memory_mapped_image())
        heap, stack, stop = 0x200000000, 0x300000000, 0x400000000
        cpu.mem_map(heap, 4096); cpu.mem_map(stack, 4096); cpu.mem_map(stop, 4096)
        cpu.mem_write(heap, key + b'\0'); key = b''
        rsp = stack + 2048
        cpu.mem_write(rsp, struct.pack('<Q', stop))
        for reg, value in [(UC_X86_REG_RCX, heap), (UC_X86_REG_RDX, heap + 256), (UC_X86_REG_R8, heap + 512), (UC_X86_REG_R9, heap + 768), (UC_X86_REG_RSP, rsp)]:
            cpu.reg_write(reg, value)
        cpu.emu_start(0x14010fab0, stop, count=20000)
        if cpu.reg_read(UC_X86_REG_RIP) != stop:
            raise ValueError()
        public = bytes(cpu.mem_read(heap + 256, 9)).split(b'\0')[0]
        result = dict(originalPublicIdentityMatches=hashlib.sha256(public).hexdigest() == expected, binarySha256=digest)
        cpu.mem_write(heap, bytes(4096))
        return result
    finally:
        private[:] = bytes(len(private))

try:
    print(json.dumps(check()))
except Exception:
    print(json.dumps(dict(failure='Private native identity comparison failed')))
    sys.exit(1)
