(()=>{'use strict';
const root=document.getElementById('memberSocial'),status=document.getElementById('socialStatus');if(!root)return;
const member=window.turkceMember;let selected='feed',generation=0;
const el=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e;};
const date=s=>new Intl.DateTimeFormat('tr-TR',{dateStyle:'medium',timeStyle:'short',timeZone:'Europe/Istanbul'}).format(new Date(s));
function button(text,fn){const b=el('button',text);b.type='button';b.className='social-action';b.addEventListener('click',async()=>{b.disabled=true;try{await fn();}catch(e){status.textContent=e.message;}finally{b.disabled=false;}});return b;}
function picture(name){const pic=el('img');pic.className='friend-character';pic.dataset.characterUser=name;pic.src='avatar-assets/head-boy-v3.webp';pic.alt='';return pic;}
async function load(){const token=++generation;status.textContent='Arkadaşların hazırlanıyor…';await member.ready;if(!member.data){status.textContent='Arkadaşların için hesabına giriş yap.';return;}try{
 const [social,feed]=await Promise.all([member.request('social'),member.featuresRequest('social')]);if(token!==generation)return;
 root.replaceChildren();status.textContent='';
 const tabs=el('div');tabs.className='social-tabs';tabs.setAttribute('aria-label','Arkadaşlar görünümü');for(const [key,title]of [['feed','✨ Akış'],['friends','👥 Arkadaşlarım']]){const b=button(title,async()=>{selected=key;await load();});b.setAttribute('aria-pressed',String(selected===key));tabs.append(b);}tabs.append(button('↻ Yenile',load));root.append(tabs);
 if(selected==='friends'){
 const form=el('form');form.className='social-add';const input=el('input');input.placeholder='Arkadaşının kullanıcı adı';input.required=true;input.minLength=3;input.maxLength=20;input.setAttribute('aria-label','Arkadaşının kullanıcı adı');const submit=el('button','İstek gönder');submit.type='submit';form.append(input,submit);form.addEventListener('submit',async e=>{e.preventDefault();submit.disabled=true;try{await member.request('friend_request',{username:input.value.trim()});await load();status.textContent='Arkadaşlık isteğin gönderildi.';}catch(error){status.textContent=error.message;}finally{submit.disabled=false;}});root.append(form);
 if(!social.friends.length){const empty=el('p','Birlikte öğrenmek daha güzel! Kullanıcı adıyla ilk arkadaşını ekle.');empty.className='social-empty';root.append(empty);}
 for(const f of social.friends){const row=el('article');row.className='social-card social-friend';row.append(picture(f.username),el('strong',f.username),el('small',f.accepted?(f.online?'● Çevrimiçi':'Arkadaşın'):f.incoming?'Gelen istek':'İstek gönderildi'));if(!f.accepted&&f.incoming)row.append(button('Kabul et',async()=>{await member.request('friend_accept',{user_id:f.id});await load();}));row.append(button(f.accepted?'Arkadaşlıktan çıkar':'İsteği kaldır',async()=>{await member.request('friend_remove',{user_id:f.id});await load();}));root.append(row);}
 }else{
 if(!feed.feed.length){const empty=el('div');empty.className='social-empty';empty.append(el('h3','Birlikte başarıyoruz!'),el('p','Senin ve arkadaşlarının paylaşılan parkur, oyun ve ders başarıları burada görünecek.'),button('Arkadaş ekle',async()=>{selected='friends';await load();}));root.append(empty);}
 for(const item of feed.feed){const row=el('article');row.className='social-card';const header=el('header');header.append(picture(item.username),el('strong',item.self?'Sen · '+item.username:item.username));const time=el('time',date(item.created_at));time.dateTime=item.created_at;header.append(time);const footer=el('footer');let liked=item.liked;const react=button((liked?'♥ Beğendin':'♡ Beğeni gönder')+' · '+item.likes,async()=>{const r=await member.featuresRequest('like',{activity_id:item.id,liked:!liked});liked=r.liked;react.textContent=(liked?'♥ Beğendin':'♡ Beğeni gönder')+' · '+r.likes;react.setAttribute('aria-pressed',String(liked));status.textContent=liked?'Beğenin gönderildi.':'Beğenin geri alındı.';});react.setAttribute('aria-pressed',String(liked));footer.append(react);row.append(header,el('p',item.description),footer);root.append(row);}
 }
 window.turkceCharacters?.decorate(root);window.turkceCharacters?.lookup([...social.friends.map(f=>f.username),...feed.feed.map(f=>f.username)]).catch(()=>{});
 }catch(e){if(token===generation)status.textContent=e.message;}}
document.querySelector('[data-view=friendsView]')?.addEventListener('click',()=>load());
window.addEventListener('member-state',e=>{if(!e.detail){generation++;root.replaceChildren();status.textContent='';}});
})();
