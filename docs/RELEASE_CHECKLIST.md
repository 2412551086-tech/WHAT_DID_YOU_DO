# Release Checklist

详细的小白部署、备案、iOS App Store 和 Android 应用市场流程见：

- [DEPLOYMENT_AND_STORE_RELEASE_GUIDE.md](./DEPLOYMENT_AND_STORE_RELEASE_GUIDE.md)
- [ANDROID_RELEASE_GUIDE.md](./ANDROID_RELEASE_GUIDE.md)

本清单用于每个候选版本的最后复核；当前项目仍有正式登录、账号注销、生产部署和 Android 客户端等上架阻断项。

## Product

- [ ] PRD scope reviewed for the release.
- [ ] MVP acceptance criteria mapped to test cases.
- [ ] Paid/free feature boundaries verified.
- [ ] Family privacy rules reviewed.

## Backend

- [ ] Database migrations reviewed and applied.
- [ ] Environment variables documented.
- [ ] API contract published.
- [ ] Authentication and authorization checks covered.
- [ ] Error codes documented.
- [ ] Observability and logging configured.

## iOS

- [ ] Xcode project generated and committed when ready.
- [ ] Bundle ID, signing, and deployment target confirmed.
- [ ] App icons and launch assets prepared.
- [ ] Privacy strings reviewed.
- [ ] App Store metadata drafted.

## Android

- [ ] Android 客户端核心流程与 iOS 对齐。
- [ ] 正式 package name 和 signing keystore 已冻结并安全备份。
- [ ] targetSdk 满足提交时的商店要求。
- [ ] App 备案已增加 Android 平台、包名和签名信息。
- [ ] 软件著作权及各商店版权材料准备完成。
- [ ] 隐私弹窗、权限和第三方 SDK 清单通过合规自查。
- [ ] 国内各渠道包及 Google Play AAB 分别验证。

## QA

- [ ] Core record flow tested.
- [ ] Family membership isolation tested.
- [ ] Photo proof rules tested.
- [ ] Voice confirmation flow tested.
- [ ] Monthly report generation tested.
- [ ] Subscription restore tested.

## Operations

- [ ] Production database backup plan confirmed.
- [ ] Secrets provisioned outside Git.
- [ ] Rollback plan documented.
- [ ] Release tag created.
