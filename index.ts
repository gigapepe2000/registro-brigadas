import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (o: unknown, s = 200) =>
  new Response(JSON.stringify(o), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const token = (req.headers.get('Authorization') || '').replace('Bearer ', '');
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return json({ error: 'No has iniciado sesión' }, 401);
  const { data: p } = await admin.from('profiles').select('es_admin,activo').eq('id', user.id).single();
  if (!p?.es_admin || !p.activo) return json({ error: 'Solo los administradores pueden hacer esto' }, 403);

  const b = await req.json();
  if (b.action === 'crear') {
    const { data, error } = await admin.auth.admin.createUser({ email: b.email, password: b.password, email_confirm: true });
    if (error) return json({ error: error.message }, 400);
    await admin.from('profiles').insert({ id: data.user.id, nombre: b.nombre, es_admin: !!b.es_admin });
    return json({ ok: true });
  }
  if (b.action === 'baja' || b.action === 'alta') {
    if (b.id === user.id) return json({ error: 'No puedes darte de baja a ti mismo' }, 400);
    const baja = b.action === 'baja';
    await admin.auth.admin.updateUserById(b.id, { ban_duration: baja ? '876000h' : 'none' });
    await admin.from('profiles').update({ activo: !baja }).eq('id', b.id);
    return json({ ok: true });
  }
  return json({ error: 'Acción no válida' }, 400);
});
