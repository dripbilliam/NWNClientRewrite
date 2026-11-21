import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {clientAttackSound} from '../src/client_attack_sound.js';
import {nativeAudioResRef} from '../src/native_audio.js';
test('combat sound coordinator matches633 whole original executions and cosmetic draw order',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-attack-sound-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,633);
 for(const {case:c,result,calls:expected,draws}of oracle.cases){const source={id:1,objectType:5},target={id:99,objectType:c.targetType},calls=[],record={targetId:99,result:c.result,ranged:c.ranged,duration:c.duration??916,weaponAttackType:c.weaponAttackType??1};let drawIndex=0;
  const p={object:()=>c.missingTarget||c.invalidClient?null:target,animationCategory:()=>c.category,currentAnimation:o=>o===source?c.current:c.targetCurrent,appearance:o=>o===source?1:2,
   int:(table,row,column)=>{let found=true,value;if(table==='appearance')value=row===1?3:4;else if(table==='appearancesndset'){if(column==='MissIndex'){found=c.missFound??false;value=c.missIndex??0;}else value=c.weapon??0;}else value=11;calls.push(['int',table,row,column,found,value]);return{found,value};},
   string:(table,row,column)=>{let found=true,value;if(table==='weaponsounds')value=row+'_'+column;else if(table==='appearancesndset'){if(column==='Custom')value=c.custom??'';else value=c.armorType??'';found=Boolean(value);}else if(table==='defaultacsounds')value=row?'plate':'leather';else if(table==='placeableobjsnds')value='wood';else throw Error(table);calls.push(['string',table,row,column,found,value]);return{found,value};},
   equipped:(o,slot)=>o===source?(slot!==null&&(c.held??true)?{}:null):(c.armorItem??true)?{}:null,weaponMaterial:()=>c.material??9,armorIndex:()=>c.armorIndex??3,armorOverride:()=>c.override??'',doorTypes:()=>({doorType:c.doorType??5,genericType:6}),
   random:()=>{const values=c.draws??[17,31],value=values[drawIndex++%values.length];calls.push(['random',value]);return value;},play:(_o,ref,delay)=>calls.push(['play',nativeAudioResRef(ref),[1,2,3],1.5,13,delay,0])};
  assert.equal(Number(clientAttackSound(source,c.nullRecord?null:record,c.phase,p)),result,JSON.stringify(c));assert.deepEqual(calls,expected,JSON.stringify(c));assert.equal(drawIndex,draws,JSON.stringify(c));
 }
});
