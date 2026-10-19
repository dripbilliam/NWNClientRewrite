// Use the existing native-style radial presenter for assignment. The category
// presentation is local; binding payloads retain native quickbar type fields.
const choices=(title,entries)=>({title,entries:[...entries.slice(0,7).map((e,slot)=>({slot,label:e.label,icon:e.icon??'IR_XABILITY',action:'quickbar.assign',binding:e.binding})),
  ...(entries.length>7?[{slot:7,label:'More…',icon:'IR_XABILITY',children:()=>choices(title,entries.slice(7))}]:[])]});
export function quickbarAssignmentMenu(title,groups){return {title,entries:[
  ...groups.filter(g=>g.entries.length).map(g=>({slot:g.slot,label:g.label,icon:g.icon,children:()=>choices(g.label,g.entries)})),
  {slot:6,label:'Clear slot',icon:null,action:'quickbar.assign',binding:null}
]};}
