'use strict';
const assert=require('node:assert/strict');
function position(value){if(value&&['Vector3','Vector3i','PackedFloat32Array','PackedFloat64Array'].includes(value.$type))value=value.value;return Array.isArray(value)&&value.length===3&&value.every(Number.isFinite)?value.slice():null;}
function distance(a,b){return Math.hypot(...a.map((x,i)=>x-b[i]));}
class FrontendFlow {
 constructor({input,finish,observe,now=Date.now}){Object.assign(this,{input,finish,observe,now});this.phase='menu';this.connection=0;this.selected='installed:wizard.bic';this.started=now();this.area=null;this.worldReady=false;this.origin=null;this.finished=false;this.walkAt=0;this.requestId=918273;}
 event(direction,message){
  if(this.finished)return;
  if(direction==='native'&&message.kind==='main-menu-observed'&&this.phase==='menu'){
   // Ordinary UI preparation may publish an incomplete surface first. It is
   // not an acknowledgment until every real readiness/visibility field holds.
   if(!message.ready||!message.mainVisible||!message.browserHidden||!message.lobbyHidden)return;
   this.phase='browser';this.observe({kind:'main-menu-ready'});this.input({kind:'browser-input',operation:'open',connection:this.connection});return;
  }
  if(direction==='host'&&message.kind==='lobby'){
   assert(Number.isSafeInteger(message.connection)&&message.connection>=0);this.connection=message.connection;
   const state=message.state||{};
   if(state.error)throw Error('Ordinary lobby reported an error: '+state.error);
   if(this.phase==='joining'&&state.canSelect&&Array.isArray(state.choices)&&state.choices.some(x=>x.key===this.selected)){
    this.phase='choosing';this.observe({kind:'local-character-available',connection:this.connection,key:this.selected});this.input({kind:'lobby-choose',connection:this.connection,key:this.selected,requestId:this.requestId});
   }else if(this.phase==='choosing'&&state.selected===this.selected&&state.preview&&state.selectionAck?.requestId===this.requestId&&state.selectionAck?.key===this.selected){
    this.phase='playing';this.observe({kind:'selection-ack-and-real-preview',connection:this.connection,key:this.selected});this.input({kind:'lobby-play',connection:this.connection,key:this.selected});
   }
   return;
  }
  if(direction==='host'&&message.kind==='browser-view'&&this.phase==='browser'&&!message.busy&&message.canJoin){
   assert(message.localOnly===true&&message.canDiscover===false,'Local-only browser policy');assert(Number.isSafeInteger(message.viewId));this.phase='joining';this.observe({kind:'local-browser-ready',connection:this.connection,viewId:message.viewId});this.input({kind:'browser-input',operation:'join',connection:this.connection,viewId:message.viewId,direct:true,values:{host:'127.0.0.1',port:5121,name:'NativeLocalAuthority',password:'',cdKey:''}});return;
  }
  if(direction==='native'&&message.kind==='area-ready'){
   assert(message.connection===this.connection,'Native area connection');assert(Number.isSafeInteger(message.generation)&&Number.isSafeInteger(message.areaId));this.area={connection:message.connection,generation:message.generation,areaId:message.areaId};this.observe({kind:'native-area-ready',...this.area});
  }
  if(direction==='native'&&message.kind==='observed'&&this.area&&!this.worldReady&&message.connection===this.area.connection&&message.generation===this.area.generation&&message.areaId===this.area.areaId){
   const state=message.state||{};
   if(state.ready===true&&state.object_visuals_complete===true&&state.pending_batches===0&&state.entities+state.hidden===state.desired){this.worldReady=true;this.observe({kind:'native-world-ready',...this.area,entities:state.entities,hidden:state.hidden,desired:state.desired});}
  }
 }
 controlled(scope,result){
  if(!this.area||!this.worldReady||!['playing','walking'].includes(this.phase)||!result?.available)return;
  const ref=result.reference,entity=result.entity;
  if(!ref||!entity||ref.connection!==this.area.connection||ref.area_generation!==this.area.generation||ref.area_id!==this.area.areaId)return;
  assert(scope.connection===ref.connection&&scope.area_generation===ref.area_generation&&scope.area_id===ref.area_id,'Read-only API current scope');
  assert(entity.received?.source==='client_received_read_model','Actual decoded/merged received provenance');
  const received=position(entity.received?.value?.replicated?.position),presented=position(entity.presentation?.value?.position);
  if(!received||!presented||!entity.presentation?.available)return;
  const identity=JSON.stringify(ref);
  if(this.phase==='playing'){
   this.origin={identity,reference:{...ref},received,presented};this.target=[received[0]+1.25,received[1],received[2]];this.walkAt=this.now();this.phase='walking';this.observe({kind:'authoritative-origin',...this.area,objectId:result.object_id,received,presented,target:this.target});this.input({kind:'walk',...this.area,position:this.target});return;
  }
  assert(identity===this.origin.identity,'Controlled identity/lifetime stayed current');
  const serverDistance=distance(received,this.origin.received),nativeDistance=distance(presented,this.origin.presented);
  if(serverDistance>0.2&&serverDistance<2.5&&nativeDistance>0.2&&nativeDistance<2.5&&this.now()-this.walkAt>=2000){
   this.finished=true;this.phase='finished';const proof={kind:'actual-authority-and-native-movement',...this.area,reference:this.origin.reference,originReceived:this.origin.received,finalReceived:received,originPresented:this.origin.presented,finalPresented:presented,serverDistance,nativeDistance,elapsedMs:this.now()-this.walkAt};this.observe(proof);this.finish(proof);
  }
 }
}
module.exports={FrontendFlow};
