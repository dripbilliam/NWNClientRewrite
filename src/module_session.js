import { GameObjectArray, GAME_OBJECT_TYPE, OBJECT_INVALID } from './game_object_array.js';
import { initializeCreaturePerception } from './perception_detection.js';
import { loadPerceptionRanges,postProcessPerceptionRanges } from './perception_ranges.js';
import { parseGff, getGffStructType, cloneGff } from './gff.js';
import { decodeResourceText, RESOURCE_TYPE } from './resource_archive.js';
import { parseNcs, parseScriptApi } from './ncs.js';
import { NwScriptVm } from './nwscript_vm.js';
import { ScriptScheduler } from './script_scheduler.js';
import { ScriptVariableTable } from './script_variables.js';
import { parseCharacter, loadCharacterRules, characterStats, experienceAward, resolvePlayerModels, importedObjectIds } from './character.js';
import { Conversation } from './conversation.js';
import { nearestObjects, creatureCriteria } from './nearest_objects.js';
import { inTrigger, triggerGeometry, encounterGeometry } from './trigger_geometry.js';
import { parse2da } from './area.js';
import { creatureTalkRange } from './interaction_range.js';
import { EffectRuntime } from './effect_runtime.js';
import { nativeDistanceSquared } from './nearest_objects.js';
import { reconcileExperience, initializeBonusSpellSlots } from './character_progression.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { NativeRandom } from './native_random.js';
import { equipmentCombatEffects } from './combat_modifiers.js';
import { damageEffectIntegers, damageImmunityEffectIntegers, damageResistanceEffectIntegers, damageReductionEffectIntegers } from './damage_effect.js';
import { DamageRuntime } from './damage_runtime.js';
import { CombatRuntime } from './combat_runtime.js';
import { damageBonusEffectIntegers } from './damage_effect_bonus.js';
import { skillRank } from './skill_rank.js';
import { creatureCurrentHitPoints } from './creature_damage.js';
import { difficultyOption } from './difficulty.js';
import { createCombatRound } from './combat_round.js';
import { creatureRoot, creatureAlignment } from './creature_rules.js';
import { createObjectActionState } from './object_actions.js';
import { VisibilityList } from './perception.js';
import { FactionReputationTable, objectReputation, aiStateReaction, effectivePVPSetting, subtractWorldTimes } from './reputation.js';
import { scriptLastAttackMode, scriptLastAttackType } from './combat_events.js';
import { addNativeFeat, removeNativeFeat } from './feat_uses.js';
import { initializeSkillArmorPenalties, initializeClassSkillPenalties } from './skill_caches.js';
import { PathInformation } from './path_information.js';
import { WorldTimer } from './world_timer.js';
import { NativeGeometryResources, NativeAreaGeometry } from './area_geometry.js';
import { NativeAreaSpatialArray, setObjectPosition } from './area_spatial.js';
import { NativeIdList } from './native_id_list.js';
import { NativeAIMaster,scriptSetAILevel } from './native_ai_master.js';
import { updateSubareasOnMove, intersectSubareaPolygon } from './subareas.js';
import { dispatchSubareaEvent } from './subarea_events.js';
import { initialMovementFactor,loadMovementRate,nativeFloatEntry } from './movement_rate.js';
import { intEntry } from './combat_stats.js';
import { updatePersonalSpace } from './personal_space.js';

const label = value => typeof value === 'string' ? value : value?.entries?.[0]?.text ?? '';
const scriptTypes = { creature: 1, player: 1, item: 2, trigger: 4, door: 8, areaOfEffect: 16, waypoint: 32, placeable: 64, store: 128, encounter: 256 };
const localTypes = ['int', 'float', 'string', 'object', 'location'];
const blueprintTypes = { door: [2042, 'UTD '], placeable: [2044, 'UTP '], creature: [2027, 'UTC '], waypoint: [2058, 'UTW '], trigger: [2032, 'UTT '], encounter: [2040, 'UTE '], store: [2051, 'UTM '], sound: [2035, 'UTS '], item: [2025, 'UTI '] };
const position = entry => [Number(entry.XPosition ?? entry.X ?? 0), Number(entry.ZPosition ?? entry.Z ?? 0), -Number(entry.YPosition ?? entry.Y ?? 0)];

export class ModuleSession {
  constructor(resolver, { onDiagnostic = () => {}, onMessage = () => {}, onCombatMessage = null, onSound = () => {}, onTransition = null, onDoorState = () => {}, onConversation = () => {}, onCutscene = () => {}, onClearActions = () => {}, runStartupScripts = true, difficultyLevel = 2, serverPvpSetting = null, naturalOnesFailSavingThrows = true, stickyCombatModes = false } = {}) {
    Object.assign(this, { resolver, onDiagnostic, onMessage, onSound, onTransition, onDoorState, onConversation, onCutscene, onClearActions, runStartupScripts });
    this.registry = new GameObjectArray({ clientMode: true });
    this.sources = new Map(); this.areas = new Map(); this.tags = new Map(); this.programs = new Map(); this.diagnostics = [];
    this.blueprints = new Map();
    this.geometryResources = new NativeGeometryResources(resolver, (error, context) => this.report(error, context));
    this.scheduler = new ScriptScheduler({ validTarget: id => Boolean(this.registry.get(id)), beforePump: () => this.updateWorld(), dispatch: e => this.dispatch(e), onError: (error, queued) => this.report(error, { ...this.diagnosticContext(queued.targetId), eventType: queued.event.type, script: queued.event.name }) });
    this.worldTimer=new WorldTimer(()=>BigInt(Math.trunc(this.scheduler.time*1000)));
    this.started = false; this.currentArea = null; this.transitioning = false;
    this.conversation = new Conversation(this); this.triggerMembers = new Map();
    this.effects = new EffectRuntime(this);
    this.aiMaster=new NativeAIMaster();
    this.damage = new DamageRuntime(this);
    this.combat = new CombatRuntime(this);
    this.onCombatMessage=onCombatMessage??(message=>runtimeDiagnostics.record('combat.presentation-unimplemented',
      'Native combat message delivered locally; combat UI/animation routing is not implemented',{...this.diagnosticContext(message.recipientId),messageType:message.type}));
    if (!Number.isInteger(difficultyLevel)) throw new Error('Invalid game difficulty');
    this.difficultyLevel = Math.min(4, Math.max(0, difficultyLevel));
    this.random = new NativeRandom((Date.now() >>> 0));
    if (serverPvpSetting !== null && !Number.isInteger(serverPvpSetting)) throw new Error('Invalid server PVP setting');
    this.serverPvpSetting = serverPvpSetting;
    // DefineServerConfiguration 1405758cf..140575913 defaults
    // ruleset.natural-ones-fail-saving-throws to byte1. Its live callback
    // 14057b380 writes CServerInfo+148, read by SavingThrowRoll.
    if(typeof naturalOnesFailSavingThrows!=='boolean')throw new Error('Invalid natural-one saving throw setting');
    this.naturalOnesFailSavingThrows=naturalOnesFailSavingThrows;
    // DefineServerConfiguration 140576aca..140576af9 defaults
    // ruleset.combat.sticky-modes to byte0; GetStickyCombatModesEnabled
    // 14055b9c0 reads the live server-internal +101f8 value.
    if(typeof stickyCombatModes!=='boolean')throw new Error('Invalid sticky combat mode setting');
    this.stickyCombatModes=stickyCombatModes;
  }
  diagnosticContext(id) {
    const object = this.registry.get(id), area = this.registry.get(object?.areaId);
    return { module: this.resolver?.moduleName ?? this.module?.tag, area: area?.resRef ?? this.currentArea?.resRef,
      objectId: object?.id, sourceKey: object?.sourceKey, objectKind: object?.kind, objectTag: object?.tag };
  }
  report(error, context = {}) {
    runtimeDiagnostics.error(error, 'session.failure', { ...this.diagnosticContext(error?.diagnosticContext?.objectId), ...context });
    const message = error.message ?? String(error); this.diagnostics.push(message);
    if (this.diagnostics.length > 64) this.diagnostics.shift(); this.onDiagnostic(message);
  }
  register(kind, sourceKey, data) {
    if (this.sources.has(sourceKey)) throw new Error(`Duplicate source placement ${sourceKey}`);
    const object = { ...data, kind, sourceKey, objectType: GAME_OBJECT_TYPE[kind], eventObjects: {} };
    // CNWSObject constructor 14048bb36; distinct from effect/AoE spell IDs.
    if(object.objectType>=5&&object.objectType<=14){object.lastSpellId??=-1;object.plot??=false;object.counterSpellTargetId??=OBJECT_INVALID;}
    // CNWSObject constructor14048ba79 and CNWSModule constructor1404787f0.
    // AI list registration and subsequent level changes have separate owners.
    if(object.objectType>=5&&object.objectType<=14){object.nativeAILevel7c??=-1;object.nativeAILocked80??=0;object.animationState??=0;}
    if(object.objectType===3){object.nativePathfindingLevel464??=2;object.nativeTimeOfDay3d4??=0;object.nativeInvisibleCreatureIds330??=[];}
    if (object.objectType === 5) {
      initializeCreaturePerception(object,this.random);
      object.isPC??=kind==='player';object.isDM??=false;
      object.nativeSilence75c??=0;
      // Listen detection reads the same +8fc master ID as associate cleanup.
      // Preserve the old research accessor as an alias, never a second cell.
      if(object.masterId!==undefined&&object.nativeStealthTarget8fc!==undefined&&(object.masterId>>>0)!==(object.nativeStealthTarget8fc>>>0))throw new Error('Conflicting native master ID values');
      object.masterId=(object.masterId??object.nativeStealthTarget8fc??OBJECT_INVALID)>>>0;
      Object.defineProperty(object,'nativeStealthTarget8fc',{enumerable:true,configurable:true,get(){return this.masterId;},set(value){this.masterId=value>>>0;}});
      for(const field of ['nativeField771','nativeField8d6','nativeField58c','nativeFieldEc','nativeOrphanState918','nativeOrphanDay91c','nativeOrphanTime920','nativeReputationCounter590','nativeInvited7dc','nativeInvitationDay7e0','nativeInvitationTime7e4'])object[field]??=0;
      object.nativeInvitations7e8??=null;object.nativeInvitations7f0??=null;
      object.nativeAutoMapTileX6e4??=255;object.nativeAutoMapTileY6e5??=255;object.nativeAutoMapArea6e8??=OBJECT_INVALID;
      object.nativeSightRange7b0??=0;object.nativeHearingRange7b8??=0;
      object.nativePerceptionRange798??=11;object.nativeSize718??=0;object.nativeAttackRange71c??=0;
      object.nativeVisualTypes160??=[];
      object.nativeLastPerceived79c??=OBJECT_INVALID;
      for(const name of ['nativePerceptionHeard7a0','nativePerceptionSeen7a4','nativePerceptionInaudible7a8','nativePerceptionVanished7ac'])object[name]??=0;
      // CNWSCreature constructor14037a3b2..14037a3c7.
      object.nativeFollowingAOEs ??= new NativeIdList();
      object.nativeSubareaMembership ??= new NativeIdList();
      object.objectActionState = createObjectActionState();
      // CNWSCreature constructor 0x14037a8c3..14037a9ed and
      // 0x14037adf0..14037ae63. Status/perception updates remain separate.
      // +8d4 is one native WORD. Perception consumes its low byte;
      // movement-rate category1 clears bit1 in that same storage.
      const field8d4=[object.nativeField8d4,object.nativeMovementFlags8d4].filter(v=>v!==undefined),byte8d4=object.perceptionUpdateFlags;
      if(field8d4.some(v=>!Number.isInteger(v))||field8d4.some(v=>(v&65535)!==(field8d4[0]&65535))||
        byte8d4!==undefined&&(!Number.isInteger(byte8d4)||field8d4.length>0&&(byte8d4&255)!==(field8d4[0]&255)))
        throw new Error('Conflicting native creature field8d4 values');
      object.nativeField8d4=field8d4.length?field8d4[0]&65535:byte8d4===undefined?65535:0xff00|(byte8d4&255);
      Object.defineProperty(object,'nativeMovementFlags8d4',{enumerable:true,configurable:true,get(){return this.nativeField8d4&65535;},set(v){this.nativeField8d4=v&65535;}});
      Object.defineProperty(object,'perceptionUpdateFlags',{enumerable:true,configurable:true,get(){return this.nativeField8d4&255;},set(v){this.nativeField8d4=(this.nativeField8d4&0xff00)|(v&255);}});
      object.creatureState ??= 0;
      object.visionFlags ??= 0;object.blindSightRange ??= 0;
      object.nativeField6ed ??= 0;
      object.nativeField6ec??=0;object.nativeField6ee??=0;
      object.creatureAnimation ??= 0; object.currentAITargetId ??= OBJECT_INVALID;
      object.nativeField700 ??= 0;
      // AddAttackActions writes +708 as its passive argument; retarget owners
      // read/write that SAME native int. Keep semantic accessors on one cell.
      const field708 = [object.nativeField708, object.passiveAttack, object.attackTargetChanged].filter(v => v !== undefined);
      if (field708.some(v => !Number.isInteger(v)) || field708.some(v => (v|0) !== (field708[0]|0)))
        throw new Error('Conflicting native creature field708 values');
      object.nativeField708 = (field708[0] ?? 0) | 0;
      for (const name of ['passiveAttack','attackTargetChanged']) Object.defineProperty(object,name,{
        enumerable:true,configurable:true,get(){return this.nativeField708;},set(value){this.nativeField708=value|0;},
      });
      object.nativeField704 ??= 0; object.nativeField744 ??= 100;
      object.combatMode ??= 0; object.pendingCombatMode ??= 0;
      object.combatAnimationSpeed??=0; // constructor 14037a97d, byte +6f8
      object.activities ??= 0; object.lockedActivities ??= 0;
      object.nativeBodyState ??= 0; object.chairId ??= OBJECT_INVALID; object.lockOrientationId ??= OBJECT_INVALID;
      object.nativeCollisionFlag788??=0;object.cutsceneGhost??=false; // constructor 14037b24a/14037b25c
      object.nativeStatsFieldBC??=0; // stats constructor 1403ee3d1
      object.nativeField76c??=0;
      object.orientation??=[1,0,-0]; // CNWSObject constructor14048b998..14048b9af: native(1,0,0).
      object.nativeFrameElapsedD4??=0;object.nativeBarter??=null;
      object.nativeAcceleration538??=1;object.nativeMovementFactor78c??=1; // creature constructor14037b1d5/14037b251
      object.nativeMovementFactor8e8??=initialMovementFactor(this.characterRules??{});
      object.nativeHaste308??=0;
      object.attackActionTargetId ??= OBJECT_INVALID; object.nativeAttackTarget724 ??= OBJECT_INVALID;
      object.attackTargetId ??= OBJECT_INVALID;
      object.attackTargetPosition ??= [0, 0, 0]; // constructor14037ae14/14037ae63
      object.nativeMovementAreaId ??= OBJECT_INVALID; object.nativeMovementGoal ??= [0, 0, 0]; // constructor14037a98c..14037a9b5
      object.nativeField948 ??= OBJECT_INVALID; // constructor14037ab9b
      object.spellActionTargetId ??= OBJECT_INVALID;
      object.nativeTarget740 ??= OBJECT_INVALID;
      object.lastAttackType ??= 0; object.lastAttackMode ??= 0; object.lastWeaponUsedId ??= OBJECT_INVALID;
      object.masterId ??= OBJECT_INVALID; object.associateType ??= 0;
      object.associateIds ??= [];object.excitedDuration ??= 0;
      object.nativeField750 ??= 0;object.nativeField754 ??= 0;
      object.nativeAttackField748??=6000;object.nativeMovementField74c??=1000;
      object.commandable??=true;
      object.reputationPCFlag ??= Number(Boolean(object.isPC));
      object.personalReputationList ??= []; object.factionReputation ??= null; object.pvpReputationList ??= null;
    }
    if ([9, 10].includes(object.objectType)) object.hardness = (object.authored?.Hardness ?? 0) & 255;
    object.locals = new ScriptVariableTable({ onSetInt: (name, value) => {
      if (object.journal && name.startsWith('NW_JOURNAL_ENTRY')) object.journal.set(name.slice(16), value);
    } });
    const result = this.registry.addInternalObject(object);
    if (result.status) throw new Error(`Cannot allocate ${kind}`);
    // Creature constructor14037a5e5..14037a603 registers level0 only when
    // its explicit AI-registration argument is nonzero. Raw test/client
    // records may omit registration; local authored creatures request it.
    if(object.objectType===5&&data.registerAI)this.aiMaster.setLevel(object,0);
    if(object.objectType===5)object.nativePathInfo??=new PathInformation(object.id);
    if (object.objectType === 5) object.perception ??= new VisibilityList(object.id, message =>
      runtimeDiagnostics.record('combat.perception-warning', message, this.diagnosticContext(object.id)));
    this.sources.set(sourceKey, object.id);
    // Native tag lookup compares byte strings case-sensitively, truncated to 64.
    const tag = String(object.tag ?? '').slice(0, 64);
    if (tag) this.tags.set(tag, [object.id, ...(this.tags.get(tag) ?? [])]);
    for (const entry of data.variables ?? []) {
      const type = localTypes[entry.Type - 1];
      if (type) object.locals.set(entry.Name, type, entry.Value);
    }
    return object;
  }
  source(key) { return this.registry.get(this.sources.get(key)); }
  async instance(kind, placement) {
    // GIT objects / embedded inventory items contain complete instance data.
    // TemplateResRef identifies their origin; it does not justify inheriting
    // blueprint locals/scripts omitted by the serialized instance. Store stock
    // may instead explicitly reference a UTI using InventoryRes.
    const template = String(placement.InventoryRes ?? '').toLowerCase();
    if (!template) return placement;
    const [type, signature] = blueprintTypes[kind], key = `${template}:${type}`;
    if (!this.blueprints.has(key)) {
      this.blueprints.set(key, this.resolver.getResource(template, type).then(bytes => parseGff(bytes, signature).root).catch(error => {
        this.report(new Error(`${kind} blueprint ${template}: ${error.message}`)); return {};
      }));
    }
    return { ...await this.blueprints.get(key), ...placement };
  }
  async loadInventory(owner, entry) {
    owner.inventory = [];
    for (const list of ['ItemList', 'Equip_ItemList']) {
      for (const [index, placement] of (entry[list] ?? []).entries()) {
        const data = await this.instance('item', placement);
        const item = this.register('item', `${owner.sourceKey}:${list}:${index}`, {
          ownerId: owner.id, areaId: OBJECT_INVALID, tag: String(data.Tag ?? ''), name: label(data.LocalizedName),
          position: position(data), variables: data.VarTable, authored: data,
          inventoryPosition: data.Repos_PosX === undefined ? null : [data.Repos_PosX, data.Repos_Posy ?? data.Repos_PosY], equipmentSlot: list === 'Equip_ItemList' ? getGffStructType(placement) : null
        });
        owner.inventory.push(item.id);
        if (data.ItemList?.length) await this.loadInventory(item, data);
      }
    }
  }
  byTag(tag, kind = null) {
    return (this.tags.get(String(tag).slice(0, 64)) ?? []).map(id => this.registry.get(id)).filter(o => o && (!kind || o.kind === kind));
  }
  async initialize(areaResRefs, { character = null } = {}) {
    this.ifo = parseGff(await this.resolver.getResource('module', RESOURCE_TYPE.IFO), 'IFO ').root;
    this.worldTimer.loadModule(this.ifo);
    // HAKs may contain unused AREs. Module membership comes from the IFO list.
    if (Array.isArray(this.ifo.Mod_Area_list)) areaResRefs = this.ifo.Mod_Area_list.map(entry => String(entry.Area_Name).toLowerCase());
    if (!areaResRefs.length || new Set(areaResRefs).size !== areaResRefs.length) throw new Error('Module area list is empty or has duplicates');
    this.module = this.register('module', 'module', { tag: this.ifo.Mod_Tag, name: label(this.ifo.Mod_Name), variables: this.ifo.VarTable });
    const api = parseScriptApi(decodeResourceText(await this.resolver.getResource('nwscript', RESOURCE_TYPE.NSS)));
    if (api[6]?.name !== 'AssignCommand' || api[385]?.name !== 'JumpToObject') throw new Error('Unrecognized NWScript command table');
    this.vm = new NwScriptVm({ api, command: name => this.commands[name], diagnosticContext: id => this.diagnosticContext(id), limitations: {
      SetAreaTransitionBMP: 'Transition bitmap is retained but the transition loading-screen presentation is not implemented',
      SpeakString: 'Speech is shown in the message UI; native overhead presentation and sound recipients are not implemented',
      FloatingTextStringOnCreature: 'Floating text is shown in the message UI; native overhead placement is not implemented',
      PlaySound: 'Sound routing is implemented; browser spatial attenuation approximates the native audio listener',
    } });
    this.appearances = parse2da(decodeResourceText(await this.resolver.getResource('appearance', RESOURCE_TYPE.TWO_DA)));
    try {
      const factions = parseGff(await this.resolver.getResource('repute', 2038), 'FAC ').root;
      if (!Array.isArray(factions.FactionList) || factions.FactionList.length < 1) throw new Error('Native FAC faction list is unavailable');
      this.factionTable = new FactionReputationTable(factions.FactionList.length - 1, factions.RepList ?? []);
    } catch (error) {
      if (this.resolver.module.entries.has('repute:2038')) throw error;
      // CreateDefaultFactions constructs five factions, then an NPC matrix
      // initialized 100 except its first cell, zero. No campaign exception.
      this.factionTable = new FactionReputationTable(4, [{ FactionID1: 0, FactionID2: 1, FactionRep: 0 }]);
    }
    this.nextFactionId = this.factionTable.npcCount + 1;
    this.journalDefinitions = new Map();
    try {
      for (const category of parseGff(await this.resolver.getResource('module', RESOURCE_TYPE.JRL), 'JRL ').root.Categories ?? []) this.journalDefinitions.set(category.Tag, category);
    } catch (error) { if (this.resolver.module.entries.has(`module:${RESOURCE_TYPE.JRL}`)) throw error; }
    for (const resRef of areaResRefs) {
      const are = parseGff(await this.resolver.getResource(resRef, RESOURCE_TYPE.ARE), 'ARE ').root;
      const git = parseGff(await this.resolver.getResource(resRef, RESOURCE_TYPE.GIT), 'GIT ').root;
      const area = this.register('area', resRef, { resRef, tag: are.Tag, name: label(are.Name), variables: are.VarTable, flags: are.Flags ?? 0, pvpSetting: (are.PlayerVsPlayer ?? 0) & 255,
        nativePlayerCount150:0,
        width: Number(are.Width ?? 0) | 0, height: Number(are.Height ?? 0) | 0,
        nativeSpotModifier21c:(are.ModSpotCheck??0)|0,nativeListenModifier220:(are.ModListenCheck??0)|0,
        tilesetResRef: String(are.Tileset ?? '').toLowerCase(), tilePlacements: are.Tile_List,
        scripts: { enter: are.OnEnter ?? '', exit: are.OnExit ?? '' }, objects: [] });
      area.nativeGeometry = new NativeAreaGeometry(area, this.geometryResources, this.registry);
      area.nativeSpatial = new NativeAreaSpatialArray(this.registry, message => this.report(new Error(message), { areaId: area.id, operation: 'native-area-spatial-query' }));
      area.nativeSubareas = new NativeIdList();
      this.areas.set(resRef, area);
      for (const [kind, field] of [['door', 'Door List'], ['placeable', 'Placeable List'], ['creature', 'Creature List'], ['waypoint', 'WaypointList'], ['trigger', 'TriggerList'], ['encounter', 'Encounter List'], ['store', 'StoreList'], ['sound', 'SoundList'], ['item', 'List']]) {
        for (const [index, placement] of (git[field] ?? []).entries()) {
          const entry = await this.instance(kind, placement);
          let geometry;
          try { geometry = kind === 'trigger' ? triggerGeometry(entry) : kind === 'encounter' ? encounterGeometry(entry) : undefined; }
          catch (error) { this.report(error, { areaId: area.id, sourceKey: `${resRef}:${kind}:${index}`, operation: 'native-subarea-load' }); continue; }
          const object = this.register(kind, `${resRef}:${kind}:${index}`, { areaId: area.id, tag: String(entry.Tag ?? ''), name: label(entry.LocalizedName ?? entry.LocName) || [label(entry.FirstName), label(entry.LastName)].filter(Boolean).join(' '), authored: entry,
            position: position(entry), bearing: Number(entry.Bearing ?? -Math.atan2(entry.XOrientation ?? 0, entry.YOrientation ?? 1)), variables: entry.VarTable,
            animationState: Number(entry.AnimationState ?? 0), locked: Boolean(entry.Locked), usable: entry.Useable !== 0,
            linkedTo: String(entry.LinkedTo ?? ''), linkedToFlags: Number(entry.LinkedToFlags ?? 0), linkedToModule: String(entry.LinkedToModule ?? ''),
            scripts: { click: entry.OnClick ?? '', open: entry.OnOpen ?? '', closed: entry.OnClosed ?? '', failToOpen: entry.OnFailToOpen ?? '',
              dialogue: entry.ScriptDialogue ?? '', used: entry.OnUsed ?? '', enter: entry.ScriptOnEnter ?? '', exit: entry.ScriptOnExit ?? '', userDefined: entry.ScriptUserDefine ?? entry.OnUserDefined ?? '',
              attacked: entry.ScriptAttacked ?? '', damaged: entry.ScriptDamaged ?? entry.OnDamaged ?? '', death: entry.ScriptDeath ?? entry.OnDeath ?? '',
              spellAt: entry.ScriptSpellAt ?? entry.OnSpellCastAt ?? '', roundEnd: entry.ScriptEndRound ?? '', heartbeat: entry.ScriptHeartbeat ?? '',spawn:entry.ScriptSpawn??'',perception:entry.ScriptOnNotice??'' },
            geometry, factionId: entry.FactionID ?? entry.Faction,
            isPC: kind === 'creature' && Boolean(entry.IsPC), isDM: kind === 'creature' && Boolean(entry.DM), plot: Boolean(entry.Plot), commandable: true,registerAI:kind==='creature' });
          area.objects.push(object.id);
          area.nativeSpatial.insert(object.id);
          // TriggerAddToArea1404ff70c and EncounterAddToArea14043b1e9.
          if (kind === 'trigger' || kind === 'encounter') area.nativeSubareas.append(object.id);
          if (kind === 'creature' || kind === 'placeable' || kind === 'store') await this.loadInventory(object, entry);
        }
      }
    }
    this.player = this.register('player', 'player', { areaId: OBJECT_INVALID, position: [0, 0, 0], radius: 0.22,
      name: 'Preview player', playerName: 'Local preview', isPC: true, isDM: false, isPossessedFamiliar: false, journal: new Map(),registerAI:true });
    if (character) await this.loadCharacter(character);
    this.characterRules ??= await loadCharacterRules(this.resolver);
    for (const object of this.registry.objects.values()) if (object.kind === 'creature') {
      try { this.loadCreatureStats(object); }
      catch (error) { this.report(error, this.diagnosticContext(object.id)); }
    }
    return this;
  }
  async loadCharacter(bytes, filename = 'Player character') {
    if (this.scheduler.pumping) throw new Error('Cannot import a character during script dispatch');
    if (this.player.characterLoaded) throw new Error('Select another BIC before opening a new module. Replacing an active character is not implemented.');
    const authored = parseCharacter(bytes);
    const rules = this.characterRules ?? await loadCharacterRules(this.resolver);
    const stats = characterStats(authored, rules), appearance = resolvePlayerModels(authored, rules);
    for (const message of stats.limitations) runtimeDiagnostics.record('rules.partial', message, { ...this.diagnosticContext(this.player.id), characterFile: filename });
    if (Number.isInteger(authored.MaxHitPoints) && authored.MaxHitPoints !== stats.maxHP) this.report(new Error(`Character HP differs from the saved snapshot (${stats.maxHP} computed, ${authored.MaxHitPoints} saved); native runtime comparison remains open`));
    // Importing a BIC creates owned objects in THIS session. Serialized IDs,
    // saved area/perception/combat references never become runtime IDs.
    const before = new Set(this.registry.objects.keys());
    const player = this.player;
    try { await this.loadInventory(player, authored); }
    catch (error) {
      for (const id of this.registry.objects.keys()) if (!before.has(id)) this.unregister(id);
      player.inventory = []; throw error;
    }
    const imported = (player.inventory ?? []).map(id => this.registry.get(id));
    for (let i = 0; i < imported.length; i++) for (const id of imported[i].inventory ?? []) imported.push(this.registry.get(id));
    const ids = importedObjectIds(player, authored, imported);
    for (const object of [...imported, player]) {
      for (const variable of (object === player ? authored.VarTable : object.authored.VarTable) ?? []) {
        const type = localTypes[variable.Type - 1];
        if (!type) continue;
        const value = type === 'object' ? ids.get(variable.Value) ?? OBJECT_INVALID : type === 'location' ? null : variable.Value;
        if (type !== 'location') object.locals.set(variable.Name, type, value);
        else this.report(new Error(`BIC local location ${variable.Name}: saved area reference cannot be imported into this module`));
      }
    }
    Object.assign(player, { authored, creatureData: initializeBonusSpellSlots(cloneGff(authored)), stats, appearance, characterLoaded: true, characterFile: filename,
      name: [label(authored.FirstName), label(authored.LastName)].filter(Boolean).join(' ') || filename,
      playerName: 'Local player', isPC: true, isDM: false, savedQuickbar: authored.QBList ?? [], importItemIds: ids });
    this.characterRules = rules;
    this.initializeCombatState(player);
    this.initializeReputationState(player, player.creatureData, ids);
    player.itemCombatEffects = equipmentCombatEffects(this.equippedItems(player), rules, { root: player.creatureData });
    this.refreshCombat(player);
    for (const property of player.stats.combat?.unsupportedItemProperties ?? []) runtimeDiagnostics.record('rules.item-property-unimplemented', property.reason,
      { ...this.diagnosticContext(player.id), characterFile: filename, ...property });
    const tag = String(authored.Tag ?? '').slice(0, 64);
    if (tag) { player.tag = tag; this.tags.set(tag, [player.id, ...(this.tags.get(tag) ?? [])]); }
    return player;
  }
  unregister(id) {
    const object = this.registry.get(id); if (!object) return;
    this.registry.get(object.areaId)?.nativeSpatial?.remove(id);
    this.registry.get(object.areaId)?.nativeSubareas?.remove(id);
    this.registry.delete(id); this.sources.delete(object.sourceKey);
    const tag = String(object.tag ?? '').slice(0, 64);
    if (tag) this.tags.set(tag, (this.tags.get(tag) ?? []).filter(other => other !== id));
  }
  creatureStats(id) {
    const object = this.registry.get(id);
    if (object?.objectType !== 5) return null;
    if (!object.stats) throw new Error('Creature stats have not been loaded for this object');
    return object.stats;
  }
  loadCreatureStats(object) {
    const data = cloneGff(object.authored);
    if (data.PM_IsPolymorphed || data.EffectList?.length) throw new Error('Saved creature polymorph/effect import is not implemented');
    for (const field of ['Str', 'Dex', 'Con', 'Int', 'Wis', 'Cha', 'Race', 'HitPoints']) if (!Number.isInteger(data[field])) throw new Error(`Creature stat ${field} is missing or invalid`);
    if (!Array.isArray(data.ClassList) || !data.ClassList.length) throw new Error('Creature class list is missing');
    data.LvlStatList ??= []; data.Experience ??= 0; data.IsPC ??= 0;
    if (data.IsPC && data.LvlStatList.length < data.ClassList.reduce((n, c) => n + c.ClassLevel, 0)) throw new Error('Saved PC creature level history is incomplete');
    initializeBonusSpellSlots(data);
    object.creatureData = data;
    const items = object.inventory.map(id => this.registry.get(id)).filter(i => i.equipmentSlot)
      .map(i => ({ id: i.id, source: i.id, slot: i.equipmentSlot, data: i.authored }));
    object.itemCombatEffects = equipmentCombatEffects(items, this.characterRules, { root: data });
    object.stats = characterStats(data, this.characterRules, { items, itemCombatEffects: object.itemCombatEffects, areaFlags: this.registry.get(object.areaId)?.flags ?? 0 });
    this.initializeCombatState(object);
    this.initializeReputationState(object, data);
    for (const property of object.stats.combat?.unsupportedItemProperties ?? []) runtimeDiagnostics.record('rules.item-property-unimplemented', property.reason,
      { ...this.diagnosticContext(object.id), ...property });
    return object.stats;
  }
  initializeCombatState(object) {
    // PostProcess14039b420..14039b43c /14039b4d9..14039b4f0.
    if(Number(object.isPC)===1||Number(object.isDM)===1)this.aiMaster.setLevel(object,4);
    loadMovementRate(object,this.characterRules);
    updatePersonalSpace(object,this.characterRules,{warning:message=>runtimeDiagnostics.record('combat.personal-space-warning',message,this.diagnosticContext(object.id))});
    if(this.characterRules.ranges){
      loadPerceptionRanges(object,this.characterRules);
      postProcessPerceptionRanges(object,this.characterRules,{pc:o=>Number(o.isPC),possessed:o=>Number(o.isPossessedFamiliar??false),hasFeat:(o,id)=>this.combat.hasFeat(o,id)});
    }else runtimeDiagnostics.record('combat.perception-ranges-unavailable','Native ranges.2da is unavailable; perception range initialization cannot complete',this.diagnosticContext(object.id));
    this.combat.initializeFeatUses(object);
    initializeClassSkillPenalties(object);
    initializeSkillArmorPenalties(object,this.equippedItems(object),this.characterRules);
    object.combatRound = createCombatRound(this.characterRules); object.initiativePending = 1;
    object.combatUpdateTime = Math.trunc(this.scheduler.time);
    object.animationState ??= 1; object.creatureState ??= 0;
    // UpdateAppearanceDependantInfo 0x1403a6c14..0x1403a6c68 stores the
    // MODELTYPE string, not the creature's mesh resource name, at +0x6b8.
    const table = this.characterRules.appearance, column = table.columns.find(c => c.toLowerCase() === 'modeltype');
    const row = table.orderedRows[(object.creatureData ?? object.authored).Appearance_Type & 65535];
    const value = row?.[column];
    const size=intEntry(table,(object.creatureData??object.authored).Appearance_Type&65535,'SIZECATEGORY');
    object.nativeSize718=size.value;
    const reach=nativeFloatEntry(table,(object.creatureData??object.authored).Appearance_Type&65535,'PREFATCKDIST');
    object.nativeAttackRange71c=reach.value;
    if (typeof value === 'string' && value !== '****') object.modelType = value;
    else runtimeDiagnostics.record('combat.appearance-modeltype-unavailable', 'Native damage reaction MODELTYPE is unavailable', this.diagnosticContext(object.id));
  }
  async updateWorld() {
    // AIUpdate 0x14037be20 advances a creature's combat timer BEFORE its
      // UpdateEffectList. Shared RunActions is connected; full AI-level/area
      // scheduling, perception, height, traps and movement remain pending.
    const now = Math.trunc(this.scheduler.time);
    this.worldTimer.snapshot();
    for (const object of this.registry.objects.values()) {
      if (object.objectType === 5 && object.combatRound) {
        const delta = (now - (object.combatUpdateTime ?? 0)) | 0;
        object.combatUpdateTime = now;
        try {
          // Startup-disabled resource/isolated-owner tests retain their
          // explicit bypass. Normal sessions run the native script/perception
          // owner BEFORE round timers. Global AI budget traversal is pending.
          if(this.started&&this.runStartupScripts)await this.combat.updateBeforeTimer(object);
          await this.combat.updateTimer(object, delta);
          await this.combat.updateExcited(object,delta);
          await this.effects.updateObject(object);
          await this.combat.updateAfterEffects(object,delta);
        }
        catch (error) { this.report(error, this.diagnosticContext(object.id)); }
      }else await this.effects.updateObject(object);
    }
  }
  refreshCombat(object) {
    if (!object?.stats?.combat?.saves) return;
    const items = Array.isArray(object.inventory) ? object.inventory.map(id => this.registry.get(id)).filter(i => i?.equipmentSlot)
      .map(i => ({ id: i.id, source: i.id, slot: i.equipmentSlot, data: i.authored })) : undefined;
    const computed = characterStats(object.creatureData ?? object.authored, this.characterRules, {
      currentHP: object.stats.currentHP, items, effects: object.effects ?? [],
      areaFlags: this.registry.get(object.areaId)?.flags ?? 0, limits: this.combatLimits, acCache: object.acCache, possessedFamiliar: Boolean(object.isPossessedFamiliar), itemCombatEffects: object.itemCombatEffects
    });
    Object.assign(object.stats, computed);
  }
  equippedItems(object) {
    return (object.inventory ?? []).map(id => this.registry.get(id)).filter(i => i?.equipmentSlot)
      .map(i => ({ id: i.id, source: i.id, slot: i.equipmentSlot, data: i.authored }));
  }
  savingThrowStat(id, save) {
    const object = this.registry.get(id);
    if (!object) return 0;
    if (object.objectType === 5) {
      const stats = this.creatureStats(id);
      if (!stats.combat?.saves) throw new Error('Final saving throw rules have not been loaded for this creature');
      return stats.combat.saves[save];
    }
    if (['door', 'placeable'].includes(object.kind)) return (object.authored?.[{ fortitude: 'Fort', reflex: 'Ref', will: 'Will' }[save]] ?? 0) & 255;
    return 0;
  }
  skillEffect(type,skill,amount,creatorId) {
    const table=this.characterRules?.skills;if(!table)throw new Error('Native skill rules are unavailable');
    skill|=0;
    const count=(table.orderedRows?.length??table.rows.size)&255;
    if((skill<0||skill>=count)&&skill!==255)return this.effects.invalid();
    return this.effects.create(type,creatorId,[skill,amount|0,28,0,0],8);
  }
  hitPoints(id, maximum) {
    const object = this.registry.get(id);
    if (!object || object.objectType < 5) return 0;
    if (object.objectType === 5) {
      const stats = this.creatureStats(id);
      return maximum ? (stats.maxHP << 16) >> 16 : creatureCurrentHitPoints({ baseHP: stats.currentHP, temporaryHP: stats.temporaryHP ?? 0 });
    }
    // Doors/placeables have their own object HP fields rather than PC stats.
    if (!['door', 'placeable'].includes(object.kind)) throw new Error('Hit point provider for this object type is not implemented');
    return (((!maximum ? object.currentHP : undefined) ?? object.authored?.[maximum ? 'HP' : 'CurrentHP'] ?? object.authored?.HP ?? 0) << 16) >> 16;
  }
  getDifficultyOption(option) { return difficultyOption(this.characterRules?.diffsettings, this.difficultyLevel, option); }
  setExperience(id, amount) {
    const object = this.registry.get(id);
    if (object?.objectType !== 5 || (amount | 0) < 0 || object.isDM) return;
    this.changeExperience(object, amount >>> 0);
  }
  changeExperience(object, xp) {
    const stats = this.creatureStats(object.id), source = object.creatureData ?? object.authored;
    const beforeFeats=(source.FeatList??[]).map(entry=>entry.Feat);
    const result = reconcileExperience(source, stats, xp, this.characterRules, {
      isPC: Boolean(object.isPC), associateType: object.associateType ?? 0,
      minimumLevel: this.minimumLevel ?? 1, maximumLevel: this.maximumLevel ?? 40
    });
    if (result.root) object.creatureData = result.root;
    else if (object.creatureData) object.creatureData.Experience = xp;
    // Preserve the shared stats object for existing UI/engine consumers.
    Object.assign(stats, result.stats);
    if(object.featUsePool) {
      const afterFeats=(creatureRoot(object).FeatList??[]).map(entry=>entry.Feat);
      for(const id of beforeFeats)if(!afterFeats.includes(id))removeNativeFeat(object,id);
      for(const id of afterFeats)if(!beforeFeats.includes(id))addNativeFeat(object,id,this.characterRules,this.combat.featProviders(object));
    }
    this.refreshCombat(object);
    if (result.delta && (object.isPC || object.kind === 'player')) this.onMessage({ type: 'xp', id: object.id, amount: result.delta,
      text: `Experience ${result.delta > 0 ? 'gained' : 'lost'}: ${Math.abs(result.delta)}` });
    if (result.changes.length) this.onMessage({ type: 'level', id: object.id, level: stats.level,
      amount: result.changes.reduce((n, d) => n + d, 0), text: `Character level: ${stats.level}` });
  }
  giveExperience(id, amount) {
    const object = this.registry.get(id);
    if (object?.objectType !== 5 || (amount | 0) <= 0 || object.isDM || object.associateType) return;
    const stats = this.creatureStats(id);
    const award = experienceAward(stats, amount, this.characterRules);
    this.changeExperience(object, (stats.xp + award) >>> 0);
  }
  async program(name) {
    const key = name.toLowerCase();
    if (!this.programs.has(key)) this.programs.set(key, this.resolver.getResource(key, RESOURCE_TYPE.NCS).then(bytes => parseNcs(bytes, key)));
    return this.programs.get(key);
  }
  queueScript(name, selfId, eventObjects = {}) {
    if (name) this.scheduler.enqueue(selfId, { type: 'script', name, eventObjects });
  }
  async dispatch({ targetId, event }) {
    const target = this.registry.get(targetId);
    if (event.type === 'situation') await this.vm.run(event.situation.program, targetId, { situation: event.situation });
    else if (event.type === 'script') {
      Object.assign(target.eventObjects, event.eventObjects);
      if (Object.hasOwn(event.eventObjects, 'damager')) target.lastDamagerId = event.eventObjects.damager;
      if (event.name) await this.vm.run(await this.program(event.name), targetId);
    } else if (event.type === 'nativeSubareaScript') await dispatchSubareaEvent(target, event.eventId, event.payload, {
      runScript: async (object, index) => {
        const name = object.scripts?.[index === (object.objectType === 7 ? 1 : 0) ? 'enter' : 'exit'];
        if (name) await this.vm.run(await this.program(name), object.id);
      },
      // Native encounter activation/removal and trap owners have not yet been
      // reconstructed. Required-provider failures are persisted by scheduler.
    });
    else if (event.type === 'removeEffect') await this.effects.remove(targetId, event.effectId);
    else if (event.type === 'combatAI') await this.combat.dispatchEvent(target, event);
    else if (event.type === 'playSound') {
      const listener = this.player;
      if (listener?.areaId === target.areaId && nativeDistanceSquared(listener.position, target.position) <= 400) {
        await this.onSound({ objectId: target.id, resRef: event.resRef, position: [...target.position], listenerId: listener.id });
      }
    } else if (event.type === 'jump') await this.jump(target, event.destinationId, event.walkStraight);
    else if (event.type === 'talk') await this.talk(target, this.registry.get(event.playerId), event.resRef);
    else if (event.type === 'use') {
      const player = this.registry.get(event.playerId);
      if (player?.areaId !== target.areaId || !target.usable) return;
      target.lastUsedBy = player.id;
      if (target.scripts?.used) await this.vm.run(await this.program(target.scripts.used), target.id);
    }
    else if (event.type === 'dialogReply') await this.conversation.choose(event.ordinal, event.version);
    else if (event.type === 'dialogClose') { if (event.version === this.conversation.version) await this.conversation.finish(event.aborted); }
  }
  async enterArea(resRef, spawn) {
    const next = this.areas.get(resRef); if (!next) throw new Error(`Unknown area ${resRef}`);
    const initialEntry = !this.started;
    const previous = this.currentArea;
    if (previous && previous !== next) {
      if (this.conversation.state) await this.conversation.finish(true);
      this.leaveTriggers(this.player);
      // Exit scripts must observe membership in the old area, even when this
      // transfer itself is dispatched by the scheduler's active pump.
      previous.eventObjects.exiting = this.player.id;
      if (previous.scripts.exit) {
        try { await this.vm.run(await this.program(previous.scripts.exit), previous.id); }
        catch (error) { this.report(error); }
      }
    }
    if (previous && previous !== next) {
      previous.objects = previous.objects.filter(id => id !== this.player.id);
      previous.nativeSpatial?.remove(this.player.id);
      if(previous.nativePlayerCount150!==undefined)previous.nativePlayerCount150=(previous.nativePlayerCount150-1)|0;
      this.player.nativeSubareaMembership.setSize(0);
    }
    this.currentArea = next; this.player.areaId = next.id; this.player.position = spawn;
    this.refreshCombat(this.player);
    next.objects ??= [];
    if (!next.objects.includes(this.player.id)) next.objects.push(this.player.id);
    next.nativeSpatial?.insert(this.player.id);
    if(previous!==next&&next.nativePlayerCount150!==undefined){
      // AddObjectToArea14035bbe9..14035bd44: first actual controlled
      // creature activates level0 creatures; IDs stay in persistent arrays.
      if(next.nativePlayerCount150===0)for(const id of next.nativeSpatial?.view()??[]){const object=this.registry.get(id);if(object?.objectType===5&&object.nativeAILevel7c===0)this.aiMaster.setLevel(object,1);}
      next.nativePlayerCount150=(next.nativePlayerCount150+1)|0;
    }
    if (!this.started) {
      this.started = true;
      if (this.runStartupScripts) {
        this.queueScript(this.ifo.Mod_OnModLoad, this.module.id);
        this.queueScript(this.ifo.Mod_OnModStart, this.module.id);
        this.queueScript(this.ifo.Mod_OnClientEntr, this.module.id, { entering: this.player.id });
      } else this.onMessage({ type: 'testing', text: 'Testing: module startup and initial area-entry scripts disabled for this session.' });
    }
    if (previous !== next && (!initialEntry || this.runStartupScripts)) this.queueScript(next.scripts.enter, next.id, { entering: this.player.id });
    if (previous !== next) this.updateTriggers(this.player);
  }
  isDead(object) {
    const hp = object?.stats || [9, 10].includes(object?.objectType) ? this.hitPoints(object.id, false) : object?.authored?.CurrentHitPoints;
    if (hp === undefined) { if (!object || object.kind === 'player' && !object.characterLoaded) return false; throw new Error('Dead-state HP provider is unavailable'); }
    return hp < (object.isPC || object.isPossessedFamiliar ? -9 : 1);
  }
  setPosition(object, point, flag = 0) {
    try { return setObjectPosition(object, point, flag, {
      area: actor => this.registry.get(actor.areaId) ?? null,
      update: (area, actor) => {
        if (!area.nativeSpatial) throw new Error('Native area spatial array is unavailable');
        return area.nativeSpatial.update(actor);
      },
    }); } catch (error) { this.report(error, { ...this.diagnosticContext(object.id), operation: 'native-object-set-position' }); throw error; }
  }
  updatePositionArray(object) {
    // Preview controller shares the canonical position array and mutates it
    // before this call. Maintain native ordering; subarea behavior is separate.
    try {
      const area = this.registry.get(object.areaId);
      if (area?.nativeSpatial) area.nativeSpatial.update(object);
    } catch (error) { this.report(error, { ...this.diagnosticContext(object.id), operation: 'native-area-spatial-update' }); throw error; }
  }
  isDying(object) {
    const hp = object?.stats ? this.hitPoints(object.id, false) : object?.authored?.CurrentHitPoints;
    return Boolean((object?.isPC || object?.isPossessedFamiliar) && hp <= 0 && hp > -10);
  }
  initializeReputationState(object, data, importIds) {
    object.reputationPCFlag = Number(Boolean(object.isPC));
    if (object.reputationPCFlag && !object.reputationInitialized) {
      if (!this.factionTable) throw new Error('Native faction table is unavailable');
      object.factionId = this.nextFactionId++; object.originalFactionId = object.factionId;
    } else object.originalFactionId ??= object.factionId;
    object.factionReputation = Array.isArray(data.ReputationList)
      ? data.ReputationList.map(entry => (entry.Amount ?? 0) | 0)
      : object.reputationPCFlag ? this.factionTable.defaultPC() : null;
    object.personalReputationList = (data.PersonalRepList ?? []).map(entry => {
      const stored = (entry.ObjectId ?? OBJECT_INVALID) >>> 0;
      // Saved/imported references cannot become live IDs by coincidence.
      const mapped = importIds?.get(stored) ?? OBJECT_INVALID;
      if (stored !== OBJECT_INVALID && mapped === OBJECT_INVALID) runtimeDiagnostics.record('reputation.reference-unavailable',
        'Saved personal reputation target could not be mapped into the live session', { ...this.diagnosticContext(object.id), storedObjectId: stored });
      return { day: (entry.Day ?? 0) >>> 0, time: (entry.Time ?? 0) >>> 0, objectId: mapped,
        amount: (entry.Amount ?? 0) | 0, decays: Number(Boolean((entry.Decays ?? 0) & 255)), duration: (entry.Duration ?? 0) | 0 };
    });
    // LoadPersonalReputationList 140398170 grows from zero to sixteen,
    // then doubles. Retain allocation capacity independently of list length.
    object.personalReputationCapacity=0;
    for(let count=0;count<object.personalReputationList.length;count++)
      if(count===object.personalReputationCapacity)object.personalReputationCapacity=count===0?16:count*2;
    object.reputationInitialized = true;
  }
  getPVPSetting(area) {
    // Native area zero produces zero for every server setting. Other values
    // require the actual configured server value; do not invent one.
    if (area.pvpSetting === 0) return 0;
    return effectivePVPSetting(area.pvpSetting, this.serverPvpSetting);
  }
  reputationProviders() {
    return { table: this.factionTable, object: id => this.registry.get(id) ?? null,
      creature: id => this.registry.get(id)?.objectType === 5 ? this.registry.get(id) : null,
      faction: object => {
        if (![5, 7, 9, 10, 13].includes(object.objectType)) return null;
        if (!Number.isInteger(object.factionId)) throw new Error('Native object faction is unavailable');
        return object.factionId;
      },
      area: object => this.registry.get(object.areaId) ?? null, pvp: area => this.getPVPSetting(area),
      elapsed: entry => {
        return subtractWorldTimes(this.worldTimer.time(), entry, this.worldTimer.dayLength);
      }, warning: message => runtimeDiagnostics.record('combat.reputation-warning', message) };
  }
  reputation(subject, reference) {
    if (!subject || !reference) return 0;
    try { return objectReputation(subject, reference.id, 0, this.reputationProviders()).reputation; }
    catch (error) { this.report(error, this.diagnosticContext(subject.id)); throw error; }
  }
  aiReaction(actor, targetId) {
    try { return aiStateReaction(actor, targetId, this.reputationProviders()); }
    catch (error) { this.report(error, this.diagnosticContext(actor.id)); throw error; }
  }
  nearestCreature(args, location = false) {
    const [type, value, target, nth = 1, type2 = -1, value2 = -1, type3 = -1, value3 = -1] = args;
    const object = location ? target && { ...target, position: [target.position[0], target.position[2], -target.position[1]] } : this.registry.get(target);
    return nearestObjects(this, object, nth, creatureCriteria(this, object ?? {}, [[type, value], [type2, value2], [type3, value3]]), location ? OBJECT_INVALID : target);
  }
  setCutscene(id, mode, leftClicks = 0) {
    const object = this.registry.get(id);
    if (!object || !object.isPC && !object.isPossessedFamiliar) return;
    const enabled = mode === 1;
    if (enabled) { if (!object.cutscene?.enabled) object.savedCutscenePlot = Boolean(object.plot); object.plot = true; }
    else object.plot = object.savedCutscenePlot ?? Boolean(object.plot);
    object.cutscene = { enabled, leftClicks: Boolean(leftClicks), rawMode: mode };
    this.onCutscene(object, enabled);
  }
  updateTriggers(actor) {
    const area = this.registry.get(actor.areaId), previous = this.triggerMembers.get(actor.id) ?? new Set(), next = new Set();
    for (const id of area?.objects ?? []) {
      const trigger = this.registry.get(id);
      if (trigger?.kind !== 'trigger' || !inTrigger(trigger, actor.position)) continue;
      next.add(id);
      if (!previous.has(id)) this.queueScript(trigger.scripts.enter, id, { entering: actor.id });
    }
    for (const id of previous) if (!next.has(id)) this.queueScript(this.registry.get(id)?.scripts.exit, id, { exiting: actor.id });
    this.triggerMembers.set(actor.id, next);
    // The preview controller still has its own trigger polling owner. Bridge
    // its membership into native combat movement so switching owners cannot
    // publish the same ordinary trigger entry twice. This is not native
    // JumpToLocation or initial subarea activation (encounters/AOEs remain separate).
    if (area?.nativeSubareas && actor.nativeSubareaMembership) {
      const membership = new NativeIdList();
      for (const id of area.nativeSubareas.view()) {
        const object = this.registry.get(id);
        if (object?.objectType === 7 ? next.has(id) : actor.nativeSubareaMembership.indexOf(id) >= 0) membership.append(id);
      }
      actor.nativeSubareaMembership.copyFrom(membership);
    }
  }
  async updateSubareasOnMove(actor, from, to, useProvided = 0, provided = null, transitionFlag = 0, providers = {}) {
    try {
      const changed = await updateSubareasOnMove(actor, from, to, useProvided, provided, transitionFlag, {
        area: object => this.registry.get(object.areaId), object: id => this.registry.get(id),
        aoe: id => { const o = this.registry.get(id); return o?.objectType === 11 ? o : null; },
        inTrigger: (object, point) => Number(inTrigger(object, point)),
        inEncounter: (object, point) => Number(inTrigger(object, point)),
        lineTrigger: (object, start, end) => intersectSubareaPolygon(object, start, end, Boolean(this.registry.get(object.areaId))),
        lineEncounter: (object, start, end) => intersectSubareaPolygon(object, start, end, Boolean(this.registry.get(object.areaId))),
        dm: object => Number((object.associateType & 65535) === 0 && Boolean(this.combat.broadcastProviders().client(object.id)) && Boolean(object.isDM)),
        event: (_code, callerId, targetId, payload) => this.scheduler.enqueue(targetId, { type: 'nativeSubareaScript', eventId: 10, callerId, payload }),
        warning: message => this.report(new Error(message), this.diagnosticContext(actor.id)), ...providers,
      });
      if (changed) this.triggerMembers.set(actor.id, new Set([...actor.nativeSubareaMembership.view()].filter(id => this.registry.get(id)?.objectType === 7)));
      return changed;
    } catch (error) { this.report(error, { ...this.diagnosticContext(actor.id), operation: 'native-subarea-movement' }); throw error; }
  }
  leaveTriggers(actor) {
    for (const id of this.triggerMembers.get(actor.id) ?? []) this.queueScript(this.registry.get(id)?.scripts.exit, id, { exiting: actor.id });
    this.triggerMembers.delete(actor.id);
  }
  requestTalk(targetId, playerId = this.player.id, resRef = '') {
    const target = this.registry.get(targetId), player = this.registry.get(playerId);
    if (!target || !player || target.areaId !== player.areaId || this.conversation.state) return false;
    this.scheduler.enqueue(targetId, { type: 'talk', playerId, resRef }); return true;
  }
  talkRange(actor, target) { return creatureTalkRange(actor, target, this.appearances); }
  async talk(owner, player, resRef = '') {
    if (!owner || !player?.isPC || owner.areaId !== player.areaId || this.conversation.state) return false;
    owner.lastSpeakerId = player.id; owner.listenPatternNumber = -1;
    if (owner.scripts?.dialogue) {
      owner.requestedDialog = resRef;
      try { await this.vm.run(await this.program(owner.scripts.dialogue), owner.id); return Boolean(this.conversation.state); }
      finally { owner.requestedDialog = ''; }
    }
    return this.conversation.start(owner, player, resRef);
  }
  transitionTarget(door) {
    if (!door) return undefined;
    const cached = this.registry.get(door.linkedTargetId);
    if (cached && !['area', 'module'].includes(cached.kind)) return cached;
    if (!door.linkedToFlags || door.linkedToModule) return undefined;
    const result = this.byTag(door.linkedTo, 'waypoint')[0] ?? this.byTag(door.linkedTo, 'door')[0] ?? this.byTag(door.linkedTo).find(object => !['area', 'module'].includes(object.kind));
    door.linkedTargetId = result?.id ?? OBJECT_INVALID;
    return result;
  }
  doorEvent(door, actor, event) {
    if (event.type === 'door.clicked') {
      door.eventObjects.clicking = actor.id; door.eventObjects.entering = actor.id;
      if (door.linkedToModule) { this.report(new Error('Inter-module traversal is not implemented')); return; }
      this.queueScript(event.script && event.script !== 'default' ? event.script : 'nw_g0_transition', door.id, { clicking: actor.id, entering: actor.id });
    } else if (event.type === 'door.stateChanged') {
      const key = event.state ? 'opened' : 'closed'; door.eventObjects[key] = actor.id;
      door.lastUsedBy = actor.id;
      const other = this.transitionTarget(door);
      if (other?.kind === 'door') { const previous = other.animationState; other.animationState = event.state; this.onDoorState(other, previous); }
      this.queueScript(event.script, door.id, { [key]: actor.id });
    } else if (event.type === 'door.failedToOpen') this.queueScript(event.script, door.id);
  }
  async jump(actor, destinationId, walkStraight) {
    const destination = this.registry.get(destinationId);
    if (!destination || !['player', 'creature'].includes(actor.kind)) return;
    if (actor !== this.player) throw new Error('NPC scripted jumps are not implemented');
    if (!this.onTransition) throw new Error('No area transition adapter');
    this.transitioning = true;
    try { await this.onTransition({ actor, destination, walkStraight }); }
    finally { this.transitioning = false; }
  }
  local(id, name, type) { return this.registry.get(id)?.locals.get(name, type) ?? (type === 'string' ? '' : type === 'object' ? OBJECT_INVALID : type === 'location' ? null : 0); }
  commands = {
    Random: ([maximum]) => this.random.random(maximum),
    d2: ([count = 1]) => this.random.scriptDice(count, 2),
    d3: ([count = 1]) => this.random.scriptDice(count, 3),
    d4: ([count = 1]) => this.random.scriptDice(count, 4),
    d6: ([count = 1]) => this.random.scriptDice(count, 6),
    d8: ([count = 1]) => this.random.scriptDice(count, 8),
    d10: ([count = 1]) => this.random.scriptDice(count, 10),
    d12: ([count = 1]) => this.random.scriptDice(count, 12),
    d20: ([count = 1]) => this.random.scriptDice(count, 20),
    d100: ([count = 1]) => this.random.scriptDice(count, 100),
    AssignCommand: ([subject, situation]) => { if (this.registry.get(subject)) this.scheduler.enqueue(subject, { type: 'situation', situation }); },
    DelayCommand: ([seconds, situation], f) => { if (this.registry.get(f.self)) this.scheduler.enqueue(f.self, { type: 'situation', situation }, seconds); },
    ExecuteScript: async ([name, target], f) => { target ??= f.self; if (this.registry.get(target)) await this.vm.run(await this.program(name), target, { budget: f.budget, depth: f.depth + 1 }); },
    GetIsObjectValid: ([id]) => Number(Boolean(this.registry.get(id))),
    GetObjectType: ([id]) => scriptTypes[this.registry.get(id)?.kind] ?? 32767,
    GetModule: () => this.module.id,
    GetArea: ([id]) => this.registry.get(id)?.areaId ?? OBJECT_INVALID,
    GetTag: ([id]) => this.registry.get(id)?.tag ?? '',
    GetName: ([id]) => this.registry.get(id)?.name ?? '',
    GetPCPlayerName: ([id]) => this.registry.get(id)?.playerName ?? '',
    GetObjectByTag: ([tag, ordinal = 0]) => this.byTag(tag)[ordinal]?.id ?? OBJECT_INVALID,
    GetWaypointByTag: ([tag]) => this.byTag(tag, 'waypoint')[0]?.id ?? OBJECT_INVALID,
    GetTransitionTarget: ([id]) => this.transitionTarget(this.registry.get(id))?.id ?? OBJECT_INVALID,
    GetEnteringObject: (_, f) => this.registry.get(f.self)?.eventObjects.entering ?? OBJECT_INVALID,
    GetExitingObject: (_, f) => this.registry.get(f.self)?.eventObjects.exiting ?? OBJECT_INVALID,
    GetClickingObject: (_, f) => this.registry.get(f.self)?.eventObjects.clicking ?? OBJECT_INVALID,
    GetLastOpenedBy: (_, f) => this.registry.get(f.self)?.eventObjects.opened ?? OBJECT_INVALID,
    GetLastClosedBy: (_, f) => this.registry.get(f.self)?.eventObjects.closed ?? OBJECT_INVALID,
    GetLastUsedBy: (_, f) => this.registry.get(f.self)?.lastUsedBy ?? OBJECT_INVALID,
    GetIsPC: ([id]) => Number(Boolean(this.registry.get(id)?.isPC)),
    GetIsDM: ([id]) => Number(Boolean(this.registry.get(id)?.isDM)),
    GetIsPossessedFamiliar: ([id]) => Number(Boolean(this.registry.get(id)?.isPossessedFamiliar)),
    GetAILevel: ([id]) => this.registry.get(id)?.objectType===5?this.registry.get(id).nativeAILevel7c:0,
    SetAILevel: ([id,level]) => scriptSetAILevel(this.registry.get(id)?.objectType===5?this.registry.get(id):null,level,{
      master:this.aiMaster,possessed:o=>Number(Boolean(o.isPossessedFamiliar)),area:o=>this.registry.get(o.areaId)??null,
      creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;}}),
    GetReputation: ([sourceId, targetId]) => {
      const target = this.registry.get(targetId);
      return target?.objectType > 4 ? objectReputation(target, sourceId, 0, this.reputationProviders()).reputation : -1;
    },
    GetNearestCreature: args => this.nearestCreature(args),
    GetNearestCreatureToLocation: args => this.nearestCreature(args, true),
    GetNearestObject: ([mask = 32767, id, nth = 1]) => nearestObjects(this, this.registry.get(id), nth, o => Boolean((scriptTypes[o.kind] ?? 0) & mask) && !o.isDM, id),
    GetNearestObjectByTag: ([tag, id, nth = 1]) => nearestObjects(this, this.registry.get(id), nth, o => String(o.tag ?? '').slice(0, 64) === String(tag).slice(0, 64), id),
    GetIsDead: ([id]) => Number(this.isDead(this.registry.get(id))),
    GetIsInTrigger: ([triggerId, objectId]) => { const t = this.registry.get(triggerId), o = this.registry.get(objectId); return Number(t?.kind === 'trigger' && o?.areaId === t.areaId && inTrigger(t, o.position)); },
    GetObjectSeen: ([id, observerId]) => { const observer = this.registry.get(observerId); return observer?.objectType === 5 ? (observer.perception?.get(id) ?? 0) & 1 : 0; },
    GetObjectHeard: ([id, observerId]) => { const observer = this.registry.get(observerId); return observer?.objectType === 5 ? ((observer.perception?.get(id) ?? 0) >>> 1) & 1 : 0; },
    GetLastPerceived: (args,{self})=>this.registry.get(self)?.objectType===5?this.registry.get(self).nativeLastPerceived79c:OBJECT_INVALID,
    GetLastPerceptionHeard: (args,{self})=>this.registry.get(self)?.objectType===5?this.registry.get(self).nativePerceptionHeard7a0:0,
    GetLastPerceptionInaudible: (args,{self})=>this.registry.get(self)?.objectType===5?this.registry.get(self).nativePerceptionInaudible7a8:0,
    GetLastPerceptionSeen: (args,{self})=>this.registry.get(self)?.objectType===5?this.registry.get(self).nativePerceptionSeen7a4:0,
    GetLastPerceptionVanished: (args,{self})=>this.registry.get(self)?.objectType===5?this.registry.get(self).nativePerceptionVanished7ac:0,
    SetCutsceneMode: ([id, mode = 1, leftClicks = 0]) => this.setCutscene(id, mode, leftClicks),
    GetCutsceneMode: ([id]) => this.registry.get(id)?.cutscene?.rawMode ?? 0,
    GetPlotFlag: ([id]) => Number(Boolean(this.registry.get(id)?.plot)),
    SetPlotFlag: ([id, value]) => { const o = this.registry.get(id); if (o) o.plot = Boolean(value); },
    GetPCSpeaker: (_, f) => this.registry.get(f.self)?.conversation?.playerId ?? OBJECT_INVALID,
    GetLastSpeaker: (_, f) => this.registry.get(f.self)?.lastSpeakerId ?? OBJECT_INVALID,
    GetAttemptedAttackTarget: (_, f) => { const o = this.registry.get(f.self); return o?.objectType === 5 ? o.attemptedAttackTargetId ?? OBJECT_INVALID : OBJECT_INVALID; },
    GetAttemptedSpellTarget: (_, f) => { const o = this.registry.get(f.self); return o?.objectType === 5 ? o.attemptedSpellTargetId ?? OBJECT_INVALID : OBJECT_INVALID; },
    GetLastAttacker: ([id]) => this.registry.get(id)?.lastAttackerId ?? OBJECT_INVALID,
    GetLastAttackMode: ([id]) => scriptLastAttackMode(this.registry.get(id)),
    GetLastAttackType: ([id]) => scriptLastAttackType(this.registry.get(id)),
    GetLastWeaponUsed: ([id]) => this.registry.get(id)?.objectType === 5 ? this.registry.get(id).lastWeaponUsedId : OBJECT_INVALID,
    // ExecuteCommandGetAttackTarget14051f500 reads +724, not the separate
    // +738 associate-command target used by AddAttackActions/EndCombatRound.
    GetAttackTarget: ([id]) => { const o = this.registry.get(id); return o?.objectType === 5 ? o.nativeAttackTarget724 : OBJECT_INVALID; },
    GetLastDamager: ([id], f) => this.registry.get(id ?? f.self)?.lastDamagerId ?? OBJECT_INVALID,
    GetLastKiller: (_, f) => this.registry.get(f.self)?.lastKillerId ?? OBJECT_INVALID,
    GetLastHostileActor: ([id], f) => this.damage.lastHostile(this.registry.get(id ?? f.self)),
    GetMaster: ([id]) => {
      const object = this.registry.get(id);
      if (object?.objectType !== 5) return OBJECT_INVALID;
      // ExecuteCommandGetMaster reads +0x8fc directly; it does not resolve or
      // invalidate the referenced master. Ownership mutation is still pending.
      const master = object.masterId ?? OBJECT_INVALID;
      if (master !== OBJECT_INVALID && ((object.associateType ?? 0) << 16 >> 16) === 0)
        runtimeDiagnostics.record('object.associate-inconsistent', 'Creature has a master but ASSOCIATE_TYPE_NONE',
          { ...this.diagnosticContext(object.id), masterId: master });
      return master;
    },
    GetDamageDealtByType: ([flags], f) => this.damage.amountByType(this.registry.get(f.self), flags),
    GetTotalDamageDealt: (_, f) => this.damage.total(this.registry.get(f.self)),
    // ExecuteCommandModuleAccess reads distinct module fields, regardless of self.
    GetLastPlayerDying: () => this.module?.eventObjects.dying ?? OBJECT_INVALID,
    GetLastPlayerDied: () => this.module?.eventObjects.died ?? OBJECT_INVALID,
    GetGameDifficulty: () => this.difficultyLevel,
    GetSkillRank: ([skill, id, baseOnly = 0], f) => {
      const object = this.registry.get(id ?? f.self);
      if (object?.objectType !== 5) return -1;
      return baseOnly!==0?skillRank(object, skill, this.characterRules, true):this.combat.skill(object,skill,null,0);
    },
    GetAlignmentGoodEvil: ([id]) => { const o = this.registry.get(id); return o?.objectType === 5 ? creatureAlignment(creatureRoot(o)).goodEvil : -1; },
    GetAlignmentLawChaos: ([id]) => { const o = this.registry.get(id); return o?.objectType === 5 ? creatureAlignment(creatureRoot(o)).lawChaos : -1; },
    GetIsTrapped: ([id]) => { const o = this.registry.get(id); return ['trigger', 'placeable', 'door'].includes(o?.kind) ? (o.trapped ?? o.authored?.TrapFlag ?? 0) | 0 : 0; },
    IsInConversation: ([id]) => Number(this.registry.get(id)?.dialogOwnerId !== undefined && this.registry.get(id)?.dialogOwnerId !== OBJECT_INVALID),
    BeginConversation: async ([resRef = '', id = OBJECT_INVALID], f) => {
      const self = this.registry.get(f.self), target = this.registry.get(id === OBJECT_INVALID ? self?.lastSpeakerId : id);
      if (!self || !target) return 0;
      return Number(await this.conversation.start(target.isPC ? self : target, target.isPC ? target : self, resRef || self.requestedDialog, f));
    },
    ActionStartConversation: ([id, resRef = ''], f) => {
      const self = this.registry.get(f.self), target = this.registry.get(id);
      if (self?.isPC) this.requestTalk(id, self.id, resRef);
      else if (target?.isPC) this.requestTalk(f.self, id, resRef);
    },
    GetListenPatternNumber: (_, f) => this.registry.get(f.self)?.listenPatternNumber ?? -1,
    GetCommandable: ([id]) => Number(this.registry.get(id)?.objectType === 5 && this.registry.get(id)?.commandable !== false),
    GetCurrentAction: ([id]) => this.registry.get(id)?.currentActionId ?? 65535,
    // ExecuteCommandAttack 140510e80. The script requests
    // attack actions; it does not directly roll or subtract hit points.
    ActionAttack: async ([id,passive=0],f) => {
      const actor=this.registry.get(f.self);
      if(actor?.objectType===5&&Number(actor.commandable)!==0)
        await this.combat.requestAttack(actor,id,passive,0,0);
    },
    ClearAllActions: async ([clearCombat=0,id], f) => {
      // ExecuteCommandClearAllActions 140511df0..140511f67. The optional
      // object defaults to OBJECT_SELF; +738 is deliberately retained.
      const object=this.registry.get(id===undefined?f.self:id);
      if(!object||object.objectType<=4)return;
      if(object.objectType!==5)this.combat.unsupported(object,'Native noncreature ClearAllActions is not implemented');
      await this.combat.clearActions(object);
      this.combat.setLock(object,OBJECT_INVALID);
      object.attackActionTargetId=object.nativeAttackTarget724=object.spellActionTargetId=OBJECT_INVALID;
      if(clearCombat!==0)this.combat.setCombatState(object,0);
      this.scheduler.events=this.scheduler.events.filter(e=>e.targetId!==object.id||!['talk','jump','playSound'].includes(e.event.type));
      this.onClearActions(object.id);
    },
    EffectHeal: ([amount], f) => this.effects.create((amount | 0) > 0 ? 39 : 0, f.self, [amount | 0], 8),
    EffectDamage: ([amount, flags = 3, power = 0], f) => this.effects.create(38, f.self,
      damageEffectIntegers(amount, flags, power, this.characterRules?.damagetypes?.orderedRows?.length), 8),
    EffectDamageIncrease: ([cost, flags = 8], f) => this.effects.create(13, f.self, damageBonusEffectIntegers(cost, flags, this.characterRules), 8),
    EffectDamageDecrease: ([cost, flags = 8], f) => this.effects.create(14, f.self, damageBonusEffectIntegers(cost, flags, this.characterRules), 8),
    EffectTemporaryHitpoints: ([amount], f) => this.effects.create((amount | 0) > 0 ? 15 : 0, f.self, [amount | 0], 8),
    EffectDamageResistance: ([flags, amount, limit = 0, rangedOnly = 0], f) => this.effects.create(2, f.self,
      damageResistanceEffectIntegers(flags, amount, limit, rangedOnly, this.characterRules?.damagetypes?.orderedRows?.length), 8),
    EffectDamageReduction: ([amount, power, limit = 0, rangedOnly = 0], f) => this.effects.create(12, f.self,
      damageReductionEffectIntegers(amount, power, limit, rangedOnly), 8),
    EffectDamageImmunityIncrease: ([flags, amount], f) => this.effects.create(16, f.self,
      damageImmunityEffectIntegers(flags, amount, true, this.characterRules?.damagetypes?.orderedRows?.length), 8),
    EffectDamageImmunityDecrease: ([flags, amount], f) => this.effects.create(17, f.self,
      damageImmunityEffectIntegers(flags, amount, false, this.characterRules?.damagetypes?.orderedRows?.length), 8),
    EffectCutsceneGhost: (_, f) => this.effects.create(93, f.self),
    EffectACIncrease: ([amount, category = 0, damage = 4103], f) => this.effects.create(48, f.self, [category < 0 || category > 4 ? 0 : category | 0, amount | 0, 28, 0, 0, damage | 0], 8),
    EffectSavingThrowIncrease: ([save, amount, saveType = 0], f) => this.effects.create(26, f.self, [amount | 0, (save >>> 0) > 3 ? 0 : save | 0, saveType | 0, 28, 0, 0], 8),
    EffectAttackIncrease: ([amount, hand = 0], f) => this.effects.create(10, f.self, [amount | 0, hand < 0 || hand > 7 ? 0 : hand | 0, 28, 0, 0], 8),
    EffectACDecrease: ([amount, category = 0, damage = 4103], f) => this.effects.create(49, f.self, [category < 0 || category > 4 ? 0 : category | 0, amount | 0, 28, 0, 0, damage | 0], 8),
    EffectSavingThrowDecrease: ([save, amount, saveType = 0], f) => this.effects.create(27, f.self, [amount | 0, (save >>> 0) > 3 ? 0 : save | 0, saveType | 0, 28, 0, 0], 8),
    EffectSkillIncrease: ([skill,amount], f) => this.skillEffect(55,skill,amount,f.self),
    EffectSkillDecrease: ([skill,amount], f) => this.skillEffect(56,skill,amount,f.self),
    EffectAttackDecrease: ([amount, hand = 0], f) => this.effects.create(11, f.self, [amount | 0, hand < 0 || hand > 7 ? 0 : hand | 0, 28, 0, 0], 8),
    EffectImmunity: ([category], f) => this.effects.create(22, f.self, [category < 0 || category > 33 ? 0 : category | 0, 28, 0, 0], 8),
    ApplyEffectToObject: ([duration, effect, id, seconds = 0], f) => this.effects.apply(duration, effect, id, seconds, f),
    RemoveEffect: ([id, effect], f) => this.effects.requestRemoval(id, effect, f.self),
    GetFirstEffect: ([id]) => this.effects.enumerate(id, true),
    GetNextEffect: ([id]) => this.effects.enumerate(id),
    GetIsEffectValid: ([effect]) => this.effects.valid(effect),
    GetEffectType: ([effect, all = 0]) => ({ 2: 1, 12: 7, 93: 83, 10: 40, 11: 41, 13: 42, 14: 43, 15: 9, 16: 44, 17: 45, 22: 15, 26: 50, 27: 51, 48: 46, 49: 47, 55:54, 56:55 })[effect?.type] ?? (all ? ({ 38: 93, 39: 96 })[effect?.type] ?? 0 : 0),
    GetEffectCreator: ([effect]) => effect?.creatorId ?? OBJECT_INVALID,
    GetEffectDurationType: ([effect]) => effect?.durationType ?? 0,
    GetEffectSubType: ([effect]) => effect?.subtype ?? 0,
    GetEffectSpellId: ([effect]) => effect?.spellId ?? -1,
    GetItemPossessedBy: ([id, tag]) => (this.registry.get(id)?.inventory ?? []).map(i => this.registry.get(i)).find(i => i.tag === tag)?.id ?? OBJECT_INVALID,
    GetGender: ([id]) => this.registry.get(id)?.stats?.gender ?? this.registry.get(id)?.authored?.Gender ?? 2,
    GetHasFeat: ([feat, id, ignoreUses=0]) => {
      const o=this.registry.get(id);if(o?.objectType!==5)return 0;
      const highest=this.combat.highestFeat(o,feat);
      return this.combat.hasFeat(o,highest)===0?0:ignoreUses!==0?1:Number(this.combat.remainingUses(o,highest)!==0);
    },
    GetFeatRemainingUses: ([feat,id])=>{
      const o=this.registry.get(id);if(o?.objectType!==5)return 0;
      const highest=this.combat.highestFeat(o,feat);if(this.combat.hasFeat(o,highest)===0)return 0;
      const uses=this.combat.remainingUses(o,highest);return uses===100?2147483647:uses;
    },
    DecrementRemainingFeatUses: ([id,feat])=>{
      const o=this.registry.get(id);if(o?.objectType!==5||!o.stats)return;
      const highest=this.combat.highestFeat(o,feat);
      if(highest!==65535&&this.combat.hasFeat(o,highest)!==0&&this.combat.remainingUses(o,highest)!==0)this.combat.decrementUses(o,highest);
    },
    IncrementRemainingFeatUses: ([id,feat])=>{
      const o=this.registry.get(id);if(o?.objectType!==5||!o.stats||this.combat.hasFeat(o,feat)===0)return;
      const highest=this.combat.highestFeat(o,feat);
      if(!o.featUsePool)throw new Error('Native feat-use pool is unavailable');o.featUsePool.increment(highest);
    },
    GetHasSpell: ([spell, id]) => {
      const o = this.registry.get(id); if (o?.objectType !== 5) return 0;
      const data = o.creatureData ?? o.authored;
      if ((data?.ClassList ?? []).some(c => {
        const row = this.characterRules?.classes.rows.get(c.Class);
        return row?.SpellCaster === '1' && row.MemorizesSpells !== '1';
      })) throw new Error('Spontaneous remaining spell uses are not implemented');
      return (data?.ClassList ?? []).reduce((sum, c) => sum + Array.from({ length: 10 }, (_, l) => c[`MemorizedList${l}`] ?? []).flat().filter(s => s?.Spell === spell && s.Ready).length, 0);
    },
    EventUserDefined: ([number]) => ({ type: 'userDefined', number }),
    SignalEvent: ([id, event]) => { const o = this.registry.get(id); if (event.type !== 'userDefined') throw new Error('This event type is not implemented'); if (o) this.queueScript(o.scripts?.userDefined, id, { userDefined: event.number }); },
    GetUserDefinedEventNumber: (_, f) => this.registry.get(f.self)?.eventObjects.userDefined ?? 0,
    SpeakString: ([text, volume = 0], f) => this.onMessage({ type: 'speech', id: f.self, text, volume }),
    PlaySound: ([resRef], f) => {
      const object = this.registry.get(f.self);
      if (object && !['module', 'area'].includes(object.kind) && object.commandable !== false) this.scheduler.enqueue(object.id, { type: 'playSound', nativeActionId: 23, resRef });
    },
    GetXP: ([id]) => (this.creatureStats(id)?.xp ?? 0) | 0,
    SetXP: ([id, amount]) => this.setExperience(id, amount),
    GiveXPToCreature: ([id, amount]) => this.giveExperience(id, amount),
    GetRacialType: ([id]) => this.creatureStats(id)?.race ?? 28,
    GetHitDice: ([id]) => this.creatureStats(id)?.level ?? 0,
    GetBaseAttackBonus: ([id]) => {
      const stats = this.creatureStats(id);
      if (!stats) return 0;
      if (!stats.combat) throw new Error('Base attack bonus rules have not been loaded for this creature');
      return stats.combat.baseAttackBonus;
    },
    GetFortitudeSavingThrow: ([id]) => this.savingThrowStat(id, 'fortitude'),
    GetReflexSavingThrow: ([id]) => this.savingThrowStat(id, 'reflex'),
    GetWillSavingThrow: ([id]) => this.savingThrowStat(id, 'will'),
    GetAC: ([id]) => {
      const object = this.registry.get(id);
      if (!object || object.objectType < 5) return -1;
      if (object.objectType === 5) {
        const stats = this.creatureStats(id);
        if (stats.combat?.armorClass === undefined) throw new Error('Armor class rules have not been loaded for this creature');
        return stats.combat.armorClass;
      }
      return [6, 9, 10].includes(object.objectType) ? 0 : -1;
    },
    GetGold: ([id]) => {
      const object = this.registry.get(id);
      if (object?.objectType === 5) return (object.stats?.gold ?? object.authored?.Gold ?? 0) | 0;
      if (object?.kind === 'placeable') return ((object.inventory ?? []).map(i => this.registry.get(i)).find(i => i?.authored.BaseItem === 76)?.authored.StackSize ?? 0) | 0;
      return 0;
    },
    GetClassByPosition: ([index, id]) => this.creatureStats(id)?.classes[index - 1]?.id ?? (this.registry.get(id)?.objectType === 5 ? 255 : 0),
    GetLevelByPosition: ([index, id]) => this.creatureStats(id)?.classes[index - 1]?.level ?? 0,
    GetLevelByClass: ([classId, id]) => this.creatureStats(id)?.classes.find(c => c.id === classId)?.level ?? 0,
    GetCurrentHitPoints: ([id]) => this.hitPoints(id, false),
    GetMaxHitPoints: ([id]) => this.hitPoints(id, true),
    GetAbilityScore: ([id, ability, base = 0]) => {
      const stats = this.creatureStats(id); if (!stats || ability < 0 || ability > 5) return 0;
      return (base ? stats.baseAbilities : stats.equippedAbilities)[['Str', 'Dex', 'Con', 'Int', 'Wis', 'Cha'][ability]];
    },
    GetItemInSlot: ([slot, id]) => {
      const owner = this.registry.get(id); if (owner?.objectType !== 5) return OBJECT_INVALID;
      return (owner.inventory ?? []).map(item => this.registry.get(item)).find(item => item?.equipmentSlot === (1 << (slot & 31)))?.id ?? OBJECT_INVALID;
    },
    GetItemPossessor: ([id, immediate = 0]) => {
      const item = this.registry.get(id); if (item?.kind !== 'item') return OBJECT_INVALID;
      const owner = this.registry.get(item.ownerId);
      return !immediate && owner?.kind === 'item' ? owner.ownerId ?? OBJECT_INVALID : item.ownerId ?? OBJECT_INVALID;
    },
    GetPosition: ([id]) => { const p = this.registry.get(id)?.position ?? [0, 0, 0]; return [p[0], -p[2], p[1]]; },
    GetLocation: ([id]) => {
      const o = this.registry.get(id); if (!o?.position) return null;
      // Script locations use native XYZ and degrees, not renderer XZ/-Y or the
      // ARE/GIT bearing angle. Bearing zero has native facing (0,1,0).
      return { areaId: o.areaId, position: [o.position[0], -o.position[2], o.position[1]], orientation: ((90 + (o.bearing ?? 0) * 180 / Math.PI) % 360 + 360) % 360 };
    },
    GetLocalInt: ([id, name]) => this.local(id, name, 'int'),
    GetLocalFloat: ([id, name]) => this.local(id, name, 'float'),
    GetLocalString: ([id, name]) => this.local(id, name, 'string'),
    GetLocalObject: ([id, name]) => this.local(id, name, 'object'),
    GetLocalLocation: ([id, name]) => this.local(id, name, 'location'),
    SetLocalInt: ([id, name, value]) => {
      if (name.startsWith('NW_JOURNAL') && !name.startsWith('NW_JOURNAL_ENTRY')) throw new Error('Journal date/time/picture variable hooks are not implemented');
      this.registry.get(id)?.locals.setInt(name, value);
    },
    SetLocalFloat: ([id, name, value]) => this.registry.get(id)?.locals.setFloat(name, value),
    SetLocalString: ([id, name, value]) => this.registry.get(id)?.locals.setString(name, value),
    SetLocalObject: ([id, name, value]) => this.registry.get(id)?.locals.setObject(name, value),
    SetLocalLocation: ([id, name, value]) => this.registry.get(id)?.locals.setLocation(name, value),
    DeleteLocalInt: ([id, name]) => this.registry.get(id)?.locals.deleteIndex(name, 'int'),
    DeleteLocalFloat: ([id, name]) => this.registry.get(id)?.locals.deleteIndex(name, 'float'),
    DeleteLocalString: ([id, name]) => this.registry.get(id)?.locals.deleteIndex(name, 'string'),
    DeleteLocalObject: ([id, name]) => this.registry.get(id)?.locals.deleteIndex(name, 'object'),
    DeleteLocalLocation: ([id, name]) => this.registry.get(id)?.locals.deleteIndex(name, 'location'),
    SetAreaTransitionBMP: ([index, custom = '']) => { this.transitionBitmap = { index, custom }; },
    ActionJumpToObject: ([destinationId, walkStraight = 1], f) => this.scheduler.enqueue(f.self, { type: 'jump', destinationId, walkStraight }),
    JumpToObject: ([destinationId, walkStraight = 1], f) => {
      // Native adds this jump to the FRONT of the actor action queue (196
      // appends). The first slice serializes jumps; other action kinds still fail.
      const action = this.scheduler.enqueue(f.self, { type: 'jump', destinationId, walkStraight });
      const same = this.scheduler.events.findIndex(e => e !== action && e.targetId === f.self && e.event.type === 'jump' && e.due === action.due);
      if (same >= 0) { this.scheduler.events.splice(this.scheduler.events.indexOf(action), 1); this.scheduler.events.splice(same, 0, action); }
    },
    AddJournalQuestEntry: ([tag, state, id, party = 1, allPlayers = 0, override = 0]) => {
      const category = this.journalDefinitions.get(tag);
      if (!category || !category.EntryList.some(entry => entry.ID === state)) return;
      const recipient = this.registry.get(id);
      if (!recipient?.isPC) return;
      // Current session has one PC and no associates. Broad party propagation
      // must be implemented alongside party/faction membership.
      const old = recipient.journal.get(tag);
      if (old === undefined || override || state > old) recipient.journal.set(tag, state);
    },
    SendMessageToPC: ([id, text]) => { if (this.registry.get(id)?.isPC) this.onMessage({ type: 'pc', id, text }); },
    FloatingTextStringOnCreature: ([text, id, broadcast = 1]) => { if (this.registry.get(id)?.objectType === 5) this.onMessage({ type: 'floating', id, text, broadcast }); },
    SendMessageToAllDMs: ([text]) => { for (const object of this.registry.objects.values()) if (object.isDM) this.onMessage({ type: 'dm', id: object.id, text }); },
    IntToString: ([value]) => String(value)
  };
}
