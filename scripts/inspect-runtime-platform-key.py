"""Authorized read-only observation of our installed local NWN server.

Resolve the exported key getter from this exact server PE, then read its
RIP-relative storage in the running image. Never print key bytes or mutate it.
"""
import ctypes as c
from ctypes import wintypes as w
import hashlib, json, sys
from pathlib import Path
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

root = Path(__file__).resolve().parents[1]
image = (root / '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe').resolve()
digest = hashlib.sha256(image.read_bytes()).hexdigest()
assert digest == '98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'
pid = int(sys.argv[1])
pe = pefile.PE(str(image))
export = next(e for e in pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name == b'?GetPlatformSpecificIdentifierKey@CConnectionLib@@AEBAPEAEXZ')
code = pe.get_data(export.address, 8)
instruction = next(Cs(CS_ARCH_X86, CS_MODE_64).disasm(code, pe.OPTIONAL_HEADER.ImageBase + export.address))
assert instruction.mnemonic == 'lea' and code[:3] == b'\x48\x8d\x05'
storage_rva = export.address + 7 + int.from_bytes(code[3:7], 'little', signed=True)
kernel = c.WinDLL('kernel32', use_last_error=True)
psapi = c.WinDLL('psapi', use_last_error=True)
kernel.OpenProcess.argtypes = [w.DWORD, w.BOOL, w.DWORD]
kernel.OpenProcess.restype = w.HANDLE
kernel.CloseHandle.argtypes = [w.HANDLE]
kernel.QueryFullProcessImageNameW.argtypes = [w.HANDLE, w.DWORD, w.LPWSTR, c.POINTER(w.DWORD)]
kernel.ReadProcessMemory.argtypes = [w.HANDLE, c.c_void_p, c.c_void_p, c.c_size_t, c.POINTER(c.c_size_t)]
psapi.EnumProcessModules.argtypes = [w.HANDLE, c.POINTER(c.c_void_p), w.DWORD, c.POINTER(w.DWORD)]
handle = kernel.OpenProcess(0x410, False, pid)  # query information + VM_READ only
if not handle:
    raise c.WinError(c.get_last_error())
try:
    name = c.create_unicode_buffer(32768); size = w.DWORD(len(name))
    if not kernel.QueryFullProcessImageNameW(handle, 0, name, c.byref(size)):
        raise c.WinError(c.get_last_error())
    assert Path(name.value).resolve() == image
    modules = (c.c_void_p * 1024)(); needed = w.DWORD()
    if not psapi.EnumProcessModules(handle, modules, c.sizeof(modules), c.byref(needed)):
        raise c.WinError(c.get_last_error())
    base = modules[0]
    def read(address, count):
        buffer = (c.c_ubyte * count)(); actual = c.c_size_t()
        if not kernel.ReadProcessMemory(handle, address, buffer, count, c.byref(actual)):
            raise c.WinError(c.get_last_error())
        assert actual.value == count
        return bytes(buffer)
    assert read(base + export.address, 8) == code
    value = read(base + storage_rva, 32)
    initial = pe.get_data(storage_rva, 32).ljust(32, b'\0')  # virtual zero-filled PE data
    report = dict(target=digest, pid=pid, access='read-only', getterRva=hex(export.address),
                  storageRva=hex(storage_rva), runtimeMatchesInitial=value == initial,
                  runtimeAllZero=value == bytes(32), keySha256=hashlib.sha256(value).hexdigest())
    output = root / 'backups/animations/native-runtime-platform-key-observation.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
finally:
    kernel.CloseHandle(handle)
