import {encodeGffText} from '../src/gff_text.js';
const hex=bytes=>Buffer.from(bytes).toString('hex');
const note=value=>({nameStrRef:value.strRef,nameEntries:value.entries.map(e=>[e.key,hex(e.bytes)])});
const fieldGroups={
 area:[['dword',[8,0x98,0x9c,0xa0,0xb8,0xbc,0xc0]],['byte',[0xa4,0xc4,0x104,0xe0,0xe3,0xe4,0x344,0x330]],['int',[0xa8,0xc8,0xd8,0xdc,0x100,0x34c,0x334,0x368,0x380,0x10c,0xc,0x10]],['float',[0xac,0xb0,0xb4,0xcc,0xd0,0xd4,0x108,0xe8,0xec,0xf0,0xf4,0xf8,0xfc]]],
 ambient:[['int',[8,0x18,0x20,0xc,0x10,0x14,0x1c,0x24,0x28]],['byte',[0x2c,0x2d]]],
 module:[['dword',[0x3c0,0x3c4,0x3c8,0x3cc,0x3d0]],['byte',[0x3d4,0x3b9,0x3ba]]],
 tile:[['int',[0x14,0x24,0x18]],['byte',[0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f]]],
 grass:[['byte',[0x10]],['float',[0x28,0x2c,0x30,0x34,0x38,0x3c,0x40,0x44]]],
 5:[['dword',[0x8fc]]],12:[['int',[0x308,0x30c]],['float',[0xa4,0xa8,0xac]]],9:[['word',[0x32c]],['int',[0x594,0x5a0]],['float',[0xa4,0xa8,0xac,0xb0,0xb4,0xb8]]],
 16:[['int',[0x308,0x30c,0x310,0x358,0x35c,0x32c]],['byte',[0x314,0x318,0x31c,0x328]],['dword',[0x324,0x348,0x34c]],['word',[0x340]],['float',[0xa4,0xa8,0xac,0x320,0x350,0x354,0x330,0x334]]],
};

// Read-only, explicit snapshot of the live provider inputs supplied to the
// unchanged native packer oracle. It is evidence, not production protocol data.
export async function areaPackCase(session,message,area,client,format){
 const p=session.areaMessages.providers(message,{clients:[client],hasExpansion:()=>1}),fields=(object,kind)=>Object.fromEntries((fieldGroups[kind]??[]).flatMap(([type,offsets])=>offsets.map(offset=>[offset.toString(16),[type,p.field(object,offset,type)]])));
 const ids=[...area.nativeSpatial.view()],objects=[],lightRows={};
 const all=[...new Set([...ids,client.object.id])];
 for(const id of all){
  const o=session.registry.get(id);if(!o)continue;
  const record={id:o.id,type:o.objectType,fields:fields(o,o.objectType),locals:{},refs:[]};
  if(o.objectType===12)Object.assign(record,note(o.nativeMapNote310));
  if(o.objectType===16)record.refsHex=o.nativeSoundRefs338.map(hex);
  if(o.objectType===9){const row=p.field(o,0x32c,'word'),entry=await p.lightColor(row,'LightColor');lightRows[row]=[entry.status,entry.value];}
  if(o.objectType===5)for(const [key,value]of o.locals.entries){
   if(!key.startsWith('NW_MAP_PIN_')&&key!=='NW_TOTAL_MAP_PINS')continue;
   for(const type of ['int','float','object','string']){record.locals[type]??={};record.locals[type][key]=type==='string'?hex(encodeGffText(value[type])):value[type];}
  }
  objects.push(record);
 }
 return{format,size:65536,playerId:client.nativePlayerId48,language:client.nativeLanguage4c,id:area.id,point:[2,-3,4],area:fields(area,'area'),ambient:fields(p.ambient(area),'ambient'),module:fields(session.module,'module'),
  areaRefHex:hex(p.resRef(area,0x120)),tilesetRefHex:hex(p.resRef(area,0x1a8)),...note(area.nativeName188),custom:area.nativeCustomName358?hex(area.nativeCustomName358):'',tiles:area.nativeMessageTiles.map(tile=>fields(tile,'tile')),
  grass:area.nativeMessageGrassEntries.map(entry=>({fields:fields(entry,'grass'),name:hex(entry.nativeName18)})),ids,objects,controlled:client.object.id,expansions:{'35:0':1,'14:0':1,'36:3':1,'36:5':1},pvp:session.getPVPSetting(area),lightRows};
}
