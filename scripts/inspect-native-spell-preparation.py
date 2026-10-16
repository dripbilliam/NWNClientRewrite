"""Original clear owners, Input16/17 and spell-slot drop callback.
Unchanged instruction bodies; canonical client/object, message scalar reads,
rule lookup, SetSlot, GUI SetSpell/tint, warning and delete are captured
boundaries. Not a packet-codec/native-GUI-heap or complete-rest claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,client,message,app,rules,spells,vt,dest,source,icon=[m.heap+n*0x1000 for n in range(1,12)]

def hook(u,a,n,_):
 global cursor,overflowIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404ba840:calls.append(['clientObject']);m.finish(0 if c.get('missingObject') else actor)
 elif a==m.stop+0x100:calls.append(['asCreature']);m.finish(0 if c.get('wrongType') else actor)
 elif a==0x1402d9460:
  overflows=c.get('overflows',[0,0]);v=overflows[min(overflowIndex,len(overflows)-1)];overflowIndex+=1;calls.append(['overflow',v]);m.finish(v)
 elif a==0x1402d9520:calls.append(['underflow',c.get('underflow',0)]);m.finish(c.get('underflow',0))
 elif a in [0x1402d9630,0x1402d9bc0]:
  name='byte' if a==0x1402d9630 else 'dword';v=values[cursor];cursor+=1;calls.append([name,v&(255 if name=='byte' else 0xffffffff)]);m.finish(v)
 elif a==0x1402af4a0:
  if kind=='list':m.finish(m.heap+0x70000+(y&0xffffffff)*0x200 if (y&0xffffffff)<4 else 0)
  else:calls.append(['spell',y&0xffffffff]);m.finish(0 if c.get('missingSpell') else spells)
 elif a==0x1406ac1a0:m.finish(0 if c.get('missingActor') else actor)
 elif a==0x1407f66e0:m.finish(len(c.get('known',[0,1,2]))&65535)
 elif a==0x1407f5c50:m.finish(c.get('known',[0,1,2])[w&255])
 elif a==0x1402af530:m.finish(c.get('levels',[0,1,1,2])[(x-(m.heap+0x70000))//0x200]&255)
 elif a in [0x1407f3cc0,0x1407f3d30]:m.finish(0 if a==0x1407f3cc0 else 1)
 elif a==0x1402a3ba0:m.finish(m.heap+0x60000+(y&255)*0x100)
 elif a==0x140415c00:calls.append(['set',y&255,z&255,w&0xffffffff,m.si(rsp+0x28)&255,m.si(rsp+0x30)&255,m.si(rsp+0x38)]);m.finish(c.get('setResult',1))
 elif a==0x1403f1fc0 and kind=='input':calls.append(['clear',y&255,z&255,w&255]);m.finish()
 elif a==0x140115890:
  ptr=m.q(rsp+0x38);text=bytes(u.mem_read(ptr,80)).split(b'\0')[0].decode();calls.append(['warning',text]);m.finish()
 elif a==0x140c10360:calls.append(['delete',m.si(x),y&0xffffffff]);m.finish()
 elif a==m.stop+0x108:m.finish(c.get('sourceType',0x53704278))
 elif a==0x1409c2630:
  label='source' if x==source else 'destination';calls.append(['setWidget',label,y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30)&255]);m.wi(x+0x144,y);m.wi(x+0x160,m.si(rsp+0x28));m.wi(x+0x164,w);u.mem_write(x+0x15c,bytes([m.si(rsp+0x30)&255]));m.finish()
 elif a==0x1400a4c30:calls.append(['tint','source' if x==icon else 'destination']);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x1403f1fc0,0x1403f210a),(0x1404531b0,0x1404557a4),(0x1409c21d0,0x1409c2336),(0x14088ddb0,0x14088e157),(0x1407f1080,0x1407f109f)]):raise AssertionError(f'Uncaptured preparation dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case,which):
 global c,kind,calls,cursor,overflowIndex,values
 c=case;kind=which;calls=[];cursor=overflowIndex=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spells);u.mem_write(0x14141e310,b'\0');m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x100);m.wq(actor+0xad0,stats);m.wi(actor+0x8ac,c.get('field8ac',0))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop)
 if which=='clear':
  count=c.get('classCount',2);u.mem_write(stats+0xd8,bytes([count]));index=c.get('classIndex',0)&255;level=c.get('level',1)&255;slot=c.get('slot',0)&255
  at=stats+0xe0+min(index,7)*0x188+0xa0+min(level,9)*16;pool=m.heap+0x20000;records=m.heap+0x30000;m.wq(at,pool);m.wi(at+8,c.get('count',3));m.wi(at+12,512)
  for i in range(c.get('count',3)):
   ptr=records+i*16;m.wi(ptr,100+i);m.wq(pool+i*8,0 if c.get('null') else ptr)
  args=[stats,c.get('classIndex',0),c.get('level',1),c.get('slot',0)];entry=0x1403f1fc0
 elif which=='input':
  clear=c.get('clear',False);values=c.get('values',[0,1,0] if clear else [0,100,1,0,2]);args=[message,client,17 if clear else 16,0];entry=0x1404531b0
 elif which=='list':
  m.wq(actor+0x3b0,stats);m.wq(rules+0x110,m.heap+0x50000);m.wq(app,app);m.wq(rules+0xd0,spells);m.wi(spells,4)
  u.mem_write(dest+0x23c0,b'\0');u.mem_write(dest+0x23c4,bytes([c.get('index',0)&255]));m.wi(m.heap+0x504f0,c.get('restricted',0));m.wi(m.heap+0x504f4,c.get('pickDomains',1));m.wi(m.heap+0x5051c,c.get('minimum',1));u.mem_write(stats+0x296+(c.get('index',0)&255)*0x150,bytes([c.get('classLevel',3)&255]))
  for i,mask in enumerate(c.get('masks',[0,1,3,63])):u.mem_write(m.heap+0x70000+i*0x200+0x18c,bytes([mask&255]))
  for i,id in enumerate(c.get('domains',[2,3])):
   for l in range(10):m.wi(m.heap+0x60000+i*0x100+0x1c+l*4,id)
  m.wi(source,c.get('cursor',0));m.wi(source+4,7);u.mem_write(rsp+0x28,bytes([c.get('meta',0)&255]));args=[dest,c.get('level',1),source,source+4];entry=0x14088ddb0
 else:
  for ptr,record in [(dest,c.get('destination',{})),(source,c.get('source',{}))]:
   m.wq(ptr,vt+0x200);m.wq(vt+0x220,m.stop+0x108)
   for offset,key,default in [(0x140,'kind',0),(0x144,'id',100),(0x154,'level',1),(0x158,'ready',1),(0x160,'metamagic',0),(0x164,'domain',0)]:m.wi(ptr+offset,record.get(key,default))
   u.mem_write(ptr+0x15c,bytes([record.get('classIndex',2)&255]));m.wq(ptr+0x148,0 if c.get('missingIcon') else icon if ptr==source else icon+0x100)
  args=[dest,c.get('flags',0),dest if c.get('same') else source,0];entry=0x1409c21d0
 for reg,value in zip([UC_X86_REG_RSP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[rsp,*args]):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception as error:raise AssertionError(f'{which} {c} RIP{u.reg_read(UC_X86_REG_RIP):x} calls{calls}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 out=dict(case=c,calls=calls)
 if which=='clear':out['slots']=[None if m.q(pool+i*8)==0 else m.si(m.q(pool+i*8)) for i in range(c.get('count',3))]
 else:out['result']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 if which=='list':out.update(cursor=m.si(source),domain=m.si(source+4));out.pop('calls')
 if which=='drop':out['ready']=[m.si(p+0x158) for p in [dest,source]]
 return out
clears=[dict(classIndex=i,level=l,slot=s,count=n,null=null) for i,l,s,n,null in itertools.product([0,1,2,256],[1,9,10,257],[0,2,255,256],[0,3,260],[False,True])]
inputs=[dict(clear=clear,missingObject=missing,wrongType=wrong,field8ac=field,overflows=overflow,underflow=underflow,missingSpell=spell) for clear,missing,wrong,field,overflow,underflow,spell in itertools.product([False,True],[False,True],[False,True],[0,1],[[0,0],[1,0],[0,1]],[0,1],[False,True])]
inputs += [dict(clear=False,values=[257,0xffffffff,258,259,260],setResult=0),dict(clear=True,values=[257,258,259])]
drops=[dict(destination=dict(id=old,kind=dk,level=1,metamagic=2),source=dict(id=id,kind=sk,level=sl,metamagic=4,domain=domain),flags=flags,sourceType=type,same=same,missingIcon=missing) for old,id,dk,sk,sl,domain,flags,type,same,missing in itertools.product([-1,101],[-1,100],[0,1],[0,1],[1,2],[0,1],[0,1,0x40],[0x53704278,0],[False,True],[False,True])]
lists=[dict(restricted=r,level=l,meta=meta,cursor=cursor,domains=domains,classLevel=level,minimum=minimum,index=index) for r,l,meta,cursor,domains,level,minimum,index in itertools.product([0,1],[0,1,2],[0,1,4],[0,1,3,4,5,6],[[2,3],[2,2],[-1,3],[2,-1]], [0,3],[1,4],[0,8])]
lists += [dict(missingActor=True),dict(restricted=1,known=list(range(4))*66,cursor=256,meta=1),dict(restricted=1,known=list(range(4))*66,cursor=257,meta=4)]
out=m.root/'backups/animations/native-spell-preparation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,clear=[run(c,'clear') for c in clears],input=[run(c,'input') for c in inputs],drop=[run(c,'drop') for c in drops],list=[run(c,'list') for c in lists]))+'\n');print(json.dumps(dict(clear=len(clears),input=len(inputs),drop=len(drops),list=len(lists),output=str(out))))
