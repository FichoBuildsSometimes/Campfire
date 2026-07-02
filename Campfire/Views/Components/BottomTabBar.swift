import SwiftUI

enum CampfireTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case profile = "Profile"
    case settings = "Settings"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .home:
            "house.fill"
        case .profile:
            "person.fill"
        case .settings:
            "gearshape.fill"
        }
    }
}

struct BottomTabBar: View {
    @Binding var selectedTab: CampfireTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CampfireTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 18, weight: .semibold))

                        Text(tab.rawValue)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? AppTheme.Palette.emberGold : AppTheme.Palette.creamMuted)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.Palette.navyInk.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.34), radius: 24, x: 0, y: 12)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Bottom Tab Bar") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        VStack {
            Spacer()
            BottomTabBar(selectedTab: .constant(.home))
                .padding()
        }
    }
}
