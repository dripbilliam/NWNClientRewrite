"""Unchanged MoveToPoint forced-payload branch1403c4071..1403c4134 and
creature event18 block14038f22d..14038f440. Capture time conversion, AI event,
CancelAction, action allocation/parameter storage, jump execution and disposal.
This does not prove the captured jump/transport/VM/geometry owners.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,app,server,payload,node,clock,queued=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
 if a in [m.stop,0x1403c4134,0x14038f440]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:m.finish(payload if x==0x1c else queued)
 elif a==0x14055ba10:m.finish(clock)
 elif a in [0x140597140,0x140597010]:calls.append(['time' if a==0x140597140 else 'day',m.xmm(UC_X86_REG_XMM1)]);m.finish(c['time'] if a==0x140597140 else c['day'])
 elif a==0x14055b960:m.finish(server)
 elif a==0x1405570b0:
  point=[m.rf(payload+0xc),m.rf(payload+0x10),m.rf(payload+0x14)]
  calls.append(['event',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),dict(type=m.si(payload),group=int.from_bytes(u.mem_read(payload+4,2),'little'),areaId=m.si(payload+8)&0xffffffff,position=point,targetId=m.si(payload+0x18)&0xffffffff)]);m.finish(1)
 elif a==0x140386700:calls.append(['cancel',y&65535,z&65535]);m.finish(c.get('cancel',0))
 elif a==0x14048bcf0:u.mem_write(x,bytes(0xa0));m.wi(x+0x9c,1);m.finish(x)
 elif a==0x14048d2c0:
  kind=w&0xffffffff;raw=m.si(m.q(rsp+0x28));params.append([kind,raw]);m.finish(1)
 elif a in [0x1403c2a90,0x1403c1a60]:calls.append(['jumpPoint' if a==0x1403c2a90 else 'jumpObject',m.si(y),int.from_bytes(u.mem_read(y+0x98,2),'little'),list(params)]);m.finish(2)
 elif a in [0x14048c470,0x140c10360]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403c4071,0x1403c4134),(0x140441b10,0x140441b40),(0x140441b40,0x140441b41),(0x14038f22d,0x14038f440)]):raise AssertionError(f'Uncaptured forced movement dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,params
 c=case;calls=[];params=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wi(actor+8,99)
 rsp=m.stack+0x1f508;u.mem_write(rsp-0x500,bytes(0xa00));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);frame=rsp+0x200
 m.wi(payload,c.get('type',1));u.mem_write(payload+4,struct.pack('<H',c['group']&65535));m.wi(payload+8,88);m.wi(payload+0x18,c['target'])
 for i,v in enumerate([1,2,3]):m.wf(payload+0xc+i*4,v)
 u.reg_write(UC_X86_REG_RBP,frame)
 if c['operation']=='queue':
  u.mem_write(node+0x98,struct.pack('<H',c['group']&65535));m.wi(rsp+0x70,88)
  for i,v in enumerate([1,2,3]):m.wf(frame+0x18+i*4,v)
  for reg,v in [(UC_X86_REG_R13,node),(UC_X86_REG_R14,actor),(UC_X86_REG_R12,c['target']),(UC_X86_REG_R15,0)]:u.reg_write(reg,v)
  u.reg_write(UC_X86_REG_XMM11,int.from_bytes(struct.pack('<f',c['seconds']),'little'));address=0x1403c4071
 else:
  for reg,v in [(UC_X86_REG_RSI,actor),(UC_X86_REG_R14,payload),(UC_X86_REG_R12,1),(UC_X86_REG_RDI,0)]:u.reg_write(reg,v)
  address=0x14038f22d
 u.emu_start(address,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP) in [0x1403c4134,0x14038f440]
 return dict(case=c,calls=calls)
rows=[run(dict(operation='queue',group=group,target=target,seconds=seconds,day=day,time=time)) for group,target,seconds,day,time in itertools.product([0,17,65535],[100,0x7f000000],[.125,15],[0,1],[0,12345])]
rows += [run(dict(operation='receive',group=group,target=target,type=type,cancel=cancel)) for group,target,type,cancel in itertools.product([0,17,65535],[100,0x7f000000],[0,1,2],[0,1,2])]
out=m.root/'backups/animations/native-forced-movement-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
