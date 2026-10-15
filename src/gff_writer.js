import { getGffFieldTypes, getGffStructType } from './gff.js';
import { encodeGffText } from './gff_text.js';
export { encodeGffText } from './gff_text.js';

export const gffField = (type, value) => ({ type, value });
export const gffRecord = (fields, type = 0xffffffff) => ({ fields, type });
const concat = arrays => { const out = new Uint8Array(arrays.reduce((n, b) => n + b.length, 0)); let at = 0; for (const b of arrays) { out.set(b, at); at += b.length; } return out; };
const u32 = n => { const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, n >>> 0, true); return b; };

// Preserve the actual field widths and struct IDs of installed UTI resources.
// No item/object IDs are assigned here; ModuleSession allocates them on import.
export function typedGff(record, type = getGffStructType(record) ?? 0xffffffff) {
  const types = getGffFieldTypes(record);
  if (!types) throw new Error('GFF field metadata is unavailable');
  return gffRecord(Object.fromEntries(Object.entries(record).map(([name, value]) => {
    const t = types[name];
    if (t === undefined) throw new Error(`GFF type is unavailable for ${name}`);
    return [name, gffField(t, t === 14 ? typedGff(value) : t === 15 ? value.map(v => typedGff(v)) : value)];
  })), type);
}

export function writeGff(fileType, root) {
  if (!/^[\x20-\x7e]{4}$/.test(fileType)) throw new Error('GFF file type must contain four ASCII characters');
  const structs = [], fields = [], labels = [], fieldData = [], fieldIndices = [], listIndices = [], seen = new Set();
  let dataLength = 0;
  const data = bytes => { const offset = dataLength; fieldData.push(bytes); dataLength += bytes.length; return offset; };
  const label = name => { if (!/^[\x20-\x7e]{1,16}$/.test(name)) throw new Error(`Invalid GFF label ${name}`); let i = labels.indexOf(name); if (i < 0) { i = labels.length; labels.push(name); } return i; };
  const add = (node, depth = 0) => {
    if (depth > 128 || seen.has(node)) throw new Error('GFF structure cycle or excessive depth');
    seen.add(node);
    const index = structs.length, structure = { type: node.type >>> 0, indices: [] }; structs.push(structure);
    for (const [name, { type, value }] of Object.entries(node.fields)) {
      const item = { type, label: label(name), value: 0 }; structure.indices.push(fields.length); fields.push(item);
      if (type <= 5) {
        const ranges = [[0,255],[-128,127],[0,65535],[-32768,32767],[0,0xffffffff],[-0x80000000,0x7fffffff]], range = ranges[type];
        if (!range || !Number.isInteger(value) || value < range[0] || value > range[1]) throw new Error(`GFF ${name} exceeds field range`);
        item.value = value >>> 0;
      } else if (type === 8) { const b = new Uint8Array(4); const v = new DataView(b.buffer); v.setFloat32(0,value,true); item.value = v.getUint32(0,true); }
      else if ([6,7,9].includes(type)) { const b = new Uint8Array(8), v = new DataView(b.buffer); if (type === 9) v.setFloat64(0,value,true); else if (type === 6) v.setBigUint64(0,BigInt(value),true); else v.setBigInt64(0,BigInt(value),true); item.value = data(b); }
      else if (type === 10 || type === 11) { const b = encodeGffText(value); if (type === 11 && b.length > 16) throw new Error(`Resref ${name} is too long`); item.value = data(concat([type === 11 ? Uint8Array.of(b.length) : u32(b.length),b])); }
      else if (type === 12) {
        const loc = typeof value === 'string' ? {strRef:0xffffffff,entries:[{languageId:0,text:value}]} : value;
        const entries = (loc.entries ?? []).map(e => { const b = encodeGffText(e.text); return concat([u32(e.languageId),u32(b.length),b]); });
        const body = concat([u32(loc.strRef ?? 0xffffffff),u32(entries.length),...entries]); item.value = data(concat([u32(body.length),body]));
      } else if (type === 13) { const b = new Uint8Array(value); item.value = data(concat([u32(b.length),b])); }
      else if (type === 14) item.value = add(value,depth+1);
      else if (type === 15) { const at = listIndices.length; listIndices.push(value.length,...Array(value.length).fill(0)); for (let i=0;i<value.length;i++) listIndices[at+i+1] = add(value[i],depth+1); item.value = at*4; }
      else if (type === 16 || type === 17) { const count = type === 16 ? 4 : 3; if (value.length !== count) throw new Error(`Invalid GFF ${name} vector`); const b = new Uint8Array(count*4),v=new DataView(b.buffer); value.forEach((x,i)=>v.setFloat32(i*4,x,true)); item.value=data(b); }
      else if (type === 18) item.value = data(u32(value));
      else throw new Error(`Unsupported GFF field type ${type}`);
    }
    seen.delete(node); return index;
  };
  add(root);
  const sb = new Uint8Array(structs.length*12), sv=new DataView(sb.buffer);
  structs.forEach((n,i)=>{sv.setUint32(i*12,n.type,true);sv.setUint32(i*12+8,n.indices.length,true);sv.setUint32(i*12+4,n.indices.length===1?n.indices[0]:n.indices.length>1?fieldIndices.length*4:0,true);if(n.indices.length>1)fieldIndices.push(...n.indices);});
  const fb=new Uint8Array(fields.length*12),fv=new DataView(fb.buffer);fields.forEach((f,i)=>{fv.setUint32(i*12,f.type,true);fv.setUint32(i*12+4,f.label,true);fv.setUint32(i*12+8,f.value,true);});
  const lb=new Uint8Array(labels.length*16);labels.forEach((n,i)=>lb.set(encodeGffText(n),i*16));
  const sections=[sb,fb,lb,concat(fieldData),concat(fieldIndices.map(u32)),concat(listIndices.map(u32))],counts=[structs.length,fields.length,labels.length,dataLength,fieldIndices.length*4,listIndices.length*4];
  const header=new Uint8Array(56),hv=new DataView(header.buffer);header.set(encodeGffText(fileType+'V3.2'));let offset=56;sections.forEach((b,i)=>{hv.setUint32(8+i*8,offset,true);hv.setUint32(12+i*8,counts[i],true);offset+=b.length;});return concat([header,...sections]);
}
