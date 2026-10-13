// Generates an entirely authored, disposable native-server fixture. Installed
// assets are referenced by resref; none are copied into the module.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { openLocalModule } from './local-module.mjs';
import { decodeResourceText } from '../src/resource_archive.js';
import { parseScriptApi, parseNcs } from '../src/ncs.js';
import { parseGff } from '../src/gff.js';
import { OracleScript, writeMod, writeGff, field as f, record as r } from './native-oracle-data.mjs';

const [install, sourceModule, output = 'backups/native-combat-oracle/home/modules/codex_combat_oracle.mod'] = process.argv.slice(2);
if (!install || !sourceModule) throw new Error('Usage: node scripts/build-combat-oracle.mjs <install> <read-only module for resolver> [output]');
const resolver = await openLocalModule(install, sourceModule);
const api = parseScriptApi(decodeResourceText(await resolver.getResource('nwscript', 2009)));
const tileset = decodeResourceText(await resolver.getResource('ttr01', 2013));
const tiles = [...tileset.matchAll(/\[TILE(\d+)\]([\s\S]*?)(?=\[|$)/g)];
const flat = tiles.find(([, , body]) => ['TopLeft','TopRight','BottomLeft','BottomRight'].every(side => new RegExp(`^${side}=Grass\\s*$`, 'm').test(body) && new RegExp(`^${side}Height=0\\s*$`, 'm').test(body)) && ['Top','Right','Bottom','Left'].every(side => new RegExp(`^${side}=\\s*$`, 'm').test(body)));
if (!flat) throw new Error('No flat grass tile available in installed tileset');
const resources = [], add = (name, type, bytes) => resources.push([name, type, bytes]);
const gff = (name, type, signature, node) => { const bytes = writeGff(signature, node); parseGff(bytes, signature); add(name, type, bytes); };
const call = (name, ...args) => ({ call: name, args }), self = { self: true };
const object = tag => call('GetObjectByTag', tag, 0), integer = expression => call('IntToString', expression);
const log = (...parts) => call('PrintString', { concat: ['ORACLE ', ...parts, ' t=', integer(call('GetTimeSecond')), '.', integer(call('GetTimeMillisecond'))] });
const script = (name, body) => { const code = new OracleScript(api); body(code); const bytes = code.finish(); parseNcs(bytes, name); add(name, 2010, bytes); };
script('oc_load', code => {
  code.statement(log('LOAD'));
  code.statement(call('ExecuteScript', 'oc_probe', object('oc_i')));
  for (const tag of ['oc_a', 'oc_b']) code.statement(call('ExecuteScript', 'oc_attack', object(tag)));
});
script('oc_probe', code => {
  code.statement(log('PROBE id=', call('ObjectToString', self), ' BAB=', integer(call('GetBaseAttackBonus', self)), ' AC=', integer(call('GetAC', self, 0)), ' HP=', integer(call('GetCurrentHitPoints', self))));
  code.statement(call('ApplyEffectToObject', 0, call('EffectDamage', 50, 4096, 6), self, { float: 0 }));
  code.statement(log('IMMORTAL id=', call('ObjectToString', self), ' HP=', integer(call('GetCurrentHitPoints', self))));
  for(const skill of [10,16])code.statement(log('SKILL id=',call('ObjectToString',self),' skill=',integer(skill),' base=',integer(call('GetSkillRank',skill,self,1)),' effective=',integer(call('GetSkillRank',skill,self,0))));
  code.statement(call('ApplyEffectToObject', 2, call('EffectImmunity', 2), self, { float:0 }));
  for(const name of ['FortitudeSave','ReflexSave','WillSave'])code.statement(log('SAVE id=',call('ObjectToString',self),' kind=',name,' dc=65535 category=2 result=',integer(call(name,self,65535,2,self))));
  for(const [stage,name,amount] of [['up5','EffectSkillIncrease',5],['up3','EffectSkillIncrease',3],['down2','EffectSkillDecrease',2]]){
    code.statement(call('ApplyEffectToObject',2,call(name,10,amount),self,{float:0}));
    code.statement(log('SKILL_EFFECT id=',call('ObjectToString',self),' stage=',stage,' base=',integer(call('GetSkillRank',10,self,1)),' effective=',integer(call('GetSkillRank',10,self,0))));
  }
  const featLog=(stage,feat)=>log('FEAT id=',call('ObjectToString',self),' stage=',stage,' feat=',integer(feat),' has=',integer(call('GetHasFeat',feat,self,0)),' owned=',integer(call('GetHasFeat',feat,self,1)),' uses=',integer(call('GetFeatRemainingUses',feat,self)));
  for(const feat of [223,39,5])code.statement(featLog('loaded',feat));
  for(const stage of ['consume1','consume2','exhausted']){
    code.statement(call('DecrementRemainingFeatUses',self,39));code.statement(featLog(stage,39));
  }
  code.statement(call('IncrementRemainingFeatUses',self,39));code.statement(featLog('restore',39));
});
script('oc_attack', code => {
  code.statement(call('SetAILevel', self, 4));
  code.statement(log('START id=', call('ObjectToString', self), ' BAB=', integer(call('GetBaseAttackBonus', self)), ' AC=', integer(call('GetAC', self, 0)), ' HP=', integer(call('GetCurrentHitPoints', self)), '/', integer(call('GetMaxHitPoints', self))));
  // Both creatures receive this script; identity determines the other target.
  code.ifThen(call('GetIsObjectValid', object('oc_a')), () => {
    // Self comparison is done through the installed GetTag API.
    code.ifThen({ equalString: [call('GetTag', self), 'oc_a'] },
      () => code.statement(call('ActionAttack', object('oc_b'), 0)),
      () => code.statement(call('ActionAttack', object('oc_a'), 0)));
  });
});
script('oc_attacked', code => code.statement(log('ATTACKED id=', call('ObjectToString', self), ' caller=', call('ObjectToString', call('GetLastAttacker', self)), ' type=', integer(call('GetLastAttackType', self)), ' mode=', integer(call('GetLastAttackMode', self)))));
script('oc_damaged', code => code.statement(log('DAMAGED id=', call('ObjectToString', self), ' caller=', call('ObjectToString', call('GetLastDamager', self)), ' damage=', integer(call('GetTotalDamageDealt')), ' HP=', integer(call('GetCurrentHitPoints', self)))));
script('oc_round', code => {
  const count = () => call('GetLocalInt', self, 'oc_rounds');
  code.statement(call('SetLocalInt', self, 'oc_rounds', { add: [count(), 1] }));
  code.statement(log('ROUND id=', call('ObjectToString', self), ' count=', integer(count()), ' HP=', integer(call('GetCurrentHitPoints', self))));
  code.ifThen({ ge: [count(), 3] }, () => code.statement(call('ClearAllActions', 1, self)));
});
const creature = (tag, faction, x, options = {}) => r({
  TemplateResRef: f(11, tag), Tag: f(10, tag), FirstName: f(12, tag), LastName: f(12, ''),
  Appearance_Type: f(2, 1), Gender: f(0, 0), Race: f(0, 6), Phenotype: f(5, 0),
  FactionID: f(2, faction), Str: f(0, 10), Dex: f(0, options.dex ?? 10), Con: f(0, 10), Int: f(0, 10), Wis: f(0, 10), Cha: f(0, 10),
  HitPoints: f(3, 20), CurrentHitPoints: f(3, 20), MaxHitPoints: f(3, 20), NaturalAC: f(0, 0),
  ClassList: f(15, [r({ Class: f(5, 4), ClassLevel: f(3, options.level ?? 1) }, 2)]),
  SkillList: f(15, Array.from({ length: 27 }, () => r({ Rank: f(0, 0) }, 0))), FeatList: f(15, (options.feats??[]).map(([feat,uses])=>r({Feat:f(2,feat),...(uses===undefined?{}:{Uses:f(0,uses)})},1))),
  Equip_ItemList: f(15, []), ItemList: f(15, []), SpecAbilityList: f(15, []), VarTable: f(15, []),
  GoodEvil: f(0, 50), LawfulChaotic: f(0, 50), IsPC: f(0, 0), IsImmortal: f(0, 1), Plot: f(0, 0),
  BodyBag: f(0, 0), WalkRate: f(5, 0), Interruptable: f(0, 1), DecayTime: f(4, 5000),
  ScriptAttacked: f(11, 'oc_attacked'), ScriptDamaged: f(11, 'oc_damaged'), ScriptEndRound: f(11, 'oc_round'),
  XPosition: f(8, x), YPosition: f(8, 5), ZPosition: f(8, 0), XOrientation: f(8, x === 4 ? 1 : -1), YOrientation: f(8, 0)
}, 4);
const actors = [creature('oc_a',1,4), creature('oc_b',2,5), creature('oc_i',0,8,{ level:11,dex:14,feats:[[223,0],[39,2],[5]] })];
for (const actor of actors) gff(actor.fields.Tag.value, 2027, 'UTC ', actor);
gff('oc_arena', 2023, 'GIT ', r({ 'Creature List': f(15, actors), 'Door List': f(15, []), 'Placeable List': f(15, []), 'TriggerList': f(15, []), 'WaypointList': f(15, []), StoreList: f(15, []), 'Encounter List': f(15, []), SoundList: f(15, []) }));
gff('oc_arena', 2012, 'ARE ', r({ Tag: f(10, 'oc_arena'), Name: f(12, 'Owned Combat Oracle'), Tileset: f(11, 'ttr01'), Width: f(5, 1), Height: f(5, 1), Flags: f(4, 0), ID: f(5, 0), Version: f(4, 1), PlayerVsPlayer: f(0, 0),
  Tile_List: f(15, [r({ Tile_ID: f(5, Number(flat[1])), Tile_Height: f(5, 0), Tile_Orientation: f(5, 0), Tile_MainLight1: f(0, 0), Tile_MainLight2: f(0, 0), Tile_SrcLight1: f(0, 0), Tile_SrcLight2: f(0, 0), Tile_AnimLoop1: f(0, 0), Tile_AnimLoop2: f(0, 0), Tile_AnimLoop3: f(0, 0) }, 1)]) }));
gff('oc_arena', 2046, 'GIC ', r({ CreatureList: f(15, []) }));
gff('module', 2014, 'IFO ', r({ Mod_Name: f(12, 'Owned Combat Oracle'), Mod_Tag: f(10, 'codex_combat_oracle'), Mod_Description: f(12, 'Authored research fixture'), Mod_Area_list: f(15, [r({ Area_Name: f(11, 'oc_arena') }, 6)]),
  Mod_Entry_Area: f(11, 'oc_arena'), Mod_Entry_X: f(8, 2), Mod_Entry_Y: f(8, 2), Mod_Entry_Z: f(8, 0), Mod_Entry_Dir_X: f(8, 1), Mod_Entry_Dir_Y: f(8, 0), Mod_OnModLoad: f(11, 'oc_load'),
  Mod_MinGameVer: f(10, '1.69'), Mod_Creator_ID: f(5, 0), Mod_Version: f(4, 3), Mod_IsSaveGame: f(0, 0), Mod_ID: f(13, Buffer.alloc(16, 1)), Mod_HakList: f(15, []), Mod_StartYear: f(4, 1372), Mod_StartMonth: f(0, 6), Mod_StartDay: f(0, 1), Mod_StartHour: f(0, 12), Mod_MinPerHour: f(0, 2), Mod_DawnHour: f(0, 6), Mod_DuskHour: f(0, 18) }));
gff('repute', 2038, 'FAC ', r({ FactionList: f(15, ['PC','A','B'].map((name, i) => r({ FactionName: f(10, name), FactionParentID: f(4, i ? 0 : 0xffffffff), FactionGlobal: f(0, 1) }, 0))),
  RepList: f(15, Array.from({ length: 9 }, (_, index) => { const a = index % 3, b = Math.floor(index / 3); return r({ FactionID1: f(4, a), FactionID2: f(4, b), FactionRep: f(4, a === b ? 100 : a && b ? 0 : 50) }, 1); })) }));
const bytes = writeMod(resources); assert.ok(bytes.length > 0);
await fs.mkdir(path.dirname(path.resolve(output)), { recursive: true }); await fs.writeFile(output, bytes);
await fs.writeFile(path.resolve(output) + '.manifest.json', JSON.stringify({ authored: true, moduleSha256:createHash('sha256').update(bytes).digest('hex'), tileId: Number(flat[1]), resources: resources.map(([name,type,data]) => ({ name,type,bytes:data.length })), commands: [...new Set(resources.filter(([,t]) => t === 2010).flatMap(([, ,b]) => [...parseNcs(b).instructions.values()].filter(i => i.op === 5).map(i => i.command)))].map(id => ({ id, name: api[id].name })) }, null, 2));
console.log(JSON.stringify({ output: path.resolve(output), bytes: bytes.length, tile: Number(flat[1]), resources: resources.length }));
