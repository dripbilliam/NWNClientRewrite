"""Complete GetHasSkill140525700..1405257d3 with captured VM, object-array,
AsCreature virtual and existing GetCanUseSkill lower boundaries. Checks BYTE
narrowing, repeated cast, exact return1 and failure/call ordering, not lower
skill/class-rule correctness (covered by its existing separate native tests).
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);creaturePtr,objectPtr,appPtr,tablePtr,statsPtr=[m.heap+n*0x1000 for n in range(1,6)];castCall=m.stop+0x80
def hook(u,a,n,_):
 global output,calls
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140286110:m.wi(y,c['skill']);m.finish(c['intPop']);return
 if a==0x140286160:m.wi(y,0x12345678);m.finish(c['objectPop']);return
 if a==0x14055b850:m.finish(appPtr);return
 if a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,objectPtr);m.finish(c['status']);return
 if a==castCall:calls.append(['asCreature']);m.finish(creaturePtr if c['creature']else 0);return
 if a==0x1403fa1d0:assert x==statsPtr;calls.append(['canUse',y&0xffffffff]);m.finish(c['canUse']);return
 if a==0x140286410:output=y&0xffffffff;m.finish(c['push']);return
 if not 0x140525700<=a<0x1405257d4:raise RuntimeError(f'Uncaptured GetHasSkill owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output,calls
 c=case;output=None;calls=[];m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(objectPtr,tablePtr);m.wq(tablePtr+0x60,castCall);m.wq(creaturePtr+0xad0,statsPtr);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x180));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.emu_start(0x140525700,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,calls=calls)
if __name__=='__main__':
 rows=[run(dict(skill=skill,status=status,creature=creature,canUse=canUse,intPop=intPop,objectPop=objectPop,push=push))for skill,status,creature,canUse,intPop,objectPop,push in itertools.product([-257,-1,0,1,27,100,101,102,255,256,257,0x7fffffff],[0,1,255,256],[False,True],[0,1,2,-1],[0,1],[0,1],[0,1])]
 output=m.root/'backups/animations/native-script-has-skill-observations.json';output.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(output),rows=len(rows))))
