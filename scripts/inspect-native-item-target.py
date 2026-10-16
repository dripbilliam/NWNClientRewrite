"""Original item ActivateActionTarget1407039f0, nested spell setup140703ea0,
creature veto140703d00, confirmation140703860 and client UseItem140805740.
Canonical client lookups, metadata, UI reset/types/preview/disposal, final input
and transport are captured. No real pointer picking or packet encoding claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
state,item,prop,spell,child,base,app,rules,inventory,container,actor,target,point,icon,transport=[m.heap+n*0x1000 for n in range(1,16)]
q,si,wi,wq,wf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','finish']]
def xyz(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def hook(u,a,n,_):
 global reset,activated
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406abc80:
  calls.append(['item',y&0xffffffff]);finish(target if kind=='confirm' and c.get('targetItem') else item if kind!='confirm' and c.get('item',True) else 0)
 elif a==0x14083d580:calls.append(['property',y&0xffffffff]);finish(prop if c.get('property',True) else 0)
 elif a==0x14083bcf0:reset=True;calls.append(['reset']);finish()
 elif a==0x14083d6d0:calls.append(['propertySpell',y&0xffff]);finish(100)
 elif a==0x1402af4a0:
  id=y&0xffffffff;calls.append(['spell',id]);finish(spell if id==100 and c.get('spell',True) else child if id==201 and not c.get('childMissing') else 0)
 elif a==0x1402af850:calls.append(['subRadialSpell',y&255]);finish(201 if (y&255)<c.get('children',0) else -1)
 elif a==0x14029ca00:calls.append(['baseInfo']);finish(base if c.get('base',True) else 0)
 elif a==0x1406abbe0:finish(inventory)
 elif a==0x1406abfd0:finish(container)
 elif a==0x1406ac1c0:calls.append(['controlledId']);finish(99)
 elif a==0x1406ac1a0:calls.append(['player']);finish(actor if c.get('actor',True) else 0)
 elif a==0x1406ab9e0:calls.append(['creature',y&0xffffffff]);finish(actor if c.get('targetCreature',True) and c.get('self') else target if c.get('targetCreature',True) else 0)
 elif a==0x14083bac0:calls.append(['type',y&0xffffffff,z&0xffffffff]);finish()
 elif a==0x140704a50:u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',3.5))[0]);finish()
 elif a==0x140704bd0:calls.append(['preview',w&0xffffffff]);finish()
 elif a==0x140703860 and kind=='activate':calls.append(['confirm',y&0xffffffff]);finish()
 elif a==0x14083b9e0:activated=True;calls.append(['activate']);finish()
 elif a==0x140115890:calls.append(['warning']);finish()
 elif a==0x140805740 and kind=='confirm':calls.append(['use',y&0xffffffff,z&0xffffffff,w&0xffffffff,xyz(q(rsp+0x28))]);finish()
 elif a==0x140704bb0:calls.append(['clearPreview',x&0xffffffff]);finish()
 elif a==0x140704b90:calls.append(['clearRange',m.xmm(UC_X86_REG_XMM0)]);finish()
 elif a==0x14083b890:calls.append(['dispose']);finish()
 elif a==0x140c10360:calls.append(['free',y&0xffffffff]);finish()
 elif a==0x1406abf90:finish(transport if c.get('transport',True) else 0)
 elif a==0x1407c0610:calls.append(['transport',y&0xffffffff,z&255,w&0xffffffff,si(rsp+0x28)&0xffffffff,xyz(q(rsp+0x30))]);finish()
 elif a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x1407039f0,0x140703d00),(0x140703ea0,0x140704180),(0x140703d00,0x140703e20),(0x140703860,0x140703968),(0x140805740,0x1408057b4)]):raise AssertionError(f'Uncaptured item target dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,which):
 global c,kind,calls,reset,activated
 c=case;kind=which;calls=[];reset=activated=False;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));wq(0x1412df970,app);wq(app,app);wq(0x1412df8f8,rules);wq(rules+0xd0,rules);wq(rules+0x20,rules)
 u.mem_write(prop,struct.pack('<H',c.get('type',15)));wi(item+0x40,50);u.mem_write(spell+0x50,struct.pack('<H',c.get('mask',3)));u.mem_write(child+0x50,struct.pack('<H',c.get('childMask',9)));u.mem_write(spell+0x170,bytes([c.get('children',0)]));u.mem_write(base+0xad,bytes([c.get('behavior',0)]));u.mem_write(0x1412970e8,bytes([c.get('autoSelf',1)]));wi(inventory+0xb0,c.get('inventoryMode',0));wi(container+0xb0,c.get('containerMode',0));wi(actor+8,99);wi(target+8,100);wi(target+0x264,77)
 packed=(c.get('index',0)&65535)|((c.get('variant',255)&65535)<<16);wi(state+0x150,55);wi(state+0x154,packed);wi(state+0x14c,c.get('targetId',100))
 for ptr,values in [(state+0x140,[1.25,2.5,3.75]),(target+0x80,[10,20,30]),(actor+0x38,[40,50,60]),(target+0x38,[40,50,60]),(point,[1.25,2.5,3.75])]:
  for i,v in enumerate(values):wf(ptr+i*4,v)
 rsp=m.stack+0x1fc08;wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[state,55,packed,icon] if kind=='activate' else [state,c.get('targetId',100),0,0] if kind=='veto' else [state,packed,0,0] if kind=='confirm' else [actor,55,packed,c.get('targetId',100)]
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v&0xffffffffffffffff)
 if kind=='transport':wq(rsp+0x28,point)
 u.emu_start({'activate':0x1407039f0,'veto':0x140703d00,'confirm':0x140703860,'transport':0x140805740}[kind],m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,reset=reset,activated=activated,flags=q(state+0x118),point=xyz(state+0x140),targetId=si(state+0x14c)&0xffffffff)
activate=[dict(type=t,mask=mask,behavior=b,autoSelf=auto,inventoryMode=inv,containerMode=cont) for t,mask,b,auto,inv,cont in itertools.product([15,55,70,80,1],[0,1,2,3,4,5,9,127],[0,2],[0,1],[0,1],[0,1])]
activate += [dict(children=2,variant=v,childMissing=missing) for v,missing in itertools.product([0,1,255,256,65535],[False,True])]+[dict(**{key:False}) for key in ['item','property','spell','base']]
veto=[dict(mask=mask,self=self,targetCreature=cr,children=children,variant=variant) for mask,self,cr,children,variant in itertools.product([0,1,2,3,9,127],[False,True],[False,True],[0,1],[0,255,65535])]+[dict(item=False),dict(spell=False)]
confirms=[dict(actor=a,targetItem=i,targetCreature=cr,self=self) for a,i,cr,self in itertools.product([False,True],[False,True],[False,True],[False,True])]
transports=[dict(index=i,variant=v,transport=t) for i,v,t in itertools.product([0,255,256,65535],[0,255,32768,65535],[False,True])]
out=m.root/'backups/animations/native-item-target-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,activate=[run(c,'activate') for c in activate],veto=[run(c,'veto') for c in veto],confirm=[run(c,'confirm') for c in confirms],transport=[run(c,'transport') for c in transports]))+'\n');print(json.dumps(dict(activate=len(activate),veto=len(veto),confirm=len(confirms),transport=len(transports),output=str(out))))
