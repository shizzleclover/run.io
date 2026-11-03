# run.io

Run real loops, claim the hexes inside them, and defend your land from
rivals. Paper.io rules on real streets, starting with Nigerian campuses.

The repo has two parts:

| | What | Stack |
|---|---|---|
| `/` | Android app | Flutter, Riverpod, Mapbox |
| `backend/` | Game server | Node 22, Express 5, TypeScript, Postgres, WebSocket |

`backend/` is gitignored in this repo and gets its own git repo.

---

## 1. What you need

- **Flutter** (stable) and the Android SDK, with `adb` on your PATH
- **Node 22** and npm
- **Docker Desktop**, for the local database
- **A Mapbox public token** (`pk.…`) from account.mapbox.com
- **An Android phone** with USB debugging on (or an emulator)

---

## 2. Run the backend (staging, on your Mac)

```sh
cd backend
docker compose up -d        # Postgres 17 on :5432 (databases: runio, runio_test)
npm install
cp .env.example .env        # first time only; then fill in the secrets below
npm run migrate             # creates the tables
npm run dev                 # API + WebSocket on http://localhost:8080
```

In `.env`, generate the two secrets with `openssl rand -base64 48`
(`JWT_SECRET`, `OTP_SECRET`). Everything else works as it is.

Check it's up:

```sh
curl localhost:8080/health          # {"ok":true}
npm run env:check                   # database, email, storage, push
```

With `MAIL_PROVIDER=console`, **sign-up codes are printed in the
`npm run dev` terminal** instead of emailed. Set `MAIL_PROVIDER=resend` to
get real emails.

Within a minute of starting, the server seeds 4 labelled ghost runners in
each launch area (UI, OAU, UNILAG, …), so the map isn't empty.

---

## 3. Run the app

Create `env.json` in the repo root (it's gitignored):

```sh
cp env.example.json env.json        # then paste your Mapbox token in
```

| Key | What |
|---|---|
| `MAPBOX_TOKEN` | Your Mapbox public token. Required. |
| `MAPBOX_STYLE` | Map style for dark mode |
| `API_URL_STAGING` | The backend on your Mac. Default `http://localhost:8080`. |
| `API_URL_PROD` | The deployed backend |
| `INVITE_URL` | Download link put in invites. Optional. |

Plug in the phone, then:

```sh
adb reverse tcp:8080 tcp:8080       # the phone's localhost → your Mac
flutter run --dart-define-from-file=env.json
```

**Run `adb reverse` again every time the phone reconnects.** Without it,
sign-up shows "Can't reach run.io".

### Which server the app talks to

| Build | Server |
|---|---|
| `flutter run` (debug) | **staging**: your Mac |
| `flutter build apk` (release) | **prod**: `API_URL_PROD` |
| add `--dart-define=APP_ENV=offline` | no server; ghosts run on the phone |

Override with `--dart-define=APP_ENV=staging|prod|offline`. Settings shows
the environment next to the version number, except in prod.

On the Android **emulator**, use
`--dart-define=API_URL_STAGING=http://10.0.2.2:8080` instead of
`adb reverse`.

### First run

1. Onboarding: pick an avatar, a name and a colour.
2. **Create account**: email, username, password. Then enter the 6-digit
   code from the backend terminal.
3. Allow location ("While using the app").
4. Home shows your launch area and its ghosts. Press **Start run**, close a
   loop of 200 m or more, and the land inside is yours.

---

## 4. Tests

```sh
# App (engine, invites; the live tests skip without a server)
flutter test

# Backend (uses the runio_test database, wipes it each run)
cd backend && npm test
```

**Live tests** run every endpoint the app uses, through the app's own
code, against a real server. Start one on another port against the test
database, so staging data stays clean:

```sh
cd backend && npm run build
PORT=8097 JOBS_ENABLED=false PUBLIC_URL=http://localhost:8097 \
  DATABASE_URL=postgres://runio:runio@localhost:5432/runio_test \
  node --env-file=.env dist/server.js > /tmp/runio-api.log &

cd .. && RUNIO_MAIL_LOG=/tmp/runio-api.log flutter test test/live \
  --dart-define=API_URL_STAGING=http://localhost:8097
```

The engine is the same on both sides. `backend/src/engine` is a port of
`lib/engine`, and `backend/test/engine-parity.test.ts` checks it against
outputs recorded from the Dart engine. If you change the game rules in
`lib/engine`, regenerate the fixtures and update the port:

```sh
cd backend
dart run scripts/engine_fixtures.dart > test/fixtures/engine.json
npm test
```

---

## 5. Build an APK for testers

Bump `version:` in `pubspec.yaml` first (e.g. `1.0.1+2`), or Android won't
install it over the previous one. Keep `kAppVersion` in
`lib/core/constants.dart` in step.

```sh
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (most phones)
```

A release build talks to **prod**. To send one before the backend is
deployed, add `--dart-define=APP_ENV=offline`.

---

## 6. Deploy the backend (Render + Neon)

Production config lives in `backend/.env.production` (gitignored). It points
at Neon Postgres, Neon object storage (private bucket) and Resend email.

```sh
cd backend
npm run env:check -- .env.production   # everything should be ✓
```

1. Create the Render service from `backend/render.yaml` (Frankfurt, one
   instance: live play is held in memory).
2. Render → Environment → **Add from .env**, then paste `.env.production`.
3. Set `PUBLIC_URL` to the Render address (or `api.byu-connect.com`).
4. Deploy. Migrations run before each deploy.
5. Put the same address in `env.json` as `API_URL_PROD`, then build the app.

The server refuses to start in production with a console mailer, a
localhost or pooled database URL, or plain http.

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| "Can't reach run.io" on sign-up | Is `npm run dev` running? Run `adb reverse tcp:8080 tcp:8080`. |
| No sign-up code | It's in the `npm run dev` terminal (console mailer). |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | A release build with a higher version is installed. Bump `version:`, or uninstall (this wipes the phone's data). |
| White screen: "No Mapbox token" | Run with `--dart-define-from-file=env.json`. |
| Map shows no ghosts | Wait a minute after starting the backend (seeding runs shortly after boot), and make sure you're inside a launch area. |
| Port 5432 already in use | Another Postgres is running; stop it, or change the port in `docker-compose.yml` and `.env`. |
| `password authentication failed` on Neon | Use the **direct** connection string (no `-pooler`), with `sslmode=verify-full`. |

---

## Where things are

```
lib/
  engine/        game rules: hex grid, loops, claims, cuts, decay (pure Dart)
  core/api/      HTTP client, session, every endpoint (runio_api.dart)
  state/         Riverpod state: game, runs, account, sync, live presence
  features/      screens: home, map, run, auth, crew, social, settings…
backend/src/
  engine/        the same rules in TypeScript
  modules/       one folder per feature: auth, runs, territory, live, crews…
  shared/        db, errors, auth guard, rate limits, mailer, jobs
backend/README.md  API, live protocol, scaling, conventions
```
