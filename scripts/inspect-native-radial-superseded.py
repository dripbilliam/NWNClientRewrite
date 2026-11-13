"""Execute actual prior-top virtual dispatch/guards; capture final menu deactivate.

Original PE/vtables unchanged. Manager/widget/model memory is authored. This
does not run deactivation implementation or equate an unknown native guard with
any current Godot input/drag flag. Static guard writers are retained separately.
"""
from pathlib import Path
import argparse,bisect,hashlib,json,struct,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'backups/research-python'))
import pefile,capstone,unicorn
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);out=Path(parser.parse_args().report).resolve()
if out.exists():raise SystemExit('Refusing to overwrite evidence')
raw=(ROOT.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(raw).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase;cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True
guard_ins=next(i for i in cs.disasm(pe.get_data(0x1f9330,0x18),0x1401f9330)if any(o.type==capstone.x86.X86_OP_MEM and o.mem.base==capstone.x86.X86_REG_RIP for o in i.operands))
guard=guard_ins.address+guard_ins.size+next(o.mem.disp for o in guard_ins.operands if o.type==capstone.x86.X86_OP_MEM)
u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x10000);u.mem_map(stop,0x1000)
q=lambda a:int.from_bytes(u.mem_read(a,8),'little')
def wq(a,n):u.mem_write(a,struct.pack('<Q',n))
returned=False;events=[];window=heap+0x1000
def hook(_u,address,size,_data):
 global returned
 if address==stop:returned=True;u.emu_stop();return
 if address==0x1401f8a00:
  assert u.reg_read(UC_X86_REG_RCX)==window;events.append('menu-deactivate-request')
  sp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(sp));u.reg_write(UC_X86_REG_RSP,sp+8);return
 if not(0x1401f9320<=address<0x1401f9348 or 0x1401ee980<=address<0x1401ee983):raise RuntimeError('Unexpected original helper '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
rtti=json.loads((ROOT/'godot-client/reports/native-gui-modal-rtti-v2.json').read_text());owners=[r for r in rtti['guiTypes']if r['radialBase']]+[r for r in rtti['guiTypes']if r['type']in['.?AVCPanelOkCancel@@','.?AVCGuiItemStackSplitPanel@@']]
rows=[]
for owner in owners:
 for table in owner['tables']:
  t=int(table['address'],16)
  for model in [False,True]:
   for protected in ['none','self','other']:
    for slot in ([0x138,0xc0]if owner['radialBase']else[0x138]):
     u.mem_write(window,bytes(0x1000));wq(window,t);wq(window+0xa0,heap+0x4000 if model else 0);wq(guard,{'none':0,'self':window,'other':heap+0x6000}[protected]);sp=stack+0xff08;wq(sp,stop)
     u.reg_write(UC_X86_REG_RCX,window);u.reg_write(UC_X86_REG_RSP,sp);returned=False;events.clear();u.emu_start(q(t+slot),stop+1,count=100)
     expected=bool(owner['radialBase']and model and protected!='self');assert returned and bool(events)==expected,(owner['type'],model,protected,slot,events)
     rows.append({'type':owner['type'],'vtable':hex(t),'slot':slot,'modelPresent':model,'protectedPointer':protected,'deactivateRequested':bool(events)})
# Exact RIP references to the protected pointer; verify each within its full
# original unwind body, rather than treating a coincidental byte hit as a call.
section=next(s for s in pe.sections if s.Name.rstrip(b'\0')==b'.text');code=section.get_data();origin=base+section.VirtualAddress;spans=sorted((base+r.struct.BeginAddress,base+r.struct.EndAddress)for r in pe.DIRECTORY_ENTRY_EXCEPTION);starts=[s[0]for s in spans];refs={}
for rex in [b'\x48',b'\x4c']:
 for opcode,length in [(0x8b,7),(0x89,7),(0x8d,7),(0x39,7),(0x3b,7),(0xc7,11),(0x83,8)]:
  prefix=rex+bytes([opcode]);at=code.find(prefix)
  while at>=0:
   address=origin+at
   if at+length<=len(code)and code[at+2]&0xc7==5 and address+length+int.from_bytes(code[at+3:at+7],'little',signed=True)==guard:
    index=bisect.bisect_right(starts,address)-1
    if index>=0 and address<spans[index][1]:refs.setdefault(spans[index],set()).add(address)
   at=code.find(prefix,at+1)
writers=[]
for(start,end),addresses in sorted(refs.items()):
 body=pe.get_data(start-base,end-start);instructions=list(cs.disasm(body,start));matched=[]
 for i in instructions:
  if i.address not in addresses:continue
  for n,o in enumerate(i.operands):
   if o.type==capstone.x86.X86_OP_MEM and o.mem.base==capstone.x86.X86_REG_RIP and i.address+i.size+o.mem.disp==guard:matched.append({'address':hex(i.address),'instruction':i.mnemonic+' '+i.op_str,'operandIndex':n,'access':o.access})
 if matched:writers.append({'start':hex(start),'endExclusive':hex(end),'sha256':hashlib.sha256(body).hexdigest(),'references':matched,'assembly':[f'{i.address:#x}: {i.mnemonic} {i.op_str}'for i in instructions]})
result={'success':True,'checks':len(rows),'binarySha256':digest,'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'guard':{'address':hex(guard),'comparison':guard_ins.mnemonic+' '+guard_ins.op_str,'meaning':'Unclassified native protected-menu pointer; no Godot field alias inferred'},'rows':rows,'guardReferences':writers,'scope':'Unchanged actual vtables/prior-top callbacks/C0 guard execution; authored owner/model/global state; final CGuiMenu deactivation captured, not executed. Static writer bodies do not prove runtime reachability. No game process/window/server/GPU/build.','runtime':{'unicorn':unicorn.__version__,'capstone':capstone.__version__},'gpu':False,'processes':0,'servers':0,'nativeBuilds':0}
out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps({'success':True,'checks':len(rows),'guard':hex(guard),'guardFunctions':[r['start']for r in writers],'report':str(out)}))
