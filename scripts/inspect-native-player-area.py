"""Unchanged area-wait60, area subtype3 acknowledgement, player placement
and associate realization owners. Registry/cast, placement, area ownership,
visibility, automap, action clearing and packet sends are captured boundaries.
No packet serialization or whole PC transfer completion claim.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,client,app,server,message,module,area,otherArea,path,vtable,listOwner,ids,node=[m.heap+n*0x2000 for n in range(1,14)]
children=[m.heap+0x30000+n*0x2000 for n in range(3)]
def vec(a):return[m.rf(a+i*4) for i in range(3)]
def writevec(a,v):
 for i,n in enumerate(v):m.wf(a+i*4,n)
def label(a):return {actor:99,module:66,area:88,otherArea:89,0:None,**{v:100+i for i,v in enumerate(children)}}[a]
def hook(u,a,n,_):
 global modes,safes,entered
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0))
 elif a==0x14055b980:
  values=c.get('modes',[2,2]);value=values[min(modes,len(values)-1)];modes+=1;calls.append(['mode']);m.finish(value)
 elif a==0x1404ba840:calls.append(['clientObject',u.mem_read(client+0x50,1)[0]]);m.finish(actor if c.get('object',True) else 0)
 elif a in [0x1404de300,0x1404de710]:
  if a==0x1404de300:calls.append(['addPlayer',m.si_value(y)]);m.finish(c.get('adds',[1,1])[len([v for v in calls if v[0]=='addPlayer'])-1])
  else:calls.append(['allPlayers']);m.finish(c.get('all',1))
 elif a==0x14055bcc0:calls.append(['movePlayer']);m.finish()
 elif a==0x1404d7a00:calls.append(['party',m.si_value(y)]);m.finish(c.get('party',1))
 elif a==0x14055b860:calls.append(['pauseState',y&255]);m.finish(c.get('pause',[0,0])[(y&255)-1])
 elif a==0x1404dd0c0:calls.append(['sendPause',y&255,z&0xffffffff]);m.finish()
 elif a==0x14055b590:calls.append(['controlled',y&0xffffffff]);m.finish(c.get('controlled',0))
 elif a==0x140494e80:calls.append(['area',label(x)]);m.finish(area if c.get('rootArea',True) else 0)
 elif a==m.stop+0x10:calls.append(['asCreature']);m.finish(actor)
 elif a==m.stop+0x20:calls.append(['asModule']);m.finish(module)
 elif a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,module if c.get('module',True) else 0);m.finish(0)
 elif a==0x14055b6e0:calls.append(['module']);m.finish(module)
 elif a==0x14047d5a0:
  calls.append(['moduleArea',y&0xffffffff]);m.finish(area if (y&0xffffffff)==88 and c.get('area',True) else otherArea if (y&0xffffffff)==89 and c.get('pending',True) else 0)
 elif a==0x14036aa90:
  values=c.get('safe',[1,1]);index=min(safes,len(values)-1);calls.append(['safe',label(x),vec(y),m.xmm(UC_X86_REG_XMM2),m.si(w+0x24),m.si(rsp+0x28)])
  if c.get('write',[True,True])[min(safes,len(c.get('write',[True,True]))-1)]:writevec(m.q(rsp+0x30),[20+safes,30+safes,40+safes])
  safes+=1;m.finish(values[index])
 elif a==0x1403db4a0:calls.append(['subareas',label(x),vec(y),z&0xffffffff]);m.finish()
 elif a==0x140380470:calls.append(['addArea',label(x),label(y),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.si(rsp+0x30),m.si(rsp+0x38)]);m.finish()
 elif a==0x14039d820:
  if c['operation']!='realize' or entered:
   calls.append(['realize',label(x)]);
   if c.get('truncate'):m.wi(listOwner+8,1)
   m.finish()
  else:entered=True
 elif a==0x1403dba50:calls.append(['visible',label(x)]);m.finish()
 elif a==0x1403d54d0:calls.append(['possessed',label(x)]);m.finish(c.get('possessed',0))
 elif a==0x1403a7390:calls.append(['automap',label(x),y&0xffffffff]);m.finish()
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(children[(y&0xffffffff)-100] if 100<=(y&0xffffffff)<102 else 0)
 elif a==0x140490b80:calls.append(['clear',label(x),m.si(x+0x58c)]);m.finish()
 elif a==0x140115890:calls.append(['warning','pArea' if vec_condition(u,rsp) else 'Could not find Associate.']);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403ac840,0x1403acf89),(0x1404435a0,0x140443803),(0x140568520,0x140568720),(0x14039d820,0x14039db3b)]):raise AssertionError(f'Uncaptured area owner dependency {a:x}')
def vec_condition(u,rsp):return u.reg_read(UC_X86_REG_RIP)==0x140115890 and m.si(rsp+0x28)==0x1f21
m.si_value=lambda x:(x&0xffffffff)-0x100000000 if x&0x80000000 else x&0xffffffff
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,modes,safes,entered
 c=case;calls=[];modes=safes=0;entered=False;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wi(server+0x100d0,66);m.wq(server+0x100c8,server)
 u.mem_write(client+0x50,bytes([c.get('load',2)]));m.wi(actor+8,99);m.wq(actor,vtable);m.wq(module,vtable);m.wq(vtable+0x60,m.stop+0x10);m.wq(vtable+0x40,m.stop+0x20);m.wi(actor+0x89c,c.get('pc',1));m.wi(actor+0x908,c.get('associateType',0));m.wq(actor+0x530,path);m.wi(actor+0x4f4,88);writevec(actor+0x4f8,[11,12,13]);writevec(actor+0xa4,[1,2,3]);m.wi(area+0x140,88);m.wi(otherArea+0x140,89)
 m.wq(actor+0x900,0 if c.get('nullList') else listOwner);m.wq(listOwner,ids);m.wi(listOwner+8,len(c.get('ids',[100,102,101])))
 for i,id in enumerate(c.get('ids',[100,102,101])):m.wi(ids+i*4,id)
 for i,o in enumerate(children):
  m.wi(o+8,100+i);m.wq(o+0x530,path+0x100+i*0x200);m.wi(m.q(o+0x530)+0x24,100+i);m.wi(o+0x4f4,89 if i==0 else 0x7f000000);writevec(o+0x4f8,[7+i,8+i,9+i]);m.wi(o+0x89c,c.get('pc',1));m.wi(o+0x58c,777);m.wi(o+0x54c,888);m.wi(o+0x550,999)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0xa00,bytes(0xb00));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args={'wait':(actor,node,0),'ack':(message,client,c.get('subtype',3)),'move':(server,client,0),'realize':(actor,0,0)}[c['operation']]
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,v)
 try:u.emu_start({'wait':0x1403ac840,'ack':0x1404435a0,'move':0x140568520,'realize':0x14039d820}[c['operation']],m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,load=u.mem_read(client+0x50,1)[0],owner=m.si(path+0x24),children=[[m.si(o+off) for off in [0x58c,0x54c,0x550]] for o in children[:2]],**(dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff) if c['operation'] in ['ack','wait'] else {}))
if __name__=='__main__':
 rows=[run(dict(operation='wait',pc=pc,associateType=kind,controlled=controlled,rootArea=area)) for pc,kind,controlled,area in itertools.product([0,1,2],[0,3,4,65539],[0,1,2],[False,True])]
 rows += [run(dict(operation='ack',load=load,subtype=subtype,overflow=overflow,modes=modes,object=object,adds=adds,all=all,party=party,pause=pause)) for load,subtype,overflow,modes,object,adds,all,party,pause in itertools.product([0,1,2],[3,4,259],[0,1],[[2,2],[0,2],[2,0]],[False,True],[[1,1],[0,1],[2,3]],[1,3],[0,1],[[0,0],[1,1],[2,1]])]
 rows += [run(dict(operation='move',object=object,module=module,area=area,safe=[safe],write=[write],pc=pc,possessed=possessed)) for object,module,area,safe,write,pc,possessed in itertools.product([False,True],[False,True],[False,True],[0,1,2],[False,True],[0,1],[0,1])]
 rows += [run(dict(operation='realize',nullList=null,ids=ids,area=area,pending=pending,rootArea=rootArea,safe=safe,write=write,pc=pc,possessed=possessed,truncate=truncate)) for null,ids,area,pending,rootArea,safe,write,pc,possessed,truncate in itertools.product([False,True],[[],[100,102,101],[101,100]],[False,True],[False,True],[False,True],[[0,1],[1,0]],[[True,False],[False,True]],[0,1],[0,1],[False,True])]
 out=m.root/'backups/animations/native-player-area-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
