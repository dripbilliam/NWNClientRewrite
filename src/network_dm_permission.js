// Original797ae0/22, dispatched by7a41a0 case31. Field114 and parameter
// remain raw owner names; permission false clears only the current actor's
// native stats110 cache. Permission true is NOT an all-skills override.
export const DM_PERMISSION_SOURCE='received_game_master_permission_31_22';
export const CLIENT_PERMISSION_SOURCE='native_connection_start_16';
export function normalConnectionPermission(connectionType){return connectionType===16?{permission:0,field114:null,parameter:null,source:CLIENT_PERMISSION_SOURCE}:null;}
export function validGameMasterPermission(value){return value?.kind==='game-master-permission'&&[0,1].includes(value.permission)&&[0,1].includes(value.field114)&&Number.isInteger(value.parameter)&&value.parameter>=-2147483648&&value.parameter<=2147483647;}
export function readGameMasterPermission(reader){
 return{kind:'game-master-permission',permission:reader.readBool(),field114:reader.readBool(),parameter:reader.readInt()};
}
