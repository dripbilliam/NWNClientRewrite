"""Finite unchanged6f7160 top-modal close decision proof.

Author original-layout manager/list/window memory. Capture set allocation/insert,
virtual type getter and final deactivate helpers; no real window/process/server.
"""
from pathlib import Path
import argparse,hashlib,json,struct,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backups/research-python'))
import pefile,unicorn,capstone
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
p=argparse.ArgumentParser();p.add_argument('--report',required=True);output=Path(p.parse_args().report).resolve()
if output.exists():raise SystemExit('Refusing to overwrite original observation')
image=(ROOT.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(image).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=image);base=pe.OPTIONAL_HEADER.ImageBase
START,END,RMNU=0x1406f7160,0x1406f73d3,0x524d6e75
body=pe.get_data(START-base,END-START)
prior=json.loads((ROOT/'godot-client/reports/native-gui-panel-access-original-v2.json').read_text())
assert hashlib.sha256(body).hexdigest()==next(v['sha256']for v in prior['functions']if v['name']=='disable')
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x100000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
q=lambda at:int.from_bytes(u.mem_read(at,8),'little')
def wq(at,n):u.mem_write(at,struct.pack('<Q',n))
def wi(at,n):u.mem_write(at,struct.pack('<I',n&0xffffffff))
client,manager,array,node=heap+0x10000,heap+0x1000,heap+0x2000,heap+0x50000
wq(0x1406f738d+0xbe8523,manager)
events=[];trace=[];windows={};case={};returned=False
def finish(value=0):
 sp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RAX,value);u.reg_write(UC_X86_REG_RIP,q(sp));u.reg_write(UC_X86_REG_RSP,sp+8)
def hook(_u,address,size,_data):
 global returned
 if address==stop:returned=True;u.emu_stop();return
 if address==0x1406f57c0:
  expected=client+(case['panel']+0x3d)*16
  assert u.reg_read(UC_X86_REG_RCX)==expected
  assert int.from_bytes(u.mem_read(u.reg_read(UC_X86_REG_RDX),4),'little')==case['target']
  wi(node+0x1c,case['target']);events.append({'kind':'captured-set-find'});finish(node)
 elif address==0x1406f5b20:events.append({'kind':'captured-set-insert'});finish()
 elif address==stop+0x100:
  window=u.reg_read(UC_X86_REG_RCX);assert window in windows
  events.append({'kind':'virtual-type','window':window,'value':windows[window]});finish(windows[window])
 elif address==0x1401fc470:
  events.append({'kind':'deactivate','window':u.reg_read(UC_X86_REG_RCX),'argument':u.reg_read(UC_X86_REG_RDX)});finish()
 elif not START<=address<END:raise RuntimeError('Uncaptured helper '+hex(address))
 trace.append(hex(address))
 if len(trace)>48:trace.pop(0)
u.hook_add(UC_HOOK_CODE,hook)
def execute(panel,target,types):
 global case,returned,windows
 case={'panel':panel,'target':target};returned=False;events.clear();trace.clear();windows={}
 u.mem_write(client,bytes(0x800));u.mem_write(manager,bytes(0x100));u.mem_write(array,bytes(0x100))
 wi(manager+0x90,len(types));wq(manager+0x88,array)
 for index,kind in enumerate(types):
  if kind is None:wq(array+index*8,0);continue
  window=heap+0x20000+index*0x100;vtable=heap+0x30000+index*0x100
  windows[window]=RMNU if kind=='Rmnu'else 0x4f746872
  wq(array+index*8,window);wq(window,vtable);wq(vtable+0x20,stop+0x100)
 for register in [UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R9,UC_X86_REG_R10,UC_X86_REG_R11,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(register,0)
 sp=stack+0xff08;wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,client);u.reg_write(UC_X86_REG_RDX,panel&0xffffffff);u.reg_write(UC_X86_REG_R8,target)
 u.emu_start(START,stop+1,count=2000);assert returned,'Finite instruction bound exceeded'
 closes=[e for e in events if e['kind']=='deactivate'];queries=[e for e in events if e['kind']=='virtual-type']
 wanted=16<=panel<=22 and bool(types) and types[-1]=='Rmnu'
 top=heap+0x20000+(len(types)-1)*0x100 if types and types[-1]is not None else None
 assert closes==([{'kind':'deactivate','window':top,'argument':0}]if wanted else []),(case,types,events)
 assert len(queries)==int(16<=panel<=22 and top is not None)
 assert len([e for e in events if e['kind']=='captured-set-insert'])==int(0<=panel<=22)
 return {'panel':panel,'target':target,'modalTypes':types,'closeTop':wanted,'deactivateCalls':len(closes),'typeQueries':len(queries),'events':list(events)}
rows=[];failure=None
try:
 for panel in [16,17,18,19,20,21,22,9,10,11,-1,23]:
  for target in [0,0x80000002,0x7f000000,0xffffffff]:
   for types in [[],[None],['Rmnu'],['other'],['Rmnu','other'],['other','Rmnu'],['Rmnu','Rmnu'],['Rmnu',None],[None,'Rmnu'],['other',None,'Rmnu']]:rows.append(execute(panel,target,types))
except Exception as error:failure={'type':type(error).__name__,'message':str(error),'trace':trace,'case':case}
cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
result={'success':failure is None,'checks':len(rows),'binarySha256':digest,'function':{'start':hex(START),'endExclusive':hex(END),'sha256':hashlib.sha256(body).hexdigest()},'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'failure':failure,'rows':rows,'modalTailAssembly':[f'{i.address:#x}: {i.mnemonic} {i.op_str}'for i in cs.disasm(pe.get_data(0x1406f7386-base,END-0x1406f7386),0x1406f7386)],'boundary':'Full unchanged original6f7160 executed. Original-layout manager/list/vtable memory authored; set allocation/insertion, virtual type getter and final deactivate captured. Proves current-last-modal-only decision/arguments, not real GUI stack activation, set contents, deactivation implementation, server/native UI or pixels.','runtime':{'unicorn':unicorn.__version__,'capstone':capstone.__version__},'gpu':False,'processes':0,'servers':0,'nativeBuilds':0}
output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'success':result['success'],'checks':len(rows),'report':str(output),'failure':failure}));raise SystemExit(0 if failure is None else 1)
