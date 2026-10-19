import {gffField as field,gffRecord as record} from './gff_writer.js';
import {nativeGffLabel} from './native_gff_fields.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item save ${n} is unavailable`);return v|0;};
const byte=(v,n)=>integer(v,n)&255,word=(v,n)=>integer(v,n)&65535;
const list=(v,n)=>{if(!Array.isArray(v))throw new Error(`Native item save ${n} storage is unavailable`);return v;};
const put=(root,name,type,value)=>{root.fields[nativeGffLabel(name)]=field(type,value);};
const extended=(root,name,value)=>{value=word(value,name);put(root,name,0,value<256?value:0);put(root,`x${name}`,2,value);};
const colors=['Leather1Color','Leather2Color','Cloth1Color','Cloth2Color','Metal1Color','Metal2Color'];
const armor=[['ArmorPart_Neck',9],['ArmorPart_Torso',7],['ArmorPart_Belt',8],['ArmorPart_Pelvis',6],['ArmorPart_LShoul',15],['ArmorPart_LBicep',13],['ArmorPart_LFArm',11],['ArmorPart_LHand',17],['ArmorPart_LThigh',4],['ArmorPart_LShin',3],['ArmorPart_LFoot',1],['ArmorPart_RShoul',14],['ArmorPart_RBicep',12],['ArmorPart_RFArm',10],['ArmorPart_RHand',16],['ArmorPart_RThigh',5],['ArmorPart_RShin',2],['ArmorPart_RFoot',0],['ArmorPart_Robe',18]];

// Complete SaveItemProperties14046c130..14046c41b. Struct IDs retain physical
// indices, including skipped temporary records; remaining uses are low BYTE.
export function saveItemProperties(item,p,root=record({})){
 const entries=[];put(root,'PropertiesList',15,entries);
 const active=()=>list(p.properties(item,true),'active property'),passive=()=>list(p.properties(item,false),'passive property');
 for(const [get,isActive]of [[active,true],[passive,false]])for(let i=0;i<get().length;i++){
  const property=get()[i];if(!property)throw new Error('Native item save property record is unavailable');
  if(byte(property.durationType,'property duration')!==2)continue;
  const node=record({},isActive?i:(active().length+i)>>>0);entries.push(node);
  for(const [name,type,key]of [['PropertyName',2,'type'],['Subtype',2,'subtype'],['CostTable',0,'costTable'],['CostValue',2,'costValue'],['Param1',0,'param1'],['Param1Value',0,'param1Value'],['ChanceAppear',0,'chance'],['UsesPerDay',0,'usesPerDay'],['Useable',0,'remaining']])put(node,name,type,type===2?word(property[key],key):byte(property[key],key));
  if(typeof property.customTag!=='string')throw new Error('Native item save property tag is unavailable');put(node,'CustomTag',10,property.customTag);
 }
 return root;
}

// Complete CNWSItem::SaveItem14046b760..14046c125. Shared state/visual/UUID
// save owners are explicit dependencies; missing owners cannot become no-ops.
export async function saveNativeItem(item,flag,p,root=record({}),ancestors=new Set()){
 flag=integer(flag,'save flag');if(!item)throw new Error('Native item save source is unavailable');
 if(ancestors.has(item))throw new Error('Native item save repository recursion contains a cycle');ancestors.add(item);
 try{
  const scalar=offset=>integer(p.scalar(item,offset),`field ${offset.toString(16)}`);
  const string=offset=>{const value=p.string(item,offset);if(typeof value!=='string')throw new Error('Native item save string storage is unavailable');return value;};
  if(flag===0)await p.objectState(item,root);
  put(root,'BaseItem',5,scalar(0x40));put(root,'Tag',10,string(0x68));put(root,'TemplateResRef',11,p.resref(string(0x78)));
  put(root,'Identified',0,scalar(0x360)&255);
  for(const [name,offset]of [['Description',0x3f0],['DescIdentified',0x3e0]])put(root,name,12,structuredClone(p.localized(item,offset)));
  put(root,'DescriptionOverride',10,string(0x410));put(root,'DescIdentifiedOverride',10,string(0x400));put(root,'LocalizedName',12,structuredClone(p.localized(item,0x420)));
  put(root,'StackSize',2,scalar(0x454)&65535);put(root,'Stolen',0,scalar(0x458)&255);put(root,'Hidden',0,Number(scalar(0x468)!==0));
  const display=string(0x430);if(display.length!==0)put(root,'DisplayName',10,display);
  put(root,'Dropable',0,scalar(0x448)&255);put(root,'Pickpocketable',0,Number(scalar(0x44c)!==0&&scalar(0x450)===0));
  let base=await p.baseInfo(item);if(!base)throw new Error('Native item save base item is unavailable');
  const model=byte(base.modelType,'base model type');
  if(model===1||model===3)for(let i=0;i<6;i++)put(root,colors[i],0,byte(p.appearance(item,'colors',i),'palette color'));
  if(model===0||model===1)extended(root,'ModelPart1',p.appearance(item,'modelParts',0));
  else if(model===2)for(let i=0;i<3;i++)extended(root,`ModelPart${i+1}`,p.appearance(item,'modelParts',i));
  else if(model===3){
   for(let part=0;part<19;part++)for(let channel=0;channel<6;channel++){
    const color=byte(await p.partColor(item,channel,part),'part color');if(color!==255)put(root,`APart_${part}_Col_${channel}`,0,color);
   }
   for(const [name,index]of armor)extended(root,name,p.appearance(item,'armorParts',index));
  }
  put(root,'Charges',0,scalar(0x388)&255);let cost=0;
  if(scalar(0x144)!==1&&((scalar(0x40)-69)>>>0)>4){
   if(scalar(0x398)!==0){await p.calculateBaseCosts(item);p.writeScalar(item,0x398,0);}
   const unit=scalar(0x360)===0?scalar(0x390):(scalar(0x394)+scalar(0x38c))|0;
   if(unit!==0||(base=await p.baseInfo(item),word(base.stacking,'base stacking')<=scalar(0x454))){cost=Math.imul(scalar(0x454),unit)>>>0;if(cost===0)cost=1;}
  }
  put(root,'Cost',4,cost);put(root,'AddCost',4,scalar(0x394)>>>0);put(root,'Plot',0,scalar(0x144)&255);put(root,'Cursed',0,scalar(0x450)&255);put(root,'Useable',0,scalar(0x2ac)&255);
  base=await p.baseInfo(item);if(!base)throw new Error('Native item save container definition is unavailable');
  const repository=integer(base.container,'base container flag')!==0?p.repository(item):null;
  if(repository){
   const entries=[];put(root,'ItemList',15,entries);let index=0;const visited=new Set();
   for(let node=p.head(repository);node;node=p.next(repository,node),index=(index+1)>>>0){
    if(visited.has(node))throw new Error('Native item save repository node cycle');visited.add(node);
    const stored=p.value(repository,node),child=stored===null?null:await p.item(integer(stored,'repository object ID')>>>0);
    if(!child)continue;const entry=record({},index);entries.push(entry);
    // Child SaveItem may mutate repository coordinates; native snapshots first.
    const x=byte(p.scalar(child,0x3d8),'repository X'),y=byte(p.scalar(child,0x3d9),'repository Y');
    await saveNativeItem(child,flag,p,entry,ancestors);put(entry,'Repos_PosX',0,x);put(entry,'Repos_Posy',0,y);
   }
  }
  await p.itemProperties(item,root);
  for(const [name,offset]of [['XPosition',0xec],['YPosition',0xf0],['ZPosition',0xf4],['XOrientation',0xf8],['YOrientation',0xfc],['ZOrientation',0x100]]){
   const value=p.float(item,offset);if(typeof value!=='number')throw new Error('Native item save spatial FLOAT is unavailable');put(root,name,8,Math.fround(value));
  }
  for(const owner of ['visualTransform','materialOverrides','textureOverrides','animationOverrides','miscVisuals','uuid'])await p[owner](item,root);
  return root;
 }finally{ancestors.delete(item);}
}
