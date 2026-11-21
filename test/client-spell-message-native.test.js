import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {receiveSpellCombatMessage} from '../src/client_spell_message.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-spell-message-observations.json',import.meta.url)));
test('native CC8 receive branch matches read/overflow order, item/identified/alternate templates, colors, token mutation and output',()=>{
 for(const row of capture.rows){
  const c=row.case,calls=[],tokens={1:'old1',2:'old2'};let bool=0,overflow=0;
  const parse=ref=>ref===0xf721?`Item(${tokens[0]??''})`:ref===0x28f2?`${tokens[0]??''} ${tokens[1]??''} ${tokens[2]??''}`:`Alt(${tokens[0]??''})`;
  receiveSpellCombatMessage({objectId:()=>{calls.push(['object']);return 0x80000063;},dword:bits=>{calls.push(['dword',bits]);return 37;},bool:()=>{calls.push(['bool']);return[c.identified,c.casting,c.hasItem,c.localized][bool++];},
   overflow:()=>{calls.push(['overflow']);return Number(c.fail===++overflow);},byte:(bits,mode)=>{calls.push(['byte',bits,mode]);return 8;},localizedString:(a,b)=>{calls.push(['localized',a,b]);return'ItemLoc';},string:bits=>{calls.push(['string',bits]);return'ItemOverride';},
   spell:id=>{calls.push(['spell',id>>>0]);return c.spell?{name:123,altMessage:c.alt}:null;},sourceName:id=>{calls.push(['name',id]);return c.name?'Caster':null;},player:()=>{calls.push(['player']);return c.player?{id:c.playerId}:null;},
   tlk:ref=>{calls.push(['tlk',ref]);return'T'+ref;},token:(id,text)=>{calls.push(['token',id,text]);tokens[id]=text;},parse:ref=>{calls.push(['parse',ref]);return parse(ref);},baseItemName:id=>{calls.push(['baseItem',id]);return'Base';},display:(...args)=>calls.push(['display',...args])});
  assert.deepEqual({calls,tokens},{calls:row.calls,tokens:row.tokens},JSON.stringify(c));
 }
 assert.equal(capture.rows.length,1536);
});
