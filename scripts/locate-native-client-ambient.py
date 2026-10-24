"""Read-only candidate vtable scan around the observed client ambient owners.
Consecutive executable pointers are candidates, not semantic class proof.
Follow their constructors/call sites and Ghidra dossiers before naming them.
"""
from pathlib import Path
import sys,hashlib,json,struct
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
data=(root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe').read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=data,fast_load=True);base=pe.OPTIONAL_HEADER.ImageBase;code=[(base+s.VirtualAddress,base+s.VirtualAddress+s.Misc_VirtualSize)for s in pe.sections if s.Characteristics&0x20000000];rdata=next(s for s in pe.sections if s.Name.rstrip(b'\0')==b'.rdata');raw=rdata.get_data();values=[struct.unpack_from('<Q',raw,i)[0]for i in range(0,len(raw)-7,8)];rows=[];seen=set()
valid=lambda v:any(lo<=v<hi for lo,hi in code)
for i,t in enumerate(values):
 if not 0x140875000<=t<0x140878000:continue
 lo=i;hi=i+1
 while lo>0 and valid(values[lo-1]):lo-=1
 while hi<len(values)and valid(values[hi]):hi+=1
 if lo in seen or hi-lo<4:continue
 seen.add(lo);rows.append(dict(address=hex(base+rdata.VirtualAddress+lo*8),targets=[hex(v)for v in values[lo:hi]]))
out=root/'backups/animations/native-client-ambient-vtable-candidates.json';out.write_text(json.dumps(dict(target=digest,limits=__doc__,candidates=rows),indent=2)+'\n');print(json.dumps(rows,indent=2))
