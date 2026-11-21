// Opt-in launch/scope validation only. No process, credential, network or render work.
const flag='--script-floating-visual';
function options(argv){
 const enabled=argv.includes(flag),secondsArgs=argv.filter(v=>v.startsWith('--visual-seconds='));
 if(!enabled){if(secondsArgs.length)throw Error('Visual seconds requires the distinct visual mode');return{enabled:false,seconds:120};}
 const value=name=>argv.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
 const exact=new Set([flag]),prefixes=['--run=','--native-runtime=','--script-floating-directory=','--private-login-pipe=','--native-screen=','--visual-seconds='];
 if(argv.some(v=>!exact.has(v)&&!prefixes.some(p=>v.startsWith(p))))throw Error('Visual mode cannot combine unrelated launch modes');
 if(argv.filter(v=>v===flag).length!==1||prefixes.some(p=>argv.filter(v=>v.startsWith(p)).length>1))throw Error('Duplicate visual launch options');
 if(value('native-runtime')!=='editor'||!value('script-floating-directory')||!value('private-login-pipe')||!/^native-script-floating-[a-z0-9-]+$/.test(value('run')??''))throw Error('Visual mode requires protected owned original-local editor identity');
 const raw=value('visual-seconds')??'120';
 if(!/^[1-9][0-9]{1,2}$/.test(raw)||Number(raw)<30||Number(raw)>180)throw Error('Visual hold must be30–180 seconds');
 if(value('native-screen')!==undefined&&!/^(0|[1-9][0-9]*)$/.test(value('native-screen')))throw Error('Invalid visual display index');
 return{enabled:true,seconds:Number(raw)};
}
function scopeMatches(message,session,connection){
 return Boolean(session&&!session.closed&&session.phase==='playing'&&Number.isSafeInteger(connection)&&message?.connection===connection&&message?.scope?.connection===connection&&message.scope.generation===session.areaGeneration&&message.scope.areaId===session.world?.areaId);
}
function payload(message,session,connection){
 if(!scopeMatches(message,session,connection))throw Error('Visual observation scope retired');
 if(Buffer.byteLength(JSON.stringify(message))>65536)throw Error('Visual observation exceeds64KiB');
 if(!['ordinary-speech-visual-ready','ordinary-speech-visual-sample','ordinary-speech-visual-finished'].includes(message.kind))throw Error('Unexpected visual observation');
 return JSON.parse(JSON.stringify(message));
}
module.exports={options,scopeMatches,payload};
