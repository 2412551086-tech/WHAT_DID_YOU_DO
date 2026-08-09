import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasAcceptedAgreement = false
    @State private var isPhoneLoginPresented = false
    @State private var notice: LoginNotice?
    @State private var copySeed = Int.random(in: 0..<10_000)

    var body: some View {
        ZStack {
            Image("login_household_battle")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if colorScheme == .dark {
                Color.black
                    .opacity(0.42)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: heroHeight)
                        .accessibilityHidden(true)

                    VStack(spacing: 14) {
                        statusBanner

                        LoginActionButton(
                            title: "手机号登录",
                            systemImage: "iphone",
                            fill: DSColor.yellow,
                            isLoading: viewModel.isLoading
                        ) {
                            beginPhoneLogin()
                        }

                        LoginActionButton(
                            title: "微信登录",
                            systemImage: "bubble.left.and.bubble.right.fill",
                            fill: DSColor.sky
                        ) {
                            notice = .comingSoon("微信登录")
                        }

                        LoginActionButton(
                            title: "Apple 登录",
                            systemImage: "apple.logo",
                            fill: DSColor.surface
                        ) {
                            notice = .comingSoon("Apple 登录")
                        }

                        Text(RotatingCopy.value(from: RotatingCopy.login, seed: copySeed))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DSColor.mutedInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        agreementRow
                    }
                    .padding(.horizontal, 38)
                    .padding(.bottom, 28)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("家庭保卫战登录")
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isPhoneLoginPresented) {
            PhoneLoginSheet()
                .environmentObject(viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .onChange(of: viewModel.sessionState) { _, newState in
            if newState == .authenticated {
                isPhoneLoginPresented = false
            }
        }
        .onAppear {
            copySeed = Int.random(in: 0..<10_000)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var agreementRow: some View {
        Button {
            hasAcceptedAgreement.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: hasAcceptedAgreement ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(hasAcceptedAgreement ? DSColor.infoBlue : DSColor.ink)

                agreementText
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            LoginAccentStar()
                .frame(width: 30, height: 36)
                .offset(x: -28, y: -18)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(hasAcceptedAgreement ? "已同意用户协议和隐私政策" : "同意用户协议和隐私政策")
        .accessibilityValue(hasAcceptedAgreement ? "已选择" : "未选择")
    }

    private var agreementText: Text {
        Text("我已阅读并同意 ")
            .foregroundColor(DSColor.ink)
        + Text("用户协议")
            .foregroundColor(DSColor.infoBlue)
            .underline()
        + Text(" 和 ")
            .foregroundColor(DSColor.ink)
        + Text("隐私政策")
            .foregroundColor(DSColor.infoBlue)
            .underline()
    }

    private var heroHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 410 : 579
    }

    private func beginPhoneLogin() {
        guard hasAcceptedAgreement else {
            notice = .agreementRequired
            return
        }
        isPhoneLoginPresented = true
    }
}

private struct PhoneLoginSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: PhoneLoginField?
    @State private var verificationCode = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("手机号登录")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("开发登录暂不校验手机号长度。")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    loginTextField(
                        title: "输入手机号",
                        systemImage: "iphone"
                    ) {
                        TextField("输入手机号", text: $viewModel.phoneNumber)
                            .font(.system(size: 18, weight: .medium))
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focusedField, equals: .phone)
                    }

                    loginTextField(
                        title: "输入验证码",
                        systemImage: "number"
                    ) {
                        TextField("输入验证码", text: $verificationCode)
                            .font(.system(size: 18, weight: .medium))
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField, equals: .code)
                            .submitLabel(.done)
                            .onSubmit {
                                viewModel.mockLogin()
                            }
                    }

                    Text("当前开发阶段暂不校验验证码；登录后会沿用账号已有昵称。")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DSColor.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    PhoneLoginSubmitButton(
                        title: "登录并进入家庭",
                        systemImage: "arrow.right.circle.fill",
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.mockLogin()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(DSColor.quietBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .onAppear {
            focusedField = viewModel.phoneNumber.isEmpty ? .phone : .code
        }
    }

    private func loginTextField<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 26)

            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(DSColor.pureSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DSColor.outline.opacity(0.9), lineWidth: 1.5)
        )
        .accessibilityLabel(title)
    }
}

private enum PhoneLoginField: Hashable {
    case phone
    case code
}

private struct PhoneLoginSubmitButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DSColor.ink)
                } else {
                    Image(systemName: systemImage)
                }

                Text(isLoading ? "正在登录…" : title)
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(DSColor.yellow)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DSColor.outline, lineWidth: 1.8)
            }
            .opacity(isLoading ? 0.65 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

private struct LoginActionButton: View {
    let title: String
    let systemImage: String
    let fill: Color
    var isLoading = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(DSColor.shadow.opacity(0.92))
                    .offset(
                        x: isPressed ? 2 : 7,
                        y: isPressed ? 2 : 8
                    )

                ZStack {
                    Text(isLoading ? "正在登录…" : title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(DSColor.ink)
                                .frame(width: 34, height: 34)
                        } else if title == "微信登录" {
                            WeChatLoginIcon(cutoutColor: fill)
                                .frame(width: 30, height: 26)
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 27, weight: .semibold))
                                .frame(width: 34, height: 34)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .foregroundStyle(DSColor.ink)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(DSColor.outline, lineWidth: 1.8)
                )
            }
            .padding(.trailing, 7)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isLoading { isPressed = true }
                }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .accessibilityHint(title == "手机号登录" ? "打开手机号输入" : "该登录方式即将支持")
    }
}

private struct WeChatLoginIcon: View {
    let cutoutColor: Color

    var body: some View {
        ZStack {
            Image(systemName: "message.fill")
                .font(.system(size: 22, weight: .black))
                .offset(x: -5, y: -2)

            Circle()
                .fill(cutoutColor)
                .frame(width: 2.7, height: 2.7)
                .offset(x: -8, y: -5)
            Circle()
                .fill(cutoutColor)
                .frame(width: 2.7, height: 2.7)
                .offset(x: -2, y: -5)

            Image(systemName: "message.fill")
                .font(.system(size: 18, weight: .black))
                .offset(x: 6, y: 5)

            Circle()
                .fill(cutoutColor)
                .frame(width: 2.3, height: 2.3)
                .offset(x: 3, y: 3)
            Circle()
                .fill(cutoutColor)
                .frame(width: 2.3, height: 2.3)
                .offset(x: 8, y: 3)
        }
        .foregroundStyle(DSColor.ink)
    }
}

private struct LoginAccentStar: View {
    var body: some View {
        FourPointSparkle()
            .fill(DSColor.yellow)
            .overlay {
                FourPointSparkle()
                    .stroke(DSColor.outline, lineWidth: 2.4)
            }
            .rotationEffect(.degrees(-12))
    }
}

private struct FourPointSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = [
            CGPoint(x: center.x, y: rect.minY),
            CGPoint(x: center.x + rect.width * 0.16, y: center.y - rect.height * 0.14),
            CGPoint(x: rect.maxX, y: center.y),
            CGPoint(x: center.x + rect.width * 0.16, y: center.y + rect.height * 0.14),
            CGPoint(x: center.x, y: rect.maxY),
            CGPoint(x: center.x - rect.width * 0.16, y: center.y + rect.height * 0.14),
            CGPoint(x: rect.minX, y: center.y),
            CGPoint(x: center.x - rect.width * 0.16, y: center.y - rect.height * 0.14)
        ]

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private enum LoginNotice: Identifiable {
    case agreementRequired
    case comingSoon(String)

    var id: String {
        switch self {
        case .agreementRequired: return "agreement"
        case .comingSoon(let name): return "coming-soon-\(name)"
        }
    }

    var title: String {
        switch self {
        case .agreementRequired: return "请先确认协议"
        case .comingSoon(let name): return name
        }
    }

    var message: String {
        switch self {
        case .agreementRequired:
            return "请先阅读并同意用户协议和隐私政策。"
        case .comingSoon:
            return "该登录方式即将支持，本地联调请使用手机号登录。"
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppViewModel(forceMockData: true))
}
