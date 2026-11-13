"""Bounded forward decode from REA-confirmed tooltip-setting instructions.

Read-only pinned executable. The known first boundaries are confirmed by REA;
linear following bytes are observations, not proof of complete control flow.
"""
import hashlib,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import capstone,pefile
raw=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
digest=hashlib.sha256(raw).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw,fast_load=True);base=pe.OPTIONAL_HEADER.ImageBase
decoder=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
blocks=[]
for start,first in [(0x1406b7530,'488d85e8320000'),(0x140827601,'488d15c82b6000')]:
    data=pe.get_data(start-base,256);assert data[:7].hex()==first
    instructions=[dict(address=hex(i.address),bytes=i.bytes.hex(),instruction=i.mnemonic+' '+i.op_str)for i in decoder.disasm(data,start)]
    blocks.append(dict(start=hex(start),instructions=instructions))
print(json.dumps(dict(sha256=digest,blocks=blocks,scope=__doc__),indent=2))
