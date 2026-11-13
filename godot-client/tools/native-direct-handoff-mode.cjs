'use strict';
function options(argv){
 const enabled=argv.includes('--direct-handoff-check'),find=name=>argv.find(a=>a.startsWith('--'+name+'='))?.slice(name.length+3);
 if(!enabled){if(argv.some(a=>a.startsWith('--direct-handoff-')))throw Error('Direct handoff parameters require explicit check');return{enabled:false};}
 const flags=new Set(['--direct-handoff-check','--native-headless','--native-debugger']),prefixes=['--run=','--native-runtime=','--direct-handoff-directory=','--direct-handoff-scenario=','--private-login-pipe='];
 for(const arg of argv.filter(a=>a.startsWith('--')))if(!flags.has(arg)&&!prefixes.some(p=>arg.startsWith(p)))throw Error('Unrelated direct-handoff argument');
 for(const p of prefixes)if(argv.filter(a=>a.startsWith(p)).length!==1)throw Error('Exact direct-handoff parameters required');
 if(argv.filter(a=>a==='--direct-handoff-check').length!==1||argv.filter(a=>a==='--native-debugger').length>1||!argv.includes('--native-headless')||find('native-runtime')!=='editor'||!/^native-direct-handoff-[a-z0-9-]+$/.test(find('run')??'')||!find('direct-handoff-directory')||!find('private-login-pipe'))throw Error('Direct handoff requires protected headless editor mode');
 const scenario=find('direct-handoff-scenario');if(!['roundtrip','cancel','failure'].includes(scenario))throw Error('Unknown direct-handoff scenario');
 return{enabled:true,scenario,directory:find('direct-handoff-directory'),run:find('run')};
}
module.exports={options};
