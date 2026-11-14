# THE LEELA CAFE — Online Ordering + Admin Starter

## What's included
- `index.html`: customer menu/cart/checkout and admin login/dashboard in one responsive site.
- `supabase_admin_setup.sql`: secure order RPC and admin policies.

## Current setup
- Supabase project URL and publishable key are already configured in `index.html`.
- Menu loads from `public.menu_items`.
- Cash checkout calls the `place_order` database function.
- Delivery fee: ₹50 below ₹300; free at ₹300+; takeaway free.
- UPI is intentionally disabled until the cafe supplies its QR/payment details.
- Admin email allowlist: theleelacafe2000@gmail.com.
- Admin dashboard supports live order updates, order status, menu price/availability editing, bill/KOT printing.

## Important setup steps
1. In Supabase SQL Editor, run `supabase_admin_setup.sql` once.
2. In Supabase Dashboard > Database > Replication, ensure Realtime is enabled for the `orders` table (for live admin updates).
3. Deploy this folder as a static site to Vercel (project root is this folder; no build command; output directory `.`).
4. Open the deployed URL, choose Admin Login > Create admin account. Use the approved cafe email and a password you create. Confirm the email if Supabase asks, then sign in.
5. Do not share the admin password. Do not expose any `sb_secret_...` key.

## Before sharing with customers
- Test one takeaway cash order and one delivery order.
- Verify all 100 menu names and prices.
- Verify delivery areas manually with customers; the website currently accepts an address as free text and does not enforce a service-area boundary.
- Connect and test the cafe Windows printer. Browser printing uses the standard print dialog; automatic silent printing requires a dedicated local print bridge/app.
- UPI is not live yet.

## Deployment
Upload this folder to a GitHub repository and import it in Vercel, or use Vercel's static deployment workflow. No domain is required; Vercel will assign a `*.vercel.app` address after successful deployment. The example domain is not reserved.
