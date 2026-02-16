import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        .init(title: "PassTalk", subtitle: "说句话，密码就记好了", detail: "像聊天一样录入账号和密码"),
        .init(title: "自动追问", subtitle: "缺少字段会提示补充", detail: "并自动分配预设标签，保持整洁"),
        .init(title: "你的数据在你手里", subtitle: "本地存储，V1 不做云同步", detail: "未来支持 iCloud Pro 同步")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)
            logoMark
            Spacer(minLength: 28)

            Group {
                Text(pages[safePageIndex].title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                Text(pages[safePageIndex].subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                Text(pages[safePageIndex].detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 40)

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == safePageIndex ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 18)

            Button(action: handlePrimaryAction) {
                Text(safePageIndex == pages.count - 1 ? "开始使用" : "继续")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .background(Color(white: 0.96).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    private var safePageIndex: Int {
        min(max(0, page), pages.count - 1)
    }

    private func handlePrimaryAction() {
        if safePageIndex >= pages.count - 1 {
            onFinish()
            return
        }
        page = safePageIndex + 1
    }

    private var logoMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .frame(width: 56, height: 36)
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            HStack(spacing: 6) {
                Circle().fill(Color.gray.opacity(0.65)).frame(width: 6, height: 6)
                Circle().fill(Color.gray.opacity(0.35)).frame(width: 6, height: 6)
                Circle().fill(Color.orange).frame(width: 6, height: 6)
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let detail: String
}
