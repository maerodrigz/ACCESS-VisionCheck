# UAT test accounts guide

**For facilitators only.** Do not paste passwords into email, chat logs, or these markdown files.

## Where passwords live

After provisioning, passwords are stored in:

`access_backend/.env.uat.accounts.local` (gitignored)

Share that file with testers using your campus-approved secure method (password manager, encrypted drive, in-person handout).

## Account roles (UAT database `access_uat`)

| Role | Email (public label) | Used for |
|------|----------------------|----------|
| Admin | `uat-admin@access-uat.example.com` | Admin Web only |
| Member 1 | `uat-member1@access-uat.example.com` | Flutter mobile (primary member tasks) |
| Member 2 | `uat-member2@access-uat.example.com` | Second member (assignment / ranking checks) |
| Requestor | `uat-requestor@access-uat.example.com` | Flutter mobile (organization / partner) |

All accounts are **approved** at creation. They exist only in **`access_uat`**, not in production or QA `access_waverep_test`.

## Environment keys in `.env.uat.accounts.local`

| Variable | Meaning |
|----------|---------|
| `UAT_ADMIN_EMAIL` / `UAT_ADMIN_PASSWORD` | Admin Web login |
| `UAT_MEMBER1_EMAIL` / `UAT_MEMBER1_PASSWORD` | Member 1 mobile login |
| `UAT_MEMBER2_EMAIL` / `UAT_MEMBER2_PASSWORD` | Member 2 mobile login |
| `UAT_REQUESTOR_EMAIL` / `UAT_REQUESTOR_PASSWORD` | Requestor mobile login |

## Re-provisioning (if needed)

Re-running `python scripts/seed_uat_accounts.py` **does not reset passwords** for emails that already exist. To rotate a password, use Admin Web **Account management** or delete the user in `access_uat` (facilitator only) and re-run the seed script.

## What testers must not use

- Production API (`127.0.0.1:3001` or campus production URL)
- QA integration accounts from `.env.smoke.local` (WaveRep / QA org on `access_waverep_test`)
- Real student PII or real event data (use synthetic titles and venues from scenarios)
