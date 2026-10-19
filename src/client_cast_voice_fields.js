import {creatureRoot} from './creature_rules.js';
import {importCreatureGender} from './creature_appearance_state.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native chant ${n} is unavailable`);return v|0;};

// Local projection of canonical race and the stats->appearance->client chain.
// Load39772d supplies creature+a60 to stats ReadStatsFromGff;41203d copies
// stats A4 to appearance17 (server a77), distinct from phenotype16 (a76).
// Appearance writer4ea838 emits flag4's BYTE, client78055d stores local D0,
// and successful body creation9744ed copies D0 into the live model appearance.
// Outer update flags/packet delivery and full appearance creation are separate.
export function clientCastVoiceFields(actor){
 if(!actor.stats)throw new Error('Native chant source stats are unavailable');
 const root=creatureRoot(actor);
 return{race:(integer(root?.Race,'race WORD')<<16)>>16,gender:importCreatureGender(root,actor.stats.gender)};
}
