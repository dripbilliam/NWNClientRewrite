"""Read-only compiler-unwind ranges and instructions for Commands party owners.

The target is never launched. Ranges are PE runtime-function records, not a
claim about every Ghidra function-body chunk. Existing full9945d0/98f7d0 dossiers
remain the decompiler authority; these instructions expose party query owners.
"""
from pathlib import Path
import argparse, hashlib, json, sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True);args=parser.parse_args()
output=Path(args.report).resolve();assert output.is_relative_to(root) and not output.exists()
image=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(image).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=image);base=pe.OPTIONAL_HEADER.ImageBase;disassembler=Cs(CS_ARCH_X86,CS_MODE_64)
functions=[]
entries=[0x140851d00,0x140851d80,0x140851dd0,0x140851ff0,0x1408520c0,0x140852180,0x140992240,0x14098f7d0,0x1409945d0]
for address in entries:
    records=[entry.struct for entry in pe.DIRECTORY_ENTRY_EXCEPTION if base+entry.struct.BeginAddress==address]
    if records:
        assert len(records)==1,hex(address)
        entry=records[0];start=entry.BeginAddress;end=entry.EndAddress;authority='PE runtime-function unwind record'
    else:
        # Leaf functions legitimately have no unwind record. Capture only a
        # bounded instruction excerpt up to the NEXT independently known entry;
        # do not call that excerpt an analyzed complete function-body range.
        following=min(entry for entry in entries if entry>address)
        assert following-address<=0x220,hex(address)
        start=address-base;end=following-base;authority='Bounded excerpt between independently known function entries; leaf has no PE unwind record'
    raw=pe.get_data(start,end-start)
    functions.append({'address':hex(address),'endExclusive':hex(base+end),'rangeAuthority':authority,'sha256':hashlib.sha256(raw).hexdigest(),'instructions':[f'{instruction.address:#x}: {instruction.mnemonic} {instruction.op_str}' for instruction in disassembler.disasm(raw,address)]})
output.write_text(json.dumps({'binarySha256':digest,'authority':__doc__,'functions':functions,'targetExecuted':False,'publicConnections':0},indent=2)+'\n')
print(json.dumps({'success':True,'report':str(output),'functions':len(functions),'instructions':sum(len(row['instructions']) for row in functions)}))
