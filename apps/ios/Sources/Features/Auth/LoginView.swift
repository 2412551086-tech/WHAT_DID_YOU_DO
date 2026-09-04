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

                Spacer(minLength: 220)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gateTitle)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(DSColor.ink)
                        Text("登录后会继续刚才的步骤，不需要重新配置。")
                            .font(.system(size: 14))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    ForEach(viewModel.availableAuthProviders) { provider in
                        AuthProviderButton(provider: provider, isLoading: viewModel.isLoading) {
                            guard hasAcceptedAgreement else {
                                notice = .agreementRequired
                                return
                            }
                            if provider == .email {
                                viewModel.selectAuthProvider(provider)
                                showsEmailLogin = true
                            } else {
                                viewModel.selectAuthProvider(provider)
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
                .padding(22)
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
        case nil: "登录家庭保卫战"
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

private struct AuthProviderButton: View {
    let provider: ClientAuthProvider
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 17)
            .frame(minHeight: 54)
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
        case .apple: "通过 Apple 登录"
        case .wechat: "通过微信登录"
        case .email: "通过邮箱验证码登录"
        case .google: "通过 Google 登录"
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
        provider == .apple ? DSColor.ink : DSColor.pureSurface
    }

    private var foregroundColor: Color {
        provider == .apple ? DSColor.pureSurface : DSColor.ink
    }
}

private enum LoginNotice: Identifiable {
    case agreementRequired

    var id: String { "agreement-required" }
    var title: String { "请先确认协议" }
    var message: String { "登录前需要阅读并同意用户协议和隐私政策。" }
}
