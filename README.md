# SCSN ADUSTECH Wudil Chapter Website

A mobile-first static website starter built from the materials supplied in the conversation.

## Included
- SCSN crest and ADUSTECH logo
- SCSN ADUSTECH Wudil chapter information
- President section
- 100–400 level Chemistry course catalogue based on the supplied curriculum images
- Resource categories with placeholders
- Student search interface
- WhatsApp community button
- Contact numbers
- Admin dashboard UI with upload controls for resources/documents/announcements
- Responsive layout for phones

## Important production note
The included Admin Dashboard is a front-end prototype. It does NOT provide real authentication, persistent uploads, or a database. For production, connect it to Supabase (Auth + Storage + Postgres) or another backend before publishing.

## Deployment
The site can be deployed as a static site to Vercel, Netlify, GitHub Pages, or any normal web host. For the full admin/upload functionality, connect the dashboard to a backend first.

## Supplied curriculum note
The source image contains a duplicate course code CHM 4233 with two different titles in 400 Level electives. The website preserves both entries and flags the issue rather than silently changing the supplied material.
