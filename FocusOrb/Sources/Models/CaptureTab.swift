import Foundation

enum CaptureTab: String, CaseIterable, Identifiable {
    case notes
    case tasks
    case clips

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes:
            return L10n.string("Notes")
        case .tasks:
            return L10n.string("Tasks")
        case .clips:
            return L10n.string("Clips")
        }
    }
}
