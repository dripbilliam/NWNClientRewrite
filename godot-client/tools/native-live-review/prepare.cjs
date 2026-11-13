'use strict';
// Freeze reviewed code into an isolated manual-test client; never rewrite WIP.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),vm=require('node:vm');
const project=path.resolve(__dirname,'../..'),label=process.argv[2];assert(/^[a-z0-9-]+$/.test(label??''));
const out=path.join(project,'.cache/native-live-review',label),view=path.join(out,'project');assert(!fs.existsSync(out),'Fresh review stage required');fs.mkdirSync(view,{recursive:true});
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),pin=f=>{const b=fs.readFileSync(f);return {file:f,bytes:b.length,sha256:sha(b)};};
const put=(r,f)=>{assert(!path.isAbsolute(r)&&!r.split('/').includes('..'));const d=path.join(view,r);fs.mkdirSync(path.dirname(d),{recursive:true});fs.copyFileSync(f,d);return {relative:r,...pin(d),source:f};};
const identity=require('../native-feature-manifest.cjs').sourceIdentity(project),files=new Set(identity.files.map(r=>r.file));
const skip=new Set(['node_modules','reports','runtime-logs','backups']);
function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(e.name.startsWith('.')||skip.has(e.name)||e.isSymbolicLink())continue;const r=rel?rel+'/'+e.name:e.name,f=path.join(dir,e.name);if(e.isDirectory())walk(f,r);else if(/\.(?:gd|gdshader|gdshaderinc|gdextension|glsl|tscn|tres|json)$/.test(r))files.add(r);}}
walk(project);
for(const r of ['.godot/global_script_class_cache.cfg','tools/native-performance-runtime.cjs','tools/native-client-flags.cjs','tools/native-feature-manifest.cjs','.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/build-manifest.json'])files.add(r);
for(const r of ['.cache/native-clock-source-v1/clock_source.gdextension','.cache/native-clock-source-v1/nwn-clock-source.dll'])if(fs.existsSync(path.join(project,r)))files.add(r);
const excluded=new Set(['systems/native_render/rig_construction.gd','systems/native_render/model_placement_job.gd']);
for(const r of files){if(excluded.has(r)||/native-godot-particles|gpu_particle_architecture_test/.test(r))continue;put(r,path.join(project,r));}
fs.writeFileSync(path.join(view,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
fs.mkdirSync(path.join(view,'reports'),{recursive:true});
const overrides=[];
function restoreTree(base,rel=''){for(const e of fs.readdirSync(path.join(base,rel),{withFileTypes:true})){const r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())restoreTree(base,r);else if(r.endsWith('.gd'))overrides.push({reason:'Exclude unfinished NWN-62 publication work',...put(r,path.join(base,r))});}}
restoreTree(path.join(project,'.cache/nwn62/before'));
// Keep the live scope to reviewed gameplay changes; the cache/loader merge is
// reviewed separately and will not drag its combined WIP AssetService along.
overrides.push({reason:'Keep accepted pre-NWN70 loader dependency API',...put('systems/native_data/prework_store.gd',path.join(project,'.cache/nwn70/baseline/prework_store.gd'))});
for(const [r,name] of [['systems/model_rigs.gd','model_rigs.gd'],['systems/native_render/skeletal_rigs.gd','skeletal_rigs.gd']])overrides.push({reason:'Reviewed NWN-65 idle scheduling',...put(r,path.join(project,'.cache/nwn65/review-source',name))});
const expected={
 'systems/native_render/drive_collision_indexed.gd':'4f251cecfc9d72fa6fe3dd57ea9ca67b9333a1c8bc3cf544f3c99dab18412c39',
 'systems/visual_world.gd':'e68bc0a8243ad08c928a19d74757eb4267088e324f9e7875d01a3afa38b9d9ac',
 'systems/native_render/effect_world.gd':'d4ca5e7e59203d39c93fe885c138ecae90bf94fee212521e3dbe8b0f4431718d',
 'systems/native_render/effect_model.gd':'8b3b79fb1fa7993d81d4a87af1389eadcfb9014532c5f15a0987ef6e55dff875',
 'systems/native_nameplate.gd':'fc62e566cce153e9990bf4ad8646c3dd8cb2155b90391f7337be4d808dece20e',
 '.tools/native-core/Godot_native_core_e_win64.exe':'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b',
 '.cache/native-kernel/nwn-particle-kernel.dll':'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d'};
for(const [r,wanted]of Object.entries(expected))assert.equal(pin(path.join(view,r)).sha256,wanted,r);
assert(fs.existsSync(path.join(view,'data/native_text_codepages.json')),'Text codepage data required');
const source=path.join(out,'launcher');fs.mkdirSync(source);
const c={version:1,project,out,view,source,run:'native-review-'+label,electron:path.resolve(project,'../node_modules/electron/dist/electron.exe'),bootstrap:path.join(project,'tools/native-session-bootstrap.cjs'),host:path.join(project,'tools/native-session-host.cjs'),userdata:path.join(out,'working-settings'),appdata:path.join(out,'working-appdata'),localappdata:path.join(out,'working-localappdata'),compiledHost:path.join(source,'host.cjs')};
c.bootstrapSha256=pin(c.bootstrap).sha256;c.hostSha256=pin(c.host).sha256;c.bootstrapArguments=[c.bootstrap,'--run='+c.run,'--public-servers','--detailed-profiling=off'];
let host=fs.readFileSync(c.host,'utf8');function one(before,after){assert.equal(host.split(before).length-1,1,'Host seam changed: '+before.slice(0,70));host=host.replace(before,after);}
one("const project=path.resolve(__dirname,'..'),root=path.dirname(project),loaded=new Set();",'const project='+JSON.stringify(view)+',root='+JSON.stringify(path.dirname(project))+',loaded=new Set();');
one('nativeArgs.unshift(...performanceOptions.engineArguments);','nativeArgs.push('+[['render-preferences','native-render-preferences.cfg'],['menu-layout','native-menu-layout.cfg'],['lobby-preferences','native-lobby-preferences.cfg']].map(([name,file])=>JSON.stringify('--'+name+'='+path.join(c.userdata,file))).join(',')+');\n nativeArgs.unshift(...performanceOptions.engineArguments);');
const spawn="native=spawn(launch,launchArgs,{cwd:runtimeSelection.directory,windowsHide:true,env:{...process.env,...renderConfiguration.environment},stdio:['ignore','pipe','pipe']});";
one(spawn,spawn.replace('...renderConfiguration.environment}','...renderConfiguration.environment,APPDATA:'+JSON.stringify(c.appdata)+',LOCALAPPDATA:'+JSON.stringify(c.localappdata)+'}')+'\n await fs.writeFile('+JSON.stringify(path.join(out,'native-start.json'))+',JSON.stringify({pid:native.pid,hostPid:process.pid,engine:runtimeSelection.executable,engineSha256:runtimeSelection.executableSha256,sourceProject:project,normalEngine:true,automaticLogin:false})+"\\n",{flag:"wx"});');
new vm.Script(host);fs.writeFileSync(c.compiledHost,host,{flag:'wx'});c.compiledHostSha256=pin(c.compiledHost).sha256;
const bootstrap=fs.readFileSync(path.join(project,'tools/native-tracy/live/bootstrap-preload.cjs'),'utf8').replaceAll('NWN_PRIVATE_TRACY_CONFIG','NWN_LIVE_REVIEW_CONFIG');new vm.Script(bootstrap);fs.writeFileSync(path.join(source,'bootstrap-preload.cjs'),bootstrap,{flag:'wx'});
fs.copyFileSync(path.join(__dirname,'host-preload.cjs'),path.join(source,'host-preload.cjs'));fs.copyFileSync(path.join(project,'tools/native-window-screen.ps1'),path.join(source,'native-window-screen.ps1'));
c.sourceIdentity=require('../native-feature-manifest.cjs').sourceIdentity(view).sha256;
const configFile=path.join(out,'config.json');fs.writeFileSync(configFile,JSON.stringify(c,null,2)+'\n',{flag:'wx'});
const pins=[];function collect(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,e.name);if(e.isDirectory())collect(f);else pins.push(pin(f));}}collect(view);collect(source);
const proof={version:1,kind:'reviewed-normal-client-live-test',config:pin(configFile),files:pins,source:c.sourceIdentity,reviewedTickets:['NWN-63','NWN-65 (idle scheduling only)','NWN-66','NWN-67','NWN-68','NWN-69'],excluded:['Unfinished NWN-62 publication changes','Unfinished NWN-61 commits','Unselected NWN-64 native experiments','Combined NWN-70 loader integration'],overrides,expected,originalAssetsCopied:false,automaticLogin:false,tracy:false,performanceAccepted:false,scope:'Copied reviewed source and unchanged accepted uninstrumented engine/CPU particle DLL. This is live-test preparation, not live FPS acceptance.'};
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({config:configFile,run:c.run,source:c.sourceIdentity,files:pins.length,normalEngine:true,tracy:false}));
