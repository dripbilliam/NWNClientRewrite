"""Complete native bonus feat apply/remove/membership and ordinary HasFeat.
Both owned WORD-list Contains implementations execute, including their sentinel
paths. Captured allocation/realloc/memmove and chest-item/armor providers only.
Upper handler/pool semantics, not complete polymorph or equipment proof.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,stats,vt,effect,ints,bonuses,permanent,pool,item=[m.heap+n*0x2000 for n in range(9)]
ranges=[(0x140427fd0,0x140428095),(0x1404360c0,0x140436266),(0x140425ba0,0x140425c2d),(0x14040b900,0x14040b9cb),(0x140296910,0x14029699a),(0x140423fc0,0x140423fcb),(0x1405180b0,0x140518a6e),(0x140425210,0x14042521c)]
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x10:m.finish(actor if c.get('creature',True)else 0)
 elif a==0x140c4f038:
  calls.append(['realloc',y]);ptr=m.heap+0xa0000;u.mem_write(ptr,bytes(u.mem_read(x,min(y,c.get('capacity',len(c.get('bonuses',[])))*2))));m.finish(ptr)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140462bd0:m.finish(0 if c.get('armor')is None else item)
 elif a==0x140466500:m.finish(c['armor'])
 elif a==0x140c10324:m.finish(m.heap+0xc0000)
 elif a==0x1404233d0:
  m.wq(x+0x48,m.heap+0xc1000);m.wi(x+0x40,8);m.wi(x+0x20,1);m.wi(x+0x24,1);m.wi(x+0x18,0x7f000000);m.finish(x)
 elif a==0x140286110:m.wi(y,c.get('id',289));m.finish(c.get('pop',1))
 elif a==0x1402a3bd0:calls.append(['feat',y&65535]);m.finish(item if c.get('validFeat',True)and(y&65535)<1000 else 0)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a==0x140286330:
  flags=int.from_bytes(u.mem_read(z+10,2),'little');output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(z+24)&0xffffffff,integers=[m.si(m.q(z+0x48)+i*4)for i in range(8)]);m.finish(c.get('push',1))
 elif a in [0x140c10360,0x140423770]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected bonus-feat dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,output
 c=case;calls=[];output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wq(stats+0x30,actor);m.wq(actor+0x950,item);m.wi(actor+12,99)
 m.wq(stats,permanent);m.wi(stats+8,len(c.get('permanent',[])))
 for i,value in enumerate(c.get('permanent',[])):u.mem_write(permanent+i*2,struct.pack('<H',value&65535))
 m.wq(stats+0x20,bonuses);m.wi(stats+0x28,len(c.get('bonuses',[])));m.wi(stats+0x2c,c.get('capacity',len(c.get('bonuses',[]))))
 for i,value in enumerate(c.get('bonuses',[])):u.mem_write(bonuses+i*2,struct.pack('<H',value&65535))
 classes=c.get('classes',[]);u.mem_write(stats+0xd8,bytes([len(classes)]))
 for i,value in enumerate(classes):u.mem_write(stats+0x25c+i*0x188,bytes([value&255]))
 m.wq(effect,77);m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wi(ints,c.get('id',289));m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
 for i,e in enumerate(c.get('effects',[])):
  ptr=m.heap+0x30000+i*0x200;storage=ptr+0x110;m.wq(ptr,e.get('id',78));u.mem_write(ptr+8,struct.pack('<H',e.get('type',83)));m.wq(ptr+0x48,storage);m.wi(ptr+0x40,8);m.wi(storage,e.get('feat',289));m.wq(pool+i*8,ptr)
 entry={'constructor':0x1405180b0,'apply':0x140427fd0,'remove':0x1404360c0,'hasBonus':0x140425ba0,'hasFeat':0x14040b900}[c['mode']];args=[actor,1107,1]if c['mode']=='constructor'else[0,actor,effect]if c['mode']in['apply','remove']else[stats,c.get('id',289)]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,bonuses=list(struct.unpack('<'+'H'*m.si(stats+0x28),u.mem_read(m.q(stats+0x20),m.si(stats+0x28)*2))),capacity=m.si(stats+0x2c),output=output)
rows=[]
profiles=[[],[289],[14,289,40],list(range(16)),list(range(17)),list(range(32)),[289,1,289],list(range(16))+[289],list(range(16))+[289,289]]
for mode,values,id,creature in itertools.product(['apply','remove','hasBonus'],profiles,[-1,0,1,14,16,40,289,65825],[False,True]):
 rows.append(run(dict(mode=mode,bonuses=values,capacity=0 if not values else 16 if len(values)<=16 else 32,id=id,creature=creature)))
for effects,id in itertools.product([[],[dict(id=77)],[dict(id=78)],[dict(id=78,feat=65825)],[dict(id=78,type=84),dict(id=79)],[dict(id=78,type=82),dict(id=79)],[dict(id=78,feat=1)]],[289,65825]):rows.append(run(dict(mode='remove',bonuses=[289,14],capacity=16,effects=effects,id=id)))
for owned,bonus,classes,armor,id in itertools.product([[],[289],[1]],profiles,[[],[7],[4,7]],[None,0,3,4,6],[0,1,14,41,289,65825]):rows.append(run(dict(mode='hasFeat',permanent=owned,bonuses=bonus,classes=classes,armor=armor,id=id)))
constructors=[run(dict(mode='constructor',id=id,validFeat=valid))for id,valid in itertools.product([-65535,-1,0,1,289,65825,65535,65536],[False,True])];constructors.extend([run(dict(mode='constructor',pop=0)),run(dict(mode='constructor',push=0))])
out=m.root/'backups/animations/native-bonus-feat-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,constructors=constructors),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),constructors=len(constructors),output=str(out))))
