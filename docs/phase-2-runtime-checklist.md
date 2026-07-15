# Phase 2 Local Runtime Checklist

## Detected State - 2026-07-14

- `docker`: missing from `PATH`; no Docker Windows service found.
- `podman`: missing from `PATH`; no Podman service found.
- `nerdctl`: missing.
- Rancher Desktop CLI: missing.
- `psql`: missing.
- `wsl.exe`: present, but Windows reports that WSL is not installed.

No database reset, migration, seed, pgTAP, RLS, storage, idempotency, or concurrency result may be marked verified in this state.

## One-Time Manual Setup

1. Install and start Docker Desktop for Windows using an administrator-approved configuration.
2. If Docker Desktop requests WSL 2, run `wsl --install` from an elevated terminal, reboot, finish the Linux distribution setup, then restart Docker Desktop.
3. Wait until Docker Desktop reports that the engine is running.
4. Open PowerShell and verify:

```powershell
docker version
docker info
docker run --rm hello-world
```

5. From `D:\~\DAWNLOADS\falcon`, confirm the pinned CLI:

```powershell
npx supabase --version
```

Expected CLI version: `2.109.1`.

## Clean Local Verification

Run in this exact order and retain complete stdout/stderr and exit codes:

```powershell
npm install
npm run db:start
npm run db:reset
npm run db:lint
npm run db:test
npm run db:types
npm run typecheck
npm run build
npm run lint
```

After `db:types`, verify that `src/types/database.generated.ts` contains real `public` and `api` table/function definitions and no error payload. The generation script writes only after a successful CLI response, so a failure preserves the prior file.

## Required Evidence

Record for every command: command text, UTC timestamp, exit code, passed/failed count where available, and a concise unedited output summary. Also capture:

```powershell
npx supabase status
git diff --check
git status --short
```

Do not deploy, link a remote project, run remote migrations, push, merge, or begin Phase 3 from this checklist.
