import {saveScriptSituation} from './script_situation_save.js';
import {loadScriptSituation} from './script_situation_load.js';
import {parseNcs} from './ncs.js';
import {ScriptEngineRuntime} from './script_engine_runtime.js';

// Native format bridge for owned interpreter snapshots. Missing engine values
// and native jump-map ownership stay explicit dependencies, never empty stubs.
export class ScriptSituationRuntime{
 constructor(session){this.session=session;this.engine=new ScriptEngineRuntime(session);}
 model(value){
  const fail=field=>{throw new Error(`Native VM script-situation serialization state is unavailable: ${field}`);};
  if(value?.disposed)fail('disposed snapshot');if(!(value?.program?.nativeCode instanceof Uint8Array))fail('owned code');
  const ctx=value.nativeScriptState;if(!ctx||!Array.isArray(ctx.jumps)||!(ctx.ndb===null||ctx.ndb instanceof Uint8Array)||typeof ctx.scriptChunk!=='string')fail('script metadata');
  for(const field of ['nativeInstructionPtr','nativeSecondaryPtr','nativeScriptEventId','nativeStackSize','nativeStackCapacity','bp'])if(!Number.isInteger(value[field]))fail(field);
  if(!Array.isArray(value.stack))fail('stack');
  return{code:value.program.nativeCode,ndb:ctx.ndb,name:value.program.name,instructionPtr:value.nativeInstructionPtr,secondaryPtr:value.nativeSecondaryPtr,scriptEventId:value.nativeScriptEventId,stackSize:value.nativeStackSize,
   stack:{basePointer:value.bp,stackPointer:value.stack.length,totalSize:value.nativeStackCapacity,cells:value.stack},jumps:ctx.jumps,scriptChunk:ctx.scriptChunk};
 }
 async save(value,root){
  try{return await saveScriptSituation(this.model(value),{saveEngine:(kind,value,row)=>this.engine.save(kind,value,row)},root);}
  catch(error){this.session.report(error,{operation:'native-vm-situation-save',script:value?.program?.name});throw error;}
 }
 async load(data,previous){
  try{
   const out={value:undefined},status=await loadScriptSituation(data,{loadEngine:(kind,row,slot)=>this.engine.load(kind,row,slot),
    assignJump:()=>{throw new Error('Native VM jump-map load ownership is unavailable');},
    stackFailure:line=>this.session.report(new Error(`Native LoadStack failed at line0x${line.toString(16)}`),{operation:'native-vm-stack-load',nativeLine:line}),
   },out);
   if(status===0){if(previous===undefined)throw new Error('Native VM script-situation loading state is unavailable: output pointer is unwritten');return previous;}
   const s=out.value,stack=s.stack;if(stack.loadFailureLine!==undefined||stack.basePointer>stack.stackPointer||stack.cells.length!==stack.stackPointer)throw new Error('Native VM loaded stack is unavailable for execution');
   const bytes=new Uint8Array(s.code.length+13);bytes.set([78,67,83,32,86,49,46,48,66]);new DataView(bytes.buffer).setUint32(9,bytes.length,false);bytes.set(s.code,13);
   const program=parseNcs(bytes,s.name);
   return{program,pc:s.instructionPtr===-1?null:s.instructionPtr+13,bp:stack.basePointer,stack:stack.cells,nativeInstructionPtr:s.instructionPtr,nativeSecondaryPtr:s.secondaryPtr,nativeScriptEventId:s.scriptEventId,
    nativeStackSize:s.stackSize,nativeStackCapacity:stack.totalSize,nativeScriptState:{ndb:s.ndb,jumps:s.jumps,scriptChunk:s.scriptChunk}};
  }catch(error){this.session.report(error,{operation:'native-vm-situation-load'});throw error;}
 }
}
