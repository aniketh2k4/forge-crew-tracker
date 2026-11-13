# FORGE / CREW

A responsive React gym tracker for workout sessions, per-set lifting logs, daily nutrition, progress charts, and a crew training calendar.

## Run locally

1. Install Node.js (LTS).
2. From this folder, run `npm install`.
3. Run `npm run dev` and open the local address Vite prints.

Supabase project settings are required to sign in, create an account, and sync data.

## Enable shared accounts and calendars

1. Create a Supabase project.
2. Open its SQL editor and run [`supabase/schema.sql`](supabase/schema.sql).
3. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` using the project URL and publishable/anon key.
4. In Supabase Auth, configure the app's local and deployed URLs, and choose whether email confirmation is required.
5. Restart the development server. Sign up to create an account and a crew. Share the crew invite code from the crew button.

### Upgrade an existing project for weight tracking

For an existing Supabase project, run [`supabase/migrations/20261113_weight_tracking.sql`](supabase/migrations/20261113_weight_tracking.sql) and [`supabase/migrations/20261113_weight_entry_type.sql`](supabase/migrations/20261113_weight_entry_type.sql) in the SQL editor. New installs can use the updated `supabase/schema.sql` instead. Weight entries are private to each account.

Only use the public anon/publishable key in this browser app. Never put a Supabase service role/secret key in `.env.local` or client code.

## Deploy

Build the static app with `npm run build`, then deploy the generated `dist` folder to any static host. Configure the deployed URL in Supabase Auth and provide the same two public environment variables in the host's build settings.

## Nutrition estimates

Known common foods use approximate nutrition averages in the app. For unfamiliar foods or packaged foods, turn off estimation and enter values from the nutrition label. Estimates vary by recipe, brand, and preparation.

Body goals are estimates for adults. The app uses Mifflin–St Jeor, a selected daily activity level adjusted by completed workouts logged in the previous 28 days, a gradual 250 kcal/day goal offset, and 1.6 g protein per kg body weight. Monthly weight check-ins refresh the stored calorie and protein goals. These are not medical advice; consult a qualified clinician for individual needs.
