import SwiftUI

struct EditarTagsSheet: View {
    let clienteId: Int
    let nombreCliente: String
    @State var tags: [String]
    let onSaved: ([String]) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @State private var input = ""
    @State private var saving = false

    private let sugeridas = ["vip", "frecuente", "moroso", "trabajo", "familia", "amigo", "puntual", "problemático"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Etiqueta a \(nombreCliente) para encontrarlo rápido y verlo de un vistazo.")
                        .font(PType.body(13)).foregroundColor(Theme.inkSoft)

                    Text("Actuales").font(PType.caption(11)).foregroundColor(Theme.inkSoft).tracking(0.6)
                    FlowChips(items: tags) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(PType.bodyBold(12))
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.deepGreen))
                        .onTapGesture { tags.removeAll { $0 == tag } }
                    }
                    if tags.isEmpty {
                        Text("Sin etiquetas aún")
                            .font(PType.body(12)).foregroundColor(Theme.inkMuted)
                    }

                    HStack {
                        TextField("Nueva etiqueta…", text: $input)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceLight))
                        Button {
                            agregar(input)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26)).foregroundColor(Theme.deepGreen)
                        }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Text("Sugeridas").font(PType.caption(11)).foregroundColor(Theme.inkSoft).tracking(0.6)
                    FlowChips(items: sugeridas.filter { !tags.contains($0) }) { s in
                        Text(s).font(PType.body(12)).foregroundColor(Theme.deepGreen)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().stroke(Theme.deepGreen, lineWidth: 1))
                            .onTapGesture { agregar(s) }
                    }

                    Spacer()
                    DuoButton(title: "Guardar etiquetas", icon: "checkmark", loading: saving) {
                        Task { await guardar() }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
            }
            .navigationTitle("Etiquetas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundColor(Theme.deepGreen)
                }
            }
        }
    }

    private func agregar(_ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty, !tags.contains(t), tags.count < 8, t.count <= 24 else { return }
        tags.append(t)
        input = ""
    }

    struct TagsBody: Encodable { let tags: [String] }

    private func guardar() async {
        saving = true; defer { saving = false }
        do {
            struct R: Decodable { let ok: Bool; let tags: [String]? }
            let r: R = try await APIClient.shared.put("clientes/\(clienteId)/tags", body: TagsBody(tags: tags))
            onSaved(r.tags ?? tags)
            Haptics.success()
            toast.show("Etiquetas guardadas", kind: .success)
            AppEvent.post(AppEvent.clientesChanged)
            dismiss()
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}

/// Layout que fluye los chips en múltiples líneas cuando no caben.
struct FlowChips<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        let (_, totalH) = layout(subviews: subviews, width: width)
        return CGSize(width: width, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (positions, _) = layout(subviews: subviews, width: bounds.width)
        for (idx, pos) in positions.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y),
                                anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> ([CGPoint], CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 {
                x = 0; y += lineH + spacing; lineH = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return (positions, y + lineH)
    }
}
