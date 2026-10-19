"""Execute unchanged CNWSTransition::LoadFromGff; capture typed GFF reads/free.
The byte-verified original PE stays read-only. In particular, capture the
sixth ReadFieldCExoString argument rather than trusting decompiler arity.
"""
import importlib,sys,json,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,gff,root=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000
def exostring(p,s):
 global cursor
 b=s.encode('ascii');a=m.heap+cursor;cursor+=len(b)+32
 u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def cstring(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('ascii')
def read(name,t,default):
 entry=nested.get('fields',{}).get(name)
 return (entry['value'],1)if entry and entry['type']==t else(default,0)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1401a04e0:
  assert cstring(w)=='Transition';entry=case['data']['fields'].get('Transition');ok=entry is not None and entry['type']==14
  m.wi(y,1 if ok else -1);calls.append(['struct',int(ok)]);m.finish(int(ok));return
 if a==0x1401a1130:
  assert cstring(w)=='TargetTag';default=text(m.q(rsp+0x30));value,status=read('TargetTag',10,default)
  m.wi(m.q(rsp+0x28),status);exostring(y,value);calls.append(['tag',default,status]);m.finish(y);return
 if a==0x1401a1510:
  assert cstring(z)=='TargetObjectId';default=m.si(rsp+0x28)&0xffffffff;value,status=read('TargetObjectId',4,default)
  m.wi(w,status);calls.append(['id',default,status]);m.finish(value);return
 if a==0x140c10370:m.finish();return
 if not 0x1404fe610<=a<=0x1404fe6d7:raise RuntimeError(f'Uncaptured transition dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def f(t,v):return dict(type=t,value=v)
def node(fields):return dict(type=1,fields=fields)
cases=[]
for initial in [dict(targetTag='',targetObjectId=0x7f000000),dict(targetTag='Existing\0tail',targetObjectId=0xffffffff)]:
 for fields in [None,{},dict(TargetTag=f(10,'New\0tail')),dict(TargetObjectId=f(4,0x80000001)),dict(TargetTag=f(10,''),TargetObjectId=f(4,0)),dict(TargetTag=f(4,2),TargetObjectId=f(5,-1))]:
  cases.append(dict(initial=initial,data=node({}if fields is None else dict(Transition=f(14,node(fields))))))
 cases.append(dict(initial=initial,data=node(dict(Transition=f(10,'wrong-type')))))
observations=[]
for case in cases:
 cursor=0x10000;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));nested=case['data']['fields'].get('Transition',{}).get('value',{})
 if not isinstance(nested,dict):nested={}
 exostring(obj,case['initial']['targetTag']);m.wi(obj+0x10,case['initial']['targetObjectId']);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[obj,gff,root]):u.reg_write(reg,v)
 u.emu_start(0x1404fe610,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 observations.append(dict(case=copy.deepcopy(case),output=dict(targetTag=text(obj),targetObjectId=m.si(obj+0x10)&0xffffffff),calls=calls))
out=m.root/'backups/animations/native-object-transition-load-observations.json';out.write_text(json.dumps(dict(cases=observations),indent=2)+'\n')
print(json.dumps(dict(cases=len(observations),output=str(out))))
