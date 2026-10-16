"""Untouched damage-shield constructor, application and reflection owners.
Capture VM/resource/RNG/allocation/setter/ApplyEffect boundaries; original
clamps, gate/order, effect payload and live-array iteration execute unchanged.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,attackerAddress,stats,effect,ints,app,rules,tables,effectRows,vm=[m.heap+n*0x1000 for n in range(1,11)]
def snapshot(e):return dict(type=int.from_bytes(u.mem_read(e+8,2),'little'),durationType=int.from_bytes(u.mem_read(e+10,2),'little')&7,creatorId=m.si(e+0x18)&0xffffffff,integers=list(struct.unpack('<'+'i'*m.si(e+0x40),u.mem_read(m.q(e+0x48),m.si(e+0x40)*4))))
def hook(u,a,n,_):
 global allocation,output
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140286110:m.wi(y,args.pop(0));m.finish(1)
 elif a==0x140286330:output=snapshot(z);m.finish(1)
 elif a==0x1402a3c00:m.finish(c.get('highest',8191))
 elif a==0x1404953b0:m.finish(c.get('dead',0))
 elif a==0x140423fc0:m.finish(m.si(m.q(x+0x48)+(y&0xffffffff)*4))
 elif a in [0x140c10324,0x140c10368]:allocation+=1;m.finish(m.heap+0x30000+allocation*0x1000)
 elif a==0x1404233d0:
  u.mem_write(x,bytes(0x110));m.wq(x+0x48,x+0x200);m.wi(x+0x40,8);m.finish(x)
 elif a==0x140423570:
  u.mem_write(x,bytes(u.mem_read(y,0x110)));m.wq(x+0x48,x+0x200);u.mem_write(x+0x200,bytes(u.mem_read(m.q(y+0x48),m.si(y+0x40)*4)));m.finish(x)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a==0x140425210:m.wi(m.q(x+0x48)+(y&0xffffffff)*4,z);m.finish()
 elif a==0x140425230:m.wi(x+0x40,y);m.finish()
 elif a==0x1401a7010:
  name=bytes(u.mem_read(m.q(z),20)).split(b'\0')[0].decode();value={'NumDice':c.get('count',1),'Die':c.get('sides',6),'VisualEffectID':c.get('visual',101)}[name];calls.append(['entry',y&0xffffffff,name]);m.wi(w,value);m.finish(1)
 elif a==0x1402ad680:calls.append(['roll',y&255,z&255]);m.finish(c.get('roll',4))
 elif a==0x1402a3b60:m.finish((y&0xffffffff).bit_length()-1 if (y&0xffffffff)>1 else 0)
 elif a==0x14048e350:calls.append(['apply',100 if x==attackerAddress else 99,snapshot(y),z&0xffffffff]);m.finish(1)
 elif a in [0x140423770,0x140c10360,0x140c10370]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403e4c50,0x1403e503e),(0x140519760,0x1405198d2),(0x14042a4c0,0x14042a585)]):raise AssertionError(f'Uncaptured shield dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,args,calls,allocation,output
 c=case;args=[c.get('base',3),c.get('die',4),c.get('flags',256)];calls=[];allocation=0;output=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,vm);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x2f0,tables);m.wq(tables+0x3e0,tables);m.wq(actor+0xad0,stats);u.mem_write(stats+0xdb8,b'\0\0');m.wi(actor+8,99);m.wi(attackerAddress+8,100);m.wi(app+0xc,99);m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wi(effect+0x18,98);u.mem_write(effect+8,struct.pack('<HH',61,c.get('durationType',2)|8))
 for i,v in enumerate(args):m.wi(ints+i*4,v)
 m.wq(actor+0x150,effectRows);m.wi(actor+0x158,c.get('shields',1))
 for i in range(c.get('shields',1)):m.wq(effectRows+i*8,effect)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 regs={'construct':[app,144,3,0],'apply':[app,actor,effect,c.get('loading',0)],'resolve':[actor,attackerAddress if c.get('attacker',True) else 0,0,0]}[c['owner']]
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,v)
 u.emu_start({'construct':0x140519760,'apply':0x14042a4c0,'resolve':0x1403e4c50}[c['owner']],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,calls=calls)
rows=[]
for base,die,flags in itertools.product([-1,0,10000,10001],[0,1,255,256],[-1,0,1,3,256,8191,8192]):rows.append(run(dict(owner='construct',base=base,die=die,flags=flags)))
for loading,dead,duration in itertools.product([0,1],[0,1],range(5)):rows.append(run(dict(owner='apply',loading=loading,dead=dead,durationType=duration)))
for shields,attacker,count,sides,base,flags in itertools.product([0,1,2],[False,True],[0,1,257],[0,6,260],[-1,3],[0,3,256]):rows.append(run(dict(owner='resolve',shields=shields,attacker=attacker,count=count,sides=sides,base=base,flags=flags)))
out=m.root/'backups/animations/native-damage-shield-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
