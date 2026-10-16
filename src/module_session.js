import { GameObjectArray, GAME_OBJECT_TYPE, OBJECT_INVALID } from './game_object_array.js';
import {ObjectUUIDRegistry} from './object_uuid.js';
import {WorldTemplateRuntime} from './world_template_runtime.js';
import {moduleTagKey,addModuleTag,scriptObjectByTag,scriptWaypointByTag} from './module_tag_lookup.js';
import {readNativeGff} from './native_gff_fields.js';
import {nativeObjectTag} from './object_tag.js';
import {readItemGffField} from './item_gff_load.js';
import {objectTemplateResRef} from './create_object.js';
import {WorldCreationRuntime} from './world_creation_runtime.js';
import {loadCreatureTemplateData} from './creature_template.js';
import {featAbilityDeltas,computeFeatAbilityBonuses} from './feat_ability_bonuses.js';
import {addUseObjectAction,scriptInteractObject} from './use_object.js';
import { initializeCreaturePerception } from './perception_detection.js';
import { loadPerceptionRanges,postProcessPerceptionRanges } from './perception_ranges.js';
import { parseGff, getGffStructType, getGffFieldTypes, cloneGff } from './gff.js';
import { decodeResourceText, RESOURCE_TYPE } from './resource_archive.js';
import { parseNcs, parseScriptApi } from './ncs.js';
import { NwScriptVm } from './nwscript_vm.js';
import { ScriptScheduler } from './script_scheduler.js';
import { ScriptVariableTable } from './script_variables.js';
import {loadScriptVariableRows,loadScriptVariables} from './script_variable_load.js';
import { parseCharacter, loadCharacterRules, characterStats, experienceAward, resolvePlayerModels, importedObjectIds } from './character.js';
import { Conversation } from './conversation.js';
import {loadQuickbar,saveQuickbar,removeQuickbarItem} from './quickbar.js';
import {requestCameraMode} from './camera_modes.js';
import { nearestObjects, creatureCriteria,areaSpatialIds,firstAreaSpatialIndex } from './nearest_objects.js';
import { inTrigger, triggerGeometry, encounterGeometry } from './trigger_geometry.js';
import {createTriggerFacingBounds} from './facing_actions.js';
import {initializeSpellContext,scriptSpellContext,spellTargetLocation} from './spell_context.js';
import {spellStringEntry} from './spell_metadata.js';
import {spellCastAtEvent} from './spell_notification.js';
import {scriptGetIsImmune} from './effect_immunity.js';
import {abilityEffect} from './ability_effect.js';
import {versusEffect} from './versus_effect.js';
import {spellTimeConversion,scriptSavingThrow} from './script_spell_support.js';
import {constructVisualEffect,constructBeamEffect} from './visual_effect.js';
import {enumerateItemProperty,validItemProperty,itemPropertyValue,itemHasProperty,itemPropertyDurationType} from './item_property_query.js';
import {bindItemPropertyFactory} from './item_property_factory.js';
import {scriptAddItemProperty,scriptRemoveItemProperty} from './item_property_mutation.js';
import {damageShieldIntegers} from './damage_shield.js';
import { parse2da } from './area.js';
import { creatureTalkRange } from './interaction_range.js';
import { EffectRuntime } from './effect_runtime.js';
import {AreaEffectRuntime} from './area_effect_runtime.js';
import {constructAreaEffect,areaEffectCreator} from './area_effect.js';
import {invisibilityEffect} from './invisibility_effect.js';
import {concealmentEffect} from './concealment_effect.js';
import { nativeDistanceSquared } from './nearest_objects.js';
import { reconcileExperience, initializeBonusSpellSlots } from './character_progression.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { NativeRandom } from './native_random.js';
import { equipmentCombatEffects,itemArmorClass } from './combat_modifiers.js';
import { damageEffectIntegers, damageImmunityEffectIntegers, damageResistanceEffectIntegers, damageReductionEffectIntegers } from './damage_effect.js';
import { DamageRuntime } from './damage_runtime.js';
import { CombatRuntime } from './combat_runtime.js';
import { damageBonusEffectIntegers } from './damage_effect_bonus.js';
import { skillRank } from './skill_rank.js';
import { creatureCurrentHitPoints } from './creature_damage.js';
import { difficultyOption } from './difficulty.js';
import { createCombatRound,weaponAttackType } from './combat_round.js';
import { creatureRoot, creatureAlignment } from './creature_rules.js';
import { createObjectActionState } from './object_actions.js';
import { VisibilityList } from './perception.js';
import { FactionReputationTable, objectReputation, aiStateReaction, effectivePVPSetting, subtractWorldTimes } from './reputation.js';
import { scriptLastAttackMode, scriptLastAttackType } from './combat_events.js';
import { addNativeFeat, removeNativeFeat } from './feat_uses.js';
import { initializeSkillArmorPenalties, initializeClassSkillPenalties } from './skill_caches.js';
import { PathInformation } from './path_information.js';
import { WorldTimer } from './world_timer.js';
import { initializeModuleAI,initializeAreaAI,updateModule } from './module_ai.js';
import { NativeGeometryResources, NativeAreaGeometry } from './area_geometry.js';
import { NativeAreaSpatialArray, setObjectPosition } from './area_spatial.js';
import { NativeIdList } from './native_id_list.js';
import { NativeAIMaster,scriptSetAILevel } from './native_ai_master.js';
import { initializeCreatureFrame,initializeSkillTimers } from './combat_frame.js';
import { updateSubareasOnMove,updateSubareasOnJump, intersectSubareaPolygon } from './subareas.js';
import { dispatchSubareaEvent } from './subarea_events.js';
import { initialMovementFactor,loadMovementRate,nativeFloatEntry } from './movement_rate.js';
import { intEntry,rulesetInt } from './combat_stats.js';
import { initializeModuleExperience,initializeCreatureExperience } from './combat_experience.js';
import { NativeFactionManager,initializeCreatureFaction } from './faction_manager.js';
import { updatePersonalSpace } from './personal_space.js';
import { getActionMode,setActionMode } from './combat_mode.js';
import {scriptAppearanceType,scriptCreatureSize,scriptCreatureTail,importCreatureTail,scriptSubrace} from './creature_appearance_state.js';
import {setBaseAbility} from './base_ability.js';
import {constructPolymorph} from './polymorph_effect.js';
import {PolymorphRuntime} from './polymorph_runtime.js';
import {initializePolymorphState} from './polymorph_form.js';
import {updateAppearanceInfo} from './appearance_info.js';
import {receiveCancelPolymorphInput} from './combat_input.js';
import {constructTurnResistance,turnResistanceHD} from './turn_resistance.js';
import {nativeFeatSourceClass} from './spell_caster_level.js';
import {FeatRuntime} from './feat_runtime.js';
import {scriptSetDroppable,scriptGetDroppable} from './item_droppable.js';
import {initializeInventoryDisturbance,lastDisturbed,inventoryDisturbItem,inventoryDisturbType} from './inventory_disturbance.js';
import {EncounterRuntime} from './encounter_runtime.js';
import {objectInShape} from './shape_query.js';
import {scriptCos,scriptSin,scriptLog,scriptAngleToVector} from './script_scalar.js';
import {getItemBaseType} from './item_query.js';
import {inventoryItem} from './inventory_enumeration.js';
import {equipCreatureItem,unequipCreatureItem} from './equipment_mutation.js';
import {runEquip} from './equipment_actions.js';
import {runUnequip,canUnequipWeapon,scriptEquipItem,scriptUnequipItem} from './equipment_unequip.js';
import {scriptSelectWeapon,selectAmmunition,relativeWeaponSize} from './weapon_selection.js';
import {scriptLocation,scriptObjectLocation} from './script_location.js';
import {scriptGetAssociate,creatureAssociateId} from './associate_query.js';
import {getObjectLocked} from './lock_query.js';
import {scriptRandomWalk} from './random_walk.js';
import { detectMode } from './perception_detection.js';
import {addDoCommandAction} from './script_action.js';
import {PlayerEnumeration} from './player_enumeration.js';
import {scriptObjectDistance,scriptDistanceBetween,scriptDistanceBetweenLocations,scriptFacingVector} from './script_geometry.js';
import {floatingText} from './floating_text.js';
import {reflexAdjustedDamage} from './reflex_damage.js';
import {broadcastFloatyData} from './combat_broadcast.js';
import {setObjectDestroyable} from './object_lifecycle.js';
import {ObjectLifecycleRuntime} from './object_lifecycle_runtime.js';
import {initializeObjectVisualData,initializeCreatureVisualData} from './object_visual_data.js';
import {ObjectVisualRuntime} from './object_visual_runtime.js';
import {setDoorOpenState} from './world_displacement.js';
import {scriptVoiceChat,sendQuickChatMessage} from './quick_chat.js';
import {ListenExpression,ListenExpressions} from './listen_expression.js';
import {MatchedExpressionStrings,matchedSubstring,matchedSubstringCount} from './listen_event.js';
import {associateListenPatterns} from './associate_listen_patterns.js';
import {scriptStringLeft,scriptStringRight,scriptStringToInt,scriptStringToFloat,scriptSubString,scriptStringCase} from './script_string.js';
import {scriptDoorAction,doorEventOpenState} from './door_actions.js';
import {scriptAssociateType,scriptSittingCreature,scriptObjectFacing,scriptIsOpen,nativeDoorOpenState,authoredVectorOrientation,authoredBearingOrientation} from './script_object_queries.js';
import {initializeTrapQuery,appendLoadedTrap,nearestTrap} from './trap_query.js';
import {scriptMoveToObject,scriptMoveToLocation,scriptWait} from './script_movement.js';
import {scriptForceFollow} from './force_follow.js';
import {scriptPlayAnimation} from './script_animation.js';
import {scriptFloatToInt,scriptIntToFloat} from './script_scalar.js';
import {scriptTalent,talentValid} from './talent.js';
import {nativeObjectDead,nativeObjectDying,commonObjectHitPoints} from './object_life_state.js';
import {initializeBonusFeats,bonusFeats} from './bonus_feat_effect.js';
import {featInfo} from './feat_uses.js';
import {scriptEffectType} from './effect_script_type.js';
import {initializeModuleItemHistory,receiveModuleItemEvent,moduleItemHistory} from './module_item_events.js';
import {NativeItemRuntime,canonicalItemData} from './native_item_runtime.js';
import {ItemRepository,repositoryAdd,repositoryItemsOverlap,repositoryFindPosition,repositoryFit,repositoryRemove,repositoryPage,repositoryContains} from './item_repository.js';
import {initializeWorldObjectOwnership,importPlaceableInventoryState} from './world_object_state.js';
import {setItemPossessor} from './item_possession.js';
import {compareStackItems,nativeItemTag} from './item_stack_compare.js';
import {EquipmentInventory} from './equipment_inventory.js';
import {sendCombatFeedback} from './combat_broadcast.js';
import {setCreatureGold,addCreatureGold} from './creature_gold.js';
import {importCreatureCorpseFields,getCreatureLootable,setCreatureLootable,getBodyBag,setBodyBag,importPlaceableBodyBag} from './corpse_inventory.js';
import {canEquipImportedItem,canEquipCreatureItem} from './item_equipment_gate.js';
import {alignmentRestrictions,classRestrictions,raceRestrictions,itemProficient,scrollSchoolAllowed} from './item_restrictions.js';
import {getItemWeight} from './inventory_weight.js';
import {TalentRuntime,initializeTalentSpellState} from './talent_runtime.js';
import {talentAccess} from './talent_actions.js';
import {getScriptItemCharges,setScriptItemCharges} from './item_charge_command.js';
import {SpellBookRuntime} from './spell_book_runtime.js';
import {SpellRuntime} from './spell_runtime.js';
import {constructAppearEffect} from './appear_effect.js';
import {hasFeatEffectApplied,hasSpellEffectApplied} from './feat_effect.js';
import {initializeArcaneEquipmentCache,arcaneSpellFailure} from './arcane_spell_failure.js';
import {abilityModifierCells,refreshAbilityModifierCache,scriptAbilityModifier} from './ability_modifier_cache.js';
import {playableRacialType} from './playable_race.js';
import {acquireCreatureItem,acquirePlaceableItem,removePlaceableItem,scriptCreateItem} from './item_acquisition.js';
import {setItemIdentified} from './item_identification.js';
import {scriptItemGoldValue} from './item_price.js';
import {removeCreatureItem} from './item_removal.js';
import {SkillRuntime} from './skill_runtime.js';
import {RestRuntime} from './rest_runtime.js';
import {initializeRestState} from './rest.js';
import {AutomapRuntime} from './automap_runtime.js';
import {automapByteCount} from './automap.js';
import {scriptExploreArea,scriptTileExploration,scriptAutomapExploration} from './automap_script.js';
import {importPlaceableStatic,incrementAreaPlayers,decrementAreaPlayers} from './creature_area_lifecycle.js';
import {importAreaPackEntry,importAreaLoadScreen,scriptSetAreaTransitionBmp,setAreaTransitionBmp} from './client_area_message.js';
import {initializeAreaMessageName} from './native_message_text.js';
import {initializeAreaMessageFields,loadAreaMessageHeader,tileMessageMetadata} from './area_message_metadata.js';
import {AreaMessageRuntime} from './area_message_runtime.js';
import {loadAreaMessageProperties} from './area_message_properties.js';
import {loadWaypointMessageState} from './waypoint_message.js';
import {initializeSoundMessageState,loadSoundMessageState} from './sound_message.js';
import {initializePlaceableMessageState,loadPlaceableMessageState} from './placeable_message.js';

const label = value => typeof value === 'string' ? value : value?.entries?.[0]?.text ?? '';
const scriptTypes = { creature: 1, player: 1, item: 2, trigger: 4, door: 8, areaOfEffect: 16, waypoint: 32, placeable: 64, store: 128, encounter: 256 };
const localTypes = ['int', 'float', 'string', 'object', 'location'];
const blueprintTypes = { door: [2042, 'UTD '], placeable: [2044, 'UTP '], creature: [2027, 'UTC '], waypoint: [2058, 'UTW '], trigger: [2032, 'UTT '], encounter: [2040, 'UTE '], store: [2051, 'UTM '], sound: [2035, 'UTS '], item: [2025, 'UTI '] };
const position = entry => [Number(entry.XPosition ?? entry.X ?? 0), Number(entry.ZPosition ?? entry.Z ?? 0), -Number(entry.YPosition ?? entry.Y ?? 0)];

export class ModuleSession {
  constructor(resolver, { onDiagnostic = () => {}, onMessage = () => {}, onCombatMessage = null, onSound = () => {}, onCameraMode = () => {}, onTransition = null, onDoorState = () => {}, onConversation = () => {}, onCutscene = () => {}, onClearActions = () => {}, runStartupScripts = true, runNativeAI = runStartupScripts, difficultyLevel = 2, serverPvpSetting = null, naturalOnesFailSavingThrows = true, stickyCombatModes = false, alwaysResetEncounterSpawns = false, itemLevelRestrictions = false, maximumLevel = 40 } = {}) {
    Object.assign(this, { resolver, onDiagnostic, onMessage, onSound, onTransition, onDoorState, onConversation, onCutscene, onClearActions, runStartupScripts });
    this.onCameraMode = onCameraMode;
    if (typeof runNativeAI !== 'boolean') throw new Error('Invalid native AI setting');
    this.runNativeAI = runNativeAI;
    this.registry = new GameObjectArray({ clientMode: true });
    this.uuids=new ObjectUUIDRegistry({warning:(message,o)=>runtimeDiagnostics.record('object.uuid-warning',message,this.diagnosticContext(o.id))});
    this.nativePCEnumeration=new PlayerEnumeration();
    this.sources = new Map(); this.areas = new Map(); this.tags = new Map(); this.programs = new Map(); this.diagnostics = [];
    this.diagnosticNotifications = new Map();
    this.blueprints = new Map();
    this.factionManager = new NativeFactionManager();
    this.geometryResources = new NativeGeometryResources(resolver, (error, context) => this.report(error, context));
    this.scheduler = new ScriptScheduler({ validTarget: id => Boolean(this.registry.get(id)), beforePump: () => this.updateWorld(), dispatch: e => this.dispatch(e), onError: (error, queued) => this.report(error, { ...this.diagnosticContext(queued.targetId), eventType: queued.event.type, script: queued.event.name }) });
    this.worldTimer=new WorldTimer(()=>BigInt(Math.trunc(this.scheduler.time*1000)));
    this.started = false; this.currentArea = null; this.transitioning = false;
    // Local host input FIFO, separate from native AI/script events and packets.
    // The scheduler drains a snapshot before AI so UI clicks cannot mutate an
    // action list in the middle of an awaited creature/script update.
    this.pendingPlayerInputs = [];
    // Local authority starts unpaused. This is host configuration, not a
    // claim about the serialized native server constructor/pause packets.
    this.nativeServerPause={flags:0,list100f8:[],list10100:[]};
    this.conversation = new Conversation(this); this.triggerMembers = new Map();
    this.effects = new EffectRuntime(this);
    this.polymorph=new PolymorphRuntime(this);
    this.areaEffects=new AreaEffectRuntime(this);
    this.items=new NativeItemRuntime(this);
    this.talents=new TalentRuntime(this);
    this.spellBook=new SpellBookRuntime(this);
    this.spells=new SpellRuntime(this);
    this.feats=new FeatRuntime(this);
    this.skills=new SkillRuntime(this);
    this.rest=new RestRuntime(this);
    this.aiMaster=new NativeAIMaster();
    this.damage = new DamageRuntime(this);
    this.combat = new CombatRuntime(this);
    this.lifecycle=new ObjectLifecycleRuntime(this);
    this.objectVisuals=new ObjectVisualRuntime(this);
    this.worldTemplates=new WorldTemplateRuntime(this);
    this.worldCreation=new WorldCreationRuntime(this);
    this.automap=new AutomapRuntime(this);this.areaMessages=new AreaMessageRuntime(this);
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
    // DefineServerConfiguration140574db1..140574df5 default BYTE0;
    // callback14057ba10 writes ServerInfo134. External configuration loading
    // is separate. Enabled ILR still requires the minimum-item-level owner.
    if(typeof itemLevelRestrictions!=='boolean')throw new Error('Invalid item-level restriction setting');
    this.nativeItemLevelRestriction134=Number(itemLevelRestrictions);
    // DefineServerConfiguration140576bd1 defaults always-reset to byte0;
    // callback14057b4a0 writes CServerInfo160, used by both pool owners.
    if(typeof alwaysResetEncounterSpawns!=='boolean')throw new Error('Invalid encounter always-reset setting');
    this.alwaysResetEncounterSpawns=alwaysResetEncounterSpawns;
    this.encounters=new EncounterRuntime(this);
    // DefineServerConfiguration140576054 sets MaxCharLevel default40,
    // replacing CServerInfo constructor1402ccc61's preconfiguration20.
    if(!Number.isInteger(maximumLevel)||maximumLevel<1||maximumLevel>255)throw new Error('Native maximum character level is unsupported');
    this.nativeMaximumLevelF4=maximumLevel;
  }
  diagnosticContext(id) {
    const object = this.registry.get(id), area = this.registry.get(object?.areaId);
    return { module: this.resolver?.moduleName ?? this.module?.tag, area: area?.resRef ?? this.currentArea?.resRef,
      objectId: object?.id, sourceKey: object?.sourceKey, objectKind: object?.kind, objectTag: object?.tag };
  }
  report(error, context = {}) {
    const detail={...this.diagnosticContext(error?.diagnosticContext?.objectId),...context};
    runtimeDiagnostics.error(error, 'session.failure', detail);
    const message = error.message ?? String(error);
    // Preserve every occurrence in the durable journal. Present each failure
    // once per area so repeated AI calls cannot bury actual gameplay feedback.
    const key=JSON.stringify([error?.diagnosticCode??'session.failure',detail.area,message]);
    const count=(this.diagnosticNotifications.get(key)??0)+1;
    this.diagnosticNotifications.set(key,count);
    if(count!==1)return;
    this.diagnostics.push(message);
    if (this.diagnostics.length > 64) this.diagnostics.shift(); this.onDiagnostic(message);
  }
  register(kind, sourceKey, data,{requestedId=OBJECT_INVALID}={}) {
    if(!Number.isInteger(requestedId)||requestedId<0||requestedId>0xffffffff)throw new Error('Native requested object ID is unavailable');
    if (this.sources.has(sourceKey)) throw new Error(`Duplicate source placement ${sourceKey}`);
    const object = { ...data, kind, sourceKey, objectType: GAME_OBJECT_TYPE[kind], eventObjects: {} };
    if(object.objectType===5){initializeBonusFeats(object);initializeCreatureVisualData(object);}
    if(object.objectType===3)object.nativeMinutesPerHour3b8??=5; // module ctor1404787f9.
    if(object.objectType===3)initializeModuleItemHistory(object);
    initializeTrapQuery(object);
    initializeSpellContext(object);
    if(object.objectType>=5&&object.objectType<=14)object.nativeCreatedAreaEffects170??=new NativeIdList(); // base ctor14048b883/88a.
    if(object.objectType===4)object.nativeTrapIds158??=new NativeIdList();
    // CNWSObject constructor 14048bb36; distinct from effect/AoE spell IDs.
    if(object.objectType>=5&&object.objectType<=14){object.areaId??=OBJECT_INVALID;object.position??=[0,0,0];object.lastSpellId??=-1;object.plot??=false;object.counterSpellTargetId??=OBJECT_INVALID;object.effects??=[];initializeInventoryDisturbance(object);}
    if(object.objectType>=5&&object.objectType<=14){initializeObjectVisualData(object);object.nativeLoopingVisuals160??={records:[],capacity:0};object.nativePortraitId??=65535;object.nativePortraitResRef??='';} // object ctor14048b875/87c/48bc91; portrait40/52.
    // CNWSObject constructor14048ba79 and CNWSModule constructor1404787f0.
    // AI list registration and subsequent level changes have separate owners.
    if(object.objectType>=5&&object.objectType<=14){object.nativeAILevel7c??=-1;object.nativeAILocked80??=0;object.animationState??=0;
      object.objectActionState=createObjectActionState();
      if(object.nativeFieldEc!==undefined&&object.commandable!==undefined&&(object.nativeFieldEc|0)!==Number(object.commandable))throw new Error('Conflicting native commandable values');
      object.nativeFieldEc=(object.nativeFieldEc??Number(object.commandable??true))|0;
      Object.defineProperty(object,'commandable',{enumerable:true,configurable:true,get(){return this.nativeFieldEc;},set(value){this.nativeFieldEc=Number(value)|0;}});
      object.nativeListening1ec??=0;object.nativeListenExpressions??=new ListenExpressions();
      object.nativeMatchedStrings??=new MatchedExpressionStrings(); // object ctor14048b8bb/c2.
      object.lastSpeakerId??=OBJECT_INVALID;object.lastVoiceChatId??=0;object.lastSpeechVolume??=-1;object.lastSpokenText??='';} // ctor14048ba41/14048bc43.
    if(object.objectType>=5&&object.objectType<=14){object.nativeDestroyableF0??=1;object.nativeRaiseableF4??=0;object.nativeSelectableWhenDeadF8??=0;
      object.orientation??=[1,0,-0];} // CNWSObject ctor14048b998..14048b9af.
    if(object.objectType===9){object.nativeBodyBag59c??=0;object.nativeOccupant36c??=OBJECT_INVALID;object.nativePlaceableActionPoints550??=[[0,0,0],[0,0,0]];initializePlaceableMessageState(object);} // ctor1404afd3b/1404afd0d/1404afae3/1404afd17.
    if(object.objectType===3){object.nativePathfindingLevel464??=2;object.nativeTimeOfDay3d4??=0;object.nativeInvisibleCreatureIds330??=[];}
    if (object.objectType === 5) {
      initializeRestState(object);
      initializeCreaturePerception(object,this.random);
      initializeCreatureFrame(object,this.worldTimer.time());
      object.isPC??=kind==='player';object.isDM??=false;
      object.nativeSilence75c??=0;
      object.nativeQuickbar4e0??=null; // creature ctor14037aec1.
      object.nativeGold898??=0; // low DWORD of creature ctor QWORD898.
      for(const field of ['nativeField868','nativeField86c','nativeField870'])object[field]??=0; // ctor14037aefe/14037af05.
      for(const field of ['nativeWeightDirty96c','nativeEncumbrance970','nativeTotalWeight978'])object[field]??=0; // ctor14037af28..3a.
      object.nativePickpocketStage830??=0;object.nativePickpocketDetected834??=0; // ctor14037ac89.
      object.nativeField89c??=0; // ctor14037ae7f: high DWORD of zeroed QWORD898.
      object.nativeField9f4??=0; // ctor14037a53e; area enter/exit suppression.
      object.nativeField9f8??=0; // same ctor QWORD9f4 write; polymorph lock mode.
      object.nativeNaturalACD51??=0; // stats ctor1403ee49a zeroes DWORDd4f..d52.
      initializePolymorphState(object);
      // Both research names refer to the same DWORD97c. Caster/queue and
      // skill/equipment owners must observe each other's mutations.
      if(object.nativeField97c!==undefined&&object.nativeEquipmentLock97c!==undefined&&(object.nativeField97c|0)!==(object.nativeEquipmentLock97c|0))throw new Error('Conflicting native creature field97c values');
      object.nativeField97c=(object.nativeField97c??object.nativeEquipmentLock97c??0)|0; // ctor14037afbd.
      Object.defineProperty(object,'nativeEquipmentLock97c',{enumerable:true,configurable:true,get(){return this.nativeField97c;},set(value){this.nativeField97c=value|0;}});
      // Listen detection reads the same +8fc master ID as associate cleanup.
      // Preserve the old research accessor as an alias, never a second cell.
      if(object.masterId!==undefined&&object.nativeStealthTarget8fc!==undefined&&(object.masterId>>>0)!==(object.nativeStealthTarget8fc>>>0))throw new Error('Conflicting native master ID values');
      object.masterId=(object.masterId??object.nativeStealthTarget8fc??OBJECT_INVALID)>>>0;
      Object.defineProperty(object,'nativeStealthTarget8fc',{enumerable:true,configurable:true,get(){return this.masterId;},set(value){this.masterId=value>>>0;}});
      for(const field of ['nativeField8d6','nativeField58c','nativeOrphanState918','nativeOrphanDay91c','nativeOrphanTime920','nativeReputationCounter590','nativeInvited7dc','nativeInvitationDay7e0','nativeInvitationTime7e4'])object[field]??=0;
      object.nativeFieldEc??=1; // CNWSObject constructor14048ba4c.
      object.nativeProjectileRange268??=45; // object constructor14048bc91; DAT140dda4c8.
      object.nativeInvitations7e8??=null;object.nativeInvitations7f0??=null;
      object.nativeAutoMapTileX6e4??=255;object.nativeAutoMapTileY6e5??=255;object.nativeAutoMapArea6e8??=OBJECT_INVALID;
      this.automap.initialize(object);
      object.nativeSightRange7b0??=0;object.nativeHearingRange7b8??=0;
      object.nativePerceptionRange798??=11;object.nativeSize718??=0;object.nativeAttackRange71c??=0;
      object.nativeVisualTypes160??=[];
      object.nativeLastPerceived79c??=OBJECT_INVALID;
      for(const name of ['nativePerceptionHeard7a0','nativePerceptionSeen7a4','nativePerceptionInaudible7a8','nativePerceptionVanished7ac'])object[name]??=0;
      // CNWSCreature constructor14037a3b2..14037a3c7.
      object.nativeFollowingAOEs ??= new NativeIdList();
      object.nativeSubareaMembership ??= new NativeIdList();
      // CNWSCreature constructor 0x14037a8c3..14037a9ed and
      // 0x14037adf0..14037ae63. Status/perception updates remain separate.
      // +8d4 is one native WORD. Perception consumes its low byte;
      // movement-rate category1 clears bit1 in that same storage.
      const field8d4=[object.nativeField8d4,object.nativeMovementFlags8d4,object.nativeDeathWord8d4].filter(v=>v!==undefined),byte8d4=object.perceptionUpdateFlags;
      if(field8d4.some(v=>!Number.isInteger(v))||field8d4.some(v=>(v&65535)!==(field8d4[0]&65535))||
        byte8d4!==undefined&&(!Number.isInteger(byte8d4)||field8d4.length>0&&(byte8d4&255)!==(field8d4[0]&255)))
        throw new Error('Conflicting native creature field8d4 values');
      object.nativeField8d4=field8d4.length?field8d4[0]&65535:byte8d4===undefined?65535:0xff00|(byte8d4&255);
      Object.defineProperty(object,'nativeMovementFlags8d4',{enumerable:true,configurable:true,get(){return this.nativeField8d4&65535;},set(v){this.nativeField8d4=v&65535;}});
      Object.defineProperty(object,'nativeDeathWord8d4',{enumerable:true,configurable:true,get(){return this.nativeField8d4&65535;},set(v){this.nativeField8d4=v&65535;}});
      Object.defineProperty(object,'perceptionUpdateFlags',{enumerable:true,configurable:true,get(){return this.nativeField8d4&255;},set(v){this.nativeField8d4=(this.nativeField8d4&0xff00)|(v&255);}});
      if(object.nativeField771!==undefined&&object.creatureState!==undefined&&(object.nativeField771&255)!==(object.creatureState&255))throw new Error('Conflicting native creature state771 values');
      object.nativeField771=(object.nativeField771??object.creatureState??0)&255;
      Object.defineProperty(object,'creatureState',{enumerable:true,configurable:true,get(){return this.nativeField771;},set(value){this.nativeField771=value&255;}});
      object.visionFlags ??= 0;object.blindSightRange ??= 0;
      object.nativeField6ed ??= 0;
      object.nativeField6ec??=0;object.nativeField6ee??=0;
      object.creatureAnimation ??= 0; object.currentAITargetId ??= OBJECT_INVALID;
      object.nativeField700 ??= 0;
      object.nativeField828??=0; // CNWSCreature ctor14037aef7; item-cast guard.
      object.nativeField8ac??=0; // creature constructor14037af9b; input veto.
      // Creature constructor14037ab82/89 clears these shared command fields.
      object.lastAssociateCommand??=0;object.nativeField910??=0;object.nativeField914??=0;
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
      object.nativeCounterspellers310??=Array(10).fill(OBJECT_INVALID);object.nativeCounterCount338??=0; // ctor14037a901..14037a964.
      object.nativeBodyState ??= 0; object.chairId ??= OBJECT_INVALID; object.lockOrientationId ??= OBJECT_INVALID;
      object.nativeCollisionFlag788??=0;object.cutsceneGhost??=false; // constructor 14037b24a/14037b25c
      object.nativeStatsFieldBC??=0; // stats constructor 1403ee3d1
      object.enemyAttackBonus??=0; // stats ctor1403ee4b4 clears WORDd53, including BYTEd54.
      for(const field of abilityModifierCells)object[field]??=0; // stats ctor1403ee576/581.
      for(const field of ['nativeArcaneEffectD78','nativeArcaneChestD79','nativeArcaneShieldD7a'])object[field]??=0; // stats ctor1403ee55d/566.
      object.nativeSpellFailuresD7b??=Array(9).fill(0); // stats ctor1403ee638/63f.
      object.nativeSpellResistanceIncreaseD84??=0;object.nativeSpellResistanceDecreaseD85??=0; // stats ctor1403ee56d.
      object.nativeEffectIcons778??={records:[],capacity:0}; // creature ctor14037a42d/434.
      object.nativeFlag8b0??=0;object.nativeFlag8b4??=0;
      object.nativeFlag8b8??=0; // ctor14037b226.
      object.nativeField54c??=0;object.nativeField550??=0; // ctor14037a690.
      object.nativeField76c??=0;
      for(const [field,name] of [['nativeHaste760','hasted'],['nativeSlow764','slowed']]){
        const values=[object[field],object[name]].filter(v=>v!==undefined);
        if(values.some(v=>!Number.isInteger(v))||values.some(v=>(v|0)!==(values[0]|0)))throw new Error(`Conflicting native creature ${field} values`);
        object[field]=(values[0]??0)|0;
        Object.defineProperty(object,name,{enumerable:true,configurable:true,get(){return this[field];},set(value){this[field]=value|0;}});
      }
      object.nativeFrameElapsedD4??=0;object.nativeBarter??=null;
      object.nativeAcceleration538??=1;object.nativeMovementFactor78c??=1; // creature constructor14037b1d5/14037b251
      object.nativeMovementFactor8e8??=initialMovementFactor(this.characterRules??{});
      object.nativeHaste308??=0;
      object.attackActionTargetId ??= OBJECT_INVALID; object.nativeAttackTarget724 ??= OBJECT_INVALID;
      object.attackTargetId ??= OBJECT_INVALID;
      object.attackTargetPosition ??= [0, 0, 0]; // constructor14037ae14/14037ae63
      object.nativeMovementAreaId ??= OBJECT_INVALID; object.nativeMovementGoal ??= [0, 0, 0]; // constructor14037a98c..14037a9b5
      // These native addresses already back movement's pending destination.
      // AddToArea and jump actions must share those cells, rather than create
      // a second independent area ID/position with a different lifetime.
      Object.defineProperty(object,'nativeLastClientArea4f4',{configurable:true,enumerable:true,get(){return this.nativeMovementAreaId;},set(value){this.nativeMovementAreaId=value>>>0;}});
      Object.defineProperty(object,'nativePendingAreaPosition4f8',{configurable:true,enumerable:true,get(){const p=this.nativeMovementGoal;return[p[0],Math.fround(-p[2]),p[1]];},set(p){this.nativeMovementGoal=[Math.fround(p[0]),Math.fround(p[2]),Math.fround(-p[1])];}});
      object.nativeInventoryEnumeration??={outer:0,inner:0,bagId:OBJECT_INVALID}; // ctor14037a748/755.
      object.nativeEquipmentLock97c??=0;object.nativeField94c??=0; // ctor14037afbd/14037aec8.
      object.nativeField81c??=0; // ctor14037ae6a: independent unlimited spell-use flag.
      object.nativeCasterOverride820??=0;object.nativeCasterOverride824??=0;object.nativeSpellTarget818??=OBJECT_INVALID; // ctor14037ae6a/14037aecf/14037aed6.
      object.nativeEffectSpellId774??=-1; // creature ctor14037aba6.
      object.nativeSpellOverride9e8??=-1;object.nativeSpellOverride9ec??=-1;object.nativeSpellOverride9f0??=-1; // ctor14037b1bc/1c7.
      object.nativeLootable4e8??=0;object.nativeDecayTime4ec??=5000;object.nativeBodyBag8a8??=0;object.nativeNoPermDeath8bc??=0; // ctor14037b1e7/14037b226..23f.
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
    if(object.objectType===9)object.nativeEffectSpellId590??=-1; // placeable ctor1404afcfc.
    if(object.objectType===10){object.nativeDoorField498??=1;object.nativeDoorHeartbeat49c??=0;object.nativeDoorHeartbeat4a0??=0;object.nativeDoorBounds4c8??=[[0,0,0],[0,0,0]];object.nativeAnimationD8??=({0:22,1:50,2:51,3:72})[object.animationState&255]??22;}
    object.locals = new ScriptVariableTable({ onSetInt: (name, value) => {
      if (object.journal && name.startsWith('NW_JOURNAL_ENTRY')) object.journal.set(name.slice(16), value);
    } });
    const result = requestedId===OBJECT_INVALID?this.registry.addInternalObject(object):this.registry.addObjectAtPos(requestedId,object);
    if (result.status) throw new Error(`Cannot allocate ${kind}`);
    // Area ctor35a1ae uses its CGameObject subobject+138; base ctor48b967
    // uses this directly. Both belong to the same canonical JS object record.
    if(object.objectType>=4&&object.objectType<=14)this.uuids.initialize(object);
    if(object.objectType===6)this.items.initialize(object);
    initializeWorldObjectOwnership(object,{repository:(...args)=>new ItemRepository(...args),setAILevel:(o,level)=>this.aiMaster.setLevel(o,level)},requestedId);
    // Creature constructor14037a5e5..14037a603 registers level0 only when
    // its explicit AI-registration argument is nonzero. Raw test/client
    // records may omit registration; local authored creatures request it.
    if(object.objectType===5&&data.registerAI)this.aiMaster.setLevel(object,0);
    if(object.objectType===10)this.aiMaster.setLevel(object,0); // Door ctor14041d7e9..14041d7f7.
    if(object.objectType===5)object.nativePathInfo??=new PathInformation(object.id);
    if(object.objectType===7)object.nativeFacingBounds??=createTriggerFacingBounds();
    if (object.objectType === 5) object.perception ??= new VisibilityList(object.id, message =>
      runtimeDiagnostics.record('combat.perception-warning', message, this.diagnosticContext(object.id)));
    this.sources.set(sourceKey, object.id);
    for(const entry of object.authored?.ExpressionList??[])this.setListenPattern(object,entry.ExpressionString??'',entry.ExpressionId??0);
    // Native tag lookup compares byte strings case-sensitively, truncated to 64.
    const tag = String(object.tag ?? '');
    if (tag&&!data.deferTagLookup) addModuleTag(this.tags,tag,object.id);
    this.loadNativeVariableRows(object,data.variables??[]);
    return object;
  }
  source(key) { return this.registry.get(this.sources.get(key)); }
  async instance(kind, placement) {
    // GIT objects / embedded inventory items contain complete instance data.
    // TemplateResRef identifies their origin; it does not justify inheriting
    // blueprint locals/scripts omitted by the serialized instance. Store stock
    // may instead explicitly reference a UTI using InventoryRes.
    const itemReference=kind==='item'?(Object.hasOwn(placement,'EquippedRes')?'EquippedRes':Object.hasOwn(placement,'InventoryRes')?'InventoryRes':null):null;
    const template = String(itemReference?placement[itemReference]:placement.InventoryRes??'').toLowerCase();
    if(itemReference&&!template)throw new Error(`Native item ${itemReference} references an empty template`);
    if (!template) return placement;
    const [type, signature] = blueprintTypes[kind], key = `${template}:${type}`;
    if (!this.blueprints.has(key)) {
      this.blueprints.set(key, this.resolver.getResource(template, type).then(bytes => parseGff(bytes, signature).root).catch(error => {
        if(kind==='item')throw error;
        this.report(new Error(`${kind} blueprint ${template}: ${error.message}`)); return {};
      }));
    }
    if(itemReference){
      const data=cloneGff(await this.blueprints.get(key));
      for(const field of ['Dropable','Pickpocketable'])if(Object.hasOwn(placement,field))data[field]=itemReference==='EquippedRes'?placement[field]&255:Number(placement[field]!==0);
      return data;
    }
    return { ...await this.blueprints.get(key), ...placement };
  }
  itemOwnershipProviders(){
    return{module:()=>this.module,objectById:id=>this.registry.get(id),repository:item=>item.nativeRepository,
      statsPC:o=>{if(!Number.isInteger(o.nativeStatsIsPCb0))throw new Error('Native item possession stats-PC state is unavailable');return o.nativeStatsIsPCb0;},
      quickbar:o=>o.nativeQuickbar4e0,
      removeQuickbarItem:(o,id)=>removeQuickbarItem(o,id),
      event:(source,target,type,objectIds,integers)=>this.combat.enqueueEvent(10,source,target,0,{type,objectIds,integers}),
      feedback:(o,code,data)=>sendCombatFeedback(o,code,data,this.combat.broadcastProviders())};
  }
  equipmentSlot(owner,flag){
    if(owner.nativeInventoryImported)return owner.nativeEquipment.get(flag,id=>{const item=this.registry.get(id);return item?.objectType===6?item:null;});
    return(owner.inventory??[]).map(id=>this.registry.get(id)).find(item=>item?.equipmentSlot===flag)??null;
  }
  equipmentMutationProviders(){
    const inventory=o=>{if(!o.nativeInventoryImported||!o.nativeEquipment)throw new Error('Native equipment slot storage is unavailable');return o.nativeEquipment;};
    const p={equipEvent:(o,item,slot)=>this.combat.enqueueEvent(10,o.id,this.module.id,0,{type:39,objectIds:[item.id,o.id],integers:[inventory(o).index(slot)]}),
      unequipEvent:async(o,item,slot)=>{this.module.nativeUnequippedSlot37c=inventory(o).index(slot);await this.receiveItemModuleEvent(o.id,{type:40,objectIds:[item.id,o.id],integers:[]});},
      setPossessor:(...args)=>setItemPossessor(...args,this.itemOwnershipProviders()),contains:(o,item)=>inventory(o).contains(item),
      unequip:(...args)=>this.unequipItem(...args),slot:(o,item)=>inventory(o).slot(item),
      applyProperties:(...args)=>this.items.applyEquipped(...args),removeProperties:(...args)=>this.items.removeEquipped(...args),
      put:(o,slot,item)=>{inventory(o).put(slot,item);item.equipmentSlot=inventory(o).slot(item)||null;},remove:(o,item)=>{const result=inventory(o).remove(item);item.equipmentSlot=inventory(o).slot(item)||null;return result;},
      armor:o=>{initializeSkillArmorPenalties(o,this.equippedItems(o),this.characterRules);initializeArcaneEquipmentCache(o,this);
        this.items.refreshProjection(o);this.refreshCombat(o);},
      combatInformation:o=>this.refreshCombat(o),weight:item=>getItemWeight(item,this.combat.weightProviders())};return p;
  }
  equipItem(...args){return equipCreatureItem(...args,this.equipmentMutationProviders());}
  unequipItem(...args){return unequipCreatureItem(...args,this.equipmentMutationProviders());}
  canUnequip(actor,item){
    return canUnequipWeapon(actor,item,{...this.weaponSelectionProviders(actor),client:id=>this.combat.broadcastProviders().client(id),
      clearWeaponSelection:client=>{const luo=client.inventoryGUI?.openInventory;if(!luo)throw new Error('Native inventory LUO selection storage is unavailable');luo.nativeWeaponSelection10=luo.nativeWeaponSelection14=OBJECT_INVALID;}});
  }
  runUnequip(actor,itemId,repositoryId,x,y,flag,playerId){
    const p=this.weaponSelectionProviders(actor),ownership=this.itemOwnershipProviders();
    return runUnequip(actor,itemId,repositoryId,x,y,flag,playerId,{...p,client:id=>this.combat.broadcastProviders().client(id),messageAvailable:()=>true,
      inventoryGUI:(client,explicit)=>{const gui=explicit?client.alternateInventoryGUI:client.inventoryGUI;if(!gui)throw new Error('Native inventory GUI owner is unavailable');return gui;},
      creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      inEquipment:(o,i)=>{if(!o.nativeInventoryImported||!o.nativeEquipment)throw new Error('Native equipped item storage is unavailable');return o.nativeEquipment.contains(i);},
      canUnequip:(...args)=>this.canUnequip(...args),addItem:(...args)=>repositoryAdd(...args,this.itemRepositoryProviders()),
      acquire:(...args)=>acquireCreatureItem(...args,this.itemAcquisitionProviders()),removeItem:(...args)=>removeCreatureItem(...args,this.itemAcquisitionProviders()),
      drop:o=>this.combat.unsupported(o,'Native item AddToArea drop owner is unavailable'),setPossessor:(...args)=>setItemPossessor(...args,ownership),page:repositoryPage,
      selectPanel:(client,gui,page)=>this.lifecycle.inventoryInputProviders().setPanel(gui,client,page),
      cancel:(client,itemId,explicit)=>this.onCombatMessage({recipientId:client.object.id,type:'inventory-unequip-cancel',itemId,explicit}),
      unequippedMessage:(client,itemId,explicit)=>this.onCombatMessage({recipientId:client.object.id,type:'inventory-unequipped',itemId,explicit}),
      equippedMessage:(client,itemId,slot,explicit)=>this.onCombatMessage({recipientId:client.object.id,type:'inventory-equipped',itemId,slot,explicit})});
  }
  runEquip(actor,itemId,slot,playerId){
    const p=this.weaponSelectionProviders(actor),ownership=this.itemOwnershipProviders();
    return runEquip(actor,itemId,slot,playerId,{...p,client:id=>this.combat.broadcastProviders().client(id),messageAvailable:()=>true,
      cancel:(client,id,slot,explicit)=>this.onCombatMessage({recipientId:client.object.id,type:'inventory-equip-cancel',itemId:id,slot,explicit}),
      controlledId:client=>client.object.id,creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      acquire:(...args)=>acquireCreatureItem(...args,this.itemAcquisitionProviders()),
      canEquip:(o,i,ref,check,ignore,feedback,client)=>{
        if(client&&client.object!==o)this.combat.unsupported(o,'Native alternate equipment recipient is unavailable');
        return canEquipCreatureItem(o,i,ref,check,ignore,feedback,this.importedEquipmentProviders());},
      contains:(repo,item)=>{if(!repo)throw new Error('Native equipment repository is unavailable');return Number([...repo.ids()].includes(item.id));},
      setPossessor:(...args)=>setItemPossessor(...args,ownership),
      removeItem:(...args)=>removeCreatureItem(...args,this.itemAcquisitionProviders()),drop:o=>this.combat.unsupported(o,'Native item AddToArea drop owner is unavailable'),
      merge:o=>this.combat.unsupported(o,'Native direct item MergeItem owner is unavailable'),destroy:i=>this.unregister(i.id),
      equippedMessage:(client,id,slot,explicit)=>this.onCombatMessage({recipientId:client.object.id,type:'inventory-equipped',itemId:id,slot,explicit}),
      monkWeapon:i=>intEntry(this.characterRules.baseitems,i.baseItem,'IsMonkWeapon').value,
      hasFeat:(o,id)=>this.combat.hasFeat(o,id),setCombatMode:(...args)=>this.combat.setCombatMode(...args)});
  }
  weaponSelectionProviders(actor){
    const current=o=>o.combatRound.attacks[Math.min(o.combatRound.currentAttack&255,49)];
    const p={repository:o=>{if(o.nativeRepository===undefined)throw new Error('Native creature repository is unavailable');return o.nativeRepository;},object:id=>this.registry.get(id),
      item:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},equipped:(o,slot)=>this.equipmentSlot(o,slot),baseInfo:i=>this.items.baseInfo(i),
      equip:(...args)=>this.equipItem(...args),unequip:(...args)=>this.unequipItem(...args),
      stash:(o,ref,...flags)=>repositoryAdd(o.nativeRepository,ref,...flags,this.itemRepositoryProviders()),remove:(r,i)=>repositoryRemove(r,i,this.itemRepositoryProviders()),
      canEquip:(o,i,ref,...flags)=>canEquipCreatureItem(o,i,ref,...flags,this.importedEquipmentProviders()),
      weaponAttackType:o=>weaponAttackType(o.combatRound,this.equippedItems(o),this.random),relativeSize:(o,i)=>relativeWeaponSize(o,i,this.items.baseInfo(i),m=>this.combat.warning(o,m)),
      monkAbilities:o=>{const v=o.stats?.combat?.finalBreakdown?.armor?.monkAbilities;if(typeof v!=='boolean')throw new Error('Native monk abilities are unavailable');return Number(v);},
      damage:(o,t,offhand)=>this.damage.roll(o,t,current(o),{offhand:offhand!==0,critical:false,sneak:false,death:false,maximize:true}),
      elemental:async(o,t)=>!t||t.plot?0:(await this.damage.effectBonus(o,t,current(o),{energy:true,maximize:true,offhand:false})).total,
      attackModifier:(o,t)=>this.combat.attackModifier(o,t,current(o)),
      addEquip:(...args)=>this.combat.addEquip(...args),warning:m=>this.combat.warning(actor,m)};
    p.ammunition=(...args)=>selectAmmunition(...args,p);return p;
  }
  selectWeapon(id,target,offhand,ranged){const o=this.registry.get(id);return scriptSelectWeapon(o?.objectType===5?o:null,target,offhand,ranged,this.weaponSelectionProviders(o));}
  itemRestrictionProviders(){
    return{hasProperty:(i,type)=>Number([...i.activeProperties,...i.passiveProperties].some(p=>p.type===type)),passiveProperties:i=>i.passiveProperties,
      skillRank:(o,id)=>this.combat.skill(o,id,null,0),canUseSkill:(o,id)=>this.combat.canUseSkill(o,id),
      itemCost:(...args)=>this.items.price(...args),
      classIds:o=>(creatureRoot(o).ClassList??[]).map(c=>c.Class),race:o=>creatureRoot(o).Race??0,
      goodEvil:o=>creatureAlignment(creatureRoot(o)).goodEvil,lawChaos:o=>creatureAlignment(creatureRoot(o)).lawChaos};
  }
  importedEquipmentProviders(){
    const r=this.itemRestrictionProviders(),rules=this.characterRules;
    return{baseInfo:i=>this.items.baseInfo(i),equipmentSlot:(o,s)=>this.equipmentSlot(o,s),isDM:o=>Number(o.isDM),
      alignmentRestrictions:(o,i)=>alignmentRestrictions(o,i,rules,r),classRestrictions:(o,i)=>classRestrictions(o,i,rules,r),raceRestrictions:(o,i)=>raceRestrictions(o,i,rules,r),
      proficient:(o,i,slot)=>itemProficient(o,i,slot,{baseInfo:j=>this.items.baseInfo(j),armorClass:j=>itemArmorClass({data:canonicalItemData(j)},rules),hasFeat:(a,id)=>this.combat.hasFeat(a,id)}),
      possessedFamiliar:o=>Number((o.associateType&65535)===3&&Boolean(this.combat.broadcastProviders().client(o.id))),
      associatesCanInteract:()=>rulesetInt(rules,'ALL_ASSOCIATES_CAN_INTERACT',0),
      itemLevelRestrictions:()=>{if(!Number.isInteger(this.nativeItemLevelRestriction134))throw new Error('Native server item-level restriction setting134 is unavailable');return this.nativeItemLevelRestriction134;},
      level:o=>o.stats.level,minimumEquipLevel:()=>{throw new Error('Native item minimum equip level/pricing owner is unavailable');},
      weaponClientContext:o=>{
        const client=this.combat.broadcastProviders().client(o.id);if(!client)return null;
        // Import starts with empty hands; existing-hand client preview writes
        // require the actual client panel owner when an item is moved later.
        return{actor:this.registry.get(client.id)??o,preview:null};
      },feedback:(o,code)=>sendCombatFeedback(o,code,null,this.combat.broadcastProviders())};
  }
  itemUseProviders(){
    const r=this.itemRestrictionProviders();
    return {...this.importedEquipmentProviders(),baseItem:i=>i.baseItem,
      scrollSchoolAllowed:(o,i)=>scrollSchoolAllowed(o,i,this.characterRules,{...r,classSchool:(a,n)=>creatureRoot(a).ClassList[n].School??0,firstActiveProperty:j=>j.activeProperties[0]}),
      controlledByPlayer:o=>Number(Boolean(this.combat.broadcastProviders().client(o.id))),identified:i=>i.identified};
  }
  itemRepositoryProviders(){
    return{...this.itemOwnershipProviders(),baseInfo:i=>this.items.baseInfo(i),baseItem:i=>i.baseItem,
      itemById:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},
      hasProperty:(i,type)=>[...i.activeProperties,...i.passiveProperties].some(p=>p.type===type),
      compareItems:(a,b)=>compareStackItems(a,b,{baseInfo:i=>this.items.baseInfo(i),tag:i=>nativeItemTag(i.tag)}),
      addGold:(o,amount,feedback)=>addCreatureGold(o,amount,feedback,{feedback:(o,code,data)=>sendCombatFeedback(o,code,data,this.combat.broadcastProviders())}),destroyItem:i=>this.lifecycle.destroy(i),
      updateEncumbrance:(...args)=>this.combat.encumbrance(...args),
      mergeFeedback:(repo,existing,incoming,x,y)=>{
        const owner=this.registry.get(repo.ownerId);if(owner?.objectType!==5&&owner?.objectType!==6)return;
        if(repositoryItemsOverlap(existing,incoming,x,y,{baseInfo:i=>this.items.baseInfo(i)})!==0)return;
        const client=this.combat.broadcastProviders().client(owner.objectType===5?owner.id:owner.possessorId);
        if(client)runtimeDiagnostics.record('items.merge-client-message-unimplemented','Native stack merge requires destroy-item feedback/client presentation',
          {...this.diagnosticContext(incoming.id),ownerId:owner.id,mergedInto:existing.id});
      },
      feedback:(o,code)=>sendCombatFeedback(o,code,null,this.combat.broadcastProviders()),
      warning:message=>runtimeDiagnostics.record('items.repository-warning',message)};
  }
  itemAcquisitionProviders(){
    const r=this.itemRepositoryProviders();
    const p={...r,repository:o=>o.nativeRepository,creatureById:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      findPosition:(repo,item,drop)=>repositoryFindPosition(repo,item,drop,{...r,makeRoom:()=>{throw new Error('Native repository make-room item removal/drop owner is unavailable');}}),
      fit:(...args)=>repositoryFit(...args,r),add:(...args)=>repositoryAdd(...args,r),
      inEquipment:(o,item)=>{if(!o.nativeInventoryImported)throw new Error('Native equipment membership is unavailable');return o.nativeEquipment.contains(item);},
      runUnequip:(...args)=>this.runUnequip(...args),
      removePlaceableItem:(...args)=>removePlaceableItem(...args,p),
      contains:(repo,item,nested)=>repositoryContains(repo,item,nested,{object:id=>this.registry.get(id),baseInfo:i=>this.items.baseInfo(i),repository:o=>o.nativeRepository}),
      removeRepositoryItem:async(repo,item)=>{
        const result=await repositoryRemove(repo,item,r);
        const owner=this.registry.get(repo.ownerId);if(result===1&&owner?.inventory)owner.inventory=owner.inventory.filter(id=>id!==item.id);
        return result;
      },
      encumbrance:(...args)=>this.combat.encumbrance(...args),
      removeFromArea:item=>this.lifecycle.removeItemArea(item),setPossessor:async(...args)=>{
        await setItemPossessor(...args,r);
        // Compatibility UI view only: authoritative membership is still the
        // repository/slot ID cells, and the item's canonical direct owner.
        const owner=this.registry.get(args[1]);if(owner?.inventory&&!owner.inventory.includes(args[0].id))owner.inventory.push(args[0].id);
      }};
    p.removeCreatureItem=(...args)=>removeCreatureItem(...args,p);return p;
  }
  async loadItemTemplate(item,reference,newTag){
    if(typeof reference!=='string'||typeof newTag!=='string')throw new Error('Native item template/tag string is unavailable');
    // CResRef::InitFromCharArray140190d30 copies at most16 bytes, up to NUL.
    const bytes=nativeItemTag(reference).bytes,zero=bytes.indexOf(0),length=Math.min(zero<0?bytes.length:zero,16);
    const template=new TextDecoder('windows-1252').decode(Uint8Array.from(bytes.slice(0,length)));
    let data;try{data=await this.instance('item',{InventoryRes:template});}
    catch(error){this.report(error,{...this.diagnosticContext(item.id),operation:'native-item-template',resource:template,resourceType:2025});return 0;}
    item.templateResRef=template;item.name=label(data.LocalizedName);
    await this.items.loadData(item,data);
    this.loadNativeVariableRows(item,data.VarTable??[]);
    if(newTag.length!==0)item.tag=nativeObjectTag(newTag);
    addModuleTag(this.tags,item.tag,item.id);
    return 1;
  }
  addNativeItemTag(item){addModuleTag(this.tags,item.tag??'',item.id);}
  createItem(reference,targetId,stack,newTag){
    const acquisition=this.itemAcquisitionProviders();
    return scriptCreateItem(reference,this.registry.get(targetId),stack,newTag,{
      construct:()=>this.register('item',`runtime:item:${this.registry.nextObjectId[0]}`,{areaId:OBJECT_INVALID,position:[0,0,0],authored:{},equipmentSlot:null,deferTagLookup:true}),
      loadTemplate:(...args)=>this.loadItemTemplate(...args),destroy:item=>this.lifecycle.destroy(item),baseInfo:i=>this.items.baseInfo(i),acquireCreature:(...args)=>acquireCreatureItem(...args,acquisition),
      acquirePlaceable:(...args)=>acquirePlaceableItem(...args,acquisition),
      addStore:()=>{throw new Error('Native store item creation owner is unavailable');},
      acquireContainer:()=>{throw new Error('Native container item acquisition owner is unavailable');}});
  }
  async loadInventory(owner, entry,{loading=0}={}) {
    if(owner.objectType===5||owner.objectType===6)return this.loadNativeInventory(owner,entry,{loading});
    if(owner.objectType===9)return this.loadPlaceableInventory(owner,entry);
    runtimeDiagnostics.record('items.inventory-owner-unimplemented','Placeable/store repository import still requires its native owner',this.diagnosticContext(owner.id));
    owner.inventory = [];
    // Creature ReadItemsFromGff14039c2d2 /14039c86d imports equipment
    // BEFORE carried items. The allocator must observe that same order.
    // Native caps equipment at18 and stats-PC carried records at360.
    const creature=owner.objectType===5;
    for (const list of creature?['Equip_ItemList','ItemList']:['ItemList','Equip_ItemList']) {
      const cap=creature&&list==='Equip_ItemList'?18:creature&&((entry.IsPC??1)|0)!==0?360:Infinity;
      for (const [index, placement] of (entry[list] ?? []).slice(0,cap).entries()) {
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
  async loadPlaceableInventory(owner,entry){
    importPlaceableInventoryState(owner,entry);
    if(!owner.nativeRepository)throw new Error('Native placeable constructor repository is unavailable');
    owner.nativeInventoryImported=true;owner.inventory=[];const acquisition=this.itemAcquisitionProviders();
    for(const [index,placement]of(entry.ItemList??[]).entries()){
      const item=this.register('item',`${owner.sourceKey}:ItemList:${index}`,{areaId:OBJECT_INVALID,authored:{},deferTagLookup:true,equipmentSlot:null});
      try{
        // Placeable Load1404b654d passes0 for Item::LoadFromGff's last flag.
        if(await this.items.loadFromGff(item,placement,{insideContainer:0})===0){await this.lifecycle.destroy(item);continue;}
        const ref={item};await acquirePlaceableItem(owner,ref,OBJECT_INVALID,(placement.Repos_PosX??65535)&255,(placement.Repos_Posy??65535)&255,1,acquisition);
      }catch(error){
        if(!item.nativeItemFromGffLoaded)await this.lifecycle.destroy(item);
        this.report(error,{...this.diagnosticContext(owner.id),itemId:item.id,inventoryList:'ItemList',inventoryIndex:index});
      }
    }
    // Renderer/UI view only; canonical order and membership live in the repo.
    owner.inventory=[...owner.nativeRepository.ids()];
  }
  async loadNativeInventory(owner,entry,{loading=0}={}){
    const creature=owner.objectType===5;
    if(creature){
      initializeCreatureExperience(owner,entry);setCreatureGold(owner,(entry.Gold??owner.nativeGold898)|0);
      owner.nativeEquipment=new EquipmentInventory(message=>runtimeDiagnostics.record('items.equipment-warning',message,this.diagnosticContext(owner.id)));
      owner.nativeRepository=new ItemRepository(owner.id,10,36,60,0);
      owner.nativeSize718=intEntry(this.characterRules.appearance,(entry.Appearance_Type??0)&65535,'SIZECATEGORY').value;
      owner.nativeEquippedWeight968=0;
    }
    if(!owner.nativeRepository)throw new Error('Native imported inventory repository is unavailable');
    owner.inventory=[];owner.nativeInventoryImported=true;
    const ownership=this.itemOwnershipProviders(),repository=this.itemRepositoryProviders();
    for(const list of creature?['Equip_ItemList','ItemList']:['ItemList']){
      const cap=creature&&list==='Equip_ItemList'?18:creature&&owner.nativeStatsIsPCb0!==0?360:Infinity;
      for(const [index,placement] of(entry[list]??[]).slice(0,cap).entries()){
        // Native allocation precedes template load; failed loads consume IDs.
        const requestedId=loading!==0?readItemGffField(placement,'dword','ObjectId',OBJECT_INVALID).value:OBJECT_INVALID;
        const item=this.register('item',`${owner.sourceKey}:${list}:${index}`,{areaId:OBJECT_INVALID,authored:{},deferTagLookup:true,equipmentSlot:null},{requestedId});
        try{
          if(await this.items.loadFromGff(item,placement,{loading,insideContainer:Number(!creature)})===0){await this.lifecycle.destroy(item);continue;}
          const ref={item};
          if(list==='Equip_ItemList'){
            const slot={slot:getGffStructType(placement)};
            if(!Number.isInteger(slot.slot)||slot.slot===0||slot.slot>0x20000||(slot.slot&(slot.slot-1))!==0){this.unregister(item.id);runtimeDiagnostics.record('items.equipment-warning','Invalid imported equipment slot',this.diagnosticContext(owner.id));continue;}
            await setItemPossessor(item,owner.id,1,0,0,ownership);
            if(await canEquipImportedItem(owner,item,slot,this.importedEquipmentProviders())!==0){
              // EquipItem's property/AC/combat cache materialization is routed
              // through the existing equipment rules after creature stats load.
              // The slot and weight owners are canonical immediately.
              owner.nativeEquipment.put(slot.slot,item);item.equipmentSlot=slot.slot;
              owner.nativeEquippedWeight968=(owner.nativeEquippedWeight968+await getItemWeight(item,this.combat.weightProviders()))|0;
              if(owner.nativeStatsIsPCb0===1)this.combat.enqueueEvent(10,owner.id,this.module.id,0,{type:39,objectIds:[item.id,owner.id],integers:[owner.nativeEquipment.index(slot.slot)]});
            }else await repositoryAdd(owner.nativeRepository,ref,255,255,0,1,repository);
          }else{
            const x=(placement.Repos_PosX??255)&255,y=(placement.Repos_Posy??255)&255;
            if(await repositoryAdd(owner.nativeRepository,ref,x,y,0,Number(!creature),repository)===1&&ref.item)
              await setItemPossessor(ref.item,owner.id,1,0,0,ownership);
          }
          if(ref.item&&ref.item.possessorId===owner.id&&!owner.inventory.includes(ref.item.id))owner.inventory.push(ref.item.id);
        }catch(error){
          // Resource/property import failures leave no half-loaded item. A
          // later possession/equipment failure retains native state for audit.
          if(!item.nativeItemFromGffLoaded)await this.lifecycle.destroy(item);
          this.report(error,{...this.diagnosticContext(owner.id),itemId:item.id,inventoryList:list,inventoryIndex:index});
        }
      }
    }
  }
  byTag(tag, kind = null) {
    return (this.tags.get(moduleTagKey(tag)) ?? []).map(id => this.registry.get(id)).filter(o => o && (!kind || o.kind === kind));
  }
  async initialize(areaResRefs, { character = null } = {}) {
    this.ifo = parseGff(await this.resolver.getResource('module', RESOURCE_TYPE.IFO), 'IFO ').root;
    this.worldTimer.loadModule(this.ifo);
    // HAKs may contain unused AREs. Module membership comes from the IFO list.
    if (Array.isArray(this.ifo.Mod_Area_list)) areaResRefs = this.ifo.Mod_Area_list.map(entry => String(entry.Area_Name).toLowerCase());
    if (!areaResRefs.length || new Set(areaResRefs).size !== areaResRefs.length) throw new Error('Module area list is empty or has duplicates');
    this.module = this.register('module', 'module', { tag: this.ifo.Mod_Tag, name: label(this.ifo.Mod_Name), variables: this.ifo.VarTable,
      nativeMinutesPerHour3b8:(this.ifo.Mod_MinPerHour??0)&255,scripts:{heartbeat:this.ifo.Mod_OnHeartbeat??''} });
    initializeModuleAI(this.module,this.ifo,this.worldTimer);
    importAreaPackEntry(this.module,this.ifo);
    initializeModuleExperience(this.module,this.ifo);
    const api = parseScriptApi(decodeResourceText(await this.resolver.getResource('nwscript', RESOURCE_TYPE.NSS)));
    if (api[6]?.name !== 'AssignCommand' || api[385]?.name !== 'JumpToObject') throw new Error('Unrecognized NWScript command table');
    bindItemPropertyFactory(this,api);
    this.vm = new NwScriptVm({ api, command: name => this.commands[name], diagnosticContext: id => this.diagnosticContext(id), limitations: {
      SetAreaTransitionBMP: 'Native per-player transition selection is stored; ClientArea packing/loading-screen presentation is not connected',
      SpeakString: 'Speech is shown in the message UI; native overhead presentation and sound recipients are not implemented',
      SpeakOneLinerConversation: 'Native one-liner selection, local recipients, text and authored sounds are routed; native overhead bubble placement and the complete token vocabulary remain unfinished',
      FloatingTextStringOnCreature: 'Floating text is shown in the message UI; native overhead placement is not implemented',
      PlaySound: 'Sound routing is implemented; browser spatial attenuation approximates the native audio listener',
    } });
    this.characterRules??=await loadCharacterRules(this.resolver);
    this.appearances = parse2da(decodeResourceText(await this.resolver.getResource('appearance', RESOURCE_TYPE.TWO_DA)));
    try {
      const factions = parseGff(await this.resolver.getResource('repute', 2038), 'FAC ').root;
      if (!Array.isArray(factions.FactionList) || factions.FactionList.length < 1) throw new Error('Native FAC faction list is unavailable');
      this.factionManager=new NativeFactionManager();this.factionManager.load(factions.FactionList);
      this.factionTable = new FactionReputationTable(this.factionManager.npcCount, factions.RepList ?? []);
    } catch (error) {
      if(error.code!=='RESOURCE_NOT_FOUND'){
        this.report(error,{operation:'native-faction-resource-load',resRef:'repute',resourceType:2038});throw error;
      }
      runtimeDiagnostics.record('faction.default-fallback','FAC resource is absent; native CreateDefaultFactions supplies the five default owners',
        {module:this.resolver.moduleName,resRef:'repute',resourceType:2038});
      // CreateDefaultFactions constructs five factions, then an NPC matrix
      // initialized 100 except its first cell, zero. No campaign exception.
      this.factionTable = new FactionReputationTable(4, [{ FactionID1: 0, FactionID2: 1, FactionRep: 0 }]);
      this.factionManager=new NativeFactionManager();this.factionManager.createDefaults();
    }
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
        scripts: { enter: are.OnEnter ?? '', exit: are.OnExit ?? '',heartbeat:are.OnHeartbeat??'' }, objects: [] });
      initializeAreaAI(area,are,this.worldTimer);this.module.nativeAreaIds50.append(area.id);
      importAreaLoadScreen(area,are);initializeAreaMessageName(area,are);initializeAreaMessageFields(area);loadAreaMessageHeader(area,are);
      area.nativeMessageTiles=(are.Tile_List??[]).map(tileMessageMetadata);
      loadAreaMessageProperties(area,git);
      area.nativeMapByteCount348=automapByteCount(area.width,area.height);
      area.nativeSoundPath288=new PathInformation();
      area.nativeGeometry = new NativeAreaGeometry(area, this.geometryResources, this.registry);
      area.nativeSpatial = new NativeAreaSpatialArray(this.registry, message => this.report(new Error(message), { areaId: area.id, operation: 'native-area-spatial-query' }));
      area.nativeSubareas = new NativeIdList();
      this.areas.set(resRef, area);
      // LoadGIT140360f40: canonical object allocation order, including items
      // before triggers and stores after sounds.
      for (const [kind, field] of [['door', 'Door List'], ['placeable', 'Placeable List'], ['creature', 'Creature List'], ['item', 'List'], ['trigger', 'TriggerList'], ['encounter', 'Encounter List'], ['waypoint', 'WaypointList'], ['sound', 'SoundList'], ['store', 'StoreList']]) {
        for (const [index, placement] of (git[field] ?? []).entries()) {
          const entry = await this.instance(kind, placement);
          let geometry;
          try { geometry = kind === 'trigger' ? triggerGeometry(entry) : kind === 'encounter' ? encounterGeometry(entry) : undefined; }
          catch (error) { this.report(error, { areaId: area.id, sourceKey: `${resRef}:${kind}:${index}`, operation: 'native-subarea-load' }); continue; }
          const object = this.register(kind, `${resRef}:${kind}:${index}`, { areaId: area.id, tag: String(entry.Tag ?? ''), name: label(entry.LocalizedName ?? entry.LocName) || [label(entry.FirstName), label(entry.LastName)].filter(Boolean).join(' '), authored: entry,
            position: position(entry), bearing: Number(entry.Bearing ?? -Math.atan2(entry.XOrientation ?? 0, entry.YOrientation ?? 1)), variables: entry.VarTable,
            animationState: Number(entry.AnimationState ?? 0), locked: (entry.Locked??0)|0, usable: entry.Useable !== 0,
            linkedTo: String(entry.LinkedTo ?? ''), linkedToFlags: Number(entry.LinkedToFlags ?? 0), linkedToModule: String(entry.LinkedToModule ?? ''),
            scripts: { click: entry.OnClick ?? '', open: entry.OnOpen ?? '', closed: entry.OnClosed ?? '', failToOpen: entry.OnFailToOpen ?? '', lock:entry.OnLock??'',unlock:entry.OnUnlock??'',
              dialogue: entry.ScriptDialogue ?? '', used: entry.OnUsed ?? '', enter: entry.ScriptOnEnter ?? '', exit: entry.ScriptOnExit ?? '', userDefined: entry.ScriptUserDefine ?? entry.OnUserDefined ?? '',
              attacked: entry.ScriptAttacked ?? '', damaged: entry.ScriptDamaged ?? entry.OnDamaged ?? '', death: entry.ScriptDeath ?? entry.OnDeath ?? '',rest:entry.ScriptRested??'',
              spellAt: entry.ScriptSpellAt ?? entry.OnSpellCastAt ?? '', roundEnd: entry.ScriptEndRound ?? '', heartbeat: entry.ScriptHeartbeat ?? entry.OnHeartbeat ?? '',spawn:entry.ScriptSpawn??'',perception:entry.ScriptOnNotice??'',blocked:entry.ScriptOnBlocked??'',disturbed:kind==='placeable'?entry.OnInvDisturbed??'':entry.ScriptDisturbed??'' },
            geometry, factionId: entry.FactionID ?? entry.Faction,
            isPC: kind === 'creature' && Boolean(entry.IsPC), isDM: kind === 'creature' && Boolean(entry.DM), plot: Boolean(entry.Plot), commandable: true,registerAI:kind==='creature' });
          area.objects.push(object.id);
          try{
            if(kind==='creature')object.orientation=authoredVectorOrientation(placement);
            else if(kind==='waypoint')object.orientation=authoredVectorOrientation(entry,true);
            else if(kind==='door'||kind==='placeable')object.orientation=authoredBearingOrientation(placement);
          }catch(error){this.report(error,{...this.diagnosticContext(object.id),operation:'native-authored-orientation-load'});}
          if(kind==='placeable'){importPlaceableBodyBag(object,entry);importPlaceableStatic(object,entry,0);await loadPlaceableMessageState(object,entry,this.areaMessages.providers(null));}
          if(kind==='waypoint'){loadWaypointMessageState(object,entry);await this.loadNativeUUID(object,entry);}
          if(kind==='sound'){initializeSoundMessageState(object);loadSoundMessageState(object,entry);}
          if(kind==='encounter'){
            object.scripts={enter:entry.OnEntered??'',exit:entry.OnExit??'',heartbeat:entry.OnHeartbeat??'',exhausted:entry.OnExhausted??'',userDefined:entry.OnUserDefined??''};
            this.encounters.initialize(object,entry);
          }
          area.nativeSpatial.insert(object.id);
          appendLoadedTrap(area,object);
          // TriggerAddToArea1404ff70c and EncounterAddToArea14043b1e9.
          if (kind === 'trigger' || kind === 'encounter') area.nativeSubareas.append(object.id);
          if (kind === 'creature' || kind === 'placeable' || kind === 'store') await this.loadInventory(object, entry);
          // LoadPlaceable1404b6637..6678 loads visual data after ItemList.
          // Other class loaders have separate admission/order owners.
          if(kind==='placeable')await this.objectVisuals.load(object,entry);
        }
      }
    }
    this.player = this.register('player', 'player', { areaId: OBJECT_INVALID, position: [0, 0, 0], radius: 0.22,
      name: 'Preview player', playerName: 'Local preview', isPC: true, isDM: false, isPossessedFamiliar: false, journal: new Map(),registerAI:true });
    if (character) await this.loadCharacter(character);
    this.characterRules ??= await loadCharacterRules(this.resolver);
    for (const object of this.registry.objects.values()) if (object.kind === 'creature') {
      try { await this.loadCreatureStats(object); }
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
    this.characterRules=rules;
    player.authored=authored;player.creatureData=initializeBonusSpellSlots(cloneGff(authored));
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
        if (!type) {if(variable.Type===6||variable.Type===7)this.report(new Error('Native BIC structured local import is unavailable'),{...this.diagnosticContext(object.id),variableName:variable.Name,variableType:variable.Type});continue;}
        const value = type === 'object' ? ids.get(variable.Value) ?? OBJECT_INVALID : type === 'location' ? null : variable.Value;
        if (type !== 'location') object.locals.set(variable.Name, type, value);
        else{object.locals.deleteIndex(variable.Name,'location');this.report(new Error(`BIC local location ${variable.Name}: saved area reference cannot be imported into this module`));}
      }
    }
    Object.assign(player, { authored, creatureData: initializeBonusSpellSlots(cloneGff(authored)), stats, appearance, characterLoaded: true, characterFile: filename,
      name: [label(authored.FirstName), label(authored.LastName)].filter(Boolean).join(' ') || filename,
      playerName: 'Local player', isPC: true, isDM: false, savedQuickbar: authored.QBList ?? [], importItemIds: ids });
    this.loadPlayerQuickbar(player,authored.QBList??[]);
    if(!Array.isArray(authored.QBList))runtimeDiagnostics.record('quickbar.defaults-unimplemented','Native CreateDefaultQuickButtons for a character without QBList is not implemented',{...this.diagnosticContext(player.id),characterFile:filename});
    initializeCreatureExperience(player,authored);
    importCreatureCorpseFields(player,authored);
    this.characterRules = rules;
    await this.initializeCombatState(player);
    await this.initializeReputationState(player, player.creatureData, ids);
    player.itemCombatEffects = this.items.combatProjection(player);
    this.refreshCombat(player);
    for (const property of player.stats.combat?.unsupportedItemProperties ?? []) runtimeDiagnostics.record('rules.item-property-unimplemented', property.reason,
      { ...this.diagnosticContext(player.id), characterFile: filename, ...property });
    const tag = String(authored.Tag ?? '').slice(0, 64);
    if (tag) { player.tag = tag; addModuleTag(this.tags,tag,player.id); }
    return player;
  }
  unregister(id) {
    const object = this.registry.get(id); if (!object) return;
    this.registry.get(object.areaId)?.nativeSpatial?.remove(id);
    this.registry.get(object.areaId)?.nativeSubareas?.remove(id);
    this.registry.get(object.areaId)?.nativeTrapIds158?.remove(id);
    this.registry.delete(id); this.sources.delete(object.sourceKey);
    const tag = moduleTagKey(object.tag??'');
    if (tag) this.tags.set(tag, (this.tags.get(tag) ?? []).filter(other => other !== id));
  }
  quickbarProviders(){return {object:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},equipped:(o,slot)=>this.equipmentSlot(o,slot),
    at:(repo,x,y)=>{for(const id of repo?.ids()??[]){const item=this.registry.get(id);if(item?.repositoryX===x&&item.repositoryY===y)return item;}return null;},
    slot:(o,item)=>{const index=o.nativeEquipment?.ids.indexOf(item.id)??-1;return index<0?null:1<<index;},
    unsupported:(index,row,message)=>runtimeDiagnostics.record('quickbar.import-unimplemented',message,{...this.diagnosticContext(),index,type:row.QBObjectType})};}
  loadPlayerQuickbar(actor,list){return loadQuickbar(actor,list,this.quickbarProviders());}
  savePlayerQuickbar(actor=this.player){return saveQuickbar(actor,this.quickbarProviders());}
  creatureStats(id) {
    const object = this.registry.get(id);
    if (object?.objectType !== 5) return null;
    if (!object.stats) throw new Error('Creature stats have not been loaded for this object');
    return object.stats;
  }
  async loadCreatureStats(object,{finalize=true,forceNonPC=false}={}) {
    const data = cloneGff(object.authored);
    if(forceNonPC)data.IsPC=0; // Template ReadStats last flag1 forces native stats-PCb0 to0.
    if (data.PM_IsPolymorphed || data.EffectList?.length) throw new Error('Saved creature polymorph/effect import is not implemented');
    for (const field of ['Str', 'Dex', 'Con', 'Int', 'Wis', 'Cha', 'Race', 'HitPoints']) if (!Number.isInteger(data[field])) throw new Error(`Creature stat ${field} is missing or invalid`);
    if (!Array.isArray(data.ClassList) || !data.ClassList.length) throw new Error('Creature class list is missing');
    data.LvlStatList ??= []; data.Experience ??= 0; data.IsPC ??= 1;
    if (data.IsPC && data.LvlStatList.length < data.ClassList.reduce((n, c) => n + c.ClassLevel, 0)) throw new Error('Saved PC creature level history is incomplete');
    initializeBonusSpellSlots(data);
    object.creatureData = data;
    importCreatureCorpseFields(object,data);
    initializeCreatureExperience(object,data);
    const items = this.equippedItems(object);
    object.itemCombatEffects = equipmentCombatEffects(items, this.characterRules, { root: data });
    const nativeTailE18=importCreatureTail(data,object.stats?.nativeTailE18??0);
    object.stats = characterStats(data, this.characterRules, { items, itemCombatEffects: object.itemCombatEffects, areaFlags: this.registry.get(object.areaId)?.flags ?? 0 });
    object.stats.nativeTailE18=nativeTailE18;
    object.stats.gold=object.nativeGold898;
    if(finalize){await this.initializeCombatState(object);await this.initializeReputationState(object,data);}
    for (const property of object.stats.combat?.unsupportedItemProperties ?? []) runtimeDiagnostics.record('rules.item-property-unimplemented', property.reason,
      { ...this.diagnosticContext(object.id), ...property });
    return object.stats;
  }
  nativeVariableLoadProviders(object){
    const missing=kind=>{throw new Error(`Native local ${kind} engine-structure load is unavailable`);};
    return{loadCswy:()=>missing('Cassowary'),setCswy:()=>missing('Cassowary'),createJson:()=>missing('JSON'),parseJson:()=>missing('JSON'),setJson:()=>missing('JSON'),
      uninitializedStruct:kind=>{throw new Error(`Native ${kind} local Value structure is unavailable; failed first read leaves uninitialized native storage`);}};
  }
  loadNativeVariableRows(object,rows){
    if(!Array.isArray(rows))return; // Native GetList rejects non-list fields.
    try{
      const p=this.nativeVariableLoadProviders(object);
      if(rows.every(row=>getGffFieldTypes(row)))return loadScriptVariableRows(object.locals,rows,p);
      for(const row of rows){
        if(getGffFieldTypes(row))loadScriptVariableRows(object.locals,[row],p);
        else{
          // register also accepts already-decoded semantic values from local
          // callers. Serialized GFF records always take the typed path above.
          const type=localTypes[row.Type-1];
          if(type)object.locals.set(row.Name,type,row.Value,1);
          else if(row.Type===6||row.Type===7)throw new Error('Native structured semantic local import is unavailable');
        }
      }
    }catch(error){this.report(error,{...this.diagnosticContext(object.id),operation:'native-script-variable-load'});throw error;}
  }
  loadNativeVariables(object,data){
    try{return loadScriptVariables(object.locals,data,this.nativeVariableLoadProviders(object));}
    catch(error){this.report(error,{...this.diagnosticContext(object.id),operation:'native-script-variable-load'});throw error;}
  }
  loadNativeUUID(object,data){
    return this.uuids.load(object,()=>readNativeGff(data,'UUID',10,''));
  }
  async loadCreatureTemplate(object,resRef,newTag=''){
    resRef=objectTemplateResRef(resRef);const context={...this.diagnosticContext(object.id),resource:resRef,operation:'native-creature-template-load'};
    try{return await loadCreatureTemplateData(object,resRef,newTag,{
      resource:async(type,signature,name)=>{try{return{loaded:1,data:parseGff(await this.resolver.getResource(name,type),signature).root};}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;this.report(error,context);return{loaded:0,data:null};}},
      root:r=>r.data,release:r=>{r.data=null;},warning:message=>runtimeDiagnostics.record('object.template-warning',message,context),
      readStats:async(o,_r,data)=>{
        o.authored=cloneGff(data);o.name=label(data.LocalizedName??data.LocName)||[label(data.FirstName),label(data.LastName)].filter(Boolean).join(' ');
        await this.loadCreatureStats(o,{finalize:false,forceNonPC:true});
        // ReadStats14040fa36..fac8 applies AsTAG twice, preserving the
        // existing string as typed-read default; Plot uses its current BYTE.
        o.tag=nativeObjectTag(nativeObjectTag(readNativeGff(data,'Tag',10,o.tag??'').value));o.plot=Boolean(readNativeGff(data,'Plot',0,Number(o.plot)&255).value&255);
        initializeTalentSpellState(o,this.characterRules);return 0;
      },
      featBonuses:(o,remove)=>computeFeatAbilityBonuses(o,o.creatureData.FeatList??[],remove,{
        ...this.effects.abilityProviders(),modifier:(_o,score)=>this.effects.abilityProviders().modifier(score),
        deltas:(feats,remove)=>featAbilityDeltas(feats,remove,{hasFeat:(list,id)=>Number(list.some(entry=>(entry.Feat&65535)===id)),rule:(label,fallback)=>rulesetInt(this.characterRules,label,fallback)}),
      }),
      setTemplate:(o,name)=>{o.templateResRef=name;},
      scripts:(o,_r,data)=>{
        const previous=o.scripts??{};
        o.scripts=Object.fromEntries(Object.entries({dialogue:'ScriptDialogue',attacked:'ScriptAttacked',damaged:'ScriptDamaged',death:'ScriptDeath',spellAt:'ScriptSpellAt',rest:'ScriptRested',roundEnd:'ScriptEndRound',heartbeat:'ScriptHeartbeat',spawn:'ScriptSpawn',perception:'ScriptOnNotice',blocked:'ScriptOnBlocked',disturbed:'ScriptDisturbed',userDefined:'ScriptUserDefine'}).map(([key,name])=>[key,objectTemplateResRef(readNativeGff(data,name,11,objectTemplateResRef(previous[key]??'')).value)]));
      },
      items:o=>this.loadNativeInventory(o,o.creatureData),spells:o=>this.spellBook.initialize(o,0),variables:(o,_r,data)=>this.loadNativeVariables(o,data),
      asTag:nativeObjectTag,assignTag:(o,value)=>{o.tag=value;},
      postProcess:async o=>{o.itemCombatEffects=this.items.combatProjection(o);this.refreshCombat(o);await this.initializeCombatState(o,{initializeSpells:false});await this.initializeReputationState(o,o.creatureData);addModuleTag(this.tags,o.tag,o.id);},
      updateSpellUses:(o,level)=>this.rest.ready(o,level),
    });}catch(error){this.report(error,context);throw error;}
  }
  async initializeCombatState(object,{initializeSpells=true}={}) {
    refreshAbilityModifierCache(object,this.characterRules);
    // Creature LoadPersonalInformation140397a4e..140397a69 reads BYTE,
    // default0, distinct from SetListening's unrestricted INT assignment.
    object.nativeListening1ec=(creatureRoot(object).Listening??0)&255;
    for(const entry of creatureRoot(object).ExpressionList??[])this.setListenPattern(object,entry.ExpressionString??'',entry.ExpressionId??0);
    // PostProcess14039b4d3 copies the stats INT into the distinct object cell.
    object.nativeField89c=object.nativeStatsIsPCb0|0;
    await this.automap.postProcess(object);
    // PostProcess14039b420..14039b43c /14039b4d9..14039b4f0.
    if(Number(object.isPC)===1||Number(object.isDM)===1)this.aiMaster.setLevel(object,4);
    loadMovementRate(object,this.characterRules);
    updatePersonalSpace(object,this.characterRules,{warning:message=>runtimeDiagnostics.record('combat.personal-space-warning',message,this.diagnosticContext(object.id))});
    if(this.characterRules.ranges){
      loadPerceptionRanges(object,this.characterRules);
      postProcessPerceptionRanges(object,this.characterRules,{pc:o=>Number(o.isPC),possessed:o=>Number(o.isPossessedFamiliar??false),hasFeat:(o,id)=>this.combat.hasFeat(o,id)});
    }else runtimeDiagnostics.record('combat.perception-ranges-unavailable','Native ranges.2da is unavailable; perception range initialization cannot complete',this.diagnosticContext(object.id));
    this.combat.initializeFeatUses(object);
    if(initializeSpells){initializeTalentSpellState(object,this.characterRules);this.spellBook.initialize(object,0);} // ReadSpells callers pass ready-default0; template caller readies levels later.
    initializeArcaneEquipmentCache(object,this);
    object.nativeArcaneFailurePropertiesPending=this.equippedItems(object).some(i=>i.data.PropertiesList?.some(p=>p.PropertyName===84));
    initializeSkillTimers(object,this.characterRules);
    initializeClassSkillPenalties(object);
    initializeSkillArmorPenalties(object,this.equippedItems(object),this.characterRules);
    object.combatRound = createCombatRound(this.characterRules); object.initiativePending = 1;
    object.combatUpdateTime = Math.trunc(this.scheduler.time);
    object.animationState ??= 1; object.creatureState ??= 0;
    updateAppearanceInfo(object,this.characterRules);
  }
  async queuePlayerAttack(targetId) {
    if (!Number.isInteger(targetId) || targetId < 0 || targetId > 0xffffffff) throw new Error('Player attack requires a canonical OBJECT_ID');
    if (!this.player || this.registry.get(this.player.id) !== this.player) throw new Error('Player attack has no controlled creature');
    return new Promise((resolve, reject) => this.pendingPlayerInputs.push({ actor: this.player, actorId: this.player.id, targetId: targetId >>> 0, resolve, reject }));
  }
  queuePlayerUseObject(targetId,{popup=0,notify=0}={}){
    popup=Number(popup);notify=Number(notify);
    if(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff||![popup,notify].every(v=>Number.isInteger(v)&&v>=-2147483648&&v<=2147483647))return Promise.reject(new Error('Use-object input requires canonical OBJECT_ID and decoded INT flags'));
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Use-object input has no controlled creature'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'use-object',actor:this.player,actorId:this.player.id,targetId,request:{targetId,popup,notify},resolve,reject}));
  }
  queuePlayerContainerInput(subtype,ownerId=OBJECT_INVALID){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Container input has no controlled creature'));
    if(![1,2,3].includes(subtype)||!Number.isInteger(ownerId)||ownerId<0||ownerId>0xffffffff)return Promise.reject(new Error('Container input requires a known subtype and canonical owner ID'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'container',actor:this.player,actorId:this.player.id,request:{subtype,ownerId},resolve,reject}));
  }
  queuePlayerRepositoryMove(itemId,destination,x,y){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Repository input has no controlled creature'));
    if(![itemId,destination].every(v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff)||![x,y].every(v=>Number.isInteger(v)&&v>=0&&v<=255))return Promise.reject(new Error('Repository input requires canonical IDs and BYTE coordinates'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'repository-move',actor:this.player,actorId:this.player.id,request:{itemId,destination,x,y},resolve,reject}));
  }
  queuePlayerInventoryStatus(value,ownerId=OBJECT_INVALID){
    return this.queuePlayerInventoryInput({subtype:1,value,ownerId});
  }
  queuePlayerInventoryPanel(panel,primary=1){
    return this.queuePlayerInventoryInput({subtype:2,panel,value:primary});
  }
  queuePlayerInventoryInput(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Inventory input has no controlled creature'));
    if(![1,2].includes(request.subtype)||!Number.isInteger(request.value)||request.value< -2147483648||request.value>2147483647||request.subtype===1&&(!Number.isInteger(request.ownerId)||request.ownerId<0||request.ownerId>0xffffffff)||request.subtype===2&&(!Number.isInteger(request.panel)||request.panel<0||request.panel>255))return Promise.reject(new Error('Inventory input requires decoded INT flags, canonical owner ID and BYTE panel'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'inventory',actor:this.player,actorId:this.player.id,request:{...request},resolve,reject}));
  }
  queuePlayerClearActions(){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Player cancellation has no controlled creature'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'clear-actions',actor:this.player,actorId:this.player.id,resolve,reject}));
  }
  queuePlayerCancelPolymorph(){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Polymorph cancellation has no controlled creature'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'cancel-polymorph',actor:this.player,actorId:this.player.id,resolve,reject}));
  }
  queuePlayerAssociateCommand(targetId,command){
    if(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff||!Number.isInteger(command)||command< -2147483648||command>2147483647)return Promise.reject(new Error('Associate command requires canonical OBJECT_ID and signed INT32'));
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Associate command has no controlled creature'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'associate-command',actor:this.player,actorId:this.player.id,targetId,command,resolve,reject}));
  }
  queuePlayerMode(mode,targetId=OBJECT_INVALID){
    if(!Number.isInteger(mode)||mode<0||mode>255||!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff)return Promise.reject(new Error('Player mode requires a BYTE mode and canonical target ID'));
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Player mode has no controlled creature'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'mode',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,mode,targetId,resolve,reject}));
  }
  queuePlayerCastSpell(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Player casting has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    const spell=this.spellBook.castingSpell(request.spellId);
    if(!spell)return Promise.resolve(0);
    const cast={...request,targetType:spell.targetType,position:request.position?.slice()??[0,0,0]};
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'cast-spell',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,request:cast,resolve,reject}));
  }
  queuePlayerUseItem(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Item use has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    const item={itemId:request.itemId,propertyIndex:request.propertyIndex??0,variant:request.variant??0,targetId:request.targetId??OBJECT_INVALID,location:request.location??0,position:request.position?.slice()??[0,0,0]};
    if(![item.itemId,item.propertyIndex,item.variant,item.targetId,item.location].every(Number.isInteger)||item.itemId<0||item.itemId>0xffffffff||item.targetId<0||item.targetId>0xffffffff||item.propertyIndex<0||item.propertyIndex>255||item.variant<0||item.variant>255||item.position.length!==3||!item.position.every(Number.isFinite))return Promise.reject(new Error('Player item input fields are unavailable'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'use-item',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,request:item,resolve,reject}));
  }
  queuePlayerLearnScroll(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Scroll learning has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    if(!Number.isInteger(request.itemId)||request.itemId<0||request.itemId>0xffffffff)return Promise.reject(new Error('Scroll learning requires a canonical item ID'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'learn-scroll',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,request:{itemId:request.itemId},resolve,reject}));
  }
  queuePlayerRest(request={}){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Rest has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'rest',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,resolve,reject}));
  }
  queuePlayerSpellPreparation(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Spell preparation has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    const clear=request.clear===true,fields=clear?['classIndex','level','slot']:['classIndex','spellId','slot','domainLevel','metamagic'];
    if(!fields.every(key=>Number.isInteger(request[key])&&request[key]>=0&&request[key]<=(key==='spellId'?0xffffffff:255)))return Promise.reject(new Error('Spell preparation requires native BYTE fields and a DWORD spell ID'));
    const copy={clear};for(const key of fields)copy[key]=request[key];
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'spell-preparation',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,request:copy,resolve,reject}));
  }
  queuePlayerSpellLike(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Spell-like casting has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    const cast={spellId:request.spellId,casterLevel:request.domainLevel??0,targetId:request.targetId??OBJECT_INVALID,position:request.position?.slice()??[0,0,0],location:request.location??0};
    if(![cast.spellId,cast.casterLevel,cast.targetId,cast.location].every(Number.isInteger)||cast.position.length!==3||!cast.position.every(Number.isFinite))return Promise.reject(new Error('Player spell-like input fields are unavailable'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'spell-like',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,request:cast,resolve,reject}));
  }
  queuePlayerFeat(request){
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Feat activation has no controlled creature'));
    if(request.actorId!==undefined&&request.actorId!==this.player.id||request.areaId!==undefined&&request.areaId!==this.player.areaId)return Promise.resolve(0);
    const feat={featId:request.featId,auxiliary:request.auxiliary??0,targetId:request.targetId??OBJECT_INVALID,position:request.position?.slice()??[0,0,0]};
    if(![feat.featId,feat.auxiliary,feat.targetId].every(Number.isInteger)||feat.position.length!==3||!feat.position.every(Number.isFinite))return Promise.reject(new Error('Player feat input fields are unavailable'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'feat',actor:this.player,actorId:this.player.id,areaId:this.player.areaId,request:feat,resolve,reject}));
  }
  queuePlayerCancelAction(actionId,groupId){
    if(![actionId,groupId].every(value=>Number.isInteger(value)&&value>=0&&value<=65535))return Promise.reject(new Error('Player queue cancellation requires uint16 action/group IDs'));
    if(!this.player||this.registry.get(this.player.id)!==this.player)return Promise.reject(new Error('Player queue cancellation has no controlled creature'));
    return new Promise((resolve,reject)=>this.pendingPlayerInputs.push({kind:'cancel-action',actor:this.player,actorId:this.player.id,actionId,groupId,resolve,reject}));
  }
  async drainPlayerInputs() {
    const batch = this.pendingPlayerInputs.splice(0);
    for (const input of batch) {
      // A queued click belongs to its original controlled object. Changing
      // characters must never retarget that click to the replacement PC.
      if (this.player !== input.actor || this.registry.get(input.actorId) !== input.actor) {
        runtimeDiagnostics.record('combat.input-control-changed', 'Queued player input discarded because the controlled creature changed', { actorId: input.actorId, targetId: input.targetId }, 'info');
        if(input.kind==='learn-scroll')this.items.learnReply(input.request.itemId);
        input.resolve(0); continue;
      }
      try {
        if(input.kind==='clear-actions'){await this.combat.clearActions(input.actor);input.resolve(1);}
        else if(input.kind==='cancel-polymorph')input.resolve(await receiveCancelPolymorphInput(null,{readObjectId:()=>input.actorId,overflow:()=>0,creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},effects:o=>o.effects,remove:(o,id)=>this.effects.remove(o.id,id)}));
        else if(input.kind==='cancel-action')input.resolve(await this.combat.cancelQueuedAction(input.actor,input.actionId,input.groupId));
        else if(input.kind==='use-object')input.resolve(await this.combat.receiveUseObjectInput(input.request));
        else if(input.kind==='inventory')input.resolve(await this.lifecycle.receiveInventoryInput(input.request));
        else if(input.kind==='container')input.resolve(await this.lifecycle.receiveContainerInput(input.request));
        else if(input.kind==='repository-move')input.resolve(await this.combat.receiveRepositoryMoveInput(input.request));
        else if(input.kind==='cast-spell')input.resolve(input.areaId===input.actor.areaId?await this.spells.input(input.request):0);
        else if(input.kind==='spell-like')input.resolve(input.areaId===input.actor.areaId?await this.spells.inputLike(input.request):0);
        else if(input.kind==='spell-preparation')input.resolve(input.areaId===input.actor.areaId?await this.spellBook.inputPreparation(input.request):0);
        else if(input.kind==='rest')input.resolve(input.areaId===input.actor.areaId?await this.rest.input():0);
        else if(input.kind==='feat')input.resolve(input.areaId===input.actor.areaId?await this.feats.input(input.request):0);
        else if(input.kind==='use-item')input.resolve(input.areaId===input.actor.areaId?await this.items.input(input.request):0);
        else if(input.kind==='learn-scroll'){if(input.areaId!==input.actor.areaId){this.items.learnReply(input.request.itemId);input.resolve(0);}else input.resolve(await this.items.inputLearn(input.request));}
        else if(input.kind==='mode')input.resolve(input.areaId===input.actor.areaId?await this.combat.receiveModeInput(input.mode,input.targetId):0);
        else if(input.kind==='associate-command')input.resolve(await this.combat.receiveAssociateInput(input.targetId,input.command));
        else input.resolve(await this.combat.receiveAttackInput(input.targetId));
      }
      catch (error) { this.report(error, { ...this.diagnosticContext(input.actorId), targetId: input.targetId, actionId:input.actionId,groupId:input.groupId,
        operation: `queued-player-${input.kind??'attack'}` }); input.reject(error); }
    }
  }
  cancelPendingPlayerInputs() {
    for (const input of this.pendingPlayerInputs.splice(0)) {
      runtimeDiagnostics.record('combat.input-session-closed', 'Queued player input discarded because its local session closed', { actorId: input.actorId, targetId: input.targetId }, 'info');
      if(input.kind==='learn-scroll')this.items.learnReply(input.request.itemId);
      input.resolve(0);
    }
  }
  async updateWorld() {
    // Native AI master interleaves due events and level-list traversal.
    // Active area clocks, height/traps and complete dialog timing remain pending.
    const now = Math.trunc(this.scheduler.time);
    this.worldTimer.snapshot();
    await this.drainPlayerInputs();
    if(this.started&&this.runNativeAI){
      await this.aiMaster.updateState({
        worldTime:()=>this.worldTimer.time(),microseconds:()=>BigInt(Math.trunc(performance.now()*1000)),
        object:id=>this.registry.get(id)??null,peekEvent:()=>this.scheduler.events[0],eventDue:event=>event.due<=now,
        // UpdateState14055a300..14055a4e9 drains every due event before
        // advancing the AI list. The non-native scheduler's256-event pump
        // cap is not a native limit: large modules enqueue thousands of
        // finite spawn events. Applying it here aborted normal startup.
        takeEvent:()=>this.scheduler.events.shift(),
        dispatchEvent:async event=>{try{await this.dispatch(event);}catch(error){this.report(error,{...this.diagnosticContext(event.targetId),eventType:event.event.type});}},
        deferEvent:(event,milliseconds)=>this.scheduler.enqueueMilliseconds(event.targetId,event.event,milliseconds),
        disposeEvent:()=>{},random:()=>this.random.next(),
        updateObject:object=>this.updateWorldObject(object,now,true),
        resetWork:()=>{this.nativeAIField98=0;this.nativeAIFieldA8=0;this.nativeAIFieldB0=0;this.nativeAIFieldB4=0;this.nativeAIFieldB8=0;this.nativeAIFieldBC=-1;},
        updateDialog:object=>{
          if(this.conversation.state)runtimeDiagnostics.repeat('combat.ai-dialog-update-unimplemented','Native per-object UpdateDialog timing is not implemented',this.diagnosticContext(object.id));
        },
        overflow:(object,code,elapsed,limit)=>runtimeDiagnostics.record('combat.ai-overflow','Native AI object update exceeded its overflow threshold',{...this.diagnosticContext(object.id),code,elapsed,limit}),
        moduleUpdate:async()=>{try{await this.updateModuleAI();}catch(error){this.report(error,{...this.diagnosticContext(this.module?.id),operation:'native-module-update'});}},
        playerDialogs:()=>{},
      });
      return true;
    }
    for (const object of this.registry.objects.values()) {
      await this.updateWorldObject(object,now,false);
    }
  }
  async updateModuleAI(){
    if(!this.module)return;
    const clients=this.combat.broadcastProviders();
    await updateModule(this.module,{
      worldTime:()=>this.worldTimer.time(),dayLength:this.worldTimer.dayLength,
      calendar:day=>this.worldTimer.calendar(day),timeParts:time=>this.worldTimer.timeParts(time),
      random:()=>this.random.next(),areaById:id=>{const o=this.registry.get(id);return o?.objectType===4?o:null;},
      runHeartbeat:o=>this.damage.runEvent(o,o.scripts?.heartbeat),clients:clients.clients,
      clientObject:c=>c.object??null,area:o=>this.registry.get(o.areaId)??null,
      sendTime:(c,data)=>clients.send(c,'moduleTime',data),sendWeather:(c,data)=>clients.send(c,'areaWeather',data),
      // Local normal-game adapter. Server pause flags, exclusion ownership and
      // SetPauseState clock transitions have not been mapped into this session.
      activePauseState:()=>((this.nativeActivePauseFlags??0)&2)!==0?2:Number(((this.nativeActivePauseFlags??0)&1)!==0),
      exclusionIds:()=>{throw new Error('Native active pause exclusion ownership is unavailable');},
      creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},effects:o=>o.effects??[],
      togglePause:()=>{throw new Error('Native server pause-state transition is unavailable');},
    });
  }
  async updateWorldObject(object,now,nativeAI=false){
      if(object.objectType===10){
        // CNWSDoor::AIUpdate14041db30: heartbeat (strict >5999ms), effects,
        // then the shared base-object action list. No creature round required.
        if(object.scripts?.heartbeat||object.objectActionState.list.count||(object.effects?.length??0)){
          const time=this.worldTimer.time(),elapsed=subtractWorldTimes(time,{day:object.nativeDoorHeartbeat49c,time:object.nativeDoorHeartbeat4a0},this.worldTimer.dayLength);
          if(elapsed.milliseconds>5999){
            if(object.nativeDoorHeartbeat4a0!==0&&!this.isDead(object)&&object.scripts?.heartbeat)try{await this.runScript(object.scripts.heartbeat,object.id,{scriptEventContext:10005});}catch(error){this.report(error,this.diagnosticContext(object.id));}
            object.nativeDoorHeartbeat49c=time.day;object.nativeDoorHeartbeat4a0=time.time;
          }
          await this.effects.updateObject(object);
          if(object.objectActionState.list.count)await this.combat.runActions(object,time.day,time.time);
        }
        return;
      }
      if(object.objectType===11){try{await this.areaEffects.update(object);}catch(error){this.report(error,this.diagnosticContext(object.id));}return;}
      if (object.objectType === 5 && object.combatRound) {
        if(nativeAI){
          try{await this.combat.updateNativeFrame(object);}catch(error){this.report(error,this.diagnosticContext(object.id));}
          return;
        }
        const delta = (now - (object.combatUpdateTime ?? 0)) | 0;
        object.combatUpdateTime = now;
        try {
          // Startup-disabled resource/isolated-owner tests retain their
          // explicit bypass. Normal sessions run the native script/perception
          // owner BEFORE round timers, inside the shared AI budget traversal.
          await this.combat.updateTimer(object, delta);
          await this.combat.updateExcited(object,delta);
          await this.effects.updateObject(object);
          await this.combat.updateAfterEffects(object,delta);
        }
        catch (error) { this.report(error, this.diagnosticContext(object.id)); }
      }else await this.effects.updateObject(object);
  }
  refreshCombat(object,{refreshAbilityCaches=true}={}) {
    if (!object?.stats?.combat?.saves) return;
    const items = Array.isArray(object.inventory) ? this.equippedItems(object) : undefined;
    const computed = characterStats(object.creatureData ?? object.authored, this.characterRules, {
      currentHP: object.stats.currentHP, items, abilityProjectionItems:items?this.items.projectionItems(object,items):undefined,effects: object.effects ?? [],
      areaFlags: this.registry.get(object.areaId)?.flags ?? 0, limits: this.combatLimits, acCache: object.acCache, possessedFamiliar: Boolean(object.isPossessedFamiliar), itemCombatEffects: object.itemCombatEffects,
      abilityItem:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},bonusFeats:bonusFeats(object),actor:object
    });
    computed.gold=object.nativeGold898;
    Object.assign(object.stats, computed);
    if(refreshAbilityCaches)refreshAbilityModifierCache(object,this.characterRules);
  }
  setBaseAbility(object,ability,value,adjustHP=1){
    if(object?.objectType!==5)throw new Error('Native base-ability setter requires a canonical creature');
    return setBaseAbility(object,ability,value,adjustHP,this.effects.abilityProviders());
  }
  equippedItems(object) {
    if(object.nativeInventoryImported)return object.nativeEquipment.ids.map((id,index)=>({item:this.registry.get(id),slot:1<<index})).filter(v=>v.item?.objectType===6)
      .map(({item,slot})=>({id:item.id,source:item.id,slot,data:canonicalItemData(item)}));
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
    if(object.objectType===6)return commonObjectHitPoints(object,maximum);
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
      minimumLevel: this.minimumLevel ?? 1, maximumLevel: this.nativeMaximumLevelF4
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
    if (!this.programs.has(key)) {
      const pending=this.resolver.getResource(key, RESOURCE_TYPE.NCS).then(bytes => parseNcs(bytes, key)).catch(error=>{
        if(this.programs.get(key)===pending)this.programs.delete(key);throw error;
      });
      this.programs.set(key,pending);
    }
    return this.programs.get(key);
  }
  async runScript(name,selfId,options={}){
    // RunScript140283d5e..140284014: ReadScriptFile's missing-resource
    // result(-634) returns failure0 without entering RunScriptFile/ExecuteCode.
    // Keep the absence recorded, without turning it into a gameplay exception.
    if(!name)return {executed:false,nativeResult:0,stack:[]};
    let program;
    try{program=await this.program(name);}
    catch(error){
      if(error.code!=='RESOURCE_NOT_FOUND'||error.resourceType!==RESOURCE_TYPE.NCS)throw error;
      runtimeDiagnostics.record('script.resource-unavailable',`Script ${name} is unavailable; native RunScript returns failure without execution`,{
        ...this.diagnosticContext(selfId),script:String(name).toLowerCase(),resRef:error.resRef,resourceType:RESOURCE_TYPE.NCS,
        nativeLoadError:-634,nativeResult:0,scriptEventContext:options.scriptEventContext??-1,
        callerScript:options.callerScript,outcome:'No script instructions ran; the calling event or script continues',cause:error.message});
      return {executed:false,nativeResult:0,loadError:-634,stack:[]};
    }
    const result=await this.vm.run(program,selfId,options);
    return {...result,executed:true,nativeResult:1};
  }
  async script2DAString(name,column,row){
    if(!Number.isInteger(row))throw new Error('Native script 2DA row is unavailable');
    name=String(name);if(!name.length)return '';
    const resource=name.split('\0')[0].slice(0,16).replace(/[A-Z]/g,c=>c.toLowerCase());
    this.nativeScript2DATables??=new Map();
    if(!this.nativeScript2DATables.has(resource))this.nativeScript2DATables.set(resource,(async()=>{
      try{return parse2da(decodeResourceText(await this.resolver.getResource(resource,RESOURCE_TYPE.TWO_DA)));}
      catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;
        runtimeDiagnostics.record('rules.script-table-unavailable',error.message,{...this.diagnosticContext(),engineCall:'Get2DAString',resource});return null;}
    })());
    let table;
    try{table=await this.nativeScript2DATables.get(resource);}catch(error){this.nativeScript2DATables.delete(resource);throw error;}
    if(!table)this.nativeScript2DATables.delete(resource); // native failed loads are not cached.
    return table?spellStringEntry(table,row|0,String(column)):'';
  }
  queueScript(name, selfId, eventObjects = {}) {
    if (name) this.scheduler.enqueue(selfId, { type: 'script', name, eventObjects });
  }
  deleteSituation(situation){
    if(!situation)return;
    // Local ownership release. The immutable NCS program remains cached;
    // stack cells (including engine structures) become collectible.
    situation.stack=[];situation.program=null;situation.disposed=true;
  }
  async runSituation(situation,selfId){
    if(!situation||situation.disposed||!situation.program)throw new Error('Native owned script situation is unavailable');
    try{await this.vm.run(situation.program,selfId,{situation});}
    catch(error){this.report(error,this.diagnosticContext(selfId));}
    finally{this.deleteSituation(situation);}
  }
  async dispatch({ targetId, event }) {
    const target = this.registry.get(targetId);
    if (event.type === 'situation') await this.vm.run(event.situation.program, targetId, { situation: event.situation });
    else if (event.type === 'script') {
      Object.assign(target.eventObjects, event.eventObjects);
      if (Object.hasOwn(event.eventObjects, 'damager')) target.lastDamagerId = event.eventObjects.damager;
      if (event.name) await this.runScript(event.name, targetId);
    } else if (event.type === 'nativeSubareaScript') await dispatchSubareaEvent(target, event.eventId, event.payload, {
      runScript: async (object, index) => {
        const name = object.scripts?.[object.objectType===13?['enter','exit','heartbeat','exhausted','userDefined'][index]:index===1?'enter':'exit'];
        if (name) await this.runScript(name, object.id,{scriptEventContext:(object.objectType&255)*1000+index});
      },
      encounterEnterBeforeSpawn:()=>rulesetInt(this.characterRules,'ENCOUNTERS_ON_ENTER_FIRE_BEFORE_SPAWN',0),
      activateEncounter:(...args)=>this.encounters.spawn(...args),updateEncounterActivation:(...args)=>this.encounters.updateActivation(...args),
      // Native trap firing still requires its separate owner.
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
      if (target.scripts?.used) await this.runScript(target.scripts.used, target.id);
    }
    else if (event.type === 'dialogReply') await this.conversation.choose(event.ordinal, event.version);
    else if (event.type === 'dialogClose') { if (event.version === this.conversation.version) await this.conversation.finish(event.aborted); }
  }
  async receiveItemModuleEvent(caller,payload){
    const fields={7:'Mod_OnAcquirItem',8:'Mod_OnUnAqreItem',15:'Mod_OnPlrEqItm',16:'Mod_OnPlrUnEqItm'};
    return receiveModuleItemEvent(this.module,caller,payload,{scriptName:(_m,index)=>this.ifo?.[fields[index]]??'',
      runScript:async(module,name,context)=>{await this.runScript(name,module.id,{scriptEventContext:context});},
      runEventScript:async(module,index)=>{
        const name=this.ifo?.[fields[index]]??'';
        if(name)await this.runScript(name,module.id,{scriptEventContext:(module.nativeScriptObjectType34&255)*1000+index});
      }});
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
        try { await this.runScript(previous.scripts.exit, previous.id); }
        catch (error) { this.report(error); }
      }
    }
    if (previous && previous !== next) {
      previous.objects = previous.objects.filter(id => id !== this.player.id);
      previous.nativeSpatial?.remove(this.player.id);
      if(previous.nativePlayerCount150!==undefined)await decrementAreaPlayers(previous,this.lifecycle.areaProviders());
      this.player.nativeSubareaMembership.setSize(0);
    }
    this.currentArea = next; this.player.areaId = next.id; this.player.position = spawn;
    // This local renderer has completed area entry. Mirror the SAME pending
    // area/destination cells used by ClientArea/MovePlayerToArea, so a native
    // same-area remove/re-add (e.g. polymorph) does not request another load.
    this.player.nativeLastClientArea4f4=next.id;
    this.player.nativePendingAreaPosition4f8=[spawn[0],Math.fround(-spawn[2]),spawn[1]];
    this.refreshCombat(this.player);
    next.objects ??= [];
    if (!next.objects.includes(this.player.id)) next.objects.push(this.player.id);
    next.nativeSpatial?.insert(this.player.id);
    if(previous!==next&&next.nativePlayerCount150!==undefined){
      await incrementAreaPlayers(next,this.lifecycle.areaProviders());
    }
    // The local PC adapter also applies AddToArea's verified map update.
    // The native ClientArea send/ready protocol remains a separate owner.
    if(this.player.characterLoaded)await this.automap.update(this.player,this.player.id);
    if (!this.started) {
      this.started = true;
      if (this.runStartupScripts) {
        this.queueScript(this.ifo.Mod_OnModLoad, this.module.id);
        this.queueScript(this.ifo.Mod_OnModStart, this.module.id);
        this.queueScript(this.ifo.Mod_OnClientEntr, this.module.id, { entering: this.player.id });
      } else this.onMessage({ type: 'testing', text: 'Testing: module startup and initial area-entry scripts disabled for this session.' });
    }
    if (previous !== next && (!initialEntry || this.runStartupScripts)) this.queueScript(next.scripts.enter, next.id, { entering: this.player.id });
    // The local scene-transition adapter still owns PC entry until the native
    // ClientArea handshake is connected. Queue the PC area entry before NPC
    // AddToArea entry events, then restore companions through the native owner.
    if(previous!==next&&this.player.associateIds.length)await this.lifecycle.realizeAssociates(this.player);
    if (previous !== next) this.updateTriggers(this.player);
  }
  isDead(object) {
    if(!object||object.kind==='player'&&!object.stats&&!object.characterLoaded)return false;
    return nativeObjectDead(object,this.lifeStateProviders());
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
    if(!object||object.kind==='player'&&!object.stats&&!object.characterLoaded)return false;
    return nativeObjectDying(object,this.lifeStateProviders());
  }
  lifeStateProviders(){return{creature:o=>o?.objectType===5?o:null,
    possessedFamiliar:o=>Number((o.associateType&65535)===3&&Boolean(this.combat.broadcastProviders().client(o.id))),
    hitPoints:o=>o.stats||[6,9,10].includes(o.objectType)?this.hitPoints(o.id,false):o.authored?.CurrentHitPoints};}
  factionProviders() {
    const clients=this.combat.broadcastProviders();
    return {creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      pc:o=>o.reputationPCFlag,statsPC:o=>o.nativeStatsIsPCb0,possessed:o=>Number(o.isPossessedFamiliar??false),dm:o=>Number(o.isDM),
      client:clients.client,warning:message=>runtimeDiagnostics.record('faction.member-warning',message),
      bringAssociates:async(actor,factionId)=>{
        if(!Array.isArray(actor.associateIds))throw new Error('Native faction associate list is unavailable');
        // BringAssociatesToNewFaction1403d0ff0: live list and count.
        for(let i=0;i<actor.associateIds.length;i++){
          const associate=this.registry.get(actor.associateIds[i]);
          if(associate?.objectType===5)await this.factionManager.addMember(this.factionManager.get(factionId),associate.id,0,this.factionProviders());
        }
      },
      reprocessAssociates:o=>{if(!Array.isArray(o.associateIds))throw new Error('Native faction associate list is unavailable');
        if(o.associateIds.length)this.combat.unsupported(o,'Native PostProcess ReprocessAssociateList is not implemented');},
      // DefineServerConfiguration140577eac defaults server.one-party-only1.
      // Singleplayer currently has one actual local client. No invented clients.
      autoParty:async(o,manager)=>{for(const client of clients.clients()){
        const other=client.object;if(!other||other.id===o.id||other.isDM)continue;
        await manager.addMember(manager.get(other.factionId),o.id,1,this.factionProviders());break;
      }},
      setLikes:o=>this.combat.unsupported(o,'Native faction PVP attitude/aggression update is not implemented'),
      attitude:(recipient,other,value)=>this.onCombatMessage({recipientId:recipient.object.id,type:'pvpAttitude',data:{otherId:other.object.id,value}}),
      partyList:(recipient,members,updateType,subjectId)=>this.onCombatMessage({recipientId:recipient.object.id,type:'partyList',data:{memberIds:[...members],updateType,subjectId}})};
  }
  async initializeReputationState(object, data, importIds) {
    object.reputationPCFlag = object.nativeStatsIsPCb0;
    if(!object.reputationInitialized){
      // ReadStatsFromGff14041047c..1404104a2 imports FactionID as WORD;
      // native ctor's current faction -1 becomes 65535 if the field is absent.
      object.factionId=(data.FactionID??65535)&65535;
      try {await initializeCreatureFaction(object,this.factionManager,this.factionProviders());}
      catch(error){this.report(error,{...this.diagnosticContext(object.id),operation:'native-faction-postprocess'});throw error;}
    }
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
  scriptEmotion(targetId,sourceId,type){
    const target=this.registry.get(targetId);if(!target||target.objectType<=4)return 0;
    // ExecuteCommandGetEmotions1405236d0 queries TARGET toward SOURCE.
    // These legacy thresholds differ from the AI reaction type queries.
    const reputation=objectReputation(target,sourceId,0,this.reputationProviders()).reputation;
    return Number(type==='enemy'?reputation<=10:type==='friend'?reputation>=90:((reputation-11)>>>0)<=78);
  }
  scriptShape(first,args,selfId){
    const [shape,size,location,los=0,filter=1,origin=[0,0,0]]=args;
    return objectInShape(first,this.registry.get(selfId),shape,size,location,los,filter,origin,{
      area:id=>{const o=this.registry.get(id);return o?.objectType===4?o:null;},object:id=>this.registry.get(id),
      position:o=>[o.position[0],-o.position[2],o.position[1]],isDM:o=>Number(o.isDM),spatialIds:a=>areaSpatialIds(this,a),firstByX:(a,x)=>firstAreaSpatialIndex(this,a,x),
      lineOfSight:(a,from,to,source,target,flag)=>{if(!a.nativeGeometry)throw new Error('Native shape area LOS is unavailable');return a.nativeGeometry.lineOfSight(from,to,[0,0,0],{id:OBJECT_INVALID},source,target,flag);}});
  }
  scriptInventoryItem(first,id){
    return inventoryItem(first,this.registry.get(id),{repository:o=>{if(o.nativeRepository===undefined)throw new Error('Native inventory owner repository import is unavailable');return o.nativeRepository;},
      item:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},baseInfo:o=>this.items.baseInfo(o),storeRepositories:o=>o.nativeStoreRepositories});
  }
  scriptFacing(value,id,point){
    const actor=this.registry.get(id),orientation=scriptFacingVector(actor,value,point);if(!orientation)return;
    if(actor.objectType===9)return this.lifecycle.setOrientation(actor,[orientation[0],-orientation[2],orientation[1]]);
    if(actor.objectType===5)this.combat.setLock(actor,OBJECT_INVALID);
    actor.orientation=orientation;
  }
  scriptFactionMember(id,pcOnly,first){
    const actor=this.registry.get(id);if(!actor||![5,7,9,10,13].includes(actor.objectType))return OBJECT_INVALID;
    if(!this.factionManager)throw new Error('Native faction manager is unavailable');
    const faction=this.factionManager.get(actor.factionId);if(!faction)return OBJECT_INVALID;
    return this.factionManager.member(faction,first?0:faction.field18,pcOnly,id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;});
  }
  setListenPattern(object,pattern,id){
    if(!object||object.objectType<=4)return;
    if(!object.nativeListenExpressions)throw new Error('Native object listening expression storage is unavailable');
    const result=object.nativeListenExpressions.set(String(pattern),id|0);
    if(result<0)this.report(new Error(`Native listening expression parse failed (${result})`),{...this.diagnosticContext(object.id),patternId:id|0,operation:'native-listen-pattern-parse'});
    // ExecuteCommandSetListenString ignores ParseString's result. Preserve the
    // failed graph and record its failure, without aborting the caller script.
  }
  scriptAnimation(actor,id,speed,duration,immediate){
    return scriptPlayAnimation(actor,id,speed,duration,immediate,{
      modelType:o=>{
        const root=creatureRoot(o),table=this.characterRules?.appearance,row=table?.orderedRows[root.Appearance_Type&65535];
        const column=table?.columns.find(c=>c==='MODELTYPE'),value=row?.[column];
        if(typeof value!=='string')throw new Error('Native script animation appearance MODELTYPE is unavailable');return value;
      },
      clearActions:o=>this.combat.clearActions(o),
      setAnimation:o=>this.combat.unsupported(o,'Native scripted door animation and client automap lifecycle are unavailable'),
      updateAutomaps:o=>this.combat.unsupported(o,'Native area UpdatePlayerAutomaps is unavailable')});
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
        inAOE:(o,point)=>this.areaEffects.contains(o,point),lineAOE:(o,from,to)=>this.areaEffects.intersects(o,from,to),moveAOE:(o,point)=>this.areaEffects.move(o,point),
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
  async updateSubareasOnJump(actor,point,areaId,providers={}){
    try{
      const result=await updateSubareasOnJump(actor,point,areaId,{
        areaById:id=>{const o=this.registry.get(id);if(!o)throw new Error('Native jump subarea target area is unavailable');return o.objectType===4?o:null;},
        object:id=>this.registry.get(id)??null,aoe:id=>{const o=this.registry.get(id);return o?.objectType===11?o:null;},
        inTrigger:(o,p)=>Number(inTrigger(o,p)),inEncounter:(o,p)=>Number(inTrigger(o,p)),inAOE:(o,p)=>this.areaEffects.contains(o,p),
        jumpAOE:(o,area,p)=>this.areaEffects.jump(o,area,p),
        dm:o=>Number((o.associateType&65535)===0&&Boolean(this.combat.broadcastProviders().client(o.id))&&Boolean(o.isDM)),
        event:(_code,callerId,targetId,payload)=>this.scheduler.enqueue(targetId,{type:'nativeSubareaScript',eventId:10,callerId,payload}),...providers,
      });
      this.triggerMembers.set(actor.id,new Set([...actor.nativeSubareaMembership.view()].filter(id=>this.registry.get(id)?.objectType===7)));
      return result;
    }catch(error){this.report(error,{...this.diagnosticContext(actor.id),operation:'native-subarea-jump'});throw error;}
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
      try { await this.runScript(owner.scripts.dialogue, owner.id); return Boolean(this.conversation.state); }
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
  async setNativeDoorOpenState(door,state){
    const previous=door.animationState,area=this.registry.get(door.areaId);
    // Native AddToArea has already loaded these bounds/points. Materialize
    // our lazy geometry before entering that same state-change coordinator.
    try{if(area?.objectType===4)await area.nativeGeometry.objects.load();await setDoorOpenState(door,state,{
      area:o=>{const a=this.registry.get(o.areaId);return a?.objectType===4?a:null;},animation:(o,value)=>{o.nativeAnimationD8=value;},
      position:o=>[o.position[0],-o.position[2],o.position[1]].map(Math.fround),
      updateMaps:a=>this.automap.updatePlayersInArea(a),budge:(...args)=>this.lifecycle.budgeCreatures(...args),
    });}catch(error){this.report(error,{...this.diagnosticContext(door.id),operation:'native-door-set-open-state'});throw error;}
    if(door.animationState!==previous){door.version=(door.version??0)+1;this.onDoorState(door,previous);}
  }
  async receiveDoorUseEvent(door,callerId,open){
    const caller=this.registry.get(callerId),state=open?doorEventOpenState(door,caller):0;
    door.eventObjects[open?'opened':'closed']=callerId;
    await this.setNativeDoorOpenState(door,state);
    const other=this.transitionTarget(door);if(other?.objectType===10)await this.setNativeDoorOpenState(other,state);
    const name=door.scripts?.[open?'open':'closed'];
    if(name)await this.runScript(name,door.id,{scriptEventContext:open?10000:10001});
  }
  doorEvent(door, actor, event) {
    if (event.type === 'door.clicked') {
      door.eventObjects.clicking = actor.id; door.eventObjects.entering = actor.id;
      if (door.linkedToModule) { this.report(new Error('Inter-module traversal is not implemented')); return; }
      this.queueScript(event.script && event.script !== 'default' ? event.script : 'nw_g0_transition', door.id, { clicking: actor.id, entering: actor.id });
    } else if (event.type === 'door.stateChanged') {
      // The preview interaction adapter has already changed the canonical
      // visible state. Keep its native animation cell in sync until that
      // adapter is replaced by the full creature-owned door action owner.
      door.nativeAnimationD8=({0:22,1:50,2:51,3:72})[event.state]??door.nativeAnimationD8;
      const key = event.state ? 'opened' : 'closed'; door.eventObjects[key] = actor.id;
      door.lastUsedBy = actor.id;
      const other = this.transitionTarget(door);
      if (other?.kind === 'door') { const previous = other.animationState; other.animationState = event.state;other.nativeAnimationD8=({0:22,1:50,2:51,3:72})[event.state]??other.nativeAnimationD8; this.onDoorState(other, previous); }
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
    CreateObject:(args,f)=>this.worldCreation.create(args,f.self),
    VersusAlignmentEffect:([effect,lawChaos=0,goodEvil=0])=>versusEffect(effect,355,lawChaos,goodEvil),
    VersusRacialTypeEffect:([effect,race])=>{
      const rows=this.characterRules?.racialtypes?.orderedRows;
      if(!rows)throw new Error('Native versus-effect racialtypes rules are unavailable');
      return versusEffect(effect,356,race,0,rows.length);
    },
    EffectTurnResistanceDecrease:(args,f)=>constructTurnResistance(552,args,f.self,{create:(...a)=>this.effects.create(...a),setCreator:(...a)=>this.effects.setCreator(...a)}),
    EffectTurnResistanceIncrease:(args,f)=>constructTurnResistance(553,args,f.self,{create:(...a)=>this.effects.create(...a),setCreator:(...a)=>this.effects.setCreator(...a)}),
    GetTurnResistanceHD:([id])=>{const o=this.registry.get(id);return o?.objectType===5?turnResistanceHD(o):0;},
    EffectSummonCreature:(args,f)=>this.lifecycle.constructSummon(args,f.self),
    DestroyObject:([id,seconds=0],f)=>this.lifecycle.requestDestroy(id,seconds,f.self),
    ActionInteractObject:([id],f)=>scriptInteractObject(f.self,id,{
      placeable:id=>{const o=this.registry.get(id);return o?.objectType===9?o:null;},creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},addUse:(o,id)=>addUseObjectAction(o,id),
    }),
    EffectAppear:(args,f)=>constructAppearEffect(args,f.self,{create:(...a)=>this.effects.create(...a)}),
    ActionCounterSpell:async([targetId],f)=>{const actor=this.registry.get(f.self);if(actor?.objectType===5)await this.spells.addCounter(actor,targetId);},
    TouchAttackMelee:(args,f)=>this.combat.touchAttack(146,args,f.self),
    TouchAttackRanged:(args,f)=>this.combat.touchAttack(147,args,f.self),
    ActionCastSpellAtObject:(args,f)=>this.spells.script(48,args,f),
    ActionUseFeat:(args,f)=>this.feats.script(args,f),
    ActionUseItemOnObject:Object.assign((args,f)=>this.items.script(910,args,f),{nativeStack:(vm,f)=>this.items.scriptStack(910,vm,f)}),
    ActionUseItemAtLocation:Object.assign((args,f)=>this.items.script(911,args,f),{nativeStack:(vm,f)=>this.items.scriptStack(911,vm,f)}),
    ActionCastSpellAtLocation:(args,f)=>this.spells.script(234,args,f),
    ActionCastFakeSpellAtObject:(args,f)=>this.spells.script(501,args,f),
    ActionCastFakeSpellAtLocation:(args,f)=>this.spells.script(502,args,f),
    GetCasterLevel:([id],f)=>this.spellBook.casterLevel(this.registry.get(id??f.self)),
    GetSpellSaveDC:(_args,f)=>this.spellBook.saveDC(this.registry.get(f.self)),
    GetMetaMagicFeat:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetMetaMagicFeat'),
    GetSpellCasterItem:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetSpellCasterItem'),
    GetSpellCastItem:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetSpellCasterItem'),
    Get2DAString:([name,column,row])=>this.script2DAString(name,column,row),
    GetSpellTargetObject:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetSpellTargetObject'),
    GetSpellTargetLocation:(_args,f)=>{
      const actor=this.registry.get(f.self),location=spellTargetLocation(actor,{object:id=>this.registry.get(id)??null,
        area:o=>this.registry.get(o.areaId)??null,orientation:o=>[o.orientation[0],-o.orientation[2],o.orientation[1]]});
      return{...location,orientation:actor&&[5,9].includes(actor.objectType)?scriptObjectFacing(actor):0};
    },
    GetSpellId:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetSpellId'),
    GetSpellFeatId:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetSpellFeatId'),
    GetSpellCastSpontaneously:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetSpellCastSpontaneously'),
    GetLastSpellCaster:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetLastSpellCaster'),
    GetLastSpell:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetLastSpell'),
    GetLastSpellHarmful:(_args,f)=>scriptSpellContext(this.registry.get(f.self),'GetLastSpellHarmful'),
    RoundsToSeconds:([count])=>spellTimeConversion(121,count,this.worldTimer.minutesPerHour),
    HoursToSeconds:([count])=>spellTimeConversion(122,count,this.worldTimer.minutesPerHour),
    TurnsToSeconds:([count])=>spellTimeConversion(123,count,this.worldTimer.minutesPerHour),
    FortitudeSave:(args,f)=>scriptSavingThrow(108,args,f.self,{object:id=>this.registry.get(id),save:(...args)=>this.combat.savingThrow(...args)}),
    ReflexSave:(args,f)=>scriptSavingThrow(109,args,f.self,{object:id=>this.registry.get(id),save:(...args)=>this.combat.savingThrow(...args)}),
    WillSave:(args,f)=>scriptSavingThrow(110,args,f.self,{object:id=>this.registry.get(id),save:(...args)=>this.combat.savingThrow(...args)}),
    GetReflexAdjustedDamage:args=>reflexAdjustedDamage(args,{creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      hasFeat:(o,id)=>this.combat.hasFeat(o,id),save:(...args)=>this.combat.savingThrow(...args),
      evasionVisual:(o,creator)=>this.effects.apply(0,this.effects.create(30,creator,[256]),o.id)}),
    GetIsDMPossessed:([id])=>{const o=this.registry.get(id);return o?.objectType===5?Number(((o.associateType-7)&65535)<=1):0;},
    ResistSpell:([caster,target],f)=>this.combat.resistSpell(caster,target,f.self),
    GetSpellResistance:([id])=>{const o=this.registry.get(id);return o?.objectType===5?this.combat.spellResistance(o):0;},
    GetFactionEqual:([first,second])=>{
      const p=this.reputationProviders(),a=this.registry.get(first),b=this.registry.get(second),x=a?p.faction(a):null;
      if(x===null)return 0;const y=b?p.faction(b):null;return Number(y!==null&&(x|0)===(y|0));
    },
    GetFirstItemProperty:([id])=>enumerateItemProperty(this.registry.get(id),true,()=>this.effects.invalid()),
    GetNextItemProperty:([id])=>enumerateItemProperty(this.registry.get(id),false,()=>this.effects.invalid()),
    GetIsItemPropertyValid:([effect])=>validItemProperty(effect),
    GetItemPropertyDurationType:([effect])=>itemPropertyDurationType(effect),
    GetItemPropertyType:([effect])=>itemPropertyValue(effect,614),
    GetItemPropertySubType:([effect])=>itemPropertyValue(effect,734),
    GetItemPropertyCostTable:([effect])=>itemPropertyValue(effect,769),
    GetItemPropertyCostTableValue:([effect])=>itemPropertyValue(effect,770),
    GetItemPropertyParam1:([effect])=>itemPropertyValue(effect,771),
    GetItemPropertyParam1Value:([effect])=>itemPropertyValue(effect,772),
    GetItemHasItemProperty:([id,type])=>itemHasProperty(this.registry.get(id),type),
    AddItemProperty:([duration,effect,id,seconds=0],f)=>{
      if(duration===2&&this.registry.get(id)?.objectType===6&&!Number.isInteger(this.nativeItemLevelRestriction134))throw new Error('Native server item-level restriction setting134 is unavailable');
      return scriptAddItemProperty(duration,structuredClone(effect),id,seconds,this.items.scriptPropertyProviders(f));
    },
    RemoveItemProperty:([id,effect],f)=>scriptRemoveItemProperty(id,structuredClone(effect),f.self,this.items.scriptPropertyProviders(f)),
    GetModuleItemAcquired:()=>moduleItemHistory(this.module,282),
    GetModuleItemAcquiredFrom:()=>moduleItemHistory(this.module,283),
    GetModuleItemLost:()=>moduleItemHistory(this.module,292),
    GetModuleItemLostBy:()=>moduleItemHistory(this.module,293),
    GetModuleItemAcquiredStackSize:()=>moduleItemHistory(this.module,579),
    GetModuleItemAcquiredBy:()=>moduleItemHistory(this.module,707),
    ActionDoCommand:async([situation],f)=>{
      const actor=this.registry.get(f.self);
      if(actor&&actor.objectType>4)await addDoCommandAction(actor,situation,s=>this.deleteSituation(s));
      else this.deleteSituation(situation);
    },
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
    ExecuteScript: async ([name, target], f) => { target ??= f.self; if (this.registry.get(target)) await this.runScript(name, target, { budget: f.budget, depth: f.depth + 1,callerScript:f.program?.name }); },
    GetIsObjectValid: ([id]) => Number(Boolean(this.registry.get(id))),
    GetObjectType: ([id]) => scriptTypes[this.registry.get(id)?.kind] ?? 32767,
    GetModule: () => this.module.id,
    GetArea: ([id]) => this.registry.get(id)?.areaId ?? OBJECT_INVALID,
    GetTag: ([id]) => this.registry.get(id)?.tag ?? '',
    GetName: ([id]) => this.registry.get(id)?.name ?? '',
    GetPCPlayerName: ([id]) => this.registry.get(id)?.playerName ?? '',
    GetObjectByTag: ([tag, ordinal = 0]) => scriptObjectByTag(this.tags,tag,ordinal),
    GetWaypointByTag: ([tag]) => scriptWaypointByTag(this.tags,tag,id=>this.registry.get(id)),
    GetTransitionTarget: ([id]) => this.transitionTarget(this.registry.get(id))?.id ?? OBJECT_INVALID,
    GetEnteringObject: (_, f) => this.registry.get(f.self)?.eventObjects.entering ?? OBJECT_INVALID,
    GetExitingObject: (_, f) => this.registry.get(f.self)?.eventObjects.exiting ?? OBJECT_INVALID,
    GetClickingObject: (_, f) => this.registry.get(f.self)?.eventObjects.clicking ?? OBJECT_INVALID,
    GetLastOpenedBy: (_, f) => this.registry.get(f.self)?.eventObjects.opened ?? OBJECT_INVALID,
    GetLastClosedBy: (_, f) => this.registry.get(f.self)?.eventObjects.closed ?? OBJECT_INVALID,
    GetLastUsedBy: (_, f) => this.registry.get(f.self)?.lastUsedBy ?? OBJECT_INVALID,
    // ExecuteCommandIsPC1405336a0 asks GetClientObjectByObjectId, not the
    // creature's authored/stats IsPC flag used by faction and XP owners.
    GetIsPC: ([id]) => Number(Boolean(this.combat.broadcastProviders().client(id))),
    GetIsEnemy:([target,source],f)=>this.scriptEmotion(target,source??f.self,'enemy'),
    GetIsFriend:([target,source],f)=>this.scriptEmotion(target,source??f.self,'friend'),
    GetIsNeutral:([target,source],f)=>this.scriptEmotion(target,source??f.self,'neutral'),
    GetIsReactionTypeFriendly:([target,source],f)=>{const actor=this.registry.get(source??f.self);return actor?.objectType>4?Number(this.aiReaction(actor,target)===1):0;},
    GetIsReactionTypeNeutral:([target,source],f)=>{const actor=this.registry.get(source??f.self);return actor?.objectType>4?Number(this.aiReaction(actor,target)===0):0;},
    GetIsReactionTypeHostile:([target,source],f)=>{const actor=this.registry.get(source??f.self);return actor?.objectType>4?Number(this.aiReaction(actor,target)===2):0;},
    GetDistanceToObject:([target,source],f)=>scriptObjectDistance(this.registry.get(source??f.self),this.registry.get(target),o=>this.registry.get(o.areaId)??null),
    GetDistanceBetween:([first,second])=>scriptDistanceBetween(this.registry.get(first),this.registry.get(second)),
    GetDistanceBetweenLocations:([first,second])=>scriptDistanceBetweenLocations(first,second),
    FloatingTextStrRefOnCreature:(args)=>{const p=this.combat.broadcastProviders();return floatingText(525,args,{object:id=>this.registry.get(id),client:p.client,send:p.send,broadcast:(o,data)=>broadcastFloatyData(o,data,p)});},
    FloatingTextStringOnCreature:(args)=>{const p=this.combat.broadcastProviders();return floatingText(526,args,{object:id=>this.registry.get(id),client:p.client,send:p.send,broadcast:(o,data)=>broadcastFloatyData(o,data,p)});},
    SetFacing:([value,id],f)=>this.scriptFacing(value,id??f.self,false),
    SetFacingPoint:([value,id],f)=>this.scriptFacing(value,id??f.self,true),
    UnlockAchievement:([id,name,a=0,b=0,c=0])=>{
      const actor=this.registry.get(id);if(actor?.objectType!==5)return;
      const p=this.combat.broadcastProviders(),client=p.client(id);if(!client)return;
      const data={objectIds:[id>>>0],strings:[String(name)],integers:[a|0,b|0,c|0]};
      p.send(client,'achievement',data);
      runtimeDiagnostics.record('engine.achievement-presentation-unimplemented','Native achievement message delivered locally; platform achievement presentation is unavailable',
        {...this.diagnosticContext(id),messageSubtype:0x14,achievement:String(name)});
    },
    GetFirstPC:()=>this.nativePCEnumeration.next(this.combat.broadcastProviders().clients(),c=>c.object?.id??OBJECT_INVALID,true),
    GetNextPC:()=>this.nativePCEnumeration.next(this.combat.broadcastProviders().clients(),c=>c.object?.id??OBJECT_INVALID),
    GetFirstFactionMember:([id,pcOnly=1])=>this.scriptFactionMember(id,pcOnly,true),
    GetNextFactionMember:([id,pcOnly=1])=>this.scriptFactionMember(id,pcOnly,false),
    GetBlockingDoor: (_,frame) => {
      const o=this.registry.get(frame.self);if(o?.objectType!==5)return OBJECT_INVALID;
      // Constructor does not initialize +528 in the verified body. Do not
      // invent a default for a field whose load initialization is still open.
      if(!Number.isInteger(o.nativeBlockingObject528))throw new Error('Native blocking object field528 is unavailable');
      return o.nativeBlockingObject528>>>0;
    },
    GetIsDM: ([id]) => Number(Boolean(this.registry.get(id)?.isDM)),
    ExploreAreaForPlayer:args=>scriptExploreArea(args,this.automap.scriptProviders()),
    GetTileExplored:args=>scriptTileExploration(867,args,this.automap.scriptProviders()),
    SetTileExplored:args=>scriptTileExploration(866,args,this.automap.scriptProviders()),
    GetCreatureExploresMinimap:args=>scriptAutomapExploration(869,args,this.automap.scriptProviders()),
    SetCreatureExploresMinimap:args=>scriptAutomapExploration(868,args,this.automap.scriptProviders()),
    GetIsPossessedFamiliar: ([id]) => Number(Boolean(this.registry.get(id)?.isPossessedFamiliar)),
    GetAILevel: ([id]) => this.registry.get(id)?.objectType===5?this.registry.get(id).nativeAILevel7c:0,
    // Native script accessors 140527310/140527140 read their actual creature
    // cells; neither is inferred from the current queue or authored template.
    GetIsInCombat:([id])=>{const o=this.registry.get(id);return o?.objectType===5?o.nativeField700|0:0;},
    GetIsEncounterCreature:([id])=>{const o=this.registry.get(id);return o?.objectType===5?Number((o.nativeField948>>>0)!==OBJECT_INVALID):0;},
    GetActionMode:async([id,mode])=>{const o=this.registry.get(id);return o?.objectType===5?getActionMode(o,mode,a=>detectMode(a,{hasFeat:(c,feat)=>this.combat.hasFeat(c,feat)})):0;},
    SetActionMode:async([id,mode,value])=>{const o=this.registry.get(id);if(o?.objectType===5)await setActionMode(o,mode,value,{detect:a=>detectMode(a,{hasFeat:(c,feat)=>this.combat.hasFeat(c,feat)}),toggle:(...args)=>this.combat.toggleMode(...args)});},
    GetAppearanceType:([id])=>scriptAppearanceType(this.registry.get(id)),
    GetCreatureSize:([id])=>scriptCreatureSize(this.registry.get(id)),
    GetCreatureTailType:([id])=>scriptCreatureTail(this.registry.get(id)),
    GetSubRace:([id])=>scriptSubrace(this.registry.get(id)),
    SetDroppableFlag:([id,value])=>scriptSetDroppable(this.registry.get(id),value),
    GetDroppableFlag:([id])=>scriptGetDroppable(this.registry.get(id)),
    // ExecuteCommandGetIsNight140527430 reads the cached module BYTE, not
    // an independent hour threshold or the currently rendered area's light.
    GetIsNight:()=>{if(!this.module)return 0;if(!Number.isInteger(this.module.nativeTimeOfDay3d4))throw new Error('Native module time-of-day byte is unavailable');return Number((this.module.nativeTimeOfDay3d4&255)===2);},
    GetIsDay:()=>{if(!this.module)return 0;if(!Number.isInteger(this.module.nativeTimeOfDay3d4))throw new Error('Native module time-of-day byte is unavailable');return Number((this.module.nativeTimeOfDay3d4&255)===1);},
    GetIsDawn:()=>{if(!this.module)return 0;if(!Number.isInteger(this.module.nativeTimeOfDay3d4))throw new Error('Native module time-of-day byte is unavailable');return Number((this.module.nativeTimeOfDay3d4&255)===3);},
    GetIsDusk:()=>{if(!this.module)return 0;if(!Number.isInteger(this.module.nativeTimeOfDay3d4))throw new Error('Native module time-of-day byte is unavailable');return Number((this.module.nativeTimeOfDay3d4&255)===4);},
    GetStringRight:([text,count])=>scriptStringRight(text,count),
    GetStringLeft:([text,count])=>scriptStringLeft(text,count),
    StringToInt:([text])=>scriptStringToInt(text),
    StringToFloat:([text])=>scriptStringToFloat(text),
    AngleToVector:([angle])=>scriptAngleToVector(angle),
    GetAssociateType:([id])=>scriptAssociateType(this.registry.get(id)),
    GetSittingCreature:([id])=>scriptSittingCreature(this.registry.get(id)),
    GetIsOpen:([id])=>scriptIsOpen(id,{object:id=>this.registry.get(id)??null,asDoor:o=>o.objectType===10?o:null,asPlaceable:o=>o.objectType===9?o:null,openState:nativeDoorOpenState}),
    GetObjectByUUID:([uuid])=>this.uuids.lookup(uuid),
    GetFacing:([id])=>scriptObjectFacing(this.registry.get(id)),
    GetSubString:([text,start,count])=>scriptSubString(text,start,count),
    GetStringLength:([text])=>[...scriptStringRight(text,0x7fffffff)].length,
    GetStringLowerCase:([text])=>scriptStringCase(text),
    GetStringUpperCase:([text])=>scriptStringCase(text,true),
    FloatToInt:([value])=>scriptFloatToInt(value),
    IntToFloat:([value])=>scriptIntToFloat(value),
    GetTimeHour:()=>this.worldTimer.getHour(),
    GetTimeMinute:()=>this.worldTimer.getMinute(),
    GetTimeSecond:()=>this.worldTimer.getSecond(),
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
    GetLootable:([id])=>getCreatureLootable(this.registry.get(id)),
    GetBodyBag:([id])=>getBodyBag(this.registry.get(id)),
    SetBodyBag:([id,value])=>setBodyBag(id,value,{entry:async(name,row,column)=>{const table=await this.items.table(name);if(!table)throw new Error(`Native corpse ${name}.2da is unavailable`);return intEntry(table,row,column);},
      creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},placeable:id=>{const o=this.registry.get(id);return o?.objectType===9?o:null;}}),
    SetLootable:([id,value])=>setCreatureLootable(this.registry.get(id),value,{dead:o=>Number(this.isDead(o)),dying:o=>Number(this.isDying(o)),
      possessed:o=>Number((o.associateType&65535)===3&&Boolean(this.combat.broadcastProviders().client(o.id)))}),
    SetIsDestroyable:([destroyable,raiseable=1,selectable=0,id],f)=>setObjectDestroyable(this.registry.get(id??f.self),destroyable,raiseable,selectable,{
      dead:o=>Number(this.isDead(o)),setLock:(o,id)=>this.combat.setLock(o,id),
      possessedFamiliar:o=>Number((o.associateType&65535)===3&&Boolean(this.combat.broadcastProviders().client(o.id))),
      enqueue:(...args)=>this.combat.enqueueEvent(...args)}),
    GetIsDestroyable:([id])=>this.registry.get(id)?.nativeDestroyableF0??0,
    GetIsRaiseable:([id])=>this.registry.get(id)?.nativeRaiseableF4??0,
    GetIsSelectableWhenDead:([id])=>this.registry.get(id)?.nativeSelectableWhenDeadF8??0,
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
    GetLocked:([id])=>getObjectLocked(this.registry.get(id)),
    SetLocked:([id,value],f)=>{
      const o=this.registry.get(id);if(!o)return;
      if(o.objectType===9||o.objectType===10)o.locked=value|0;
      this.combat.enqueueEvent(10,f.self,o.id,0,{type:value!==0?28:29,objectIds:[],integers:[]});
    },
    GetLastLocked:(_,f)=>this.registry.get(f.self)?.eventObjects.locked??OBJECT_INVALID,
    GetLastUnlocked:(_,f)=>this.registry.get(f.self)?.eventObjects.unlocked??OBJECT_INVALID,
    GetLastDisturbed:([id],f)=>lastDisturbed(this.registry.get(id??f.self)),
    GetInventoryDisturbItem:([id],f)=>{const o=this.registry.get(id??f.self);return inventoryDisturbItem(o?.objectType>=5&&o.objectType<=14?o:null);},
    GetInventoryDisturbType:([id],f)=>{const o=this.registry.get(id??f.self);return inventoryDisturbType(o?.objectType>=5&&o.objectType<=14?o:null);},
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
    GetNearestTrapToObject:([id,detected=1],f)=>nearestTrap(this,this.registry.get(id??f.self),detected),
    IsInConversation: ([id]) => Number(this.registry.get(id)?.dialogOwnerId !== undefined && this.registry.get(id)?.dialogOwnerId !== OBJECT_INVALID),
    BeginConversation: async ([resRef = '', id = OBJECT_INVALID], f) => {
      const self = this.registry.get(f.self), target = this.registry.get(id === OBJECT_INVALID ? self?.lastSpeakerId : id);
      if (!self || !target) return 0;
      return Number(await this.conversation.start(target.isPC ? self : target, target.isPC ? target : self, resRef || self.requestedDialog, f));
    },
    SpeakOneLinerConversation: ([resRef = '', tokenTargetId = OBJECT_INVALID], f) => this.conversation.oneLiner(this.registry.get(f.self), resRef, tokenTargetId, f),
    SetCameraMode: ([id, mode]) => requestCameraMode(id, mode, { client: this.combat.broadcastProviders().client,
      apply: (actor, value) => { actor.scriptCameraMode = value; this.onCameraMode(actor, value); } }),
    ActionStartConversation: ([id, resRef = ''], f) => {
      const self = this.registry.get(f.self), target = this.registry.get(id);
      if (self?.isPC) this.requestTalk(id, self.id, resRef);
      else if (target?.isPC) this.requestTalk(f.self, id, resRef);
    },
    GetListenPatternNumber: (_, f) => this.registry.get(f.self)?.listenPatternNumber ?? -1,
    GetMatchedSubstring:([index],f)=>matchedSubstring(this.registry.get(f.self),index,{storage:o=>{if(!o.nativeMatchedStrings)throw new Error('Native matched-string storage is unavailable');return o.nativeMatchedStrings;}}),
    GetMatchedSubstringsCount:(_,f)=>matchedSubstringCount(this.registry.get(f.self),{storage:o=>{if(!o.nativeMatchedStrings)throw new Error('Native matched-string count storage is unavailable');return o.nativeMatchedStrings;}}),
    GetLastAssociateCommand:([id],f)=>{const o=this.registry.get(id??f.self);return o?.objectType===5?o.lastAssociateCommand|0:0;},
    SetListening:([id,value])=>{const o=this.registry.get(id);if(o)o.nativeListening1ec=value|0;},
    SetListenPattern:([id,pattern,number=0])=>this.setListenPattern(this.registry.get(id),pattern,number),
    SetAssociateListenPatterns:([id],f)=>{
      const object=this.registry.get(id??f.self);if(object?.objectType!==5)return;
      for(const entry of associateListenPatterns)this.setListenPattern(object,entry.pattern,entry.id);
    },
    TestStringAgainstPattern:([pattern,text])=>{const expression=new ListenExpression();const result=expression.parse(pattern);
      if(result<0)runtimeDiagnostics.record('engine.listen-pattern-parse-failure',`Native listening expression parse failed (${result})`,{operation:'TestStringAgainstPattern'});
      return expression.test(text,1);},
    GetIsListening:([id])=>{
      const o=this.registry.get(id);if(!o)return 0;
      if(!Number.isInteger(o.nativeListening1ec))throw new Error('Native listening field is unavailable');
      return o.nativeListening1ec|0;
    },
    GetCommandable: ([id],f) => {const o=this.registry.get(id??f.self);return o?o.nativeFieldEc|0:0;},
    SetCommandable: ([value,id],f) => {const o=this.registry.get(id??f.self);if(o?.objectType>4)o.nativeFieldEc=Number((value|0)!==0);},
    GetCurrentAction: ([id]) => this.registry.get(id)?.currentActionId ?? 65535,
    ActionRest:async([seen=0],f)=>{const o=this.registry.get(f.self);if(o?.objectType===5)await this.rest.request(o,0,Number((seen|0)!==0));},
    ForceRest:([id])=>this.rest.force(id),
    GetIsResting:([id])=>{const o=this.registry.get(id);return Number(o?.objectType===5&&(o.activities&16)!==0);},
    GetLastPCRested:()=>this.module?.nativeLastPCRested380??OBJECT_INVALID,
    GetLastRestEventType:()=>this.module?.nativeLastRestEvent384??0,
    // ExecuteCommandAttack 140510e80. The script requests
    // attack actions; it does not directly roll or subtract hit points.
    ActionAttack: async ([id,passive=0],f) => {
      const actor=this.registry.get(f.self);
      if(actor?.objectType===5&&Number(actor.commandable)!==0)
        await this.combat.requestAttack(actor,id,passive,0,0);
    },
    ActionMoveToObject:([id,run=0,range=1],f)=>scriptMoveToObject(this.registry.get(f.self),this.registry.get(id),run,range,0,this.combat.movementProviders()),
    ActionForceFollowObject:([id,distance=0,flags=0],f)=>scriptForceFollow(this.registry.get(f.self),id,distance,flags),
    ActionForceMoveToObject:([id,run=0,range=1,timeout=30],f)=>scriptMoveToObject(this.registry.get(f.self),this.registry.get(id),run,range,timeout,this.combat.movementProviders()),
    ActionMoveToLocation:([location,run=0],f)=>scriptMoveToLocation(this.registry.get(f.self),location,run,0,this.combat.movementProviders()),
    ActionForceMoveToLocation:([location,run=0,timeout=30],f)=>scriptMoveToLocation(this.registry.get(f.self),location,run,timeout,this.combat.movementProviders()),
    ActionWait:([seconds],f)=>scriptWait(this.registry.get(f.self),seconds),
    ActionOpenDoor:([id,run=0],f)=>scriptDoorAction(this.registry.get(f.self),id,run,true,{area:o=>this.registry.get(o.areaId)}),
    ActionCloseDoor:([id,run=0],f)=>scriptDoorAction(this.registry.get(f.self),id,run,false,{area:o=>this.registry.get(o.areaId)}),
    ActionEquipItem:([id,slot],f)=>scriptEquipItem(f.self,id,slot,{creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      item:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},addEquip:(...args)=>this.combat.addEquip(...args)}),
    ActionUnequipItem:([id],f)=>scriptUnequipItem(f.self,id,{creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},
      item:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},addUnequip:(...args)=>this.combat.addUnequip(...args)}),
    ActionPlayAnimation:([id,speed=1,duration=0],f)=>this.scriptAnimation(this.registry.get(f.self),id,speed,duration,false),
    PlayAnimation:([id,speed=1,duration=0],f)=>this.scriptAnimation(this.registry.get(f.self),id,speed,duration,true),
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
    EffectAbilityIncrease:([ability,amount],f)=>abilityEffect(36,ability,amount,f.self,{create:(...args)=>this.effects.create(...args)}),
    EffectAbilityDecrease:([ability,amount],f)=>abilityEffect(37,ability,amount,f.self,{create:(...args)=>this.effects.create(...args)}),
    EffectVisualEffect:(args,f)=>constructVisualEffect(args,f.self,{create:(...args)=>this.effects.create(...args)}),
    EffectBeam:(args,f)=>constructBeamEffect(args,f.self,{create:(...a)=>this.effects.create(...a),invalid:()=>this.effects.invalid(),visualType:id=>this.effects.visualProviders().visualType(id)}),
    EffectBlindness:(_args,f)=>this.effects.create(73,f.self,[16],8),
    EffectDeaf:(_args,f)=>this.effects.create(21,f.self,[],8),
    EffectDispelMagicAll:([level=0],f)=>this.effects.create(51,f.self,[level],8),
    EffectDispelMagicBest:([level=0],f)=>this.effects.create(52,f.self,[level],8),
    EffectDamageShield:([base,die,flags],f)=>this.effects.create(61,f.self,damageShieldIntegers(base,die,flags,this.characterRules.damagetypes.orderedRows.length),8),
    EffectDarkness:(_args,f)=>this.effects.create(74,f.self,[],8),
    EffectSeeInvisible:(_args,f)=>this.effects.create(70,f.self,[],8),
    EffectUltravision:(_args,f)=>this.effects.create(71,f.self,[],8),
    EffectTrueSeeing:(_args,f)=>this.effects.create(72,f.self,[],8),
    EffectAreaOfEffect:(args,f)=>constructAreaEffect(args,f.self,{create:(...args)=>this.effects.create(...args)}),
    GetAreaOfEffectCreator:([id])=>areaEffectCreator(this.registry.get(id)),
    GetFirstInPersistentObject:([id,filter=1,zone=0])=>this.areaEffects.enumerate(true,id,filter,zone),
    GetNextInPersistentObject:([id,filter=1,zone=0])=>this.areaEffects.enumerate(false,id,filter,zone),
    EffectLinkEffects:([left,right],f)=>this.effects.link(left,right,f.self),
    MagicalEffect:([effect])=>this.effects.subtype(effect,112),
    SupernaturalEffect:([effect])=>this.effects.subtype(effect,113),
    ExtraordinaryEffect:([effect])=>this.effects.subtype(effect,114),
    EffectSpellResistanceIncrease:([amount],f)=>this.effects.create(33,f.self,[amount|0],8),
    EffectSpellResistanceDecrease:([amount],f)=>this.effects.create(34,f.self,[amount|0],8),
    EffectSpellLevelAbsorption:([level,budget=0,school=0],f)=>{const valid=(((level|0)+1)>>>0)<=10&&(school>>>0)<=8;return this.effects.create(valid?65:0,valid?f.self:OBJECT_INVALID,valid?[level|0,budget|0,school|0,Number((budget|0)===0)]:[0,0,0,Number((budget|0)===0)],valid?8:0);},
    EffectSpellImmunity:([spell],f)=>{const valid=(spell|0)>=-1&&(spell|0)<=this.characterRules.spells.orderedRows.length;return this.effects.create(valid?50:0,valid?f.self:OBJECT_INVALID,valid?[spell|0]:[],valid?8:0);},
    // ExecuteCommandEffectComplex1405180b0, ordinal133. The constructor
    // retains raw INTs; death application owns their interpretation.
    EffectDeath:([spectacular=0,feedback=1],f)=>this.effects.create(19,f.self,[spectacular|0,feedback|0],8),
    EffectKnockdown:(_,f)=>this.effects.create(20,f.self,[],8),
    EffectHaste:(_,f)=>this.effects.create(1,f.self,[],8),
    EffectSlow:(_,f)=>this.effects.create(3,f.self,[],8),
    EffectSilence:(_,f)=>this.effects.create(46,f.self,[],8),
    EffectInvisibility:([kind=1],f)=>invisibilityEffect(kind,f.self,{create:(...args)=>this.effects.create(...args),invalid:()=>this.effects.invalid()}),
    EffectConcealment:([percent,kind=0],f)=>concealmentEffect(percent,kind,f.self,{create:(...args)=>this.effects.create(...args),invalid:()=>this.effects.invalid()}),
    // VM constructors51a920/51a830 retain the raw INT percent. Admission
    // and conversion to a movement factor belong to the shared handlers.
    EffectMovementSpeedIncrease:([percent],f)=>this.effects.create(28,f.self,[percent|0],8),
    EffectMovementSpeedDecrease:([percent],f)=>this.effects.create(29,f.self,[percent|0],8),
    EffectParalyze:(_,f)=>this.effects.create(8,f.self,[8],8),
    // Dedicated constructor14051ab90 still produces the shared SetState
    // type8/kind15; its apply/remove owners already handle petrification.
    EffectPetrify:(_,f)=>this.effects.create(8,f.self,[15],8),
    EffectPoison:([id],f)=>this.effects.create(35,f.self,[id|0],8),
    EffectDisease:([id],f)=>this.effects.create(5,f.self,[id|0],16),
    EffectRegenerate:([amount,interval],f)=>this.effects.create(7,f.self,[Math.max(0,amount|0),scriptFloatToInt(Math.fround(Math.fround(interval)*1000))],8),
    EffectResurrection:(_,f)=>this.effects.create(4,f.self,[],8),
    EffectNegativeLevel:([amount,bonus=0],f)=>{const valid=(amount|0)<=rulesetInt(this.characterRules,'MAX_NEGATIVE_LEVELS',100),effect=this.effects.create(valid?82:0,valid?f.self:OBJECT_INVALID,valid?[amount|0,bonus|0]:[],valid?8:0);if(valid)effect.durationType=1;return effect;},
    EffectBonusFeat:([id],f)=>{const valid=featInfo(this.characterRules,id)!==null;return this.effects.create(valid?83:0,f.self,valid?[id|0]:[],8);},
    EffectPolymorph:(args,f)=>{const book=this.spellBook;return constructPolymorph(args,f.self,{
      create:(...a)=>this.effects.create(...a),setCreator:(...a)=>this.effects.setCreator(...a),
      creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},hasStats:o=>Boolean(o.stats),
      classType:(o,index)=>creatureRoot(o).ClassList[index&255]?.Class??255,
      featSource:(o,id)=>nativeFeatSourceClass(o,id,message=>book.warning(o,message)),
      classInfo:type=>({get castingAbility(){return book.classAbility(type);},get primaryAbility(){return book.classAbility(type,true);}})});},
    EffectSleep:(_,f)=>this.effects.create(8,f.self,[9],8),
    EffectCharmed:(_,f)=>this.effects.create(8,f.self,[1],8),
    EffectConfused:(_,f)=>this.effects.create(8,f.self,[2],8),
    EffectFrightened:(_,f)=>this.effects.create(8,f.self,[3],8),
    EffectDominated:(_,f)=>this.effects.create(8,f.self,[7],8),
    EffectDazed:(_,f)=>this.effects.create(8,f.self,[5],8),
    EffectStunned:(_,f)=>this.effects.create(8,f.self,[6],8),
    EffectCutsceneImmobilize:(_,f)=>this.effects.create(94,f.self,[],8),
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
    ApplyEffectAtLocation:([duration,effect,location,seconds=0])=>this.effects.applyAtLocation(duration,effect,location,seconds),
    RemoveEffect: ([id, effect], f) => this.effects.requestRemoval(id, effect, f.self),
    GetFirstEffect: ([id]) => this.effects.enumerate(id, true),
    GetNextEffect: ([id]) => this.effects.enumerate(id),
    GetIsEffectValid: ([effect]) => this.effects.valid(effect),
    GetEffectType:([effect,all=0])=>scriptEffectType(effect,all),
    GetEffectCreator: ([effect]) => effect?.creatorId ?? OBJECT_INVALID,
    // ExecuteCommandObjectToString140536fd0 formats raw DWORD with %x;
    // no lookup, padding, prefix or special invalid-object string.
    ObjectToString:([id])=>{if(!Number.isInteger(id))throw new Error('Native ObjectToString DWORD is unavailable');return(id>>>0).toString(16);},
    GetIsImmune:args=>scriptGetIsImmune(args,{creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},immunity:(...args)=>this.combat.immunity(...args)}),
    GetEffectDurationType: ([effect]) => effect?.durationType ?? 0,
    GetEffectSubType: ([effect]) => effect?.subtype ?? 0,
    GetEffectSpellId: ([effect]) => effect?.spellId ?? -1,
    TalentSpell:([id])=>scriptTalent(0,id),
    TalentFeat:([id])=>scriptTalent(1,id),
    TalentSkill:([id])=>scriptTalent(2,id),
    GetIsTalentValid:([talent])=>talentValid(talent),
    GetTypeFromTalent:([talent])=>talentAccess(362,talent),
    GetIdFromTalent:([talent])=>talentAccess(363,talent),
    ActionUseTalentOnObject:Object.assign((args,f)=>this.talents.script(309,args,f),{nativeStack:(vm,f)=>this.talents.scriptStack(309,vm,f)}),
    ActionUseTalentAtLocation:Object.assign((args,f)=>this.talents.script(310,args,f),{nativeStack:(vm,f)=>this.talents.scriptStack(310,vm,f)}),
    GetCreatureTalentBest:([category,maxCR,id],f)=>this.talents.choose(this.registry.get(id??f.self),category,maxCR),
    GetCreatureTalentRandom:([category,id],f)=>this.talents.choose(this.registry.get(id??f.self),category,-1),
    GetCreatureHasTalent:([talent,id],f)=>this.talents.has(this.registry.get(id??f.self),talent),
    GetHasFeatEffect:([feat,id])=>{const o=this.registry.get(id);return o&&o.objectType>=5&&o.objectType<=14?hasFeatEffectApplied(o,feat,this.characterRules):0;},
    GetHasSpellEffect:([spell,id])=>{const o=this.registry.get(id);return o&&o.objectType>=5&&o.objectType<=14?hasSpellEffectApplied(o,spell):0;},
    CreateItemOnObject:([reference,id,stack=1,newTag=''],f)=>this.createItem(reference,id??f.self,stack,newTag),
    GetIdentified:([id])=>{const item=this.registry.get(id);return item?.objectType===6?item.identified|0:0;},
    GetGoldPieceValue:([id])=>scriptItemGoldValue(id,{lookup:id=>this.registry.getGameObject(id),asItem:o=>o?.objectType===6?o:null,price:(...args)=>this.items.price(...args)}),
    GetItemCharges:([id])=>getScriptItemCharges(id,{item:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;}}),
    SetItemCharges:([id,value],f)=>setScriptItemCharges(id,value,f.self,{item:id=>{const o=this.registry.get(id);return o?.objectType===6?o:null;},
      setCharges:(...a)=>this.items.setCharges(...a),activeChanged:(...a)=>this.items.activeChanged(...a),enqueue:(...a)=>this.combat.enqueueEvent(...a)}),
    SetIdentified:([id,value])=>{const item=this.registry.get(id);if(item?.objectType===6)setItemIdentified(item,value);},
    ActionUseSkill:([skill,target,mode=0,item=OBJECT_INVALID],f)=>this.skills.use(this.registry.get(f.self),skill,target,mode,item),
    ActionRandomWalk:(_args,f)=>scriptRandomWalk(this.registry.get(f.self),{position:o=>[o.position[0],-o.position[2],o.position[1]],area:o=>{const a=this.registry.get(o.areaId);return a?.objectType===4?a:null;}}),
    GetArcaneSpellFailure:([id])=>{const o=this.registry.get(id);return o?.objectType===5&&o.stats?arcaneSpellFailure(o):0;},
    GetAbilityModifier:([ability,id])=>{const o=this.registry.get(id);return scriptAbilityModifier(o?.objectType===5?o:null,ability);},
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
    GetHasSpell:([spell,id])=>{const o=this.registry.get(id);return o?.objectType===5?this.spellBook.hasSpell(o,spell):0;},
    GetSpellUsesLeft:([id,classType,spell,meta=0,domain=0],f)=>this.spellBook.scriptUses(id,classType,spell,meta,domain,f),
    GetSpellLevelByClass:([classType,spell],f)=>this.spellBook.scriptLevel(classType,spell,f),
    EventUserDefined: ([number]) => ({ type: 'userDefined', number }),
    EventSpellCastAt:([caster,spell,harmful=1])=>spellCastAtEvent(caster,spell,harmful),
    SignalEvent: ([id, event],f) => {
      const o=this.registry.get(id);if(event.type===2){if(o)this.combat.enqueueEvent(10,this.registry.get(f.self)?f.self:OBJECT_INVALID,id,0,structuredClone(event));return;}
      if(event.type!=='userDefined')throw new Error('This event type is not implemented');if(o)this.queueScript(o.scripts?.userDefined,id,{userDefined:event.number});
    },
    GetUserDefinedEventNumber: (_, f) => this.registry.get(f.self)?.eventObjects.userDefined ?? 0,
    SpeakString: ([text, volume = 0], f) => this.onMessage({ type: 'speech', id: f.self, text, volume }),
    PlayVoiceChat:([code,target=OBJECT_INVALID],f)=>scriptVoiceChat(f.self,code,target,{
      creature:id=>{const o=this.registry.get(id);return o?.objectType===5?o:null;},message:()=>this,
      quickChat:(_m,id,voiceCode)=>sendQuickChatMessage(id,voiceCode,{
        object:id=>this.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,area:o=>this.registry.get(o.areaId)??null,
        players:()=>this.combat.broadcastProviders().clients(),clientObject:client=>client.object,
        send:(client,actorId,code)=>{this.onCombatMessage({type:'quick-chat',recipientId:client.object.id,actorId,code});return 1;}})}),
    PlaySound: ([resRef], f) => {
      const object = this.registry.get(f.self);
      if (object && !['module', 'area'].includes(object.kind) && Number(object.commandable)!==0) this.scheduler.enqueue(object.id, { type: 'playSound', nativeActionId: 23, resRef });
    },
    GetXP: ([id]) => (this.creatureStats(id)?.xp ?? 0) | 0,
    SetXP: ([id, amount]) => this.setExperience(id, amount),
    GiveXPToCreature: ([id, amount]) => this.giveExperience(id, amount),
    GetRacialType: ([id]) => this.creatureStats(id)?.race ?? 28,
    GetIsPlayableRacialType:([id])=>playableRacialType(this.registry.get(id)),
    GetWeaponRanged:([id])=>{
      const item=this.registry.get(id);if(item?.objectType!==6)return 0;
      if(!item.nativeItemLoaded)throw new Error('Native weapon-ranged item state is unavailable');
      const base=this.items.baseInfo(item);if(!base)throw new Error('Native weapon-ranged query dereferences unavailable base storage');return Number(base.ranged!==0);
    },
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
      if (object?.objectType === 5) return object.nativeGold898|0;
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
      return this.equipmentSlot(owner,1 << (slot & 31))?.id??OBJECT_INVALID;
    },
    GetItemPossessor: ([id, immediate = 0]) => {
      const item = this.registry.get(id); if (item?.kind !== 'item') return OBJECT_INVALID;
      const owner = this.registry.get(item.ownerId);
      return !immediate && owner?.kind === 'item' ? owner.ownerId ?? OBJECT_INVALID : item.ownerId ?? OBJECT_INVALID;
    },
    GetPosition: ([id]) => { const p = this.registry.get(id)?.position ?? [0, 0, 0]; return [p[0], -p[2], p[1]]; },
    // LocationAccess140535600, command224: returns stored +18 ID even
    // when the area no longer exists; it performs no registry lookup.
    GetAreaFromLocation: ([location]) => {
      if(!location||!Number.isInteger(location.areaId))throw new Error('Native script location storage is unavailable');
      return location.areaId>>>0;
    },
    GetFirstObjectInShape:(args,frame)=>this.scriptShape(true,args,frame.self),
    cos:([value])=>scriptCos(value),
    sin:([value])=>scriptSin(value),
    log:([value])=>scriptLog(value),
    GetNextObjectInShape:(args,frame)=>this.scriptShape(false,args,frame.self),
    GetAssociate:([type,id,nth=1],frame)=>{const o=this.registry.get(id??frame.self);return scriptGetAssociate(o?.objectType===5?o:null,type,nth,id=>{const c=this.registry.get(id);return c?.objectType===5?c:null;});},
    GetHenchman:([id,nth=1],frame)=>{const o=this.registry.get(id??frame.self);return creatureAssociateId(o?.objectType===5?o:null,1,nth,id=>{const c=this.registry.get(id);return c?.objectType===5?c:null;});},
    GetBaseItemType:([id])=>getItemBaseType(this.registry.get(id)),
    ActionEquipMostDamagingMelee:([target,offhand=0],frame)=>this.selectWeapon(frame.self,target,offhand,false),
    ActionEquipMostDamagingRanged:([target],frame)=>this.selectWeapon(frame.self,target,0,true),
    GetFirstItemInInventory:([id],frame)=>this.scriptInventoryItem(true,id??frame.self),
    GetNextItemInInventory:([id],frame)=>this.scriptInventoryItem(false,id??frame.self),
    // LocationAccess140535600, command223: copies native XYZ (+0..8).
    GetPositionFromLocation: ([location]) => {
      if(!location||!Array.isArray(location.position)||location.position.length!==3||!location.position.every(Number.isFinite))
        throw new Error('Native script location position is unavailable');
      return location.position.map(Math.fround);
    },
    Location:([area,position,facing])=>scriptLocation(area,position,facing),
    GetLocation: ([id]) => scriptObjectLocation(this.registry.get(id)),
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
    SetAreaTransitionBMP:(args,f)=>scriptSetAreaTransitionBmp(args,f.self,{client:this.combat.broadcastProviders().client,setBmp:setAreaTransitionBmp}),
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
    SendMessageToAllDMs: ([text]) => { for (const object of this.registry.objects.values()) if (object.isDM) this.onMessage({ type: 'dm', id: object.id, text }); },
    IntToString: ([value]) => String(value)
  };
}
