# SCSN ADUSTECH Wudil — Smart Search + Secure Examination Results

This package updates the existing SCSN ADUSTECH website without creating a new project.

## Included
- Smart resource search for course codes, course titles, file titles and resource types.
- Examination Results section for 100, 200, 300 and 400 Level.
- Result passwords (minimum 8 characters).
- 14-day or 21-day expiry selected by the admin.
- Results are encrypted before upload and stored in a private Supabase Storage bucket.
- A Supabase Edge Function verifies the password and decrypts the result server-side before sending it to the viewer.
- No public result-file URL is exposed.
- Expired results disappear from the public site; admin can permanently delete them.

## Important deployment order
1. The SQL changes have already been run in the Supabase project, but the result bucket must be private. The supplied `schema.sql` is the authoritative version if the SQL needs to be rerun.
2. Deploy the `supabase/functions/view-result` Edge Function from the Supabase Dashboard and keep JWT verification disabled for this public password-based viewer. The function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY` automatically; never put a secret key in `config.js` or GitHub.
3. Replace the website files in the existing GitHub repository. Vercel will deploy the same project/domain.

The Edge Function can be created directly in Supabase Dashboard > Edge Functions > Deploy a new function > Via Editor. Supabase documents this dashboard deployment flow.
