import SwiftUI

struct DailyGoalSelectionView: View {
    static let presetGoals = [5_000, 7_500, 10_000]
    private static let goalStep = 500

    @Binding var dailyStepGoal: Int
    @Binding var isUsingCustomGoal: Bool

    var body: some View {
        VStack(spacing: 10) {
            goalButton(goal: 5_000, label: "Easy")
            goalButton(goal: 7_500, label: "Balanced")
            goalButton(goal: 10_000, label: "Challenge")
            customGoalRow
        }
    }

    private func goalButton(goal: Int, label: String) -> some View {
        Button {
            isUsingCustomGoal = false
            dailyStepGoal = goal
        } label: {
            GoalOptionRow(
                title: formatted(goal),
                subtitle: label,
                isSelected: !isUsingCustomGoal && dailyStepGoal == goal,
                trailing: "\(goal / 100) steps per stick"
            )
        }
        .buttonStyle(.plain)
    }

    private var customGoalRow: some View {
        VStack(spacing: 10) {
            Button {
                isUsingCustomGoal = true
                dailyStepGoal = CampfirePreferences.clampedDailyStepGoal(dailyStepGoal)
            } label: {
                GoalOptionRow(
                    title: "Custom goal",
                    subtitle: "1,000 to 50,000 steps",
                    isSelected: isUsingCustomGoal,
                    trailing: isUsingCustomGoal ? "\(dailyStepGoal / 100) steps per stick" : nil
                )
            }
            .buttonStyle(.plain)

            if isUsingCustomGoal {
                customGoalStepper
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var customGoalStepper: some View {
        HStack(spacing: 12) {
            goalAdjustButton(systemImage: "minus", delta: -Self.goalStep)

            VStack(spacing: 2) {
                Text(formatted(dailyStepGoal))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(AppTheme.Palette.cream)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Adjust by 500 steps")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
            }
            .frame(maxWidth: .infinity)

            goalAdjustButton(systemImage: "plus", delta: Self.goalStep)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.Palette.navyInk.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.Palette.emberGold.opacity(0.34), lineWidth: 1)
        )
    }

    private func goalAdjustButton(systemImage: String, delta: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                dailyStepGoal = CampfirePreferences.clampedDailyStepGoal(dailyStepGoal + delta)
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(AppTheme.Palette.navyInk)
                .frame(width: 38, height: 38)
                .background(AppTheme.Palette.emberGold, in: Circle())
                .opacity(isGoalAdjustmentDisabled(delta) ? 0.44 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isGoalAdjustmentDisabled(delta))
        .accessibilityLabel(delta < 0 ? "Decrease custom goal" : "Increase custom goal")
    }

    private func isGoalAdjustmentDisabled(_ delta: Int) -> Bool {
        let adjustedGoal = dailyStepGoal + delta
        return adjustedGoal < CampfirePreferences.minimumDailyStepGoal || adjustedGoal > CampfirePreferences.maximumDailyStepGoal
    }

    private func formatted(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic)) + " steps"
    }
}

private struct GoalOptionRow: View {
    var title: String
    var subtitle: String
    var isSelected: Bool
    var trailing: String?

    var body: some View {
        HStack(spacing: 12) {
            SelectionIndicator(isSelected: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.cream)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.creamMuted)
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.emberGold)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .selectionRowStyle(isSelected: isSelected)
    }
}

private struct SelectionIndicator: View {
    var isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? AppTheme.Palette.emberGold : AppTheme.Palette.creamMuted.opacity(0.42), lineWidth: 2)

            if isSelected {
                Circle()
                    .fill(AppTheme.Palette.emberGold)
                    .padding(4)
            }
        }
        .frame(width: 22, height: 22)
    }
}

private extension View {
    func selectionRowStyle(isSelected: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.Palette.ember.opacity(0.20) : AppTheme.Palette.glassFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? AppTheme.Palette.emberGold.opacity(0.72) : AppTheme.Palette.glassStroke, lineWidth: 1)
        )
    }
}

#Preview("Daily Goal Selection") {
    ZStack {
        AppTheme.Palette.navyInk.ignoresSafeArea()
        DailyGoalSelectionView(
            dailyStepGoal: .constant(7_500),
            isUsingCustomGoal: .constant(false)
        )
        .padding()
    }
}
