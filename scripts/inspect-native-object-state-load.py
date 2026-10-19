"""Unchanged generic load coordinator, captured GFF/construct/load/apply owners.
Full effect payload loading is separately executed in game-effect-load oracle.
"""
import importlib,sys,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,gff,root,storage=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x10000
def string(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('ascii')
def hook(u,a,n,_):
 global allocated
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1401a02c0:assert string(w)=='EffectList';calls.append(['list',c['status']]);m.finish(c['status']);return
 if a==0x1401a0370:m.finish(len(c['effects']));return
 if a==0x1401a03f0:m.wi(y,w);m.finish(1);return
 if a==0x140c10324:assert x==0x110;allocated+=1;m.finish(storage+allocated*0x200);return
 if a==0x1404233d0:calls.append(['construct',y]);m.finish(x);return
 if a==0x1404246d0:
  row=c['effects'][m.si(z)];loaded[x]=row;m.wi(x+0xe8,row['skipOnLoad']);u.mem_write(x+10,struct.pack('<H',row['packed']));calls.append(['load',row['id']]);m.finish();return
 if a==0x140423770:calls.append(['destroy',loaded[x]['id']]);m.finish();return
 if a==0x140c10360:assert y==0x110;m.finish();return
 if a==0x14048e350:assert x==obj;calls.append(['apply',loaded[y]['id'],z,w]);m.finish();return
 for address,name,offset in [(0x140507640,'variables',0x108),(0x1404963f0,'actions',0),(0x1404fe610,'transition',0x288)]:
  if a==address:assert x==obj+offset;calls.append([name]);m.finish();return
 if a==0x140c10410:m.finish();return
 if not 0x1404974b0<=a<=0x140497609:raise RuntimeError(f'Uncaptured object load dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
cases=[dict(status=0,effects=[dict(id='not-read',skipOnLoad=0,packed=1)]),dict(status=1,effects=[])]
for skip in [0,1,2,-1,256]:cases.append(dict(status=1,effects=[dict(id=f'{skip}-{i}',skipOnLoad=skip,packed=i|16)for i in range(8)]))
out=[]
for c in cases:
 calls=[];loaded={};allocated=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[obj,gff,root]):u.reg_write(reg,v)
 u.emu_start(0x1404974b0,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;out.append(dict(case=c,calls=calls))
path=m.root/'backups/animations/native-object-state-load-observations.json';path.write_text(json.dumps(dict(target=m.digest,cases=out),indent=2)+'\n');print(json.dumps(dict(cases=len(out),output=str(path))))
