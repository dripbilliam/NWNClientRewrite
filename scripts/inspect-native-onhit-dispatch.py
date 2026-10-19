"""Complete ResolveOnHitEffect1403e7840..1403e8bbc with captured lower
weapon/property access, virtual casts, active 2DA reads, RNG, saves and named
ApplyOnHit handlers. Selection, chance/DC gates, call order and parameter
narrowing execute original instructions. Handler effects are separate owners.
"""
import importlib,itertools,json,re
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,target,item,ammo,prop,app,tables,onhit,durations,cost,round_,attack,stats,vtable,door,placeable=[m.heap+n*0x1000 for n in range(16)]
handlers={m.base+s.address:re.search(r'\?ApplyOnHit(\w+)@',s.name.decode()).group(1)for s in m.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name and re.search(rb'\?ApplyOnHit(\w+)@',s.name)}
exports={s.name.decode():m.base+s.address for s in m.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name}
alignment={address:'goodEvil' if 'GoodEvil' in name else 'lawChaos' for name,address in exports.items() if '?GetSimpleAlignment' in name}
alignment.update({0x1404069f0:'goodEvil',0x140406a20:'lawChaos'})
slay={address for name,address in exports.items() if '?GetCanSlayAlignment@' in name}
slay.add(0x1403e3760)
def text(p):return bytes(u.mem_read(m.q(p),64)).split(b'\0')[0].decode()
def hook(u,a,n,_):
 global allocated
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x100:m.finish(target if c.get('creature',True)else 0)
 elif a==m.stop+0x110:m.finish(door if c.get('door',False)else 0)
 elif a==m.stop+0x120:m.finish(placeable if c.get('placeable',False)else 0)
 elif a==0x140375e40:trace.append(['attack',y&0xffffffff]);m.finish(attack)
 elif a==0x1403760a0:trace.append(['weapon',y&0xffffffff]);m.finish(item if c.get('weapon',True)else 0)
 elif a==0x140462bd0:trace.append(['ammo',y&0xffffffff]);m.finish(ammo if c.get('ammo',True)else 0)
 elif a==0x140468ef0:trace.append(['property',y&0xffffffff]);m.finish(prop if not c.get('nullProperty',False)else 0)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10368:allocated+=1;m.finish(m.heap+0x20000+allocated*0x100)
 elif a==0x1401a7010:
  column=text(z);kind='onhit' if x==onhit else 'duration' if x==durations else 'cost';value={'Param1ResRef':c.get('paramRef',1),'EffectChance':c.get('chance',50),'DurationRounds':c.get('rounds',3),'Value':c.get('dc',17)}[column];found=c.get({'onhit':'onhitFound','duration':'durationFound','cost':'costFound'}[kind],True);trace.append(['table',kind,y&0xffffffff,column,int(found),value if found else None]);
  if found:m.wi(w,value)
  m.finish(int(found))
 elif a==0x1404035c0:trace.append(['level']);m.finish(c.get('level',12)&255)
 elif a==0x1403ec600:trace.append(['save',y&255,z&65535,w&255,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.si(rsp+0x38),m.si(rsp+0x40)]);m.finish(c.get('saved',0)&255)
 elif a==0x140c7ed00:trace.append(['random',c.get('random',0)]);m.finish(c.get('random',0))
 elif a==0x1402b38a0:trace.append(['costTable',y&255]);m.finish(cost)
 elif a==0x1402a4130:trace.append(['rulesDC',f'{y:016x}',z&0xffffffff]);m.finish(c.get('rulesDC',20))
 elif a in alignment:trace.append(['alignment',alignment[a]]);m.finish(c.get(alignment[a],0))
 elif a in slay:trace.append(['canSlay']);m.finish(c.get('canSlay',1))
 elif a in handlers:trace.append(['apply',handlers[a],'property' if z==prop else z&0xffffffff]);m.finish()
 elif not(0x1403e7840<=a<0x1403e8bbd or 0x1402ae870<=a<0x1402ae899):raise AssertionError(f'Unmapped onhit dependency {a:x}: {[name for name,address in exports.items()if address==a]}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,allocated
 c=case;trace=[];allocated=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(target,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wq(vtable+0x30,m.stop+0x110);m.wq(vtable+0x98,m.stop+0x120)
 m.wq(actor+0x880,round_);m.wq(actor+0x950,m.heap+0x18000 if c.get('inventory',True)else 0);m.wq(actor+0xad0,stats);m.wq(target+0xad0,stats+0x100);m.wi(actor+8,0x80000042)
 u.mem_write(stats+0x100+0xd3d,bytes([c.get('constitution',2)&255]));u.mem_write(stats+0x100+0xd20,(c.get('race',1)&65535).to_bytes(2,'little'));u.mem_write(door+0x41f,bytes([c.get('doorLevel',20)&255]));u.mem_write(placeable+0x3a8,bytes([c.get('placeableLevel',20)&255]))
 u.mem_write(round_+0x2f2c,bytes([c.get('attack',0)&255]));u.mem_write(attack+0x56,bytes([c.get('weaponAttack',1)&255]));m.wi(item+0x40,c.get('base',9));m.wi(item+0x50,123);m.wi(ammo+0x50,124)
 for o in[item,ammo]:m.wi(o+0x380,c.get('count',1))
 m.wi(prop,(c.get('type',48)&65535)|((c.get('subtype',9)&65535)<<16));u.mem_write(prop+6,(c.get('cost',4)&65535).to_bytes(2,'little'));u.mem_write(prop+9,bytes([c.get('param',3)&255]))
 m.wq(0x1412df8f8,app);m.wq(app+0x130,tables);m.wq(tables+0x3c8,onhit);m.wq(tables+0x3d8,durations)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,target,c.get('offhand',0),c.get('critical',0)]):u.reg_write(reg,v)
 try:u.emu_start(0x1403e7840,m.stop,count=200000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,trace=trace)
cases=[dict(type=t,subtype=s,random=r,saved=save)for t,s,r,save in itertools.product([36,48,67,72],range(27),[0,50],[0,1])]
cases +=[dict(subtype=9,**{key:value})for key,values in dict(chance=[0,-1,1,99,100,101],rounds=[0,-1,1,7],onhitFound=[False],durationFound=[False],costFound=[False],creature=[False],paramRef=[0,2],param=[0,255],cost=[0,65535],level=[0,1,255],count=[0],inventory=[False],weapon=[False],nullProperty=[True],base=[6,7,8,11,61]).items()for value in values]
cases +=[dict(type=72,subtype=s,level=level,saved=save,random=50,creature=creature)for s,level,save,creature in itertools.product(range(11),[0,1,20,255],[0,2],[False,True])]
cases +=[dict(type=t,subtype=s,critical=1,creature=creature,**variation)for t,s,creature,variation in itertools.product([48,72],range(27),[False,True],[dict(onhitFound=False),dict(paramRef=2),dict(costFound=False,rulesDC=65537),dict(param=1,race=1,goodEvil=1),dict(param=3,lawChaos=3)])]
cases +=[dict(subtype=8,creature=False,door=doorFlag,placeable=placeableFlag,dc=dc,doorLevel=doorLevel,placeableLevel=placeableLevel)for doorFlag,placeableFlag,dc,doorLevel,placeableLevel in itertools.product([False,True],[False,True],[0,17,65537],[0,17,18],[0,17,18])]
cases +=[dict(type=72,subtype=5,constitution=con,level=level,saved=save)for con,level,save in itertools.product([0,127,128,255],[0,1,255],[0,1])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-onhit-dispatch-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,handlers={hex(a):name for a,name in handlers.items()},rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),handlers=len(handlers))))
