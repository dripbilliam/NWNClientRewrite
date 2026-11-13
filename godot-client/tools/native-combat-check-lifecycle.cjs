'use strict';
// Isolated CombatPresentation acceptance only. The game protocol/default host
// lifecycle remains owned by the existing handlers.
const ORDER=['actions-complete','export-complete','finish-sent','finished','ack-sent'];
class NativeCombatCheckLifecycle {
 constructor(){this.connection=null;this.index=0;this.errors=[];this.events=[];this.closed=false;}
 event(stage,details={}){if(this.events.length<32)this.events.push({stage,at:Date.now(),...details});}
 mark(stage,connection,success=true){
  this.event(stage,{connection,success});
  if(this.connection===null&&stage==='actions-complete'&&Number.isSafeInteger(connection)&&connection>0)this.connection=connection;
  if(!success||connection!==this.connection||ORDER[this.index]!==stage){this.errors.push('Invalid owned completion order: '+stage);return false;}
  this.index++;return true;
 }
 transportClosed(hadError=false){
  this.closed=true;const expected=!hadError&&this.index===ORDER.length&&this.errors.length===0;
  this.event('transport-close',{hadError,expected});
  if(!expected)this.errors.push('Transport closed before the owned completion/ACK sequence');
  return expected;
 }
 result(native,exitCode){
  const accepted=this.index===ORDER.length&&this.errors.length===0&&native?.success===true&&native?.protocol_finish_ack===true&&native?.clean_exit===true&&native?.workers_remaining===0&&exitCode===0;
  return {success:accepted,connection:this.connection,completedStages:this.index,requiredStages:ORDER.length,transportClosed:this.closed,events:[...this.events],errors:[...this.errors],nativeFinishAck:native?.protocol_finish_ack===true,nativeCleanExit:native?.clean_exit===true,nativeWorkersRemaining:native?.workers_remaining,nativeExit:exitCode};
 }
}
module.exports={NativeCombatCheckLifecycle};
