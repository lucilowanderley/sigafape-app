import CoreLocation
import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativoSigafape") {
      NativoSigafape.register(with: registrar)
    }
  }
}

/// Canal "sigafape/nativo" (o mesmo do Android): preferências, token no Keychain, nome do aparelho,
/// abrir anexo e localização (GPS).
class NativoSigafape: NSObject, FlutterPlugin, CLLocationManagerDelegate, UIDocumentInteractionControllerDelegate {
  // Mantidos vivos enquanto a localização é buscada ou o anexo está aberto
  private var gerenteLocal: CLLocationManager?
  private var pedidoLocal: FlutterResult?
  private var melhorLocal: CLLocation?
  private var limiteLocal: Timer?
  private var documento: UIDocumentInteractionController?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "sigafape/nativo", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NativoSigafape(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let chave = args["chave"] as? String ?? ""
    let valor = args["valor"] as? String
    switch call.method {
    case "ler":
      result(UserDefaults.standard.string(forKey: "p_" + chave))
    case "gravar":
      if let v = valor { UserDefaults.standard.set(v, forKey: "p_" + chave) } else { UserDefaults.standard.removeObject(forKey: "p_" + chave) }
      result(nil)
    case "lerSegredo":
      result(lerKeychain(chave))
    case "gravarSegredo":
      gravarKeychain(chave, valor)
      result(nil)
    case "aparelho":
      result("\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)")
    case "abrirArquivo":
      guard let nome = args["nome"] as? String, let bytes = args["bytes"] as? FlutterStandardTypedData else {
        result(false)
        return
      }
      result(abrirArquivo(nome, bytes.data))
    case "localizacao":
      localizacao(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func consulta(_ chave: String) -> [String: Any] {
    return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "sigafape", kSecAttrAccount as String: chave]
  }

  private func lerKeychain(_ chave: String) -> String? {
    var q = consulta(chave)
    q[kSecReturnData as String] = true
    var item: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func gravarKeychain(_ chave: String, _ valor: String?) {
    SecItemDelete(consulta(chave) as CFDictionary)
    guard let v = valor else { return }
    var q = consulta(chave)
    q[kSecValueData as String] = v.data(using: .utf8)
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(q as CFDictionary, nil)
  }

  // ---------- Abrir anexo ----------

  private func telaAtual() -> UIViewController? {
    let janelas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
    var tela = (janelas.first { $0.isKeyWindow } ?? janelas.first)?.rootViewController
    while let por = tela?.presentedViewController { tela = por }
    return tela
  }

  /// Grava o arquivo na pasta temporária e mostra a prévia do iOS (com o botão de compartilhar / abrir em outro app).
  private func abrirArquivo(_ nome: String, _ dados: Data) -> Bool {
    let limpo = nome.components(separatedBy: CharacterSet(charactersIn: "\\/:*?\"<>|")).joined(separator: "_")
    let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("anexos", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
      let arquivo = pasta.appendingPathComponent(limpo.isEmpty ? "anexo" : limpo)
      try dados.write(to: arquivo, options: .atomic)
      let doc = UIDocumentInteractionController(url: arquivo)
      doc.name = nome
      doc.delegate = self
      documento = doc
      if doc.presentPreview(animated: true) { return true }
      // Tipo sem prévia: oferece os apps que abrem o arquivo
      guard let tela = telaAtual() else { return false }
      return doc.presentOpenInMenu(from: tela.view.bounds, in: tela.view, animated: true)
    } catch {
      return false
    }
  }

  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return telaAtual() ?? UIViewController()
  }

  func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
    documento = nil
  }

  // ---------- Localização ----------

  /// Pede a permissão (se preciso) e devolve {latitude, longitude, precisao} ou um erro: sem_permissao, gps_desligado, sem_sinal.
  private func localizacao(_ result: @escaping FlutterResult) {
    guard CLLocationManager.locationServicesEnabled() else {
      result(FlutterError(code: "gps_desligado", message: "Localização do celular desligada.", details: nil))
      return
    }
    responderLocal(FlutterError(code: "cancelado", message: "Outro pedido de localização começou.", details: nil))
    pedidoLocal = result
    melhorLocal = nil
    let lm = CLLocationManager()
    lm.delegate = self
    lm.desiredAccuracy = kCLLocationAccuracyBest
    gerenteLocal = lm
    switch lm.authorizationStatus {
    case .notDetermined:
      lm.requestWhenInUseAuthorization() // a resposta chega em locationManagerDidChangeAuthorization
    case .authorizedAlways, .authorizedWhenInUse:
      comecarBusca(lm)
    default:
      responderLocal(FlutterError(code: "sem_permissao", message: "Permissão de localização negada.", details: nil))
    }
  }

  private func comecarBusca(_ lm: CLLocationManager) {
    guard limiteLocal == nil else { return }
    // Posição recente (até 2 min) já serve de ponto de partida
    if let l = lm.location, -l.timestamp.timeIntervalSinceNow < 120, l.horizontalAccuracy >= 0 { melhorLocal = l }
    lm.startUpdatingLocation()
    limiteLocal = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.responderLocal(nil) }
  }

  /// Responde ao Dart uma única vez: com o erro dado ou com a melhor posição obtida.
  private func responderLocal(_ erro: FlutterError?) {
    guard let r = pedidoLocal else { return }
    pedidoLocal = nil
    limiteLocal?.invalidate()
    limiteLocal = nil
    gerenteLocal?.stopUpdatingLocation()
    gerenteLocal?.delegate = nil
    gerenteLocal = nil
    if let e = erro {
      r(e)
    } else if let l = melhorLocal {
      r(["latitude": l.coordinate.latitude, "longitude": l.coordinate.longitude, "precisao": l.horizontalAccuracy])
    } else {
      r(FlutterError(code: "sem_sinal", message: "Não foi possível obter a localização.", details: nil))
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager === gerenteLocal, pedidoLocal != nil else { return }
    switch manager.authorizationStatus {
    case .notDetermined:
      return
    case .authorizedAlways, .authorizedWhenInUse:
      comecarBusca(manager)
    default:
      responderLocal(FlutterError(code: "sem_permissao", message: "Permissão de localização negada.", details: nil))
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for l in locations where l.horizontalAccuracy >= 0 {
      if melhorLocal == nil || l.horizontalAccuracy < melhorLocal!.horizontalAccuracy { melhorLocal = l }
    }
    // Precisão boa (até 30 m): responde já; senão espera melhorar até o limite de tempo
    if let m = melhorLocal, m.horizontalAccuracy <= 30 { responderLocal(nil) }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if (error as? CLError)?.code == .denied {
      responderLocal(FlutterError(code: "sem_permissao", message: "Permissão de localização negada.", details: nil))
    }
    // Outras falhas (sem sinal momentâneo): continua tentando até o limite de tempo
  }
}
