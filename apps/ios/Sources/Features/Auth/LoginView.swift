import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasAcceptedAgreement = false
    @State private var notice: LoginNotice?
    @State private var showsEmailLogin = false
    @StateObject private var appleAuthorization = AppleLoginAuthorization()
    @State private var isAuthorizingApple = false

    var body: some View {
        AuthIllustratedPage(compact: true) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.pendingAuthAction != nil {
                    Text(gateTitle).font(.headline)
                    Text(gateSubtitle).font(.footnote).foregroundStyle(DSColor.mutedInk)
                }
                if let errorMessage = viewModel.errorMessage {
                    DSErrorBanner(message: errorMessage)
                }
                VStack(spacing: 14) {
                    ForEach(orderedProviders) { provider in
                        AuthProviderTile(provider: provider, isLoading: viewModel.isLoading || isAuthorizingApple) {
                            beginAuthentication(with: provider)
                        }
                    }
                }
                if isAuthorizingApple || viewModel.isLoading {
                    ProgressView("正在验证账号…")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                agreementRow
            }
        }
        .overlay(alignment: .topLeading) {
            HStack {
                Button(action: viewModel.cancelAuthentication) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                .disabled(viewModel.isLoading || isAuthorizingApple)
                Spacer()
            }
            .padding(.horizontal, 16)
            .foregroundStyle(DSColor.ink)
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
        case .claimLocalDraft: "登录后选择使用云端，或保存本机家庭。两边内容都会保留。"
        case .enableCloudSync: "登录后会保留当前内容，并开启云端同步。"
        case .inviteMembers: "登录后会回到邀请家人的步骤。"
        case nil: nil
        }
    }

    private var orderedProviders: [ClientAuthProvider] {
        viewModel.availableAuthProviders.filter { $0 == .email || $0 == .apple }.sorted { left, right in
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
        } else if provider == .apple {
            guard !isAuthorizingApple else { return }
            isAuthorizingApple = true
            Task { @MainActor in
                defer { isAuthorizingApple = false }
                guard let challenge = await viewModel.requestAppleLoginChallenge() else { return }
                do {
                    let result = try await appleAuthorization.authorize(challenge)
                    await viewModel.completeAppleLogin(
                        challengeId: challenge.challengeId,
                        identityToken: result.identityToken,
                        authorizationCode: result.authorizationCode
                    )
                } catch let error as ASAuthorizationError where error.code == .canceled {
                    viewModel.errorMessage = nil
                } catch {
                    viewModel.errorMessage = "Apple 授权未完成，请重试。"
                }
            }
        }
    }

    private var agreementRow: some View {
        HStack(alignment: .top, spacing: 9) {
            Button {
                hasAcceptedAgreement.toggle()
            } label: {
                Image(systemName: hasAcceptedAgreement ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(hasAcceptedAgreement ? DSColor.infoBlue : DSColor.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("同意用户协议和隐私政策")
            .accessibilityValue(hasAcceptedAgreement ? "已勾选" : "未勾选")
            .buttonStyle(.plain)
            Text(agreementText)
                .font(.footnote)
                .tint(DSColor.infoBlue)
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private var agreementText: AttributedString {
        var text = AttributedString("我已阅读并同意")
        var terms = AttributedString("用户协议")
        terms.link = AppWebsite.terms
        text += terms
        text += AttributedString("和")
        var privacy = AttributedString("隐私政策")
        privacy.link = AppWebsite.privacy
        text += privacy
        return text
    }
}

@MainActor
private final class AppleLoginAuthorization: NSObject, ObservableObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    struct Result {
        let identityToken: String
        let authorizationCode: String
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var controller: ASAuthorizationController?
    private var anchor: ASPresentationAnchor?
    private var expectedState: String?

    func authorize(_ challenge: AppleLoginChallengeResponse) async throws -> Result {
        guard continuation == nil,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .filter({ $0.activationState == .foregroundActive })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
            throw ASAuthorizationError(.failed)
        }
        anchor = window
        expectedState = challenge.challengeId
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        request.nonce = challenge.nonce
        request.state = challenge.challengeId
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            self.controller = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              credential.state == expectedState,
              let tokenData = credential.identityToken, let codeData = credential.authorizationCode,
              let token = String(data: tokenData, encoding: .utf8),
              let code = String(data: codeData, encoding: .utf8) else {
            finish(.failure(ASAuthorizationError(.invalidResponse)))
            return
        }
        finish(.success(Result(identityToken: token, authorizationCode: code)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Swift.Result<Result, Error>) {
        let pending = continuation
        continuation = nil
        controller = nil
        anchor = nil
        expectedState = nil
        pending?.resume(with: result)
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
            ScrollView {
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
                        .font(.title2.bold())
                        .foregroundStyle(DSColor.ink)
                    Text(helperText)
                        .font(.subheadline)
                        .foregroundStyle(DSColor.mutedInk)
                }

                if let errorMessage = viewModel.errorMessage {
                    DSErrorBanner(message: errorMessage)
                }

                if challenge == nil {
                    TextField("name@example.com", text: $email)
                        .accessibilityLabel("邮箱地址")
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
                        .accessibilityLabel("六位邮箱验证码")
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
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    #if DEBUG
                    if let developmentCode = challenge?.developmentCode {
                        Text("开发环境验证码：\(developmentCode)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    #endif
                }


              }
              .padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                confirmationButton
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(DSColor.quietBackground)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isLoading)
    }

    private var confirmationButton: some View {
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
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.title3).frame(width: 32)
                Text(title).font(.headline)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(V3PrimaryButtonStyle())
        .disabled(isLoading)
    }

    private var title: String {
        switch provider {
        case .apple: "Apple 登录"
        case .wechat: "微信"
        case .email: "邮箱登录"
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

struct LoginWorkspaceChoiceView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var confirmsImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let choice = viewModel.loginWorkspaceChoice {
                    Image(systemName: "externaldrive.badge.icloud")
                        .font(.system(size: 38))
                        .foregroundStyle(DSColor.ink)
                        .accessibilityHidden(true)

                    Text(choice.cloudFamilyNames.isEmpty ? "选择这次使用的内容" : "此账号已有家庭")
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(choice.accountName).font(.headline)
                        Text(choice.cloudFamilyNames.isEmpty ? "云端还没有家庭。" : choice.cloudFamilyNames.joined(separator: "、"))
                            .foregroundStyle(DSColor.mutedInk)
                        Divider().padding(.vertical, 8)
                        Text("本机：\(choice.localFamilyName)").font(.headline)
                        Text("\(choice.localRecordCount) 条家务记录")
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Text("本机内容不会被删除。登录期间使用云端，退出后仍可继续本机记录。")
                        .foregroundStyle(DSColor.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error = viewModel.errorMessage {
                        DSErrorBanner(message: error)
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await viewModel.useCloudWorkspace() }
                        } label: {
                            Label("使用云端，保留本机", systemImage: "icloud")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(V3PrimaryButtonStyle())

                        Button {
                            confirmsImport = true
                        } label: {
                            Label("将本机保存为独立家庭", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(V3SecondaryButtonStyle())

                        Button("暂不登录，返回本机") { viewModel.logout() }
                            .foregroundStyle(DSColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .disabled(viewModel.isLoading)
                    if viewModel.isLoading {
                        ProgressView(viewModel.loadingMessage ?? "正在处理")
                            .frame(maxWidth: .infinity)
                    }
                } else if let error = viewModel.errorMessage {
                    DSRequestFailureView(title: "账号信息暂时无法读取", message: error) {
                        Task { await viewModel.retryLoginWorkspaceChoice() }
                    }
                    Button("返回本机") { viewModel.logout() }
                        .disabled(viewModel.isLoading)
                } else {
                    ProgressView("正在读取账号信息")
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DSColor.quietBackground.ignoresSafeArea())
        .navigationTitle("登录成功")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("保存本机家庭？", isPresented: $confirmsImport, titleVisibility: .visible) {
            Button("确认保存为独立家庭") {
                Task { await viewModel.importLocalWorkspaceToAccount() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本机家务和记录将复制到此账号下的新家庭，不覆盖原有云端家庭。本机副本也会保留。")
        }
    }
}
