import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveClientRangedProjectile,clientRangedProjectileMetadata} from '../src/client_ranged_projectile.js';
import {parse2da} from '../src/area.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
test('132 complete original ranged receivers agree on hand launch, scale, target/reaction, path and impact lifetime',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-ranged-projectile-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,132);
 for(const row of fixture.cases){
  const c=row.case,source={id:0x80000011,objectType:5},target={id:0x80000012,objectType:c.targetType},commands=[],created=[],header={sourceId:c.source?source.id:OBJECT_INVALID,targetId:c.target?target.id:OBJECT_INVALID,from:[1.25,-2,3.5],to:[4,5,6],duration:250,appearance:c.appearance,path:c.path,baseItem:49,result:c.result};
  const cell=(column,row,value)=>commands.push({kind:'cell',column,row,value}),p={
   rangedMetadata:()=>{if(!c.baseValid)return null;const i=c.legacy?((c.ammo<<24>>24)+({0:-1,1:5,2:11,3:17,4:23,5:29}[c.appearance]??-1))>>>0:0;cell('Model',i,'fixture_'+i);return{ammunition:c.ammo,model:'fixture_'+i,shotSound:'shot',shotFound:true,impactSound:'impact',row:i};},
   object:id=>id===source.id&&c.source?source:id===target.id&&c.target?target:null,model:o=>c.model?o:null,modelHandle:()=>c.model,appearance:()=>0,
   nodePose:(_m,part,position)=>{commands.push({kind:'pose',part});position.splice(0,3,7,8,9);return c.pose;},
   oneShot:(resource,position)=>{const i=commands.find(e=>e.kind==='cell'&&e.column==='Model').row;cell('ShotSound',i,'shot');commands.push({kind:'sound',resource,position});cell('ImpactSound',i,'impact');},
   modelType:i=>{cell('modeltype',i,c.sourceModelType);return c.sourceModelType;},weaponScale:()=>({found:true,value:c.scale}),hitPartsEnabled:()=>c.config,random:()=>c.random,randomImpactPart:()=> 'fixture_impact',
   worldTime:()=>({day:0,time:0}),register:s=>{commands.push({kind:'construct'});created.push(s);},registerAI:()=>{},
   loadModel:async(s,name)=>{commands.push({kind:'load',model:name});if(c.load)s.model={};return c.load;},destroy:s=>{commands.push({kind:'destroy'});s.destroyed=true;},modelScale:(_m,value)=>commands.push({kind:'scale',value}),defaultMaterial:()=>commands.push({kind:'material',name:'DEFAULT'}),
   setTarget:(s,id,part)=>{commands.push({kind:'target',id,part});s.targetId=id;},trackProjectile:()=>commands.push({kind:'track'}),setStage:(_s,value)=>commands.push({kind:'stage',value}),
   setPosition:(_s,value)=>commands.push({kind:'position',value}),setOrientation:(_s,value)=>commands.push({kind:'orientation',value}),
   configurePath:(s,value)=>{commands.push({kind:'duration',value:s.totalTime},{kind:'path',value});},setScene:()=>commands.push({kind:'scene'}),ready:()=>{}
  };
  await receiveClientRangedProjectile(header,p);
  const info=JSON.stringify(c),expected=row.commands.filter(e=>e.kind!=='cell'||!['ShotSound','ImpactSound'].includes(e.column));
  // Native interleaves physical table reads before model-type work. Sound
  // resource lookup is preloaded by the asynchronous adapter; compare the
  // executed commands and each field independently of that preload order.
  assert.deepEqual(commands.filter(e=>e.kind!=='cell'||!['ShotSound','ImpactSound'].includes(e.column)),expected,info);
  if(created[0]&&!created[0].destroyed){const s=created[0];assert.deepEqual({result:s.result,rangedEffect:s.rangedEffect,impactCritical:s.impactCritical??0,impactDuration:s.impactDuration,facing:s.facing,impactSound:s.impactSound},row.fields,info);}
 }
});
test('active ammunition tables select physical data and preserve signed BYTE matching, old-table fallback and absent models',()=>{
 const baseitems=parse2da('2DA V2.0\n\nAmmunitionType\n0 1\n1 255'),table=text=>parse2da('2DA V2.0\n\n'+text),rules={baseitems,ammunitiontypes:table('Model ShotSound ImpactSound AmmunitionType DamageRangedProjectile\n0 first **** impact 2 0\n1 alternate shot hit 1 8\n2 duplicate shot hit 1 8\n3 signed shot hit -1 0')};
 assert.equal(clientRangedProjectileMetadata(rules,0,8).model,'alternate');assert.equal(clientRangedProjectileMetadata(rules,1,0).model,'signed');assert.equal(clientRangedProjectileMetadata(rules,0,0),null);assert.equal(clientRangedProjectileMetadata(rules,255,0),null);
 rules.ammunitiontypes=table('Model ShotSound ImpactSound\n0 legacy **** hit');assert.equal(clientRangedProjectileMetadata(rules,0,0).model,'legacy');assert.equal(clientRangedProjectileMetadata(rules,0,0).shotFound,false);assert.equal(clientRangedProjectileMetadata(rules,0,1),null);
});
