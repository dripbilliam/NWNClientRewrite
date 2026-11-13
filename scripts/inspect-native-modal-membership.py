"""Read-only candidate index for the pinned GUI manager's modal-array owners.

This is static byte/operand evidence, not a claimed complete modal owner map.
"""
from pathlib import Path
import argparse,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'backups/research-python'))
import pefile,capstone
p=argparse.ArgumentParser();p.add_argument('--report',required=True);output=Path(p.parse_args().report).resolve()
if output.exists():raise SystemExit('Refusing to overwrite static evidence')
raw=(ROOT.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(raw).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase;cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True
text=next(s for s in pe.sections if s.Name.rstrip(b'\0')==b'.text');code=text.get_data();origin=base+text.VirtualAddress
manager=0x1412df8b0;rows=[]
def owner(address):
 for item in pe.DIRECTORY_ENTRY_EXCEPTION:
  f=item.struct
  if base+f.BeginAddress<=address<base+f.EndAddress:return {'start':hex(base+f.BeginAddress),'endExclusive':hex(base+f.EndAddress),'boundary':'PE unwind range; chained/cold chunks may be separate'}
 return None
for at in range(len(code)-7):
 if code[at]not in (0x48,0x4c)or code[at+1]not in (0x8b,0x8d)or code[at+2]&0xc7!=5:continue
 target=origin+at+7+int.from_bytes(code[at+3:at+7],'little',signed=True)
 if target!=manager:continue
 ins=list(cs.disasm(code[at:at+200],origin+at))[:35]
 rows.append({'address':hex(origin+at),'target':hex(target),'owner':owner(origin+at),'modalOperandNearby':any(any(op.type==capstone.x86.X86_OP_MEM and op.mem.disp in (0x88,0x90)or op.type==capstone.x86.X86_OP_IMM and op.imm in (0x88,0x90)for op in i.operands)for i in ins),'assembly':[f'{i.address:#x}: {i.mnemonic} {i.op_str}'for i in ins]})
# Direct member-offset candidates also catch helpers receiving manager as this.
members=[]
for prefix in [b'\x48\x8d\x89\x88\0\0\0',b'\x48\x8d\x91\x88\0\0\0',b'\x48\x8d\x99\x88\0\0\0',b'\x48\x83\xc1\x88',b'\x48\x81\xc1\x88\0\0\0']:
 at=0
 while (at:=code.find(prefix,at))>=0:
  address=origin+at;f=owner(address);members.append({'address':hex(address),'owner':f,'assembly':[f'{i.address:#x}: {i.mnemonic} {i.op_str}'for i in list(cs.disasm(code[at:at+128],address))[:24]]});at+=1
result={'success':True,'binarySha256':digest,'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'manager':hex(manager),'globalReferences':rows,'memberCandidates':members,'scope':'Static candidate index only. Nearby operands/member offsets may be unrelated; no complete owner/modality or native integration claim. No target process/server/GPU/build.','gpu':False,'servers':0,'nativeBuilds':0}
output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'success':True,'globalReferences':len(rows),'modalNearby':sum(r['modalOperandNearby']for r in rows),'memberCandidates':len(members),'report':str(output)}))
