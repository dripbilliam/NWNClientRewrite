"""Complete original PersonalReputationAccess537e50. VM scalar pops and lower
creature lookup/clear/add are captured; pop order, defaults, context/arity gates,
repeated clears and the neutral command's two insertions execute unchanged.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);commands,app,actor=[m.heap+n*0x2000 for n in range(3)]
def hook(u,a,n,_):
 global pops
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140286160,0x140286110,0x1402860c0]:
  pops+=1;kind={0x140286160:'object',0x140286110:'int',0x1402860c0:'float'}[a];calls.append(['pop',kind]);value=[99,98,c.get('decays',0),c.get('duration',180)][pops-1]
  if kind=='float':m.wf(y,value)
  else:m.wi(y,value)
  m.finish(0 if c.get('failPop')==pops else 1)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('exists',True) else 0)
 elif a==0x1403d3680:calls.append(['clear',y&0xffffffff]);m.finish()
 elif a==0x1403d0c50:calls.append(['add',y&0xffffffff,(z&0xffffffff^0x80000000)-0x80000000,(w&0xffffffff^0x80000000)-0x80000000,m.rf(rsp+0x28)]);m.finish()
 elif not 0x140537e50<=a<0x140537fe6:raise RuntimeError(f'Unexpected personal reputation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,pops
 c=case;calls=[];pops=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,app);m.wi(commands+8,c['context']);m.wi(commands+12,97)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[commands,c['ordinal'],c['argc']]):u.reg_write(r,v)
 u.emu_start(0x140537e50,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;return dict(case=c,calls=calls,result=(result^0x80000000)-0x80000000)
rows=[]
for ordinal,argc,context,exists,decays,duration in itertools.product([390,391,392,393],range(1,5),[0,1,2],[False,True],[-1,0,1],[-3.25,180.5]):rows.append(run(dict(ordinal=ordinal,argc=argc,context=context,exists=exists,decays=decays,duration=duration)))
for fail in range(1,5):rows.append(run(dict(ordinal=392,argc=4,context=1,failPop=fail)))
out=m.root/'backups/animations/native-personal-reputation-command-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
