import {parse2da} from '../src/area.js';
import {NetworkSpellbookView} from '../src/network_spellbook_view.js';
import {NetworkQuickbarView} from '../src/network_quickbar_view.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {quickbarChoiceMenu} from '../src/quickbar_menu.js';
import {quickbarAssignmentRequest} from '../src/network_quickbar.js';
import {RadialMenu} from '../src/radial_menu.js';
import {GameUi} from '../src/game_ui.js';
const viewport=document.querySelector('#fixture'),rows=[
 '0 100 family 0 1 1 3 63 1 2 3 4',
 '1 101 good 0 1 **** 3 63 **** **** **** ****',
 '2 102 evil 0 1 **** 3 63 **** **** **** ****',
 '3 103 law 0 1 **** 3 63 **** **** **** ****',
 '4 104 chaos 0 1 **** 3 63 **** **** **** ****',
 '5 105 nested 5 2 2 3 63 6 7 **** ****',
 '6 106 form 5 2 **** 3 63 **** **** **** ****',
 '7 107 subgroup 5 2 **** 3 63 8 9 **** ****',
 '8 108 leaf 5 2 **** 3 63 **** **** **** ****',
 '9 109 leaf2 5 2 **** 3 63 **** **** **** ****',
 ...Array.from({length:40},(_,i)=>`${i+10} ${i+110} ordinary ${i+10} 1 1 3 63 **** **** **** ****`)
];
const names=['Protection from Alignment','Protection from Good','Protection from Evil','Protection from Law','Protection from Chaos','Polymorph Family','Panther','Other Forms','Dragon','Golem',...Array.from({length:40},(_,i)=>'A training spell '+i)];
const tables={spells:parse2da('2DA V2.0\n\nName IconResRef Master Innate Wizard TargetType MetaMagic SubRadSpell1 SubRadSpell2 SubRadSpell3 SubRadSpell4\n'+rows.join('\n')),classes:parse2da('2DA V2.0\n\nName SpellCaster MemorizesSpells SpellbookRestricted SpellTableColumn MinCastingLevel PickDomains Icon\n0 1 1 1 1 Wizard 1 1 wizard\n'),domains:parse2da('2DA V2.0\n\nLevel_1\n0 0\n1 5\n'),ruleset:parse2da('2DA V2.0\n\nValue\n0 0\n'),feat:parse2da('2DA V2.0\n\nFEAT\n'),baseitems:parse2da('2DA V2.0\n\nLabel\n')};
const actor={id:0xffffffff,objectType:5,areaId:1,replicated:{position:[1,2,3],stats:{classes:[{id:0,level:10,domains:[0,1]}]}},playerState:{feats:[12],bonusFeats:[],spellbooks:{0:{known:[0,5,...Array.from({length:40},(_,i)=>i+10)],memorized:{1:[{spell:0,ready:1,domain:0,metamagic:0},null,null],2:[{spell:0,ready:1,domain:1,metamagic:2},null,null],3:[]},usesLeft:{}}},specialAbilities:[{spell:0,level:5,state:1}]}};
const objects=new Map([[actor.id,actor]]),world={localObjectId:actor.id,areaId:1,registry:{objects,get:id=>objects.get(id)},quickbar:Array.from({length:36},()=>({type:0})),party:[],players:new Map(),inventories:new Map()},requests={assign:[],prepare:[],cast:[],family:[]};let generation=1,targeting;
const radial=new RadialMenu(viewport,{onAction:(entry,context)=>{if(entry.action==='quickbar.assign')void quickbar.assign(context.index,entry.binding);if(entry.action==='spell.variant')void targeting.begin(entry.binding);}});
const quickbar=new NetworkQuickbarView(viewport,{world:()=>world,assign:async(index,binding)=>{requests.assign.push({index,binding,packet:[...quickbarAssignmentRequest({index,button:binding})]});world.quickbar[index]=binding??{type:0};},use:binding=>{void targeting.begin(binding);},resolve:async value=>String(value?.strRef??''),inventoryToken:()=>'',canUse:()=>true,menu:(menu,index)=>radial.open(menu,500,350,{index})});
quickbar.tables=tables;quickbar.token='family-fixture';quickbar.assets={skin:async()=>null,dispose:()=>{}};quickbar.host.hidden=false;
const icons=new Map();quickbar.icon=async name=>{if(!icons.has(name)){const canvas=document.createElement('canvas');canvas.width=canvas.height=40;const brush=canvas.getContext('2d');brush.fillStyle=({good:'#778edb',evil:'#9b3d5c',law:'#619c71',chaos:'#b78b38'})[name]??'#5c4d87';brush.fillRect(0,0,40,40);brush.strokeStyle='#efe5c1';brush.strokeRect(3,3,34,34);brush.font='24px serif';brush.fillStyle='#fff4c9';brush.fillText('✦',7,28);icons.set(name,canvas.toDataURL());}return icons.get(name);};quickbar.ruleName=async(table,id)=>table==='spells'?names[id]:'Wizard';
targeting=new NetworkSpellTargeting({world:()=>world,tables:()=>tables,context:()=>({generation}),chooseFamily:async binding=>{requests.family.push(binding);const choice=await quickbar.spellChoice(binding);radial.open(quickbarChoiceMenu(choice.label,choice.children,'spell.variant'),500,350,{});radial.clickMode=true;},submit:async request=>requests.cast.push(request)});
const view=new NetworkSpellbookView({world:()=>world,quickbar,resolve:async()=>'',prepare:async request=>requests.prepare.push(request),close:()=>{}});view.level=1;
const panel=document.createElement('section');panel.className='network-panels';panel.dataset.panel='spells';panel.append(view.host);viewport.append(panel);await view.sync();await quickbar.sync();
window.fixture={view,quickbar,targeting,radial,world,actor,requests,tables,get generation(){return generation;},nextArea:()=>{generation++;world.areaId++;quickbar.token='area-'+generation;},sync:()=>view.sync(true),drag(selector){const source=document.querySelector(selector),data=new DataTransfer();source.dispatchEvent(new DragEvent('dragstart',{bubbles:true,cancelable:true,dataTransfer:data}));this.dragData=data;return Object.fromEntries([...data.types].map(type=>[type,data.getData(type)]));},drop(index){quickbar.slots.children[index].dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:this.dragData}));},dropPreparation(level,slot){view.host.querySelector(`[data-preparation-level="${level}"][data-preparation-slot="${slot}"]`).dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:this.dragData}));},localTree(){const host=document.createElement('div'),owner={session:{characterRules:tables},ruleName:(_t,id)=>names[id],request:(...args)=>requests.cast.push(args),makeQuickbarSource:(node,binding)=>{node.draggable=true;node.dataset.binding=JSON.stringify(binding);}};owner.spellBookChoice=GameUi.prototype.spellBookChoice;owner.spellBookChoice(host,{type:2,intParam:0,classIndex:0,metamagic:2,domainLevel:1},names[0]);return host;},variant(id){return view.host.querySelector(`[data-spell-variant="${id}"]`);},known(id){return view.host.querySelector(`.network-known-spells [data-spell-id="${id}"]`);},dragVariant(id){return this.drag(`[data-spell-variant="${id}"]`);},dragKnown(id){return this.drag(`.network-known-spells [data-spell-id="${id}"]`);},ready:true};
