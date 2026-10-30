// Control messages must be able to interrupt a handshake or pending game action.
// Invoke them in arrival order; only ordinary game commands share the serial lane.
export class NativeCommandPump {
 constructor(command,onError){this.command=command;this.onError=onError;this.queue=Promise.resolve();this.tasks=new Set();}
 push(message){
  const control=message.kind==='hello'||message.kind==='browser-input'||message.kind==='login-profile-input'||message.kind.startsWith('lobby-')||['browser-observed','finished'].includes(message.kind);
  const run=()=>this.command(message);
  const task=(control?Promise.resolve().then(run):this.queue.then(run)).catch(error=>this.onError(error,message));
  if(!control)this.queue=task;
  this.tasks.add(task);void task.finally(()=>this.tasks.delete(task));return task;
 }
}
