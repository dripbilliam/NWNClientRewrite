"""Read-only coordinator call-site and creature-vtable metadata.
This first projection records original instructions/targets, not runtime order.
"""
from pathlib import Path
import sys,json,hashlib
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;decoder=Cs(CS_ARCH_X86,CS_MODE_64)
targets={0x1406f14e0:'input coordinator',0x1406f1e40:'held-key tick',0x140767d50:'AI list',0x1407fcd70:'creature selector',0x1408114d0:'path step'}
rows=[]
for address in [0x1406db800,0x1406f14e0,0x140767d50,0x1407fbd10,0x1407fcd70]:
 runtime=next(e.struct for e in pe.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=address-base<e.struct.EndAddress)
 instructions=list(decoder.disasm(pe.get_data(address-base,runtime.EndAddress-(address-base)),address))
 for i,ins in enumerate(instructions):
  if ins.mnemonic!='call':continue
  target=int(ins.op_str,16) if ins.op_str.startswith('0x') else None
  if target in targets or address==0x140767d50 and '0xe8' in ins.op_str:
   rows.append(dict(function=hex(address),address=hex(ins.address),target=hex(target) if target else ins.op_str,label=targets.get(target,'virtual AI slot'),before=[f'{x.address:#x}: {x.mnemonic} {x.op_str}' for x in instructions[max(0,i-5):i]],after=hex(instructions[i+1].address)))
entry=0x140e475d0;vtable=0x140e474e8;target=int.from_bytes(pe.get_data(entry-base,8),'little');assert target==0x1407fbd10
out=dict(target=digest,scope=__doc__,calls=rows,vtable=dict(base=hex(vtable),entry=hex(entry),slot=hex(entry-vtable),target=hex(target)))
(root/'backups/animations/native-input-frame-order-metadata-v1.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
