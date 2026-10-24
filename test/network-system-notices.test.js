import test from 'node:test';
import assert from 'node:assert/strict';
import {networkSystemNotices} from '../src/network_system_notices.js';
import {NetworkText} from '../src/network_text.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkFrontend} from '../src/network_frontend.js';
import fs from 'node:fs';
import {GameAudio} from '../src/game_audio.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';

test('roster snapshots are silent; explicit Add events announce, with native DM visibility',()=>{
 const players=[{playerId:0xffffffff,objectId:0x80000001,name:'Player',isDM:0},{playerId:2,name:'DM',isDM:1}],previousPlayers=new Map([[players[0].playerId,players[0]]]);
 assert.deepEqual(networkSystemNotices({kind:'player-list-all',players}),[]);
 assert.equal(networkSystemNotices({kind:'player-list-add',players,server140:0},{previousPlayers}).length,1);
 assert.deepEqual(networkSystemNotices({kind:'player-list-add',players,server140:1},{previousPlayers}).map(n=>n.strRef),[6610,6611]);
 const notice=networkSystemNotices({kind:'player-list-add',players:[players[0]]})[0];assert.equal(notice.playerId,0xffffffff);assert.equal(notice.strRef,6610);assert.equal(notice.playerName,'Player');assert.equal(notice.suffix,'.');assert.equal(previousPlayers.size,1);
});

test('leave notification uses the pre-removal player, never fabricates an unknown player',()=>{
 const player={playerId:0x80000001,objectId:0xffffffff,name:'Departing',isDM:0},previousPlayers=new Map([[player.playerId,player]]),message={kind:'player-list-delete',playerId:player.playerId};
 const notice=networkSystemNotices(message,{previousPlayers})[0];assert.equal(notice.strRef,6612);assert.equal(notice.playerName,'Departing');assert.deepEqual(networkSystemNotices(message),[]);assert.deepEqual(networkSystemNotices(message,{previousPlayers,ready:false}),[]);assert.equal(previousPlayers.get(player.playerId),player);
});

test('only explicit journal notification28/12 produces feedback184; flags select native GUI cue',()=>{
 for(const operation of [1,2,3,4,5,6,7,8,9])assert.deepEqual(networkSystemNotices({kind:'journal',operation}),[]);
 for(const quest of [0,1])for(const changed of [0,1]){const title={text:'Module-defined title'},notice=networkSystemNotices({kind:'journal',operation:12,title,quest,changed})[0];assert.equal(notice.title,title);assert.equal(notice.strRef,6395);assert.equal(notice.color,'#ffff01');assert.equal(notice.sound,changed?'gui_quest_done':'gui_journaladd');assert.equal(notice.quest,quest);}
});

test('captured vanilla campaign28/12 packets select the verified native feedback TLK constant',()=>{
 const constant=JSON.parse(fs.readFileSync(new URL('../backups/animations/rea-journal-feedback-tlk-constant.json',import.meta.url))).structuredContent.normalized_result;assert.equal(constant.address,'0x140e45138');assert.equal(Buffer.from(constant.bytes_hex,'hex').readUInt32LE(),6395);
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-journal-notice-captured-v1.json',import.meta.url)));assert.equal(capture.sources.length,3);for(const source of capture.sources)for(const packet of source.packets){const message=decodeServerGameMessage(Buffer.from(packet,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}}),notice=networkSystemNotices(message)[0];assert.equal(message.title.strRef,57878);assert.equal(notice.strRef,6395);assert.equal(notice.sound,'gui_journaladd');}
});

test('PlayerName token reads canonical PLAYER_ID and supports a deleted record without mutating token state',async()=>{
 const world=new NetworkWorld(),diagnostics=[];world.players.set(0x80000001,{name:'Live Player'});
 const text=new NetworkText({world,getResource:async()=>new TextEncoder().encode('2DA V2.0\n\nToken Action Default A B C D\n0 PlayerName 23 -1 -1 -1 -1 -1'),talkString:async()=>({text:''}),diagnose:(...args)=>diagnostics.push(args)});
 assert.equal(await text.resolve({text:'<PlayerName> joined'},0x7f000000,{playerId:0x80000001}),'Live Player joined');world.players.delete(0x80000001);
 assert.equal(await text.resolve({text:'<PlayerName> left'},0x7f000000,{playerId:0x80000001,playerName:'Deleted <CUSTOM42>'}),'Deleted <CUSTOM42> left');
 assert.equal(await text.resolve({text:'<PlayerName>'},0x7f000000,{playerId:0x80000001}),'');assert.equal(world.players.size,0);assert.equal(diagnostics.length,0);
});

test('native journal owner oracle covers immediate feedback, deferred quest queue, GUI absence and toolbar highlight',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-journal-notices-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,64);
 for(const {case:c,events,queued}of oracle.cases){
  if(!c.present){assert.deepEqual(events,[]);assert.deepEqual(queued,[]);continue;}
  if(c.defer&&c.quest){assert.deepEqual(events,[]);assert.deepEqual(queued,[{textHex:c.textHex,changed:c.changed}]);continue;}
  const notice=networkSystemNotices({kind:'journal',operation:12,title:{text:Buffer.from(c.textHex,'hex').toString()},quest:c.quest,changed:c.changed})[0];assert.deepEqual(queued,[]);assert.deepEqual(events,[{kind:'feedback',type:184,textHex:c.textHex},{kind:'sound',resource:notice.sound},...(c.toolbar?[{kind:'highlight',enabled:1}]:[])]);
 }
});

test('frontend captures a departure before canonical deletion and dispatches feedback after applying server state',async()=>{
 const world=new NetworkWorld(),player={playerId:0x80000001,name:'Departed',isDM:0};world.players.set(player.playerId,player);const notices=[],front={id:1,world,phase:'playing',queue:Promise.resolve(),onHud:async message=>{assert.equal(world.players.has(player.playerId),false);notices.push(message);},onParty:async()=>{},showError:error=>{throw error;}};
 NetworkFrontend.prototype.receive.call(front,{sessionId:1,kind:'message',message:{kind:'player-list-delete',playerId:player.playerId,server140:0}});await front.queue;assert.equal(notices[0].kind,'system-notice');assert.equal(notices[0].playerName,'Departed');assert.equal(notices[0].strRef,6612);assert.equal(world.players.size,0);
});

test('journal GUI cues wait for audio unlock, stay centered and cannot play after disconnect during decoding',async()=>{
 let finishResource;const resource=new Promise(r=>finishResource=r),sources=[],ctx={state:'suspended',destination:{},listener:{},addEventListener(){},resume:async()=>{ctx.state='running';},close:async()=>{},decodeAudioData:async()=>({numberOfChannels:1,sampleRate:22050,duration:.5}),createPanner:()=>{throw new Error('GUI cue must be centered');},createBufferSource:()=>{const source={connect(){},disconnect(){},addEventListener(){},start(){source.started=true;},stop(){source.stopped=true;}};sources.push(source);return source;}},actor={id:0xffffffff},audio=new GameAudio({getResource:ref=>ref==='slow'?resource:Promise.resolve(new ArrayBuffer(1))},{getObject:()=>null,getPlayer:()=>actor,createContext:()=>ctx});
 await audio.play({objectId:actor.id,channel:'gui',resRef:'gui_journaladd'});assert.equal(audio.state.played,0);assert.equal(audio.pending.length,1);await audio.unlock();assert.equal(audio.state.played,1);assert.equal(sources[0].started,true);
 const slow=audio.play({objectId:actor.id,channel:'gui',resRef:'slow'});audio.dispose();finishResource(new ArrayBuffer(1));await slow;assert.equal(audio.state.played,1);assert.equal(sources[0].stopped,true);assert.equal(audio.pending.length,0);
});
