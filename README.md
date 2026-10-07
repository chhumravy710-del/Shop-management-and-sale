# Shop Management — Online Sync Edition

## What this version adds
- Email/password login
- Same account works on iPhone, iPad and Computer
- Supabase PostgreSQL cloud database
- Row Level Security so each account sees only its own data
- Products, stock, customers, sales, sale items, expenses, settings
- Atomic sale creation with stock deduction through a database RPC
- Invoice printing
- Responsive PWA

## Setup
1. Create a Supabase project.
2. Open SQL Editor and run `schema.sql`.
3. Open Project Settings > API.
4. Copy the Project URL and the Publishable/anon key into `config.js`.
5. Host this folder on an HTTPS site (GitHub Pages, Netlify, Vercel, etc.).
6. Open the URL on iPhone/iPad Safari and choose Share > Add to Home Screen.
7. Use the SAME email/password on all devices.

Never put the Supabase service_role/secret key in `config.js`.

This package is a ready frontend + database schema. It does not contain your private Supabase credentials.
