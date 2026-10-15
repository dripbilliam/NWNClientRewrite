const column=(row,name)=>row?.[Object.keys(row??{}).find(key=>key.toLowerCase()===name.toLowerCase())];
// Resolve native AQ enum rows against active actions/spells tables. Physical
// record indices and canonical targets survive empty/special entries.
export function describeActionQueue(records,actions,spells,text){
  if(!actions?.orderedRows)throw new Error('Native action queue actions table is unavailable');
  return records.map((record,index)=>{
    const code=record.action===65535?record.special:record.action;if(code===65535)return null;
    const row=actions.orderedRows[code];if(!row)throw new Error(`Native action queue action row ${code} is unavailable`);
    const str=column(row,'STRING_REF'),label=text?.strRef(Number(str))||column(row,'LABEL')||`Action ${code}`;
    let icon=column(row,'ICONRESREF');
    if((code===4||code===19)&&record.spell>=0){
      const spell=spells?.orderedRows?.[record.spell];if(!spell)throw new Error(`Native queued spell row ${record.spell} is unavailable`);
      icon=column(spell,'IconResRef');
    }
    return{...record,index,code,label,icon:icon&&icon!=='****'?String(icon).toLowerCase():null};
  });
}
