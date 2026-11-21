// Independent original resource header/event reader, used only for research.
// It writes hashes and event metadata, never model geometry or prepared assets.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const output=process.argv.find(x=>x.startsWith('--report='))?.slice(9);assert.match(output??'',/^native-parry-source-events-[a-z0-9-]+\.json$/);
const context=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),models=[],wanted=['1hcloseh','1hslashl','1hslashr'],cstring=(b,p,n)=>b.subarray(p,p+n).toString('ascii').split('\0')[0];
let name='pmh0';for(let depth=0;name&&name!=='null'&&depth<16;depth++){
 const b=Buffer.from(await context.getResource(name,2002)),clips=[];let parent;
 if(b.readUInt32LE(0)!==0){const text=b.toString('latin1');parent=/^\s*setsupermodel\s+\S+\s+(\S+)/im.exec(text)?.[1]?.toLowerCase();for(const m of text.matchAll(/\bnewanim\s+(1hcloseh|1hslashl|1hslashr)\b[^\n]*\n([\s\S]*?)\bdoneanim\b/gi))clips.push({name:m[1].toLowerCase(),events:[...m[2].matchAll(/^\s*event\s+(\S+)\s+(\S+)/gm)].map(x=>({time:Math.fround(Number(x[1])),name:x[2]}))});}
 else{parent=cstring(b,180,64).toLowerCase();const array=12+b.readUInt32LE(132),count=b.readUInt32LE(136);assert.ok(count<100000);for(let i=0;i<count;i++){const at=12+b.readUInt32LE(array+i*4),clip=cstring(b,at+8,64).toLowerCase();if(!wanted.includes(clip))continue;const e=12+b.readUInt32LE(at+184),n=b.readUInt32LE(at+188);assert.ok(n<100000);clips.push({name:clip,events:Array.from({length:n},(_,j)=>({time:b.readFloatLE(e+j*36),name:cstring(b,e+j*36+4,32)}))});}}
 models.push({name,parent,sha256:createHash('sha256').update(b).digest('hex'),clips});name=parent;
}
assert.equal(models.length,6);const result={success:true,models,scope:'Independent byte/text reading of original pmh0 supermodel chain, resource hashes and three selected physical event arrays; no native execution or complete upper combat listener proof.'};await fs.writeFile(path.join('godot-client/reports',output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,report:output,models:models.length}));
