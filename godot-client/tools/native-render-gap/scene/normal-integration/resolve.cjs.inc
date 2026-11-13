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
 for(const name of ['drive-collision','light-input-registry','world-snapshot-preparation']){
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
