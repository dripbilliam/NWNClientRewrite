// Active-module authored spell dependency inventory. Instruction scanning is
// presence evidence only: a bound command can still have unsupported branches.
// No script bytecode or assets are copied into the report.
import {openLocalModule} from './local-module.mjs';
import {loadCharacterRules} from '../src/character.js';
import {parseNcs,parseScriptApi} from '../src/ncs.js';
import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';
import {castingSpell} from '../src/spell_metadata.js';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {bindItemPropertyFactory} from '../src/item_property_factory.js';
const [install,modulePath]=process.argv.slice(2),resolver=await openLocalModule(install,modulePath),rules=await loadCharacterRules(resolver);
const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',RESOURCE_TYPE.NSS))),session=new ModuleSession(resolver),scripts=new Map(),failures=[],calls=new Map();
bindItemPropertyFactory(session,api);
for(let id=0;id<rules.spells.orderedRows.length;id++){
  try{const spell=castingSpell(rules,id),name=spell.impactScript.split('\0')[0].toLowerCase();if(!name)continue;
    if(!scripts.has(name))scripts.set(name,{name,spellIds:[]});scripts.get(name).spellIds.push(id);
  }catch(error){failures.push({operation:'spell-metadata',spellId:id,message:error.message});}
}
for(const entry of scripts.values()){
  try{
    const program=parseNcs(await resolver.getResource(entry.name,RESOURCE_TYPE.NCS),entry.name),used=new Map();
    for(const instruction of program.instructions.values())if(instruction.op===5){
      const spec=api[instruction.command];if(!spec)throw new Error(`Unknown engine ordinal ${instruction.command}`);
      used.set(spec.name,(used.get(spec.name)??0)+1);
      if(!calls.has(spec.name))calls.set(spec.name,{name:spec.name,engineId:instruction.command,bindingPresent:typeof session.commands[spec.name]==='function',instructions:0,scripts:[],argumentCounts:{}});
      const dependency=calls.get(spec.name);dependency.instructions++;dependency.argumentCounts[instruction.argc]=(dependency.argumentCounts[instruction.argc]??0)+1;}
    entry.engineCalls=[...used].map(([name,instructions])=>({name,instructions}));
    for(const name of used.keys())calls.get(name).scripts.push(entry.name);
  }catch(error){entry.loadFailure=error.message;failures.push({operation:'impact-script',script:entry.name,spellIds:entry.spellIds,message:error.message});}
}
const dependencies=[...calls.values()].sort((a,b)=>b.scripts.length-a.scripts.length||a.name.localeCompare(b.name));
console.log(JSON.stringify({spells:rules.spells.orderedRows.length,impactScripts:scripts.size,loadedScripts:[...scripts.values()].filter(s=>!s.loadFailure).length,
  unboundCommands:dependencies.filter(d=>!d.bindingPresent),dependencies,scripts:[...scripts.values()],failures,diagnostics:runtimeDiagnostics.records,
  limits:'Static scan of active installed ImpactScript NCS instructions. Binding presence is not branch implementation, live casting or campaign readiness; actual engine/load failures remain recorded during execution.'},null,2));
if(failures.length)process.exitCode=1;
