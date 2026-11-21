import fs from 'node:fs';
import assert from 'node:assert/strict';
import {levelUpRequest} from '../../src/network_level_up.js';
import {NativeMessageReader} from '../../src/native_message.js';
const report=JSON.parse(fs.readFileSync(process.argv[2])),output=process.argv[3];if(!report.success||report.proposals.length!==5||!output||fs.existsSync(output))throw Error('Require five accepted actual-owner proposals and new output');
let checks=0;const rows=[];
for(const row of report.proposals){
 const {proposal,...options}=row,wire=levelUpRequest(proposal,options);assert.deepEqual([...wire.subarray(0,3)],[112,29,0]);checks++;
 const reader=new NativeMessageReader(1);assert.ok(reader.setReadMessage(wire.subarray(3),wire.length-3,0xffffffff,1));assert.equal(reader.readByte(),proposal.classId);if((row.level+1)%4===0)assert.equal(reader.readByte(),proposal.ability);assert.equal(reader.readByte(),proposal.hitDie);const mask=reader.readDword();for(let at=0;at<row.skillCount;at++)if(mask&(1<<(at&31)))assert.equal(reader.readByte(),proposal.skills[at]);assert.equal(reader.readWord(),proposal.skillPoints);const n=reader.readByte();assert.equal(n,proposal.feats.length);for(let at=0;at<n;at++)assert.equal(reader.readWord(),proposal.feats[at]);for(let level=0;level<10;level++)for(const key of ['known','removed']){const ids=proposal[key][level]??[],count=reader.readByte();assert.equal(count,ids.length);for(const id of ids)assert.equal(reader.readDword(),id);}assert.equal(reader.readInt(),proposal.fieldE34);reader.readCExoString();assert.equal(reader.readInt(),proposal.fieldE30);reader.readCExoString();
 if(row.pickDomains)assert.deepEqual([reader.readByte(),reader.readByte()],row.expectedDomains);if(row.pickSchool)assert.equal(reader.readByte(),row.expectedSchool);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);checks++;
 if(row.pickSchool){assert.throws(()=>levelUpRequest({...proposal,school:-1},options),/Invalid native level-up school/);checks++;}if(row.pickDomains){assert.throws(()=>levelUpRequest({...proposal,domains:[-1,1]},options),/Invalid native level-up domains/);checks++;}
 rows.push({label:row.label,bytes:wire.length,school:proposal.school,domains:proposal.domains});
}
fs.writeFileSync(output,JSON.stringify({success:true,checks,rows,scope:'Real levelUpRequest scalar writer/reader roundtrip and unchanged strict school/domain admission on detached actual SourceOwner proposals; no server or UI acceptance.'},null,2)+'\n');
