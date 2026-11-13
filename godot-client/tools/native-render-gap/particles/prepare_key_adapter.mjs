import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const directory=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),expected=process.argv[2],sha=b=>crypto.createHash('sha256').update(b).digest('hex');
if(!/^[0-9a-f]{64}$/.test(expected??''))throw Error('Explicit sealed V18 SHA256 required');
const source=path.join(directory,'replay-adapter-v18.cjs'),output=path.join(directory,'replay-adapter-v19.cjs');if(fs.existsSync(output))throw Error('Existing V19 retained');const original=fs.readFileSync(source);if(sha(original)!==expected)throw Error('Sealed V18 differs');let code=original.toString();
const replace=(a,b)=>{if(code.split(a).length!==2)throw Error('V18 seam differs: '+a.slice(0,90));code=code.replace(a,b);};
const start=code.indexOf('for(const f of s.renderGap.extraFlags)'),end=code.indexOf('].includes(f)',start);if(start<0||end<start)throw Error('V18 flag seam absent');code=code.slice(0,end)+",'--particle-key-survey'"+code.slice(end);
replace('function verifyNative(s,n){',`function keySurveyUse(k){
 if(k?.enabled!==true||k.stride!==120||k.clocks_per_frame!==0||k.global_key_capacity!==2048||k.global_key_overflow!==0||k.field_overflow!==0||!Number.isSafeInteger(k.frames)||k.frames<1||!Number.isSafeInteger(k.samples)||k.samples!==Math.ceil(k.frames/120))return false;
 if(![k.unknown_field_reads,k.unknown_map_fallbacks,k.clip_lookups,k.clip_hits].every(x=>Number.isSafeInteger(x)&&x>=0)||k.unknown_map_fallbacks>k.unknown_field_reads||k.clip_lookups<1||k.clip_hits>k.clip_lookups||!Array.isArray(k.global_keys)||!k.global_keys.length||k.global_keys.length>2048||!Array.isArray(k.private_fields)||k.private_fields.length>128)return false;
 const globalIds=new Set(),fieldIds=new Set();
 for(const r of k.global_keys){if(!Number.isSafeInteger(r.id)||r.id<0||r.id>=2048||globalIds.has(r.id)||typeof r.name!=='string'||!r.name.length||!Number.isSafeInteger(r.reads)||r.reads<1)return false;globalIds.add(r.id);}
 for(const r of k.private_fields){if(!Number.isSafeInteger(r.id)||r.id<0||r.id>=128||fieldIds.has(r.id)||typeof r.name!=='string'||!r.name.length||!Number.isSafeInteger(r.reads)||r.reads<1||!Number.isSafeInteger(r.map_fallbacks)||r.map_fallbacks<0||r.map_fallbacks>r.reads)return false;fieldIds.add(r.id);}
 return true;
}
function verifyNative(s,n){`);
replace(" const boundary=g.particle_boundary?.boundary??g.particle_boundary;"," requireUse('--particle-key-survey','keySurvey',keySurveyUse(g.key_survey));\n const boundary=g.particle_boundary?.boundary??g.particle_boundary;");
replace('verifyNative,coreSurveyUse,','verifyNative,coreSurveyUse,keySurveyUse,');
fs.writeFileSync(output,code,{flag:'wx'});console.log(JSON.stringify({source:{file:source,sha256:expected},output:{file:output,sha256:sha(code)},scope:'Source-only V19 key-counter derivative; sealed V18 unchanged.'}));
