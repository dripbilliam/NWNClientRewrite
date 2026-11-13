"""Unchanged original Abilities cost, twelve callbacks and recommendation/Cancel.
Reuses original class/ability/vital instructions from the pinned vital harness.
GUI text/help/number/OK delivery, object lookup, ruleset services, allocation and
modal lifetime are explicit providers. It proves raw/stat/point transitions,
not original pixels or complete formatted help/GUI timing/catalog/admission.
"""
import copy,importlib.util,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('vitals',Path(__file__).with_name('inspect-native-creation-vitals.py'))
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=v.u;m=v.m
extra=[(0x1408e05e0,0x1408e06a5+1),(0x1408e06b0,0x1408e078a+1),(0x1408e0790,0x1408e0839+1),(0x1408e73c0,0x1408e74d1+1),(0x1408e7570,0x1408e76ad+1),(0x1408e1560,0x1408e1771+1),(0x1408e1810,0x1408e1a50+1),(0x1408e2240,0x1408e2354+1),(0x1408e23f0,0x1408e2530+1),(0x1408e2780,0x1408e2894+1),(0x1408e2930,0x1408e2a70+1),(0x1408e2df0,0x1408e2f04+1),(0x1408e2fa0,0x1408e30e0+1),(0x1408e7e10,0x1408e8021+1),(0x1408e80c0,0x1408e8300+1),(0x1408e5cf0,0x1408e5e1e+1),(0x1408e1000,0x1408e1030+1),(0x1408e3520,0x1408e3550+1)]
providers=[0x1408ee3d0,0x1408eeaf0,0x1408e09e0,0x14016c810,0x1402023d0,0x14081b220,0x14016afb0,0x140115890,0x140c10370,m.stop+0x20]
v.ranges+=extra+[(a,a+1)for a in providers]
bump=0x80000
def cstring(a):return bytes(u.mem_read(a,128)).split(b'\0')[0].decode('cp1252')
def string(dest,text):
 global bump
 raw=text.encode('cp1252');ptr=m.heap+bump;bump+=max(32,len(raw)+1);u.mem_write(ptr,raw+b'\0');m.wq(dest,ptr);m.wi(dest+8,len(raw));m.wi(dest+12,len(raw)+1)
def ui_hook(u,a,n,_):
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x1408ee3d0,0x1408eeaf0,0x1408e09e0,0x1402023d0,0x14081b220,0x140115890,0x140c10370,m.stop+0x20]:m.finish()
 elif a==0x14016c810:string(x,str(y&0xffffffff));m.finish(x)
 elif a==0x14016afb0:
  text=cstring(y)%(z&0xffffffff,v.signed(w,32));string(x,text);m.finish(x)
u.hook_add(UC_HOOK_CODE,ui_hook)
addresses=[(0x1408e73c0,0x1408e7570),(0x1408e2780,0x1408e2930),(0x1408e2240,0x1408e23f0),(0x1408e2df0,0x1408e2fa0),(0x1408e7e10,0x1408e80c0),(0x1408e1560,0x1408e1810)]
def snapshot():
 s=v.snapshot();s['points']=int(u.mem_read(v.actor+0x10c,1)[0]);return s
def run(c,points):
 global bump
 v.run(c);bump=0x80000;v.byte(v.actor+0x10c,points);m.wq(0x14140cdb8,m.heap+0x70000)
 gui=m.heap+0x68000;vt=m.heap+0x6a000;m.wq(vt+0xd0,m.stop+0x20);m.wq(gui,vt)
 for off in[0x248,0x398,0x4e8,0x638,0x8d8,0xa28,0x6e0]:m.wq(v.panel+off+0x90,gui)
 row=c['tables']['classes']['orderedRows'][c['source']['classId']]
 for at,key in enumerate(v.keys):v.byte(v.classes+c['source']['classId']*0x530+0x49b+at,row[key])
 before=snapshot();results=[]
 for index in range(6):
  for direction in [1,-1]:
   m.wi(m.heap+0x70000+0x18,index);v.call(addresses[index][direction==1],[v.panel]);results.append(dict(operation=dict(kind='step',index=index,direction=direction),state=snapshot()))
 v.call(0x1408e5cf0,[v.panel]);results.append(dict(operation=dict(kind='recommend'),state=snapshot()))
 v.call(0x1408e1000,[v.panel]);results.append(dict(operation=dict(kind='cancel'),state=snapshot()));assert v.deactivated==[2]
 return dict(case=c,initial=before,results=results)
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-ability-points-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 rng=random.Random(82101);old=json.loads((m.root/'backups/animations/native-creation-vitals-observations-v1.json').read_text());rows=[]
 for at in range(96):
  c=copy.deepcopy(old['rows'][at%48]['case']);c['operations']=[];id=c['source']['classId'];row=c['tables']['classes']['orderedRows'][id]
  c['settings'].update([{},dict(CHARGEN_BASE_ABILITY_MIN=6,CHARGEN_BASE_ABILITY_MIN_PRIMARY=13,CHARGEN_BASE_ABILITY_MAX=21,CHARGEN_ABILITY_COST_INCREMENT2=12,CHARGEN_ABILITY_COST_INCREMENT3=15,CHARGEN_ABILITY_COST_INCREMENT4=18),dict(CHARGEN_BASE_ABILITY_MIN=-1,CHARGEN_BASE_ABILITY_MIN_PRIMARY=260,CHARGEN_BASE_ABILITY_MAX=260,CHARGEN_ABILITY_COST_INCREMENT2=3,CHARGEN_ABILITY_COST_INCREMENT3=2,CHARGEN_ABILITY_COST_INCREMENT4=0)][at%3])
  c['tables']['ruleset']['orderedRows']=[dict(Label=k,Value=str(value))for k,value in c['settings'].items()]
  for key in v.keys:c['source']['abilities'][key]=rng.choice([0,1,6,7,8,11,13,14,15,16,17,18,19,127,254,255]);row[key]=rng.choice([0,6,8,12,18,260])
  row['SpellcastingAbil']=v.keys[at%6];row['SpellCaster']=at%2
  rows.append(run(c,[0,1,2,3,4,30,255][at%7]))
 out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows,procedures=[hex(a)for pair in addresses for a in pair]+['0x1408e05e0','0x1408e0790','0x1408e5cf0','0x1408e1000']),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows),operations=sum(len(r['results'])for r in rows))))

