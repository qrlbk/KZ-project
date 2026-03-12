import SwiftUI

/// Общие UI-компоненты и стили для нативного macOS-вида.

struct PanelHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var actions: () -> Actions

    init(title: String, subtitle: String? = nil, @ViewBuilder actions: @escaping () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                actions()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct PrimaryToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundStyle(Color(nsColor: .controlTextColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0 : 0.06), radius: 3, x: 0, y: 1)
    }
}

struct SectionHeaderText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

