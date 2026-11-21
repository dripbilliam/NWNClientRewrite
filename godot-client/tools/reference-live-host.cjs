// Authored renderer integration, not an NWN server emulator or server admission.
const net=require('node:net'),fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
const{JsonLines,validateCommand}=require('./local-protocol.cjs');
const root=path.resolve(__dirname,'../..'),project=path.join(root,'godot-client');
const reportName=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9);if(!/^[a-z0-9-]+\.json$/.test(reportName??''))throw Error('Use unused --report=name.json');
const output=path.join(project,'reports',reportName),scope={connection:1,areaId:2,generation:1,transferId:1};
let server,wire,child,delivery,temp,done=false,stdout='',stderr='',timeout;
const report={scope:'Authored physical-reference renderer integration using production particle world/workers/binary transport; no NWN server or installed art',success:false,particles:{epochs:[]},diagnostics:[]};
async function stop(reason){
 if(done)return;done=true;clearTimeout(timeout);if(reason)report.failure=reason;
 try{await delivery?.close();wire?.send({...scope,kind:'quit'});if(child&&child.exitCode===null)await Promise.race([new Promise(resolve=>child.once('exit',resolve)),new Promise(resolve=>setTimeout(resolve,1500))]);if(child&&child.exitCode===null)child.kill();wire?.socket.destroy();server?.close();if(temp)await fs.rm(path.join(temp,'ticket.json'),{force:true});}catch(error){report.cleanupError=error.message;}
 report.nativeExit=child?.exitCode;report.nativeErrors=stderr;report.success=!reason&&report.native?.passed===true&&report.nativeExit===0&&!/ERROR:|SCRIPT ERROR/.test(stderr)&&report.particles.epochs.every(row=>row.pendingJobs===0&&row.remainingThreads===0);
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,output,native:report.native,failure:report.failure}));process.exitCode=report.success?0:1;
}
async function main(){
 try{await fs.access(output);throw Error('Report exists; preserved');}catch(error){if(error.code!=='ENOENT')throw error;}
 const{createReferenceFixture}=await import('./reference-fixture.mjs'),{ParticleDelivery}=await import('./particle-delivery.mjs');
 const fixture=createReferenceFixture(),frames=[];let descriptor;
 try{for(let index=0;index<20;index++){const frame=fixture.update(index);descriptor??=frame.descriptor;frames.push({root:frame.descriptor.rootMatrix,emitter:frame.descriptor.matrix,anchor:fixture.target.groups.get('target_anchor').matrixWorld.toArray(),pivot:fixture.targetWrapper.matrixWorld.toArray(),expected:frame.descriptor.referenceTarget.matrix});}}finally{fixture.close();}
 descriptor.textureMesh='authored';const data={version:1,epoch:1,emitters:[descriptor],collision:[]};
 const token=crypto.randomBytes(32).toString('hex');temp=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-reference-'));
 let authenticated=false;
 server=net.createServer(socket=>{if(wire){socket.destroy();return;}wire=new JsonLines(socket);wire.on('invalid',()=>void stop('Invalid authored test wire'));wire.on('message',message=>{void(async()=>{
  if(!authenticated){if(message.kind!=='hello'||message.token!==token)throw Error('Invalid authored test ticket');authenticated=true;delivery=new ParticleDelivery({scope,data,wire,send:value=>wire.send(value),current:()=>!done,diagnose:(code,reason)=>report.diagnostics.push({code,reason}),report:report.particles});wire.send({...scope,kind:'reference-scene',data,frames,screenshot:reportName.replace(/\.json$/,'-active.png')});return;}
  if(message.kind==='tested'){report.native=message.result;await stop(message.result.passed?null:'Native reference renderer checks failed');return;}
  validateCommand(message,scope);if(message.kind==='particles-start')await delivery.start(message.layout);else if(message.kind==='particle-frame')await delivery.frame(message);else throw Error('Unexpected authored reference command');
 })().catch(error=>void stop(error.message));});});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const ticket=path.join(temp,'ticket.json');await fs.writeFile(ticket,JSON.stringify({port:server.address().port,token}),{flag:'wx',mode:0o600});
 const log=path.join(project,'reports',reportName.replace(/\.json$/,'.engine.log'));
 child=spawn(path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),['--path',project,'--resolution','800x600','--rendering-method','forward_plus','--rendering-driver','vulkan','--script','res://tests/particle_reference_live.gd','--log-file',log,'--','--ticket='+ticket],{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',data=>stdout=(stdout+data).slice(-5000));child.stderr.on('data',data=>stderr=(stderr+data).slice(-10000));child.on('error',error=>void stop(error.message));child.on('exit',code=>{if(!done)void stop('Native reference test exited early: '+code);});timeout=setTimeout(()=>void stop('Native reference integration timed out'),45000);
}
main().catch(error=>void stop(error.message));
