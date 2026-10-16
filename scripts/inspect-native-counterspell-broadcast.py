"""Untouched BroadcastSpellCast384300 and BroadcastCounterSpellData48e960.
Captured lower boundaries: counter-count/resource queries/validation, skill,
class/school/rule queries, RNG, client resolution, allocation and CC transport.
Not a network-serialization or independent original-client rendering oracle.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
area,ids,spell,rules,app,vt,message,schools=[m.heap+n*0x1000 for n in range(1,9)]
objects={id:m.heap+0x10000+(id-99)*0x2000 for id in range(99,103)};stats={id:m.heap+0x20000+(id-99)*0x2000 for id in objects};clients={id:m.heap+0x30000+(id-99)*0x1000 for id in objects};classDefs=m.heap+0x40000
def identity(x):return next((id for id,ptr in (stats if x in stats.values() else clients if x in clients.values() else objects).items() if ptr==x),-1)
def query(kind,index,id):calls.append([kind,index,id&0xffffffff]);return int(c.get('available',True) and (id&0xffffffff)==c.get('counterId',1))
def hook(u,a,n,_):
 global allocation,data
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402af4a0:m.finish(spell)
 elif a==0x140392830:calls.append(['count']);m.finish(c.get('count',2))
 elif a==0x140494e80:m.finish(area)
 elif a==0x14055b3d0:m.finish(objects.get(y&0xffffffff,0))
 elif a==0x14055b390:m.finish(clients.get(y&0xffffffff,0) if y!=101 else 0)
 elif a==m.stop+0x10:m.finish(objects[99])
 elif a==m.stop+0x20:m.finish(area)
 elif a==0x1403d5850:
  ptr=m.heap+0xf000;m.wi(ptr+4,3);m.finish(ptr if c.get('visible',True) else 0)
 elif a==0x140406a40:calls.append(['skill',identity(x)]);m.finish(c.get('rank',5)&255)
 elif a==0x1403fa4a0:m.finish(0)
 elif a==0x1404069d0:m.finish(c.get('specialization',0))
 elif a==0x1401a7010:m.wi(w,c.get('opposition',1));m.finish(1)
 elif a==0x140404f80:
  result=query('ready',y&255,z);u.mem_write(w,bytes([2]));u.mem_write(m.q(rsp+0x28),bytes([0]));m.finish(result)
 elif a==0x140409160:m.finish(query('uses',z&255,y))
 elif a==0x1402af530:calls.append(['level',y&255]);m.finish(2)
 elif a==0x1403aae30:calls.append(['validate',identity(x),y&0xffffffff,z&255,w&255]);m.wi(x+0x7fc,y);m.finish()
 elif a==0x1402ae870:m.finish(0)
 elif a==0x1402a4130:m.finish(z)
 elif a in [0x140c10324,0x140c10368]:allocation+=1;m.finish(m.heap+0x9000+allocation*0x100)
 elif a in [0x140c10370,0x140c4f024,0x140c10360,0x140108d50]:m.finish()
 elif a==0x14008ae10:identified.append(y&0xffffffff);m.finish()
 elif a==0x1402da770:data['objects'][str(y&0xffffffff)]=z&0xffffffff;m.finish()
 elif a==0x1402da730:data['integers'][str(y&0xffffffff)]=z&0xffffffff;m.finish()
 elif a==0x1402d57f0:m.finish(int(data['objects'].get(str(y&0xffffffff),0x7f000000)))
 elif a==0x1402ad680:calls.append(['roll']);m.finish(c.get('draw',0)%20+1)
 elif a==0x140c7ed00:calls.append(['random']);m.finish(c.get('draw',0))
 elif a in [0x14055b810,0x14055b850]:m.finish(app)
 elif a==0x140296470:m.wq(z,area);m.finish(0)
 elif a==0x1404cf090:calls.append(['send',y&0xffffffff,z&255,json.loads(json.dumps(data))]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140384300,0x140384e52),(0x14048e960,0x14048ecec)]):raise AssertionError(f'Uncaptured broadcast dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,kind):
 global c,calls,identified,data,allocation
 c=case;calls=[];identified=[];data={'objects':{},'integers':{}};allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,rules);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(rules+0xd0,rules);m.wq(rules+0x110,classDefs);m.wq(rules+0x130,schools);m.wq(schools+0x290,schools);m.wf(rules+0x18,10)
 m.wq(area,vt);m.wq(vt+0x20,m.stop+0x10);m.wq(vt+0x50,m.stop+0x20);m.wq(area+0x228,ids);m.wi(area+0x230,4)
 for i,id in enumerate(objects):
  obj=objects[id];m.wq(obj,vt);m.wi(obj+8,id);m.wq(obj+0xad0,stats[id]);m.wi(obj+0xa0,88);m.wi(ids+i*4,id);m.wi(clients[id]+0x48,id);u.mem_write(stats[id]+0xd8,bytes([1 if id==100 else 0]));m.wf(obj+0xa4,0 if id==99 else c.get('distance',2) if id==100 else 3 if id==101 else 50)
 m.wi(classDefs+0x4d8,1);m.wi(classDefs+0x4ec,c.get('memo',1));m.wi(classDefs+0x4f8,1)
 actor=objects[99];viewer=objects[100];u.mem_write(viewer+0x6ef,bytes([c.get('mode',4)]));m.wi(viewer+0x6f4,c.get('target',99));m.wi(viewer+0xa0,c.get('areaId',88));m.wi(actor+0x760,c.get('haste',0));m.wi(viewer+0x760,c.get('candidateHaste',0));m.wi(viewer+0x7fc,0xffffffff)
 for i,id in enumerate((c.get('initial',[])+[0x7f000000]*10)[:10]):m.wi(actor+0x310+i*4,id)
 m.wi(actor+0x338,len(c.get('initial',[])));u.mem_write(spell+0x184,bytes([c.get('userType',1)]));m.wi(spell+0x190,c.get('alt',0));u.mem_write(spell+0x6f,bytes([c.get('innate',1)]));u.mem_write(spell+0x29,b'\1');m.wi(spell+0x17c,2);m.wi(spell+0x180,3)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
 if kind=='broadcast':u.reg_write(UC_X86_REG_RDX,1);u.reg_write(UC_X86_REG_R8,c.get('classIndex',0));u.reg_write(UC_X86_REG_R9,c.get('feat',65535));start=0x140384300
 else:
  data={'objects':{'0':99,'1':100},'integers':{'0':101,'1':102}};u.reg_write(UC_X86_REG_RDX,spell);u.reg_write(UC_X86_REG_R8,message);start=0x14048e960
 u.emu_start(start,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,identified=identified,count=m.si(actor+0x338),ids=[m.si(actor+0x310+i*4)&0xffffffff for i in range(10)],selected=m.si(viewer+0x7fc))
broadcasts=[run(dict(rank=rank,draw=draw,memo=memo,available=available,haste=haste,candidateHaste=candidateHaste),'broadcast') for rank,draw,memo,available,haste,candidateHaste in itertools.product([-128,0,10,127],[0,19],[0,1],[False,True],[0,1],[0,1])]
broadcasts += [run(dict(specialization=specialization,opposition=opposition,counterId=counterId,distance=distance,initial=initial),'broadcast') for specialization,opposition,counterId,distance,initial in itertools.product([0,1,2],[1,9],[1,2,94],[10,10.000001],[[],[101]*10])]
broadcasts += [run(dict(userType=userType,alt=alt,visible=visible,classIndex=index,feat=feat),'broadcast') for userType,alt,visible,index,feat in itertools.product([0,1],[0,1],[False,True],[0,254],[65535,12])]
feedback=[run(dict(rank=rank,draw=draw,specialization=specialization,opposition=opposition,distance=distance),'feedback') for rank,draw,specialization,opposition,distance in itertools.product([-128,0,10,127],[0,19],[0,1,2],[1,9],[2,30,30.000001])]
out=m.root/'backups/animations/native-counterspell-broadcast-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,broadcasts=broadcasts,feedback=feedback))+'\n');print(json.dumps(dict(broadcasts=len(broadcasts),feedback=len(feedback),output=str(out))))
