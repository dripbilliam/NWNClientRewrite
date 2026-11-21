'use strict';
// Source-only closure/semantic token checks; no engine, compiler or timing.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),label=process.argv[2]||'nwn64-preparation-b';
assert(/^[a-z0-9-]+$/.test(label));
const stage=path.join(root,'.cache/native-render-gap/particles',label),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const proposal=JSON.parse(fs.readFileSync(path.join(stage,'proposal.json'),'utf8'));
let checks=0;const check=(condition,message)=>{assert(condition,message);++checks;};
for(const branch of [proposal.control,proposal.candidate]){
 const manifestBytes=fs.readFileSync(path.join(branch.directory,'kernel-source-pins.json'));
 check(sha(manifestBytes)===branch.pinsSha256,'Frozen manifest SHA');
 const pins=JSON.parse(manifestBytes).pins;
 for(const pin of pins){const bytes=fs.readFileSync(path.join(branch.project,pin.relative));check(bytes.length===pin.bytes&&sha(bytes)===pin.sha256,'Exact private input '+pin.relative);}
}
const read=(branch,file)=>fs.readFileSync(path.join(proposal[branch].project,'native',file),'utf8').replace(/\r\n/g,'\n');
const tokens=source=>source.replace(/\s+/g,'');
let compact=read('candidate','particle_compact.hpp');
compact=compact.replace(/particle_preparation_audit::count\(particle_preparation_audit::BIRTHS_CALLED\);/g,'')
 .replace(/particle_preparation_audit::Span audit_(?:existing|births)\(particle_preparation_audit::(?:EXISTING|BIRTHS)\);/g,'')
 .replace(/audit_existing\.finish\(\);/g,'');
check(tokens(compact)===tokens(read('control','particle_compact.hpp')),'Original compact arithmetic, branches and operation order unchanged after removing probes');
const resident=read('candidate','particle_resident.hpp').replace('#include "particle_preparation_audit.hpp"','')
 .replace('particle_preparation_audit::CallbackScope audit_callback;','');
check(tokens(resident)===tokens(read('control','particle_resident.hpp')),'Original resident/callback logic unchanged after removing probes');
const originalPresentation=read('control','particle_presentation.hpp'),presentation=read('candidate','particle_presentation.hpp');
for(const pattern of [/const bool fused=[^;]+;/,/value\.profile=controls\.profile;/,/bool select\(size_t members\)\{[^}]+\}/]){
 const file=String(pattern).includes('select')?'particle_frame_sampler.hpp':'particle_presentation.hpp';
 const before=file==='particle_presentation.hpp'?originalPresentation:read('control',file),after=file==='particle_presentation.hpp'?presentation:read('candidate',file);
 check(before.match(pattern)?.[0]===after.match(pattern)?.[0]&&!!before.match(pattern),'Public profiling/fused/selection invariant '+pattern);
}
check((presentation.match(/owner->read_pose\(\)/g)||[]).length===(originalPresentation.match(/owner->read_pose\(\)/g)||[]).length,'Emitter pose read count unchanged');
check((presentation.match(/owner->read_pose\(true\)/g)||[]).length===(originalPresentation.match(/owner->read_pose\(true\)/g)||[]).length,'Source pose read count unchanged');
const header=read('candidate','particle_preparation_audit.hpp');
for(const [name,terminator] of [['Phase','PHASE_COUNT'],['Count','COUNT_COUNT']]){
 const members=header.match(new RegExp('enum '+name+':size_t \\{([^}]+)\\}'))[1].split(',').map(value=>value.trim());
 check(members.at(-1)===terminator,'Enum sentinel '+name);
 const strings=(header.match(new RegExp('const char\\* '+(name==='Phase'?'phase':'count')+'_names\\[[^\\]]+\\]=\\{([\\s\\S]*?)\\};'))[1].match(/"[^"]*"/g)||[]);
 check(strings.length===members.length-1,'Exact published schema width '+name);
}
check(header.includes('static constexpr size_t id_capacity=32768')&&header.includes('std::unordered_map<uint64_t,uint64_t>'),'Bounded census stores integer IDs/epochs only');
const changed=proposal.changes.map(row=>row.relative).sort();
check(JSON.stringify(changed)===JSON.stringify(['native/particle_resident.hpp','native/particle_frame_sampler.hpp','native/particle_presentation.hpp','native/particle_compact.hpp','native/particle_preparation_audit.hpp'].sort()),'Only approved private native files changed');
check(sha(fs.readFileSync(path.join(root,'tools/nwn64/prepare-source-preparation.cjs')))===proposal.factorySha256,'Frozen factory source unchanged');
for(const [relative,expected] of [
 ['.cache/native-kernel/nwn-particle-kernel.dll','485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d'],
 ['.tools/native-core/Godot_native_core_e_win64.exe','753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b']])
 check(sha(fs.readFileSync(path.join(root,relative)))===expected,'Accepted artifact intact '+relative);
const output=path.join(root,'.cache/nwn64',label+'-source-review');assert(!fs.existsSync(output),'Preserve previous report');fs.mkdirSync(output,{recursive:true});
const diff=cp.spawnSync('git',['diff','--no-index','--',proposal.control.project,proposal.candidate.project],{cwd:root,encoding:'utf8',maxBuffer:4*1024*1024});
check(diff.status===1&&!!diff.stdout,'Exact private source diff produced');fs.writeFileSync(path.join(output,'source.diff'),diff.stdout);
const report={version:1,success:true,checks,label,proposalSha256:sha(fs.readFileSync(path.join(stage,'proposal.json'))),sourceDiffSha256:sha(Buffer.from(diff.stdout)),engineStarts:0,compilations:0,sharedSourceWrites:0,scope:'Source closure and exact compact/resident token invariants only. C++ compile, GDScript parser, actual native engagement and runtime parity remain unverified until PC/runtime clearance.'};
fs.writeFileSync(path.join(output,'source-checks.json'),JSON.stringify(report,null,2)+'\n');process.stdout.write(JSON.stringify(report,null,2)+'\n');
