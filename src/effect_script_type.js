// Complete GetScriptEffectType140423fe0..140424633, target89.8193.37-17.
// These are native engine/public enum translations, independent of whether an
// application owner is implemented. Script cures must recognize every type.
const publicTypes=Object.freeze({
 1:36,2:1,3:37,5:32,7:3,10:40,11:41,12:7,13:42,14:43,15:9,16:44,17:45,18:11,
 21:13,22:15,24:17,25:18,26:50,27:51,28:48,29:49,30:74,31:20,32:21,33:52,34:53,35:31,36:38,37:39,
 45:33,46:34,47:56,48:46,49:47,50:73,51:59,52:69,55:54,56:55,59:90,61:60,62:62,63:81,64:66,65:68,67:86,
 70:65,71:70,72:64,73:67,74:58,75:71,76:72,77:78,79:75,82:61,83:88,85:76,88:77,90:79,92:82,93:83,94:84,96:85,97:87,98:89});
const hiddenTypes=Object.freeze({6:100,19:94,20:98,38:93,39:96,44:99,53:101,57:97,80:95,81:91,84:102});
const states=Object.freeze({1:23,2:24,3:25,4:35,5:28,6:29,7:26,8:27,9:30,15:79,20:80});
export function scriptEffectType(effect,all=0){
 const type=(effect?.type??0)&65535;
 if(type===8){const state=effect.integers?.[0]??0;return states[state]??((all|0)!==0&&state===21?92:0);}
 return publicTypes[type]??((all|0)!==0?hiddenTypes[type]??0:0);
}
