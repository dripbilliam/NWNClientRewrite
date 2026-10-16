// Client CSoundSet GetStrres1407d7ba0 reads this V1.0 offset table. Parsing
// malformed resources is bounded locally; the native reader trusts the image.
export function parseSoundSet(input){
  const bytes=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength),
    view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),decode=new TextDecoder('windows-1252'),range=(o,n)=>{
      if(!Number.isSafeInteger(o)||o<0||n<0||o+n>bytes.length)throw new Error('Soundset table or entry is out of bounds');};
  range(0,40);if(decode.decode(bytes.subarray(0,8))!=='SSF V1.0')throw new Error('Unsupported soundset header');
  const count=view.getUint32(8,true),table=view.getUint32(12,true);if(count>1_000_000)throw new Error('Soundset entry count is too large');range(table,count*4);
  return{count,get(id){
    id&=65535;if(id>=count)return undefined;const offset=view.getUint32(table+id*4,true);if(offset===0)return null;range(offset,20);
    return{resRef:decode.decode(bytes.subarray(offset,offset+16)).split('\0')[0],strRef:view.getUint32(offset+16,true)};
  }};
}

// GetStrres1407d7ba0: fetch text only for a valid StrRef, then always replace
// TLK's sound reference with the explicit SSF name, including an empty name.
export function soundSetString(set,id,p){
  const entry=set.get(id);if(entry===undefined){p.warning?.(id&65535,set.count);return{text:'',resRef:''};}
  if(!entry)return{text:'',resRef:''};
  return{text:entry.strRef===0xffffffff?'':p.text(entry.strRef)??'',resRef:entry.resRef};
}
