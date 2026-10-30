"""Read-only exact instruction checks for original client world/area loading.
These validate selected call sites and thresholds, not full loader execution,
all join states, scheduler thread ownership or original load-time performance.
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
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;decoder=Cs(CS_ARCH_X86,CS_MODE_64)
checks=[(0x1407a4e7e,'call','0x1407cffb0'),(0x1407a4e86,'call','0x1407cd2c0'),(0x14076e315,'call','0x1407dba70'),(0x1407dcfb7,'cmp','rax, 0xc350'),(0x1407dcfc7,'cmp','rcx, 0x3a98'),(0x1407dcfeb,'call','0x1400451c0'),(0x1407dd03b,'call','0x1402376a0'),(0x1407dd0c2,'call','0x140850110'),(0x1407dd119,'call','0x14084ef10'),(0x14008c594,'je','0x14008c6c7'),(0x14008c6cf,'call','qword ptr [rax + 0xa8]')]
rows=[]
for address,mnemonic,operands in checks:
    instruction=next(decoder.disasm(pe.get_data(address-base,16),address))
    assert instruction.mnemonic==mnemonic and instruction.op_str==operands,(hex(address),instruction.mnemonic,instruction.op_str)
    rows.append(dict(address=hex(address),instruction=instruction.mnemonic+' '+instruction.op_str))
output=root/'backups/animations/native-world-join-loading-instructions-v1.json';assert not output.exists()
output.write_text(json.dumps(dict(binarySha256=digest,scope=__doc__,checks=rows),indent=2)+'\n')
print(json.dumps(dict(checks=len(rows),output=str(output))))
