"""Authorized original-client observation using QUERY_INFORMATION + VM_READ only.

Private key buffers are never read. Initial mode locates the verified native
GetNetLayer vtable entry; account mode reads only retained BNCS name/public IDs.
"""
import ctypes as c
from ctypes import wintypes as w
import sys, json, hashlib, struct, re
from pathlib import Path

kernel=c.WinDLL('kernel32',use_last_error=True); psapi=c.WinDLL('psapi',use_last_error=True)
kernel.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD]; kernel.OpenProcess.restype=w.HANDLE
kernel.CloseHandle.argtypes=[w.HANDLE]
kernel.QueryFullProcessImageNameW.argtypes=[w.HANDLE,w.DWORD,w.LPWSTR,c.POINTER(w.DWORD)]
kernel.ReadProcessMemory.argtypes=[w.HANDLE,c.c_void_p,c.c_void_p,c.c_size_t,c.POINTER(c.c_size_t)]
psapi.EnumProcessModules.argtypes=[w.HANDLE,c.POINTER(c.c_void_p),w.DWORD,c.POINTER(w.DWORD)]
pid=int(sys.argv[1]); handle=kernel.OpenProcess(0x410,False,pid)
if not handle: raise RuntimeError('Read-only process access unavailable')
try:
    name=c.create_unicode_buffer(32768); size=w.DWORD(len(name))
    if not kernel.QueryFullProcessImageNameW(handle,0,name,c.byref(size)): raise RuntimeError('Process image unavailable')
    image=Path(name.value)
    if image.name.lower()!='nwmain.exe': raise RuntimeError('Unexpected process')
    digest=hashlib.sha256(image.read_bytes()).hexdigest()
    if digest!='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a': raise RuntimeError('Unverified original image')
    modules=(c.c_void_p*1024)(); needed=w.DWORD()
    if not psapi.EnumProcessModules(handle,modules,c.sizeof(modules),c.byref(needed)): raise RuntimeError('Process modules unavailable')
    base=modules[0]
    def read(address,count):
        buffer=(c.c_ubyte*count)(); actual=c.c_size_t()
        if not kernel.ReadProcessMemory(handle,address,buffer,count,c.byref(actual)) or actual.value!=count: raise RuntimeError('Read-only field unavailable')
        return bytes(buffer)
    def q(address): return struct.unpack('<Q',read(address,8))[0]
    manager=q(base+0x12df970)
    rows=[]
    for offset in [0,8]:
        try:
            app=q(manager+offset)
            if not app: continue
            table=q(app)
            getter=q(table+0x38)
            rows.append(dict(appOffset=offset,getterRva=hex(getter-base),getterBytes=read(getter,24).hex()))
        except RuntimeError:
            rows.append(dict(appOffset=offset,available=False))
    report=dict(pid=pid,access='QUERY_INFORMATION|VM_READ',binarySha256=digest,apps=rows)
    if len(sys.argv)>2:
        expected=sys.argv[2]
        if len(expected)!=64: raise RuntimeError('Expected comparison digest unavailable')
        app=q(manager)
        getter=q(q(app)+0x38)
        if getter-base!=0x6abfb0 or read(getter,9)!=bytes.fromhex('488b4108488b4018c3'): raise RuntimeError('Unverified native getter')
        net=q(q(app+8)+0x18)
        internal=q(net+8)
        def exo(offset,maximum):
            pointer=q(internal+offset)
            length=struct.unpack('<I',read(internal+offset+8,4))[0]
            if length>maximum or length and not pointer: raise RuntimeError('Unexpected retained login string')
            return read(pointer,length) if length else b''
        player=exo(0x10,255); public=exo(0x20,8); legacy=exo(0x30,8)
        report['account']=dict(playerName=player.decode('cp1252'),publicIdLength=len(public),publicIdentityMatchesSupplied=hashlib.sha256(public).hexdigest()==expected,legacyPresent=bool(legacy),legacyIdentityMatchesSupplied=hashlib.sha256(legacy).hexdigest()==expected)
        # Locate the effective profile without exporting its key or identifier.
        # Same CDUtil selection independently executed in check-private-login-oracle.py.
        def public_id(key):
            if len(key)!=41: return b''
            stage=material=check=index=0; output=''
            while index<41:
                char=key[index]
                if char!='-':
                    if stage==0 and material<=19:
                        stage=1; material+=1; index+=1; continue
                    if stage in [0,1]:
                        stage=2
                        if material>12 and check<7:
                            check+=1; index+=1; continue
                    stage=0
                    if len(output)<8: output+=char
                    elif material<20 or check<7: index-=1
                index+=1
            return output.encode('ascii')
        report['profiles']=[]
        for folder in ['Neverwinter Nights.0','Neverwinter Nights']:
            file=Path.home()/'Documents'/folder/'cdkey.ini'
            if not file.is_file(): continue
            content=file.read_text()
            for field,key in re.findall(r'^\s*(YourKey|Key[123])\s*=\s*([A-Z0-9-]+)\s*$',content,re.I|re.M):
                report['profiles'].append(dict(profile=folder,field=field,publicIdentityMatchesNative=public_id(key.upper())==public))
            content=''; key=''
    print(json.dumps(report))
finally:
    kernel.CloseHandle(handle)
