"""Scoped release helper for the Turkish project; never prints credentials or student rows."""
import hashlib, json, os, pathlib, sys, urllib.request, urllib.error
PROJECT = 'isgnsmkboehygxxysria'
BASE = 'https://api.supabase.com/v1/projects/' + PROJECT
TOKEN = os.environ.get('SUPABASE_ACCESS_TOKEN', '')
if not TOKEN:
    raise SystemExit('SUPABASE_ACCESS_TOKEN is missing')
def call(path, body=None):
    req=urllib.request.Request(BASE+path, data=None if body is None else json.dumps(body).encode(), headers={'Authorization':'Bearer '+TOKEN,'Content-Type':'application/json'}, method='GET' if body is None else 'POST')
    try:
        with urllib.request.urlopen(req,timeout=90) as response: return json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit('Supabase Management API failed: HTTP '+str(error.code)) from None
def query(sql): return call('/database/query',{'query':sql})
mode=sys.argv[1]
if mode=='inspect':
    report=query("""select current_database() db,
      to_regclass('public.students')::text students,
      to_regclass('public.extra_data')::text extra_data,
      to_regclass('public.dm_turkce_runs')::text turkce_runs,
      to_regclass('supabase_migrations.schema_migrations')::text migration_history,
      to_regprocedure('public.dm_game_reward_claim(uuid,text,text,integer,integer[],integer,integer,numeric,boolean,integer,integer)')::text reward,
      to_regprocedure('public.dm_parkur_question_step(uuid,text,integer,boolean)')::text energy,
      (select count(*) from public.students) student_count,
      (select count(*) from public.extra_data) extra_data_count,
      (select jsonb_agg(jsonb_build_object('column',column_name,'type',data_type)) from information_schema.columns where table_schema='public' and table_name='students' and column_name in ('id','class_no','status','role','energy','energy_max')) student_columns"""
    )
    functions=call('/functions')
    diji=next(({'slug':f.get('slug'),'version':f.get('version'),'verify_jwt':f.get('verify_jwt'),'status':f.get('status')} for f in functions if f.get('slug')=='diji-api'),None)
    print(json.dumps({'project':PROJECT,'schema':report,'diji':diji},ensure_ascii=False))
    if not report or not all(report[0].get(k) for k in ['students','extra_data','reward','energy']):raise SystemExit('Required schema/function missing')
elif mode=='migrate':
    migration=pathlib.Path('supabase/migrations/20261023120000_turkce_tek_parkur.sql').read_text()
    expected='9fb95357e55ba56076a5629b37851191dc6c3412'
    blob=hashlib.sha1(b'blob '+str(len(migration.encode())).encode()+b'\0'+migration.encode()).hexdigest()
    if blob!=expected:raise SystemExit('Migration hash does not match the tested release')
    # A PostgreSQL transaction makes the three-table migration all-or-nothing.
    existing=query("select to_regclass('public.dm_turkce_runs')::text runs")
    if existing[0]['runs'] is None:
        query('begin;\n'+migration+'\ncommit;')
        print('Turkish additive migration applied')
    else:
        print('Turkish tables already exist; checking their security before continuing')
    rows=query("""select c.relname,c.relrowsecurity,
      has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE') anon_access,
      has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE') authenticated_access
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname in ('dm_turkce_runs','dm_turkce_progress','dm_turkce_writing') order by c.relname"""
    )
    if len(rows)!=3 or any(not r['relrowsecurity'] or r['anon_access'] or r['authenticated_access'] for r in rows):raise SystemExit('Turkish table security verification failed')
    funcs=query("""select p.proname,
      has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
      has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
      has_function_privilege('service_role',p.oid,'EXECUTE') service_execute
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('dm_turkce_start','dm_turkce_answer','dm_turkce_writing_save') order by p.proname"""
    )
    if len(funcs)!=3 or any(r['anon_execute'] or r['authenticated_execute'] or not r['service_execute'] for r in funcs):raise SystemExit('Turkish RPC security verification failed')
    print(json.dumps({'tables':rows,'functions':funcs}))
else:
    raise SystemExit('Unknown mode')
