"""Unchanged original ClientArea sender, complete area/ambient/sound packers,
scalar/text/ID writers, atan2f and send-envelope owner consume normal installed
session snapshots. Server/table/GFF/lookup/expansion/logging/net transport are
captured boundaries; no real packets or live process alterations. This does
not execute the receiving client or prove ready-handshake integration.
"""
import importlib,sys,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
a=importlib.import_module('inspect-native-area-pack');m=a.m;u=a.u;w=a.w
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(a.hook_handle);u.mem_map(m.heap+0x100000,0x400000)
a.tiles=m.heap+0x110000;a.grass=m.heap+0x120000;a.ids=m.heap+0x130000;a.objectBase=m.heap+0x140000;a.objectStride=0x2000;a.soundRefOffset=0x1000
orientation,info,loadtable,vtable,net,name=[m.heap+0x480000+i*0x100 for i in range(6)];accessor=m.stop+0x300

def hook(u,address,size,unused):
 global randomIndex,sent
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if address==0x14055b980:m.finish(2);return
 if address==0x1404c2ac0:trace.append(['clearLastMap']);m.finish();return
 if address==0x1404be490:trace.append(['setBmp',struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0]]);m.wi(x+0x20,y);m.finish();return
 if address==0x1401a68f0:
  column=a.rawString(z);entry=ca['rows'][y];trace.append(['loadingString',y,column,entry]);a.owning(q,entry['value'].encode('ascii'));m.finish(entry['status']);return
 if address==0x14016ae00:m.finish(int(a.rawString(x).lower()==a.rawString(y).lower()));return
 if address==0x140c7ed00:
  assert randomIndex<len(ca['random']);value=ca['random'][randomIndex];randomIndex+=1;m.finish(value);return
 if address==0x1402d5e60:trace.append(['messageName',x&255,y&255]);m.finish(name);return
 if address==0x140115890:m.finish();return
 if address==accessor:m.finish(net);return
 if address==0x140237b30:
  sent=bytes(u.mem_read(z,q));trace.append(['transportBoundary',y&0xffffffff,q,m.si(rsp+0x28)]);m.finish(1);return
 if any(lo<=address<hi for lo,hi in [(0x1404cd9d0,0x1404ce035),(0x140c8f29c,0x140c8f6ad),(0x1404dc490,0x1404dcb46)]):return
 a.hook(u,address,size,unused)
u.hook_add(UC_HOOK_CODE,hook)

def execute():
 global ca,randomIndex,sent,trace
 ca=a.case['clientArea'];randomIndex=0;sent=None;trace=[]
 m.wi(a.client+0x20,ca['bmp']);m.wi(a.client+0x48,a.case['playerId']);m.wq(a.client+0xa8,info+0x40)
 u.mem_write(a.area+0x350,struct.pack('<H',ca['defaultBmp']));m.wq(a.module+0x108,info)
 for i,value in enumerate(ca['packFloats']):m.wf(info+0x14+i*4,value)
 for i,value in enumerate(ca['orientation']):m.wf(orientation+i*4,value)
 m.wq(a.rules+0x800+0x118,loadtable);m.wi(loadtable+0x50,len(ca['rows']))
 m.wq(a.t.server,vtable);m.wq(vtable+0x38,accessor);u.mem_write(name,b'captured Area/ClientArea\0');u.mem_write(0x14141e310,bytes(16));m.wi(w.message+0x68,1)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[w.message,a.client,a.area]):u.reg_write(reg,value)
 u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',ca['point'][0]),'little'));m.wf(rsp+0x28,ca['point'][1]);m.wf(rsp+0x30,ca['point'][2]);m.wq(rsp+0x38,orientation);m.wi(rsp+0x40,ca['flag'])
 u.emu_start(0x1404cd9d0,m.stop,count=5000000)

source=json.loads((m.root/'backups/animations/live-complete-client-area.json').read_text());rows=[]
for index,row in enumerate(source['cases']):
 u.mem_write(m.heap+0x100000,bytes(0x400000))
 try:
  result=a.run(row['case'],execute);snapshot=dict(result['observation']);native=bytes.fromhex(snapshot.pop('hex'));expected=bytes.fromhex(row['packetHex']);mask=bytes.fromhex(row['definedMaskHex'])
  assert result['result']==1;assert sent==native;assert len(native)==len(expected)
  differences=[dict(index=i,native=x,source=y,mask=b)for i,(x,y,b)in enumerate(zip(native,expected,mask))if x&b!=y&b];assert not differences,differences[:10]
  assert snapshot==row['observation'],(snapshot,row['observation']);assert m.si(a.client+0x20)==-1;assert randomIndex==len(ca['random'])
  rows.append(dict(format=row['case']['format'],areaId=row['case']['id'],result=result['result'],nativeHex=native.hex(),sourceHex=expected.hex(),definedMaskHex=mask.hex(),observation=snapshot,trace=trace,diagnostics=result['diagnostics']))
 except Exception:print(json.dumps(dict(index=index,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
out=m.root/'backups/animations/native-live-complete-client-area-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
