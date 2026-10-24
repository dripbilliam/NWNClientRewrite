// One owner for each connection/area generation. Object identity also prevents
// a retired async job committing after leave/rejoin to equal numeric area IDs.
class WorldTransfer {
 constructor(){this.serial=0;this.clear();}
 clear(){this.scope=null;this.bundle=null;this.admitted=false;}
 follow(value){
  if(!value||!Number.isInteger(value.connection)||value.connection<1||!Number.isInteger(value.areaId)||value.areaId<0||!Number.isInteger(value.generation)||value.generation<0)throw Error('Invalid native world scope');
  if(this.matches(this.scope,value))return{changed:false,scope:this.scope};
  this.scope=Object.freeze({...value,serial:++this.serial});this.bundle=null;this.admitted=false;
  return{changed:true,scope:this.scope};
 }
 matches(scope,live=null){return Boolean(scope&&scope===this.scope&&(!live||['connection','areaId','generation'].every(key=>scope[key]===live[key])));}
 prepare(scope,bundle){
  if(!this.matches(scope))return false;
  if(['connection','areaId','generation'].some(key=>scope[key]!==bundle[key]))throw Error('Prepared bundle belongs to another world');
  this.bundle=bundle;this.admitted=false;return true;
 }
 acknowledge(message){
  if(!this.bundle||!this.matches(this.scope,message)||message.sha256!==this.bundle.sha256)return false;
  this.admitted=true;return true;
 }
}
module.exports={WorldTransfer};
