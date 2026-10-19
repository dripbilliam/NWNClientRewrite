// Native party-bar order and resources, shared by both session frontends.
export const GAME_HUD_ACTIONS = Object.freeze([
  ['map','Map','pb_but_map','m'],['inventory','Inventory','pb_but_inv','i'],
  ['journal','Journal','pb_but_jour','j'],['character','Character Sheet','pb_but_char','c'],
  ['rest','Rest','pb_but_rest','r'],['spells','Spellbook','pb_but_spell','b'],
  ['options','Options','pb_but_opts','o'],['pvp','Player versus Player','pb_but_pvp',null]
].map(Object.freeze));
