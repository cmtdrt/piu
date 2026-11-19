import Foundation

/// UI language, stored in UserDefaults (French by default).
enum Language: String, CaseIterable, Identifiable {
    case fr, en

    static let storageKey = "language"

    static var current: Language {
        Language(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .fr
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        }
    }

    func t(_ fr: String, _ en: String) -> String {
        self == .en ? en : fr
    }
}

/// Shortcut for use outside views: `tr("Bonjour", "Hello")`.
func tr(_ fr: String, _ en: String) -> String {
    Language.current.t(fr, en)
}
