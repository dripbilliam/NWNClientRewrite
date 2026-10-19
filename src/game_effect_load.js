import {readNativeGff} from './native_gff_fields.js';

// CGameEffect ctor1404233d0 with argument0: no global effect-ID allocation.
export function savedEffectStorage(){
 return{id:'0000000000000000',type:0,subtype:0,durationType:0,duration:0,skipOnLoad:0,expiryDay:0,expiryTime:0,
  creatorId:0x7f000000,spellId:-1,casterLevel:-1,exposed:0,showIcon:0,bypassImmunity:0,customTag:'',propertyId:'0000000000000000',
  integers:Array(8).fill(0),floats:Array(4).fill(0),strings:Array(6).fill(''),objectIds:Array(4).fill(0x7f000000),vectors:[[0,0,0],[0,0,0]]};
}

// Whole LoadGameEffect1404246d0..140424d49. SetCreator is called before the
// saved spell/caster metadata overwrites it. Fixed list reads retain the same
// CResStruct local on failed GetListElement; absent lists leave payload intact.
export function loadGameEffect(effect,data,p){
 const read=p.read??readNativeGff,get=(o,n,t,d)=>read(o,n,t,d).value;
 const id=BigInt(get(data,'Id',6,0n));effect.id=BigInt.asUintN(64,id).toString(16).padStart(16,'0');
 effect.type=get(data,'Type',2,0)&65535;const packed=get(data,'SubType',2,0)&65535;effect.subtype=packed&~7;effect.durationType=packed&7;
 effect.duration=get(data,'Duration',8,0);effect.skipOnLoad=Number((get(data,'SkipOnLoad',0,0)&255)!==0);
 effect.expiryDay=get(data,'ExpireDay',4,0)>>>0;effect.expiryTime=get(data,'ExpireTime',4,0)>>>0;
 p.setCreator(effect,get(data,'CreatorId',4,0)>>>0);
 effect.spellId=get(data,'SpellId',4,0)|0;effect.casterLevel=get(data,'CasterLevel',4,0)|0;
 effect.exposed=get(data,'IsExposed',5,0)|0;effect.showIcon=get(data,'IsIconShown',5,0)|0;
 const count=get(data,'NumIntegers',5,0)|0;
 if(count<0)throw new Error('Native saved effect negative integer allocation is unavailable');
 effect.integers=Array(count).fill(0);effect.customTag=get(data,'CustomTag',10,'');effect.bypassImmunity=get(data,'IgnoreImmunity',5,0)|0;
 let current;
 const element=(rows,index)=>{
  if(index<rows.length)current=rows[index];
  else if(current===undefined)throw new Error('Native saved effect list reads an uninitialized struct');
  return current;
 };
 if(count>0){const list=read(data,'IntList',15,null);if(list.status===1){
  if(list.value.length>count)throw new Error('Native saved effect IntList exceeds allocated integer storage');
  for(let i=0;i<list.value.length;i++)effect.integers[i]=get(element(list.value,i),'Value',5,0)|0;
 }}
 for(const [name,key,type,size,fallback]of [['FloatList','floats',8,4,0],['StringList','strings',10,6,''],['ObjectList','objectIds',4,4,0]]){
  const list=read(data,name,15,null);if(list.status===1)for(let i=0;i<size;i++)effect[key][i]=get(element(list.value,i),'Value',type,fallback);
 }
 const vectors=read(data,'VectorList',15,null);if(vectors.status===1)for(let i=0;i<2;i++){
  const node=element(vectors.value,i);effect.vectors[i]=['X','Y','Z'].map(axis=>get(node,`Value${axis}`,8,0));
 }
 return effect;
}
