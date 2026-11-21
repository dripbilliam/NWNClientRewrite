import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {gameTalkTokenValue,loadNamedTalkTokens,clientTokenAlignmentRef} from '../src/game_talk_tokens.js';
import {parse2da} from '../src/area.js';
import {talkTokenHash} from '../src/talk_tokens.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-game-talk-token-observations.json',import.meta.url)));
test('all game token selectors match original callback fields, fallback, gender restoration and suppression/color behavior',()=>{
 for(const row of native.rows.filter(r=>r.case.mode!=='alignment')){const c=row.case,state={gender:c.gender,suppression4c:c.suppression,nativeBC:c.bc,nativeB8:c.b8,nativeC0:123},calls=[],creature={},stats={},context={},b=value=>Buffer.from(value),value=gameTalkTokenValue({action:c.action,refs:[100,101,102,103],defaultRef:199},state,{
  fetch:ref=>{calls.push(['fetch',ref]);if(c.fetchGender>=0)state.gender=c.fetchGender;return b(`R${ref}`);},context:()=>c.context?context:null,object:()=>c.object?creature:null,creature:()=>c.creature?creature:null,stats:()=>c.stats?stats:null,
  fullName:()=>b('FULL'),firstName:()=>b(c.first),lastName:()=>b(c.last),raceName:(_s,lower)=>b(lower?'race':'RACE'),subrace:()=>b('SUBRACE'),className:(_s,lower)=>b(lower?'class':'CLASS'),classLevel:()=>c.level,alignment:(_s,lower)=>b(lower?'align':'ALIGN'),alignmentScore:(_s,law)=>law?c.law:c.good,deity:()=>b('DEITY'),
  world:()=>({native160:-5,native164:25,native16c:c.world,native17c:6,native17d:18}),playerName:id=>{assert.equal(id,123);return c.player?b('PLAYER'):null;},warning:line=>calls.push(['warning',line])});
  assert.equal(value===null?b('seed').toString('hex'):Buffer.from(value).toString('hex'),row.value,JSON.stringify(c));assert.equal(state.gender,row.gender,JSON.stringify(c));assert.equal(state.suppression4c,row.suppression,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
 assert.equal(native.rows.filter(r=>r.case.mode!=='alignment').length,1928);
});
test('client alignment text references match original signed-WORD leaf thresholds and native reference grids',()=>{
 const rows=native.rows.filter(r=>r.case.mode==='alignment');assert.equal(rows.length,162);for(const r of rows)assert.equal(clientTokenAlignmentRef(r.case.law,r.case.good,r.case.lower),r.result,JSON.stringify(r.case));
});
test('named-token loading uses physical columns, unsigned CRC order and the native16-byte hash bound',()=>{
 const t=parse2da('2DA V2.0\n\nA B C D E F G\n0 Zulu 3 -1 1 2 3 4\n1 Alpha 1 -1 5 6 7 8\n2 A_very_long_token_name 2 -1 9 10 11 12'),rows=loadNamedTalkTokens(t);
 assert.deepEqual(rows.map(r=>r.hash),rows.map(r=>r.hash).sort((a,b)=>a-b));const long=rows.find(r=>r.sourceRow===2);assert.equal(long.hash,talkTokenHash(Buffer.from('A_very_long_token_name'),16));assert.notEqual(long.hash,talkTokenHash(long.name));assert.equal(rows.find(r=>r.sourceRow===1).action,1);
});
