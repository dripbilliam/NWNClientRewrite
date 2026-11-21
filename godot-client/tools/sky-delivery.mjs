// One immutable original-model set per admitted native world. Models and art
// are resolved through the session's normal module/HAK/NWSync/workshop resolver;
// only small hashed external-bundle envelopes cross the native bridge.
export class SkyDelivery {
 constructor({session,connection,active,ready,rules,prepare,write,send,diagnose=()=>{}}){Object.assign(this,{session,connection,active,ready,rules,prepare,write,send,diagnose});this.closed=false;this.request=null;this.jobs=new Set();}
 matches(request){const scope=this.ready();return !this.closed&&!this.session.closed&&this.active()&&this.request===request&&this.session.world===request.world&&scope&&['connection','areaId','generation','transferId'].every(k=>scope[k]===request.scope[k]);}
 flush(skyId){
  const scope=this.ready();if(this.closed||this.session.closed||!this.active()||!scope||scope.connection!==this.connection||scope.areaId!==this.session.world.areaId||scope.generation!==this.session.areaGeneration||!Number.isInteger(skyId)||skyId<0||skyId>255)return;
  if(this.request?.world===this.session.world&&this.request.skyId===skyId&&['connection','areaId','generation','transferId'].every(k=>this.request.scope[k]===scope[k]))return;
  const request=this.request={world:this.session.world,scope:{...scope},skyId};
  const job=this.prepareSet(request).catch(error=>{if(this.matches(request))this.diagnose('godot.sky-preparation-failed',error.message);}).finally(()=>this.jobs.delete(job));this.jobs.add(job);
 }
 async prepareSet(request){
  const phases=[],resources={};const horizon=request.skyId?'skyfade1':null;
  if(request.skyId){
   const table=await this.rules('skyboxes');if(!this.matches(request))return;
   const row=table.orderedRows?.[request.skyId];if(!row)throw Error('SkyBoxes physical row is unavailable');
   for(const key of ['DAWN','DAY','DUSK','NIGHT']){
    const name=row[key];if(typeof name!=='string'||!/^[a-z0-9_]{1,16}$/i.test(name))throw Error('SkyBoxes phase has no valid original model');
    phases.push(name.toLowerCase());
   }
   for(const name of new Set([...phases,horizon])){
    const result=await this.prepare(name);if(!this.matches(request))return;
    if(!result)throw Error('Sky model resource staging is unavailable');
    resources[name]=await this.write(result);if(!this.matches(request))return;
   }
  }
  if(this.matches(request))this.send({kind:'area-sky',...request.scope,skyId:request.skyId,phases,horizon,resources});
 }
 async close(){this.closed=true;this.request=null;await Promise.allSettled([...this.jobs]);}
}
