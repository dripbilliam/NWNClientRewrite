import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeAmbientOwner} from '../src/native_ambient.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-ambient-observations.json',import.meta.url)));
test('all eight original packet40 server writers decode as scoped presentation commands',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const c of oracle.cases.filter(c=>c.kind==='wire'&&c.format===1))for(const hex of c.packets){
  const packet=Buffer.from(hex,'hex'),decoded=decodeServerGameMessage(packet);assert.equal(decoded.kind,'ambient-command');assert.equal(decoded.operation,c.minor);
  if([1,4,6].includes(c.minor))assert.equal(decoded.play,c.value&1);else assert.equal(decoded.value,c.value);
  if([3,7,8].includes(c.minor))assert.equal(Boolean(decoded.day),Boolean(c.day));
  for(let i=3;i<packet.length;i++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,i)),JSON.stringify(c));
  assert.throws(()=>decodeServerGameMessage(Buffer.concat([packet,Buffer.of(0,0)])));
 }
});
function boundaryOwner(c,actual){
 const stream=id=>({isPlaying:()=>c[id==='music'?'playingMusic':'playingAmbient']??c.playing??0,file:()=>c[id==='music'?'currentMusic':'currentAmbient']??c.current??'',play:()=>1,fadeAndStop(){},setVolume:volume=>actual.push({op:'volume',stream:id,volume})});
 const owner=new NativeAmbientOwner({state:{'10':0,'14':0,'1c':0,'24':0,'28':0,'2c':48,'2d':49},resolve:()=>({}),streams:{music:stream('music'),ambient:stream('ambient')}});
 for(const [key,resource]of Object.entries({'10':'music_day','14':'music_night','1c':'battle','24':'ambient_day','28':'ambient_night'}))owner.tracks[key]={resource,stingers:[]};
 owner.resolve=(music,id)=>{const key=music?(c.operation===5?'0xb0':c.day?'0x30':'0x70'):c.day?'0xf0':'0x130';actual.push({op:'resolve',music:Number(music),id:id>>>0,key});return{resource:'new_track'};};
 owner.enabled=true;owner.day=Boolean(c.fields?.['1ac']??1);owner.retry=c.fields?.['174']??0;owner.s['18']=c.fields?.['18']??0;
 for(const [slot,method]of ['music','battle','ambient'].entries())owner[method]=play=>actual.push({op:'owner',slot,play:Number(play)});
 return owner;
}
function fields(owner){return{'0x8':owner.s['8'],'0x18':owner.s['18'],'0x20':owner.s['20'],'0x10':owner.s['10'],'0x14':owner.s['14'],'0x1c':owner.s['1c'],'0x24':owner.s['24'],'0x28':owner.s['28'],'0x170':owner.delay,'0x174':owner.retry,'0x1ac':Number(owner.day),'0x1a8':Number(owner.enabled),'0x1b8':Number(owner.singleStream)};}
test('original track/delay/volume setters match full signed inputs and byte-volume truncation',()=>{
 for(const {case:c,calls,fields:expected,volumes}of oracle.cases.filter(c=>c.kind==='command')){const actual=[],owner=boundaryOwner(c,actual);owner.command({...c,day:Boolean(c.day)});assert.deepEqual(actual,calls,JSON.stringify(c));assert.deepEqual(fields(owner),expected,JSON.stringify(c));assert.deepEqual([owner.s['2c'],owner.s['2d']],volumes,JSON.stringify(c));}
});
test('original day/night classification and transitions agree for every native time-of-day category',()=>{
 for(const {case:c,calls,fields:expected}of oracle.cases.filter(c=>c.kind==='day-night')){const actual=[],owner=boundaryOwner(c,actual);owner.dayNight(c.timeOfDay);assert.deepEqual(actual,calls,JSON.stringify(c));assert.deepEqual(fields(owner),expected,JSON.stringify(c));}
});
test('original frame coordinator agrees on elapsed repeat delays, battle repeats and ambient admission',()=>{
 for(const {case:c,calls,fields:expected}of oracle.cases.filter(c=>c.kind==='frame')){const actual=[],owner=boundaryOwner(c,actual);owner.lastTime=0;owner.frame(c.elapsed);assert.deepEqual(actual,calls,JSON.stringify(c));assert.deepEqual(fields(owner),expected,JSON.stringify(c));}
});
test('complete original music, battle and ambient play owners agree on stream requests and native fields',()=>{
 const names={2:'music_day',3:'music_night',1:'battle',11:'ambient_day',12:'ambient_night'};
 for(const {case:c,calls,fields}of oracle.cases.filter(c=>c.kind==='owner')){
  const actual=[],stream=id=>({isPlaying:()=>c.playing,file:()=>c.current,play:(resRef,type)=>{actual.push({op:'play',stream:id,resRef,type});return c.success;},fadeAndStop:duration=>actual.push({op:'fade',stream:id,duration}),setVolume:volume=>actual.push({op:'volume',stream:id,volume})});
  const owner=new NativeAmbientOwner({state:{'18':c.battle,'20':c.ambient,'24':11,'28':12,'2c':48,'2d':49},resolve:(_music,id)=>({resource:names[id]}),streams:{music:stream('music'),ambient:stream('ambient')},singleStream:Boolean(c.single)});
  owner.enabled=Boolean(c.enabled);owner.day=Boolean(c.day);owner.category=c.category;
  // Same lower boundaries as the native oracle: nested virtual MusicPlay,
  // stinger helper and clock capture are observed, not recursively executed.
  owner.playStinger=()=>actual.push({op:'stinger'});owner.captureClock=()=>actual.push({op:'clock'});
  if(c.minor===4)owner.music=play=>actual.push({op:'owner',slot:0,play});
  if(c.minor===1)owner.music(c.play);else if(c.minor===4)owner.battle(c.play);else owner.ambient(c.play);
  assert.deepEqual(actual,calls,JSON.stringify(c));
  assert.deepEqual({'0x8':owner.s['8'],'0x18':owner.s['18'],'0x20':owner.s['20'],'0x174':owner.retry,'0x1bc':owner.category,'0x1c0':owner.ambientFailed},fields,JSON.stringify(c));
 }
});
