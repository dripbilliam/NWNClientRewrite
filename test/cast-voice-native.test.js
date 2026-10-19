import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {importCreatureGender} from '../src/creature_appearance_state.js';
import {clientCastVoiceFields} from '../src/client_cast_voice_fields.js';
import {ClientCastVisualPresentation} from '../src/client_cast_visual_presentation.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-voice-observations.json',import.meta.url)));
test('native Gender import, phenotype/gender wire ordering and live-appearance copy retain distinct bytes',()=>{
 for(const row of capture.rows){const c=row.case,root=c.present?{Gender:c.rawGender}:{},gender=importCreatureGender(root,c.current);
  assert.equal(gender,row.importedGender,JSON.stringify(c));assert.deepEqual(row.gff,[{default:c.current}]);assert.equal(row.appearanceGender,gender);assert.equal(row.appearancePhenotype,c.phenotype);
  assert.deepEqual(row.wire,[c.phenotype,gender]);assert.equal(row.incomingGender,gender);assert.equal(row.clientGender,c.model?gender:255);assert.equal(row.clientPhenotype,c.model?c.phenotype:0);
 }
 assert.equal(capture.rows.length,5126);
});
test('native chant driver composed with imported local race/gender chooses exactly the same sounds and positions across all BYTE genders',()=>{
 for(const row of capture.rows){const c=row.case,canonical={objectType:5,animationState:15,nativeSpellId218:37,stats:{gender:c.current},authored:{Race:c.race,...c.present?{Gender:c.rawGender}:{}}},source={id:0x80000001,objectType:5,canonical,position:[1,2,3]},mirrors=new Map([[source.id,source]]),sounds=[],diagnostics=[];
  const voice=clientCastVoiceFields(canonical);assert.equal(voice.race,row.clientRace);assert.equal(voice.gender,row.importedGender);
  const p=new ClientCastVisualPresentation({objects:{mirrors,get:id=>mirrors.get(id)},spell:()=>({conjure:['','',''],conjureSoundMale:'male',conjureSoundFemale:'female',conjureSound:'generic'}),
   castFields:()=>[{type:'dword',value:37},{type:'object',value:0x7f000000},{type:'bool',value:c.suppressed}],voiceFields:clientCastVoiceFields,
   now:()=>({time:0}),difference:()=>({time:0}),sourceModel:()=>c.model?{}:null,nodePose:(_model,_part,position)=>{position.splice(0,3,7,8,9);return 1;},
   loadModel:()=>{throw new Error('Empty conjure references must not load any model');},destroyModel:()=>{},report:code=>diagnostics.push(code),oneShot:(resource,position,priority,gain)=>{assert.equal(gain,1.5);sounds.push({resource,position,gain:0x3fc00000,priority});}});
  p.update(0);const state=p.records.get(source.id);assert.deepEqual(sounds,row.sounds,JSON.stringify(c));assert.equal(state.gender,row.clientGender);assert.equal(state.race,row.clientRace);assert.equal(diagnostics.includes('visual.cast-voice-fields-unavailable'),false);p.dispose();
 }
});
test('unavailable source stats and malformed gender/race retain explicit failures',()=>{
 assert.throws(()=>clientCastVoiceFields({authored:{Race:6,Gender:1}}),/stats/);assert.throws(()=>clientCastVoiceFields({stats:{},authored:{Gender:1}}),/race/);assert.throws(()=>importCreatureGender({Gender:'1'}),/gender/);
});
