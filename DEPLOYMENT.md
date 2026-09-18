# Deployment notes

## Existing website
Keep the same GitHub repository, Vercel project, Supabase project and domain.

## Supabase SQL
The result feature uses the `exam_results` table and a private `scsn-results` bucket. The `schema.sql` in this package contains the intended schema.

## Edge Function — required before publishing the website update
Folder: `supabase/functions/view-result`

Create a new Edge Function named `view-result` in the Supabase Dashboard using **Via Editor**. Paste the contents of `supabase/functions/view-result/index.ts` into the editor. Set JWT verification to **off** for this public password-based viewer, then deploy it. Supabase's dashboard supports creating, editing and deploying Edge Functions directly. The function URL will be under `/functions/v1/view-result`.

Do not paste any secret/service-role key into the website. Supabase makes server-side function secrets available to Edge Functions.

## Website update
After the function is deployed, upload the website files to the existing GitHub repository on `main`. Vercel should automatically deploy the same production project.
