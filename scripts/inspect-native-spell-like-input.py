"""Original full input-message owner dispatched to subtype35 and full
spell talent wrappers140380fb0/140380e20 (kind0, no item). Packet primitives,
client/object registry, area, feedback and AddCastSpellActions are captured.
Native packet return remains0; queue existence and spell effects are separate.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,client,object,actor,stats,target,area,spell,rules,manager,vt=[m.heap+n*0x1000 for n in range(1,12)]
ranges=[(0x1404531b0,0x140455858),(0x140380fb0,0x140381205),(0x140380e20,0x140380fae)]
def hook(u,a,n,_):
 global byte,axis,overflow,wordsRead
 if a in [m.stop,0x140453780]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404ba840:m.finish(object if c['actor'] else 0)
 elif a==m.stop+0x10:m.finish(actor)
 elif a==0x1402d9460:overflow+=1;m.finish(int(c['overflow']==overflow))
 elif a==0x1402d9520:m.finish(c['underflow'])
 elif a==0x1402d9bc0:m.finish(c['spellId'])
 elif a==0x1402d9630:byte+=1;m.finish(c['casterLevel'] if byte==1 else c['flags'])
 elif a==0x1402da450:wordsRead+=1;m.finish(c.get('featId',257) if wordsRead==1 else c.get('auxiliary',0))
 elif a==0x140476130:m.finish(c['targetId'])
 elif a==0x1402d9c30:
  u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',[1.25,2.5,3.75][axis]))[0]);axis+=1;m.finish()
 elif a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(0 if c['missingSpell'] else spell)
 elif a==0x14037cbc0:calls.append(['manager',y&0xffffffff]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);m.finish()
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(target if c['targetCreature'] else 0)
 elif a==0x140494e80:calls.append(['area']);m.finish(area if c['area'] else 0)
 elif a==0x1403a91d0:
  ptr=m.q(rsp+0x30);calls.append(['feat',y&65535,z&65535,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,[m.rf(ptr+i*4) for i in range(3)]]);m.finish(c['addResult'])
 elif a==0x14037d540:
  calls.append(['cast',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255,m.si(rsp+0x30),[m.rf(m.q(rsp+0x38)+i*4) for i in range(3)],m.si(rsp+0x40)&0xffffffff,*[m.si(rsp+off) for off in [0x48,0x50,0x58,0x60,0x68,0x70,0x78]],m.si(rsp+0x80)&255]);m.finish(c['addResult'])
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured spell-like input dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
default=dict(actor=True,stats=True,field8ac=0,commandable=1,flags=1,casterLevel=7,spellId=100,targetId=101,targetCreature=True,area=True,missingSpell=False,overflow=0,underflow=0,addResult=1)
def run(case,wrapper=None):
 global c,calls,byte,axis,overflow,wordsRead
 c=default|case;calls=[];byte=axis=overflow=wordsRead=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager+8,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);u.mem_write(0x14141e310,b'\0')
 m.wq(object,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats if c['stats'] else 0);m.wi(actor+0x8ac,c['field8ac']);m.wi(actor+0xec,c['commandable']);m.wi(area+0x140,7)
 for i,v in enumerate([4.25,5.5,6.75]):m.wf(target+0xa4+i*4,v)
 rsp=m.stack+0x1fc08;u.mem_write(rsp-0x500,bytes(0x800));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if wrapper:
  for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,0,c['spellId'],target if wrapper=='location' else c['targetId']]):u.reg_write(reg,v)
  if wrapper=='location':
   for i,v in enumerate([1.25,2.5,3.75]):m.wf(target+i*4,v)
  for offset,value in [(0x28,254),(0x30,0x7f000000),(0x38,-1),(0x40,c['casterLevel']),(0x48,0)]:m.wi(rsp+offset,value)
  start=0x140380e20 if wrapper=='location' else 0x140380fb0
 else:
  for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[message,client,c.get('subtype',35)]):u.reg_write(reg,v)
  start=0x1404531b0
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x140453780]
 return dict(case=c,calls=calls,**(dict(wrapper=wrapper,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff) if wrapper else {}))
rows=[run(dict(flags=flags,casterLevel=level,targetId=id,targetCreature=creature,commandable=commandable,addResult=result)) for flags,level,id,creature,commandable,result in itertools.product([0,1,2,3,255],[0,7,15,255],[101,0x7f000000],[False,True],[0,1,-1],[0,1])]
rows += [run(c) for c in [dict(actor=False),dict(stats=False),dict(field8ac=1),dict(missingSpell=True),dict(overflow=1),dict(overflow=2),dict(underflow=1),dict(area=False),dict(spellId=0xffffffff)]]
wrappers=[run(dict(casterLevel=level,targetCreature=creature,commandable=commandable,area=area,addResult=result),wrapper=kind) for kind,level,creature,commandable,area,result in itertools.product(['object','location'],[0,7,255],[False,True],[0,1,-1],[False,True],[0,1])]
featRows=[run(dict(subtype=6,featId=id,auxiliary=aux,targetId=target,actor=actor,field8ac=field,area=area,addResult=result)) for id,aux,target,actor,field,area,result in itertools.product([0,257,65535,65536],[0,1004,65535],[101,0x7f000000],[False,True],[0,1],[False,True],[0,1])]
featRows += [run(dict(subtype=6,**c)) for c in [dict(overflow=1),dict(overflow=2),dict(underflow=1)]]
out=m.root/'backups/animations/native-spell-like-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,wrappers=wrappers,featRows=featRows))+'\n');print(json.dumps(dict(rows=len(rows),wrappers=len(wrappers),featRows=len(featRows),output=str(out))))
