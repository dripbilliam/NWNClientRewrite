"""Original missing-target fragment7aca8e..7acc54, delay setter765920,
fade/expiry762e40 and creature-AI removal fragment7fc56c..7fc5d2.
Creature ctor/model loader, object array/area/scene/AI virtuals, timer scalar
services, target alpha and alpha output are captured lower boundaries, not full scene/loader.
No install writes, server registry mutation, hardware render or wire claim.
Fade-out completion with delayed removal requires a nonnull model handle in the
original; invalid synthetic combinations that dereference null are excluded.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
dummy,vt,stats,app,player,area,handle,hvt,config=[m.heap+n*0x1000 for n in range(1,10)]
load,setId,setArea,scene,position,asObject,display210,display200,display218,display1f8,alpha,handleScene,destroy=[m.stop+n*0x10 for n in range(1,14)]
ranges=[(0x1407aca8e,0x1407acc54),(0x140765920,0x140765af2),(0x140762e40,0x140763073),(0x1407fc56c,0x1407fc5d2)]
def ui(p):return m.si(p)&0xffffffff
def text(p):return bytes(u.mem_read(p,64)).split(b'\0')[0].decode('ascii')if p else ''
def fb(p):return ui(p)
def xmm(r):return struct.unpack('<f',struct.pack('<I',u.reg_read(r)&0xffffffff))[0]
def hook(u,a,n,_):
 global worldCalls,deleted
 if a in [m.stop,0x1407acc54,0x1407ae7fd,0x1407fc5d2,0x1407fc730]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:calls.append(['allocate',x]);m.finish(0 if c.get('allocateFailure',0)else dummy)
 elif a==0x1407fb140:calls.append(['ctor']);m.finish(dummy)
 elif a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==load:calls.append(['load',text(y),z&255,w&255]);m.finish(c.get('load',1))
 elif a==0x1406ac1a0:worldCalls+=1;calls.append(['player']);m.finish(player if c.get('player',1)else 0)
 elif a==0x1406abb70:m.finish(app)
 elif a==0x140295d40:calls.append(['register']);m.wi(y,7);m.finish(c.get('register',0))
 elif a==setId:calls.append(['id',y&0xffffffff]);m.wi(dummy+8,y);m.finish()
 elif a==setArea:calls.append(['area']);m.wq(dummy+0x30,y);m.finish()
 elif a==0x1406ab940:m.finish(app)
 elif a==0x1407675d0:calls.append(['ai']);m.finish()
 elif a==scene:calls.append(['scene',y]);m.finish()
 elif a==position:calls.append(['position',list(struct.unpack('<3f',u.mem_read(y,12)))]);u.mem_write(dummy+0x38,bytes(u.mem_read(y,12)));m.finish()
 elif a==asObject:m.finish(dummy)
 elif a==0x1406ac330:m.finish(app)
 elif a==0x140597180:calls.append(['time']);m.wi(y,10);m.wi(z,1000);m.finish()
 elif a==0x140597a20:calls.append(['difference']);m.wi(m.q(rsp+0x30),c.get('elapsedDay',0));m.wi(m.q(rsp+0x38),c.get('elapsed',0));m.finish()
 elif a==0x140597050:calls.append(['snapshot']);m.finish(c.get('microseconds',16000))
 elif a==0x1407630e0:calls.append(['targetAlpha']);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c.get('targetAlpha',1)),'little'));m.finish()
 elif a==0x1406ab9b0:m.finish(config)
 elif a==0x1406ac1c0:calls.append(['controlled']);m.finish(c.get('controlled',7))
 elif a in [display210,display200,display218,display1f8]:calls.append(['display',{display210:0x210,display200:0x200,display218:0x218,display1f8:0x1f8}[a]]);m.finish()
 elif a==alpha:calls.append(['alpha',struct.unpack('<I',struct.pack('<f',xmm(UC_X86_REG_XMM1)))[0],z&255]);m.finish()
 elif a==handleScene:calls.append(['handleScene',y&0xffffffff]);m.finish()
 elif a==0x140767b40:calls.append(['removeAI']);m.finish()
 elif a==0x1402963d0:calls.append(['delete',y&0xffffffff]);m.wq(z,dummy if c.get('deleteObject',1)else 0);m.finish(c.get('deleteStatus',0))
 elif a==destroy:calls.append(['destroy',y&0xffffffff]);deleted=True;m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured dummy dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def setup(case):
 global c,calls,worldCalls,deleted,rsp,rbp
 c=case;calls=[];worldCalls=0;deleted=False;u.mem_write(m.heap,bytes(0x20000));rsp=m.stack+0x1ee08;rbp=rsp+0x700;u.mem_write(rsp-0x1000,bytes(0x2100));m.wq(rsp,m.stop)
 m.wq(0x1412df970,app);m.wq(app,app);m.wq(dummy,vt);m.wq(dummy+0x300,stats);m.wq(dummy+0x78,handle if c.get('handle',1)else 0);m.wq(handle,hvt);m.wq(player+0x30,area if c.get('area',1)else 0);m.wq(area+0x248,1234);u.mem_write(config+0x1c,bytes([c.get('mode',2)]));m.wi(dummy+8,c.get('objectId',0x7f000000));m.wi(stats+0xcc,0xaaaa)
 for off,fn in [(0xf0,load),(8,setId),(0x118,setArea),(0x138,scene),(0x128,position),(0x18,asObject),(0x210,display210),(0x200,display200),(0x218,display218),(0x1f8,display1f8),(0,destroy)]:m.wq(vt+off,fn)
 m.wq(hvt+0xe8,alpha);m.wq(hvt+8,handleScene);u.mem_write(dummy+0xa8,bytes([c.get('fade',1),c.get('target',1)]));m.wf(dummy+0xb0,c.get('alpha',1));m.wf(dummy+0x60,c.get('targetAlpha',1));m.wi(dummy+0x104,c.get('temporary',0));m.wi(dummy+0x108,c.get('blocked',0));m.wi(dummy+0xac,c.get('delay',0));m.wi(dummy+0xa4,c.get('duration',500));m.wi(dummy+0x9c,9);m.wi(dummy+0xa0,900)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RBP,rbp),(UC_X86_REG_RCX,dummy),(UC_X86_REG_RDI,0)]:u.reg_write(reg,value)
 u.reg_write(UC_X86_REG_MXCSR,0x1f80)
def state():return dict(id=ui(dummy+8),position=list(struct.unpack('<3f',u.mem_read(dummy+0x38,12))),desired=list(struct.unpack('<3f',u.mem_read(dummy+0x2c0,12))),appearance=int.from_bytes(u.mem_read(stats+0xcc,2),'little'),temporary=ui(dummy+0x104),target=u.mem_read(dummy+0xa9,1)[0],fade=u.mem_read(dummy+0xa8,1)[0],duration=ui(dummy+0xa4),delay=ui(dummy+0xac),alpha=fb(dummy+0xb0),since=dict(day=ui(dummy+0x9c),time=ui(dummy+0xa0)),visible=ui(dummy+0xf4),deleted=deleted)
def run(case):
 setup(case);mode=c['modeName']
 if mode=='create':
  start=0x1407aca8e;u.reg_write(UC_X86_REG_RBX,0);u.reg_write(UC_X86_REG_R12,6);u.reg_write(UC_X86_REG_RSI,c['targetId']);m.wi(rbp-0x74,c['travel']);m.wi(rsp+0x48,c['targetId']);u.reg_write(UC_X86_REG_XMM10,int.from_bytes(struct.pack('<2f',4,5),'little'));m.wf(rbp-0x48,6)
 elif mode=='set':start=0x140765920;u.reg_write(UC_X86_REG_RDX,c['newTarget']);u.reg_write(UC_X86_REG_R8,c['newDelay']);u.reg_write(UC_X86_REG_R9,c['newDuration'])
 elif mode=='delete':start=0x1407fc56c;u.reg_write(UC_X86_REG_RSI,dummy)
 else:start=0x140762e40
 try:u.emu_start(start,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 rip=u.reg_read(UC_X86_REG_RIP);assert rip in [m.stop,0x1407acc54,0x1407ae7fd,0x1407fc5d2,0x1407fc730]
 return dict(case=c,calls=calls,state=state(),result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,targetId=ui(rsp+0x48)if mode=='create'else None,aborted=rip==0x1407ae7fd)
rows=[run(dict(modeName='create',targetId=id,allocateFailure=alloc,load=loaded,player=hasPlayer,area=hasArea,register=status,handle=hasHandle,travel=travel))for id,alloc,loaded,hasPlayer,hasArea,status,hasHandle,travel in itertools.product([0x80000063,0x7f000000],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,500,0xffffff00])]
rows +=[run(dict(modeName='set',objectId=7,temporary=temp,blocked=blocked,newTarget=target,newDelay=delay,newDuration=duration,handle=hasHandle,mode=mode,controlled=controlled))for temp,blocked,target,delay,duration,hasHandle,mode,controlled in itertools.product([0,1,2],[0,1],[0,1,2],[0,1],[0,500],[0,1],[0,1,2],[7,8])]
rows +=[run(dict(modeName='expiry',fade=fade,target=target,delay=delay,duration=duration,elapsed=elapsed,elapsedDay=day,handle=hasHandle,alpha=alpha,targetAlpha=targetAlpha,microseconds=microseconds))for fade,target,delay,duration,elapsed,day,hasHandle,alpha,targetAlpha,microseconds in itertools.product([0,1,2,3],[0,1,2],[0,1],[0,500],[0,499,500,501],[0,1],[0,1],[0,.5,1],[.5,1],[0,16000])if not(hasHandle==0 and target==0 and fade!=0 and delay!=0 and alpha<=targetAlpha)]
rows +=[run(dict(modeName='delete',fade=1,target=1,delay=1,duration=500,elapsed=elapsed,deleteStatus=status,deleteObject=obj))for elapsed,status,obj in itertools.product([499,500,501],[0,1],[0,1])]
out=m.root/'backups/animations/native-client-dummy-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
