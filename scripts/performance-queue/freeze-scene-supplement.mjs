// Offline discovery/export only. Never used as a live replay fallback.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {SceneCapture} from '../../electron/scene_capture.mjs';import {SceneCaptureArchive} from '../../electron/scene_capture_archive.mjs';
import {parseNWSyncManifest} from '../../src/nwsync_manifest.js';import {decodeNWSyncBlob} from '../../electron/nwsync_content.mjs';import {NWSyncReader} from '../../electron/nwsync_reader.mjs';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';import {installedNetworkResources} from '../../electron/installed_network_resources.mjs';import {defaultModsDirectory} from '../../electron/client_settings.mjs';
const args=process.argv.slice(2),arg=name=>args.find(a=>a.startsWith('--'+name+'='))?.slice(name.length+3);
for(const value of args)if(value!=='--run'&&!['capture','gaps','manifest','install','user-directory','output'].some(k=>value.startsWith('--'+k+'=')))throw Error('Unknown supplement option: '+value);
if(!args.includes('--run'))console.log('Prepared only. --run --capture=<private capture> --gaps=<replay report> --manifest=<cached sha1 manifest> --install=<NWN root> --user-directory=<Documents profile> --output=<new metadata report.json>');
else await main();
async function main(){
 for(const name of ['capture','gaps','manifest','install','user-directory','output'])if(!arg(name))throw Error('Missing --'+name);
 const parent=await SceneCaptureArchive.open(arg('capture')),report=JSON.parse(await fs.readFile(arg('gaps'),'utf8'));
 if(report.capture?.eventsSha256!==parent.manifest.eventsSha256)throw Error('Gap report belongs to another scene capture');
 const manifestFile=path.resolve(arg('manifest')),manifestBytes=await fs.readFile(manifestFile),sha1=bytes=>createHash('sha1').update(bytes).digest('hex'),manifestHash=sha1(manifestBytes);
 if(path.basename(manifestFile)!==manifestHash)throw Error('Cached manifest hash does not match its filename');
 const manifest=parseNWSyncManifest(manifestBytes),cacheDirectory=path.dirname(path.dirname(manifestFile)),install=path.resolve(arg('install')),userDirectory=path.resolve(arg('user-directory'));
 const source={version:1,parentEventsSha256:parent.manifest.eventsSha256,scope:'Offline reconstruction from cached manifest and local installation; original captured keys/misses are never replaced',manifest:manifestHash,manifestMatches:0,manifestMismatches:[],install,requests:[],talkTables:[]};
 // Verify common live-consumed keys, rather than assuming a same-named cached
 // catalog is appropriate. An override/mismatch requires manual investigation.
 for(const c of Object.values(parent.manifest.contexts))for(const[key,r]of Object.entries(c.resources)){
  if(r.missing||!manifest.catalog.has(key))continue;const b=await fs.readFile(path.join(parent.directory,'objects',r.sha256));if(sha1(b)!==manifest.catalog.get(key).hash)source.manifestMismatches.push(key);else source.manifestMatches++;
 }
 if(source.manifestMatches<1||source.manifestMismatches.length)throw Error('Cached server manifest does not match the recorded resource context');
 let reader;const native=()=>reader??=new NWSyncReader(path.join(userDirectory,'nwsync'));
 const layer={name:manifestHash,catalog:manifest.catalog,hasResource:(ref,type)=>manifest.catalog.has(String(ref).toLowerCase()+':'+type),getResource:async(ref,type)=>{
  const entry=manifest.catalog.get(String(ref).toLowerCase()+':'+type);if(!entry)throw Object.assign(Error('Offline manifest resource is unavailable'),{code:'RESOURCE_NOT_FOUND'});
  let encoded;try{encoded=await fs.readFile(path.join(cacheDirectory,'objects',entry.hash));}catch(e){if(e.code!=='ENOENT')throw e;encoded=await native().blob(entry.hash);}
  if(!encoded)throw Error('Required resource is absent from local caches');
  const bytes=encoded.subarray(0,4).toString('ascii')==='NSYC'?await decodeNWSyncBlob(encoded,{decompressZstd:(b,n)=>native().decompress(b,n)}):encoded;
  if(sha1(bytes)!==entry.hash||(entry.size!==null&&bytes.length!==entry.size))throw Error('Cached supplementary resource failed verification');return Uint8Array.from(bytes).buffer;
 }};
 let modsDirectory=await defaultModsDirectory(install),disabledMods=[];
 try{const settings=JSON.parse(await fs.readFile(path.join(path.dirname(path.dirname(parent.directory)),'client-settings.json'),'utf8'));if(typeof settings.modsDirectory==='string')modsDirectory=settings.modsDirectory;if(Array.isArray(settings.disabledMods))disabledMods=settings.disabledMods;}catch(e){if(e.code!=='ENOENT')throw e;}
 const capture=new SceneCapture({directory:path.dirname(parent.directory)}),contexts=new Map();let audio;
 try{
  const resolve=async id=>{if(!Object.hasOwn(parent.manifest.contexts,id))throw Error('Unknown gap context');if(!contexts.has(id)){const resolver=await openServerResourceContext({install,userDirectory,modsDirectory,disabledMods,resolved:[{kind:'nwsync',name:manifestHash,resource:layer}]});contexts.set(id,capture.wrapResolver(id,resolver));}return contexts.get(id);};
  audio=installedNetworkResources({install,userDirectory,modsDirectory,disabledMods,contentOptions:{fetch:()=>{throw Error('Offline supplement forbids all network access');}}});
  const requests=new Set(report.capture.unrecorded);
  // Placed sound lists choose randomly over time. Freeze their entire authored
  // reference lists so a longer comparison cannot create random coverage gaps.
  for await(const record of parent.events()){
   const message=record.event.message,sounds=message?.kind==='client-area'?message.area.sounds:message?.kind==='sound-object'&&message.operation===6?[message.sound]:[];
   for(const sound of sounds??[])for(const ref of sound.refs??[])if(ref)requests.add(record.context+':'+ref+':4');
  }
  for(const gap of requests){
   const match=/^(?:replay-)?(context-\d+):([^:]+):(texture|audio|\d+)$/.exec(gap);if(!match)throw Error('Invalid recorded coverage gap');const[,id,ref,kind]=match,resolver=await resolve(id);let result;
   try{
    if(kind==='texture'){const value=await resolver.getTextureResource(ref);result={type:value.type};}
    else if(kind==='audio'){const value=await audio.audioResource(resolver,ref,4);capture.resource(id,ref,value.type,value.bytes);result={type:value.type};}
    else{const type=Number(kind),bytes=type===4?await audio.waveResource(resolver,ref):await resolver.getResource(ref,type);capture.resource(id,ref,type,bytes);result={type};}
    source.requests.push({context:id,ref,kind,...result,found:true});
   }catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;if(kind==='texture')capture.texture(id,ref,null);else if(kind!=='audio')capture.miss(id,ref,Number(kind),error.code);else for(const type of [8,4])capture.miss(id,ref,type,error.code);source.requests.push({context:id,ref,kind,found:false,code:error.code});}
  }
  for(const id of Object.keys(parent.manifest.contexts)){
   const base=await fs.readFile(path.join(install,'lang/en/data/dialog.tlk'));capture.resource(id,'__talk_main',2018,base);source.talkTables.push({context:id,alias:'__talk_main',sha1:sha1(base)});
   try{const female=await fs.readFile(path.join(install,'lang/en/data/dialogf.tlk'));capture.resource(id,'__talk_main_female',2018,female);source.talkTables.push({context:id,alias:'__talk_main_female',sha1:sha1(female)});}catch(e){if(e.code!=='ENOENT')throw e;}
   const custom=manifest.entries.filter(e=>e.type===2018);if(custom.length!==1)throw Error('Select an unambiguous custom talk table before supplementing');const bytes=await layer.getResource(custom[0].name,2018);capture.resource(id,'__talk_custom',2018,bytes);source.talkTables.push({context:id,alias:'__talk_custom',sha1:sha1(new Uint8Array(bytes)),manifestResource:custom[0].name});
  }
  const sealed=await capture.close();if(!sealed.complete)throw Error('Supplement failed to seal: '+sealed.reason);await fs.writeFile(path.join(sealed.directory,'source.json'),JSON.stringify(source,null,2)+'\n',{flag:'wx'});
  await fs.writeFile(arg('output'),JSON.stringify({success:true,directory:sealed.directory,...source,bytes:sealed.bytes},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,directory:sealed.directory,found:source.requests.filter(r=>r.found).length,missing:source.requests.filter(r=>!r.found).length,bytes:sealed.bytes}));
 }finally{await capture.close();audio?.close();reader?.close();}
}
