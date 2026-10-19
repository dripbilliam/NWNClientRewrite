"""Original WalkToWaypoint140455860. Scalar codec, lookup/casts, path reset,
AI/mode/action manager, round and move insertion are captured boundaries.
Original vector normalize/cross execute; no packet/geometry/render parity claim.
Synthetic inputs only, unchanged original image SHA verified by shared fixture.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
message,client,actor,path,area,target,vt,app,roundPtr=[m.heap+i*0x1000 for i in range(1,10)]
def hook(u,a,n,_):
 global oid,axis,byte,boolean
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140476130:v=[c['areaId'],c['targetId']][oid];oid+=1;m.finish(v)
 elif a==0x1402d9c30:v=c['point'][axis];axis+=1;u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish()
 elif a==0x1402d9630:v=[c['sequence'],c['fractional']][byte];byte+=1;m.finish(v)
 elif a==0x1402d9600:v=[c['run'],c['clientPath']][boolean];boolean+=1;m.finish(v)
 elif a==0x1402d9460:m.finish(c.get('overflow',0))
 elif a==0x1402d9520:m.finish(c.get('underflow',0))
 elif a==0x1404ba840:m.finish(actor if c.get('controlled',True) else 0)
 elif a==0x140494e80:m.finish(area if c.get('area',True) else 0)
 elif a==m.stop+0x10:m.finish(x if c.get('creature',True) else 0)
 elif a==m.stop+0x20:m.finish(x if c.get('asObject',True) else 0)
 elif a==0x140294430:
  calls.append(['reset']);m.wi(path+0x20,0);m.finish()
 elif a==0x14055b4c0:m.finish(target if c.get('target',True) else 0)
 elif a==0x140379c70:calls.append(['pause',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x140379c30:calls.append(['pauseTimer',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1403e2830:calls.append(['combatStep',y&255,z&0xffffffff,w&0xffffffff]);m.finish()
 elif a==0x140387dc0:calls.append(['compute']);u.mem_write(actor+0x8d6,bytes([c.get('computed',0)]));m.finish()
 elif a==0x14055b9c0:m.finish(c['sticky'])
 elif a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);m.finish()
 elif a==0x140375570:calls.append(['clearSpecial']);m.finish()
 elif a==0x14037cbc0:calls.append(['actionManager',y&0xffffffff]);m.finish()
 elif a==0x14037f940:
  calls.append(['move',y&65535,[m.rf(z+i)for i in [0,4,8]],w&0xffffffff,m.si(sp+0x28)&0xffffffff,m.si(sp+0x30),m.rf(sp+0x38),m.rf(sp+0x40),m.si(sp+0x48),m.si(sp+0x50),m.si(sp+0x58),m.si(sp+0x60),m.si(sp+0x68),m.si(sp+0x70)]);m.finish(1)
 elif a==0x140c7d6d8:
  encoded=struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0)))
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(encoded,'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140455860,0x140455f44),(0x140230920,0x140230a10),(0x14022fba0,0x14022fc80)]):raise AssertionError(f'Unexpected walk dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,oid,axis,byte,boolean
 c=dict(areaId=88,targetId=0x7f000000,point=[8,5,0],sequence=17,fractional=0,run=1,clientPath=0,sticky=0)|case;calls=[];oid=axis=byte=boolean=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vt);m.wq(target,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x20,m.stop+0x20)
 m.wq(actor+0x530,path);m.wq(actor+0x880,roundPtr);m.wi(actor+8,99);m.wi(actor+0x8ac,c.get('field8ac',0));m.wi(actor+0xec,c.get('commandable',1));m.wi(actor+0x8d8,100);u.mem_write(actor+0x8d6,bytes([c.get('state',0)]))
 for i,v in enumerate(c.get('position',[4,5,0])):m.wf(actor+0xa4+i*4,v)
 for i,v in enumerate(c.get('targetPosition',[6,5,0])):m.wf(target+0xa4+i*4,v)
 stored=c.get('stored',[1,1,1]);reverse=c.get('reverse',0);m.wi(path+0x74,reverse);m.wi(path+0x28,c.get('storedTarget',0x7f000000));m.wi(path+(0x70 if reverse else 0x60),c.get('storedArea',88))
 for i,v in enumerate(stored):m.wf(path+(0x64 if reverse else 0x4c)+i*4,v)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,message);u.reg_write(UC_X86_REG_RDX,client)
 try:u.emu_start(0x140455860,m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,sequence=m.si(path+0x20)&0xffffffff,fractional=m.si(path+0x19c))
cases=[dict(run=r,clientPath=p,fractional=f,sequence=s,sticky=t,computed=k)for r,p,f,s,t,k in itertools.product([0,1],[0,1],[0,1,2],[0,255],[0,1],[0,1,2])]
cases += [{k:v}for k,vals in dict(overflow=[1,-1],underflow=[1],controlled=[False],area=[False],creature=[False],field8ac=[1],commandable=[0,2]).items()for v in vals]
cases += [dict(point=p,stored=[8,5,0],reverse=r)for p,r in itertools.product([[8,5,0],[8.099,5,0],[8.101,5,0]],[0,1])]
cases += [dict(state=2,point=p,target=t,asObject=a,targetPosition=q)for p,t,a,q in itertools.product([[4,5,0],[5,5,0],[3,5,0],[4,6,0],[4,4,0],[4,5,1],[5.5,5,0]],[False,True],[False,True],[[6,5,0],[4,7,1]])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-player-walk-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
