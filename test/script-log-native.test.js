import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptLogEntry,scriptLogTimestamp,sendDebugInfoString} from '../src/script_log.js';
import {ScriptLogRuntime} from '../src/script_log_runtime.js';
import {decodeGffText} from '../src/gff_text.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-log-observations.json',import.meta.url)));
const decode=hex=>decodeGffText(Buffer.from(hex,'hex'));

test('timestamped script log matches complete original owner, debug gates and live player pointer order',async()=>{
 let count=0;
 for(const row of oracle.rows.filter(r=>r.case.mode==='script')){
  const c=row.case,calls=[],list={entries:[...c.players],count:c.count};let sends=0;
  const actual=await scriptLogEntry({pop:type=>{calls.push(['pop',type]);return{ok:Boolean(c.pop),value:c.nullText?'':decode(c.hex)};},
   timestamp:()=>{calls.push(['timestamp']);return c.nullTimestamp?'':decode(c.timestampHex);},log:(text,metadata)=>{calls.push(['log',metadata]);assert.equal(text,`[${metadata.timestamp}] ${metadata.text}\n`);},
   debugMode:()=>{calls.push(['debugMode']);return c.debugMode;},configBool:(...args)=>{calls.push(['configBool',...args]);return Boolean(c.config);},
   players:()=>{calls.push(['players']);return list;},message:()=>{calls.push(['message']);return 42;},send:(_m,player,text)=>{calls.push(['send',player,text]);if(c.mutateList&&++sends===1){list.count=0;list.entries[1]=0;}return c.sendResult;}});
  assert.equal(actual>>>0,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  assert.equal(row.frees,c.pop===0?2:(c.debugMode|0)!==0?(c.config?7:5):4);count++;
 }
 assert.equal(count,134);
});

test('local wall-clock formatting matches original ctime timestamp shortening and replacement',()=>{
 const rows=oracle.rows.filter(r=>r.case.mode==='timestamp');
 for(const row of rows){const c=row.case;assert.equal(row.timestamp,decode(c.ctimeHex).split('\0')[0].slice(0,19));assert.deepEqual(row.calls,[['time'],['ctime'],['format','%.19s']]);assert.equal(row.frees,1);
  if(c.date){const[y,m,d,h,min,s]=c.date;assert.equal(scriptLogTimestamp(new Date(y,m-1,d,h,min,s)),row.timestamp);}
 }
 assert.equal(rows.length,9);assert.throws(()=>scriptLogTimestamp(new Date(NaN)),/wall clock/);
});

test('DebugInfo_String sender matches original owning-string transfer, payload failure and transport selectors',async()=>{
 let count=0;
 for(const row of oracle.rows.filter(r=>r.case.mode==='sender')){
  const c=row.case,bytes=Uint8Array.from(Buffer.from(c.hex,'hex')),string={bytes,length:bytes.length},calls=[];
  const actual=await sendDebugInfoString({},c.playerId,string,{create:(_m,...args)=>calls.push(['create',...args]),
   copyString:s=>{calls.push(['copy',Buffer.from(s.bytes).toString('hex'),s.length]);return{bytes:s.bytes[0]===0?new Uint8Array():s.bytes.slice(),length:s.bytes[0]===0?0:s.length};},
   writeString:(_m,s,bits)=>{calls.push(['writeString',Buffer.from(s.bytes).toString('hex'),bits]);s.bytes=null;s.length=0;},payload:()=>({status:c.payloadStatus,data:'payload',length:17}),playerId:p=>p,
   transport:(_m,id,major,minor,data,length)=>{assert.equal(data,'payload');calls.push(['transport',id,major,minor,length]);return c.sendResult;}});
  assert.equal(actual>>>0,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(string.bytes,bytes);assert.equal(string.length,bytes.length);count++;
 }
 assert.equal(count,40);
});

test('local script runtime preserves canonical recipient IDs and sends decoded string body only behind both gates',async()=>{
 const object={id:0x80000001},messages=[],session={diagnosticContext:id=>({objectId:id}),combat:{broadcastProviders:()=>({clients:()=>[{object}]})},onCombatMessage:message=>messages.push(message)},start=runtimeDiagnostics.records.length;
 const log=new ScriptLogRuntime(session,{now:()=>new Date(2026,0,1,0,0,0)}),frame={self:object.id,program:{name:'log_test'},pc:13};
 await log.command(['First %s\0ignored'],frame);assert.deepEqual(messages,[]);
 log.debugMode100f0=1;await log.command(['Second'],frame);assert.deepEqual(messages,[]);
 log.debugLogToPlayers=true;await log.command(['Echo €'],frame);
 assert.deepEqual(messages,[{type:'debug-info-string',recipientId:object.id,text:'[ServerLog:Thu Jan  1 00:00:00] Echo €',nativeMessage:{major:33,minor:5}}]);
 const records=runtimeDiagnostics.records.slice(start),entries=records.filter(r=>r.code==='script.timestamped-log-entry');assert.equal(entries.length,3);assert.equal(entries[0].message,'[Thu Jan  1 00:00:00] First %s\n');assert.ok(entries.every(r=>r.context.objectId===object.id&&r.context.script==='log_test'&&r.severity==='info'));
 assert.equal(records.filter(r=>r.code==='script-log.local-delivery').length,1);
 const before=runtimeDiagnostics.records.length;await assert.rejects(log.stack({pop:()=>{throw new Error('typed pop failed');}},frame),/typed pop failed/);assert.equal(runtimeDiagnostics.records.length,before);
});
