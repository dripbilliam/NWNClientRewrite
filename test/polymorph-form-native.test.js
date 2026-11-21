import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializePolymorphState,polymorphCreature,unpolymorphCreature} from '../src/polymorph_form.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-polymorph-form-observations.json',import.meta.url)));
const i8=n=>(n<<24)>>24,i16=n=>(n<<16)>>16;
const describe=e=>({type:e.type,durationType:e.durationType,creatorId:e.creatorId,integers:[...e.integers],id:e.id});
async function run(c){
 const root={Appearance_Type:5,Race:2,SoundSetFile:3,Portrait:'po_original_',PortraitId:c.portraitId??65535,Str:11,Dex:12,Con:13},o={id:99,creatureData:root,nativeField97c:c.locked??0,nativeField9f4:0,nativeNaturalACD51:0,nativeField9fc:c.reuse??0,effects:[],position:[1,2,3],areaId:98,hp:8},calls=[],items=new Map(),equipped=new Map();let nextItem=0,nextEffect=0,deadCount=0;
 initializePolymorphState(o);Object.assign(o,{nativeAppearance9dc:17,nativePortraitId9da:c.savedPortraitId??65535,nativePortrait9c8:'po_saved_',nativeStr9de:21,nativeCon9df:23,nativeDex9e0:22,nativeRace9e2:6,nativeSound9e4:7,nativeSpellOverride9e8:0,nativeSpellOverride9ec:0,nativeSpellOverride9f0:0});
 for(const [field,key]of [['nativePolymorphEquipment980','saved'],['nativePolymorphEquipmentA00','shape']])for(const [n,id]of Object.entries(c[key]??{})){o[field][n]=id;if(!items.has(id))items.set(id,{id});}
 for(const [n,id]of Object.entries(c.equipped??{})){const item={id};items.set(id,item);equipped.set(1<<Number(n),item);}
 const fresh=()=>({id:(100+(++nextEffect)).toString(16).padStart(16,'0'),type:0,durationType:0,creatorId:OBJECT_INVALID,integers:Array(8).fill(0)});
 o.effects=(c.effects??[]).map((e,n)=>{const value=fresh();nextEffect--;Object.assign(value,{id:(500+n).toString(16).padStart(16,'0'),type:e.type,durationType:e.durationType??2});value.integers[1]=e.integer1??0;return value;}).sort((a,b)=>a.type-b.type);
 const parent={id:'000000000000004d',type:62,durationType:1,creatorId:98,integers:Array(8).fill(0)},entry=(map,column)=>({found:!!map&&Object.hasOwn(map,column),value:map?.[column]??0}),p={
  table:()=>c.noTable?null:{},rowCount:()=>c.rowCount??64,
  int:(_t,row,column)=>{calls.push(['int',column]);return entry(row<0||row>=(c.rowCount??64)?null:c.ints,column);},
  string:(_t,row,column)=>{calls.push(['string',column]);const e=entry(row<0||row>=(c.rowCount??64)?null:c.strings,column);return{found:e.found&&e.value!=='',value:e.found?e.value:''};},
  portraitId:()=>root.PortraitId,portrait:()=>root.Portrait,setPortraitId:(_o,n)=>{root.PortraitId=n;},setPortrait:(_o,v)=>{root.Portrait=v;},sound:()=>root.SoundSetFile,setSound:(_o,n)=>{root.SoundSetFile=n;},
  copyCombatInformation:()=>{calls.push(['copyCombatInformation']);return{};},
  armor:()=>{const [armor,shield,au,ad,du,dd,su,sd,nu,nd,ou,od]=c.cache??[2,3,4,1,5,2,6,1,7,2,8,3];return i16(10+i8(armor+au-ad)+i8(shield+su-sd)+i8(du-dd)+i8((c.natural??2)+nu-nd)+i8(Math.min(i8(ou)-i8(od),c.dodgeLimit??20))+i8(c.tumble??3)+i8(c.dexModifier??4));},
  baseAttack:()=>c.baseAttack??7,maximumHP:()=>c.maximumHP??23,fortitude:()=>c.fortitude??5,reflex:()=>c.reflex??5,will:()=>c.will??5,
  setBaseAbility:(_o,n,v,flag)=>{calls.push(['setBaseAbility',n,v,flag]);root[['Str','Dex','Con'][n]]=v;},
  currentHP:(_o,flag)=>{calls.push(['currentHP',flag]);return c.currentHP??8;},writeHP:(_o,n)=>{o.hp=n;},dead:()=>{calls.push(['dead']);const values=c.dead??[0,0];return values[Math.min(deadCount++,values.length-1)];},
  equipped:(_o,slot)=>{calls.push(['equipped',slot]);return equipped.get(slot)??null;},unequip:(_o,item,force,event)=>{calls.push(['unequip',item.id,force,event]);equipped.delete([...equipped].find(([,v])=>v===item)[0]);return 1;},
  equip:(_o,slot,item,properties,loading,event)=>{calls.push(['equip',slot,item.id,properties,loading,event]);equipped.set(slot,item);return 1;},
  item:id=>{calls.push(['item',id]);return items.get(id)??null;},constructItem:()=>{const item={id:2000+(++nextItem)};calls.push(['constructItem',item.id]);items.set(item.id,item);return item;},
  loadItem:(item,ref)=>{calls.push(['loadItem',item.id,ref.toLowerCase().slice(0,16)]);return Number(!(c.failItems??[]).includes(ref.toLowerCase().slice(0,16)));},identified:(item,n)=>calls.push(['identified',item.id,n]),destroyItem:item=>{calls.push(['destroyItem',item.id]);items.delete(item.id);},
  create:(type,creator,ints)=>{const e=fresh();e.type=type;e.creatorId=creator;e.integers.splice(0,ints.length,...ints);return e;},copyConstruct:e=>({...e,type:0,integers:Array(8).fill(0)}),setCreator:(e,id)=>{e.creatorId=id;},effects:()=>o.effects,
  apply:(_o,e,loading)=>{calls.push(['apply',describe(e),loading]);o.effects.push(e);o.effects.sort((a,b)=>a.type-b.type);},remove:(_o,id)=>{calls.push(['remove',id]);o.effects=o.effects.filter(e=>e.id!==id);},
  personalSpace:()=>calls.push(['personalSpace']),appearanceInfo:()=>calls.push(['appearanceInfo']),area:()=>c.area&&o.areaId!==OBJECT_INVALID?{}:null,position:()=>o.position,
  safeLocation:(_a,v,range,_path,flag,out)=>{calls.push(['safeLocation',[...v],range,flag]);out.point=c.safePoint??[9,8,7];return c.safeResult??1;},setPosition:(_o,v,flag)=>{calls.push(['setPosition',[...v],flag]);o.position=[...v];},
  removeFromArea:(_o,flag)=>{calls.push(['removeFromArea',flag]);o.areaId=OBJECT_INVALID;o.position=[0,0,0];},addToArea:(_o,_a,x,y,z,force,flag)=>{calls.push(['addToArea',[x,y,z],force,flag]);o.areaId=98;o.position=[x,y,z];}
 };
 const result=c.mode==='restore'?await unpolymorphCreature(o,c.parent===false?null:parent,p):await polymorphCreature(o,c.form??3,c.parent===false?null:parent,c.loading??0,p);
 const state={appearance:root.Appearance_Type,race:root.Race,sound:root.SoundSetFile,portraitId:root.PortraitId,portrait:root.Portrait,base:[root.Str,root.Dex,root.Con],locked:o.nativeField97c,transition:o.nativeField9f4,reuse:o.nativeField9fc,natural:o.nativeNaturalACD51,overrides:[o.nativeSpellOverride9e8,o.nativeSpellOverride9ec,o.nativeSpellOverride9f0],saved:o.nativePolymorphEquipment980,shape:o.nativePolymorphEquipmentA00,savedAppearance:o.nativeAppearance9dc,savedPortraitId:o.nativePortraitId9da,savedPortrait:o.nativePortrait9c8,savedBase:[o.nativeStr9de,o.nativeDex9e0,o.nativeCon9df],savedRace:o.nativeRace9e2,savedSound:o.nativeSound9e4,armor:o.nativeArmorA50,baseAttack:o.nativeBaseAttackA54,maximumHP:o.nativeMaximumHPA58,saves:[o.nativeFortitudeA5a,o.nativeReflexA5b,o.nativeWillA5c],hp:o.hp,position:o.position,equipped:Object.fromEntries([...equipped].map(([k,v])=>[k,v.id])),items:[...items.keys()].sort((a,b)=>a-b),effects:o.effects.map(describe)};
 return{result,calls,state};
}
test('full transformation/restoration coordinators match original instruction snapshots and call order',async()=>{
 assert.equal(fixture.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,1037);
 for(const [n,row]of fixture.rows.entries()){const actual=await run(row.case);try{assert.deepEqual(actual,{result:row.result,calls:row.calls,state:row.state});}catch(error){error.message=`case${n} ${JSON.stringify(row.case)}: ${error.message}`;throw error;}}
});
