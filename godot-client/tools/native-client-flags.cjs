'use strict';
// Configuration/source inventory only. Never imports Electron, decoders or renderers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const registryFile=path.resolve(__dirname,'../systems/native_data/client_feature_registry.json');
const registry=JSON.parse(fs.readFileSync(registryFile,'utf8'));
if(registry.version!==1)throw Error('Unsupported native feature registry');
const definitions=new Map(registry.features.map(row=>[row.name,row]));
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function validateValue(definition,value){
 if(definition.type==='integer'){
  if(!/^[1-9][0-9]*$/.test(value)||!Number.isSafeInteger(Number(value))||Number(value)<definition.minimum||Number(value)>definition.maximum)throw Error('Invalid --'+definition.name+'; expected integer '+definition.minimum+'..'+definition.maximum);
 }else if(!definition.choices.includes(value))throw Error('Invalid --'+definition.name+'; expected '+definition.choices.join('|'));
 return value;
}
function parseManagedOptions(argv=[],{native=false}={}){
 if(!Array.isArray(argv)||argv.some(value=>typeof value!=='string'))throw Error('Client arguments must be strings');
 const values=Object.fromEntries(registry.features.map(row=>[row.name,row.default])),explicit=[];
 for(const argument of argv){
  if(!argument.startsWith('--'))continue;
  const split=argument.indexOf('='),name=argument.slice(2,split<0?undefined:split),definition=definitions.get(name);
  if(!definition)continue;
  if(!native&&definition.directHost===false)throw Error('--'+name+' is a native output; select --loading-pipeline instead');
  if(explicit.includes(name))throw Error('Repeated client option --'+name);
  let value=split<0?definition.bare:argument.slice(split+1);
  if(value===undefined)throw Error('--'+name+' requires a value');
  values[name]=validateValue(definition,value);explicit.push(name);
 }
 for(const name of explicit){
  const definition=definitions.get(name);
  for(const [dependency,value]of Object.entries(definition.requires??{}))if(values[dependency]!==value)throw Error('--'+name+' requires --'+dependency+'='+value);
 }
 return {values,explicit};
}
// Environment choices are canonicalized once at the ingress. Frozen production
// selections persist that argument and revalidate with an empty environment.
function canonicalPerformanceArguments(argv=[],{env={}}={}){
 if(!Array.isArray(argv)||argv.some(value=>typeof value!=='string'))throw Error('Client arguments must be strings');
 const choices=argv.filter(value=>value==='--native-runtime'||value.startsWith('--native-runtime='));
 if(choices.length>1)throw Error('Repeated native client option --native-runtime');
 if(choices.length&&!/^--native-runtime=(editor|release)$/.test(choices[0]))throw Error('Invalid native engine runtime');
 const choice=choices.length?undefined:env.NWN_GODOT_RUNTIME;
 if(choice!==undefined&&choice!==''&&!['editor','release'].includes(choice))throw Error('Invalid NWN_GODOT_RUNTIME');
 return choice?[...argv,'--native-runtime='+choice]:[...argv];
}
function resolvePerformanceOptions(argv=[],context={}){
 argv=canonicalPerformanceArguments(argv,context);
 const parsed=parseManagedOptions(argv),nativeArguments=[];
 const names=new Set(argv.filter(a=>a.startsWith('--')).map(a=>a.slice(2).split('=',1)[0]));
 // Covers every declared host/bootstrap check, including composed action checks
 // and scalar prework-check-limit, plus the visual and particle-crowd routes.
 const isolated=[...names].some(name=>/(?:^|-)(?:check|visual|probe)(?:-|$)/.test(name)||['action-particle-crowd','local-stream-abort'].includes(name));
 const runtimeChoice=argv.find(value=>value.startsWith('--native-runtime='))?.slice('--native-runtime='.length);
 const nativeRuntime={value:runtimeChoice??'editor',explicit:runtimeChoice!==undefined};
 const packaged=nativeRuntime.value==='release';
 if(nativeRuntime.explicit&&parsed.explicit.includes('performance-runtime')&&parsed.values['performance-runtime']==='verified-native')throw Error('Explicit editor/release runtime conflicts with --performance-runtime=verified-native');
 const explicitStandard=parsed.explicit.includes('performance-runtime')&&parsed.values['performance-runtime']==='standard';
 const normalGameplay=!isolated&&!nativeRuntime.explicit&&!explicitStandard;
 const preset=registry.normalGameplayDefaults;
 if(normalGameplay){
  if(!preset||preset.version!==1)throw Error('Normal gameplay performance policy is unavailable');
  for(const [name,value]of Object.entries(preset.values))if(!parsed.explicit.includes(name))parsed.values[name]=validateValue(definitions.get(name),value);
 }
 // The visible legacy Profile switch still selects logging. Only explicit,
 // conflicting detailed-profiling input rejects; implicit normal OFF yields.
 if(argv.includes('--native-profile')){
  if(parsed.explicit.includes('detailed-profiling')&&parsed.values['detailed-profiling']!=='saved')throw Error('Do not combine --native-profile with an explicit detailed-profiling policy');
  if(!parsed.explicit.includes('detailed-profiling'))parsed.values['detailed-profiling']='saved';
 }
 for(const name of ['drive-collision','drive-height-plan','drive-preview-height-index','drive-preview-worker','drive-preview-surface-cache','light-input-registry','world-snapshot-preparation','world-snapshot-verified-packet','entry-commit','entry-commit-budget','binary-clips','particle-animation-snapshot']){
  if(parsed.explicit.includes(name)||(normalGameplay&&name==='light-input-registry'))nativeArguments.push('--'+name+'='+parsed.values[name]);
 }
 if(parsed.values['detailed-profiling']!=='saved')nativeArguments.push('--profile='+(parsed.values['detailed-profiling']==='on'?'true':'false'));
 const runtimePolicy=require('./native-performance-runtime.cjs');
 const renderCore=runtimePolicy.acceptedRenderCore(parsed.values['light-input-registry'],normalGameplay&&parsed.values['performance-runtime']==='verified-native');
 nativeArguments.push(...renderCore.flags);
 const thread=parsed.values['render-thread'];
 return {runtime:parsed.values['performance-runtime'],nativeRuntime,renderThread:thread,engineArguments:thread==='default'?[]:['--render-thread',thread],nativeArguments,renderCore,
  policy:{normalGameplay,isolated,packaged,explicitStandard,defaults:normalGameplay?'accepted-normal-gameplay':'conservative',explicitChoicesHonored:true},
  requested:Object.fromEntries(registry.features.filter(row=>row.forwarder==='performance').map(row=>[row.name,{value:parsed.values[row.name],explicit:parsed.explicit.includes(row.name)}])),
  registry:{version:registry.version,file:registryFile,sha256:hash(fs.readFileSync(registryFile))},
  scope:'Resolved normal-gameplay policy plus explicit selections. Actual executable, render thread, light owner and feature use are independently verified.'};
}

function validateHostOptions(argv=[],project=path.resolve(__dirname,'..')){
 const parsed=parseManagedOptions(argv),inputs=parserInputs(project),inputMap=new Map(inputs.map(row=>[row.name,row])),known=new Set(inputMap.keys()),seen=new Set();
 for(const row of registry.features)known.add(row.name);
 for(const name of ['list-flags','native-postprocess-mask','native-postprocess-midpoint','native-postprocess-intensity','native-postprocess-vibrance'])known.add(name);
 for(const argument of argv){
  if(!argument.startsWith('--'))continue;
  const name=argument.slice(2).split('=',1)[0];
  if(seen.has(name))throw Error('Repeated native client option --'+name);seen.add(name);
  const research=registry.researchOnly.find(row=>row.name===name);
  if(research)throw Error('--'+name+' is '+research.status+': '+research.reason);
  if(!known.has(name))throw Error('Unknown native client option --'+name+'; use --list-flags');
  const form=inputMap.get(name)?.forms??[];
  if(!definitions.has(name)&&form.length===1&&form[0]==='switch'&&argument.includes('='))throw Error('--'+name+' is a bare switch; scalar values are unsupported');
  if(!definitions.has(name)&&form.length===1&&form[0]==='value'&&!argument.includes('='))throw Error('--'+name+' requires a value');
 }
 return parsed;
}
function parserInputs(project=path.resolve(__dirname,'..')){
 const rows=new Map();
 for(const relative of ['tools/native-session-host.cjs','tools/native-session-bootstrap.cjs','tools/native-render-configuration.cjs']){
  const source=fs.readFileSync(path.join(project,relative),'utf8');
  const add=(name,index,form)=>{if(!/^[a-z][a-z0-9-]*$/.test(name))return;const record=rows.get(name)??{name,forms:[],parserSources:[]};if(!record.forms.includes(form))record.forms.push(form);const line=source.slice(0,index).split('\n').length;if(!record.parserSources.some(row=>row.file===relative&&row.line===line))record.parserSources.push({file:relative,line});rows.set(name,record);};
  for(const match of source.matchAll(/\barg\(['"]([a-z][a-z0-9-]*)['"]\)/g))add(match[1],match.index,'value');
  for(const match of source.matchAll(/process\.argv\.(?:includes|indexOf)\(['"]--([a-z][a-z0-9-]*)['"]\)/g))add(match[1],match.index,'switch');
  // Protected bootstrap inputs are accepted before the protocol host starts.
  for(const match of source.matchAll(/(?:startsWith|includes)\(['"]--((?:private-login-pipe|barter-peer-key-pipe))=/g))add(match[1],match.index,'value');
 }
 return [...rows.values()].sort((a,b)=>a.name.localeCompare(b.name));
}
function nativeSourceFlags(project=path.resolve(__dirname,'..')){
 const files=[],found=new Map();
 const walk=relative=>{for(const entry of fs.readdirSync(path.join(project,relative),{withFileTypes:true})){if(entry.isSymbolicLink()||entry.name.startsWith('.'))continue;const name=path.posix.join(relative,entry.name);if(entry.isDirectory())walk(name);else if(/\.(gd|cpp|hpp)$/.test(entry.name))files.push(name);}};
 for(const root of ['systems','native','tools/native_parity'])if(fs.existsSync(path.join(project,root)))walk(root);
 for(const entry of fs.readdirSync(project,{withFileTypes:true}))if(entry.isFile()&&entry.name.endsWith('.gd'))files.push(entry.name);
 for(const file of files){const text=fs.readFileSync(path.join(project,file),'utf8');for(const match of text.matchAll(/['"]--([a-z][a-z0-9-]*[a-z0-9])(?:=|['"])/g)){const name=match[1],row=found.get(name)??{name,managed:definitions.has(name),ordinaryHostForwarding:definitions.get(name)?.forwarder??'not-declared',sources:[]};const line=text.slice(0,match.index).split('\n').length;row.sources.push({file,line});found.set(name,row);}}
 return [...found.values()].sort((a,b)=>a.name.localeCompare(b.name));
}
function catalogue(project=path.resolve(__dirname,'..')){
 const ingress=parserInputs(project),parameters=fs.readFileSync(path.join(project,'join-native.ps1'),'utf8').split(/\r?\n\$ErrorActionPreference/)[0];
 const powershell=[...new Set([...parameters.matchAll(/\$([A-Za-z][A-Za-z0-9]*)(?=\s*(?:=|,|\)))/g)].map(match=>match[1]))].sort();
 return {version:registry.version,scope:registry.scope,registrySha256:hash(fs.readFileSync(registryFile)),features:structuredClone(registry.features),normalGameplayDefaults:structuredClone(registry.normalGameplayDefaults),researchOnly:structuredClone(registry.researchOnly),applicationIngress:ingress,nativeSourceFlags:nativeSourceFlags(project),powershellParameters:powershell,defaultsNote:'Base registry defaults preserve direct/isolated routes; normalGameplayDefaults supplies the accepted normal gameplay policy, while explicit choices remain authoritative. Existing render-profile isolation/overrides and saved UI/graphics preferences remain separate and are reported at runtime. Parser-only diagnostic options have no invented default. Native source literal inventory is discoverability, not evidence the normal launcher forwards an option or the loaded native binary supports it.'};
}
function markdown(project){
 const data=catalogue(project),lines=['# Client flags and actual feature selection','','Generated by `node tools/native-client-flags.cjs --markdown`. The registry is `systems/native_data/client_feature_registry.json`. Requested options do not prove a runtime feature is active.','','Use `./join-native.ps1 -ListFlags` or `node tools/native-client-flags.cjs --list-flags`; both list options without starting a client or building native outputs. Add `--json` to the Node command for structured output.','','| Option | Default | Values | Owner |','| --- | --- | --- | --- |'];
 for(const row of data.features)lines.push('| `--'+row.name+'` | `'+row.default+'` | '+(row.choices?row.choices.map(value=>'`'+value+'`').join(', '):row.minimum+'..'+row.maximum)+' | `'+row.owner+'` |');
 lines.push('','## Research options outside normal launch','','These are visible so benchmark-only selections cannot be mistaken for production integrations.');
 for(const row of data.researchOnly)lines.push('','- `--'+row.name+'` ('+row.status+'): '+row.reason);
 lines.push('','Normal gameplay implicit policy: verified-native runtime, separate render thread, builtin typed light input and detailed profiling OFF. Explicit standard selects the conservative route; isolated/editor/package checks preserve their existing defaults.','','## Application ingress inventory','','These names are discovered from the current ordinary host/bootstrap parser declarations. Inclusion here is not normal-gameplay or performance acceptance; many are isolated test controls. Managed performance selections above have explicit validation and defaults.','',data.applicationIngress.map(row=>'`--'+row.name+'`').join(', '),'','## Native source option inventory','','Literal options found in current application GDScript/native source. An unregistered option may be internal, diagnostic, unreachable through the normal launcher, or absent from the loaded binary. Structured output includes exact source locations; this inventory does not invent defaults or capability claims.','',data.nativeSourceFlags.map(row=>'`--'+row.name+'`'+(row.managed?'':' (not managed)')).join(', '),'','## PowerShell launcher parameters','',data.powershellParameters.map(name=>'`-'+name+'`').join(', '),'','## Verification contract','','Startup manifests record requested selections, actual executable SHA, current-source signature, engine arguments, forwarded native arguments and native capability/thread/owner observations. Unavailable explicit capabilities must reject instead of silently falling back. World admission supplies collision/light owner evidence; that is distinct from startup class availability. Ordinary, streamed and merged loading do not themselves choose a render-thread mode or native engine.','');
 return lines.join('\n');
}
module.exports={catalogue,markdown,parseManagedOptions,resolvePerformanceOptions,canonicalPerformanceArguments,validateHostOptions,registryFile};
if(require.main===module){
 const options=process.argv.slice(2);
 if(options.some(value=>!['--list-flags','--json','--markdown'].includes(value))||(!options.includes('--list-flags')&&!options.includes('--markdown')))throw Error('Use --list-flags [--json] or --markdown');
 process.stdout.write(options.includes('--json')?JSON.stringify(catalogue(),null,2)+'\n':markdown());
}
