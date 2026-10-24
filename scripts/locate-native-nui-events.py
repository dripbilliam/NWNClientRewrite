"""Read-only native event-string RIP-reference candidates; ownership is provisional."""
import importlib,json,struct
m=importlib.import_module('locate-native-nui');targets={};rows=[]
for name in ['click','doubleclick','mousedown','mouseup','mousemove','mouseenter','mouseleave','focus','blur','keydown','keyup','scroll','open','close','watch']:
 pos=0
 while True:
  pos=m.data.find(name.encode()+b'\0',pos)
  if pos<0:break
  if pos==0 or m.data[pos-1]==0:targets[m.pe.OPTIONAL_HEADER.ImageBase+m.pe.get_rva_from_offset(pos)]=name
  pos+=1
for section in m.pe.sections:
 if not section.Characteristics&0x20000000:continue
 raw=section.get_data();base=m.pe.OPTIONAL_HEADER.ImageBase+section.VirtualAddress
 for needle in [b'\xba\x37\x00\x00\x00',b'\xb2\x37']:
  offset=0
  while True:
   offset=raw.find(needle,offset)
   if offset<0:break
   if 0x1407b0000<=base+offset<0x1407c8000:
    address=base+offset;rva=address-m.pe.OPTIONAL_HEADER.ImageBase;owner=next((e.struct.BeginAddress for e in m.pe.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=rva<e.struct.EndAddress),None);rows.append(dict(event='client-major55-send-candidate',address=hex(address),owner=hex(m.pe.OPTIONAL_HEADER.ImageBase+owner)if owner is not None else None))
   offset+=1
 for rex in [b'\x48\x8d',b'\x4c\x8d']:
  offset=0
  while True:
   offset=raw.find(rex,offset)
   if offset<0:break
   if offset+7<=len(raw)and raw[offset+2]&0xc7==5:
    target=base+offset+7+struct.unpack_from('<i',raw,offset+3)[0]
    if target in targets:
     address=base+offset;rva=address-m.pe.OPTIONAL_HEADER.ImageBase;owner=next((e.struct.BeginAddress for e in m.pe.DIRECTORY_ENTRY_EXCEPTION if e.struct.BeginAddress<=rva<e.struct.EndAddress),None)
     if owner is not None and 0x700000<owner<0x7d0000:rows.append(dict(event=targets[target],address=hex(address),target=hex(target),owner=hex(m.pe.OPTIONAL_HEADER.ImageBase+owner)))
   offset+=1
out=m.root/'backups/animations/native-nui-event-references-v1.json';out.write_text(json.dumps(dict(target=m.digest,candidates=rows),indent=2)+'\n');print(json.dumps(rows))
