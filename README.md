# FORGE / CREW

A responsive React gym tracker for workout sessions, per-set lifting logs, daily nutrition, progress charts, and a crew training calendar.

## Run locally

1. Install Node.js (LTS).
2. From this folder, run `npm install`.
3. Run `npm run dev` and open the local address Vite prints.

Without Supabase settings, use **Explore without an account**. Demo data is stored in this browser only.

## Enable shared accounts and calendars

1. Create a Supabase project.
2. Open its SQL editor and run [`supabase/schema.sql`](supabase/schema.sql).
3. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` using the project URL and publishable/anon key.
4. In Supabase Auth, configure the app's local and deployed URLs, and choose whether email confirmation is required.
5. Restart the development server. Sign up to create an account and a crew. Share the crew invite code from the crew button.

Only use the public anon/publishable key in this browser app. Never put a Supabase service role/secret key in `.env.local` or client code.

## Deploy

Build the static app with `npm run build`, then deploy the generated `dist` folder to any static host. Configure the deployed URL in Supabase Auth and provide the same two public environment variables in the host's build settings.

## Nutrition estimates

Known common foods use approximate nutrition averages in the app. For unfamiliar foods or packaged foods, turn off estimation and enter values from the nutrition label. Estimates vary by recipe, brand, and preparation.
