# PriceSec

Propietario del proyecto/producto: **JULIAN C. PAREDES (SHAWNDARCK)**.

PriceSec es una app Flutter Web local para:

- Comparar publicaciones de AliExpress, Temu, Shein y Amazon.
- Usar sesiones ya iniciadas en un perfil local de Chrome.
- Registrar compras/importaciones con calculos basados en Excel.
- Guardar, listar, editar y eliminar registros de compra.
- Registrar analisis de viabilidad AliExpress desde una seccion independiente.
- Registrar inventario por producto y bodega.
- Registrar ventas descontando inventario automaticamente.
- Buscar y paginar registros guardados para evitar listas infinitas.
- Proteger la app con login, registro inicial de super admin y recuperacion de contraseña.
- Consultar automaticamente la TRM USD -> COP desde una API gratuita.
- Cambiar entre dos visuales: `Vista Cyber` y `Vista Neo`.
- Navegar desde el modulo `Sistema de Gestion`, organizado por categorias.

El proyecto corre localmente. No es una app desplegada en internet.

Todas las visuales muestran un footer de propiedad:

```text
Este programa es propiedad de JULIAN C. PAREDES (SHAWNDARCK)
```

## Estructura Principal

```text
lib/main.dart                         UI principal, pestanas, formularios y formulas
lib/platform/product_search_web.dart  Cliente web para comparar tiendas
lib/platform/purchase_api_web.dart    Cliente web para compras, viabilidades, SQLite y respaldo local
scripts/price_search_server.mjs       Backend local Node: scraping, TRM, CRUD y SQLite
scripts/start_pricesec.ps1            Script para iniciar el backend local
pricesec.db                           Base SQLite local, se crea automaticamente
.pricesec-chrome-profile/             Perfil Chrome persistente para sesiones de tiendas
```

## Requerimientos

Para ejecutar PriceSec localmente desde un repo nuevo:

- Windows con PowerShell.
- Flutter instalado y disponible en `PATH`.
- Node.js instalado y disponible en `PATH`.
- Chrome o Edge instalado.
- Git recomendado para clonar/actualizar el repo.

Versiones usadas durante el desarrollo:

```text
Flutter 3.41.x
Dart 3.11.x
Node.js con soporte para node:sqlite
```

## Puertos

```text
Backend local PriceSec: http://localhost:8768
Flutter Web sugerido:  http://localhost:5036
Chrome debug:          9222
```

Si un puerto esta ocupado, puedes usar otro para Flutter, pero el backend debe quedar en `8768` porque el front lo usa directamente.

## Como Levantar El Proyecto

1. Clona o descarga el repo de JULIAN C. PAREDES (SHAWNDARCK).

2. Abre PowerShell en la carpeta del proyecto:

```powershell
cd C:\ruta\donde\descargaste\PriceSec
```

3. Descarga dependencias Flutter:

```powershell
flutter pub get
```

4. Inicia el backend local:

```powershell
.\scripts\start_pricesec.ps1
```

Este proceso debe quedarse abierto. Sirve:

- `GET /health`
- `GET /trm`
- `GET /auth/status`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/reset/request`
- `POST /auth/reset/confirm`
- `GET /auth/me`
- `GET /purchases`
- `POST /purchases`
- `PUT /purchases/:id`
- `DELETE /purchases/:id`
- `GET /aliexpress-viabilities`
- `POST /aliexpress-viabilities`
- `PUT /aliexpress-viabilities/:id`
- `DELETE /aliexpress-viabilities/:id`
- `GET /inventory`
- `POST /inventory`
- `DELETE /inventory/:id`
- `GET /sales`
- `POST /sales`
- `POST /search`

5. En otra terminal, inicia Flutter Web:

```powershell
flutter run -d web-server --web-port 5036
```

6. Abre:

```text
http://localhost:5036
```

## Verificar Que Todo Esta Vivo

Backend:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8768/health
```

Debe responder:

```json
{"ok":true}
```

TRM:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8768/trm
```

Debe responder algo parecido a:

```json
{"rate":3783.16,"source":"open.er-api.com","fetchedAt":"..."}
```

Compras:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8768/purchases
```

Viabilidades AliExpress:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8768/aliexpress-viabilities
```

## Como Detener Los Servicios

Para detener Flutter en el puerto `5036`:

```powershell
$pids = netstat -ano | Select-String ':5036\s+.*LISTENING'
foreach ($line in $pids) {
  $parts = ($line.ToString() -split '\s+') | Where-Object { $_ }
  Stop-Process -Id ([int]$parts[-1]) -Force
}
```

Para detener el backend en `8768`:

```powershell
$pids = netstat -ano | Select-String ':8768\s+.*LISTENING'
foreach ($line in $pids) {
  $parts = ($line.ToString() -split '\s+') | Where-Object { $_ }
  Stop-Process -Id ([int]$parts[-1]) -Force
}
```

## Sesiones De Tiendas

El backend abre Chrome o Edge con un perfil dedicado:

```text
.pricesec-chrome-profile
```

Si AliExpress, Temu, Shein o Amazon piden login:

1. Inicia el backend.
2. Espera a que abra la ventana de Chrome.
3. Inicia sesion manualmente en la tienda.
4. Vuelve a PriceSec y ejecuta la comparacion.

Ese login queda guardado en `.pricesec-chrome-profile`.

## Comparador De Precios

La pestana `Comparador` permite:

- Escribir producto.
- Elegir tiendas: AliExpress, Temu, Shein, Amazon.
- Filtrar por rating minimo.
- Filtrar por ventas minimas.
- Filtrar envio incluido: `Si`, `No` o `Ambos`.
- Abrir la publicacion validada.

Si una tienda no expone rating, ventas o envio en el resultado, PriceSec no descarta automaticamente el producto por ese campo; compara principalmente por mejor precio disponible.

## Vistas Visuales

PriceSec tiene dos interfaces seleccionables desde el boton superior:

```text
Vista Cyber
Vista Neo
```

`Vista Cyber` usa una apariencia oscura con acentos verdes, bordes luminosos y
paneles tipo dashboard tecnico.

`Vista Neo` usa una apariencia clara, limpia y suave, con tarjetas blancas,
bordes sutiles y sombras elegantes.

Ambas vistas conservan los mismos modulos, permisos y datos. El cambio es solo
visual.

## Sistema De Gestion

El modulo `Sistema de Gestion` funciona como una central de navegacion del
producto.

Incluye:

- Busqueda inteligente de modulos.
- Accesos rapidos a los modulos principales.
- Tarjetas por categoria:
  - Inicio
  - Inventario
  - Ventas
  - Compras
  - Integraciones
  - Configuracion
- Acceso a `Inventario general`.
- Acceso a `Registrar inventario`.
- Acceso a `Registrar ventas`.
- Acceso a `Registrar compra`.
- Acceso a `Compras guardadas`.
- Acceso a `Tiendas Mercado Libre`.
- Acceso a `Colaboradores`.

El modulo se adapta a la vista activa:

- En `Vista Cyber`, usa paneles oscuros, iconos verdes y tarjetas con borde.
- En `Vista Neo`, usa paneles claros, iconos morados y tarjetas tipo Apple.

## Login Y Super Admin

PriceSec exige iniciar sesion antes de entrar al dashboard.

El primer registro creado en una base nueva se guarda automaticamente como:

```text
role = super_admin
```

Ese primer usuario debe ser el dueño/administrador inicial del producto de JULIAN C. PAREDES (SHAWNDARCK).

Los usuarios se guardan en SQLite en la tabla:

```text
users
```

Las contraseñas no se guardan en texto plano. El backend usa hash PBKDF2 con salt individual.

Las sesiones usan tokens locales guardados en el navegador:

```text
pricesec_auth_session
```

Los endpoints de compras, viabilidades y busqueda requieren sesion por header:

```text
Authorization: Bearer <token>
```

## Restablecer Contraseña

Desde la pantalla de login:

1. Selecciona `Forget Password`.
2. Escribe el correo registrado.
3. PriceSec genera un codigo de seguridad de 6 digitos.
4. El codigo expira en 10 minutos.
5. Hay proteccion anti-spam: no genera otro codigo para el mismo usuario durante 2 minutos.
6. Escribe correo, codigo y nueva contraseña.

Importante sobre correo:

- PriceSec local no trae credenciales SMTP incluidas.
- Por seguridad, no se hardcodea ningun usuario/clave de correo en el repo.
- Puedes usar un SMTP gratuito como Gmail con App Password.
- Mientras no configures SMTP real, el codigo queda en la tabla local `auth_email_outbox` y tambien se imprime en la consola del backend.
- Esto permite probar el flujo completo sin enviar spam ni depender de un proveedor externo.

Tabla local de salida:

```text
auth_email_outbox
```

Para produccion o despliegue real, conecta esa bandeja a un proveedor SMTP/API de email autorizado por JULIAN C. PAREDES (SHAWNDARCK).

### SMTP Gratuito Con Gmail

Gmail permite usar SMTP gratis con una App Password si la cuenta tiene verificacion en dos pasos activa.

1. Activa verificacion en dos pasos en la cuenta Gmail que enviara los correos.
2. Crea una App Password en Google Account.
3. Copia el archivo de ejemplo:

```powershell
Copy-Item .\scripts\pricesec.env.example.ps1 .\scripts\pricesec.env.ps1
```

4. Edita `scripts\pricesec.env.ps1` con tus datos:

```powershell
$env:PRICESEC_SMTP_HOST = "smtp.gmail.com"
$env:PRICESEC_SMTP_PORT = "587"
$env:PRICESEC_SMTP_USER = "tu-correo@gmail.com"
$env:PRICESEC_SMTP_PASS = "tu-app-password-de-gmail"
$env:PRICESEC_SMTP_FROM = "PriceSec <tu-correo@gmail.com>"
```

5. Reinicia el backend:

```powershell
.\scripts\start_pricesec.ps1
```

El archivo `scripts\pricesec.env.ps1` esta ignorado por Git y no debe subirse al repo.

## Registrar Compra

La pestana `Registrar compra` guarda compras/importaciones segun el primer Excel:

```text
Alibaba por barco FN.xlsx
```

No toma las filas de ejemplo como datos reales. Solo replica campos y formulas.

Campos principales:

- Nombre producto
- Precio USD
- TRM actual
- Cantidad
- Envio origen USD
- Comision T.C %
- Alto, ancho, largo
- Cantidad cajas
- CBM agente carga
- Flete nacional
- Precio ML
- Comision ML %

La TRM se autocompleta usando:

```text
https://open.er-api.com/v6/latest/USD
```

El usuario tambien puede actualizarla con el boton junto al campo TRM.

## Formulas De Compra

Las formulas actuales son:

```text
Precio COP = Precio USD * TRM
Total mercancia China = Precio COP * Cantidad
Envio origen COP = Envio origen USD * TRM
Total COP China = Envio origen COP + Total mercancia China
Valor comision T.C = Total COP China * Comision T.C
Cubicaje m3 = (Alto/100) * (Ancho/100) * (Largo/100) * Cantidad cajas
Flete + nacionalizacion = Cubicaje m3 * CBM agente carga
Costo importado Bogota = Total COP China + Valor comision T.C + Flete + nacionalizacion
Costo pedido domicilio = Costo importado Bogota + Flete nacional
Costo unidad domicilio = Costo pedido domicilio / Cantidad
Precio ML - comision = Precio ML - (Precio ML * Comision ML)
Comparacion = Precio ML - comision / Costo unidad domicilio
```

El parser numerico acepta formato colombiano:

```text
3.800 -> 3800
3,800 -> 3800
5.35  -> 5.35
5,35  -> 5.35
```

## Compras Guardadas

La pestana `Compras guardadas` lista los registros y permite:

- Buscar por coincidencias parciales, sin exigir la palabra exacta.
- Paginar la lista en bloques de 20 registros.
- Editar.
- Eliminar.

Los registros intentan guardarse primero en SQLite:

```text
pricesec.db
```

Si el navegador bloquea la comunicacion con el backend o el servicio no esta activo, el front guarda temporalmente en `localStorage` del navegador como respaldo:

```text
pricesec_purchases_backup
```

Ese respaldo evita perder registros durante pruebas, pero para una operacion mas estable se debe mantener activo el backend local.

## Viabilidad AliExpress

La pestana `Viabilidad AliExpress` esta basada en:

```text
Analisis de viabilidad de productos aliexpress FN.xlsx
```

PriceSec no importa las filas de ejemplo del Excel. Solo replica sus encabezados y formulas en un formulario independiente.

Campos principales:

- Numero
- Nombre Producto
- Link del producto
- Costo de pedido en domicilio
- Cantidad (Und)
- Precio Total Producto en Mercadolibre
- Comision Meli (%)

Formulas replicadas:

```text
Costo unidad de producto en domicilio = Costo pedido domicilio / Cantidad
Libre de Comision = Precio Total Producto en Mercadolibre - (Precio Total Producto en Mercadolibre * Comision Meli)
Viabilidad = Libre de Comision / Costo unidad de producto en domicilio
```

La pestana `Viabilidades guardadas` permite:

- Buscar por coincidencias parciales en nombre, link o numero.
- Paginar la lista en bloques de 20 registros.
- Editar.
- Eliminar.

Ejemplo de busqueda:

```text
Producto guardado: Zapatos para perros
Busqueda: Zapato
Resultado: aparece
Busqueda: Perros
Resultado: aparece
```

El respaldo local de esta seccion usa otra llave para no mezclar datos con compras:

```text
pricesec_aliexpress_viability_backup
```

## Inventario

La gestion de inventario vive dentro de `Sistema de Gestion`.

Desde esa central puedes entrar a:

- `Inventario general`: vista agrupada por producto y bodega.
- `Sistema de Gestion`: formulario para cargar stock y revisar movimientos.

El formulario permite cargar stock por producto y bodega.

Campos obligatorios:

- Nombre del producto.
- Costo unitario compra.
- Cantidad ingresada.
- Precio venta publico.
- Fecha de carga.
- Bodega.

El listado mantiene el historial de movimientos con fecha, usuario, producto,
cantidad, costo, precio de venta y bodega. Tambien tiene busqueda inteligente
por producto o bodega. Si un producto queda con menos de 3 unidades, PriceSec
muestra una alerta de inventario bajo.

## Ventas

El modulo `Registrar ventas` coteja contra la tabla de inventario.

Flujo:

1. Buscar producto o bodega.
2. Seleccionar el producto disponible desde el desplegable.
3. Ingresar fecha de venta.
4. Ingresar cantidad vendida.
5. Confirmar precio unitario de venta.
6. Guardar la venta.

Al guardar, el backend descuenta la cantidad vendida del inventario seleccionado. Si quedan menos de 3 unidades, el sistema notifica la alerta de bajo stock.

## Base De Datos

SQLite esta incluida en el repositorio como base limpia:

```text
pricesec.db
```

La base se sube sin usuarios, sin tenants de clientes y sin registros de negocio.
Al descargar el repo, la pantalla inicial permite crear el primer Super Admin de
esa instalacion.

Tablas principales:

```text
users
user_sessions
password_reset_codes
auth_email_outbox
purchases
aliexpress_viabilities
inventory_items
sales
```

Los backups locales `pricesec.backup-*.db` si estan ignorados por Git para no
mezclar datos privados con codigo.

## Problemas Frecuentes

### `localhost rechazo la conexion`

Flutter no esta levantado. Ejecutar:

```powershell
flutter run -d web-server --web-port 5036
```

### `No pude comunicarme con la base local`

El backend no esta levantado o Chrome bloqueo la comunicacion. Ejecutar:

```powershell
.\scripts\start_pricesec.ps1
```

Luego verificar:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8768/health
```

### La TRM no carga

Verificar backend:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8768/trm
```

Si falla, se puede escribir manualmente la TRM en el formulario.

### El guardado no aparece en SQLite

Puede haberse guardado en respaldo local del navegador. Revisar la pestana `Compras guardadas`. Para persistencia real en `pricesec.db`, levantar primero el backend local y volver a guardar/editar.

## Comandos De Calidad

Antes de entregar cambios:

```powershell
flutter analyze
flutter test
node --check scripts\price_search_server.mjs
```

Estado esperado actual:

```text
flutter analyze: sin errores
flutter test: pruebas pasando
node --check: sin errores de sintaxis
```
## Multiusuario, Roles Y Tenants

PriceSec ahora maneja un modelo multiusuario local:

- `super_admin`: administrador global. Solo este rol puede crear, consultar,
  activar e inactivar usuarios principales.
- `owner`: usuario principal o cliente. Tiene un `tenant_id` propio y sus datos
  quedan separados de los demas usuarios principales.
- `collaborator`: colaborador creado por un owner. Comparte el tenant del owner
  y solo ve los modulos habilitados por permisos.

La separacion se hace en `pricesec.db` con `tenant_id` en las tablas de negocio:

```text
purchases
aliexpress_viabilities
inventory_items
sales
mercado_libre_stores
```

Tablas de acceso:

```text
users
tenants
permissions
user_permissions
mercado_libre_stores
user_sessions
```

Permisos disponibles:

```text
view_sales
create_publications
edit_publications
delete_publications
view_inventory
modify_inventory
manage_stores
manage_collaborators
view_reports
manage_settings
```

Datos semilla locales opcionales para pruebas:

Por defecto, una base nueva queda vacia para que el primer registro creado desde
la pantalla `Super Admin` pertenezca al usuario de esa instalacion. Si quieres
cargar datos demo, levanta el backend con:

```powershell
$env:PRICESEC_SEED_ADMIN="true"
$env:PRICESEC_SEED_EXAMPLES="true"
.\scripts\start_pricesec.ps1
```

```text
Super Admin global
Usuario: SHAWNDARCK
Correo: admin@pricesec.local
Contrasena: PriceSecAdmin2026!

Usuario principal demo
Usuario: cliente_demo
Correo: cliente.demo@pricesec.local
Contrasena: ClienteDemo2026!

Colaborador demo
Usuario: colaborador_demo
Correo: colaborador.demo@pricesec.local
Contrasena: Colaborador2026!
Permisos: view_inventory, view_sales, view_reports
```

Flujo de prueba recomendado:

1. En una base limpia, crea tu propio Super Admin desde la app. Si activaste las
   semillas demo, inicia sesion como `SHAWNDARCK`.
2. Abre `Usuarios principales`.
3. Crea un usuario principal. El backend crea su tenant aislado.
4. Cierra sesion e inicia con ese usuario principal.
5. Abre `Tiendas Mercado Libre` y registra una o mas tiendas.
6. Abre `Colaboradores`, crea un colaborador y asigna permisos.
7. Cierra sesion e inicia con el colaborador.
8. Verifica que solo aparezcan los modulos permitidos.

Endpoints multiusuario:

```text
GET  /permissions
GET  /admin/principal-users
POST /admin/principal-users
PUT  /admin/principal-users/:id
GET  /collaborators
POST /collaborators
PUT  /collaborators/:id
GET  /mercado-libre-stores
POST /mercado-libre-stores
PUT  /mercado-libre-stores/:id
```

Los endpoints existentes (`/purchases`, `/aliexpress-viabilities`,
`/inventory`, `/sales`, `/search`) validan token, tenant y permisos antes de
consultar o modificar informacion.
