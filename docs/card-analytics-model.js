(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.CardAnalytics=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const key=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ').replace(/\s*[-–]?\s*\b(?:parcela\s*)?\d{1,2}\s*\/\s*\d{1,2}\s*$/i,'').trim();
function merchant(s){const k=key(s);if(/\buber\b/.test(k)&&!/uber\s*eats/.test(k))return 'Uber';if(/\b99(?:app|pop|taxi)?\b/.test(k))return '99';if(/\bifood\b/.test(k))return 'iFood';if(/\bcobasi\b/.test(k))return 'Cobasi';return k||'Sem identificação';}
function suggest(s,rules,fallback){const k=key(s);return rules.find(r=>r.merchant_key===k)?.category||fallback(s);}
function group(rows,fn){const m=new Map();for(const r of rows){const k=fn(r);m.set(k,(m.get(k)||0)+Number(r.amount_cents));}return [...m].map(([name,value])=>({name,value})).sort((a,b)=>b.value-a.value||a.name.localeCompare(b.name,'pt-BR'));}
const total=rows=>rows.reduce((s,r)=>s+Number(r.amount_cents),0);
function join(items,statements,cards,banks){const sm=new Map(statements.map(s=>[s.id,s])),cm=new Map(cards.map(c=>[c.id,c])),bm=new Map(banks.map(b=>[b.id,b]));return items.filter(i=>i.movement_type!=='payment').flatMap(i=>{const s=sm.get(i.statement_id),c=cm.get(s?.card_id),b=bm.get(c?.bank_id);return s?[{...i,month:s.due_date.slice(0,7),card_id:s.card_id,bank_id:c?.bank_id,bank:b?.name||'Banco não informado',card:c?.name||s.card_name}]:[];});}
function filter(rows,f={}){return rows.filter(r=>(!f.period||r.month.startsWith(f.period))&&(!f.bank||r.bank_id===f.bank)&&(!f.card||r.card_id===f.card)&&(!f.category||r.category===f.category));}
function previous(month){const [y,m]=month.split('-').map(Number);return m===1?`${y-1}-12`:`${y}-${String(m-1).padStart(2,'0')}`;}
function annual(rows,year){return Array.from({length:12},(_,i)=>total(filter(rows,{period:year+'-'+String(i+1).padStart(2,'0')})));}
return {key,merchant,suggest,group,total,join,filter,previous,annual};});
