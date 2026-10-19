"""Execute original BNK0/BNK2/BNK4 wrappers. Crypto provider, peer lookup,
send boundary and logging are captured; this is not an oracle for libhydrogen's
primitives. The independent installed-server probe exercises those primitives.
"""
import importlib,sys,json,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner=0x500000000;u.mem_map(owner,0x2900000)
holder,view,slot,block,body,crypto,net,internal=[m.heap+n*0x1000 for n in range(1,9)]
internal=owner+0x100000
ranges=[]
for name in ['network-bnk0','network-bnk2','network-bnk4']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140175860:m.finish(crypto if c['statePresent']else 0);return
 if a==0x1406755f0:
  calls.append(['crypto3']);u.mem_write(z,bytes(range(48)));u.mem_write(w,bytes(range(32)));m.finish(c['cryptoResult']);return
 if a==0x1406758e0:u.mem_write(x,bytes(y));calls.append(['zero',y]);m.finish();return
 if a==0x1402511f0:calls.append(['send',bytes(u.mem_read(z,w)).hex()]);m.finish(7);return
 if a==0x1402502f0:calls.append(['login']);m.finish(7);return
 if a==0x140115890:calls.append(['rejected']);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured key-exchange dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(crypto,bytes(0x10c))
 m.wq(holder,view);m.wq(view+0x18,slot);m.wq(slot,block);m.wq(block,body);m.wq(block+8,c['size'])
 u.mem_write(body,c['tag'].encode()+struct.pack('<I',c['incomingIdentity'])+bytes(100))
 m.wq(owner+0x58,net);m.wq(net+8,internal);m.wi(owner+0x48,0);m.wi(owner+0x28a55d8,0);m.wi(owner+0x28a56cc,0);m.wq(owner+0x28a56c4,0)
 m.wi(crypto+0x44,c['stage']);m.wi(crypto+0x108,c['identity']);u.mem_write(crypto,bytes([c['haveKeys']]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[owner,12,holder]):u.reg_write(r,v)
 try:u.emu_start({'BNK0':0x140241c30,'BNK2':0x140242320,'BNK4':0x140242c60}[c['tag']],m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,stage=m.si(crypto+0x44),identity=m.q(crypto+0x108)&0xffffffff,haveKeys=u.mem_read(crypto,1)[0],connectionError=m.si(owner+0x28a56cc))

base=dict(statePresent=True,stage=1,haveKeys=0,identity=0,incomingIdentity=0xfedcba98,cryptoResult=0)
cases=[]
for tag,size in [('BNK0',4),('BNK2',84),('BNK4',8)]:
 for stage in [0,1,2,3,4]:
  cases.append(base|dict(tag=tag,size=size,stage=stage,haveKeys=int(stage>=3)))
 for length in [0,3,size-1,size+1]:cases.append(base|dict(tag=tag,size=length,stage=3 if tag=='BNK4'else 1,haveKeys=int(tag=='BNK4')))
 cases.append(base|dict(tag=tag,size=size,statePresent=False))
cases.extend([base|dict(tag='BNK2',size=84,cryptoResult=-1),base|dict(tag='BNK4',size=8,stage=3,haveKeys=0),base|dict(tag='BNK4',size=8,stage=3,haveKeys=1,identity=42),base|dict(tag='BNK4',size=8,stage=3,haveKeys=1,incomingIdentity=0)])
out=m.root/'backups/animations/native-network-key-exchange-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
