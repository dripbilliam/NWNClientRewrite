import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {GameUi} from '../src/game_ui.js';
import {GameText,parseTalkTable} from '../src/talk_table.js';
import {clientTokenAlignmentRef} from '../src/game_talk_tokens.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-talk-token-parser-v1.json',report={queries:[]};
try{
 const directory=path.join(install,'lang/en/data'),files=(await fs.readdir(directory)).filter(n=>/\.tlk$/i.test(n)).map(name=>({name,arrayBuffer:()=>fs.readFile(path.join(directory,name))}));
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{talkFiles:files,runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0],actor=s.player,root=actor.creatureData,ui={session:s,text:new GameText({base:parseTalkTable(await files.find(f=>f.name==='dialog.tlk').arrayBuffer())})};
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name),frame={stack:[]};assert.ok(ordinal>=0);for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'token_parser_'+name),actor.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0]?.value;};
 const check=(label,query,expected,gender=0)=>{const value=GameUi.prototype.dialogueText.call(ui,query,actor,gender);assert.equal(value,expected,label);report.queries.push({label,length:value.length,sha256:createHash('sha256').update(value).digest('hex')});};
 await invoke('SetCustomToken',[42,'first effect']);check('custom','<CUSTOM42>','first effect');await invoke('SetCustomToken',[42,'second effect']);check('replacement','<CUSTOM42>','second effect');check('escape','<<CUSTOM42>','<CUSTOM42>');
 const first=ui.text.resolve(root.FirstName),last=ui.text.resolve(root.LastName);check('names','<FirstName>|<LastName>|<FullName>',`${first||last}|${last||first}|${[first,last].filter(Boolean).join(' ')}`);
 const pronoun=s.talkTable.namedTokens.find(r=>Buffer.from(r.name).toString()==='He/She');check('gender','<He/She>',ui.text.strRef(pronoun.refs[1]),1);
 const race=s.characterRules.racialtypes.orderedRows[root.Race],cls=s.characterRules.classes.orderedRows[root.ClassList[0].Class];check('active-rule-names','<Race>|<race>|<Class>|<class>',[race.ConverName,race.ConverNameLower,cls.Name,cls.Lower].map(ref=>ui.text.strRef(Number(ref))).join('|'),1);
 check('alignment','<Alignment>|<alignment>',[false,true].map(lower=>ui.text.strRef(clientTokenAlignmentRef(root.LawfulChaotic,root.GoodEvil,lower))).join('|'));
 const calendar=s.worldTimer.calendar(),hour=s.worldTimer.getHour();check('calendar','<GameYear>|<GameMonth>|<GameTime>',`${calendar.year}|${calendar.month}|${((hour+11)%12)+1}`);
 check('plain-widget','<StartCheck>checked <CUSTOM42></Start>','checked second effect');
 s.talkTable.overrides.set(7,new TextEncoder().encode('Script <CUSTOM42>'));assert.equal(await invoke('GetStringByStrRef',[7]),'Script second effect');report.serverOverride=true;
 assert.equal(s.registry.nextObjectId[0],cursor);assert.equal(s.talkTable.namedTokens.length,57);report.namedRows=s.talkTable.namedTokens.length;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Installed active StringTokens/race/class/TLK data, real NCS token updates, actual GameUi dialogue-text method, local client body projection, server custom override parsing and unchanged canonical allocation. Reports only authored labels and text lengths/hashes. Client-name/world providers are local canonical projections; native rich widget context, transport/player-name lookup and full campaign dialogue flow remain separate gates.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED TOKEN PARSER/DIALOGUE TEXT/ACTIVE DATA PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
