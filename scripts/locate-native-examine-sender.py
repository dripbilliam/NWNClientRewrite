"""Read-only bounded client sender scan; candidate instructions, not a wire oracle."""
import sys,json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile,capstone
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();assert hashlib.sha256(data).hexdigest()=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);start=0x1407bf000;offset=pe.get_offset_from_rva(start-pe.OPTIONAL_HEADER.ImageBase);history=[];results=[]
decoder=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);decoder.skipdata=True
for ins in decoder.disasm(data[offset:offset+0x5000],start):
 history.append(dict(address=hex(ins.address),mnemonic=ins.mnemonic,operands=ins.op_str));history=history[-14:]
 if ins.mnemonic=='call'and ins.op_str=='0x1407c25c0'and any(h['operands']in ['r8d, 5','r8b, 5']for h in history):results.append(history.copy())
out=root/'backups/animations/native-examine-sender-candidates.json';out.write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(dict(calls=[r[-1]['address']for r in results])))
