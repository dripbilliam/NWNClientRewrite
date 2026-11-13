"""Bounded static original settings registration/UI windows; no target execution."""
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
owners=[(0x1406ae3b0,0x1406bb186,[(0x1406b72a0,0x1406b7a80)]),(0x140823e60,0x140828d8f,[(0x140826e80,0x1408276b0)])]
known={0x1406b7403,0x1406b788f,0x140826f62,0x1408274ff};observed=set();windows=[]
for start,end,bounds in owners:
    instructions=list(cs.disasm(pe.get_data(start-base,end-start),start))
    for lo,hi in bounds:
        rows=[i for i in instructions if lo<=i.address<hi]
        assert rows
        observed.update(i.address for i in rows)
        first,last=rows[0].address,rows[-1].address+rows[-1].size
        code=pe.get_data(first-base,last-first)
        windows.append(dict(owner=hex(start),start=hex(first),endExclusive=hex(last),sha256=hashlib.sha256(code).hexdigest(),instructions=[dict(address=hex(i.address),bytes=i.bytes.hex(),assembly=i.mnemonic+' '+i.op_str) for i in rows]))
assert known<=observed,sorted(hex(v)for v in known-observed)
out=root/'godot-client/reports/native-overhead-options-disassembly-v1.json'
assert not out.exists()
out.write_text(json.dumps(dict(schema='native-overhead-options-disassembly-v1',binarySha256=digest,scope=__doc__,windows=windows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),windows=[dict(start=w['start'],endExclusive=w['endExclusive'],instructions=len(w['instructions']),sha256=w['sha256'])for w in windows])))
