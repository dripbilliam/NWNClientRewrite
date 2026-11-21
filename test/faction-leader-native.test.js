import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {factionLeader,scriptFactionLeader} from '../src/faction_manager.js';
import {NativeIdList} from '../src/native_id_list.js';
import {ModuleSession} from '../src/module_session.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-faction-leader-observations.json',import.meta.url)));
const bits=value=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,value,true);return d.getUint32(0,true);};
test('faction leader matches native private-PC/familiar preference and NPC positive-CR strict/tie ordering',()=>{
 assert.equal(data.rows.length,632);
 for(const row of data.rows){const c=row.case;if(c.mode==='rating')continue;const calls=[],objects=new Map([11,22,33].flatMap((id,i)=>c.missing===id?[]:[[id,{id,nativeField89c:(c.pc??[0,0,0])[i],hasStats:c.noStats!==id,rating:Math.fround((c.ratings??[1,2,2])[i])}]])),faction={id:7,members:new NativeIdList()};for(const id of c.members??[11,22,99,33])faction.members.append(id);
  const p={managerAvailable:()=>c.server!==false&&c.manager!==false,isNPC:id=>{calls.push(['npc',id]);return c.npc??1;},creature:id=>{calls.push(['creature',id]);return objects.get(id)??null;},possessed:o=>{calls.push(['possessed',o.id]);return c.possessed??0;},hasStats:o=>o.hasStats,challengeRating:o=>o.rating,faction:()=>{calls.push(['faction']);return c.faction===false?null:faction;}};
  if(c.mode==='leader'){assert.equal(factionLeader(faction,p),row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));}
  else if(c.pop===0){assert.equal(row.result,(-639)>>>0);assert.deepEqual(row.calls,[['pop']]);}
  else{calls.push(['pop']);const result=scriptFactionLeader(c.targetId,p);calls.push(['pushObject',result]);assert.equal(result,row.output);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(row.result,c.push===0?(-638)>>>0:0);}
 }
});

test('GetChallengeRating exposes original raw imported float and missing creature/stats zero through canonical registry lookup',()=>{
 const s=new ModuleSession(null),actor=s.register('creature','raw-challenge-rating',{authored:{},stats:{}});
 for(const row of data.rows){const c=row.case;if(c.mode!=='rating')continue;if(c.pop===0){assert.equal(row.result,(-639)>>>0);continue;}
  actor.nativeChallengeRatingD0=Math.fround((c.ratings??[1,2,2])[0]);actor.stats=c.noStats===11?null:{};const result=s.commands.GetChallengeRating([c.targetId===11?actor.id:0x7f000000]);assert.equal(bits(result),row.output,JSON.stringify(c));assert.equal(row.result,c.push===0?(-638)>>>0:0);
 }
});
