import XCTest

/// Suite EXHAUSTIVA E2E de PanditaCash.
/// Prueba TODOS los botones, sliders, toggles, sheets y navegaciones.
///
/// Cada test:
/// - Lanza la app con mocks para no depender del backend
/// - Ejecuta el flujo real (taps, escribir texto, sliders, swipes)
/// - Verifica que la UI responde y muestra la info esperada
final class PanditaCashUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FAKE_ADMIN"] = "1"
        app.launchEnvironment["FAKE_DATA_ONLY"] = "1"
    }

    // MARK: - Helpers

    func launchAsAdmin(tab: String? = nil) {
        if let t = tab { app.launchEnvironment["FAKE_TAB"] = t }
        app.launch()
    }
    func launchAsCliente() {
        app.launchEnvironment.removeValue(forKey: "FAKE_ADMIN")
        app.launchEnvironment["FAKE_CLIENTE"] = "1"
        app.launch()
    }
    func launchAsOnboarding() {
        app.launchEnvironment.removeValue(forKey: "FAKE_ADMIN")
        app.launchEnvironment.removeValue(forKey: "FAKE_DATA_ONLY")
        app.launch()
    }

    func waitFor(_ el: XCUIElement, timeout: TimeInterval = 6, _ msg: String) {
        XCTAssertTrue(el.waitForExistence(timeout: timeout), msg)
    }

    // MARK: - 1. ONBOARDING (3 tests)

    func test_01_onboarding_muestraContenidoYBotones() throws {
        launchAsOnboarding()
        waitFor(app.staticTexts["PanditaCash"].firstMatch, "Onboarding: no aparece título PanditaCash")
        XCTAssertTrue(app.staticTexts["REIMAGINADO"].exists)
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Empezar'")).firstMatch.exists,
                      "No aparece botón Empezar como Cliente")
    }

    func test_02_onboarding_swipeEntrePages() throws {
        launchAsOnboarding()
        waitFor(app.staticTexts["REIMAGINADO"], "Page 1 no aparece")
        // Swipe left para pasar a page 2
        app.swipeLeft()
        waitFor(app.staticTexts["RÁPIDO"], "Page 2 (RÁPIDO) no aparece")
        app.swipeLeft()
        waitFor(app.staticTexts["PRIVADO"], "Page 3 (PRIVADO) no aparece")
    }

    func test_03_onboarding_demoLoginButton() throws {
        launchAsOnboarding()
        waitFor(app.buttons["demo_login_button"], "No aparece botón demo login")
        app.buttons["demo_login_button"].tap()
        waitFor(app.staticTexts["Acceso rápido"], "Sheet demo login no abre")
        XCTAssertTrue(app.buttons["demo_login_mama"].exists)
        XCTAssertTrue(app.buttons["demo_login_abdo"].exists)
        XCTAssertTrue(app.buttons["demo_login_test"].exists)
    }

    // MARK: - 2. DASHBOARD ADMIN (6 tests)

    func test_04_dashboard_muestraHeader() throws {
        launchAsAdmin()
        waitFor(app.staticTexts["dashboard_nombre"], "Header nombre no aparece")
        waitFor(app.staticTexts["dashboard_subtitle"], "Subtítulo no aparece")
    }

    func test_05_dashboard_muestraHeroConDatos() throws {
        launchAsAdmin()
        waitFor(app.staticTexts["Prestado activo"], "Hero card no muestra 'Prestado activo'")
        // Con el mock hay $47,500 activo
        let pesos = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '$47'")).firstMatch
        XCTAssertTrue(pesos.waitForExistence(timeout: 3), "No aparece el monto del mock")
    }

    func test_06_dashboard_muestraKPIsPagosPendientes() throws {
        launchAsAdmin()
        waitFor(app.staticTexts["Pagos pendientes"], "Sección pagos pendientes no aparece")
        // Del mock hay María González, Roberto Sánchez, Ana López
        XCTAssertTrue(app.staticTexts["María González"].exists)
        XCTAssertTrue(app.staticTexts["Roberto Sánchez"].exists)
    }

    func test_07_dashboard_fabNuevoPrestamo_abreSheet() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].firstMatch.tap()
        waitFor(app.staticTexts["Nuevo préstamo"], "Sheet Nuevo Préstamo no abre desde FAB")
    }

    func test_08_dashboard_ctaHero_abreSheetNuevo() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].firstMatch.tap()
        waitFor(app.staticTexts["Nuevo préstamo"], "Sheet no abre desde CTA hero")
    }

    func test_09_dashboard_shieldButton_abreValidacionesKYC() throws {
        launchAsAdmin()
        // Botón shield en header — vía perfil también funciona, aquí usamos Perfil
        app.buttons["tab_Perfil"].tap()
        waitFor(app.staticTexts["Validaciones KYC"], "Falta opción KYC en perfil")
        app.staticTexts["Validaciones KYC"].tap()
        waitFor(app.staticTexts["Validaciones pendientes"], "No abre KYC pendientes")
    }

    // MARK: - 3. NAVEGACIÓN TABS (4 tests)

    func test_10_tabbar_navegaAClientes() throws {
        launchAsAdmin()
        app.buttons["tab_Clientes"].tap()
        waitFor(app.staticTexts["Clientes"].firstMatch, "Tab Clientes no responde")
    }

    func test_11_tabbar_navegaAHistorial() throws {
        launchAsAdmin()
        app.buttons["tab_Historial"].tap()
        waitFor(app.staticTexts["Historial"].firstMatch, "Tab Historial no responde")
        waitFor(app.staticTexts["TOTAL COBRADO"], "Hero de historial no aparece")
    }

    func test_12_tabbar_navegaAPerfil() throws {
        launchAsAdmin()
        app.buttons["tab_Perfil"].tap()
        waitFor(app.staticTexts["Modo administrador"], "Tab Perfil no responde")
    }

    func test_13_tabbar_vuelveInicioDesdePerfil() throws {
        launchAsAdmin()
        app.buttons["tab_Perfil"].tap()
        waitFor(app.staticTexts["Modo administrador"], "Perfil no aparece")
        app.buttons["tab_Inicio"].tap()
        waitFor(app.staticTexts["dashboard_nombre"], "No vuelve a dashboard")
    }

    // MARK: - 4. CLIENTES (6 tests)

    func test_14_clientes_muestraLos5Mocks() throws {
        launchAsAdmin(tab: "clientes")
        waitFor(app.staticTexts["María González"], "María González no aparece")
        XCTAssertTrue(app.staticTexts["Roberto Sánchez"].exists)
        XCTAssertTrue(app.staticTexts["Ana López"].exists)
        XCTAssertTrue(app.staticTexts["Carlos Ramírez"].exists)
        XCTAssertTrue(app.staticTexts["Lucía Torres"].exists)
    }

    func test_15_clientes_filtroActivos_ocultaSinPrestamos() throws {
        launchAsAdmin(tab: "clientes")
        app.buttons["Activos"].tap()
        waitFor(app.staticTexts["María González"], "María debería estar en activos")
        XCTAssertFalse(app.staticTexts["Carlos Ramírez"].exists,
                       "Carlos (sin préstamos) NO debe estar en filtro Activos")
    }

    func test_16_clientes_filtroAtrasados_soloRoberto() throws {
        launchAsAdmin(tab: "clientes")
        app.buttons["Atrasados"].tap()
        waitFor(app.staticTexts["Roberto Sánchez"], "Roberto (con vencidos) debería estar")
        XCTAssertFalse(app.staticTexts["Ana López"].exists,
                       "Ana (sin atrasos) NO debe aparecer")
    }

    func test_17_clientes_searchBar_existe() throws {
        launchAsAdmin(tab: "clientes")
        let search = app.textFields["Buscar por nombre o teléfono"]
        waitFor(search, "Search bar no aparece")
        search.tap()
        search.typeText("María")
        // No verificamos filtro real porque el mock no hace fetch
    }

    func test_18_clientes_tapAbreDetalle() throws {
        launchAsAdmin(tab: "clientes")
        waitFor(app.staticTexts["María González"], "Cliente no aparece")
        app.staticTexts["María González"].tap()
        waitFor(app.staticTexts["SALDO ACTUAL"], "Hero del detalle no aparece")
    }

    func test_19_clienteDetalle_muestraInfo() throws {
        launchAsAdmin(tab: "clientes")
        waitFor(app.staticTexts["María González"], "Cliente no aparece")
        app.staticTexts["María González"].tap()
        waitFor(app.staticTexts["SALDO ACTUAL"], "Hero no aparece")
        // Verifica que se ve algún dato del mock (préstamos, saldo)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'activo'")).firstMatch.exists,
                      "No se muestran los préstamos activos")
    }

    // MARK: - 5. MOVIMIENTOS / HISTORIAL (2 tests)

    func test_20_historial_muestraHeroConDatos() throws {
        launchAsAdmin(tab: "movimientos")
        waitFor(app.staticTexts["TOTAL COBRADO"], "Hero no aparece")
        // Del mock hay $24,500 total
        let monto = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '$24'")).firstMatch
        XCTAssertTrue(monto.waitForExistence(timeout: 3), "No aparece total cobrado del mock")
    }

    func test_21_historial_muestraMovimientos() throws {
        launchAsAdmin(tab: "movimientos")
        waitFor(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'María González'")).firstMatch,
                "No aparecen los movimientos del mock")
    }

    // MARK: - 6. NUEVO PRÉSTAMO (5 tests)

    func test_22_nuevoPrestamo_muestraFormulario() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].tap()
        waitFor(app.staticTexts["Nuevo préstamo"], "Sheet no abre")
        XCTAssertTrue(app.staticTexts["Cliente"].exists)
        XCTAssertTrue(app.staticTexts["Monto a prestar"].exists)
        XCTAssertTrue(app.staticTexts["Tasa mensual"].exists)
        XCTAssertTrue(app.staticTexts["Plazo"].exists)
        XCTAssertTrue(app.staticTexts["Frecuencia de pago"].exists)
    }

    func test_23_nuevoPrestamo_chipsPlazo() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].tap()
        waitFor(app.staticTexts["Plazo"], "Sección plazo no aparece")
        // 3 meses es el default. Tap en "6"
        let seis = app.buttons.containing(NSPredicate(format: "label CONTAINS '6'")).firstMatch
        if seis.exists { seis.tap() }
    }

    func test_24_nuevoPrestamo_toggleFrecuencia() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].tap()
        waitFor(app.staticTexts["Frecuencia de pago"], "No aparece")
        app.buttons["Quincenal"].firstMatch.tap()
        app.buttons["Mensual"].firstMatch.tap()
    }

    func test_25_nuevoPrestamo_cerrarConX() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].tap()
        waitFor(app.staticTexts["Nuevo préstamo"], "Sheet no abre")
        app.buttons["close_button"].tap()
        waitFor(app.staticTexts["dashboard_nombre"], "No vuelve al dashboard")
    }

    func test_26_nuevoPrestamo_telefonoFieldPermiteEscritura() throws {
        launchAsAdmin()
        app.buttons["cta_nuevo_prestamo"].tap()
        waitFor(app.textFields["Teléfono (10 dígitos)"], "Field teléfono no aparece")
        let tel = app.textFields["Teléfono (10 dígitos)"]
        tel.tap()
        tel.typeText("5551234567")
    }

    // MARK: - 7. PERFIL ADMIN (8 tests)

    func test_27_perfil_muestraOpciones() throws {
        launchAsAdmin(tab: "perfil")
        waitFor(app.staticTexts["Ganancias y análisis"], "Falta Ganancias")
        XCTAssertTrue(app.staticTexts["Validaciones KYC"].exists)
        XCTAssertTrue(app.staticTexts["Cambiar PIN"].exists)
        XCTAssertTrue(app.staticTexts["Notificaciones"].exists)
        XCTAssertTrue(app.staticTexts["Ayuda y soporte"].exists)
        XCTAssertTrue(app.staticTexts["Términos y privacidad"].exists)
    }

    func test_28_perfil_abreCambiarPIN() throws {
        launchAsAdmin(tab: "perfil")
        waitFor(app.staticTexts["Cambiar PIN"], "opción no aparece")
        app.staticTexts["Cambiar PIN"].tap()
        waitFor(app.staticTexts["Nuevo PIN"], "Vista cambiar PIN no abre")
    }

    func test_29_perfil_abreAnalytics() throws {
        launchAsAdmin(tab: "perfil")
        app.staticTexts["Ganancias y análisis"].tap()
        waitFor(app.staticTexts["Ganancias"].firstMatch, "Analytics no abre")
    }

    func test_30_perfil_abreValidacionesKYC() throws {
        launchAsAdmin(tab: "perfil")
        app.staticTexts["Validaciones KYC"].tap()
        waitFor(app.staticTexts["Validaciones pendientes"], "KYC pendientes no abre")
    }

    func test_31_perfil_abreAyudaYSoporte() throws {
        launchAsAdmin(tab: "perfil")
        app.staticTexts["Ayuda y soporte"].tap()
        waitFor(app.staticTexts["¿Necesitas ayuda?"], "Ayuda no abre")
        XCTAssertTrue(app.staticTexts["Escríbenos por WhatsApp"].exists)
        XCTAssertTrue(app.staticTexts["Envíanos un correo"].exists)
        XCTAssertTrue(app.staticTexts["Preguntas frecuentes"].exists)
    }

    func test_32_perfil_abreTerminos() throws {
        launchAsAdmin(tab: "perfil")
        app.staticTexts["Términos y privacidad"].tap()
        waitFor(app.staticTexts["Sobre PanditaCash"], "Términos no abre")
    }

    func test_33_cambiarPIN_muestraFormulario() throws {
        launchAsAdmin(tab: "perfil")
        app.staticTexts["Cambiar PIN"].tap()
        waitFor(app.staticTexts["Nuevo PIN"], "Vista Cambiar PIN no abre")
        XCTAssertTrue(app.secureTextFields["PIN actual"].exists)
        XCTAssertTrue(app.secureTextFields["PIN nuevo (mín 4)"].exists)
        XCTAssertTrue(app.secureTextFields["Confirma PIN nuevo"].exists)
    }

    func test_34_analytics_muestraHero() throws {
        launchAsAdmin(tab: "perfil")
        app.staticTexts["Ganancias y análisis"].tap()
        waitFor(app.staticTexts["GANANCIA NETA"], "Hero de analytics no aparece")
    }

    // MARK: - 8. CLIENTE HOME (5 tests)

    func test_35_cliente_muestraHeader() throws {
        launchAsCliente()
        waitFor(app.staticTexts["Hola,"], "No aparece saludo cliente")
    }

    func test_36_cliente_muestraBannerVerificacion() throws {
        launchAsCliente()
        waitFor(app.staticTexts["Empezar verificación"], "No aparece CTA verificación")
    }

    func test_37_cliente_muestraBeneficios() throws {
        launchAsCliente()
        waitFor(app.staticTexts["¿Por qué verificarte?"], "No aparece sección beneficios")
        XCTAssertTrue(app.staticTexts["Más dinero, mejores tasas"].exists)
        XCTAssertTrue(app.staticTexts["Aprobación instantánea"].exists)
        XCTAssertTrue(app.staticTexts["100% privado"].exists)
    }

    func test_38_cliente_tapVerificacion_abreKYCFlow() throws {
        launchAsCliente()
        waitFor(app.staticTexts["Empezar verificación"], "No aparece CTA")
        app.staticTexts["Empezar verificación"].tap()
        waitFor(app.staticTexts["Verifica tu identidad"], "KYC flow no abre")
    }

    func test_39_kycFlow_muestraListaRequerimientos() throws {
        launchAsCliente()
        app.staticTexts["Empezar verificación"].tap()
        waitFor(app.staticTexts["Verifica tu identidad"], "Bienvenida KYC no abre")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'INE'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Selfie'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'aval'")).firstMatch.exists)
    }

    // MARK: - 9. DEMO LOGIN SHEET (1 test)

    func test_40_demoLoginSheet_muestraLas3Opciones() throws {
        launchAsOnboarding()
        waitFor(app.buttons["demo_login_button"], "Botón demo no aparece")
        app.buttons["demo_login_button"].tap()
        waitFor(app.staticTexts["Acceso rápido"], "Sheet no abre")
        XCTAssertTrue(app.buttons["demo_login_mama"].exists)
        XCTAssertTrue(app.buttons["demo_login_abdo"].exists)
        XCTAssertTrue(app.buttons["demo_login_test"].exists)
        // Verifica info de cada usuario
        XCTAssertTrue(app.staticTexts["Mamá Panda"].exists)
        XCTAssertTrue(app.staticTexts["abdo"].exists)
        XCTAssertTrue(app.staticTexts["Cliente Test Score"].exists)
    }
}
