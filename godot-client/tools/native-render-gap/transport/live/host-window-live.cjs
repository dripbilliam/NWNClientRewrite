'use strict';
const {HostWindow}=require('./host-window.cjs'),isFrozen=Object.isFrozen,isProxy=require('node:util').types.isProxy;
class LiveWindow extends HostWindow{
 constructor(options){super(options);this.rootCensus=null;}
 measure(phase,connection,generation,fn){
  let value,items=0;const token=this.probe.begin(phase,this.scope(connection,generation));
  try{value=fn();if(phase===0&&Array.isArray(value))items=value.length;return value;}
  finally{this.probe.end(phase,token,items);if(phase===0&&token!==0&&this.active&&this.probe.active&&!this.rootCensus&&Array.isArray(value)){const count=Math.min(value.length,65536);let frozen=0,mutable=0,unknown=0;for(let i=0;i<count;i++){const row=value[i];if(row===null||typeof row!=='object'||isProxy(row))unknown++;else if(isFrozen(row))frozen++;else mutable++;}this.rootCensus={observedProjectionRows:value.length,inspectedRoots:count,frozenRoots:frozen,mutableRoots:mutable,unknownRoots:unknown,truncated:count!==value.length,encodedProducerSelected:false,scope:'One cold root-only census AFTER projection timer ends; no graph walks/getters/IDs/payloads, no per-object clocks. Root-frozen does not prove transitive immutability.'};}}
 }
 receipt(){return{...super.receipt(),ordinaryProjectionRootCensus:this.rootCensus,encodedProducerSelected:false};}
}
module.exports={HostWindow:LiveWindow};
