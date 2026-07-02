import SwiftUI

struct ProfileRangeSelector: View {
    @Binding var selectedRange: ProfileChartRange

    var body: some View {
        Picker("Chart range", selection: $selectedRange) {
            ForEach(ProfileChartRange.allCases) { range in
                Text(range.rawValue)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(AppTheme.Palette.ember)
    }
}

#Preview("Profile Range Selector") {
    ZStack {
        AppTheme.Palette.navyInk.ignoresSafeArea()
        ProfileRangeSelector(selectedRange: .constant(.week))
            .padding()
    }
}
