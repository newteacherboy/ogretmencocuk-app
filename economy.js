/* Local economy preview. Never trust these values for public ranking or auth. */
(function(){
"use strict";
const KEY="ogretmencocuk_practice_economy_v1";
const MAX=30,REFILL_MS=30*60*1000,GIFT_MS=24*60*60*1000;
const today=()=>new Intl.DateTimeFormat("en-CA",{timeZone:"Europe/Istanbul",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
const now=()=>Date.now();
const finite=(x,fallback=0)=>Number.isFinite(Number(x))?Number(x):fallback;
const clamp=(x,min,max)=>Math.min(max,Math.max(min,x));
function load(){
 let raw=null;try{raw=JSON.parse(localStorage.getItem(KEY)||"null")}catch{}
 const t=now();
 if(!raw||typeof raw!=="object")return {day:today(),energy:MAX,lastRefillAt:t,lastGiftAt:t,xp:0,gold:0,awarded:[],games:[]};
 const energy=raw.energy!==undefined?clamp(finite(raw.energy,MAX),0,MAX):clamp(MAX-finite(raw.used,0),0,MAX);
 return {day:today(),energy,lastRefillAt:clamp(finite(raw.lastRefillAt,t),0,t),lastGiftAt:clamp(finite(raw.lastGiftAt,t),0,t),xp:Math.max(0,finite(raw.xp)),gold:Math.max(0,finite(raw.gold)),awarded:Array.isArray(raw.awarded)?raw.awarded:[],games:Array.isArray(raw.games)?raw.games:[]};
}
let data=load();
function persist(){try{localStorage.setItem(KEY,JSON.stringify(data))}catch{}window.dispatchEvent(new CustomEvent("practice-rewards-changed"))}
function reconcile(){
 const t=now(),current=today();let changed=false;
 if(data.day!==current){data.day=current;changed=true}
 if(data.lastRefillAt>t){data.lastRefillAt=t;changed=true}
 if(data.lastGiftAt>t){data.lastGiftAt=t;changed=true}
 if(data.energy>=MAX){/* Full: no pending refill, do not emit repeat change events. */}
 else{
  const elapsed=t-data.lastRefillAt,steps=Math.floor(elapsed/REFILL_MS);
  if(steps>0){data.energy=clamp(data.energy+steps,0,MAX);data.lastRefillAt=data.energy>=MAX?t:data.lastRefillAt+steps*REFILL_MS;changed=true}
 }
 if(changed)persist();
}
function claimLoginGift(){
 reconcile();
 const t=now();
 if(t-data.lastGiftAt<GIFT_MS)return 0;
 const before=data.energy;
 data.energy=Math.min(MAX,data.energy+5);
 data.lastGiftAt=t;persist();
 return data.energy-before;
}
function snapshot(){
 reconcile();
 const t=now();
 return {energy:data.energy,xp:data.xp,gold:data.gold,level:level(data.xp),nextEnergySeconds:data.energy>=MAX?0:Math.ceil((REFILL_MS-(t-data.lastRefillAt))/1000),nextGiftSeconds:Math.max(0,Math.ceil((GIFT_MS-(t-data.lastGiftAt))/1000))};
}
function nextLevelCost(currentLevel){
 if(currentLevel<1||currentLevel>=40)return Infinity;
 if(currentLevel<10)return 150+currentLevel*90;
 if(currentLevel<20)return 900+(currentLevel-10)*180;
 if(currentLevel<30)return 2800+(currentLevel-20)*420;
 const n=currentLevel-29;
 return 7000+2500*n*n; // Level 30→31: 9,500 XP; 39→40: 257,000 XP.
}
function level(xp){let n=1,remaining=Math.max(0,xp);while(n<40){const requirement=nextLevelCost(n);if(remaining<requirement)break;remaining-=requirement;n++}return n}


function spend(amount=1){
 reconcile();if(data.energy<amount)return false;
 const wasFull=data.energy===MAX;
 data.energy-=amount;
 if(wasFull)data.lastRefillAt=now();
 persist();return true;
}
function awardGame(gameId,correct,wrong,elapsed,total){
 // Max one reward per game each day; prevents infinite XP from replaying the same game.
 reconcile();
 const key=data.day+":"+String(gameId);
 if(data.games.includes(key))return {xp:0,gold:0,repeat:true};
 const accuracy=total?Math.max(0,Math.min(1,correct/total)):0;
 const speed=Math.max(.4,Math.min(1,1-Math.max(0,elapsed-75000)/480000));
 const penalty=Math.max(.4,1-Math.max(0,wrong)*.08);
 const factor=accuracy*speed*penalty;
 const xp=Math.min(70,Math.round(70*factor)),gold=Math.min(30,Math.round(30*factor));
 data.xp+=xp;data.gold+=gold;data.games.push(key);persist();
 return {xp,gold,repeat:false};
}
function spendGame(){return spend(3)}
function award(stop,correct,wrong,elapsed,total){
 if(data.awarded.includes(stop))return {xp:0,gold:0,repeat:true};
 const accuracy=total?Math.max(0,Math.min(1,correct/total)):0;
 const speed=Math.max(.5,Math.min(1,1-Math.max(0,elapsed-90000)/600000));
 const penalty=Math.max(.5,1-Math.max(0,wrong)*.07);
 const ratio=accuracy*speed*penalty;
 const xp=Math.min(140,Math.round(140*ratio)),gold=Math.min(80,Math.round(80*ratio));
 data.xp+=xp;data.gold+=gold;data.awarded.push(stop);persist();return {xp,gold,repeat:false};
}

window.practiceEconomy={snapshot,claimLoginGift,spend,spendGame,award,awardGame,level,nextLevelCost};
window.practiceEconomy.loginGiftReceived=claimLoginGift();
})();
