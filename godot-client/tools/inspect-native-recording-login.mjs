// Temporary Node-inspector diagnosis of an already-failed client. The optional
// stimulus is restricted to the owned localhost handshake and never selects a
// character. No credential buffers or arbitrary object properties are printed.
import path from 'node:path';import {pathToFileURL,fileURLToPath} from 'node:url';import fs from 'node:fs/promises';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),pid=Number(process.argv[2]),local=process.argv.includes('--local-probe');
if(!Number.isSafeInteger(pid)||pid<1)throw Error('Explicit protocol-host PID required');
const targets=await(await fetch('http://127.0.0.1:9229/json/list')).json();if(targets.length!==1)throw Error('Ambiguous inspector');
const socket=new WebSocket(targets[0].webSocketDebuggerUrl);await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
let serial=0;const pending=new Map(),failures=[];let pauseWork=Promise.resolve();
function call(method,params={}){return new Promise((resolve,reject)=>{const id=++serial,timer=setTimeout(()=>{pending.delete(id);reject(Error('Diagnostic RPC timed out'));},20000);pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));});}
socket.addEventListener('message',event=>{const v=JSON.parse(event.data);if(v.id&&pending.has(v.id)){const p=pending.get(v.id);pending.delete(v.id);clearTimeout(p.timer);v.error?p.reject(Error(JSON.stringify(v.error))):p.resolve(v.result);}else if(v.method==='Debugger.paused'){pauseWork=pauseWork.then(async()=>{try{const r=await call('Debugger.evaluateOnCallFrame',{callFrameId:v.params.callFrames[0].callFrameId,expression:'({name:error.name,message:error.message,host:this.host,port:this.port,bound:this.bound,hasLogin:!!this.login,cryptoClosed:this.crypto?.closed})',returnByValue:true});failures.push(r.result?.value??{unavailable:true});}finally{await call('Debugger.resume');}});}});
async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error('Diagnostic evaluation failed');return r.result.value;}
async function instances(relative,name){const file=path.join(project,relative);const p=await call('Runtime.evaluate',{expression:`process.getBuiltinModule('module').createRequire(${JSON.stringify(path.join(project,'tools/native-session-host.cjs'))})(${JSON.stringify(file)}).${name}.prototype`});if(p.exceptionDetails||!p.result.objectId)throw Error('No diagnostic prototype: '+(p.exceptionDetails?.text??p.result.description));return(await call('Runtime.queryObjects',{prototypeObjectId:p.result.objectId})).objects.objectId;}
const actual=await evaluate('process.pid');if(actual!==pid)throw Error('Wrong diagnostic process');
const peers=await instances('../electron/network_peer.mjs','NetworkPeer');
const before=await call('Runtime.callFunctionOn',{objectId:peers,functionDeclaration:'function(){return this.map(p=>({closed:p.closed,started:p.started,host:p.host,port:p.port,bound:p.bound,hasLogin:!!p.login,loginPhase:p.login?.phase,cryptoClosed:p.crypto?.closed,helperExit:p.crypto?.child?.exitCode}));}',returnByValue:true});
let probe=null,breakpoint;
try{
 if(local){
  await call('Debugger.enable');const url=pathToFileURL(path.join(project,'../electron/network_peer.mjs')).href;
  const text=await fs.readFile(path.join(project,'../electron/network_peer.mjs'),'utf8'),line=text.split('\n').findIndex(v=>v.includes("}catch(error){this.finish();throw new Error(error?.message==='Native network login timed out'"));if(line<0)throw Error('Catch diagnostic boundary changed');
  breakpoint=(await call('Debugger.setBreakpointByUrl',{url,lineNumber:line,columnNumber:16})).breakpointId;
  const lobbies=await instances('tools/native-lobby.mjs','NativeLobby');
  const r=await call('Runtime.callFunctionOn',{objectId:lobbies,awaitPromise:true,returnByValue:true,functionDeclaration:'async function(){if(this.length!==1)throw Error("Ambiguous lobby");const l=this[0];if(l.busy||l.session&&!l.session.closed)throw Error("Client no longer idle");await l.join({connection:l.connection,details:{host:"127.0.0.1",port:5121,name:"NwnRecordingLoginProbe",credentials:{cdKey:"",password:""}}});const result={error:l.error,phase:l.phase,connected:!!l.session&&!l.session.closed};if(result.connected)await l.leave({connection:l.connection,saveCharacter:false});return result;}'});
  probe=r.exceptionDetails?{exception:r.exceptionDetails.text,description:r.exceptionDetails.exception?.description}:r.result?.value;await pauseWork;
 }
}finally{if(breakpoint)await call('Debugger.removeBreakpoint',{breakpointId:breakpoint});if(local)await call('Debugger.disable');}
console.log(JSON.stringify({pid,before:before.result?.value,probe,failures,publicConnectionStimuli:0,worldEntries:0}));
await evaluate('setTimeout(()=>process.getBuiltinModule("inspector").close(),100);true');socket.close();
