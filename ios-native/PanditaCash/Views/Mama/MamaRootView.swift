import SwiftUI

struct MamaRootView: View {
    @State private var tab: Tab = {
        switch ProcessInfo.processInfo.environment["FAKE_TAB"] {
        case "clientes": .clientes
        case "movimientos": .movimientos
        case "perfil": .perfil
        default: .dashboard
        }
    }()

    enum Tab: Hashable { case dashboard, clientes, movimientos, perfil }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch tab {
                    case .dashboard: MamaDashboardView()
                    case .clientes: MamaClientesView()
                    case .movimientos: MamaMovimientosView()
                    case .perfil: PerfilView()
                    }
                }
                .transition(.opacity)

                FloatingTabBar(current: $tab)
            }
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea(.keyboard)
        }
        .tint(Theme.deepGreen)
    }
}

// Floating pill tab bar (estilo real-estate)
struct FloatingTabBar: View {
    @Binding var current: MamaRootView.Tab
    @Namespace private var pillNs

    private let items: [(MamaRootView.Tab, String, String)] = [
        (.dashboard, "Inicio", "house.fill"),
        (.clientes, "Clientes", "magnifyingglass"),
        (.movimientos, "Historial", "calendar"),
        (.perfil, "Perfil", "person.fill"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.0) { item in
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        current = item.0
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.2)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(current == item.0 ? .white : Theme.deepGreen)
                        if current == item.0 {
                            Text(item.1)
                                .font(PType.bodyBold(14))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .padding(.horizontal, current == item.0 ? 18 : 14)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            if current == item.0 {
                                Capsule()
                                    .fill(Theme.deepGreen)
                                    .matchedGeometryEffect(id: "pill", in: pillNs)
                            }
                        }
                    )
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .accessibilityIdentifier("tab_\(item.1)")
                .accessibilityLabel(item.1)
            }
        }
        .padding(6)
        .background(
            Capsule().fill(Color.white)
                .shadow(color: Theme.deepGreen.opacity(0.15), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}
