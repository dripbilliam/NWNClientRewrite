import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {availableCreationPortraits,customCreationPortraits} from '../src/creation_portraits.js';
import {creationPortraits} from '../src/character_creation.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';

const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-portrait-chooser-v1.json',import.meta.url)));
const table=orderedRows=>({orderedRows});
const row=(BaseResRef,Race=0,Sex=0,Plot=0)=>({BaseResRef,Race,Sex,Plot});
test('chooser availability agrees with2048 original add/dedup executions without reading images',async()=>{
 assert.equal(oracle.admission.length,2048);
 for(const c of oracle.admission){
  const available=await availableCreationPortraits({hasResource(name,type){const index='tsmlh'.indexOf(name.at(-1));return index>=0&&Boolean((type===3?c.tgaMask:c.ddsMask)&1<<index);},getResource(){throw Error('Catalog check read image bytes');}},['portrait_']);
  assert.equal(Number(available.length>0&&!c.duplicate),c.added,JSON.stringify(c));
  if(!c.duplicate||available.length){const rules={portraits:table([row('fixture'),row('fixture')]),creationAvailablePortraits:new Set(available.length?['po_fixture']:[])};assert.equal(creationPortraits({gender:0,raceId:0},rules).length,Number(available.length>0));}
 }
});
test('matching-race stable ordering agrees with32 original pass branches',()=>{
 assert.equal(oracle.race.length,32);
 for(const c of oracle.race){const ordered=creationPortraits({gender:0,raceId:c.selected},{portraits:table([row('candidate',c.value),row('separator',c.selected)])});assert.equal(ordered[c.passIndex]?.id===0,c.admitted,JSON.stringify(c));}
});
test('custom medium-file membership agrees with256 original suffix-byte branches',()=>{
 assert.equal(oracle.suffix.length,256);
 for(const c of oracle.suffix)assert.equal(customCreationPortraits(['p'+String.fromCharCode(c.byte)]).length>0,c.admitted,JSON.stringify(c));
 assert.deepEqual(customCreationPortraits(['x_m','x_M','x_h','other_l','other_t','last_s']),['x_']);
});
test('table portraits of either sex/plot remain excluded from the custom tail and rules can disable custom images',()=>{
 const rules={portraits:table([row('other',1,1),row('plot',0,0,1),row('generic',2),row('matching',0),row('matching',0)]),customPortraits:['po_other','po_plot','po_generic','loose_'],creationAvailablePortraits:new Set(['po_other','po_plot','po_generic','po_matching','loose_'])};
 assert.deepEqual(creationPortraits({gender:0,raceId:0},rules).map(p=>p.resref),['po_matching','po_generic','loose_']);
 rules.ruleset=table([{Label:'CHARGEN_ALLOW_CUSTOM_PORTRAITS',Value:'0'}]);assert.deepEqual(creationPortraits({gender:0,raceId:0},rules).map(p=>p.resref),['po_matching','po_generic']);
});
test('available image bases deduplicate and use nearest-size TGA/DDS catalog checks; malformed requests are bounded',async()=>{
 const reads=[],resolver={hasResource(name,type){reads.push([name,type]);return name==='first_h'&&type===2033||name==='second_t'&&type===3;}};
 assert.deepEqual(await availableCreationPortraits(resolver,['first_','second_','first_','missing_','']),['first_','second_']);
 assert.deepEqual(reads.slice(0,8),[['first_m',3],['first_m',2033],['first_l',3],['first_l',2033],['first_s',3],['first_s',2033],['first_h',3],['first_h',2033]]);
 const invalidRefs=[null,'not-an-array',42,['C:\\bad'],['x'.repeat(33)],[null],Array(32769).fill('x')];
 invalidRefs.push([['..','bad'].join('/')]);
 for(const refs of invalidRefs)await assert.rejects(availableCreationPortraits(resolver,refs),/Invalid/);
 await assert.rejects(availableCreationPortraits({},['x']),/unavailable/);
});
test('network catalog checks retain their resolver and reject completion after replacement or closure',async()=>{
 for(const action of['replace','close']){
  let release,entered;const gate=new Promise(resolve=>release=resolve),started=new Promise(resolve=>entered=resolve),resolver={async hasResource(){entered();await gate;return true;}};
  const session={closed:false,resolver,resourceResult:{ready:true}},pending=NetworkGameSession.prototype.creationPortraitAvailability.call(session,['fixture_']);await started;
  if(action==='replace')session.resolver={hasResource(){throw Error('Cross-server read');}};else session.closed=true;
  release();await assert.rejects(pending,/stale/);
 }
 const a={closed:false,resolver:{hasResource:(name,type)=>name==='one_m'&&type===3},resourceResult:{ready:true}},b={...a,resolver:{hasResource:(name,type)=>name==='two_m'&&type===2033}};
 assert.deepEqual(await NetworkGameSession.prototype.creationPortraitAvailability.call(a,['one_','two_']),['one_']);assert.deepEqual(await NetworkGameSession.prototype.creationPortraitAvailability.call(b,['one_','two_']),['two_']);
 await assert.rejects(NetworkGameSession.prototype.creationPortraitAvailability.call({...a,resourceResult:{ready:false}},['one_']),/unavailable/);
});
