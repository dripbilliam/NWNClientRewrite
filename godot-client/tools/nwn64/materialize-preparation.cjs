'use strict';
// Source/binary copy only; this never launches Godot or a compiler.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const [label,binary,receipt]=process.argv.slice(2),sha=value=>crypto.createHash('sha256').update(value).digest('hex');
assert(/^[a-z0-9-]+$/.test(label||'')&&binary&&receipt);
cp.execFileSync(process.execPath,[path.join(__dirname,'materialize-tests.cjs'),label,binary,receipt],{cwd:root,stdio:'inherit'});
const relative='tests/nwn64_preparation_test.gd',bytes=fs.readFileSync(path.join(root,relative));
const output=path.join(root,'.cache/nwn64',label),project=path.join(output,'project');
fs.writeFileSync(path.join(project,relative),bytes,{flag:'wx'});
const manifest={version:1,issue:'NWN-64/NWN-73',project,baseManifestSha256:sha(fs.readFileSync(path.join(output,'manifest.json'))),files:[{relative,bytes:bytes.length,sha256:sha(bytes)}],engineStarts:0,compilations:0,sharedWrites:0,scope:'Private pure-kernel preparation sampler fixture. Baseline helper already pins private DLL/build receipt and recursive dependencies.'};
const file=path.join(output,'preparation-manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
process.stdout.write(JSON.stringify({file,sha256:sha(fs.readFileSync(file)),project})+'\n');
