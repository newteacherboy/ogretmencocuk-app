"""Build both games exclusively from the reviewed grade-five topic bank."""
import hashlib,json,re
from pathlib import Path
public=[]; private=[]
goals={'isim-fiil':'İsim ve fiil içeren örnek cümleyi kur.','ismi-niteleyen':'İsmi niteleyen sözcüğü içeren cümleyi kur.','sifat-fiil':'İsmi betimleyen fiilimsi örneğini kur.','tahmin':'Tahmin bildiren örnek cümleyi kur.','ekleme':'Yeni bilgi ekleyen örnek cümleyi kur.','amac':'Amaç bildiren örnek cümleyi kur.','duygu':'Duygu bildiren örnek cümleyi kur.','karsilastirma':'Karşılaştırma bildiren örnek cümleyi kur.','zaman-baglac':'Olayları zaman sırasıyla bağlayan örneği kur.','ornek':'Örneklendirme bildiren cümleyi kur.'}
for f in sorted(Path('content/turkce/5-sinif').glob('tema-*.json')):
 theme=json.loads(f.read_text())
 for lesson in theme['konular']:
  lid=lesson['kod']; slug=lid.split('-',2)[2]; hunt=[]; workshop=[]
  for q in lesson['testler']:
   hunt.append(dict(id=q['id'],prompt=q['soru'],choices=q['secenekler']+(['Hiçbiri'] if len(q['secenekler'])==3 and 'Hiçbiri' not in q['secenekler'] else []),answer=q['dogru'],explanation=q['aciklama']))
   answer=q['dogru']; quoted=re.findall('“([^”]+)”',q['soru']); joiner=' '
   if slug in ('hece','kisa-cizgi'):
    parts=answer.split('-');joiner='-';prompt='“'+(quoted[0] if quoted else 'kelime')+'” sözcüğünün hecelerini sırayla yerleştir.'
   elif slug=='kesme' and ' ' not in answer and "'" in answer:
    word,suffix=answer.split("'",1);parts=[word,"'"+suffix];joiner='';prompt='Özel adı ve ekini doğru kesme işaretiyle birleştir.'
   else:
    target=answer
    if len(answer.split())<3 and quoted and len(quoted[0].split())>=3:
     target=quoted[0]
     if target[-1] not in '.!?…':target+='.'
    elif len(answer.split())==1 and quoted:
     target='“'+quoted[0]+'” '+answer+' olarak adlandırılır.'
    prompt=goals.get(slug,'Konu kuralına uygun örneği parçalarıyla kur.')
    words=target.split();size=max(1,(len(words)+3)//4);parts=[' '.join(words[i:i+size]) for i in range(0,len(words),size)]
   if len(parts)<2:
    # A complete, reviewed rule gives single-word answers a meaningful construction.
    words=q['aciklama'].split();size=max(1,(len(words)+3)//4);parts=[' '.join(words[i:i+size]) for i in range(0,len(words),size)];joiner=' '
   assert 2<=len(parts)<=6,(lid,q['id'],parts)
   tiles=[dict(id=hashlib.sha256((q['id']+str(i)+s).encode()).hexdigest()[:12],text=s) for i,s in enumerate(parts)]
   workshop.append(dict(id=q['id']+'-build',prompt=prompt,tiles=tiles,slots=len(parts),joiner=joiner,answer=joiner.join(parts),explanation=q['aciklama'],context=q['soru']))
  public.append(dict(id=lid,title=lesson['ad'],theme=theme['tema'],themeTitle=theme['temaAdi']))
  for kind,questions in [('hunt',hunt),('workshop',workshop)]:
   assert len(questions)>=8
   private.append((lid,kind,questions))
quote=lambda s:"'"+s.replace("'","''")+"'"
Path('content/turkce/topic-games.json').write_text(json.dumps(dict(grade=5,lessons=public),ensure_ascii=False,indent=2)+'\n')
Path('supabase/member-release/topic-games-catalog.sql').write_text('-- Generated from reviewed topic questions by tools/build-topic-games.py.\ninsert into turkce_private.topic_game_catalog(lesson_id,kind,questions) values\n'+',\n'.join('('+quote(lid)+','+quote(kind)+','+quote(json.dumps(qs,ensure_ascii=False))+'::jsonb)' for lid,kind,qs in private)+'\non conflict(lesson_id,kind) do update set questions=excluded.questions;\n')
print(len(public),'topics;',len(private),'games;',sum(len(qs) for _,_,qs in private),'game questions')
