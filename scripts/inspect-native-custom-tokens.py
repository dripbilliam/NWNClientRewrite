"""Complete original custom-token table setter, script wrapper and message
coordinator; original InitFromCharArray executes. Vector construction/destruction,
allocation/free/memcpy, VM transfers, player lookup, scalar message writers and
transport are captured lowers. Not a whole client receiver/ParseStr/network oracle.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
table,inputString,inputBytes,app,players,array,client0,client1,oldArray,payload=[m.heap+i*0x1000 for i in range(1,11)]
ranges=[(0x14019a5d0,0x14019a7f1),(0x140540570,0x1405406a2),(0x1404df990,0x1404dfa60),(0x14003d8c0,0x14003d9ab)]
def alloc(size):
 global cursor
 assert size<0x10000;ptr=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xf0000;u.mem_write(ptr,bytes(size));return ptr
def raw(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).hex()if m.q(ptr)else''
def set_string(ptr,value):
 p=alloc(len(value)+1);u.mem_write(p,value+b'\0');m.wq(ptr,p if value else 0);m.wi(ptr+8,len(value));m.wi(ptr+12,len(value)+1)
def records():
 ptr=m.q(table+0x40);return[dict(id=m.si(ptr+i*24),value=raw(ptr+i*24+8))for i in range(m.si(table+0x48))]
def hook(u,a,n,_):
 global calls
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10368:m.finish(alloc(x));return
 if a in[0x140c10370,0x140c10528,0x140c10434]:m.finish();return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if a==0x140286110:m.wi(y,c['id']);m.finish(c['popInt']);return
 if a==0x1402861b0:set_string(y,bytes.fromhex(c['value']));m.finish(c['popString']);return
 if a==0x14055b810:m.finish(app);return
 if a==0x14055b8e0:m.finish(players);return
 if a==0x1404ba840:m.finish(0 if c['missingViewer']and x==client1 else app);return
 if a==0x1404df990 and c['mode']=='script':calls.append(['send',y&0xffffffff,z&0xffffffff,raw(w)]);m.finish(c['sendResult']);return
 if a==0x1402d54a0:calls.append(['create',y&0xffffffff,z&0xffffffff,w&0xffffffff]);m.finish();return
 if a==0x1402db5a0:calls.append(['int',y&0xffffffff,z&0xffffffff]);m.finish();return
 if a==0x1402dab50:calls.append(['string',raw(y),z&0xffffffff]);m.wq(y,0);m.wq(y+8,0);m.finish();return
 if a==0x1402d5880:m.wq(y,payload);m.wi(z,23);m.finish(c['payloadStatus']);return
 if a==0x1404dc490:calls.append(['transport',y&0xffffffff,z&255,w&255,m.si(rsp+0x30)]);m.finish(c['sendResult']);return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured custom-token owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,calls
 c=case;cursor=0x30000;calls=[];u.mem_write(m.heap,bytes(0x20000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df968,table);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(table+0x40,oldArray if c['initial']else 0);m.wi(table+0x48,len(c['initial']));m.wq(oldArray-8,len(c['initial']))
 for i,id in enumerate(c['initial']):m.wi(oldArray+i*24,id);set_string(oldArray+i*24+8,f't{id}'.encode())
 set_string(inputString,bytes.fromhex(c['value']));m.wq(players,array);m.wi(players+8,c['count']);m.wq(array,client0);m.wq(array+8,client1);m.wi(client0+0x48,100);m.wi(client1+0x48,101)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 regs=[table,c['id'],inputString,0]if c['mode']=='table'else[app,100,c['id'],inputString]if c['mode']=='packet'else[app,284,2,0]
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,v&0xffffffffffffffff)
 u.emu_start({'table':0x14019a5d0,'script':0x140540570,'packet':0x1404df990}[c['mode']],m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,records=records(),calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
if __name__=='__main__':
 d=dict(mode='table',id=10,value='76616c7565',initial=[],count=2,missingViewer=False,popInt=1,popString=1,payloadStatus=1,sendResult=1)
 rows=[run(d|dict(id=id,value=value,initial=initial))for id,value,initial in itertools.product([-1,0,9,10,11,50,99,0x7fffffff,-0x80000000],['','76616c7565','006c656164','610062','80e9'],[[],[10],[10,50,99]])]
 rows +=[run(d|dict(mode='script',id=id,value=value,count=count,missingViewer=missing,popInt=pi,popString=ps,sendResult=result,initial=[10,50]))for id,value,count,missing,pi,ps,result in itertools.product([-1,0,9,10,50,0x7fffffff],['','76616c7565','006c656164','610062'],[0,2],[False,True],[0,1],[0,1],[0,1])]
 rows +=[run(d|dict(mode='packet',id=id,value=value,payloadStatus=status,sendResult=result))for id,value,status,result in itertools.product([-1,10,0x7fffffff],['','76616c7565','006c656164','610062'],[0,1],[0,1,2])]
 target=m.root/'backups/animations/native-custom-token-observations.json';target.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(target),rows=len(rows))))
