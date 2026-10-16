"""Complete original UseFeat1403a91d0 with lower ownership, uses,
equipment/modes, AddAttack/SpellActions, effect removal and event providers
captured. GetSubRadialSpell executes unchanged. These synthetic boundaries do
not prove complete combat, effect scripts, transport or campaign acceptance.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,target,feat,item,baseitem,area,rules,manager,vt,roundstate,childids,effect,payload,fxlist=[m.heap+n*0x1000 for n in range(1,16)]
parent=m.heap+0x30000;children=[m.heap+0x32000+n*0x1000 for n in range(4)]
def textat(ptr):return bytes(u.mem_read(ptr,160)).split(b'\0',1)[0].decode('ascii') if ptr else ''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404029b0:calls.append(['highest',y&65535]);m.finish(c['highest'])
 elif a==0x14040b900:
  id=y&65535;calls.append(['hasFeat',id]);m.finish(c['owned'] if id==c['highest'] else int(id in c['extraFeats']))
 elif a==0x1402a3bd0:calls.append(['feat',y&65535]);m.finish(0 if c['missingFeat'] else feat)
 elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(target if c['targetExists'] else 0)
 elif a==m.stop+0x10:calls.append(['asCreature']);m.finish(target if c['targetCreature'] else 0)
 elif a==0x1404ab6c0:calls.append(['reaction',y&0xffffffff]);m.finish(c['reaction'])
 elif a==0x1404012f0:calls.append(['remaining',y&65535]);m.finish(c['remaining'])
 elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);m.finish()
 elif a==0x1403d54d0:calls.append(['possessed']);m.finish(c['possessed'])
 elif a==0x14037d180:calls.append(['attack',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(c['addResult'])
 elif a==0x140392f80:calls.append(['ranged']);m.finish(c['ranged'])
 elif a==0x1403d8c50:calls.append(['mode',y&255,z&0xffffffff]);m.finish()
 elif a==0x140462bd0:calls.append(['equipped',y&0xffffffff]);m.finish(item if c['item'] else 0)
 elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);m.finish(baseitem)
 elif a==0x1403fa4a0:calls.append(['classType',y&255]);m.finish(c['classes'][y&255])
 elif a==0x140392fd0:calls.append(['relativeSize']);m.finish(c['relativeSize'])
 elif a==0x1404033e0:calls.append(['weaponOfChoice',y&0xffffffff]);m.finish(c['weaponOfChoice'])
 elif a==0x140374da0:calls.append(['special',y&65535]);m.finish()
 elif a==0x140c7ed00:calls.append(['random']);m.finish(c['random'])
 elif a==0x14037cbc0:calls.append(['manager',y&0xffffffff]);m.finish()
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(target if c['targetCreature'] else 0)
 elif a==0x140425210:calls.append(['setInteger',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x140498280:calls.append(['remove',y]);m.finish()
 elif a==0x1402af4a0:
  id=y&0xffffffff;calls.append(['spell',id]);ptr=parent if id==c['spellId'] else children[id-100] if 100<=id<100+len(c['children']) else 0;m.finish(0 if c['missingSpell'] or id in c['missingChildren'] else ptr)
 elif a==0x140c10324:calls.append(['allocate']);m.finish(0 if c['allocationFail'] else payload)
 elif a==0x140c10370:m.finish()
 elif a==0x14003d8c0:m.wq(x,y);m.wi(x+8,z);m.wi(x+12,z+1);m.finish(x)
 elif a==0x140494e80:calls.append(['area']);m.finish(area if c['area'] else 0)
 elif a==0x14055b960:m.finish(manager)
 elif a==0x1405570b0:
  ptr=m.q(rsp+0x38);calls.append(['enqueue',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(ptr),int.from_bytes(u.mem_read(ptr+4,2),'little'),m.si(ptr+8)&0xffffffff,m.si(ptr+0xc)&0xffffffff,m.si(ptr+0x10)&0xffffffff,[m.rf(ptr+0x14+i*4) for i in range(3)],textat(m.q(ptr+0x20)),m.si(ptr+0x30)&0xffffffff]);m.finish()
 elif a==0x1403f2750:calls.append(['decrement',y&65535]);m.finish()
 elif a==0x14037d540:
  calls.append(['cast',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255,m.si(rsp+0x30),[m.rf(m.q(rsp+0x38)+i*4) for i in range(3)],m.si(rsp+0x40)&0xffffffff,*[m.si(rsp+off) for off in [0x48,0x50,0x58,0x60,0x68,0x70,0x78]],m.si(rsp+0x80)&255]);m.finish(c['addResult'])
 elif a==0x140115890:calls.append(['warning','CNWSCreature::UseFeat() Invalid Feat' if textat(m.q(rsp+0x38)).startswith('CNWSCreature') else 'No behaviour defined for this feat!']);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403a91d0,0x1403a9f68),(0x1402af850,0x1402af8c2)]):raise AssertionError(f'Uncaptured UseFeat dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
default=dict(requested=257,highest=257,auxiliary=0,targetId=100,targetExists=True,targetCreature=True,owned=1,state=0,hostile=0,reaction=0,remaining=1,pc=0,possessed=0,ranged=0,item=False,baseItem=8,baseRanged=0,monkWeapon=0,classes=[],extraFeats=[],relativeSize=-1,weaponOfChoice=1,random=2,reqAction=1,targetSelf=0,spellId=50,missingSpell=False,missingFeat=False,children=[],missingChildren=[],targetMask=3,point=None,locked=0,hasEffect=False,allocationFail=False,area=True,hasStats=True,addResult=1)
def run(case):
 global c,calls
 c=default|case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,manager);m.wq(manager+8,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wq(rules+0x20,rules)
 m.wq(actor+0xad0,stats if c['hasStats'] else 0);m.wi(actor+8,99);u.mem_write(actor+0x771,bytes([c['state']&255]));m.wi(actor+0x89c,c['pc']);m.wq(actor+0x950,item);m.wq(actor+0x880,roundstate);u.mem_write(stats+0xd8,bytes([len(c['classes'])]));m.wq(target,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(target+0x97c,c['locked']);m.wi(feat+0x30,c['hostile']);m.wi(feat+0x2c,c['targetSelf']);m.wi(feat+0x60,c['spellId']);m.wi(feat+0x70,c['reqAction']);m.wi(item+0x40,c['baseItem']);u.mem_write(baseitem+0x18,bytes([c['baseRanged']&255]));m.wi(baseitem+0xc0,c['monkWeapon']);m.wi(area+0x140,7)
 m.wq(target+0x150,fxlist);m.wi(target+0x158,int(c['hasEffect']));m.wq(fxlist,effect);m.wq(effect,123);u.mem_write(effect+8,struct.pack('<H',62));u.mem_write(parent+0x50,struct.pack('<H',c['targetMask']));m.wq(parent+0x168,childids);u.mem_write(parent+0x170,bytes([len(c['children'])]));m.wq(parent+0x58,m.heap+0x70000);m.wi(parent+0x60,7);u.mem_write(m.heap+0x70000,b'parent\0')
 for i,value in enumerate(c['children']):m.wi(childids+i*4,100+i);m.wi(children[i]+0x198,value);m.wq(children[i]+0x58,m.heap+0x71000+i*0x100);m.wi(children[i]+0x60,7);u.mem_write(m.heap+0x71000+i*0x100,f'child{i}'.encode()+b'\0')
 point=m.heap+0x72000
 if c['point'] is not None:
  for i,v in enumerate(c['point']):m.wf(point+i*4,v)
 rsp=m.stack+0x1fc08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,c['requested'],c['auxiliary'],c['targetId']]):u.reg_write(reg,v)
 m.wi(rsp+0x28,7);m.wq(rsp+0x30,point if c['point'] is not None else 0)
 u.emu_start(0x1403a91d0,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls)
if __name__=='__main__':
 cases=[dict(highest=id,requested=id,pc=pc,possessed=possessed,ranged=ranged,item=item) for id,pc,possessed,ranged,item in itertools.product([5,9,16,17,19,23,28,30,31,39,204,257,294,296,301,389,390,425,450,454,472,882,947],[0,1],[0,1],[0,1],[False,True])]
 cases += [dict(highest=204,requested=204,classes=classes,item=True,baseRanged=ranged,monkWeapon=monk,relativeSize=size,extraFeats=feats) for classes,ranged,monk,size,feats in itertools.product([[],[5],[40],[0,5]],[0,1],[0,1],[-1,0],[[],[866],[899]])]
 cases += [dict(reqAction=req,auxiliary=aux,targetMask=mask,point=point,targetId=target,children=children) for req,aux,mask,point,target,children in itertools.product([0,1],[0,1,65535],[1,4,5],[None,[1.25,2.5,3.75]],[100,0x7f000000],[[],[1<<16,2<<16],[0xffff0000,1<<16]])]
 cases += [dict(highest=id,requested=id,auxiliary=aux,locked=1,hasEffect=True,targetSelf=1) for id,aux in itertools.product([304,305,335,339,340,342,872,873,900,902,903,1060,1061,257],[0,1004,1005,1006,1007,1008,1009,1010,1011,1012,999])]
 cases += [dict(**{key:value}) for key,values in dict(owned=[0],state=[5],remaining=[0,256],hostile=[1,2],reaction=[1],targetSelf=[1,-1],spellId=[0,-1],missingSpell=[True],missingFeat=[True],targetCreature=[False],allocationFail=[True],area=[False],hasStats=[False],children=[[1<<16]],missingChildren=[[100]]).items() for value in values if key!='missingFeat']
 cases += [dict(missingFeat=True,targetId=0x7f000000),dict(hostile=1,reaction=1),dict(reqAction=0,allocationFail=True),dict(reqAction=0,hasStats=False),dict(reqAction=0,area=False)]
 results=[run(case) for case in cases];out=m.root/'backups/animations/native-use-feat-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=results))+'\n');print(json.dumps(dict(rows=len(results),output=str(out))))
