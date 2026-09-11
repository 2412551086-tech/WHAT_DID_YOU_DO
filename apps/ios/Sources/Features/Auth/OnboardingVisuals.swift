import SwiftUI
import UIKit

enum V3OnboardingColor {
    static let butter = Color(red: 254.0 / 255, green: 207.0 / 255, blue: 46.0 / 255)
    static let rose = Color(red: 249.0 / 255, green: 151.0 / 255, blue: 192.0 / 255)
    static let buttonInk = Color(red: 0.25, green: 0.20, blue: 0.12)

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.095) : .white
    }
}

struct V3OnboardingBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        V3OnboardingColor.surface(colorScheme)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct V3PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(V3OnboardingColor.buttonInk.opacity(isEnabled ? 1 : 0.65))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(V3OnboardingColor.butter)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: V3OnboardingColor.buttonInk.opacity(colorScheme == .dark ? 0.15 : 0.07), radius: configuration.isPressed ? 1 : 4, y: configuration.isPressed ? 1 : 2)
            }
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct V3SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(V3OnboardingColor.buttonInk)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minHeight: 54)
            .background(V3OnboardingColor.rose.opacity(configuration.isPressed ? 0.9 : 1), in: RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct V3StepIllustration: View {
    let step: String
    @Environment(\.colorScheme) private var colorScheme

    private var cell: Int? {
        switch step {
        case "family": 0
        case "nickname": 1
        case "identity": 2
        case "invite": 3
        default: nil
        }
    }

    var body: some View {
        Group {
            if let cell {
                GeometryReader { geometry in
                    let width = min(geometry.size.width, geometry.size.height * 1.5)
                    let height = width / 1.5
                    // Fixed cells preserve the original illustration atlas and its margins.
                    Image(colorScheme == .dark ? "auth_v3_scenes_dark" : "auth_v3_scenes")
                        .resizable()
                        .frame(width: width * 2, height: height * 2)
                        .offset(x: -CGFloat(cell % 2) * width, y: -CGFloat(cell / 2) * height)
                        .frame(width: width, height: height, alignment: .topLeading)
                        .clipped()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .blendMode(colorScheme == .dark ? .screen : .multiply)
            } else {
                Image(colorScheme == .dark ? "subscription_teamwork_dark" : "subscription_teamwork")
                    .resizable()
                    .scaledToFit()
                    .blendMode(colorScheme == .dark ? .normal : .multiply)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct V3HouseholdPreview: View {
    let familyName: String
    let memberName: String
    @State private var showsWeekly = false
    @State private var keyboardVisible = false

    private var name: String {
        let value = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "我们的小家" : value
    }

    private var member: String {
        let value = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "我" : value
    }

    var body: some View {
        Group {
            if !keyboardVisible {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(name).font(.headline).lineLimit(2)
                        Spacer(minLength: 8)
                        Text("示例").font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("小家预览", selection: $showsWeekly) {
                        Text("家务记录").tag(false)
                        Text("每周战况").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if showsWeekly {
                        VStack(alignment: .leading, spacing: 12) {
                            contribution(member, minutes: 15, fraction: 0.6, color: V3OnboardingColor.rose)
                            contribution("家人", minutes: 10, fraction: 0.4, color: Color(red: 0.24, green: 0.64, blue: 0.58))
                        }
                    } else {
                        VStack(spacing: 12) {
                            record("洗碗收桌", asset: "chore_core_dishes_cleanup", person: member, minutes: 15)
                            record("拖地清洁", asset: "chore_core_mop_floor", person: "家人", minutes: 10)
                        }
                    }
                }
                .padding(.top, 20)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("小家示例，不会保存到实际记录")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
    }

    private func record(_ title: String, asset: String, person: String, minutes: Int) -> some View {
        HStack(spacing: 12) {
            Image(asset).resizable().scaledToFit().frame(width: 38, height: 38).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(person).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(minutes) 分钟").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func contribution(_ person: String, minutes: Int, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(person).lineLimit(1)
                Spacer()
                Text("\(minutes) 分钟")
            }.font(.subheadline)
            ProgressView(value: fraction).tint(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person)，\(minutes)分钟")
    }
}
