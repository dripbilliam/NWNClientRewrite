"""Original client767740 circle/segment query, including rotating membership
and native owner/control bypass. Candidate object lookups, virtual casts and
control-ID/mode getters are captured; comparisons and float geometry execute.
No copied assets, server simulation or live process modifications.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-drive-preview');m=p.m;u=p.u;w=p.w
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(p.hook_handle);listing=m.heap+0x50000;ids=listing+0x1000;owner=m.heap+0x40000
def hook(u,a,n,data):
 x=u.reg_read(UC_X86_REG_RCX);y=u.reg_read(UC_X86_REG_RDX)
 if a==0x1406ab9e0:m.finish(owner if c.get('ownerAvailable',True)else 0);return
 if a==0x1406ac1c0:m.finish(c.get('controlledId',999));return
 if a==0x1406ac3d0:m.finish(c.get('controlFlag',0));return
 if a==0x1406d81f0:lookups.append(y&0xffffffff);m.finish(objects.get(y&0xffffffff,0));return
 if a in[m.stop+0x180,m.stop+0x580]:m.finish(x);return
 if 0x140767740<=a<0x140767b34 or 0x1402303d0<=a<0x14023040e or 0x140c7d6d8<=a<0x140c7d784:return
 p.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def putObject(ptr,o):
 m.wq(ptr,ptr+0x800);m.wq(ptr+0x800+0x18,m.stop+0x180);m.wq(ptr+0x800+0x58,m.stop+0x580);m.wi(ptr+8,o['id']);u.mem_write(ptr+0xc,bytes([o.get('type',5)]));p.put(ptr+0x38,o.get('position',[0,0,0]));m.wq(ptr+0x300,ptr+0x400);m.wf(ptr+0x400+0xe0,o.get('radius',.5));m.wq(ptr+0x3b0,ptr+0x600);m.wi(ptr+0x600+0x110,o.get('flag110',0));m.wi(ptr+0x600+0x114,o.get('flag114',0))
def run(case):
 global c,objects,lookups
 c=case;objects={};lookups=[];p.t.reset(dict(format=1));m.wq(w.app,p.owner);m.wi(p.owner+0x630,c.get('controlFlag',0));putObject(owner,dict(id=123,flag110=c.get('flag110',0),flag114=c.get('flag114',0)))
 for i,o in enumerate(c['objects']):
  if o.get('missing'):continue
  ptr=m.heap+0x60000+i*0x1000;putObject(ptr,o);objects[o['id']]=ptr
 members=c.get('ids',[o['id']for o in c['objects']]);m.wq(listing+8,ids);m.wi(listing+0x10,len(members));m.wi(listing+0x18,c.get('cursor',-1))
 for i,oid in enumerate(members):m.wi(ids+i*4,oid)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,listing)
 for reg,v in zip([UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3],[*c['from'],c['to'][0]]):u.reg_write(reg,int.from_bytes(struct.pack('<f',v),'little'))
 m.wf(rsp+0x28,c['to'][1]);m.wi(rsp+0x30,c.get('ignoredId',123));m.wf(rsp+0x38,c['radius']);u.emu_start(0x140767740,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_EAX),cursor=m.si(listing+0x18),lookups=lookups)
lines=[([0,0],[4,0]),([4,0],[0,0]),([0,0],[0,4]),([0,4],[0,0]),([0,0],[4,4]),([0,0],[0,0])]
points=[[2,0,0],[-.25,0,0],[4.25,0,0],[2,1,0],[2,.999,0],[2,1.001,0],[0,-1,0],[4,1,0],[2,0,100]]
cases=[dict(zip(['from','to'],line),radius=radius,objects=[dict(id=201,position=pos,radius=.5,type=kind)])for line,pos,radius,kind in itertools.product(lines,points,[0,.5],[5,9])]
for profile in[dict(flag110=1,flag114=0),dict(flag110=1,flag114=1),dict(ownerAvailable=False),dict(controlledId=123,controlFlag=1)]:cases.append(dict(zip(['from','to'],lines[0]),radius=.5,objects=[dict(id=201,position=[2,0,0],radius=.5)],**profile))
for cursor,ids_ in itertools.product([-1,0,1],[[201,202,203],[201,201,202],[999,201,202],[201,999,202]]):cases.append(dict(zip(['from','to'],lines[0]),radius=.5,cursor=cursor,ids=ids_,objects=[dict(id=201,position=[8,8,0]),dict(id=202,position=[2,0,0]),dict(id=203,position=[2,1,0])]))
cases.append(dict(zip(['from','to'],lines[0]),radius=.5,objects=[]))
cases.append(dict(zip(['from','to'],lines[0]),radius=.5,ignoredId=201,objects=[dict(id=201,position=[2,0,0],radius=.5)]))
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-client-creature-line-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
