import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasAcceptedAgreement = false
    @State private var notice: LoginNotice?
    @State private var showsEmailLogin = false

    var body: some View {
        ZStack {
            Image("login_household_battle")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Color.black
                .opacity(colorScheme == .dark ? 0.48 : 0.16)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                HStack {
                    Button(action: viewModel.cancelAuthentication) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 180)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gateTitle)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(DSColor.ink)
                        Text(gateSubtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: orderedProviders.count),
                        spacing: 10
                    ) {
                        ForEach(orderedProviders) { provider in
                            AuthProviderTile(provider: provider, isLoading: viewModel.isLoading) {
                                beginAuthentication(with: provider)
                            }
                        }
                    }

                    #if DEBUG
                    Button("开发环境登录") {
                        guard hasAcceptedAgreement else {
                            notice = .agreementRequired
                            return
                        }
                        viewModel.developmentLogin()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSColor.mutedInk)
                    .frame(maxWidth: .infinity)
                    #endif

                    agreementRow
                }
                .padding(20)
                .background(DSColor.quietBackground.opacity(0.97))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showsEmailLogin) {
            EmailOTPLoginSheet()
                .environmentObject(viewModel)
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    private var gateTitle: String {
        switch viewModel.pendingAuthAction {
        case .joinFamily: "登录后加入家庭"
        case .claimLocalDraft: "登录后开启家庭同步"
        case .enableCloudSync: "登录后开启云端同步"
        case .inviteMembers: "登录后邀请家人"
        case nil: "欢迎回来"
        }
    }

    private var gateSubtitle: String {
        pendingActionSubtitle ?? "选择你上次使用的方式，继续守护这个家。"
    }

    private var pendingActionSubtitle: String? {
        switch viewModel.pendingAuthAction {
        case .joinFamily: "验证账号后将继续加入家庭。"
        case .claimLocalDraft: "登录后会保留本机家务和记录，并开启同步。"
        case .enableCloudSync: "登录后会保留当前内容，并开启云端同步。"
        case .inviteMembers: "登录后会回到邀请家人的步骤。"
        case nil: nil
        }
    }

    private var orderedProviders: [ClientAuthProvider] {
        viewModel.availableAuthProviders.sorted { left, right in
            if left == .email { return true }
            if right == .email { return false }
            return left.rawValue < right.rawValue
        }
    }

    private func beginAuthentication(with provider: ClientAuthProvider) {
        guard hasAcceptedAgreement else {
            notice = .agreementRequired
            return
        }
        viewModel.selectAuthProvider(provider)
        if provider == .email {
            showsEmailLogin = true
        }
    }

    private var agreementRow: some View {
        Button {
            hasAcceptedAgreement.toggle()
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: hasAcceptedAgreement ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(hasAcceptedAgreement ? DSColor.infoBlue : DSColor.ink)
                Text("我已阅读并同意用户协议和隐私政策")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EmailOTPLoginSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var code = ""
    @State private var challenge: EmailLoginChallengeResponse?
    @State private var resendCountdown = 0
    @State private var isSubmitting = false

    private enum Field {
        case email
        case code
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(DSColor.pureSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("取消")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: challenge == nil ? "envelope.fill" : "number.square.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(DSColor.infoBlue)
                    Text(challenge == nil ? "邮箱验证码登录" : "输入 6 位验证码")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DSColor.ink)
                    Text(helperText)
                        .font(.system(size: 14))
                        .foregroundStyle(DSColor.mutedInk)
                }

                if let errorMessage = viewModel.errorMessage {
                    DSErrorBanner(message: errorMessage)
                }

                if challenge == nil {
                    TextField("name@example.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .font(.system(size: 17))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(DSColor.pureSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DSColor.subtleStroke, lineWidth: 1)
                        }
                        .submitLabel(.continue)
                        .onSubmit(sendCode)
                } else {
                    TextField("000000", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: .code)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)
                        .background(DSColor.pureSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DSColor.subtleStroke, lineWidth: 1)
                        }
                        .onChange(of: code) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            code = String(digits.prefix(6))
                        }

                    HStack {
                        Button("更换邮箱") {
                            challenge = nil
                            code = ""
                            resendCountdown = 0
                            focusedField = .email
                        }
                        Spacer()
                        Button(resendCountdown > 0 ? "\(resendCountdown) 秒后重发" : "重新发送") {
                            sendCode()
                        }
                        .disabled(resendCountdown > 0 || viewModel.isLoading || isSubmitting)
                    }
                    .font(.system(size: 14, weight: .medium))

                    #if DEBUG
                    if let developmentCode = challenge?.developmentCode {
                        Text("开发环境验证码：\(developmentCode)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    #endif
                }

                Button {
                    if challenge == nil {
                        sendCode()
                    } else {
                        verifyCode()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(DSColor.ink)
                        }
                        Text(challenge == nil ? "发送验证码" : "验证并继续")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(DSColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DSColor.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(
                    viewModel.isLoading
                        || isSubmitting
                        || (challenge == nil ? email.isEmpty : code.count != 6)
                )

                Spacer()
            }
            .padding(22)
            .background(DSColor.quietBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focusedField = .email }
            .task(id: challenge?.challengeId) {
                while challenge != nil, resendCountdown > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    resendCountdown -= 1
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isLoading)
    }

    private var helperText: String {
        if let challenge {
            return "验证码已发送至 \(challenge.maskedEmail)，10 分钟内有效。"
        }
        return "新邮箱会自动创建账号，已使用的邮箱会登录原账号。"
    }

    private func sendCode() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            guard let response = await viewModel.requestEmailLoginCode(email) else { return }
            challenge = response
            resendCountdown = response.resendAfterSeconds
            #if DEBUG
            if let developmentCode = response.developmentCode {
                code = developmentCode
            }
            #endif
            focusedField = .code
        }
    }

    private func verifyCode() {
        guard let challenge, !isSubmitting else { return }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            let succeeded = await viewModel.verifyEmailLoginCode(
                email: email,
                challengeId: challenge.challengeId,
                code: code
            )
            if succeeded {
                dismiss()
            }
        }
    }
}

private struct AuthProviderTile: View {
    let provider: ClientAuthProvider
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(iconFillColor)
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 94)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DSColor.subtleStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var title: String {
        switch provider {
        case .apple: "Apple"
        case .wechat: "微信"
        case .email: "邮箱验证码"
        case .google: "Google"
        }
    }

    private var systemImage: String {
        switch provider {
        case .apple: "apple.logo"
        case .wechat: "bubble.left.and.bubble.right.fill"
        case .email: "envelope.fill"
        case .google: "g.circle.fill"
        }
    }

    private var fillColor: Color {
        DSColor.pureSurface
    }

    private var foregroundColor: Color {
        DSColor.ink
    }

    private var iconFillColor: Color {
        switch provider {
        case .email: DSColor.yellow.opacity(0.72)
        case .wechat: DSColor.mint.opacity(0.65)
        case .apple: DSColor.ink.opacity(0.08)
        case .google: DSColor.sky.opacity(0.58)
        }
    }
}

private enum LoginNotice: Identifiable {
    case agreementRequired

    var id: String { "agreement-required" }
    var title: String { "请先确认协议" }
    var message: String { "登录前需要阅读并同意用户协议和隐私政策。" }
}
