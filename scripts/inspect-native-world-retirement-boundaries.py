"""Read-only exact call checks in complete original area teardown1407e7770.
These do not execute virtual destructors, establish all collection semantics or
prove an original asynchronous cancellation algorithm.
"""
import hashlib,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;decoder=Cs(CS_ARCH_X86,CS_MODE_64)
checks=[(0x1407e7790,'0x1401d9c20'),(0x1407e7795,'0x14006c8b0'),(0x1407e7933,'0x140296360'),(0x1407e7aa7,'0x1401692a0'),(0x1407e7ba3,'0x1402963d0')]
rows=[]
for address,target in checks:
    instruction=next(decoder.disasm(pe.get_data(address-base,16),address))
    assert instruction.mnemonic=='call' and instruction.op_str==target
    rows.append(dict(address=hex(address),instruction='call '+target))
output=root/'backups/animations/native-world-retirement-boundaries-v1.json';assert not output.exists()
output.write_text(json.dumps(dict(binarySha256=digest,scope=__doc__,checks=rows),indent=2)+'\n')
print(json.dumps(dict(checks=len(rows),output=str(output))))
