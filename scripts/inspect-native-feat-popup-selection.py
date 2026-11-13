"""Bounded read-only original CGuiListBox selection/draw instruction evidence.
Procedure entries are from retained REA CG_FEATS9c71b0 callees; subsequent
entries are selected from those original call/vtable edges. No instructions
are patched or running processes read. This is source evidence, not pixels.
"""
from pathlib import Path
import sys,json,hashlib,struct
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;image=pe.get_memory_mapped_image();md=Cs(CS_ARCH_X86,CS_MODE_64)
entries=[int(value,16)for value in sys.argv[2:]]or[0x1401e8160,0x1401eb650]
def procedure(address):
    rva=address-base
    rows=[entry.struct for entry in pe.DIRECTORY_ENTRY_EXCEPTION if entry.struct.BeginAddress<=rva<entry.struct.EndAddress]
    assert len(rows)==1,(hex(address),len(rows))
    row=rows[0];begin=base+row.BeginAddress;end=base+row.EndAddress
    instructions=[dict(address=hex(i.address),bytes=i.bytes.hex(),mnemonic=i.mnemonic,operands=i.op_str)for i in md.disasm(image[row.BeginAddress:row.EndAddress],begin)]
    assert sum(len(bytes.fromhex(i['bytes']))for i in instructions)==end-begin
    return dict(requested=hex(address),start=hex(begin),endExclusive=hex(end),instructions=instructions)
out=root/'godot-client/reports'/sys.argv[1];assert not out.exists(),'Preserve prior source evidence'
value=dict(binarySha256=digest,scope=__doc__,procedures=[procedure(a)for a in entries]);out.write_text(json.dumps(value,indent=2)+'\n')
for row in value['procedures']:
    print(row['start'],row['endExclusive'])
    for instruction in row['instructions']:print(instruction['address'],instruction['mnemonic'],instruction['operands'])
