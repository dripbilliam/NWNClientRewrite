"""Untouched counterspell count392830, selection block384654..384c61,
and ValidateCounterSpellData3aae30. Captured lower owners: active rules,
class lookup, ready/uses/slot access and selection writes. These comparisons
do not establish cast interruption, resource consumption or counter VFX parity.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,viewer,stats,spell,rules,area,ids,frame=[m.heap+n*0x1000 for n in range(1,9)];classDefs=m.heap+0x10000;actorRound=m.heap+0x9000;viewerRound=m.heap+0xa000
def query(kind,index,id):
 calls.append([kind,index,id&0xffffffff]);pool=c.get('ready' if kind=='ready' else 'uses',{})
 return pool.get(f'{index}:{id&0xffffffff}',0)
def slot(index,level,n):
 return c.get('slots',[])[n] if n<len(c.get('slots',[])) else None
def hook(u,a,n,_):
 if a in [m.stop,0x140384c61]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402af4a0:m.finish(spell)
 elif a==0x140494e80:m.finish(0 if c.get('noArea') else area)
 elif a==0x14055b3d0:m.finish(viewer if y==100 else 0)
 elif a==0x1403fa4a0:m.finish(y&255)
 elif a==0x140404ef0:m.finish(query('ready',y&255,z))
 elif a==0x140409160:m.finish(query('uses',z&255,y))
 elif a==0x140404f80:
  result=query('ready',y&255,z);u.mem_write(w,bytes([c.get('level',2)]));u.mem_write(m.q(rsp+0x28),bytes([0]));m.finish(result)
 elif a==0x1403aae30 and operation!='validate':
  calls.append(['validate',y&0xffffffff,z&255,w&255]);m.wi(viewer+0x7fc,y);u.mem_write(viewer+0x800,bytes([z&255,0,w&255]));m.finish()
 elif a==0x1402af530:calls.append(['level',y&255]);m.finish(c.get('level',2))
 elif a==0x1402a4130:m.finish(ruleset_value(c.get('overrides',{}),y,z)&0xffffffff)
 elif a==0x1403766e0:calls.append(['pending','actor' if x==actorRound else 'viewer']);m.finish(c.get('actorPending',1) if x==actorRound else c.get('viewerPending',1))
 elif a==0x140378f80:calls.append(['remove','actor' if x==actorRound else 'viewer']);m.finish()
 elif a==0x140405770:m.finish(len(c.get('slots',[]))&255)
 elif a in [0x140404aa0,0x140404c70,0x140402ff0]:
  row=slot(y&255,z&255,w&255);key={0x140404aa0:'id',0x140404c70:'metamagic',0x140402ff0:'domain'}[a];m.finish(row.get(key,0) if row else {'id':0xffffffff,'metamagic':255,'domain':0}[key])
 elif not any(lo<=a<hi for lo,hi in [(0x140392830,0x140392eb6),(0x140384654,0x140384c61),(0x1403aae30,0x1403aaf34),(0x1402ae870,0x1402ae899),(0x14039ecb0,0x14039eda0),(0x14039e5b0,0x14039e700)]):raise AssertionError(f'Uncaptured counterspell dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,kind='count'):
 global c,calls,operation
 c=case;calls=[];operation=kind;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,rules);m.wq(rules+8,rules);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wq(rules+0x110,classDefs);m.wf(rules+0x18,10)
 m.wi(actor+8,99);m.wi(viewer+8,100);m.wi(actor+0xa0,1);m.wi(viewer+0xa0,c.get('areaId',1));m.wi(actor+0x760,c.get('haste',0));m.wi(viewer+0x760,c.get('candidateHaste',0));m.wi(viewer+0x6f4,c.get('target',99));u.mem_write(viewer+0x6ef,bytes([c.get('mode',4)]));m.wf(viewer+0xa4,c.get('distance',0));m.wq(viewer+0xad0,stats);u.mem_write(stats+0xd8,bytes([len(c.get('classes',[{}]))]));
 for i,cl in enumerate(c.get('classes',[{}])):m.wi(classDefs+i*0x530+0x4d8,cl.get('caster',1));m.wi(classDefs+i*0x530+0x4ec,cl.get('memo',1))
 u.mem_write(spell+0x6f,bytes([c.get('innate',1)]));m.wi(spell+0x17c,2);m.wi(spell+0x180,3);m.wq(area+0x228,ids);m.wi(area+0x230,c.get('candidates',1))
 for i in range(c.get('candidates',1)):m.wi(ids+i*4,100)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,1)
 if kind in ['remove','round']:
  m.wq(actor+0x880,actorRound);m.wq(viewer+0x880,viewerRound);values=(c.get('ids',[])+[0x7f000000]*10)[:10]
  for i,id in enumerate(values):m.wi(actor+0x310+i*4,id)
  m.wi(actor+0x338,c.get('count',1));u.reg_write(UC_X86_REG_RDX,c.get('id',100));u.emu_start(0x14039e5b0 if kind=='remove' else 0x14039ecb0,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
  return dict(case=c,calls=calls,count=m.si(actor+0x338),ids=[m.si(actor+0x310+i*4)&0xffffffff for i in range(10)])
 if kind=='selection':
  # Captured block begins after spellcraft/school rank computation.
  rsp=m.stack+0x1f000;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,frame);u.reg_write(UC_X86_REG_RDI,viewer);u.reg_write(UC_X86_REG_R15,spell);u.reg_write(UC_X86_REG_R13,c.get('rank',5)&0xffffffffffffffff);u.reg_write(UC_X86_REG_R12,0);u.reg_write(UC_X86_REG_RCX,stats)
  m.wq(frame+0x67,actor);m.wi(frame+0x6f,1);u.mem_write(frame+0x77,bytes([c.get('castClass',0)]));u.mem_write(frame+0x7f,c.get('feat',65535).to_bytes(2,'little'));m.wi(frame-0x2d,c.get('count',2));m.wi(viewer+0x7fc,0xffffffff)
  u.emu_start(0x140384654,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==0x140384c61
  return dict(case=c,calls=calls,qualified=u.reg_read(UC_X86_REG_R12)&0xffffffff,rank=u.reg_read(UC_X86_REG_R13)&0xffffffff,selected=m.si(viewer+0x7fc))
 if kind=='validate':
  u.reg_write(UC_X86_REG_RCX,viewer);u.reg_write(UC_X86_REG_RDX,c.get('id',1));u.reg_write(UC_X86_REG_R8,c.get('classIndex',0));u.reg_write(UC_X86_REG_R9,c.get('level',2));u.emu_start(0x1403aae30,m.stop,count=20000)
  return dict(case=c,id=m.si(viewer+0x7fc),fields=list(u.mem_read(viewer+0x800,3)))
 u.emu_start(0x140392830,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,count=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
counts=[run(dict(innate=innate,classes=[cl],ready={f'0:{id}':ready},uses={f'0:{id}':uses},haste=haste,candidateHaste=candidateHaste)) for innate,cl,id,ready,uses,haste,candidateHaste in itertools.product([1,6,10],[dict(caster=1,memo=1),dict(caster=1,memo=0),dict(caster=0,memo=1)],[1,2,3,94,41,67,122],[0,1],[0,1],[0,1],[0,1])]
counts += [run(dict(ready={'0:1':1},candidates=count,distance=distance,mode=mode,target=target)) for count,distance,mode,target in itertools.product([0,1,10,12],[0,10,10.000001],[0,4],[99,98])]
counts += [run(dict(innate=6,ready={'0:94':1},overrides={'COUNTERSPELL_LESSER_DISPEL_THRESHOLD':threshold},noArea=noArea)) for threshold,noArea in itertools.product([-1,2,6,9],[False,True])]
selects=[run(dict(innate=innate,classes=classes,ready={f'{i}:{id}':1 for i in range(len(classes))} if ready else {},uses={f'{i}:{id}':1 for i in range(len(classes))} if uses else {},level=2),'selection') for innate,classes,id,ready,uses in itertools.product([1,6,10],[[{}],[dict(memo=0)],[{},{}],[{},dict(memo=0)],[dict(caster=0),{}]],[1,2,3,94,41,67,122],[False,True],[False,True])]
selects += [run(dict(mode=mode,target=target,areaId=areaId,castClass=castClass,feat=feat,rank=-5,ready={'0:1':1}),'selection') for mode,target,areaId,castClass,feat in itertools.product([0,4],[99,98],[1,2],[0,254,255],[65535,12])]
selects += [run(dict(innate=6,ready={'0:94':1},overrides={'COUNTERSPELL_LESSER_DISPEL_THRESHOLD':threshold}),'selection') for threshold in [-1,2,6,9]]
validations=[run(dict(id=id,level=level,classIndex=classIndex,slots=slots),'validate') for id,level,classIndex,slots in itertools.product([1,0xffffffff],[0,2,255],[0,7,255],[[],[None],[dict(id=1,ready=1,metamagic=2,domain=1),dict(id=1,ready=0,metamagic=16,domain=0)],[dict(id=1,ready=0,metamagic=32,domain=1),None]])]
removals=[run(dict(ids=ids,count=count,id=id),'remove') for ids,count,id in itertools.product([[],[100],[100,101,100],[0x7f000000,100,100,100]],[-1,0,1,3],[100,101,0x7f000000])]
rounds=[run(dict(ids=ids,count=count,actorPending=actorPending,viewerPending=viewerPending),'round') for ids,count,actorPending,viewerPending in itertools.product([[],[100],[100,101,100],[0x7f000000,100]],[-1,0,1,3],[0,1,2],[0,1,2])]
out=m.root/'backups/animations/native-counterspell-selection-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,counts=counts,selections=selects,validations=validations,removals=removals,rounds=rounds))+'\n');print(json.dumps(dict(counts=len(counts),selections=len(selects),validations=len(validations),removals=len(removals),rounds=len(rounds),output=str(out))))
