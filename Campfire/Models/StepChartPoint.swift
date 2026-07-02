import Foundation

struct StepChartPoint: Identifiable, Equatable {
    let id: UUID
    let label: String
    let steps: Int
    let date: Date

    init(id: UUID = UUID(), label: String, steps: Int, date: Date) {
        self.id = id
        self.label = label
        self.steps = max(steps, 0)
        self.date = date
    }
}
