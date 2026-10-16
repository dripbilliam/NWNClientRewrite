"""Original ReadySpellLevel4123b0, highest-known402950, RemoveBadEffects39e020,
ClearSpellEffectsOnOthers491110, RestoreItemProperties39f760/39f860 and bulk
RestoreUsedActiveProperties46b4d0. External gain/slot getters, lookup/virtual
casts, removal/destruction, repositories/equipment and property-update
delivery are captured. No packet/native GUI or full effect-removal claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,app,rules,classes,vt,targets,effectArray,repo,repoList=[m.heap+n*0x1000 for n in range(1,11)]
def remove(o,id):
 arr=m.q(o+0x150);count=m.si(o+0x158);ptrs=[m.q(arr+i*8) for i in range(count)];ptrs=[ptr for ptr in ptrs if m.q(ptr)!=id]
 for i,ptr in enumerate(ptrs):m.wq(arr+i*8,ptr)
 m.wi(o+0x158,len(ptrs))
 if c.get('shrink') and o!=actor and not any(m.si(ptr+0x18)==10 for ptr in ptrs):
  count=m.si(actor+0x178);ids=[m.si(targets+i*4) for i in range(count)];id=m.si(o+8)
  if id in ids:ids.remove(id)
  for i,id in enumerate(ids):m.wi(targets+i*4,id)
  m.wi(actor+0x178,len(ids))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140405770:m.finish(c.get('count',3)&255)
 elif a==0x140408120:calls.append(['gain',y&255,z&255]);m.finish(c.get('gain',3)&255)
 elif a==0x140115890:calls.append(['warning']);m.finish()
 elif a==0x140423fc0:m.finish(m.si(x+0x40))
 elif a==0x1404c6af0:m.finish(c.get('state',1))
 elif a==0x140484d70:calls.append(['runEventScript',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a in [0x1404c64d0,0x140c10360,0x140c10370]:m.finish()
 elif a==0x140498280:calls.append(['remove',m.si(x+8),y]);remove(x,y);m.finish(1)
 elif a==0x14055b4c0:
  calls.append(['object',y&0xffffffff]);m.finish(0 if c.get('missing') else m.heap+0x30000+(y&255)*0x1000)
 elif a==m.stop+0x100:calls.append(['asWorld',m.si(x+8)]);m.finish(0 if c.get('wrongType') else x)
 elif a==m.stop+0x108:calls.append(['asArea',m.si(x+8)]);m.finish(x if c.get('areaEffect') else 0)
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405570b0:calls.append(['destroyLater',w&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30)]);m.finish()
 elif a==0x140462bd0:
  calls.append(['equipped',y&0xffffffff]);m.finish(itemPointers.get('equipment') if y==16 else 0)
 elif a==0x1404693e0:current=y;calls.append(['at',m.si(current)]);m.finish(itemPointers.get(m.si(current),0))
 elif a==0x140169110:
  current=m.q(y);next=m.q(current+8);m.wq(y,next);m.finish()
 elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);m.finish(0 if c.get('missingBase') else bases.get(y,0))
 elif a==0x14046b4d0 and kind=='items':calls.append(['restore',m.si(x+8),y&0xffffffff]);m.finish()
 elif a==0x14046cf20:calls.append(['update',m.si(x+8),y&0xffffffff]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x1404123b0,0x140412593),(0x140402950,0x1404029a1),(0x14039e020,0x14039e0c4),(0x140491110,0x1404912c8),(0x14039f760,0x14039f90c),(0x14046b4d0,0x14046b580),(0x1403d7160,0x1403d71ef),(0x14047c0b0,0x14047d1d5)]):raise AssertionError(f'Uncaptured rest resource dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,which):
 global c,kind,calls,itemPointers,bases
 c=case;kind=which;calls=[];itemPointers={};bases={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);m.wq(actor+0xad0,stats);m.wi(actor+8,10);rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);args=[actor,0,0];entry=0
 if which in ['ready','highest']:
  records=c.get('classes',[1,0]);u.mem_write(stats+0xd8,bytes([len(records)]));level=c.get('level',1)&255
  for index,memo in enumerate(records):
   at=stats+0xe0+index*0x188;u.mem_write(at+0x17c,bytes([index]));m.wi(classes+index*0x530+0x4ec,memo)
   for l in range(10):
    pool=m.heap+0x10000+index*0x10000+l*0x1000;m.wq(at+0xa0+l*16,pool);m.wi(at+0xa8+l*16,c.get('count',3));m.wi(at+l*4+0x140,c.get('bonus',0));u.mem_write(at+0x168+l,bytes([7]));u.mem_write(at+0x172+l,bytes([8]));m.wi(at+l*16+8,(c.get('known',{}) or {'3':2}).get(str(l),0))
    for slot in range(c.get('count',3)):
     ptr=m.heap+0x40000+index*0x20000+l*0x2000+slot*16;m.wq(pool+slot*8,0 if c.get('null') else ptr);m.wi(ptr,100+slot);m.wi(ptr+4,c.get('ready',0));u.mem_write(ptr+8,bytes([2,1]))
  args=[stats,c.get('level',1),0];entry=0x1404123b0 if which=='ready' else 0x140402950
 elif which in ['remove','clear','domination']:
  rows=c.get('effects',[dict(type=1,duration=1,subtype=8,creator=10),dict(type=99,duration=2,subtype=0)])
  m.wq(actor+0x170,targets);ids=c.get('targets',[20,21]);m.wi(actor+0x178,len(ids));m.wi(actor+0x17c,16)
  for i,id in enumerate(ids):m.wi(targets+i*4,id)
  m.wi(actor+0x8fc,c.get('masterId',10));owners=[actor] if which in ['remove','domination'] else [m.heap+0x30000+id*0x1000 for id in set(ids)]
  for n,o in enumerate(owners):
   id=10 if which in ['remove','domination'] else (o-(m.heap+0x30000))//0x1000;m.wi(o+8,id);m.wq(o,vt);m.wq(vt+0x20,m.stop+0x100);m.wq(vt+0xa8,m.stop+0x108);m.wi(o+0x330,c.get('areaCreator',10));arr=m.heap+0x70000+n*0x4000;m.wq(o+0x150,arr);m.wi(o+0x158,len(rows))
   for i,e in enumerate(rows):ptr=arr+0x400+i*0x200;m.wq(arr+i*8,ptr);m.wq(ptr,i+1);u.mem_write(ptr+8,struct.pack('<HH',e.get('type',1)&65535,(e.get('duration',1)&7)|(e.get('subtype',8)&0xfff8)));m.wi(ptr+0x18,e.get('creator',10));m.wi(ptr+0x40,e.get('value',7))
  entry={'remove':0x14039e020,'clear':0x140491110,'domination':0x1403d7160}[which]
 elif which=='event':
  u.mem_write(0x14141e310,b'\0\0');m.wi(actor+0x30,11);m.wi(actor+0x380,55);u.mem_write(actor+0x384,b'\7');u.mem_write(stats,struct.pack('<H',35));args=[actor,10,c.get('caller',20),stats];entry=0x14047c0b0
 elif which=='properties':
  rows=c['properties'];ptr=m.heap+0x40000;m.wq(actor+0x368,ptr);m.wi(actor+0x370,len(rows));args=[actor,c.get('onlyUnset',0),0];entry=0x14046b4d0
  for i,r in enumerate(rows):at=ptr+i*48;u.mem_write(at,struct.pack('<HHHH',r.get('type',15),0,0,r.get('cost',8)));m.wi(at+0xc,r.get('remaining',0));u.mem_write(at+0x10,bytes([r.get('uses',255)&255]))
 else:
  # Pointer-like repository cursors preserve identity/order and permit NULL
  # item records and nested carried containers without flattening them.
  def item(id,container=False):
   ptr=m.heap+0x20000+id*0x1000;itemPointers[id]=ptr;m.wi(ptr+8,id);m.wi(ptr+0x40,id);base=m.heap+0x50000+id*0x100;bases[id]=base;m.wi(base+0x80,int(container));return ptr
  def repository(ptr,ids):
   linked=ptr+0x100;m.wq(ptr+0x10,linked);m.wq(linked,ptr+0x200 if ids else 0)
   for i,id in enumerate(ids):cursor=ptr+0x200+i*32;m.wi(cursor,id);m.wq(cursor+8,ptr+0x200+(i+1)*32 if i+1<len(ids) else 0)
  itemPointers['equipment']=item(1);bag=item(2,True);item(3);item(4);m.wq(bag+0x3d0,repo+0x1000);repository(repo+0x1000,[4]);repository(repo,[2,0,3]);m.wq(actor+0x958,0 if c.get('missingRepo') else repo);m.wq(actor+0x950,app)
  entry=0x14039f760
 for reg,value in zip([UC_X86_REG_RSP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[rsp,*args]):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(entry,m.stop,count=200000)
 except Exception as error:raise AssertionError(f'{which} {c} RIP{u.reg_read(UC_X86_REG_RIP):x} calls{calls}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 out=dict(case=c,calls=calls)
 if which=='ready':out['classes']=[dict(pools=[[None if m.q(m.q(stats+0xe0+i*0x188+0xa0+l*16)+s*8)==0 else m.si(m.q(m.q(stats+0xe0+i*0x188+0xa0+l*16)+s*8)+4) for s in range(c.get('count',3))] for l in range(10)],remaining=list(u.mem_read(stats+0xe0+i*0x188+0x168,10)),maximum=list(u.mem_read(stats+0xe0+i*0x188+0x172,10))) for i in range(len(c.get('classes',[1,0])))]
 elif which=='highest':out['result']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 elif which in ['clear','remove','domination']:out['remaining']=[[m.q(m.q(o+0x150)+i*8) and m.si(m.q(m.q(o+0x150)+i*8)) for i in range(m.si(o+0x158))] for o in owners];out['targetCount']=m.si(actor+0x178)
 elif which=='event':out['history']={'pc':m.si(actor+0x380)&0xffffffff,'state':u.mem_read(actor+0x384,1)[0]}
 elif which=='properties':out['properties']=[dict(uses=u.mem_read(ptr+i*48+0x10,1)[0],remaining=m.si(ptr+i*48+0xc)) for i in range(len(rows))]
 return out
ready=[dict(classes=classes,level=level,count=count,bonus=bonus,gain=gain,null=null,ready=7) for classes,level,count,bonus,gain,null in itertools.product([[1,0],[0],[1],[],[1,0,1]],[0,1,9,10,257],[0,3,260],[0,255,256,-1],[0,3,255],[False,True])]
highest=[dict(classes=classes,known=known,count=0) for classes,known in itertools.product([[],[0],[1],[0,1]], [{},{'0':1},{'9':1},{'8':65536},{'5':65537}])]
removeCases=[dict(effects=[dict(type=type,duration=duration,subtype=subtype),dict(type=1,duration=1,subtype=8)]) for type,duration,subtype in itertools.product([1,35,99,100],[0,1,2,3,4,7],[0,8,16,24,32,40,48,56])]
clearCases=[dict(effects=[dict(type=type,duration=duration,subtype=subtype,creator=creator)],areaEffect=area,areaCreator=owner,shrink=shrink) for type,duration,subtype,creator,area,owner,shrink in itertools.product([1,91],[1,2],[0,8,24],[10,11],[False,True],[10,11],[False,True])]
clearCases += [dict(**{key:value}) for key,values in {'missing':[True],'wrongType':[True],'effects':[[]],'targets':[[],[20,20,21]]}.items() for value in values]
props=[dict(properties=[dict(type=type,cost=cost,uses=uses,remaining=ready)],onlyUnset=flag) for type,cost,uses,ready,flag in itertools.product([0,15],[0,1,7,8,9,10,11,12,13,65535],[0,2,255],[0,2],[-1,0,1])]
items=[dict(missingRepo=r,missingBase=b) for r,b in itertools.product([False,True],[False,True])]
domination=[dict(effects=[dict(type=type,creator=creator,value=value) for type in types],masterId=master) for types,creator,master,value in itertools.product([[],[8,8,8],[1,8,8],[8,1,8]],[10,11],[10,11],[7,21])]
events=[dict(caller=caller,state=state) for caller,state in itertools.product([0,20,0x80000001,0x7f000000],[-1,0,1,2,3,257])]
out=m.root/'backups/animations/native-rest-resource-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,ready=[run(c,'ready') for c in ready],highest=[run(c,'highest') for c in highest],remove=[run(c,'remove') for c in removeCases],clear=[run(c,'clear') for c in clearCases],properties=[run(c,'properties') for c in props],items=[run(c,'items') for c in items],domination=[run(c,'domination') for c in domination],event=[run(c,'event') for c in events]))+'\n');print(json.dumps(dict(ready=len(ready),highest=len(highest),remove=len(removeCases),clear=len(clearCases),properties=len(props),items=len(items),domination=len(domination),event=len(events),output=str(out))))
