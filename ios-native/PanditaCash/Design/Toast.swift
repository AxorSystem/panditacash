import SwiftUI
import Combine

final class ToastCenter: ObservableObject {
    @Published var current: ToastData?
    private var task: Task<Void, Never>?

    func show(_ text: String, kind: ToastKind = .info) {
        task?.cancel()
        current = ToastData(text: text, kind: kind)
        switch kind {
        case .success: Haptics.success()
        case .error: Haptics.error()
        case .info: Haptics.soft()
        }
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { current = nil }
        }
    }

    func dismiss() {
        task?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { current = nil }
    }
}

enum ToastKind { case success, error, info }
struct ToastData: Identifiable { let id = UUID(); let text: String; let kind: ToastKind }

struct ToastOverlay: View {
    @EnvironmentObject var toast: ToastCenter

    var body: some View {
        if let t = toast.current {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(iconBg(for: t.kind)).frame(width: 44, height: 44)
                    Image(systemName: icon(for: t.kind))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(iconColor(for: t.kind))
                }
                Text(t.text)
                    .font(PType.bodyBold(15))
                    .foregroundColor(Theme.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Button {
                    toast.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Theme.inkMuted)
                        .padding(6)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(iconColor(for: t.kind))
                            .frame(width: 4)
                            .padding(.leading, -1)
                            .padding(.vertical, 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .shadow(color: iconColor(for: t.kind).opacity(0.35), radius: 24, y: 12)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    func icon(for k: ToastKind) -> String {
        switch k {
        case .success: "checkmark"
        case .error: "exclamationmark"
        case .info: "info"
        }
    }
    func iconColor(for k: ToastKind) -> Color {
        switch k {
        case .success: Theme.success
        case .error: Theme.danger
        case .info: Theme.deepGreen
        }
    }
    func iconBg(for k: ToastKind) -> Color {
        switch k {
        case .success: Theme.softSuccess
        case .error: Theme.softDanger
        case .info: Theme.softPrimary
        }
    }
}
