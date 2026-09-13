# TestFlight Preparation - 2026-09-12

## Verified Baseline

- Backend candidate: main commit `8a12e47c8661ecbb656c587b6ced12fac0676567`.
- Backend CI passed: https://github.com/2412551086-tech/WHAT_DID_YOU_DO/actions/runs/34611813130
- iOS CI passed for that commit: https://github.com/2412551086-tech/WHAT_DID_YOU_DO/actions/runs/34611813052
- The subsequent local iOS changes add the required-reason privacy manifest and make Debug/Release iPhone-only. These changes passed a signed Release archive; they are not yet committed.
- Archive: `/tmp/familyguard-iphone-privacy-20260911.xcarchive`.
- Archived app: `com.douxiaolang.familyguard`, version `0.1.0`, build `1`, SDK 26.5, `UIDeviceFamily = [1]`, portrait.
- The app contains `PrivacyInfo.xcprivacy`, byte-identical to the source. It declares only UserDefaults with reason CA92.1. Other required-reason categories were not found in the source/dependency/binary review.
- Strict local archive code-signature verification passed. A subsequent App Store Connect distribution export and strict package verification also passed; online Apple validation is still pending.
- Production `/health` returned HTTP success on 2026-09-12. Server inspection found the existing `production` Compose project, 26 applied migrations through Apple login, and only the character migration pending.

## Production Deployment

- User explicitly confirmed the production switch. API-only deployment completed at `2026-09-12 00:53:01 Asia/Shanghai` (`2026-09-11T16:53:01Z`).
- Running revision: `8a12e47c8661ecbb656c587b6ced12fac0676567`; image `sha256:af1c48ca9a55cb17a075d2578b448985945c5737511bd7f7b1319feda8f01f62`, referenced by `production-api` and retained as `familyguard-api:8a12e47-20260912-reused`.
- Fresh switch-time backup: `/opt/familyguard-backups/switch-20260911T165237Z-8a12e47`, containing the database dump, verified archive table of contents, private deployment configuration and original backend source. Earlier backup and rollback image remain available.
- Candidate source and root build inputs were installed into the existing server build context. Local backend environment files, secret directory and uploads, if present, were preserved. The original source remains in the private backup directory.
- Recreated only `api` with the existing Compose configuration using `--no-build --no-deps`. Startup migration and seed completed. There are now 27 completed migrations; the character table exists.
- Production checks passed: health 200, auth config 200, Apple challenge 201 and unauthenticated character route 401. These checks do not substitute for a real Apple account sign-in on an iPhone.
- Independent public checks passed: `https://api.douxiaolang.com/health` returned 200 with `status: ok`, the protected character endpoint returned the expected 401, and `https://douxiaolang.com/` returned 200.
- Existing database and Caddy container IDs were verified unchanged. The website was not redeployed. TestFlight upload, invitations and review submission were not performed.
- Final read-only verification passed: production environment file is byte-identical to its fresh backup, deployed source/schema match the candidate, API is healthy with zero restarts, startup log scan found zero error lines, all 27 existing achievement events are succeeded, and no unfinished/unrolled-back migrations remain.

## Authenticated Preparation Checkpoint

- App Store Connect app created with user confirmation: `6811112270`, name `家庭保卫战`, bundle ID `com.douxiaolang.familyguard`, SKU `familyguard-ios`, primary language Simplified Chinese.
- Internal TestFlight group `内部验收` created, automatic distribution unchecked, zero testers and zero builds. No invitation sent.
- Distribution package exported successfully: `/tmp/familyguard-testflight-export-20260912/WhatDidYouDo.ipa`, about 40 MB, version `0.1.0 (1)`, iPhone only.
- Durable local package copy: `out/releases/2026-09-12/FamilyGuard-0.1.0-1.ipa`; SHA-256 `4ff79f83dfb6b6f79121dc47145c16974443df1b595abcd233acf56bfecc628a`. The backend build-context archive is also retained beside it. This output directory is ignored by Git.
- The signed archive and crash-symbol files are retained at `out/releases/2026-09-12/FamilyGuard-0.1.0-1.xcarchive` for later export/upload and crash analysis.
- Cloud-managed distribution signing succeeded for team `3WY4649N39`. Package checks passed for strict signature, `beta-reports-active`, absence of debug entitlement, iPhone device family, and unchanged privacy manifest. The export emitted an account/provider warning before succeeding; online upload validation remains necessary.
- Production host: `123.57.153.60`; deployment directory `/opt/familyguard/deploy/production`. API, database and Caddy are existing separate containers. Website assets and reverse proxy have not been replaced.
- Private pre-release database and configuration backups created under `/opt/familyguard-backups/release-20260912-8a12e47`; database archive table-of-contents check passed. Sensitive configuration remains on the server.
- Existing API image retained as `familyguard-api:rollback-20260912`.
- Apple settings, readable key file, token-encryption key format and SMTP secret presence verified without exposing values. Existing achievement policy is enabled with no allowlist; all 27 existing queue events are succeeded, with none pending at inspection time.
- Server Git clones failed over HTTP/2 and HTTP/1.1; the Aliyun upload component also failed to load. GitHub's official archive endpoint succeeded. Backend build inputs were initially extracted into `/opt/familyguard-releases/8a12e47-20260912-codeload`, without touching the running installation before confirmation.
- The initial clean-image build stalled downloading Debian packages. Its temporary build container was stopped, leaving production unchanged. Root `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml` and `backend/package.json` were compared byte-for-byte against the existing API image and all matched. A replacement build reused the retained image's dependencies, removed old backend source/build/schema directories, copied the candidate backend, regenerated Prisma and recompiled successfully.
- Verified candidate: `familyguard-api:8a12e47-20260912-reused`, image ID `sha256:af1c48ca9a55cb17a075d2578b448985945c5737511bd7f7b1319feda8f01f62`; revision label matches the fixed main commit.
- Isolated rehearsal passed: restored the private database dump to a temporary PostgreSQL container, applied migrations and seed with the candidate, and started the candidate using an isolated internal-only network with no published ports and achievement workers disabled. Health and auth config returned 200, Apple challenge returned 201, and unauthenticated character collection returned the expected 401. Production API and database remained healthy throughout. A separate inspection confirmed no rehearsal containers or network remain.
- Existing production API image reference is `production-api`; Compose startup runs migration, seed, then the API. The confirmed deployment used this reference and preserved the original source before synchronizing the candidate backend into the server build context.
- The user reviewed the API-only switch, additive character table, catalog/achievement updates, short interruption, and non-reversible reward effects, then explicitly confirmed the switch. Production deployment and interface checks passed. TestFlight upload was excluded from that confirmation.

## Deployment Artifact

- Local package: `/tmp/familyguard-backend-8a12e47-20260912.tar.gz`.
- SHA-256: `ce371c52b47f602dfed1c282b81c376b1618e906a0a59f8393d8df9ae236582b`.
- Includes the backend and its root build dependencies from the fixed main commit.
- Excludes the website, iOS changes, production configuration and secrets.
- This is a build-context package, not a standalone deployment script. Do not extract it over the running installation or run migrations until the current deployment and rollback path have been reviewed.

## Production Gate

1. Identify the existing API container, image, Compose project, source location, database and applied migrations. Do not recreate the database or reverse proxy.
2. Preserve private backups of the database, current source/image, `production.env` and Apple secret files. Verify the database dump is readable and retain the old image for application rollback. Do not put backup contents in Git or chat.
3. Check required configuration by presence/format without printing values. Preserve JWT, SMTP and Apple settings, especially `APPLE_TOKEN_ENCRYPTION_KEY`; rotating that key can make existing Apple credentials unreadable.
4. Inspect `ACHIEVEMENTS_ENABLED`, the family allowlist and pending/retryable event counts. The allowlist gates new event creation, not processing of existing queued events. Disabling achievements is not a lossless worker pause. Do not change the rollout policy implicitly.
5. Compare actual applied migrations with the candidate. The Apple-login and character migrations reviewed since the approximate September 5 baseline are additive; confirm the real pending set before proceeding.
6. Review the migration/seed plan and expected API interruption before the final production switch. Seed updates catalog and achievement definitions and is repeatable, but not globally transactional.
7. Build the candidate without replacing live services. After confirmation, avoid mixed old/new workers, apply the reviewed migrations and seed, then replace only the API service using the existing production configuration.
8. Verify API health, auth provider configuration, Apple challenge and protected character route registration. Confirm the website remains unchanged. Do not mistake a health response for successful real Apple login.

## Rollback Constraints

- Keep additive schema when rolling back application code; never reset the production database.
- An old API can reject larger local drafts, apply lower free-slot limits and count new doubt reactions incorrectly for achievements.
- A code rollback does not undo achievement unlocks or rewards already written by the new worker. Prefer a reviewed forward fix if new-format writes have occurred.
- Never restore a database backup over post-deployment user writes without explicit approval and a recovery plan.

## TestFlight Gate

- On the user's request to start testing, archive `0.1.0 (1)` was uploaded with Xcode using `out/releases/2026-09-12/UploadOptions.plist`. Destination is App Store Connect, automatic signing, original build number retained, crash-symbol upload enabled. Xcode reported `Upload succeeded` and `EXPORT SUCCEEDED` at `2026-09-12 08:07:58 Asia/Shanghai`, with the uploaded package processing. This does not submit the app for App Store review or make it available to external testers.
- The minimum supported system in the archive is iOS 17.6, with iPhone device family only. It uses the production backend. Test users should use dedicated accounts/families and avoid uninstalling an existing app that contains important unsynced guest records.
- The user restored App Store Connect access. Apple processed build `0.1.0 (1)` (ID `8bd59443-55e6-404e-a093-b6cdf0d3d87f`). After explicit user confirmation, the Apple-provided-crypto-only declaration was saved by choosing the option that neither listed algorithm category applies. Missing export compliance is cleared; the build shows Ready to Submit and is now assigned to `内部验收`. This status is not an App Store review submission.
- The user requested internal testing for their second account `2412551086@qq.com`, supplied the name `豆晓阳`, and explicitly approved app-scoped Marketing access after the permission implications were explained. An App Store Connect user invitation was sent successfully with given name `晓阳`, family name `豆`, Marketing role, and only `家庭保卫战` selected. No Admin, Finance, Developer, certificate or report permission was added.
- On 2026-09-12, the target account accepted the App Store Connect invitation and became selectable as an internal tester. Added `2412551086@qq.com` to `内部验收`, which now has one tester and one build, `0.1.0 (1)`. The initial tester status was "No Builds Available". After saving the build's testing instructions and revisiting the group, the status was verified as "Invited" dated 2026-09-12. Installation on the recipient's device remains unverified. External testing was not selected and no external review was submitted.
- User completed login to Aliyun console, App Store Connect, and Xcode for the existing developer team `3WY4649N39`.
- Confirm the App Store Connect app record, agreements, role and already-used build numbers before selecting the upload build number. Do not create a duplicate app record.
- Cloud-managed distribution export has succeeded. Do not revoke or replace existing certificates; verify the package through Apple's upload processing before calling it TestFlight-ready.
- Prepare internal testing first. External tester distribution and Beta App Review require a separate final action.
- Review export compliance in App Store Connect. Source inspection found Apple-provided HTTPS, Keychain and CryptoKit SHA-256 usage, with no custom encryption implementation found. No legal declaration was submitted or added automatically.
- Required-reason API declarations are not a complete App Store data-collection disclosure. Do not claim that this online account-based app collects no data.

## Focused Device Acceptance

1. Sign in with Apple and email on the production API; restart and confirm the session is retained.
2. With dedicated test accounts, create/join a family and approve the join request; keep tests out of real user families.
3. Create/edit/delete a chore record, verify point changes, and retry after an interrupted connection without duplicate records.
4. Test all six reactions, changing/removing reactions, and strict-majority consensus with two and four active members; verify member departure updates eligibility.
5. Verify character collection and achievement display against the newly deployed backend.
6. Verify guest-mode persistence and explicit local-to-cloud import without overwriting the guest copy unexpectedly.
7. Delete only a disposable test account to verify account cleanup and Apple revocation behavior; confirm this final destructive test beforehand.

Notifications and paid StoreKit purchases are not being enabled in this preparation. The unfinished WeChat flow must not be described to testers as operational. Production deployment, TestFlight package upload, Apple processing, confirmed export compliance, internal-group build assignment and the requested internal tester invitation are complete. Recipient installation and device acceptance remain pending; no review submission has been performed.

## Official References

- Required-reason categories and allowed reasons: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Upload requirements: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- TestFlight workflow: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- Export compliance: https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation
- Cloud-managed signing: https://developer.apple.com/help/account/certificates/cloud-managed-certificates
