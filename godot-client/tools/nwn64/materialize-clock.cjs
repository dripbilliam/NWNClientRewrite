'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const project=path.resolve(__dirname,'../..'),[label,binary,receipt]=process.argv.slice(2),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert(/^[a-z0-9-]+$/.test(label??''));
cp.execFileSync(process.execPath,[path.join(__dirname,'materialize-tests.cjs'),label,binary,receipt],{cwd:project,stdio:'inherit'});
const out=path.join(project,'.cache/nwn64',label),view=path.join(out,'project'),added=[];
function put(relative,bytes){const target=path.join(view,relative);assert(!fs.existsSync(target));fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});added.push({relative,bytes:bytes.length,sha256:sha(bytes)});}
for(const name of ['nwn64_clock_test.gd','nwn64_clock_probe.gd','nwn64_shared_clock_test.gd']){const file=path.join(project,'tests',name);if(fs.existsSync(file))put('tests/'+name,fs.readFileSync(file));}
// No renderer/rig preload: only the unmodified canonical declaration/getter,
// at its real path, to exercise identity proof without importing the world.
const full=fs.readFileSync(path.join(project,'systems/model_rigs.gd'));const normalized=full.toString().replace(/\r/g,'');
const getter=normalized.match(/^func playback_state\(id: int,model_index: int\) -> Dictionary:\n(?:\t[^\n]*\n)+/m)?.[0];assert(getter);assert(normalized.includes('\nvar entities: Dictionary = {}\n'));
const canonical=Buffer.from('extends Node\n\nvar entities: Dictionary = {}\n\n'+getter+'\n');
put('systems/model_rigs.gd',canonical);
const manifest={version:1,issue:'NWN-64',originalManifestSha256:sha(fs.readFileSync(path.join(out,'manifest.json'))),originalCanonicalScriptSha256:sha(full),added,scope:'Minimal canonical-path getter fixture only; actual source declaration/getter unchanged. No full world, rig construction, server/client or renderer preload; private native DLL only.'};
const file=path.join(out,'clock-manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(fs.readFileSync(file)),project:view,added:added.length}));
