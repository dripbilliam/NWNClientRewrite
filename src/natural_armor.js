import {creatureRoot} from './creature_rules.js';
const i8=value=>(value<<24)>>24;
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native natural armor ${name} is unavailable`);return value|0;};
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native natural armor provider ${name} is unavailable`);return p[name](...args);};

// Complete GetACNaturalBase1403f3e90. Polymorph transition9f4 OR equipment
// lock97c replaces ordinary racial/class natural armor with stats BYTEd51.
// Monk, Dwarven Defender and Armor Skin contributions retain their own gates.
export function naturalArmorParts(actor,flag,p){
 flag=integer(flag,'query flag');const root=creatureRoot(actor),classes=(root.ClassList??[]).slice(0,(root.ClassList?.length??0)&255),level=id=>{
  const c=classes.find(c=>(integer(c.Class,'class')&255)===id);return c?integer(c.ClassLevel,'class level')&255:0;
 };
 const parts={authored:0,classGains:[],dwarvenDefender:0,armorSkin:0,monkWisdom:0,monkLevels:0};
 if(call(p,'monkAbilities',actor)===1){
  if(call(p,'hasFeat',actor,260)!==0){const wisdom=i8(integer(call(p,'wisdomModifier',actor),'WIS modifier'));if(wisdom>0)parts.monkWisdom=wisdom;}
  parts.monkLevels=Math.trunc(level(5)/5);
 }
 if(flag!==1){
  parts.dwarvenDefender=Math.trunc(level(39)/3);
  if(call(p,'hasFeat',actor,490)===1)parts.armorSkin=integer(call(p,'rule','EPIC_ARMOR_SKIN_NATURAL_AC_BONUS',2),'Armor Skin rule');
  const transition=integer(actor.nativeField9f4,'transition flag'),locked=integer(actor.nativeField97c,'equipment lock');
  if(transition===0&&locked===0){
   const count=integer(call(p,'classCount'),'class count')&255;
   parts.classGains=classes.map(c=>{const id=integer(c.Class,'class')&255;return id<count?i8(integer(call(p,'classGain',id,integer(c.ClassLevel,'class level')&255),'class gain')):0;});
   parts.authored=i8(integer(root.NaturalAC??0,'base BYTE'));
  }else parts.authored=i8(integer(actor.nativeNaturalACD51,'polymorph BYTE'));
 }
 return parts;
}
export function naturalArmorTotal(parts){return i8(parts.authored+parts.classGains.reduce((n,v)=>n+v,0)+parts.dwarvenDefender+parts.armorSkin+parts.monkWisdom+parts.monkLevels);}
