// Release the caller immediately even for filesystem/DNS work without native
// AbortSignal support. The underlying operation must check the signal before
// publishing its result or taking ownership of a connection.
export function abortable(work,signal){
 if(!signal)return Promise.resolve(work);
 signal.throwIfAborted();
 return new Promise((resolve,reject)=>{
  const abort=()=>{signal.removeEventListener('abort',abort);reject(signal.reason);};
  signal.addEventListener('abort',abort,{once:true});
  Promise.resolve(work).then(resolve,reject).finally(()=>signal.removeEventListener('abort',abort));
 });
}
