// A bounded live ring, independent of the retained integration report limit.
// Only diagnostic text is projected, never arbitrary context/credential objects.
class LiveDiagnostics{
 constructor(){this.rows=[];}
 record(value){const code=String(value.code??'').slice(0,128),reason=String(value.reason??'').slice(0,800),last=this.rows.at(-1);if(last&&last.code===code&&last.reason===reason){last.count++;last.at=Date.now();return;}this.rows.push({code,reason,count:1,at:Date.now()});if(this.rows.length>128)this.rows.shift();}
 snapshot(){return this.rows.slice(-64).map(row=>({...row}));}
}
module.exports={LiveDiagnostics};
