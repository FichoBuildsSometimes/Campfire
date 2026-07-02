import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.Radius.card
    var contentPadding: CGFloat = AppTheme.Spacing.large
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.Palette.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Palette.glassStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.Palette.shadow, radius: 22, x: 0, y: 14)
    }
}

#Preview("Glass Card") {
    ZStack {
        AppTheme.Palette.forestDeep.ignoresSafeArea()
        GlassCard {
            Text("Campfire")
                .foregroundStyle(AppTheme.Palette.cream)
        }
        .padding()
    }
}
