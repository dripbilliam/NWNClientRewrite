'use strict';
// Test completion only: saving the PC can coincide with a late original-world
// disclosure. Wait for subsequent complete native observations, never equate
// an export reply or an empty batch list with complete visuals.
class CreationCompletion {
 constructor(){this.scope=null;this.exportedAt=null;this.stableAt=null;this.key=null;this.observations=[];}
 exported(scope,now=Date.now()){this.scope={...scope};this.exportedAt=now;this.stableAt=null;this.key=null;}
 observe(message,{rawPending=false}={},now=Date.now()){
  const state=message.state??{},current=Boolean(this.scope&&message.connection===this.scope.connection&&message.generation===this.scope.generation&&message.areaId===this.scope.areaId);
  const complete=current&&state.ready===true&&state.object_visuals_complete===true&&state.pending_batches===0&&state.entities+state.hidden===state.desired;
  const key=JSON.stringify([message.connection,message.generation,message.areaId,state.entities,state.hidden,state.desired]);
  if(this.exportedAt===null||!complete){this.stableAt=null;this.key=null;}
  else if(this.key!==key){this.key=key;this.stableAt=now;}
  const ready=complete&&!rawPending&&this.stableAt!==null&&now-this.stableAt>=1000;
  const value={ready,at:now,current:Boolean(current),complete:Boolean(complete),rawPending:Boolean(rawPending),entities:state.entities,hidden:state.hidden,desired:state.desired,pendingBatches:state.pending_batches,stableMs:this.stableAt===null?0:now-this.stableAt};
  this.observations.push(value);if(this.observations.length>32)this.observations.shift();return value;
 }
 snapshot(){return {scope:this.scope,exportedAt:this.exportedAt,observations:this.observations.slice(),source:'Post-export complete native world observations for one current connection/area/generation, unchanged strict native exit/cleanup checks; no FPS claim'};}
}
module.exports={CreationCompletion};
