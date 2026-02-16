import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [OnboardingPage] = [
        .init(
            kind: .welcome,
            title: "PassTalk",
            subtitle: "说句话，密码就记好了",
            details: []
        ),
        .init(
            kind: .howItWorks,
            title: "不用填表格，聊天就能记",
            subtitle: "像发消息一样告诉我账号密码",
            details: ["我会自动帮你整理更好"]
        ),
        .init(
            kind: .privacy,
            title: "你的数据，只在你手里",
            subtitle: "密码只存在你手机里",
            details: ["只有你能看到"]
        )
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: max(48, geo.size.height * 0.08))
                illustration
                    .frame(width: illustrationSize.width, height: illustrationSize.height)
                    .contentTransition(.opacity)
                Spacer(minLength: 24)

                Group {
                    Text(pages[safePageIndex].title)
                        .font(.system(size: pages[safePageIndex].kind == .welcome ? 46 : 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                    Text(pages[safePageIndex].subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    ForEach(pages[safePageIndex].details, id: \.self) { line in
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: max(28, geo.size.height * 0.045))

                PageDots(current: safePageIndex, total: pages.count)
                    .padding(.bottom, 18)

                Button(action: handlePrimaryAction) {
                    Text(safePageIndex == pages.count - 1 ? "开始使用" : "继续")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color(red: 0.30, green: 0.30, blue: 0.32))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .padding(.horizontal, 24)
                .padding(.bottom, max(22, geo.safeAreaInsets.bottom + 8))
            }
            .contentShape(Rectangle())
            .gesture(pageSwipeGesture)
            .background(Color(white: 0.96).ignoresSafeArea())
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: page)
        }
    }

    private var illustrationSize: CGSize {
        switch pages[safePageIndex].kind {
        case .welcome:
            return CGSize(width: 220, height: 170)
        case .howItWorks:
            return CGSize(width: 284, height: 194)
        case .privacy:
            return CGSize(width: 272, height: 190)
        }
    }

    private var safePageIndex: Int {
        min(max(0, page), pages.count - 1)
    }

    private func handlePrimaryAction() {
        if safePageIndex >= pages.count - 1 {
            onFinish()
            return
        }
        withOptionalAnimation {
            page = safePageIndex + 1
        }
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < -40, safePageIndex < pages.count - 1 {
                    withOptionalAnimation {
                        page += 1
                    }
                } else if value.translation.width > 40, safePageIndex > 0 {
                    withOptionalAnimation {
                        page -= 1
                    }
                }
            }
    }

    private func withOptionalAnimation(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                updates()
            }
        }
    }

    @ViewBuilder
    private var illustration: some View {
        switch pages[safePageIndex].kind {
        case .welcome:
            OnboardingWelcomeIllustration()
        case .howItWorks:
            OnboardingHowItWorksIllustration()
        case .privacy:
            OnboardingPrivacyIllustration()
        }
    }
}

private struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { idx in
                Circle()
                    .fill(idx == current ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(idx == current ? 1.12 : 1.0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(current + 1) 页，共 \(total) 页")
    }
}

private struct OnboardingPage {
    let kind: OnboardingKind
    let title: String
    let subtitle: String
    let details: [String]
}

private enum OnboardingKind {
    case welcome
    case howItWorks
    case privacy
}

private struct OnboardingWelcomeIllustration: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingLogoMark()
                .frame(width: 58, height: 58)
        }
    }
}

private struct OnboardingHowItWorksIllustration: View {
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.27, green: 0.27, blue: 0.29))
                        .frame(width: 156, height: 52)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GitHub  alex@mail.com")
                                Text("密码 Qw!2024x")
                            }
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.leading, 12)
                        }
                }
                .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 7) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 138, height: 36)
                        .overlay(alignment: .leading) {
                            Text("已记好 ✓")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.secondary)
                                .padding(.leading, 12)
                        }
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 138, height: 44)
                        .overlay {
                            HStack {
                                Circle().fill(Color.gray.opacity(0.28)).frame(width: 14, height: 14)
                                Text("GitHub")
                                    .font(.system(size: 9, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
        }
    }
}

private struct OnboardingPrivacyIllustration: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .frame(width: 156, height: 88)
                .overlay {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 20, height: 20)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 90, height: 7)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 72, height: 7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 14)
                }

            Circle()
                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .offset(x: 10, y: 12)
        }
    }
}

private struct OnboardingLogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            HStack(spacing: 6) {
                Circle().fill(Color.gray.opacity(0.65)).frame(width: 8, height: 8)
                Circle().fill(Color.gray.opacity(0.35)).frame(width: 8, height: 8)
                Circle().fill(Color.orange).frame(width: 8, height: 8)
            }
        }
    }
}
