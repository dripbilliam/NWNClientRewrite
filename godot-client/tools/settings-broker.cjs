// Electron owns OS protection. Only its child protocol host receives unlocked
// credentials over the inherited IPC channel; the native UI receives metadata.
function installSettingsBroker(child,store){
 const methods=new Set(['status','update','saveProfile','selectProfile','deleteProfile','cdKey']);
 const listener=async message=>{
  if(message?.kind!=='protected-settings-request')return;
  const id=message.id;
  if(!Number.isSafeInteger(id)||id<1||!methods.has(message.operation))return;
  let value;
  try{value=await store[message.operation](message.value);if(child.connected)child.send({kind:'protected-settings-result',id,ok:true,value});}
  catch(error){if(child.connected)child.send({kind:'protected-settings-result',id,ok:false,error:error.message});}
  finally{if(message.value&&typeof message.value.cdKey==='string')message.value.cdKey='';value=null;}
 };
 child.on('message',listener);return()=>child.off('message',listener);
}
module.exports={installSettingsBroker};
