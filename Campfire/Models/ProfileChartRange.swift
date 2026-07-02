import Foundation

enum ProfileChartRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String {
        rawValue
    }

    var averageLabel: String {
        switch self {
        case .week, .month:
            return "Avg / day"
        case .year:
            return "Avg / month"
        }
    }

    var chartUnit: Calendar.Component {
        switch self {
        case .week, .month:
            return .day
        case .year:
            return .month
        }
    }
}
