# OpenNutrition static index: deployment procedure

## Safety state

The workflow is manual-only. Its `deploy` input defaults to `false`.
A normal run builds, validates and uploads a GitHub artifact without
contacting Cloudflare.

Dataset `2025.1`, its download URL and SHA-256 are fixed together in the
workflow. The operator cannot provide a different version label while still
building the pinned 2025.1 archive.

The workflow pins the external GitHub Actions by full release commit SHA,
uses Dart `3.12.2`, and installs the versioned tooling lockfile with
`--enforce-lockfile`.

## One-time Cloudflare setup

1. Create a Cloudflare Pages **Direct Upload** project. Do not connect it
   using automatic Git integration.
2. Use a project name such as `total-tracker-opennutrition`.
3. Create an API token restricted to the minimum account and Pages
   deployment permissions needed by Wrangler.
4. Add these GitHub repository secrets:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
5. Add this GitHub repository variable:
   - `CLOUDFLARE_PAGES_PROJECT`
6. Run the workflow from `main` with `deploy=false`.
7. Inspect the uploaded artifact, manifest, semantic failures and
   licensing files.
8. Only then run it manually from `main` with `deploy=true`.

The workflow refuses a production deployment from any branch other than
`main`.

## Dataset update policy

A future OpenNutrition release requires a reviewed pull request that updates
all of the following as a single change:

- `DATASET_VERSION`;
- `DATASET_URL`;
- `DATASET_SHA256`;
- Dart tooling lockfile if dependencies change;
- semantic benchmark expectations, only when justified by evidence.

Never replace only the URL, alter only the version label, or disable checksum
verification.

## Application rollout

Before enabling the Flutter client:

1. record the final public Pages base URL;
2. download `manifest.json` from the deployed site;
3. compute and record its SHA-256 in the application build configuration;
4. keep Open Food Facts as the primary source;
5. enable OpenNutrition only after the summary/import flow is present;
6. show a no-reliable-match state rather than promoting a low-confidence
   composed food.

## Rollback

Cloudflare deployment is manual. If an invalid release is published, select
the last known-good Pages deployment or redeploy the corresponding GitHub
artifact. Do not change the app's pinned manifest hash until the replacement
deployment is independently verified.
