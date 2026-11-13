"""Read pinned original border-related x64 instruction windows; no execution."""
from pathlib import Path
import sys,hashlib,json
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
raw=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes()
sha=hashlib.sha256(raw).hexdigest();assert sha=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase;cs=Cs(CS_ARCH_X86,CS_MODE_64)
blocks=[]
for name,address,length in [('tile-border-setting',0x1406b0d92,358),('load-border-gate',0x1407dd490,64),('corner-orientation',0x1402c6720,53),('edge-orientation',0x1402c6760,53)]:
 at=pe.get_offset_from_rva(address-base);payload=raw[at:at+length]
 blocks.append(dict(name=name,address=hex(address),length=length,bytesHex=payload.hex(),instructions=[dict(address=hex(i.address),code=i.mnemonic+' '+i.op_str)for i in cs.disasm(payload,address)]))
report=dict(binarySha256=sha,scope=__doc__,blocks=blocks)
report['priorRejectedWindow']='v1 began inside prior instructions; v2 starts exact observed instruction boundaries. Original binary bytes unchanged.'
out=root/'godot-client/reports/native-area-border-blocks-v2.json';assert not out.exists();out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
