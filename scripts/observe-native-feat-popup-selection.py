"""Execute unchanged original CGuiListBox constructor/SetCurrentSelection.
Base GUI/scrollbar construction and the native string-renderer interface are
captured boundaries. The original listbox owns its palette RGBA, selected
index, row flags and line palette calls. No GPU or running process is used.
"""
from pathlib import Path
import sys,struct,importlib.util,json,hashlib
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
spec=importlib.util.spec_from_file_location('image',root/'scripts/inspect-native-intratile-coordinator.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
obj,string,table,wrapper=[m.heap+offset for offset in [0x10000,0x11000,0x12000,0x13000]]
stub=m.stop+0x100;calls=[];colors={};flags={};palettes={};count=7
for slot in range(0,0x110,8):m.wq(table+slot,stub+slot)
m.wq(string,table)
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def rf(address):return struct.unpack('<f',bytes(u.mem_read(address,4)))[0]
def hook(u,address,size,unused):
    if address==m.stop:u.emu_stop();return
    x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]];rsp=u.reg_read(UC_X86_REG_RSP)
    if address in [0x1401fac90,0x1401e5e60]:calls.append(dict(kind='base-gui-boundary',procedure=hex(address)));m.finish()
    elif address==0x1400492f0:calls.append(dict(kind='string-factory-boundary',format=x&0xffffffff));m.finish(string)
    elif stub<=address<stub+0x110:
        slot=address-stub;assert x==string,(hex(address),hex(x))
        if slot==0xb8:m.finish(wrapper)
        elif slot in [0x48,0x50,0x100]:calls.append(dict(kind='string-setup',slot=hex(slot),value=y));m.finish()
        elif slot==0x78:calls.append(dict(kind='normal-rgba',rgba=[xmm(UC_X86_REG_XMM1),xmm(UC_X86_REG_XMM2),xmm(UC_X86_REG_XMM3),rf(rsp+0x28)]));m.finish()
        elif slot==0x80:
            rgba=[xmm(UC_X86_REG_XMM2),xmm(UC_X86_REG_XMM3),rf(rsp+0x28),rf(rsp+0x30)];colors[y&0xffffffff]=rgba;calls.append(dict(kind='palette-rgba',index=y&0xffffffff,rgba=rgba));m.finish()
        elif slot==0xe8:m.finish(count)
        elif slot==0xf0:m.finish(flags.get(y&0xffffffff,0))
        elif slot==0xf8:flags[y&0xffffffff]=z&0xffffffff;calls.append(dict(kind='row-flags',index=y&0xffffffff,value=z&0xffffffff));m.finish()
        elif slot==0x108:palettes[y&0xffffffff]=z&0xffffffff;calls.append(dict(kind='row-palette',index=y&0xffffffff,palette=z&0xffffffff));m.finish()
        else:raise AssertionError('Uncaptured string method '+hex(slot))
    elif not(0x1401e8160<=address<0x1401e83f6 or 0x1401eb650<=address<0x1401eb7b7):raise AssertionError('Uncaptured original dependency '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def call(address,*args):
    rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
    u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
if __name__=='__main__':
    out=root/'godot-client/reports/native-feat-popup-selection-original-v1.json';assert not out.exists(),'Preserve source evidence'
    call(0x1401e8160,obj);constructor=calls.copy();assert colors=={1:[1.0,1.0,0.0,1.0],2:[1.0,1.0,1.0,1.0]},colors
    rows=[]
    for selected in [2,5,5,7,-1,0,6]:
        calls=[];before=m.si(obj+0x42c);call(0x1401eb650,obj,selected)
        after=m.si(obj+0x42c);rows.append(dict(request=selected,before=before,selected=after,calls=calls.copy(),palettes=palettes.copy(),flags=flags.copy()))
        assert after==(selected if 0<=selected<count else -1)
        if after>=0:assert palettes[after]==1 and flags[after]&0x10
        if before>=0 and before!=after:assert palettes[before]==0 and flags[before]&0x10==0
    value=dict(binarySha256=m.digest,scope=__doc__,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),constructor=constructor,colors=colors,rows=rows)
    out.write_text(json.dumps(value,indent=2)+'\n');print(json.dumps(dict(output=str(out),colors=colors,transitions=len(rows))))
