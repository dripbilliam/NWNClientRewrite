// Active VFX_PERSISTENT callbacks are additional spell entry points beyond
// spells.2da ImpactScript. Metadata only; no authored script bytes are copied.
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {parseNcs,parseScriptApi} from '../src/ncs.js';
import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';
import {spellStringEntry} from '../src/spell_metadata.js';
const [install,modulePath]=process.argv.slice(2),resolver=await openLocalModule(install,modulePath),session=new ModuleSession(resolver),
  table=parse2da(decodeResourceText(await resolver.getResource('vfx_persistent',RESOURCE_TYPE.TWO_DA))),
  api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',RESOURCE_TYPE.NSS))),scripts=new Map(),failures=[],calls=new Map();
for(let row=0;row<table.orderedRows.length;row++)for(const column of ['ONENTER','HEARTBEAT','ONEXIT']){
  const name=spellStringEntry(table,row,column).split('\0')[0].toLowerCase();if(!name)continue;
  if(!scripts.has(name))scripts.set(name,{name,uses:[]});scripts.get(name).uses.push({row,column});
}
for(const script of scripts.values())try{
  const program=parseNcs(await resolver.getResource(script.name,RESOURCE_TYPE.NCS),script.name),used=new Set();
  for(const instruction of program.instructions.values())if(instruction.op===5){const spec=api[instruction.command];if(!spec)throw new Error(`Unknown engine ordinal ${instruction.command}`);
    used.add(spec.name);if(!calls.has(spec.name))calls.set(spec.name,{name:spec.name,engineId:instruction.command,bindingPresent:typeof session.commands[spec.name]==='function',scripts:[]});}
  script.engineCalls=[...used];for(const name of used)calls.get(name).scripts.push(script.name);
}catch(error){script.loadFailure=error.message;failures.push({script:script.name,uses:script.uses,message:error.message});}
const dependencies=[...calls.values()].sort((a,b)=>b.scripts.length-a.scripts.length||a.name.localeCompare(b.name));
console.log(JSON.stringify({rows:table.orderedRows.length,scripts:scripts.size,loadedScripts:[...scripts.values()].filter(s=>!s.loadFailure).length,
  unboundCommands:dependencies.filter(c=>!c.bindingPresent),dependencies,scripts:[...scripts.values()],failures,
  limits:'Static installed VFX_PERSISTENT script dependency scan. Binding presence does not establish supported branches, execution, visuals or campaign readiness.'},null,2));
if(failures.length)process.exitCode=1;
