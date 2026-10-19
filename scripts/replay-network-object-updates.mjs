import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {NativeMessageReader} from '../src/native_message.js';
import {readObjectUpdates} from '../src/network_object_updates.js';
import {NetworkMessageAssembler} from '../src/network_messages.js';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
const input=process.argv[2],install=process.argv[3];if(!input||!install)throw new Error('Capture and installation paths are required');
const report=JSON.parse(await fs.readFile(input,'utf8')),module=report.transport.resources.resolved.find(r=>r.kind==='nwm');
if(!module)throw new Error('Captured module resource is unavailable');
const rules=await loadNetworkObjectRules(await openLocalModule(install,module.resource)),assembler=new NetworkMessageAssembler(),inflater=new NetworkMessageInflater();
for(const hex of report.transport.applicationFrames)assembler.push(Buffer.from(hex,'hex'));
try{for(const message of assembler.drain()){
 const bytes=await inflater.decode(message.bytes);if(bytes[1]!==5||bytes[2]!==1)continue;
 const reader=new NativeMessageReader(1);if(!reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1))throw new Error('Invalid native object-update stream');
 const decoded=readObjectUpdates(reader,{clientBuild:report.clientBuild,...rules});if(reader.messageReadOverflow()||decoded.complete&&reader.messageReadUnderflow())throw new Error('Invalid native object-update fields');console.log(JSON.stringify(decoded));
}}finally{inflater.close();}
