"""Complete GetIsAreaAboveGround1405269d0 and GetIsAreaInterior140526a50.
VM object transfer, canonical area lookup and integer push are captured lower
boundaries. Original raw-byte tests/defaults/failure returns execute unchanged.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);areaPtr,appPtr=m.heap+0x1000,m.heap+0x2000
def hook(u,a,n,_):
 global output,lookups
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x140286160:m.wi(y,0x12345678);m.finish(c['pop']);return
 if a==0x14055b2e0:lookups.append(y&0xffffffff);m.finish(areaPtr if c['exists']else 0);return
 if a==0x140286410:output=y&0xffffffff;m.finish(c['push']);return
 if not(0x1405269d0<=a<0x140526a44 or 0x140526a50<=a<0x140526acd):raise RuntimeError(f'Uncaptured area-query owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output,lookups
 c=case;output=None;lookups=[];m.wi(areaPtr+8,c['flags']);m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x80,bytes(0x100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.emu_start(0x1405269d0 if c['mode']=='above'else 0x140526a50,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,output=output,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,lookups=lookups)
if __name__=='__main__':
 rows=[run(dict(mode=mode,flags=flags,exists=exists,pop=pop,push=push))for mode,flags,exists,pop,push in itertools.product(['above','interior'],list(range(256))+[0x100,0x102,0x80000000,0xffffffff],[False,True],[0,1],[0,1])]
 output=m.root/'backups/animations/native-spell-area-queries-observations.json';output.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(output))))
