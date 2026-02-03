import Foundation

enum SessionMood: String, CaseIterable, Codable, Identifiable {
    case calm
    case good
    case stressed
    case tired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: return "平静"
        case .good: return "满足"
        case .stressed: return "焦虑"
        case .tired: return "疲惫"
        }
    }

    /// SF Symbols name (no emoji icons).
    var symbolName: String {
        switch self {
        case .calm: return "wind"
        case .good: return "sparkles"
        case .stressed: return "bolt.fill"
        case .tired: return "moon.zzz.fill"
        }
    }
}

