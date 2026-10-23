/* Local economy preview only; server must validate economy before online release. */
(function(){
"use strict";
const KEY="ogretmencocuk_practice_economy_v1",TIMEZONE="Europe/Istanbul";
const today=()=>new Intl.DateTimeFormat("en-CA",{timeZone:TIMEZONE,year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
const initial=()=>({day:today(),used:0,xp:0,gold:0,awarded:[]});
function load(){try{const s=JSON.parse(localStorage.getItem(KEY)||"null");if(!s||typeof s!=="object")return initial();return {day:String(s.day||today()),used:Math.max(0,Math.min(30,Number(s.used)||0)),xp:Math.max(0,Number(s.xp)||0),gold:Math.max(0,Number(s.gold)||0),awarded:Array.isArray(s.awarded)?s.awarded.filter(x=>typeof x==="number"):[]}}catch{return initial()}}
let data=load();
function persist(){try{localStorage.setItem(KEY,JSON.stringify(data))}catch{}window.dispatchEvent(new CustomEvent("practice-rewards-changed"))}
function snapshot(){if(data.day!==today()){data.day=today();data.used=0;persist()}return {energy:30-data.used,xp:data.xp,gold:data.gold,level:level(data.xp)}}
function nextLevelCost(currentLevel){
 if(currentLevel<1||currentLevel>=40)return Infinity;
 if(currentLevel<10)return 150+currentLevel*90;
 if(currentLevel<20)return 900+(currentLevel-10)*180;
 if(currentLevel<30)return 2800+(currentLevel-20)*420;
 const n=currentLevel-29;
 return 7000+2500*n*n; // Level 30→31: 9,500 XP; 39→40: 257,000 XP.
}
function level(xp){let n=1,remaining=Math.max(0,xp);while(n<40){const requirement=nextLevelCost(n);if(remaining<requirement)break;remaining-=requirement;n++}return n}
function spend(){if(snapshot().energy<1)return false;data.used++;persist();return true}
function award(stop,correct,wrong,elapsed,total){
 if(data.awarded.includes(stop))return {xp:0,gold:0,repeat:true};
 const accuracy=total?Math.max(0,Math.min(1,correct/total)):0;
 const speed=Math.max(.5,Math.min(1,1-Math.max(0,elapsed-90000)/600000));
 const penalty=Math.max(.5,1-Math.max(0,wrong)*.07);
 const ratio=accuracy*speed*penalty;
 const xp=Math.min(140,Math.round(140*ratio)),gold=Math.min(80,Math.round(80*ratio));
 data.xp+=xp;data.gold+=gold;data.awarded.push(stop);persist();return {xp,gold,repeat:false};
}
window.practiceEconomy={snapshot,spend,award,level,nextLevelCost};
})();