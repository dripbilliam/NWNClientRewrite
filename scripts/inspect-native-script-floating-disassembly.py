"""Bounded static ScriptFloating call sites; original instructions are never changed."""
from pathlib import Path
import sys,json,hashlib
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
source=root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data=source.read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;cs=Cs(CS_ARCH_X86,CS_MODE_64)
ranges=[(0x1406d2424,0x1406d261f),(0x1406ce9c8,0x1406ceaa8)]
windows=[]
for start,end in ranges:
 code=pe.get_data(start-base,end-start)
 windows.append(dict(start=hex(start),endExclusive=hex(end),sha256=hashlib.sha256(code).hexdigest(),instructions=[dict(address=hex(i.address),bytes=i.bytes.hex(),assembly=i.mnemonic+' '+i.op_str)for i in cs.disasm(code,start)]))
out=root/'godot-client/reports/native-script-floating-disassembly-v2.json'
assert not out.exists()
out.write_text(json.dumps(dict(schema='native-script-floating-disassembly-v1',binarySha256=digest,scope=__doc__,windows=windows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),windows=[dict(start=w['start'],endExclusive=w['endExclusive'],instructions=len(w['instructions']),sha256=w['sha256'])for w in windows])))
