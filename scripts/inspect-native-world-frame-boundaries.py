"""Read-only original instruction checks for mapped join/frame boundaries.
This does not execute the loader, resolve indirect targets or prove a complete
static-object dirty/culling algorithm. Pseudocode views have separate coverage.
"""
import hashlib,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
decoder=Cs(CS_ARCH_X86,CS_MODE_64)
checks=[(0x14076e315,'call','0x1407dba70'),(0x1407d031b,'call','0x1407e7da0'),(0x1407e9041,'call','0x140878240'),(0x1407e9054,'call','qword ptr [rax + 0x20]'),(0x1407d03ae,'call','qword ptr [rax + 0x10]'),(0x1407a01a8,'call','0x140769130')]
rows=[]
for address,mnemonic,operands in checks:
    instruction=next(decoder.disasm(pe.get_data(address-base,16),address))
    assert instruction.mnemonic==mnemonic and instruction.op_str==operands,(hex(address),instruction.mnemonic,instruction.op_str)
    rows.append(dict(address=hex(address),instruction=instruction.mnemonic+' '+instruction.op_str))
output=root/'backups/animations/native-world-frame-boundaries-v1.json'
assert not output.exists()
output.write_text(json.dumps(dict(binarySha256=digest,scope=__doc__,checks=rows),indent=2)+'\n')
print(json.dumps(dict(checks=len(rows),output=str(output))))
