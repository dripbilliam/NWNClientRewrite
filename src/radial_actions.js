// Native slot numbers: N, NE, E, SE, S, SW, W, NW. Empty slots stay empty.
const entry = (slot, label, icon, action, extra = {}) => ({ slot, label, icon, action, ...extra });
const menu = (title, entries) => ({ title, entries });
const placeholder = (slot, label, icon, action, system, extra = {}) => entry(slot,label,icon,action,{ system, ...extra });
const associateCommand=(slot,label,icon,command)=>placeholder(slot,label,icon,'associate.command','associate command dispatch',{command});
const choices = (title, values, fallback, system) => {
  if (!values?.length) return menu(title,[placeholder(0,`Select ${title.toLowerCase()}`,fallback.icon,fallback.action,system)]);
  const entries = values.slice(0,7).map((value,slot) => placeholder(slot,value.label,value.icon ?? fallback.icon,value.action ?? fallback.action,system));
  if (values.length > 7) entries.push(entry(7,'More…','IR_XABILITY',null,{ children: () => choices(title,values.slice(7),fallback,system) }));
  return menu(title,entries);
};
const branch = (slot,label,icon,children,extra = {}) => entry(slot,label,icon,null,{ children, ...extra });
const cast = (actor,options) => options.castMenu?.() ?? choices('Spell',actor.spells,{icon:'IR_CAST',action:'spell.select'},'spellcasting');
const specialAttacks = actor => choices('Special attack',actor.specialAttacks,{icon:'IR_XATTACK',action:'combat.selectSpecialAttack'},'combat feats');
const abilities = (actor,options) => options.abilityMenu?.()??choices('Special ability',actor.specialAbilities,{icon:'IR_XABILITY',action:'ability.select'},'character abilities');
const traps = () => menu('Trap',[
  placeholder(0,'Disarm trap','IR_TRAP','trap.disarm','trap rules'),
  placeholder(2,'Recover trap','IR_TRAP','trap.recover','trap rules'),
  placeholder(4,'Set trap','IR_TRAP','trap.set','inventory and trap rules')
]);
const emote = (slot,label,icon,action) => placeholder(slot,label,icon,`emote.${action}`,'emote animation selection');
const finalEmotes = () => menu('More emotes',[
  emote(0,'Fall down forwards','IR_FALLFRONT','fallFront'),emote(2,'Sit on ground','IR_SIT','sit'),
  emote(3,'Meditate','IR_MEDITATE','meditate'),emote(4,'Drink potion','IR_DRINK','drink'),
  emote(5,'Read','IR_READ','read'),emote(6,'Worship','IR_WORSHIP','worship'),emote(7,'Fall down backwards','IR_FALLBACK','fallBack')
]);
const moreEmotes = () => menu('More emotes',[
  emote(0,'Nod','IR_NOD','nod'),emote(1,'Tired','IR_TIRED','tired'),emote(2,'Beg','IR_BEG','beg'),
  emote(3,'Poisoned','IR_WOOSEY','poisoned'),emote(4,'Bored','IR_BORED','bored'),
  emote(5,'Look far','IR_LOOKFAR','lookFar'),emote(6,'Scratch head','IR_SCRATCH','scratch'),
  branch(7,'More emotes','IR_MOREEMOTES',finalEmotes)
]);
const emotes = () => menu('Emote',[
  emote(0,'Bow','IR_BOW','bow'),emote(1,'Threaten','IR_THREATEN','threaten'),emote(2,'Greet','IR_GREET','greet'),
  emote(3,'Laugh','IR_LAUGH','laugh'),emote(4,'Salute','IR_SALUTE','salute'),
  emote(5,'Cheer','IR_CHEER','cheer'),emote(6,'Goodbye','IR_GOODBYE','goodbye'),branch(7,'More emotes','IR_MOREEMOTES',moreEmotes)
]);
const commands = () => menu('Issue command',[
  placeholder(2,'Attack nearest','IR_ATTACKNEAREST','associate.attack','party and associate AI'),
  placeholder(3,'Follow','IR_FOLLOW','associate.follow','party and associate AI'),
  placeholder(4,'Stand ground','IR_STANDGROUND','associate.stand','party and associate AI'),
  placeholder(5,'Guard','IR_GUARD','associate.guard','party and associate AI'),
  placeholder(6,'Heal me','IR_HEALME','associate.heal','party and associate AI'),
  branch(7,'Associate actions','IR_ASSOC_ACTION',() => menu('Associate actions',[
    placeholder(0,'Disarm trap','IR_HAND_TRAP','associate.disarm','party and trap rules'),
    placeholder(1,'Inventory','IR_INVENTORY','associate.inventory','party and inventory'),
    placeholder(7,'Unlock','IR_UNLOCK','associate.unlock','party and lock rules')
  ]))
]);

// Owned-associate child14098f8e0. Physical slots, icons and signed command
// values depend on associate type, not on a particular creature template.
export function buildOwnedAssociateActions(type){
  const command=associateCommand;
  const entries=[placeholder(0,'Examine','IR_EXAMINE','object.examine','object descriptions')];
  if(type===1)entries.push(
    placeholder(3,'Dismiss','IR_KICK','associate.dismissHenchman','henchman removal'),
    command(1,'Unlock','IR_UNLOCK',-18),command(2,'Inventory','IR_INVENTORY',-19),command(4,'Disarm trap','IR_HAND_TRAP',-20),
    command(7,'Search','IR_SEARCH',-23),command(5,'Cast spells','IR_SPELL',-21),command(6,'Stealth','IR_STEALTH',-22));
  else if(type===2)entries.push(command(3,'Unsummon','IR_UNSUMMON',-9),placeholder(7,'Talk','IR_DIALOG','conversation.start','conversations'));
  else if(type===3)entries.push(command(3,'Unsummon','IR_UNSUMMON',-8),placeholder(2,'Possess','IFE_POSSESS','associate.possess','familiar possession'));
  else if(type===4)entries.push(command(3,'Unsummon','IR_UNSUMMON',-10));
  else if(type===5)entries.push(command(3,'Release domination','IR_RELDOM',-12));
  return menu('Associate actions',entries);
}

export function buildGroundRadialActions(actor,options = {}) {
  return menu('Ground',[
    branch(1,'Cast spell','IR_CAST',() => cast(actor,options)),
    placeholder(2,'Move to','IR_MOVETO','movement.moveTo','ground movement requests'),
    branch(3,'More actions','IR_TILEACTION',() => choices('Ground action',actor.groundActions,{icon:'IR_TILEACTION',action:'ground.selectAction'},'ground-targeted actions')),
    branch(6,'Special abilities','IR_XABILITY',() => abilities(actor,options))
  ]);
}

// Simulation handlers re-resolve canonical targets at selection. A live spell
// provider supplies the native class/level tree; unavailable systems stay logged.
export function buildRadialActions(target, actor, options = {}) {
  const title = options.title ?? (target.tag || target.name || target.kind);
  const examine = placeholder(0,'Examine','IR_EXAMINE','object.examine','object descriptions');
  const spell = branch(1,'Cast spell','IR_CAST',() => cast(actor,options));
  if (target.kind === 'door') {
    const open = target.animationState === 1 || target.animationState === 2;
    const destroyed = target.animationState === 3;
    const entries = [examine,{ ...spell, disabled:open || destroyed },
      entry(2,open ? 'Close' : 'Open','IR_OPEN','door.toggle',{ disabled:destroyed || target.usable === false || Boolean(target.animating) }),
      branch(3,'Trap','IR_TRAP',traps,{ disabled:open || destroyed || target.trapped === false }),
      placeholder(5,'Bash','IR_BASH','combat.bash','combat',{ disabled:open || destroyed })];
    if (target.locked || target.lockable !== false) entries.push(placeholder(6,target.locked ? 'Unlock' : 'Lock',target.locked ? 'IR_PICKLOCK' : 'IR_LOCK',target.locked ? 'lock.pick' : 'lock.lock','lock and key rules',{ disabled:open || destroyed }));
    // Keep all mutation actions disabled on a destroyed door.
    return menu(title,entries.map(item => item.slot === 6 ? {...item,disabled:open || destroyed} : item));
  }
  if (target.kind === 'placeable') return menu(title,[examine,spell,
    placeholder(2,'Use','IR_USE','placeable.use','placeable scripts and inventory'),
    branch(3,'Trap','IR_TRAP',traps,{ disabled:target.trapped === false }),
    placeholder(5,'Bash','IR_BASH','combat.bash','combat'),
    {...placeholder(6,target.locked ? 'Unlock' : 'Lock',target.locked ? 'IR_PICKLOCK' : 'IR_LOCK',target.locked ? 'lock.pick' : 'lock.lock','lock and key rules'),disabled:target.lockable === false && !target.locked}
  ].map(item => item.slot === 2 && target.usable === false ? {...item,disabled:true} : item));
  if (target.kind === 'item') return menu(title,[examine,spell,
    placeholder(2,target.equipped ? 'Unequip' : 'Use / equip',target.equipped ? 'IR_UNEQUIP' : 'IR_USE','item.use','inventory and equipment'),
    placeholder(4,target.ownerId === actor.id ? 'Drop' : 'Pick up',target.ownerId === actor.id ? 'IR_DROP' : 'IR_PICKUP',target.ownerId === actor.id ? 'item.drop' : 'item.pickup','inventory'),
    {...placeholder(6,'Split stack','IR_SPLIT','item.split','inventory'),disabled:!(target.stackSize > 1)},
    ...(options.itemUseEntries?.()??[])
  ]);
  const self = target.id === actor.id || target.kind === 'player';
  if (self) return menu(title,[
    placeholder(0,'Character sheet','IR_CHARSHEET','character.sheet','character UI'),spell,
    placeholder(2,'Attack','IR_ATTACK','combat.attack','combat'),branch(3,'Special attacks','IR_XATTACK',() => specialAttacks(actor)),
    ...(actor.nativeField97c!==0&&Number.isInteger(actor.nativeField97c)&&actor.nativeField9f8===0?[entry(4,'Cancel polymorph','IR_SKILLSELF','character.cancelPolymorph')]:[]),
    branch(5,'Issue command','IR_COMMAND',commands),branch(6,'Special abilities','IR_XABILITY',() => abilities(actor,options)),branch(7,'Emote','IR_EMOTES',emotes)
  ]);
  if (target.masterId === actor.id) return menu(title,[
    associateCommand(0,'Heal me','IR_HEALME',-4),spell,
    associateCommand(2,'Attack nearest','IR_ATTACKNEAREST',-3),
    associateCommand(3,'Follow','IR_FOLLOW',-5),
    associateCommand(4,'Stand ground','IR_STANDGROUND',-2),
    associateCommand(5,'Guard','IR_GUARD',-7),branch(6,'Special abilities','IR_XABILITY',() => abilities(actor,options)),branch(7,'Associate actions','IR_ASSOC_ACTION',()=>buildOwnedAssociateActions(target.associateType&65535))
  ]);
  return menu(title,[examine,spell,placeholder(2,'Attack','IR_ATTACK','combat.attack','combat'),
    branch(3,'Special attacks','IR_XATTACK',() => specialAttacks(actor)),
    placeholder(4,'Animal empathy','isk_aniemp','skill.animalEmpathy','skill rules'),
    placeholder(5,'Pick pocket','isk_pocket','skill.pickPocket','skill rules'),
    branch(6,'Special abilities','IR_XABILITY',() => abilities(actor,options)),placeholder(7,'Talk','IR_DIALOG','conversation.start','conversations')
  ]);
}

export function radialHit(dx,dy,scale = 1) {
  if (!(scale > 0)) throw new Error('Invalid radial scale');
  const radiusSquared = Math.round((dx*dx + dy*dy)/(scale*scale));
  // DOM y points down; native GUI/model y points up.
  const octant = ((Math.floor((Math.PI/2 - Math.atan2(-dy,dx))/(2*Math.PI)*8 + 0.5) % 8) + 8) % 8;
  const zone = radiusSquared <= 400 ? 'center' : radiusSquared <= 3136 ? 'cancel' : radiusSquared <= 22500 ? 'select' : radiusSquared <= 90000 ? 'submenu' : 'exit';
  return { octant,zone,radiusSquared };
}

export function radialActionRequest(entry,target,actor,groundPoint = null) {
  return { action:entry.action,targetId:target.id,actorId:actor.id,areaId:target.areaId,
    label:entry.label,system:entry.system ?? null,groundPoint };
}
