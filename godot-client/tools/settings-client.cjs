function createSettingsClient({transport=process,initial={},onStatus=()=>{},fallbackKey=()=>''}={}){
 let serial=0,closed=false;const pending=new Map();
 const listener=message=>{
  if(message?.kind!=='protected-settings-result'||!pending.has(message.id))return;
  const item=pending.get(message.id);pending.delete(message.id);clearTimeout(item.timer);
  if(message.ok)item.resolve(message.value);else item.reject(Error(message.error||'Protected settings request failed'));
 };
 const close=()=>{if(closed)return;closed=true;transport.off('message',listener);transport.off('disconnect',close);for(const item of pending.values()){clearTimeout(item.timer);item.reject(Error('Protected settings broker closed'));}pending.clear();};
 transport.on('message',listener);transport.on('disconnect',close);
 const request=(operation,value)=>{
  if(closed)return Promise.reject(Error('Protected settings broker closed'));
  if(!transport.connected||typeof transport.send!=='function'){
   if(operation==='status')return Promise.resolve(initial);
   if(operation==='cdKey'&&fallbackKey())return Promise.resolve(fallbackKey());
   return Promise.reject(Error('Open the client through join-native.ps1 to change protected settings'));
  }
  const id=++serial;
  return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{pending.delete(id);reject(Error('Protected settings broker timed out'));},15000);pending.set(id,{resolve,reject,timer});try{transport.send({kind:'protected-settings-request',id,operation,value},error=>{if(error&&pending.has(id)){clearTimeout(timer);pending.delete(id);reject(Error('Protected settings broker unavailable'));}});}catch{clearTimeout(timer);pending.delete(id);reject(Error('Protected settings broker unavailable'));}});
 };
 const status=async(operation,value)=>{const result=await request(operation,value);onStatus(result);return result;};
 return{status:()=>status('status'),update:value=>status('update',value),saveProfile:value=>status('saveProfile',value),selectProfile:id=>status('selectProfile',id),deleteProfile:id=>status('deleteProfile',id),cdKey:()=>request('cdKey'),close};
}
function credentialSettings(client,initial,privateKey,{fixedResources=false}={}){
 if(!privateKey()&&!fixedResources)return client;
 return{...client,status:async()=>({...initial(),hasSavedCdKey:Boolean(privateKey())||Boolean(initial().hasSavedCdKey)}),cdKey:async()=>privateKey()||client.cdKey()};
}
module.exports={createSettingsClient,credentialSettings};
