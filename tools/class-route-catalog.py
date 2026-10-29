import json
from pathlib import Path
rows=[]
for grade in [6,7,8]:
 bank=json.loads(Path(f'supabase/functions/diji-api/turkce-bank-{grade}.json').read_text());position=0
 for theme in bank['themes']:
  for a in theme['activities']:
   position+=1
   payload={'id':a['id'],'title':a['title'],'theme':theme['title'],'kind':a['kind'],'body':a.get('body'),'questions':[{'id':q['id'],'prompt':q['soru'],'choices':q['secenekler'],'answer':q['dogru'],'explanation':q['aciklama']} for q in a['questions']]}
   rows.append((grade,a['id'],position,payload))
quote=lambda s:"'"+s.replace("'","''")+"'"
Path('supabase/member-release/class-route-catalog.sql').write_text('insert into turkce_private.class_route_catalog(grade,activity_id,position,payload) values\n'+',\n'.join(f'({g},{quote(a)},{pos},{quote(json.dumps(p,ensure_ascii=False))}::jsonb)' for g,a,pos,p in rows)+'\non conflict(activity_id) do update set grade=excluded.grade,position=excluded.position,payload=excluded.payload;\n')
print(len(rows),'class-route stops from the reviewed 6–8 banks')
