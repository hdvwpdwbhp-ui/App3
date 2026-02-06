import SwiftUI
import WebKit

struct LocalHTMLWebView: UIViewRepresentable {
    let fileName: String
    let fileExtension: String

    func makeCoordinator() -> Coordinator {
        print("🔧 makeCoordinator() aufgerufen")
        return Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        print("🔧 makeUIView() aufgerufen")
        
        // WICHTIG: Coordinator MUSS zuerst erstellt sein
        let coordinator = context.coordinator
        
        // User Content Controller mit Message Handlers
        let contentController = WKUserContentController()
        
        // Registriere Message Handlers
        contentController.add(coordinator, name: "audio")
        print("✅ Message Handler 'audio' registriert")
        
        contentController.add(coordinator, name: "diktat")
        print("✅ Message Handler 'diktat' registriert")
        
        contentController.add(coordinator, name: "notifications")
        print("✅ Message Handler 'notifications' registriert")

        // WebView Configuration
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        // WICHTIG: Preferences setzen
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        // Developer Extras aktivieren (für Debugging)
        if #available(iOS 16.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        
        print("✅ WKWebViewConfiguration erstellt")

        // WebView erstellen
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        coordinator.webView = webView
        
        // Inspection aktivieren (iOS 16.4+)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
            print("✅ WebView Inspection aktiviert")
        }
        
        print("✅ WKWebView erstellt")

        // HTML laden
        if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            print("✅ HTML gefunden: \(url.path)")
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            print("❌ HTML NICHT gefunden: \(fileName).\(fileExtension)")
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // nothing
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        
        // WKNavigationDelegate - Debugging
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🔄 WebView startet Navigation")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView Navigation abgeschlossen")
            
            // Injiziere Test-Script um zu verifizieren dass Handler verfügbar sind
            let testScript = """
            console.log('=== WebKit Test ===');
            if (window.webkit) {
                console.log('✅ window.webkit verfügbar');
                if (window.webkit.messageHandlers) {
                    console.log('✅ messageHandlers verfügbar');
                    console.log('Verfügbare Handler:', Object.keys(window.webkit.messageHandlers));
                } else {
                    console.log('❌ messageHandlers NICHT verfügbar');
                }
            } else {
                console.log('❌ window.webkit NICHT verfügbar');
            }
            """
            
            webView.evaluateJavaScript(testScript) { result, error in
                if let error = error {
                    print("❌ JavaScript Test Fehler: \(error.localizedDescription)")
                } else {
                    print("✅ JavaScript Test erfolgreich")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView Navigation Fehler: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView Provisional Navigation Fehler: \(error.localizedDescription)")
        }

        // WKScriptMessageHandler - Message von JavaScript empfangen
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("📨 Nachricht empfangen: \(message.name)")
            print("   Body: \(message.body)")
            
            switch message.name {
            case "audio":
                handleAudio(message.body)
            case "diktat":
                handleDiktat(message.body)
            case "notifications":
                handleNotifications(message.body)
            default:
                print("⚠️ Unbekannter Handler: \(message.name)")
                break
            }
        }

        private func handleAudio(_ body: Any) {
            print("🎵 Audio Handler aufgerufen")
            let cmd = parseCmd(body)
            switch cmd {
            case "start":
                print("   → Audio START")
                AudioBridge.shared.audio.start()
            case "stop":
                print("   → Audio STOP")
                AudioBridge.shared.audio.stop()
            default:
                print("   → Unbekannter Command: \(cmd ?? "nil")")
                break
            }
        }

        private func handleDiktat(_ body: Any) {
            print("🎤 Diktat Handler aufgerufen")
            let cmd = parseCmd(body)
            switch cmd {
            case "start":
                print("   → Diktat START")
                SpeechBridge.shared.stt.start(
                    locale: Locale(identifier: "de-DE"),
                    onStatus: { [weak self] active in
                        print("   📊 Diktat Status: \(active)")
                        self?.callJS("window.dStatus && window.dStatus(\(active ? "true" : "false"))")
                    },
                    onText: { [weak self] text in
                        print("   📝 Diktat Text: \(text)")
                        self?.callJS("window.dText && window.dText(\(text.jsQuoted))")
                    },
                    onError: { [weak self] msg in
                        print("   ❌ Diktat Fehler: \(msg)")
                        self?.callJS("window.dFehler && window.dFehler(\(msg.jsQuoted))")
                    }
                )
            case "stop":
                print("   → Diktat STOP")
                SpeechBridge.shared.stt.stop()
                callJS("window.dStatus && window.dStatus(false)")
            default:
                print("   → Unbekannter Command: \(cmd ?? "nil")")
                break
            }
        }

        private func handleNotifications(_ body: Any) {
            print("🔔 Notifications Handler aufgerufen")
            guard let dict = body as? [String: Any] else {
                print("   ❌ Body ist kein Dictionary")
                return
            }
            let cmd = dict["cmd"] as? String
            print("   → Command: \(cmd ?? "nil")")

            if cmd == "permission" {
                print("   → Benachrichtigungs-Berechtigung anfordern")
                NotificationPermission.request()
                return
            }

            guard cmd == "reschedule" else { return }
            guard let stateObj = dict["state"] as? [String: Any] else {
                print("   ❌ state nicht gefunden")
                return
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: stateObj, options: [])
                let decoder = JSONDecoder()
                let state = try decoder.decode(AppStateForNotifications.self, from: data)
                print("   ✅ State erfolgreich dekodiert")

                NotificationPermission.request { granted in
                    guard granted else {
                        print("   ❌ Benachrichtigungs-Berechtigung verweigert")
                        return
                    }
                    print("   ✅ Benachrichtigungen neu geplant")
                    NotificationScheduler.shared.rescheduleAll(from: state)
                }
            } catch {
                print("   ❌ Decode Fehler: \(error)")
                callJS("console.error('Notif decode error:', \(String(describing: error).jsQuoted))")
            }
        }

        private func parseCmd(_ body: Any) -> String? {
            if let s = body as? String { return s }
            if let dict = body as? [String: Any], let s = dict["cmd"] as? String { return s }
            return nil
        }

        private func callJS(_ js: String) {
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
}

@MainActor final class AudioBridge {
    static let shared = AudioBridge()
    let audio = AudioRecorder()
}

@MainActor final class SpeechBridge {
    static let shared = SpeechBridge()
    let stt = SpeechToTextManager()
}

private extension String {
    var jsQuoted: String {
        var s = self
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\"", with: "\\\"")
        s = s.replacingOccurrences(of: "\n", with: "\\n")
        s = s.replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(s)\""
    }
}
