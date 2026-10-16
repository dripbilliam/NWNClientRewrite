"""Complete client receiver1407857f0..14078644b, valid decoded streams,
protocol transform-map extension disabled, profiling disabled. Message reads,
active Type_FD strings, canonical lookups, view18 and AddVisual178 captured.
Dummy allocator deliberately fails (no client ID fabricated). Empty map/string
allocation/copy/free are providers. Not malformed-packet/version/scene proof.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
message,manager,app,rules,table,target,source,vt,head=[m.heap+n*0x1000 for n in range(1,10)]
def readv(ptr):return[m.rf(ptr+i*4)for i in range(3)]
def hook(u,a,n,_):
 global allocation,objectReads,floatReads,byteReads
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140368530:m.finish(head)
 elif a in [0x140c10370,0x14011b210,0x140369860]:m.finish()
 elif a==0x140c10368:
  ptr=m.heap+0x80000+allocation*0x400;allocation+=1;m.finish(ptr)
 elif a==0x1409737c0:
  value=[c['targetId'],c['sourceId']][objectReads];objectReads+=1;m.finish(value)
 elif a==0x1402da450:m.finish(c['visualId']&65535)
 elif a in [0x1402d9460,0x1402d9520,0x1407c4ab0]:m.finish(0)
 elif a==0x1402d9c30:
  value=([1.25,-2,3.5]+[7,8,9]+[c['duration']])[floatReads];floatReads+=1;u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
 elif a==0x1402d9630:value=[17,250][byteReads];byteReads+=1;m.finish(value)
 elif a==0x1401a68f0:
  value=c['kind'].encode()+b'\0';ptr=m.heap+0x90000;u.mem_write(ptr,value);m.wq(w,ptr);m.wi(w+8,len(value)-1);m.finish(1)
 elif a==0x1406abb60:
  ident=y&0xffffffff;calls.append(['object',ident]);m.finish(target if ident==123 else source if ident==789 else 0)
 elif a==0x1403591a0:m.wq(x,head);m.wq(x+8,0);m.finish(x)
 elif a==0x140c10324:
  assert x==0x480;caller=m.q(rsp);calls.append(['dummy',{0x140785b1b:'point',0x140785ee7:'source',0x1407860b9:'target'}[caller]]);m.finish(0)
 elif a==m.stop+0x10:m.finish(x)
 elif a==m.stop+0x20:
  calls.append(['add',m.si(x+8),y&65535,w&0xffffffff,z&0xffffffff,m.si(rsp+0x28)&255,m.si(rsp+0x30)&255,readv(m.q(rsp+0x38))]);m.finish(c['addResult'])
 elif not(0x1407857f0<=a<0x14078644b):raise RuntimeError(f'Unexpected visual receiver dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,objectReads,floatReads,byteReads
 c=case;calls=[];allocation=objectReads=floatReads=byteReads=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,app);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x280,table)
 for ptr,ident,kind in [(target,123,c['targetType']),(source,789,5)]:m.wq(ptr,vt);m.wi(ptr+8,ident);u.mem_write(ptr+0xc,bytes([kind]))
 m.wq(vt+0x18,m.stop+0x10);m.wq(vt+0x178,m.stop+0x20)
 for off in [0,8,16]:m.wq(head+off,head)
 u.mem_write(head+0x19,b'\1');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,message)
 try:u.emu_start(0x1407857f0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[run(dict(kind=kind,visualId=visualId,targetId=targetId,sourceId=sourceId,targetType=targetType,addResult=addResult,duration=2.5))for kind,visualId,targetId,sourceId,targetType,addResult in itertools.product(['F','D','P','B','p','PB','','P\0tail'],[1,999,65537],[123,456,0x7f000000],[789,123,0x7f000000],[5,6],[0,1])]
out=m.root/'backups/animations/native-object-visual-delivery-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
