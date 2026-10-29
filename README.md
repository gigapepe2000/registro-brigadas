# Registro de brigadas

Página web instalable en el móvil para que las brigadas registren sus trabajos. Funciona sin cobertura y sincroniza al recuperar la conexión.

- **Código y publicación:** GitHub (GitHub Pages, Cloudflare Pages o Netlify).
- **Datos, usuarios y permisos:** Supabase.

## Qué hace cada rol

| | Usuario | Administrador |
|---|---|---|
| Ver todos los informes | Sí | Sí |
| Crear informe | Sí | Sí |
| Editar | Solo si es autor o colaborador | Todos |
| Eliminar | Solo el autor | Todos |
| Restaurar eliminados, ver historial | No | Sí |
| Cerrar y reabrir meses | No | Sí |
| Instituciones, usuarios, importar, informe mensual | No | Sí |

Un mes cerrado impide que los usuarios editen sus informes. Los administradores siguen pudiendo.
Los informes nunca se borran de verdad: «eliminar» los oculta y el historial guarda cada cambio.

## Puesta en marcha

### 1. Crear el proyecto en Supabase
1. Crea una cuenta en supabase.com y un proyecto nuevo.
2. Abre **SQL Editor**, pega el contenido de `supabase/schema.sql` y pulsa **Run**.
3. En **Authentication > Users**, crea tu usuario con correo y contraseña (marca *Auto confirm user*).
4. En el SQL Editor, hazte administrador:
   ```sql
   insert into profiles (id, nombre, es_admin)
   select id, 'Tu nombre', true from auth.users where email = 'tu@correo.com';
   ```

### 2. Publicar la función que crea cuentas
Con la [CLI de Supabase](https://supabase.com/docs/guides/cli) instalada:
```bash
supabase login
supabase link --project-ref TU-REF
supabase functions deploy admin-users
```
`TU-REF` es el código que aparece en la URL de tu proyecto.

### 3. Conectar la página
En **Project Settings > API** copia la *Project URL* y la clave *anon public*. Pégalas al inicio del script de `index.html`:
```js
const SB_URL='https://TU-PROYECTO.supabase.co', SB_KEY='TU-CLAVE-ANON-PUBLICA';
```
La clave *anon* es pública por diseño. **Nunca** pongas aquí la clave `service_role`.

### 4. Subir a GitHub y publicar
1. Sube el contenido de esta carpeta a un repositorio.
2. **GitHub Pages:** *Settings > Pages > Deploy from a branch > main*.
   En el plan gratuito exige repositorio público. Eso solo expone el código, no los datos.
   Si prefieres repositorio privado sin pagar, conecta el repositorio a Cloudflare Pages o Netlify.
3. En Supabase, **Authentication > URL Configuration**, añade la dirección publicada como *Site URL*.

### 5. Primer uso
1. Entra con tu cuenta de administrador.
2. En **Configuración**, añade las instituciones y crea las cuentas del equipo.
3. En el móvil, abre la dirección y elige *Añadir a pantalla de inicio*.

## Uso sin cobertura
- Cada persona debe iniciar sesión **una vez con conexión** en su móvil.
- Lo escrito sin señal queda guardado en el teléfono y aparece como «Por enviar».
- Si dos personas editan el mismo informe sin cobertura, prevalece el último en llegar. El historial conserva ambas versiones.
- Si un administrador cierra el mes antes de que llegue un cambio, el servidor lo rechaza y se avisa.
- No cierres sesión con cambios por enviar: se perderían.

## Copias de seguridad
El plan gratuito de Supabase no incluye copias automáticas. Pide a un administrador que use **Exportar JSON** cada mes y guarde el archivo. Ese mismo archivo sirve para **Importar copia**.
El plan gratuito también pausa los proyectos tras una semana sin actividad. Se reactivan desde el panel de Supabase.

## Estructura
```
index.html                 Aplicación completa
sw.js                      Funcionamiento sin conexión
manifest.webmanifest       Instalación en el móvil
supabase/schema.sql        Tablas, permisos, cierre de meses e historial
supabase/functions/admin-users/index.ts   Crear y dar de baja cuentas
```
