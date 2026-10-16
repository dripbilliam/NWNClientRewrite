import {startVisualPhases,stopVisualPhases} from './visual_phase_control.js';
import {updateVisualPhases} from './visual_phase_update.js';
import {placeVisualModels} from './visual_placement.js';
import {attachVisualModels} from './visual_attachment.js';
import {detachVisualModels} from './visual_detachment.js';
import {cleanupVisualModels} from './visual_program.js';
import {visualIsRetired} from './visual_selection.js';

// Logical fields initialized by140968660. JS owns storage, not a game ID or
// a substitute engine allocation. Controller-map construction is a lower owner.
export function createVisualPhaseState(){
 return{vector18:[0,0,0],sourceAnchor28:'',targetAnchor38:'',point48:[0,0,0],target54:0x7f000000,source58:0x7f000000,
  modelRemaining5c:[0,0,0],modelStates68:[0,0,0],models88:[null,null,null],extraModelsA0:[null,null,null],proceduralB8:null,
  retireRemainingC0:[0,0,0],programRemainingCc:0,programsD0:[0,0,0],updateProgramD8:0,retiredDc:[0,0,0],retiringE8:0,
  closedEc:0,startedF0:0,finishedF4:0,visualF8:0,programPhaseFa:0,durationFc:0,field100:1,field104:0,shadow108:0,
  scope10c:0,programType10d:0,field110:0,attached114:0,sound118:null,orient120:0,controllers128:null};
}
// Composition follows AddVisual140762180 at2e2..317: start, initial placement,
// detach, then the caller's group-selection callback. Per-frame selection and
// list removal stay in the actor presenter. Delta here is native DWORD ms;
// renderer seconds/clock conversion belongs to its platform adapter.
export class VisualPhaseRuntime{
 constructor(state,providers){this.nativeState=state;this.providers=providers;this.begun=false;this.disposed=false;}
 attach(){
  if(this.disposed)throw new Error('Cannot start a disposed visual phase instance');
  if(this.begun)return;this.begun=true;
  startVisualPhases(this.nativeState,this.providers);placeVisualModels(this.nativeState,0,this.providers);detachVisualModels(this.nativeState,this.providers);
 }
 attachModels(){if(!this.disposed)attachVisualModels(this.nativeState,this.providers);}
 detachModels(){if(!this.disposed)detachVisualModels(this.nativeState,this.providers);}
 restart(){if(!this.disposed)startVisualPhases(this.nativeState,this.providers);}
 stopForSelection(requested){if(!this.disposed)stopVisualPhases(this.nativeState,requested,this.providers);}
 stop(requested=1){this.stopForSelection(requested);}
 updateMilliseconds(delta){
  if(!Number.isInteger(delta)||delta<0||delta>0xffffffff)throw new Error('Visual phase update requires a native DWORD millisecond delta');
  if(!this.disposed)updateVisualPhases(this.nativeState,delta,this.providers);
 }
 isRetired(){return this.disposed||visualIsRetired(this.nativeState);}
 dispose(){
  if(this.disposed)return;this.disposed=true;
  const e=this.nativeState,p=this.providers;
  //140968810 destroys duration sound before resource cleanup, then the
  // controller map and anchor strings. The providers own platform resources.
  if(e.sound118)p.destroySound(e.sound118,1);
  cleanupVisualModels(e,p);p.destroyControllers(e.controllers128);e.sourceAnchor28='';e.targetAnchor38='';
 }
}
