import SwiftUI

struct OnboardingPageView: View {
    var systemImage: String
    var title: String
    var message: String
    var accent: Color = AppTheme.Palette.emberGold

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 68, height: 68)
                .background(accent.opacity(0.16), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Onboarding Page") {
    ZStack {
        AppTheme.Palette.navyInk.ignoresSafeArea()
        OnboardingPageView(
            systemImage: "flame.fill",
            title: "Keep your fire warm",
            message: "Your daily walk feeds a cozy campfire that grows with every step."
        )
        .padding()
    }
}
