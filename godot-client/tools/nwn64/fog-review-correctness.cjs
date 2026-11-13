'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='.cache/nwn64/fog-fixture-c',read=mode=>JSON.parse(fs.readFileSync(root+'/'+mode+'/report.json')),before=read('before'),after=read('after');
assert(before.success&&after.success&&before.checks===64&&after.checks===64);assert.equal(before.cases.length,after.cases.length);
function packetBytes(values){const b=Buffer.alloc(values.length*4);values.forEach((v,i)=>b.writeFloatLE(v,i*4));return b.toString('hex');}
const rows=[];for(let i=0;i<before.cases.length;i++){
 const a=before.cases[i],b=after.cases[i];assert.equal(a.name,b.name);
 for(const phase of ['before','after']){assert.equal(packetBytes(a[phase].packet),packetBytes(b[phase].packet));for(const key of ['area_source','failure','publications'])assert.deepEqual(a[phase][key],b[phase][key]);}
 assert(a.samples===b.samples||a.samples===1&&b.samples===0&&a.before.area_source);
 rows.push({name:a.name,beforeSamples:a.samples,afterSamples:b.samples,publicationPacketF32BytesMatch:true,ownershipAreaFlagAndPublicationCountMatch:true});
}
const result={issue:'NWN-64',success:true,beforeChecks:before.checks,afterChecks:after.checks,rows,scope:'Offline comparison of actual complete emitter tick prefix controls. Owner instance IDs are process-local and intentionally not compared; ownership/lifetime behavior has explicit fixture assertions. Every retained fog packet matches in f32 bytes, publication counts/area flags/errors match; only authoritative sample calls are removed. No full simulation or FPS claim.'};
const output=root+'/comparison.json';assert(!fs.existsSync(output));fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,sha256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex'),cases:rows.length,beforeSamples:before.sample_count,afterSamples:after.sample_count}));
