"""Original bounded ApplyEffect expiry block48e68b..48e739, common effect
expiry comparison49e04a..49e0b8, full native seconds conversions, world-time
add/compare and expiry setter/getter. World timer lookup and removal dispatch
are captured boundaries. Captured pre-handler time is an explicit input;
complete ApplyEffect admission/retention/AI callbacks and UpdateEffectList
periodic branches are not executed here. No Time Stop/campaign/wire claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
effect,timer,app,actor=[m.heap+n*0x1000 for n in range(4)];frame=m.stack+0x1f500;sp=m.stack+0x1f000
ranges=[(0x14048e68b,0x14048e73a),(0x14049e04a,0x14049e0bd),(0x140597010,0x14059703e),(0x140597140,0x14059717a),(0x140596b40,0x140596bc9),(0x140596e50,0x140596e90),(0x1404251f0,0x1404251f8),(0x140423fa0,0x140423fb1)]
def hook(u,a,n,_):
 if a in [0x14048e73a,0x14049e7ca,0x14049e7d3,0x14049e7d6]:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14055ba10:m.finish(timer)
 elif a==0x140498280:calls.append(['remove',f'{y:016x}']);m.finish(1)
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unknown effect clock dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(effect,123);u.mem_write(effect+10,struct.pack('<H',c['kind']&65535));m.wf(effect+12,c.get('duration',0));m.wi(effect+16,c['expiry'][0]);m.wi(effect+20,c['expiry'][1]);m.wi(timer+0x30,c['length']);m.wi(timer+0x34,c['length']//1000)
 u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RBP,frame)
 if c['mode']=='initialize':
  u.reg_write(UC_X86_REG_RSI,effect);u.reg_write(UC_X86_REG_R15,c.get('loading',0));m.wi(sp+0x88,c['now'][0]);m.wi(sp+0x80,c['now'][1]);start=0x14048e68b
 else:
  u.reg_write(UC_X86_REG_R14,0 if c.get('null')else effect);u.reg_write(UC_X86_REG_R15,actor);u.reg_write(UC_X86_REG_RDI,c['now'][1]);m.wi(sp+0x6c,c['now'][0]);m.wq(frame-0x60,timer);start=0x14049e04a
 try:u.emu_start(start,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(case=c,calls=calls,expiry=[m.si(effect+16)&0xffffffff,m.si(effect+20)&0xffffffff])
cases=[dict(mode='initialize',kind=kind,loading=loading,duration=duration,now=now,expiry=[77,88],length=length)for kind,loading,duration,now,length in itertools.product([0,1,2,3,4,9],[0,1,2],[-1,0,0.0009,0.001,0.2999,0.5,1.234,2,5,7200.5],[[0,0],[7,999],[0xffffffff,0]],[1000,7200000])]
cases += [dict(mode='expired',kind=kind,now=now,expiry=expiry,length=1000,null=null)for kind,now,expiry,null in itertools.product([0,1,2,9],[[0,0],[1,0],[1,299],[1,300],[1,301],[1,1000],[0xffffffff,999]],[[0,0],[1,0],[1,300],[1,1000],[0xffffffff,999]],[False,True])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-effect-clock-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),initialize=sum(r['case']['mode']=='initialize'for r in rows),expired=sum(r['case']['mode']=='expired'for r in rows))))
