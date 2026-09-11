# Achievement V2 Artwork

Date: 2026-09-09. Generated and edited with built-in ImageGen.

The approved hybrid reference is `approved-style.png`. All previous artwork remains untouched.

Production atlases live in `apps/ios/Resources/Assets.xcassets/achv2_atlas_1.imageset` through `achv2_atlas_6.imageset`. Each PNG is 1536x1024 with four columns and two rows. The key-to-cell mapping is in `apps/ios/Sources/Features/Home/AchievementArtworkV2.swift`.

The six atlases contain 43 achievement illustrations, one anonymous mystery silhouette, and four character portraits. Ordinary achievements reuse the established cast. Only trash, cooking, pet care and childcare silver mastery unlock the four new character rewards.

## Prompt Set

Generation: friendly household achievement app, eight isolated illustrations per 4x2 atlas, rounded faces and simple silhouettes, subtle gouache texture inside flat color shapes, few colors, no outlines or busy accessories. Use the approved hybrid style and existing cast reference. Full figures and props within their cells. No text, labels or badge frames. Request genuine transparent background.

Correction applied to each atlas: replace every simulated checkerboard pixel with a uniform pure-white background; preserve character identities, outfits, props, layout and colors. No grid, labels or shadows. The production PNGs are then processed locally into RGBA with edge-connected matte removal; the originals are archived in `design-assets/Final_product/02-screens/icon-transparency-review/originals/`.

Portrait correction: match the chef's small moustache and chin beard and the father's clean-shaven face to their full-body illustrations. Final atlas correction: shrink the first three scenes in atlas 6 within their 384x512 cells to avoid clipping shoes and the table.

Independent transparent exports and no-action bust illustrations are not included in this delivery.

## Verification

`icon-transparency-review/contact-sheets/achv2-cells-8x6-dark.png` contains all 48 V2 cells at review scale, with matching light and color sheets plus 2x3 full-atlas sheets. `legacy-after-dark.png` and `contact-sheets/chore-report-27-dark.png` cover the existing icon passes. No V2 white matte remains as a full background; pale interior artwork is preserved.

iOS full suite: 104 passed, one unsigned-host Keychain test skipped, zero failures. Backend: 66 unit and 40 end-to-end tests passed. No production deployment or real-device verification was performed.
