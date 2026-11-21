import fs from 'node:fs';
import assert from 'node:assert/strict';
import {NativeMessageWriter} from '../../src/native_message.js';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
const output=process.argv[2];if(!output||fs.existsSync(output))throw Error('Supply a new owned fixture path');
const cases=[];
for(const revision of [33,37])for(const force of [0,1])for(const hide of [0,1]){
 const writer=new NativeMessageWriter(1);writer.create(256,0xffffffff,1);writer.writeStringBytes(Buffer.from('OwnedLevelRules'));writer.writeBool(0);writer.writeStringBytes(Buffer.from('Owned module flags'));writer.writeByte(5);writer.writeCResRef(Buffer.from('owned_area'.padEnd(16,'\0')));writer.writeDword(0);writer.writeByte(0);writer.writeBool(force);writer.writeBool(hide);if(revision>=34)writer.writeBool(0);if(revision>=35)writer.writeBool(1);writer.setPrefix(Uint8Array.of(80,3,1));
 const packet=Uint8Array.from(writer.getWriteMessage().data),message=decodeServerGameMessage(packet,{serverBuild:{number:8193,revision,postfix:0}});assert.equal(message.kind,'module-info');assert.equal(typeof message.module.serverFlags.field158,'number');assert.equal(typeof message.module.serverFlags.field164,'number');assert.equal(message.module.serverFlags.field158,force);assert.equal(message.module.serverFlags.field164,hide);
 cases.push({revision,packet:Buffer.from(packet).toString('hex'),module:message.module,expected:{forceMaximum:force===1,hideHitPointGain:hide===1}});
}
fs.writeFileSync(output,JSON.stringify({success:true,cases,producer:'NativeMessageWriter→decodeServerGameMessage(module-info)→JSON; actual readBool numeric0/1, no game peer/server'},null,2)+'\n');
