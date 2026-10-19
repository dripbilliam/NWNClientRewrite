"""Complete GetImmortal/SetImmortal original wrappers and both bounded
ReadStatsFromGff immortality blocks, including the complete native Boolean and
BYTE field readers. VM transfers, creature lookup and GFF field lookup/descriptor
access are captured boundaries. This does not execute the whole stats loader,
damage engine or GFF parser, nor establish save/export behavior.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,app,resource,root,field=[m.heap+n*0x1000 for n in range(1,7)]
ranges=[(0x140525f40,0x140525fb7),(0x140541fa0,0x140542002),(0x14040ff21,0x14040ff47),(0x1404100da,0x140410100),(0x1401a0f60,0x1401a0f80),(0x1401a0ee0,0x1401a0f54)]
ends={0x14040ff47,0x140410100}
def hook(u,a,n,_):
 global output,calls
 if a==m.stop or a in ends:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140286160:calls.append('popObject');m.wi(y,0x12345678);m.finish(c['objectPop']);return
 if a==0x140286110:calls.append('popInt');m.wi(y,c['value']);m.finish(c['intPop']);return
 if a==0x14055b3d0:assert y==0x12345678;calls.append('lookup');m.finish(actor if c['creature']else 0);return
 if a==0x140286410:output=y&0xffffffff;calls.append('push');m.finish(c['push']);return
 if a==0x14019fcc0:
  assert bytes(u.mem_read(z,11))==b'IsImmortal\0';calls.append('fieldByLabel');m.finish(7);return
 if a==0x14019fc20:assert z==7;calls.append('fieldDescriptor');m.finish(field if c['present']else 0);return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured immortality owner{a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,output,calls
 c=case;output=None;calls=[];m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(stats+0x30,actor);m.wi(actor+0x8b8,c['initial']);m.wi(field,c.get('fieldType',0));m.wi(field+8,c['value'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x180,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.reg_write(UC_X86_REG_R14,stats);u.reg_write(UC_X86_REG_R12,root);u.reg_write(UC_X86_REG_RSI,resource)
 start={'get':0x140525f40,'set':0x140541fa0,'loadA':0x14040ff21,'loadB':0x1404100da}[c['command']]
 u.emu_start(start,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop or u.reg_read(UC_X86_REG_RIP)in ends
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,stored=m.si(actor+0x8b8),calls=calls)
if __name__=='__main__':
 default=dict(initial=-123,value=0,objectPop=1,intPop=1,push=1,creature=True,present=True,fieldType=0)
 rows=[run(default|dict(command=command,initial=value,value=value,creature=creature,objectPop=op,intPop=ip,push=push))for command,value,creature,op,ip,push in itertools.product(['get','set'],[0,1,2,-1,255,256,0x7fffffff,-0x80000000],[False,True],[0,1],[0,1],[0,1])]
 rows += [run(default|dict(command=command,value=value,present=present,fieldType=fieldType))for command,value,present,fieldType in itertools.product(['loadA','loadB'],[0,1,2,127,255,256,-1],[False,True],[0,1,4,5])]
 out=m.root/'backups/animations/native-creature-immortality-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
