import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case english

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.preferredLanguages.first ?? Locale.current.identifier
        case .zhHans:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    var lprojName: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    var displayNameKey: String {
        switch self {
        case .system:
            return "Follow System"
        case .zhHans:
            return "Simplified Chinese"
        case .english:
            return "English"
        }
    }
}

enum L10n {
    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = string(key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: AppSettings.shared.appLanguage.locale, arguments: args)
    }

    private static var baseBundle: Bundle {
        // SwiftPM resources (including Localizable.strings) live in the module bundle.
        // Using Bundle.main breaks localization when running via `swift run` or Xcode SwiftPM.
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle.main
#endif
    }

    private static var bundle: Bundle {
        let language = AppSettings.shared.appLanguage
        guard let lprojName = language.lprojName else {
            return baseBundle
        }

        if let forced = localizedBundle(in: baseBundle, lprojName: lprojName) {
            return forced
        }

        // Fallback: in some packaging setups resources may end up in the main bundle.
        if baseBundle !== Bundle.main, let forced = localizedBundle(in: Bundle.main, lprojName: lprojName) {
            return forced
        }

        return baseBundle
    }

    private static func localizedBundle(in bundle: Bundle, lprojName: String) -> Bundle? {
        // Fast path for common cases.
        for candidate in [lprojName, lprojName.lowercased()] {
            if let path = bundle.path(forResource: candidate, ofType: "lproj"),
               let forced = Bundle(path: path) {
                return forced
            }
        }

        // Slow path: case-insensitive scan (SwiftPM may emit `zh-hans.lproj`).
        let target = (lprojName + ".lproj").lowercased()
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: bundle.bundleURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        guard let match = urls.first(where: { $0.lastPathComponent.lowercased() == target }) else {
            return nil
        }
        return Bundle(url: match)
    }
}
