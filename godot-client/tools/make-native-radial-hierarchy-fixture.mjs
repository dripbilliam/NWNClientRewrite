// Offline oracle construction only. No runtime UI or game-server connection.
import fs from 'node:fs/promises';import path from 'node:path';
import {collectClassAbilities,classAbilityPage} from '../../src/feat_radial.js';
import {buildSpellLikeRadial} from '../../src/spell_like_radial.js';
const target=process.argv.find(v=>v.startsWith('--output='))?.slice(9);if(!target||!path.isAbsolute(target))throw Error('Absolute new fixture output required');
const cases=[];
for(let trial=0;trial<60;trial++){
 const classes=Array.from({length:1+trial%6},(_,index)=>({id:index+2,level:10,domains:index===0?[0,1]:[]}));
 const featRows=Array.from({length:160},(_,id)=>({FEAT:1000+id,ICON:'feat'+id,SUCCESSOR:id%9===1?id+1:0,SpellId:id+1,UsesPerDay:1}));
 const domains=[{Name:1,GrantedFeat:150,CastableFeat:trial%2},{Name:2,GrantedFeat:151,CastableFeat:trial%3===0?1:0}];
 const classRows=Array.from({length:8},(_,id)=>({Name:2000+id,Icon:'class'+id,FeatsTable:'custom_class_'+id})),tables={classes:{orderedRows:classRows},feat:{orderedRows:featRows},domains:{orderedRows:domains}};
 const owned=[];for(let id=1;id<160;id++)if((id+trial)%5!==0)owned.push(id);
 for(const cls of classes)tables[classRows[cls.id].FeatsTable]={orderedRows:Array.from({length:(trial*3+cls.id)%25},(_,index)=>({FeatIndex:1+cls.id*18+index%18,OnMenu:index%7===0?0:1}))};
 const actor={id:99,objectType:5,replicated:{stats:{classes}},playerState:{feats:owned,featUses:Object.fromEntries(owned.map(id=>[id,3]))}};
 const p={classCount:()=>classes.length,classType:i=>classes[i].id,classDomain:(i,d)=>classes[i].domains[d]??255,domain:id=>domains[id]?{featId:domains[id].GrantedFeat,castable:domains[id].CastableFeat}:null,classInfo:type=>{const table=tables[classRows[type].FeatsTable].orderedRows;return{featCount:table.length,storage:table};},classFeat:(cls,i)=>cls.storage[i]?{id:cls.storage[i].FeatIndex,onMenu:cls.storage[i].OnMenu}:null,grouped:()=>classes.length>3,owns:id=>owned.includes(id),feat:id=>featRows[id]?{successor:featRows[id].SUCCESSOR}:null,remaining:id=>owned.includes(id)?3:0,warning:()=>{}};
 const descriptors=collectClassAbilities(p).map(d=>({...d,group:!!d.group})),pages=[];for(let i=0;i<classes.length;i++)for(const start of [0,1,7,14,24])pages.push({index:i,start,expected:classAbilityPage(i,start,p).map(row=>row.next!==undefined?row:row.domain?row:{slot:row.slot,featId:row.featId})});
 // Use the actual legacy native-derived duplicate/physical-slot oracle.
 const pool=Array.from({length:trial%21},(_,index)=>({id:index%5===1?index-1:index,casterLevel:1+index%3,remaining:index%4===0?0:1}));
 actor.playerState.specialAbilities=pool.map(a=>({spell:a.id,level:a.casterLevel,state:a.remaining}));
 const innate=[];const valid=id=>id%11!==4;for(const start of [0,1,7,14]){
  const legacySpells={columns:['Name','IconResRef','Innate'],orderedRows:Array.from({length:30},(_,id)=>({Name:String(id+3000),IconResRef:'spell'+id,Innate:'0'}))};
  const menu=buildSpellLikeRadial({id:99,nativeSpellLikeAbilities:pool},null,{spells:legacySpells}, {spell:id=>valid(id)?{targetType:65535}:null,name:(_t,id)=>'spell'+id},{start,assignment:true});
  innate.push({start,expected:menu.entries.map(row=>row.start!==undefined?{slot:row.slot,next:row.start}:{slot:row.slot,spellId:row.binding.spellId,domainLevel:row.binding.domainLevel,uses:row.uses})});
 }
 tables.spells={orderedRows:Array.from({length:30},(_,id)=>valid(id)?{Name:3000+id,IconResRef:'spell'+id}: {})};
 cases.push({actor,tables,descriptors,pages,innate});
}
await fs.writeFile(target,JSON.stringify({version:1,binarySha256:'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a',scope:'Legacy reference derived from pinned binary; static cross-implementation decisions, no live native execution or server outcome',cases})+'\n',{flag:'wx'});console.log(JSON.stringify({cases:cases.length,output:target}));
