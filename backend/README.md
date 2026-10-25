A server app built using [Shelf](https://pub.dev/packages/shelf),
configured to enable running with [Docker](https://www.docker.com/).

This sample code handles HTTP GET requests to `/` and `/echo/<message>`

# Running the sample

## Running with the Dart SDK

You can run the example with the [Dart SDK](https://dart.dev/get-dart)
like this:

```
$ dart run bin/server.dart
Server listening on port 8080
```

The server uses `HOST=0.0.0.0` and `PORT=8080` by default. If the port is
already occupied by a healthy VN Guide server, the new process reports that it
is already running instead of starting a duplicate. Otherwise, stop the process
using that port or choose another port. In PowerShell:

```powershell
$env:PORT = "8081"
dart run bin/server.dart
```

When using a different port, set the Flutter app's `API_BASE_URL` to the same
port (for example, `http://localhost:8081` or
`http://10.0.2.2:8081` for an Android emulator).

## Tourist-place database

The backend and the tourist-place importer use the same MariaDB settings from
`backend/.env` (`DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, and
`DB_DATABASE`). Run these commands from the `backend` directory:

```powershell
dart run bin/import_dulich.dart
dart run bin/server.dart
```

The importer synchronizes `assets/data/places.json` into `tourist_place`
without deleting existing rows. Server startup also creates the table if it is
missing and adds the `province` column to an older table. Tourist-place API
reads, writes, and health checks all use this same table. Rows inserted into a
separate `destinations` table are synchronized automatically when the server
starts and when the app requests tourist places. To sync them manually:

```powershell
dart run bin/import_destinations.dart
```

Province-filtered results are available through repeated `province` query
parameters.

For a local passwordless database, start Docker Desktop and run this command
once from PowerShell:

```powershell
docker run --detach --name vnguide-mariadb --restart unless-stopped `
  --publish 127.0.0.1:3306:3306 `
  --env MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 `
  --env 'MARIADB_ROOT_HOST=%' `
  --env MARIADB_DATABASE=vietnam_travel `
  --volume vnguide-mariadb-data:/var/lib/mysql `
  mariadb:11.4
```

Configure `backend/.env` with `DB_HOST=127.0.0.1`, `DB_PORT=3306`,
`DB_USERNAME=root`, `DB_PASSWORD=`, and `DB_DATABASE=vietnam_travel`. The
container publishes MySQL only on loopback; do not expose this empty-password
account to a network.

## Three-region dialect data

Set the shared MariaDB connection in `backend/.env`. If the database account has
no password, leave `DB_PASSWORD=` empty. From the `backend` directory, crawl
and import the dialect records with:

```powershell
dart run bin/crawl_tungu.dart
dart run bin/import_tungu.dart
```

The importer reads `phrases.json` and upserts records into the `phrases` table,
so running it again does not create duplicate regional word entries.

And then from a second terminal:
```
$ curl http://0.0.0.0:8080
Hello, World!
$ curl http://0.0.0.0:8080/echo/I_love_Dart
I_love_Dart
```

## Running with Docker

If you have [Docker Desktop](https://www.docker.com/get-started) installed, you
can build and run with the `docker` command:

```
$ docker build . -t myserver
$ docker run -it -p 8080:8080 myserver
Server listening on port 8080
```

And then from a second terminal:
```
$ curl http://0.0.0.0:8080
Hello, World!
$ curl http://0.0.0.0:8080/echo/I_love_Dart
I_love_Dart
```

You should see the logging printed in the first terminal:
```
2021-05-06T15:47:04.620417  0:00:00.000158 GET     [200] /
2021-05-06T15:47:08.392928  0:00:00.001216 GET     [200] /echo/I_love_Dart
```
