// Pure launch options only. Preparation, rendering, caching and file I/O remain native.
const streamed=Object.freeze([
 '--base-scenery-owner=retained',
 '--base-scenery-templates=retained',
 '--base-scenery-template-probe=ready',
 '--base-scenery-admission=timed',
 '--base-scenery-stream=continuous',
 '--model-template=recipe'
]);
const merged=Object.freeze(['--static-scenery=merged','--base-scenery-draw=merged']);
const names=new Set(['loading-pipeline','shared-animation-preparation','native-draw-cache','native-draw-cache-gib']);

function resolveNativeLoadingPipeline(argv=[]){
 if(!Array.isArray(argv)||argv.some(value=>typeof value!=='string'))throw Error('Loading pipeline arguments must be strings');
 const options=new Map();
 for(const argument of argv){
  if(!argument.startsWith('--'))continue;
  const split=argument.indexOf('='),name=argument.slice(2,split<0?undefined:split);
  if(!names.has(name))continue;
  if(options.has(name))throw Error('Repeated loading option: '+name);
  options.set(name,split<0?null:argument.slice(split+1));
 }
 const pipeline=options.has('loading-pipeline')?options.get('loading-pipeline'):'ordinary';
 if(!['ordinary','streamed','merged'].includes(pipeline))throw Error('Invalid native loading pipeline');
 const animation=options.has('shared-animation-preparation')?options.get('shared-animation-preparation'):'false';
 if(animation!==null&&!['true','false'].includes(animation))throw Error('Invalid shared animation preparation switch');
 const sharedAnimation=animation===null||animation==='true';
 const cache=options.has('native-draw-cache')?options.get('native-draw-cache'):'off';
 if(cache!==null&&!['prepared','off'].includes(cache))throw Error('Invalid native draw cache switch');
 const nativeDrawCache=cache===null||cache==='prepared';
 const rawBudget=options.get('native-draw-cache-gib');
 if(options.has('native-draw-cache-gib')&&!nativeDrawCache)throw Error('Native cache budget requires the native draw cache');
 const budget=options.has('native-draw-cache-gib')?Number(rawBudget):25;
 if((options.has('native-draw-cache-gib')&&(typeof rawBudget!=='string'||!/^[1-9][0-9]*$/.test(rawBudget)))||!Number.isSafeInteger(budget)||budget<25||budget>1024)throw Error('Native cache budget must be an integer from 25 to 1024 GiB');
 const args=pipeline==='ordinary'?[]:[...streamed];
 if(pipeline==='merged')args.push(...merged);
 if(sharedAnimation)args.push('--shared-animation-preparation=true');
 if(nativeDrawCache)args.push('--native-draw-cache=prepared','--native-draw-cache-gib='+budget);
 return {
  arguments:args,
  summary:{pipeline,selection:options.has('loading-pipeline')?'explicit':'default',shared_animation_preparation:sharedAnimation,native_draw_cache:nativeDrawCache,native_cache_gib:budget,native_cache_budget_explicit:options.has('native-draw-cache-gib'),scope:'Optional native loading configuration only; ordinary preserves existing defaults; no rendering or asset I/O in the host'}
 };
}

module.exports={resolveNativeLoadingPipeline};
