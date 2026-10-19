"""Original LoadBaseItems PropColumn14029f670..14029f716 and RangedWeapon
14029ec06..14029ecbb blocks, plus damage ammunition lookup3942d8..39430d.
The unchanged code builds its column name, executes lookup and stores low BYTE.
Heap/free and C2DA lookup status/output are captured. Not full loader parity.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);array,record,string,table,weapon,ammo,base,actor,rules=[m.heap+n*0x1000 for n in range(9)]
def hook(u,a,n,_):
 if a in [0x14029f717,0x14029ecbc,0x14039430e]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10370:m.finish()
 elif a==0x140c10368:assert x in [11,13];m.finish(string)
 elif a==0x1401a7010:
  name=bytes(u.mem_read(m.q(z),13)).split(b'\0')[0].decode('ascii');calls.append(dict(row=y&0xffffffff,column=name));m.wi(w,c['value']);m.finish(c['status'])
 elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);m.finish(record if len(calls)==1 else base)
 elif a==0x140462bd0:calls.append(['equipped',y&0xffffffff]);m.finish(ammo)
 elif not any(lo<=a<hi for lo,hi in [(0x14029f670,0x14029f717),(0x14029ec06,0x14029ecbc),(0x1403942d8,0x14039430e)]):raise AssertionError(f'Unexpected base-column dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[];lookups=[]
for mode,value,status in itertools.product(['PropColumn','RangedWeapon'],[-2147483648,-257,-256,-1,0,1,6,21,255,256,257,2147483647],[0,1]):
 c=dict(mode=mode,value=value,status=status);calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(array+8,record)
 for r,v in [(UC_X86_REG_RSP,m.stack+0x10000),(UC_X86_REG_RBP,m.stack+0x18000),(UC_X86_REG_RSI,array),(UC_X86_REG_R14,0),(UC_X86_REG_R13,0),(UC_X86_REG_R12,table),(UC_X86_REG_R15,7)]:u.reg_write(r,v)
 start,stop,offset=(0x14029f670,0x14029f717,0x32) if mode=='PropColumn' else (0x14029ec06,0x14029ecbc,0x18)
 u.emu_start(start,stop,count=200);assert u.reg_read(UC_X86_REG_RIP)==stop;rows.append(dict(case=c,byte=bytes(u.mem_read(record+offset,1))[0],calls=calls))
for ranged,slot in itertools.product([0,20,25,27,255,256,281],[0,16,2048,4096,8192,3072]):
 c=dict(ranged=ranged,slot=slot);calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(weapon+0x40,7);u.mem_write(record+0x18,bytes([ranged&255]));m.wi(base+4,slot);m.wq(0x1412df8f8,rules);m.wq(rules+0x20,rules)
 u.reg_write(UC_X86_REG_RAX,weapon);u.reg_write(UC_X86_REG_R14,actor);u.reg_write(UC_X86_REG_RSP,m.stack+0x10000);u.emu_start(0x1403942d8,0x14039430e,count=60);assert u.reg_read(UC_X86_REG_RIP)==0x14039430e;lookups.append(dict(case=c,calls=calls))
out=m.root/'backups/animations/native-base-property-column-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,lookups=lookups),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),lookups=len(lookups),output=str(out))))
