import SwiftUI
import StoreKit

enum AppWebsite {
    static let home = URL(string: "https://douxiaolang.com/familyguard/")!
    static let privacy = home.appendingPathComponent("privacy")
    static let terms = home.appendingPathComponent("terms")
    static let subscription = home.appendingPathComponent("subscription")
    static let support = home.appendingPathComponent("support")
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}

enum PremiumUpgradeTrigger: String, Identifiable, Equatable, CaseIterable {
    case profile, commonLimit, customChore, personalLayout, pointsMultiplier, voiceInput

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: "一人订阅，全家一起用"
        case .commonLimit: "常用家务，不必再做取舍"
        case .customChore: "记下你们家的独门家务"
        case .personalLayout: "每个人，都有顺手的常用区"
        case .pointsMultiplier: "让积分更贴合家务难度"
        case .voiceInput: "说一句，把几件家务一起记下"
        }
    }
}

enum FamilySubscriptionPlan: String, CaseIterable, Identifiable {
    case monthly, yearly
    var id: String { rawValue }
    var title: String { self == .monthly ? "月度订阅" : "年度订阅" }
    var proposedPrice: String { self == .monthly ? "¥6/月" : "¥49.90/年" }
    var renewalCopy: String { self == .monthly ? "按月自动续费" : "按年自动续费" }
}

struct PremiumUpgradeSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    let trigger: PremiumUpgradeTrigger
    var onContinueFree: (() -> Void)? = nil
    var onUnlocked: (() -> Void)? = nil

    @State private var selectedPlan: FamilySubscriptionPlan = .yearly
    @State private var showsDetails = false
    @State private var showsStoreNotice = false
    @State private var showsDeveloperRedemption = false
    @State private var didUnlock = false

    private var accent: Color { colorScheme == .dark ? DSColor.mint : Color(red: 0.03, green: 0.44, blue: 0.34) }
    private var ink: Color { DSColor.ink }
    private var secondaryInk: Color { DSColor.mutedInk }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if didUnlock {
                    unlockedContent
                } else if viewModel.hasPremiumAccess {
                    membershipContent
                } else {
                    Text(trigger.title)
                        .font(.system(size: 28, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Image("subscription_teamwork")
                        .resizable()
                        .scaledToFit()
                        .accessibilityHidden(true)
                    planPicker
                    comparisonTable
                    secondaryActions
                }
            }
            .frame(maxWidth: 560)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(DSColor.pureSurface)
        .foregroundStyle(ink)
        .safeAreaInset(edge: .top, spacing: 0) {
            header.padding(.horizontal, 20).padding(.vertical, 8)
                .background(DSColor.pureSurface)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !viewModel.hasPremiumAccess && !didUnlock { purchaseFooter }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsDetails) { detailsSheet }
        .sheet(isPresented: $showsDeveloperRedemption) {
            DeveloperPremiumRedemptionSheet {
                didUnlock = true
            }
        }
        .alert("商店订阅尚未开放", isPresented: $showsStoreNotice) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("月度 ¥6、年度 ¥49.90 为拟上线方案，当前不会扣费。购买、恢复购买和 Apple 优惠码将在商店配置及权益校验完成后开放。")
        }
        .onChange(of: viewModel.hasPremiumAccess) { wasPremium, isPremium in
            if !wasPremium && isPremium { didUnlock = true }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("brand_app_logo")
                .resizable().scaledToFit().frame(width: 38, height: 38)
                .accessibilityHidden(true)
            Text("家庭保卫战").font(.system(size: 17, weight: .semibold))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 19, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("关闭")
            .buttonStyle(.plain)
        }
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("家庭高级版").font(.system(size: 20, weight: .semibold))
            Text("同一家庭共享 · 订阅暂未开放")
                .font(.system(size: 13)).foregroundStyle(secondaryInk)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                ForEach(FamilySubscriptionPlan.allCases) { plan in
                    Button { selectedPlan = plan } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 7) {
                                Image(systemName: selectedPlan == plan ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedPlan == plan ? accent : secondaryInk)
                                Text(plan.title).font(.system(size: 14, weight: .medium))
                            }
                            Text(plan.proposedPrice).font(.system(size: 23, weight: .semibold))
                                .minimumScaleFactor(0.8).lineLimit(1)
                            Text(plan == .yearly ? "每年省 ¥22.10" : "按月续订")
                                .font(.system(size: 12)).foregroundStyle(secondaryInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(selectedPlan == plan ? accent.opacity(0.08) : DSColor.pureSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedPlan == plan ? accent : Color(white: 0.82), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPlan == plan ? .isSelected : [])
                }
            }
        }
    }

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("权益对比").font(.system(size: 18, weight: .semibold)).padding(.bottom, 12)
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                comparisonRow("权益", free: "免费版", premium: "高级版", isHeader: true)
                comparisonRow("常用家务", free: freeCommonCopy, premium: "不限")
                comparisonRow("自定义家务", free: freeCustomCopy, premium: "100项")
                comparisonRow("个人布局", free: "家庭统一", premium: "每人定制")
                comparisonRow("积分倍率", free: "系统默认", premium: "0.5–2.0倍")
                comparisonRow("家庭同步", free: "支持", premium: "支持")
                comparisonRow("记录与统计", free: "支持", premium: "支持")
            }
            Text("成就奖励栏位永久保留。语音输入正在规划，不属于当前权益。")
                .font(.system(size: 12)).foregroundStyle(secondaryInk)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Read live limits so an older server never advertises capacity it cannot grant.
    private var freeCommonCopy: String {
        "\(viewModel.commonChoreSelectionLimit ?? 8)项"
    }

    private var freeCustomCopy: String { "\(viewModel.customChoreLimit)项" }

    private func comparisonRow(_ title: String, free: String, premium: String, isHeader: Bool = false) -> some View {
        GridRow {
            tableCell(title, alignment: .leading, isHeader: isHeader)
            tableCell(free, alignment: .center, isHeader: isHeader)
            tableCell(premium, alignment: .center, isHeader: isHeader)
                .foregroundStyle(accent)
                .background(accent.opacity(0.045))
        }
    }

    private func tableCell(_ text: String, alignment: Alignment, isHeader: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: isHeader ? .semibold : .regular))
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: alignment)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(alignment: .bottom) { Color(white: 0.89).frame(height: 0.5) }
    }

    private var secondaryActions: some View {
        VStack(spacing: 4) {
            HStack {
                Button("兑换优惠码") { showsStoreNotice = true }.frame(minHeight: 44)
                Spacer()
                Button("订阅说明") { showsDetails = true }.frame(minHeight: 44)
            }
            .font(.system(size: 14)).frame(minHeight: 44)
            .buttonStyle(.plain)
            #if DEBUG
            Button("开发测试兑换") { showsDeveloperRedemption = true }
                .font(.system(size: 12)).frame(minHeight: 44)
                .foregroundStyle(secondaryInk)
            #endif
            if let onContinueFree {
                Button("继续使用免费版") {
                    dismiss()
                    DispatchQueue.main.async { onContinueFree() }
                }
                .font(.system(size: 14)).frame(minHeight: 44)
            }
        }
    }

    private var purchaseFooter: some View {
        VStack(spacing: 10) {
            Button { showsStoreNotice = true } label: {
                Text("查看订阅上线说明")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 8)
                    .foregroundStyle(DSColor.pureSurface).background(ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            Text("订阅尚未开放，当前不会扣费")
                .font(.system(size: 12)).foregroundStyle(secondaryInk)
                .multilineTextAlignment(.center)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { footerLinks }
                VStack(spacing: 0) { footerLinks }
            }
            .font(.system(size: 12)).tint(secondaryInk)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(DSColor.pureSurface)
        .overlay(alignment: .top) { Color(white: 0.92).frame(height: 0.5) }
    }

    @ViewBuilder private var footerLinks: some View {
        Button("恢复购买") { showsStoreNotice = true }.frame(minHeight: 44)
        Link("服务条款", destination: AppWebsite.terms).frame(minHeight: 44)
        Link("隐私政策", destination: AppWebsite.privacy).frame(minHeight: 44)
    }

    private var membershipContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("家庭高级版已启用").font(.system(size: 26, weight: .semibold))
            Image("subscription_teamwork").resizable().scaledToFit().accessibilityHidden(true)
            Text("当前家庭成员共享高级权益。")
                .font(.system(size: 15)).foregroundStyle(secondaryInk)
            Link("管理 Apple 订阅", destination: AppWebsite.manageSubscriptions)
                .font(.system(size: 16, weight: .semibold)).frame(minHeight: 44)
            Text("由其他成员开通的订阅，请由购买者管理；测试兑换权益不会产生 Apple 账单。")
                .font(.system(size: 13)).foregroundStyle(secondaryInk)
            Button("权益与订阅说明") { showsDetails = true }.frame(minHeight: 44)
            Link("帮助与支持", destination: AppWebsite.support).frame(minHeight: 44)
        }
    }

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("家庭高级版已解锁").font(.system(size: 26, weight: .semibold))
            Image("subscription_teamwork").resizable().scaledToFit().accessibilityHidden(true)
            Button("继续刚才的操作") {
                dismiss()
                DispatchQueue.main.async { onUnlocked?() }
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(DSColor.pureSurface).background(ink)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var detailsSheet: some View {
        NavigationStack {
            List {
                Section("家庭权益") {
                    Text("权益适用于 App 内当前同一家庭，不等同于 Apple 家庭共享。")
                    Text("免费版常用家务和自定义家务分别计数，成就可额外增加栏位。高级版自定义家务目前设有 100 项技术保护上限。")
                    Text("个人布局支持成员设置自己的常用区；积分倍率可在记录时调整。语音输入尚未上线，不属于当前可用权益。")
                }
                Section("订阅与取消") {
                    Text("拟定月度 ¥6、年度 ¥49.90。正式开售以 Apple 购买确认页展示的币种、价格、期限为准。")
                    Text("订阅将自动续费。取消后可使用至已付费周期结束。注销 App 账户不会自动取消 Apple 订阅，请先在 Apple 账户管理。")
                    Link("管理 Apple 订阅", destination: AppWebsite.manageSubscriptions)
                }
                Section("网站与协议") {
                    Link("官方网站", destination: AppWebsite.home)
                    Link("订阅说明", destination: AppWebsite.subscription)
                    Link("服务条款", destination: AppWebsite.terms)
                    Link("隐私政策", destination: AppWebsite.privacy)
                    Link("帮助与支持", destination: AppWebsite.support)
                }
            }
            .navigationTitle("订阅说明").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showsDetails = false } } }
        }
    }
}

// Test redemption is deliberately excluded from Release UI, not disguised as IAP.
private struct DeveloperPremiumRedemptionSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let onSuccess: () -> Void
    @State private var code = ""
    @State private var isRedeeming = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("仅供授权测试账号使用") {
                    SecureField("兑换码", text: $code)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if let error { Text(error).foregroundStyle(.red) }
                    Button(isRedeeming ? "正在验证…" : "兑换") {
                        Task {
                            isRedeeming = true
                            defer { isRedeeming = false }
                            if await viewModel.redeemPremium(code: code) {
                                code = ""
                                dismiss()
                                onSuccess()
                            } else {
                                error = viewModel.errorMessage ?? "兑换失败，请重试。"
                            }
                        }
                    }
                    .disabled(isRedeeming || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("开发测试兑换").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(isRedeeming) } }
            .interactiveDismissDisabled(isRedeeming)
        }
    }
}
