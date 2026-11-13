"""Index verified direct calls to original modal/ordinary activation services.

PE unwind bodies and instruction boundaries are checked. This is static source
evidence, not a runtime modal inventory, computed-call proof or GUI acceptance.
"""
from pathlib import Path
import argparse,bisect,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backups/research-python'))
import pefile,capstone
arg=argparse.ArgumentParser();arg.add_argument('--report',required=True);out=Path(arg.parse_args().report).resolve()
if out.exists():raise SystemExit('Refusing to overwrite evidence')
raw=(ROOT.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(raw).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase;cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True
text=next(s for s in pe.sections if s.Name.rstrip(b'\0')==b'.text');code=text.get_data();origin=base+text.VirtualAddress
spans=sorted((base+r.struct.BeginAddress,base+r.struct.EndAddress)for r in pe.DIRECTORY_ENTRY_EXCEPTION);starts=[s[0]for s in spans]
targets={0x1401fbe40:'modal_activate',0x1401f66f0:'modal_insert',0x1401f6490:'modal_remove_or_promote',0x1401fbe70:'ordinary_activate',0x1401fc470:'deactivate'}
owners={};outside=[]
for byte in [b'\xe8',b'\xe9']:
 at=code.find(byte)
 while at>=0:
  if at+5<=len(code):
   address=origin+at;target=address+5+int.from_bytes(code[at+1:at+5],'little',signed=True)
   if target in targets:
    index=bisect.bisect_right(starts,address)-1
    if index<0 or address>=spans[index][1]:outside.append({'address':hex(address),'target':hex(target)})
    else:owners.setdefault(spans[index],[]).append((address,target))
  at=code.find(byte,at+1)
def source_string(address):
 try:
  offset=pe.get_offset_from_rva(address-base)
  chunk=raw[offset:offset+160];end=chunk.find(b'\0')
  if end<4:return None
  value=chunk[:end]
  if all(32<=v<127 for v in value)and any(65<=v<=90 or 97<=v<=122 for v in value):return value.decode('ascii')
 except (pefile.PEFormatError,ValueError,OverflowError):pass
 return None
rows=[]
for (start,end),candidates in sorted(owners.items()):
 offset=pe.get_offset_from_rva(start-base);body=raw[offset:offset+end-start];ins=list(cs.disasm(body,start));positions={i.address:i for i in ins}
 calls=[];strings=[]
 for address,target in candidates:
  i=positions.get(address)
  if i is not None and i.mnemonic in ['call','jmp']and len(i.operands)==1 and i.operands[0].type==capstone.x86.X86_OP_IMM and i.operands[0].imm==target:calls.append({'address':hex(address),'target':hex(target),'service':targets[target],'instruction':i.mnemonic+' '+i.op_str})
 if not calls:continue
 for i in ins:
  for op in i.operands:
   if op.type==capstone.x86.X86_OP_MEM and op.mem.base==capstone.x86.X86_REG_RIP:
    address=i.address+i.size+op.mem.disp;value=source_string(address)
    if value is not None and value not in [r['value']for r in strings]:strings.append({'instruction':hex(i.address),'address':hex(address),'value':value})
 rows.append({'start':hex(start),'endExclusive':hex(end),'bodySha256':hashlib.sha256(body).hexdigest(),'boundary':'PE unwind body; cold/chained code may have separate entries','calls':calls,'strings':strings,'assembly':[f'{i.address:#x}: {i.mnemonic} {i.op_str}'for i in ins],'completeLinearDecode':bool(ins)and ins[-1].address+ins[-1].size==end})
result={'success':True,'binarySha256':digest,'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'services':{hex(k):v for k,v in targets.items()},'procedures':rows,'unownedCandidates':outside,'scope':'Static direct-call/member-service index only; no complete indirect caller inventory or runtime modal classification/interaction claim. Original body bytes unchanged.','gpu':False,'servers':0,'nativeBuilds':0}
out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'success':True,'procedures':len(rows),'callsByService':{name:sum(c['service']==name for r in rows for c in r['calls'])for name in targets.values()},'report':str(out)}))
