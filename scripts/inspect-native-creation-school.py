"""Execute original School prepare/select/Recommended/OK/Cancel/Escape,
programmatic SelectTab/SetChecked and SetSchool. Captured UI/table/lifetime
services and the three spell-clear/recompute/coordinator boundaries remain
explicit. This does not execute spell cache rebuilding or child continuation,
which have independent original evidence. No live process/GPU/server/profile.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,actor,stats,vtable,tabarray,table,rules,classes=[m.heap+n for n in[0x1000,0x5000,0x9000,0xd000,0xe000,0x10000,0x20000,0x30000]]
ranges=[(0x1409ccb40,0x1409cce45),(0x1409c7e40,0x1409c7ea1),(0x1409c9860,0x1409c9a2d),(0x1409c8c60,0x1409c8d05),(0x1409c7d10,0x1409c7d6b),(0x1409c8580,0x1409c85ff),(0x1407fa7c0,0x1407fa823),(0x1401eff30,0x1401eff8c),(0x1401e5ae0,0x1401e5b38)]
case={};texts={};calls=[]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def hook(_u,a,_n,_):
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop:u.emu_stop();return
 if a==0x140800c90:m.finish(actor if case['present'] else 0)
 elif a==0x1401ed880:
  count=m.si(x+0x20);m.wq(x+0x18,tabarray);m.wq(tabarray+count*8,y);m.wi(x+0x20,count+1);m.finish()
 elif a==0x1401fb890:texts[hex(x-panel)]=y&0xffffffff;m.finish()
 elif a in[0x1401fe0b0,0x1401fb540,0x1401eb5c0,0x1409cda40]:m.finish()
 elif a==0x1401eb800:m.wi(x+8,(m.si(x+8)&~1)|(0 if y else 1));m.finish()
 elif a==0x1402ae870:m.finish(0x12345678)
 elif a==0x1402a4130:m.finish(case['recommendedEnabled'])
 elif a in[0x140c10324,0x140c10368]:m.finish(table if x==0x60 else m.heap+0x70000)
 elif a==0x140c10370:m.finish()
 elif a==0x14018ded0:
  data=bytes(u.mem_read(y,17)).split(b'\0',1)[0];u.mem_write(x,(data+b'\0'*17)[:17]);m.finish(x)
 elif a==0x1401a62b0:m.wq(x,vtable);m.finish(x)
 elif a==0x1401a73a0:m.finish(int(case['packagesLoaded']))
 elif a==0x1407f69a0:m.finish(case['oldSchool']&255)
 elif a==0x1407f0f60:m.finish(1)
 elif a==0x1401a7010:
  calls.append(['package-school-read',y&0xffffffff]);m.wi(w,case['recommended']);m.finish(int(case['schoolCellPresent']))
 elif a in[0x1407edae0,0x1407ed850,0x1407faf60]:calls.append([{0x1407edae0:'clear-memorized',0x1407ed850:'clear-known',0x1407faf60:'recompute-slots'}[a],int(u.mem_read(stats+0x292+case['classIndex']*0x150,1)[0])]);m.finish()
 elif a==0x1407edcc0:calls.append(['reset-derived']);m.finish()
 elif a==0x1409c69a0:calls.append(['coordinator',w&0xffffffff,int(u.mem_read(stats+0x292+case['classIndex']*0x150,1)[0])]);m.finish()
 elif a==0x1401fc440:calls.append(['deactivate',y&0xffffffff]);m.finish()
 elif a==m.stop+0x10:
  if x==panel:calls.append(['delete-panel'])
  m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original School dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,*args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(c):
 global case,texts,calls
 case=c;texts={};calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(panel,vtable);m.wq(vtable,m.stop+0x10);m.wq(actor+0x3b0,stats);byte(stats+0x6a,c['classIndex']);byte(stats+0x292+c['classIndex']*0x150,c['oldSchool']);m.wi(stats+0x6c,27);m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);m.wi(classes+0x530+0x4e4,44);m.wi(panel+0x1020,c['mode']);m.wi(panel+0x1058,42);m.wi(panel+0x1038,-1);m.wi(0x14142958c,2)
 for id in range(9):m.wi(0x1412992d0+id*8,1000+id);m.wi(0x1412992d4+id*8,2000+id)
 invoke(0x1409ccb40,panel);initial=dict(selected=m.si(panel+0x1038),help=dict(texts),oldSchool=int(u.mem_read(stats+0x292+c['classIndex']*0x150,1)[0]),recommendEnabled=not bool(m.si(panel+0xf40)&1))
 if c['select'] is not None:
  invoke(0x1401eff30,panel+0x1028,c['select']);invoke(0x1409c7e40,panel,c['select'])
 if c['recommend']:invoke(0x1409c9860,panel)
 selection=dict(selected=m.si(panel+0x1038),help=dict(texts),school=int(u.mem_read(stats+0x292+c['classIndex']*0x150,1)[0]))
 invoke({'ok':0x1409c8c60,'cancel':0x1409c7d10,'escape':0x1409c8580}[c['finish']],panel)
 return dict(input=c,initial=initial,selection=selection,output=dict(school=int(u.mem_read(stats+0x292+c['classIndex']*0x150,1)[0]),stage=m.si(0x14142958c),calls=calls.copy()))
if __name__=='__main__':
 out=m.root/'godot-client/reports/native-creation-school-original-v1.json';assert not out.exists(),'Preserve original evidence'
 rows=[]
 for selected,exists,mode,finish in itertools.product([None,0,1,4,8],[False,True],[0,1],['ok','cancel','escape']):
  rows.append(run(dict(select=selected,present=exists,mode=mode,finish=finish,recommend=False,recommendedEnabled=1,packagesLoaded=True,schoolCellPresent=True,recommended=3,oldSchool=8,classIndex=0)))
 for index,recommended,loaded,cell in itertools.product([0,1],[0,2,8],[False,True],[False,True]):
  rows.append(run(dict(select=None,present=True,mode=0,finish='ok',recommend=True,recommendedEnabled=1,packagesLoaded=loaded,schoolCellPresent=cell,recommended=recommended if cell else 0,oldSchool=7,classIndex=index)))
 out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,ranges=[[hex(a),hex(b)]for a,b in ranges],rows=rows),indent=2)+'\n')
 print(json.dumps(dict(output=str(out),cases=len(rows),publicConnections=0,gpu=False)))
