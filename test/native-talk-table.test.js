import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {fetchTalkRecord,fetchTalkRecordSync,scriptGetStringByStrRef,scriptGetStringByStrRefSync,createTalkRecord,assignTalkRecord} from '../src/native_talk_table.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-talk-table-observations.json',import.meta.url))),hex=bytes=>Buffer.from(bytes).toString('hex');
const snapshot=r=>({text:hex(r.text),sound:hex(r.sound),durationBits:r.durationBits});
function fixture(c){
 const raw=Buffer.alloc(100+Buffer.from(c.text,'hex').length),entry=Buffer.alloc(40);entry.writeUInt32LE(c.flags);Buffer.from(c.sound,'hex').copy(entry,4,0,16);entry.writeUInt32LE(c.offset,28);entry.writeUInt32LE(c.length,32);entry.writeUInt32LE(c.durationBits,36);entry.copy(raw,20);entry.copy(raw,60);Buffer.from(c.text,'hex').copy(raw,100);
 const file=name=>({name,version14:0x302e3356,count1c:name==='female'&&c.femaleOnly&&c.fail==='range'?0:c.count,textOffset20:100,bytes:c.sizeLimit<0?raw:raw.subarray(0,c.sizeLimit),position:0}),male=file('male'),female=file('female'),state={gender:c.gender},warnings=[],parses=[],cacheWrites=[],io=[];
 const p={override:()=>c.override?Buffer.from('override<TOKEN>'):null,file:(custom,g)=>custom&&c.missingCustom||!custom&&c.missingBase?null:g===1?female:male,
  warning:line=>warnings.push(line),parse:(_s,r)=>{parses.push(hex(r.text));r.text=Buffer.concat([Buffer.from('p:'),r.text]);},cached:()=>c.cached?{text:Buffer.from('cached'),sound:Buffer.from('CACHE'),durationBits:0x40200000}:null,
  cache:(f,index,r)=>cacheWrites.push({file:f.name,index,value:snapshot(r)}),size:f=>f.bytes.length,seek:(f,offset)=>{f.position=offset;io.push(['seek',f.name,offset]);return Number(!(c.fail===(offset<100?'entrySeek':'textSeek')&&(f===female||!c.femaleOnly)));},
  read:(f,destination,size)=>{const phase=f.position<100?'entry':'text',count=c.fail===phase+'Read'&&(f===female||!c.femaleOnly)?Math.max(0,size-1):size,bytes=f.bytes.subarray(f.position,f.position+count);destination.set(bytes);f.position+=bytes.length;io.push(['read',f.name,size,bytes.length]);return bytes.length;},
  allocate:length=>({bytes:new Uint8Array(length).fill(0xa5),defined:new Uint8Array(length).fill(1)})};
 return{state,p,warnings,parses,cacheWrites,io};
}
test('FetchInternal matches complete original file/cache/override/fallback control flow and persistent gender',async()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='fetch')){const c=row.case,{state,p,warnings,parses,cacheWrites,io}=fixture(c),out={text:Buffer.from('initial'),sound:Buffer.from('old'),durationBits:0x41100000};
  const result=await fetchTalkRecord(state,c.ref,out,c.parse,p),context=JSON.stringify(c);assert.equal(result,row.result,context);assert.deepEqual(snapshot(out),row.value,context);assert.equal(state.gender,row.gender,context);assert.deepEqual(warnings,row.warnings,context);assert.deepEqual(parses,row.parses,context);assert.deepEqual(cacheWrites,row.cacheWrites,context);assert.deepEqual(io,row.io,context);
 }
});
test('GetStringByStrRef matches original optional gender, string transfer and error contracts',async()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='script')){const c=row.case,{state,p,warnings,parses,cacheWrites,io}=fixture(c),popped=c.pop1&&(c.argc<2||c.pop2);assert.equal(row.result,!popped?0xfffffd81:c.push?0:0xfffffd82);
  if(!popped){assert.equal(row.value,null);assert.deepEqual(row.io,[]);continue;}
  const result=await scriptGetStringByStrRef(state,c.ref,c.argc<2?0:c.requestedGender,p);assert.equal(hex(result),row.value,JSON.stringify(c));assert.equal(state.gender,row.gender);assert.deepEqual(warnings,row.warnings);assert.deepEqual(parses,row.parses);assert.deepEqual(cacheWrites,row.cacheWrites);assert.deepEqual(io,row.io);
  const sync=fixture(c);assert.equal(hex(scriptGetStringByStrRefSync(sync.state,c.ref,c.argc<2?0:c.requestedGender,sync.p)),row.value);assert.equal(sync.state.gender,row.gender);assert.deepEqual(sync.io,row.io);
 }
 assert.equal(native.rows.length,604);
});
test('unknown short-read heap bytes are diagnosed instead of fabricating original text',async()=>{
 const c={...native.rows[0].case,gender:0,ref:0,flags:1,fail:'textRead',length:6},fixtureCase=fixture(c);fixtureCase.p.allocate=length=>({bytes:new Uint8Array(length),defined:new Uint8Array(length)});
 await assert.rejects(fetchTalkRecord(fixtureCase.state,0,createTalkRecord(),0,fixtureCase.p),/unknown allocated bytes/);
});
test('talk record assignment owns Buffer-backed text and sound inputs',()=>{
 const text=Buffer.from('owned'),sound=Buffer.from('WAVE'),record=assignTalkRecord(createTalkRecord(),{text,sound,durationBits:0});text.fill(0);sound.fill(0);assert.equal(Buffer.from(record.text).toString(),'owned');assert.equal(Buffer.from(record.sound).toString(),'WAVE');
});
test('synchronous client fetch uses the same complete original control-flow cases as asynchronous script fetch',()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='fetch')){const{state,p,warnings,parses,cacheWrites,io}=fixture(row.case),out={text:Buffer.from('initial'),sound:Buffer.from('old'),durationBits:0x41100000};assert.equal(fetchTalkRecordSync(state,row.case.ref,out,row.case.parse,p),row.result);assert.deepEqual(snapshot(out),row.value);assert.equal(state.gender,row.gender);assert.deepEqual(warnings,row.warnings);assert.deepEqual(parses,row.parses);assert.deepEqual(cacheWrites,row.cacheWrites);assert.deepEqual(io,row.io);}
});
