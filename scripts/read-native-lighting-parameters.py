"""Read verified native renderer lighting globals with QUERY_INFORMATION|VM_READ.

No debugger, writes, remote execution, input, account buffers, or general scans.
Addresses come from the retained native-render-parity setter dossiers.
"""
import ctypes as c
from ctypes import wintypes as w
import hashlib
import json
from pathlib import Path
import struct
import sys
import time

k = c.WinDLL('kernel32', use_last_error=True)
p = c.WinDLL('psapi', use_last_error=True)
k.OpenProcess.argtypes = [w.DWORD, w.BOOL, w.DWORD]
k.OpenProcess.restype = w.HANDLE
k.CloseHandle.argtypes = [w.HANDLE]
k.QueryFullProcessImageNameW.argtypes = [w.HANDLE, w.DWORD, w.LPWSTR, c.POINTER(w.DWORD)]
k.ReadProcessMemory.argtypes = [w.HANDLE, c.c_void_p, c.c_void_p, c.c_size_t, c.POINTER(c.c_size_t)]
p.EnumProcessModules.argtypes = [w.HANDLE, c.POINTER(c.c_void_p), w.DWORD, c.POINTER(w.DWORD)]
pid = int(sys.argv[1])
handle = k.OpenProcess(0x410, False, pid)
if not handle:
    raise RuntimeError('Read-only native process access unavailable')
try:
    name = c.create_unicode_buffer(32768)
    size = w.DWORD(len(name))
    if not k.QueryFullProcessImageNameW(handle, 0, name, c.byref(size)):
        raise RuntimeError('Native process identity unavailable')
    image = Path(name.value)
    digest = hashlib.sha256(image.read_bytes()).hexdigest()
    if image.name.lower() != 'nwmain.exe' or digest != '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a':
        raise RuntimeError('Native executable does not match mapped renderer')
    modules = (c.c_void_p * 1024)()
    needed = w.DWORD()
    if not p.EnumProcessModules(handle, modules, c.sizeof(modules), c.byref(needed)):
        raise RuntimeError('Native image base unavailable')
    base = modules[0]

    def scalar(rva, index, fmt):
        address = base + rva + index * 4
        buffer = (c.c_ubyte * 4)()
        actual = c.c_size_t()
        if not k.ReadProcessMemory(handle, address, buffer, 4, c.byref(actual)) or actual.value != 4:
            raise RuntimeError('Renderer global unavailable')
        return struct.unpack(fmt, bytes(buffer))[0]

    result = dict(
        pid=pid, at=int(time.time() * 1000), binary_sha256=digest,
        access='QUERY_INFORMATION|VM_READ', bytes_read=24,
        gamma_correction=scalar(0x13d2810, 0, '<i'),
        fragment_lighting=scalar(0x13d2810, 1, '<i'),
        shader_quality=scalar(0x13d2810, 7, '<i'),
        cutoff_range_multiplier=scalar(0x13d2760, 0x12, '<f'),
        intensity_at_range=scalar(0x13d2760, 0x13, '<f'),
        maximum_intensity=scalar(0x13d2760, 0x14, '<f'),
        scope='Six mapped renderer globals only; no account or private-key data, memory writes, debugger attach, or process control.',
    )
    # Verified setters: GLRender::SetAreaAmbientLight b67e0 and
    # SetAreaDiffuseLight b6840. Headlight flag getter a5120 and property
    # setter 7dcb0 were independently inspected through REA.
    result['area_ambient_linear'] = [scalar(0x14087a0, index, '<f') for index in range(3)]
    result['area_diffuse_linear'] = [scalar(0x14087b0, index, '<f') for index in range(3)]
    result['area_diffuse_direction'] = [scalar(0x14087c0, index, '<f') for index in range(3)]
    result['headlight_enabled_word'] = scalar(0x128e520, 0, '<I') & 0xffff
    result['headlight_diffuse'] = [scalar(0x128e5c0, index, '<f') for index in range(3)]
    result['headlight_ambient'] = [scalar(0x128e5d0, index, '<f') for index in range(3)]
    # Camera::InitializeFrameBufferResources 140059670 and
    # DoFrameBufferEffects 140057b20 verify these exact renderer globals.
    # HDR/active postprocessing must be recorded, not inferred from shaders
    # or a saved profile. They contain no account or server payload data.
    result['framebuffer'] = dict(
        hdr=scalar(0x12e0320, 0, '<i'),
        effects_mask=scalar(0x12e0314, 0, '<I'),
        enabled=scalar(0x128e2f4, 0, '<i'),
        postprocess_types=scalar(0x13d2810, 2, '<I'),
        display_gamma=scalar(0x13d2760, 11, '<f'),
        levels_blackpoint=scalar(0x13d2760, 3, '<f'),
        levels_whitepoint=scalar(0x13d2760, 4, '<f'),
        dynamic_contrast_intensity=scalar(0x13d2760, 5, '<f'),
        dynamic_contrast_midpoint=scalar(0x13d2760, 6, '<f'),
        vibrance=scalar(0x13d2760, 7, '<f'),
    )
    result['bytes_read'] = 128
    result['scope'] = 'Verified renderer lighting globals only; no account/private-key reads, general scans, memory writes, debugger attach, or process control. Area shader state may be transient during GUI draws.'
    if '--sample' in sys.argv[3:]:
        samples = {}
        for _ in range(1000):
            state = dict(
                ambient=[scalar(0x14087a0, index, '<f') for index in range(3)],
                diffuse=[scalar(0x14087b0, index, '<f') for index in range(3)],
                direction=[scalar(0x14087c0, index, '<f') for index in range(3)],
                headlight=scalar(0x128e520, 0, '<I') & 0xffff,
            )
            identity = json.dumps(state, sort_keys=True)
            if identity in samples:
                samples[identity]['count'] += 1
            elif len(samples) < 128:
                samples[identity] = dict(state=state, count=1)
            time.sleep(0.002)
        result['observations'] = list(samples.values())
        result['bytes_read'] += 1000 * 40
        result['scope'] += ' Polls are not atomic draw captures; repeated stable states must be distinguished from mid-update observations.'
    if len(sys.argv) > 2:
        with Path(sys.argv[2]).open('x', encoding='utf8') as output:
            json.dump(result, output, indent=2)
            output.write('\n')
    print(json.dumps(result))
finally:
    k.CloseHandle(handle)
