// Use the existing native-style radial presenter for assignment. The category
// presentation is local; binding payloads retain native quickbar type fields.
export const quickbarChoiceMenu=(title,entries,action='quickbar.assign')=>({title,entries:[...entries.slice(0,7).map((e,slot)=>({slot,label:e.label,icon:e.icon??'IR_XABILITY',...(e.children?{children:()=>quickbarChoiceMenu(e.label,e.children,action),disabled:!e.children.length}:{action,binding:e.binding})})),
  ...(entries.length>7?[{slot:7,label:'More…',icon:'IR_XABILITY',children:()=>quickbarChoiceMenu(title,entries.slice(7),action)}]:[])]});
export function quickbarAssignmentMenu(title,groups){return {title,entries:[
  ...groups.filter(g=>g.entries.length).map(g=>({slot:g.slot,label:g.label,icon:g.icon,children:()=>quickbarChoiceMenu(g.label,g.entries)})),
  {slot:6,label:'Clear slot',icon:null,action:'quickbar.assign',binding:null}
]};}
