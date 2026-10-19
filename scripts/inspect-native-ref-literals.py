"""Read-only exact ref model-name literals in the verified original image.
Metadata addresses only; no binary or resource copied.
"""
from pathlib import Path
import hashlib,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backups/research-python'))
import pefile
data=(Path(__file__).resolve().parents[2]/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();assert hashlib.sha256(data).hexdigest()=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data);offset=0
while(offset:=data.find(b'ref\0',offset))>=0:
 if offset==0 or data[offset-1]==0:print(hex(pe.OPTIONAL_HEADER.ImageBase+pe.get_rva_from_offset(offset)))
 offset+=4
