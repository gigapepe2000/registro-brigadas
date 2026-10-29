-- Pega este archivo completo en Supabase > SQL Editor y pulsa Run.

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  nombre text not null,
  es_admin boolean not null default false,
  activo boolean not null default true
);

create table instituciones (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  activa boolean not null default true
);

create table meses_cerrados (mes date primary key); -- siempre el día 1 del mes

create table informes (
  id uuid primary key default gen_random_uuid(),   -- lo genera el móvil, así funciona sin cobertura
  fecha date not null,
  institucion_id uuid not null references instituciones(id),
  tipo text not null check (tipo in ('mantenimiento','averia')),
  descripcion text not null,
  autor uuid not null references profiles(id),
  colaboradores uuid[] not null default '{}',
  borrado boolean not null default false,
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);

create table historial (
  id bigserial primary key,
  informe_id uuid not null,
  usuario uuid,
  accion text not null,
  antes jsonb,
  despues jsonb,
  cuando timestamptz not null default now()
);

-- Funciones auxiliares
create function es_admin() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce((select es_admin and activo from profiles where id = auth.uid()), false) $$;

create function mes_cerrado(d date) returns boolean language sql stable security definer set search_path = public as
$$ select exists (select 1 from meses_cerrados where mes = date_trunc('month', d)::date) $$;

-- Reglas que no se pueden saltar desde la página
create function informes_guard() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not es_admin() then
    if tg_op = 'UPDATE' then
      if new.autor <> old.autor then raise exception 'No se puede cambiar el autor'; end if;
      if new.borrado <> old.borrado and old.autor <> auth.uid() then
        raise exception 'Solo el autor o un administrador puede eliminar'; end if;
      if mes_cerrado(old.fecha) or mes_cerrado(new.fecha) then raise exception 'Mes cerrado'; end if;
    else
      if mes_cerrado(new.fecha) then raise exception 'Mes cerrado'; end if;
    end if;
  end if;
  new.actualizado := now();
  return new;
end $$;
create trigger t_guard before insert or update on informes for each row execute function informes_guard();

create function informes_hist() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into historial (informe_id, usuario, accion, antes, despues)
  values (new.id, auth.uid(),
    case when tg_op = 'INSERT' then 'creado'
         when new.borrado and not old.borrado then 'eliminado'
         when old.borrado and not new.borrado then 'restaurado'
         else 'editado' end,
    case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;
create trigger t_hist after insert or update on informes for each row execute function informes_hist();

-- Permisos por fila
alter table profiles enable row level security;
alter table instituciones enable row level security;
alter table meses_cerrados enable row level security;
alter table informes enable row level security;
alter table historial enable row level security;

create policy "ver perfiles" on profiles for select to authenticated using (true);
create policy "admin perfiles" on profiles for update to authenticated using (es_admin()) with check (es_admin());

create policy "ver instituciones" on instituciones for select to authenticated using (true);
create policy "admin instituciones" on instituciones for all to authenticated using (es_admin()) with check (es_admin());

create policy "ver meses" on meses_cerrados for select to authenticated using (true);
create policy "admin meses" on meses_cerrados for all to authenticated using (es_admin()) with check (es_admin());

create policy "ver informes" on informes for select to authenticated using (not borrado or es_admin());
create policy "crear informes" on informes for insert to authenticated with check (es_admin() or autor = auth.uid());
create policy "editar informes" on informes for update to authenticated
  using (es_admin() or (not borrado and (autor = auth.uid() or auth.uid() = any (colaboradores))))
  with check (true);
-- No hay política de borrado: los informes nunca se eliminan de verdad.

create policy "ver historial" on historial for select to authenticated using (es_admin());

-- Primer administrador: crea su usuario en Authentication > Users y luego ejecuta:
-- insert into profiles (id, nombre, es_admin) select id, 'Tu nombre', true from auth.users where email = 'tu@correo.com';
