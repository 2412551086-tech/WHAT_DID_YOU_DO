# macOS Migration Notes

This repository has been cloned on macOS with full Git history preserved.

## Local Tooling

- Xcode: installed and available through `xcodebuild`.
- Swift: installed and available through `swift`.
- Node.js: requires `>=22`.
- pnpm: managed by Corepack through the root `packageManager` field.

Run these commands from the repository root:

```sh
corepack enable
pnpm install
cp backend/.env.example backend/.env
pnpm backend:prisma:generate
pnpm backend:build
```

## iOS Status

The repository currently contains only the planned iOS folder structure under `apps/ios`. It does not contain an Xcode project or workspace yet.

If you have an unpushed Xcode project from the Windows machine, copy or commit these files before continuing:

- `*.xcodeproj`
- `*.xcworkspace`
- Swift source files
- asset catalogs such as `Assets.xcassets`
- configuration files required by the app

Keep generated files such as `DerivedData`, build products, and user-specific Xcode settings out of Git.

## Line Endings

The repository now includes `.gitattributes` to keep text files normalized to LF on macOS and in Git. This avoids noisy changes when moving between Windows and macOS.
