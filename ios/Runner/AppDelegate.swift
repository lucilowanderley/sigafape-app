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

/// Canal "sigafape/nativo" (o mesmo do Android): preferências, token no Keychain e nome do aparelho.
class NativoSigafape: NSObject, FlutterPlugin {
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
}
