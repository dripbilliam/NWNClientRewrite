"""Complete static ParseStr/FetchInternal bytes; no original-code execution."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
source=root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
data=source.read_bytes();digest=hashlib.sha256(data).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase;cs=Cs(CS_ARCH_X86,CS_MODE_64)
windows=[]
for name,start,end in [('ParseStr',0x140199e20,0x14019a421),('FetchInternal',0x140198c60,0x1401994b7)]:
    code=pe.get_data(start-base,end-start)
    instructions=list(cs.disasm(code,start))
    assert sum(i.size for i in instructions)==len(code)
    windows.append(dict(name=name,start=hex(start),endExclusive=hex(end),sha256=hashlib.sha256(code).hexdigest(),bytes=code.hex(),instructions=[dict(address=hex(i.address),bytes=i.bytes.hex(),assembly=i.mnemonic+' '+i.op_str)for i in instructions]))
out=root/'godot-client/reports/native-talk-parse-disassembly-v1.json';assert not out.exists()
out.write_text(json.dumps(dict(schema='native-talk-parse-disassembly-v1',binarySha256=digest,scope=__doc__,windows=windows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),windows=[dict(name=w['name'],start=w['start'],endExclusive=w['endExclusive'],instructions=len(w['instructions']),sha256=w['sha256'])for w in windows])))
