"""Original client7bfbe0 sender; original server4bceb5..4bcf27 pack block
with real localized-name/DWORD/opaque-byte codecs. BIC serialization, filesystem,
virtual creature names and transport are explicit synthetic boundaries. No
complete SaveCreature, client filename, GUI or live persistence claim.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
creature,vt,first,last,payload,player=[m.heap+n for n in [0x80000,0x81000,0x82000,0x84000,0x86000,0x89000]]
def loc(ptr,raw,ref):
 private,linked,node,entry,buf=[ptr+n for n in[0x100,0x200,0x300,0x400,0x500]]
 m.wq(ptr,private);m.wi(ptr+8,ref);m.wq(private,linked);m.wi(private+8,int(case['localized']));m.wq(linked,node if case['localized']else 0);m.wq(node+8,0);m.wq(node+0x10,entry);m.wi(entry,0);m.wq(entry+8,buf);m.wi(entry+0x10,len(raw));u.mem_write(buf,raw or b'\0')
def hook(u,a,n,data):
 if a==m.stop+0x240:m.finish(first);return
 if a==m.stop+0x260:m.finish(last);return
 if a==0x1407c25c0:
  size=m.si(u.reg_read(UC_X86_REG_RSP)+0x28)&0xffffffff;assert size==0 and u.reg_read(UC_X86_REG_R9)==0;requests.append([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255]);m.finish(1);return
 if 0x1407bfbe0<=a<0x1407bfc00 or 0x1404bceb5<=a<0x1404bcf27 or 0x1402dbc20<=a<0x1402dbccd:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,localized,size in itertools.product([0,1],[False,True],[0,1,7,128,4097]):
 case=dict(format=fmt,localized=localized,size=size);requests=[];t.reset(dict(format=fmt));w.call(0x1407bfbe0,[w.message]);assert requests==[[112,6,31]]
 m.wq(creature,vt);m.wq(vt+0x120,m.stop+0x240);m.wq(vt+0x128,m.stop+0x260);loc(first,b'Native \x80\xe9',123);loc(last,b'Export',456)
 data=bytes((i*17+3)&255 for i in range(size));u.mem_write(payload,data or b'\0');m.wi(player+0x48,0x80000001)
 rsp=m.stack+0x1f008;rbp=m.stack+0x1f800;m.wq(rbp+0x67,player);m.wq(rbp+0x77,w.message)
 for reg,value in[(UC_X86_REG_RSP,rsp),(UC_X86_REG_RBP,rbp),(UC_X86_REG_RBX,creature),(UC_X86_REG_R12,size),(UC_X86_REG_R13,payload)]:u.reg_write(reg,value)
 u.emu_start(0x1404bceb5,0x1404bcf27,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x1404bcf27
 observation=w.snapshot();rows.append(dict(case=case,request=requests[0],payload=data.hex(),body=observation))
out=m.root/'backups/animations/native-character-export-wire-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(rows))))
