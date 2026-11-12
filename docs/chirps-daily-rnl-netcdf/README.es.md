# CHIRPS v3 diario `rnl` en NetCDF: copia local

**Idiomas:** [English](README.md) | [Italiano](README.it.md) | Español | [Français](README.fr.md)

[`examples/download_chirps_daily_rnl_netcdf.sh`](../../examples/download_chirps_daily_rnl_netcdf.sh)
mantiene una copia local del producto diario CHIRPS v3 `rnl` (totales de
péntada repartidos en días con ERA5) en NetCDF, desde 1981 hasta hoy.

- Origen: `https://data.chc.ucsb.edu/products/CHIRPS/v3.0/daily/final/rnl/netcdf/byMonth/`
- Un archivo NetCDF por mes: unos 550 archivos, entre 25 y 30 GB en total
  (estimación; la prueba del paso 3 muestra el valor real).
- La descarga usa HTTPS, así que no hace falta el puerto de rsync (873).
- No se necesita `sudo`.

## 1. Instalar uv (una sola vez)

[uv](https://docs.astral.sh/uv/) gestiona el entorno de Python de este
proyecto. Omite este paso si `uv --version` ya responde.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

## 2. Obtener el repositorio y preparar el entorno

```bash
cd ~
git clone https://github.com/ecor/chc-data-download.git
cd chc-data-download
uv sync
```

`uv sync` crea un entorno aislado en `.venv/` e instala las dependencias
fijadas en el lockfile. No modifica el Python del sistema ni los entornos de
conda. Si el repositorio ya está clonado, usa `git pull` en lugar de
`git clone`.

## 3. Elegir el destino y hacer una prueba

Por defecto los archivos se guardan en
`/home/wefe/local/data/precipitation/chirps/v3.0/daily/final/rnl/netcdf/byMonth/`.
Para usar otra carpeta raíz, define `CHIRPS_DATA`:

```bash
export CHIRPS_DATA=/ruta/de/chirps
```

Revisa el plan sin descargar nada:

```bash
bash examples/download_chirps_daily_rnl_netcdf.sh all --dry-run
```

Comprueba el número de archivos y el tamaño total que aparecen al final.

## 4. Descargar el archivo completo en segundo plano

```bash
nohup bash examples/download_chirps_daily_rnl_netcdf.sh all --yes > ~/chirps_rnl_download.log 2>&1 &
```

`nohup` y `&` mantienen la descarga activa después de cerrar la sesión SSH.
`--yes` es obligatorio aquí, porque un proceso en segundo plano no puede
responder a la pregunta de confirmación de los planes de más de 10 GB. La
descarga tarda unas horas: la herramienta envía una petición cada vez.

Para empezar en un año posterior, escríbelo después de `all`, por ejemplo
`all 2000 --yes`.

## 5. Seguir el avance

```bash
tail -f ~/chirps_rnl_download.log        # Ctrl-C cierra tail, no la descarga
pgrep -af download_chirps_daily_rnl      # ¿sigue en ejecución?
du -sh "${CHIRPS_DATA:-/home/wefe/local/data/precipitation/chirps}"
```

## 6. Detener y reanudar

```bash
pkill -f download_chirps_daily_rnl_netcdf.sh
```

Para reanudar, ejecuta otra vez el comando del paso 4: los archivos completos
se omiten y los interrumpidos se descargan de nuevo. No borres la carpeta de
destino para empezar desde cero.

## 7. Actualización mensual con cron

Los datos definitivos de un mes suelen publicarse entre el día 12 y el 18 del
mes siguiente. Añade esta línea con `crontab -e`:

```bash
30 3 12-20 * * bash $HOME/chc-data-download/examples/download_chirps_daily_rnl_netcdf.sh update >> $HOME/chirps_rnl_update.log 2>&1
```

`update` revisa solo los archivos de los últimos 90 días. Si usas un destino
propio, escribe `CHIRPS_DATA=/ruta/de/chirps` antes de `bash` en esa línea.

## Ajustes

| Variable | Significado | Valor por defecto |
| --- | --- | --- |
| `CHIRPS_DATA` | Carpeta raíz del archivo CHIRPS local | `/home/wefe/local/data/precipitation/chirps` |
| `CHC_UA` | User-Agent que identifica tus peticiones a CHC | `ecor-chirps-mirror (https://github.com/ecor/chc-data-download)` |

Cualquier otra opción se pasa a `download-chc-data`, por ejemplo `--dry-run`,
`--yes` o `--max-bytes`.

## Respetar el servidor de CHC

El servidor de CHC bloquea las direcciones que envían más de unas dos
peticiones por segundo. Ejecuta una sola copia cada vez (el script se niega a
iniciar una segunda), mantén la espera por defecto y no lances la
actualización en un bucle continuo. Consulta
[Downloading Politely](../../README.md#downloading-politely).

## Problemas frecuentes

- **`uv: command not found`**: ejecuta `source ~/.bashrc` o abre una terminal
  nueva.
- **`HTTP 429`, `HTTP 403` o tiempos de espera repetidos**: es posible que tu
  dirección esté bloqueada. Detén todas las descargas hacia CHC desde tu red,
  espera unas horas y contacta con CHC si el problema continúa.
- **La ejecución se interrumpió**: ejecuta otra vez el mismo comando.
