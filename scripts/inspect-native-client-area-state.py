"""Original SetAreaTransitionBMP1404be490 and last-update ClearAutoMapData
1404c2ac0. String copying/free are captured lower memory boundaries. Tests
stored state, not complete CNWSPlayer construction or control transfers.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);client,text,incoming,copy,old=[m.heap+i*0x1000 for i in range(5)]
def string(ptr,data,where):
 b=data.encode('ascii');u.mem_write(where,b+b'\0');m.wq(ptr,where);m.wi(ptr+8,len(b));m.wi(ptr+12,len(b)+1)
def read(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode('ascii') if m.q(ptr) else ''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('ascii'),copy);m.finish(x)
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1404be490,0x1404be4fc),(0x1404c2ac0,0x1404c2af5)]):raise RuntimeError(f'Unmapped client state dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(client+0x20,27);string(client+0x28,'custom',old);string(text,case.get('text',''),incoming);m.wi(client+0x178,case.get('area',88));m.wq(client+0x170,old if case.get('map',False) else 0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[client,case.get('index',0)&0xffffffff,text]):u.reg_write(reg,value)
 u.emu_start(0x1404be490 if case['operation']=='bmp' else 0x1404c2ac0,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,bmp=m.si(client+0x20),user=read(client+0x28),area=m.si(client+0x178)&0xffffffff,map=bool(m.q(client+0x170)))
rows=[run(dict(operation='bmp',index=index,text=text))for index,text in itertools.product([-2147483648,-1,0,1,2,2147483647,4294967297],['','picture','MiXeD','a\0bc'])]
rows += [run(dict(operation='clear',map=hasMap,area=area))for hasMap,area in itertools.product([False,True],[0,88,0x80000001,0xffffffff])]
out=m.root/'backups/animations/native-client-area-state-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
