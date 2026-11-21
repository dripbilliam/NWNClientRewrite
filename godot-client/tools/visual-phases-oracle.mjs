import {createVisualPhaseState,VisualPhaseRuntime} from '../../src/visual_phase_runtime.js';
import {visualMilliseconds,visualMillisecondsLong} from '../../src/visual_phase_control.js';
import {visualHasCessation} from '../../src/visual_selection.js';
import {clearVisualProgram} from '../../src/visual_program.js';

// Authored phase/provider scenarios evaluated by the retained reviewed original
// owners. This is a source oracle, not fresh runtime observation of NWN.
export function createPhaseFixture(config){
 const state=createVisualPhaseState(),trace=[],models=new Map(),sounds=new Map();let target=true,render=true,replaced=false;
 const model=id=>id===null?null:models.get(id)??(models.set(id,{modelToken:id}),models.get(id));
 const sound=id=>sounds.get(id)??(sounds.set(id,{soundToken:id}),sounds.get(id));
 Object.assign(state,{...structuredClone(config.initial),models88:config.models.map(model),extraModelsA0:config.extra.map(model),proceduralB8:model(config.procedural),controllers128:{authored:true}});
 const row=(...values)=>trace.push(values),actor={actorToken:1},view={position38:[.123456789,12.3456789,-4.7654321]};
 const p={
  clientObject:id=>{row('clientObject',id);return target?actor:null;},renderObject:()=>{row('renderObject');return render?view:null;},
  playAnimation:(value,name,speed,flags,time)=>{row('playAnimation',value?.modelToken??null,name,speed,flags,time);if(config.replaceOnImpact&&name==='impact'&&!replaced){replaced=true;state.models88[0]=model(3);}return value!==null&&Object.hasOwn(config.clips[value.modelToken]??{},name)?1:0;},
  animationInfo:(value,name)=>{row('animationInfo',value?.modelToken??null,name);return{length:config.clips[value?.modelToken]?.[name]??0};},
  visualString:(_id,column)=>{row('visualString',column);return{found:true,value:column==='SoundDuration'?(config.sound?'duration':''):column==='SoundImpact'?'impact':'cessation'};},
  visualInt:(_id,column)=>{row('visualInt',column);return{found:true,value:config.shake};},
  visualFloat:(_id,column)=>{row('visualFloat',column);return{found:config.shakeFound,value:column==='ShakeDuration'?1.234567:.123456789};},
  controlledClient:()=>{row('controlledClient');return config.controlled?actor:null;},
  shakeOnce:(_client,delay)=>row('shakeOnce',delay),shakeLoop:(_client,delay,duration)=>row('shakeLoop',delay,duration),
  positionalSound:(...args)=>row('positionalSound',...args),
  createSound:name=>{row('createSound',name);return name?sound(0):null;},
  soundSetting:(value,name,arg)=>row('soundSetting',value.soundToken,name,arg),playSound:value=>row('playSound',value.soundToken),
  stopSound:value=>{row('stopSound',value.soundToken);if(config.replaceSound)state.sound118=sound(9);},
  destroySound:(value,flags)=>row('destroySound',value.soundToken,flags),updateSound:(value,...args)=>row('updateSound',value.soundToken,...args),
  programType:(_e,id)=>{row('programType',id);return config.types[id]??0;},
  clearProgram:e=>{row('clearProgram');clearVisualProgram(e,p);},
  loadProgram:(e,id)=>{row('loadProgram',id);e.proceduralB8=Object.hasOwn(config.programModels,id)?model(config.programModels[id]):null;},
  startProgram:(_e,id)=>row('startProgram',id),stopProgram:(_e,id)=>row('stopProgram',id),
  updateProgram:(_e,id,delta)=>row('updateProgram',id,delta),currentProgram:e=>{row('currentProgram');const phase=e.programPhaseFa&255;return phase>=1&&phase<=3?e.programsD0[phase-1]&65535:65535;},
  setParent:(value,...args)=>{row('setParent',value.modelToken,...args);},setScene:(value,...args)=>row('setScene',value.modelToken,...args),
  detachProcedural:(value,...args)=>{row('detachProcedural',value.modelToken,...args);if(config.replaceProcedural)state.proceduralB8=model(4);},
  unsceneProcedural:(value,...args)=>row('unsceneProcedural',value.modelToken,...args),destroyProcedural:(value,...args)=>row('destroyProcedural',value.modelToken,...args),
  destroyModel:(value,...args)=>row('destroyModel',value.modelToken,...args),destroyControllers:value=>row('destroyControllers',value),
  detach:e=>{row('detach');e.attached114=0;},
 };
 const runtime=new VisualPhaseRuntime(state,p);
 const encode=value=>JSON.parse(JSON.stringify(value,(_key,v)=>v&&Object.hasOwn(v,'modelToken')?{model:v.modelToken}:v&&Object.hasOwn(v,'soundToken')?{sound:v.soundToken}:v));
 function step(operation){
  trace.length=0;
  if(operation.kind==='start')runtime.restart();else if(operation.kind==='stop')runtime.stop(operation.requested);else if(operation.kind==='update')runtime.updateMilliseconds(operation.delta);else if(operation.kind==='dispose')runtime.dispose();
  else if(operation.kind==='target')target=operation.value;else if(operation.kind==='render')render=operation.value;else if(operation.kind==='patch')Object.assign(state,operation.values);else throw Error('Unknown phase oracle operation');
  return{trace:encode(trace),state:encode(state),retired:runtime.isRetired(),cessation:visualHasCessation(state)};
 }
 return{state,step};
}

export function phaseOracle(){
 const bits=value=>{const buffer=Buffer.alloc(8);buffer.writeDoubleLE(value);return buffer.toString('hex');};
 const cases=[];
 for(let index=0;index<96;index++){
  const programs=[[65535,65535,65535],[10,11,12],[65535,11,12],[10,65535,65535],[65535,65535,12],[10,11,65535]][index%6];
  const config={initial:{target54:1,visualF8:42,closedEc:1,programsD0:programs,durationFc:[0,1,256,257][index%4],scope10c:index%5===0?258:0,updateProgramD8:1,attached114:1,retiredDc:[0,0,0]},models:index%3===0?[0,0,1]:index%3===1?[0,1,2]:[null,1,2],extra:[null,index%7===0?0:null,null],procedural:index%9===0?2:null,
   clips:{0:{impact:index%2===0?.1257:0,duration:1,...(index%4===0?{cessation:.25}:{})},1:{duration:2,...(index%3===0?{impact:.123456789}:{}),...(index%4!==0?{cessation:.123456789}:{})},2:{duration:.1,...(index%5===0?{impact:4294968.25}:{}),...(index%3===0?{cessation:-1}:{})},3:{impact:.54321,cessation:1.001},4:{}},types:{10:7,11:index%2===0?4:7,12:index%4<2?4:12},programModels:{10:2,11:3,12:4},replaceOnImpact:index%7===0,replaceProcedural:index%5===0,replaceSound:index%3===0,sound:index%2===0,controlled:index%4!==1,shake:index%3,shakeFound:index%4!==2};
  const operations=[{kind:'start'},{kind:'start'},{kind:'update',delta:0},{kind:'update',delta:17},{kind:'target',value:false},{kind:'update',delta:500},{kind:'target',value:true},{kind:'render',value:false},{kind:'update',delta:500},{kind:'render',value:true},{kind:'update',delta:250},{kind:'update',delta:999},{kind:'stop',requested:0},{kind:'start'},{kind:'patch',values:{attached114:1}},{kind:'update',delta:1000},{kind:'stop',requested:1},{kind:'stop',requested:0},{kind:'update',delta:2999},{kind:'update',delta:1},{kind:'update',delta:0xffffffff},{kind:'dispose'},{kind:'dispose'},{kind:'start'},{kind:'update',delta:1}];
  const f=createPhaseFixture(config);cases.push({name:'authored-'+index,config,steps:operations.map(operation=>({operation,...f.step(operation)}))});
 }
 const values=[0,.00001,.0167,.1257,1.234567,4294968.25,-1,1e16,-1e16,NaN,Infinity,-Infinity];
 const clocks=cases.slice(0,4).map(row=>{
  const f=createPhaseFixture(row.config);let elapsed=0,previous=0;
  const start=f.step({kind:'start'}),deltas=[0,.00001,...Array(180).fill(1/144),...Array(20).fill(1/60),.1257,4294968.25];
  return{config:row.config,start,steps:deltas.map((delta,index)=>{elapsed+=delta*1000;const now=Math.trunc(elapsed),ms=(now-previous)>>>0;previous=now;return{delta,deltaBits:bits(delta),elapsed,elapsedBits:bits(elapsed),previous,frames:index+1,...f.step({kind:'update',delta:ms})};})};
 });
 return{scope:'Retained reviewed JS visual phase owners on authored provider inputs; not fresh original-process capture or complete effect presentation',constructorState:createVisualPhaseState(),milliseconds:values.map(value=>({value:String(value),long:BigInt(visualMillisecondsLong(value)).toString(),dword:visualMilliseconds(value)})),cases,clocks};
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/visual-phases-oracle.mjs')){
 const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output)throw Error('Provide --output');const{writeFile}=await import('node:fs/promises');const oracle=phaseOracle();await writeFile(output,JSON.stringify(oracle)+'\n',{flag:'wx'});console.log(JSON.stringify({output,cases:oracle.cases.length,steps:oracle.cases.reduce((sum,row)=>sum+row.steps.length,0)}));
}
