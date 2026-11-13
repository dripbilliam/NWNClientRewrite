// Pure receipt/source contracts. No filesystem, process, engine, clocks or IO.
export const LIFECYCLE_PREFIX='NWN_PARTICLE_LIFECYCLE_RESULT ';
export const LIFECYCLE_PHASES=Object.freeze(['core_init','scene_init','scene_uninit','servers_uninit','core_uninit']);

export function generatedLifecycleOrder(text){
 if(typeof text!=='string')throw Error('Generated module source must be text');
 function extract(name){
  const anchor='void '+name+'(ModuleInitializationLevel p_level) {';
  if(text.split(anchor).length!==2)throw Error('Generated '+name+' definition differs');
  const start=text.indexOf(anchor)+anchor.length,end=text.indexOf('\n}',start);
  if(end<0)throw Error('Generated function end missing');
  const body=text.slice(start,end),verb=name==='initialize_modules'?'initialize':'uninitialize';
  const producer=verb+'_nwn_particle_reads_module(p_level);';
  const probe=verb+'_nwn_particle_reads_lifecycle_test_module(p_level);';
  const occurrences=call=>{
   const escaped=call.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
   return [...body.matchAll(new RegExp('^[\\t ]*'+escaped+'[\\t ]*\\r?$','gm'))].map(match=>match.index);
  };
  // Match full generated call lines: "uninitialize_" contains the substring
  // "initialize_", so substring search cannot establish the correct verb.
  const producerCalls=occurrences(producer),probeCalls=occurrences(probe);
  if(producerCalls.length!==1||probeCalls.length!==1||producerCalls[0]>=probeCalls[0])throw Error('Actual generated '+name+' does not run producer before probe');
  return {producerOffset:producerCalls[0],probeOffset:probeCalls[0],producerBeforeProbe:true};
 }
 return {initialize:extract('initialize_modules'),uninitialize:extract('uninitialize_modules')};
}

export function parseLifecycleRecord(stdout){
 if(typeof stdout!=='string')throw Error('Lifecycle stdout must be text');
 const lines=stdout.split('\n'),matches=[];
 for(let i=0;i<lines.length;i++)if(lines[i].startsWith(LIFECYCLE_PREFIX))matches.push(i);
 if(matches.length!==1)throw Error('Expected exactly one complete lifecycle record');
 const index=matches[0];
 if(index===lines.length-1)throw Error('Lifecycle record is missing its final newline');
 const line=lines[index].endsWith('\r')?lines[index].slice(0,-1):lines[index];
 return JSON.parse(line.slice(LIFECYCLE_PREFIX.length));
}

export function lifecyclePhasesValid(value){
 return value?.version===1&&value.success===true&&value.nodes_retained===0&&value.dll_callbacks_retained===0&&Array.isArray(value.events)&&value.events.length===5&&value.events.every((event,i)=>event!==null&&typeof event==='object'&&event.phase===LIFECYCLE_PHASES[i]&&event.expected===(i===1?1:5)&&event.eligibility===event.expected&&event.validation===event.expected&&event.transform===event.expected&&event.table===true&&event.same_table===true&&event.output===true&&event.bounds===true);
}

export function lifecycleEngineErrors(stdout,stderr,log){
 return /SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use/im.test(stdout+'\n'+stderr+'\n'+log);
}
