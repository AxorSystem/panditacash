import SwiftUI
import UIKit

struct AyudaSoporteView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    hero.padding(.horizontal, 20).padding(.top, 20)
                    contactCard.padding(.horizontal, 20)
                    faqCard.padding(.horizontal, 20)
                    Spacer(minLength: 60)
                }
            }
        }
        .navigationTitle("Ayuda y soporte")
        .navigationBarTitleDisplayMode(.inline)
    }

    var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 110, height: 110)
                Image(systemName: "questionmark.circle.fill").font(.system(size: 54)).foregroundColor(Theme.deepGreen)
            }
            Text("¿Necesitas ayuda?").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Estamos para ayudarte")
                .font(PType.body(14)).foregroundColor(Theme.inkSoft)
        }
    }

    var contactCard: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                openWA()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.success).frame(width: 46, height: 46)
                        Image(systemName: "message.fill").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Escríbenos por WhatsApp").font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                        Text("Respondemos en 10 min").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Theme.inkMuted).font(.system(size: 13, weight: .semibold))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
            }
            .buttonStyle(PressableStyle(scale: 0.98))

            Button {
                Haptics.tap()
                UIApplication.shared.open(URL(string: "mailto:soporte@axorcloud.com?subject=Soporte%20PanditaCash")!)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.info).frame(width: 46, height: 46)
                        Image(systemName: "envelope.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Envíanos un correo").font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                        Text("soporte@axorcloud.com").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Theme.inkMuted).font(.system(size: 13, weight: .semibold))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
            }
            .buttonStyle(PressableStyle(scale: 0.98))
        }
    }

    var faqCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preguntas frecuentes").font(PType.title(20)).foregroundColor(Theme.ink).padding(.top, 8)
            faqItem("¿Cómo pido un préstamo?",
                    "Primero verifica tu identidad (foto INE, selfie y aval). Después toca 'Solicitar préstamo' y mamá revisará tu petición.")
            faqItem("¿Cómo se calcula la tasa?",
                    "La tasa depende de tu score de confianza. Nivel Oro tiene la tasa más baja, nivel Inicial la más alta.")
            faqItem("¿Puedo pagar antes?",
                    "Sí. Todo pago adelantado reduce tu deuda y sube tu score para el próximo préstamo.")
        }
    }

    func faqItem(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(q).font(PType.bodyBold(14)).foregroundColor(Theme.ink)
            Text(a).font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surfaceLight))
    }

    func openWA() {
        let tel = "525525034846"
        let msg = "Hola, necesito ayuda con PanditaCash".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/\(tel)?text=\(msg)") {
            UIApplication.shared.open(url)
        }
    }
}

struct TerminosPrivacidadView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    seccion("Sobre PanditaCash",
                            "PanditaCash es una app de gestión de préstamos personales operada por AxorSystem. No somos una institución financiera regulada; funcionamos como intermediario para gestionar préstamos entre familiares y conocidos.")
                    seccion("Tu información",
                            "Toda la información que subes (INE, selfie, comprobantes) se almacena encriptada en servidores privados dentro de México. Solo tu prestamista puede ver esta información — nunca la compartimos con terceros ni la usamos para publicidad.")
                    seccion("Cómo cobramos",
                            "PanditaCash no cobra comisiones al cliente. La tasa de interés la define tu prestamista al aprobar el préstamo. Los cargos automáticos vía tarjeta cuando estén disponibles serán opcionales y transparentes.")
                    seccion("Baja de cuenta",
                            "Puedes solicitar la eliminación de tu cuenta y datos en cualquier momento contactando a soporte@axorcloud.com. Los datos se eliminan de nuestros servidores en máximo 30 días.")
                    seccion("Contacto",
                            "AxorSystem · soporte@axorcloud.com · WhatsApp +52 55 2503 4846")
                }
                .padding(20)
            }
        }
        .navigationTitle("Términos y privacidad")
        .navigationBarTitleDisplayMode(.inline)
    }

    func seccion(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).font(PType.title(18)).foregroundColor(Theme.ink)
            Text(texto).font(PType.body(14)).foregroundColor(Theme.inkSoft)
        }
    }
}
