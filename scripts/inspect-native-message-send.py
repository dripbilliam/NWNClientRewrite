"""Complete unchanged SendServerToPlayerMessage coordinator with profiling
disabled. Capture name lookup/logging, server net accessor, transport and
malloc/free lower boundaries. No real packets are sent or processes altered.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,app,server,vtable,net,packet,temp,name=[m.heap+i*0x1000 for i in range(8)]
accessor=m.stop+0x200

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,t=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402d5e60:trace.append(['name',x&255,y&255]);m.finish(name)
 elif a==0x140115890:
  rolePtr=m.q(rsp+0x38);role=bytes(u.mem_read(rolePtr,6)).split(b'\0')[0].decode()
  trace.append(['log',role,m.si(rsp+0x40)&0xffffffff,m.q(rsp+0x48)==name,m.si(rsp+0x50)&0xffffffff]);m.finish(99)
 elif a==0x140c10368:trace.append(['allocate',x]);m.finish(0 if case['allocationFails'] else temp)
 elif a==0x140c10370:trace.append(['free',x==temp]);m.finish(0x76543210)
 elif a==accessor:trace.append(['netLayer',x==server]);m.finish(net)
 elif a==0x140237b30:
  trace.append(['send',x==net,y&0xffffffff,bytes(u.mem_read(z,t)).hex(),t,m.si(rsp+0x28)]);m.finish(case['sendReturn'])
 elif not 0x1404dc490<=a<0x1404dcb46:raise RuntimeError(f'Unmapped send dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(c):
 global trace,case
 case=c;trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 u.mem_write(0x14141e310,bytes(16));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server,vtable);m.wq(vtable+0x38,accessor)
 m.wi(message+0x64,123);m.wi(message+0x68,c['role']);u.mem_write(packet,bytes([0xa5])*16);u.mem_write(temp,bytes([0xa5])*3);u.mem_write(name,b'fixture\0')
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,0 if c['nullData'] else packet);m.wi(rsp+0x30,c['length']);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[message,c['playerId'],c['major'],c['minor']]):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(0x1404dc490,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(case=c,result=result if result<1<<31 else result-(1<<32),trace=trace,playerId64=m.si(message+0x64)&0xffffffff,packet=bytes(u.mem_read(packet,16)).hex())

if __name__=='__main__':
 rows=[]
 for role,length,nullData,allocationFails,sendReturn in itertools.product([0,1,-1],[0,1,2,3,16],[False,True],[False,True],[0,1,-1,0x7fffffff]):
  rows.append(run(dict(role=role,length=length,nullData=nullData,allocationFails=allocationFails,sendReturn=sendReturn,playerId=0x80000001,major=0x104,minor=0x201)))
 out=m.root/'backups/animations/native-message-send-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
