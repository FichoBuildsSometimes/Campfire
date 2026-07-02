import Foundation

enum CampfireStage: Int, CaseIterable, Identifiable {
    case stage1 = 1
    case stage2
    case stage3
    case stage4
    case stage5

    var id: Int { rawValue }

    var assetName: String {
        "campfire_stage_\(rawValue)"
    }

    init(fireCharge: Int) {
        let clampedCharge = min(max(fireCharge, 0), 100)

        switch clampedCharge {
        case 0...19:
            self = .stage1
        case 20...39:
            self = .stage2
        case 40...59:
            self = .stage3
        case 60...79:
            self = .stage4
        default:
            self = .stage5
        }
    }
}
