import SwiftUI

struct EditorPalette {
    let dark: Bool

    var background: Color {
        dark ? Color(red: 0.045, green: 0.070, blue: 0.112) :
            Color(red: 0.945, green: 0.965, blue: 0.982)
    }

    var sidebar: LinearGradient {
        LinearGradient(colors: dark ?
            [Color(red: 0.060, green: 0.100, blue: 0.155), Color(red: 0.045, green: 0.072, blue: 0.116)] :
            [Color(red: 0.922, green: 0.951, blue: 0.976), Color(red: 0.954, green: 0.971, blue: 0.985)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var surface: Color {
        dark ? Color(red: 0.090, green: 0.140, blue: 0.205) : .white
    }

    var stroke: Color {
        dark ? Color.white.opacity(0.085) : Color(red: 0.18, green: 0.31, blue: 0.42).opacity(0.13)
    }

    var accent: Color {
        dark ? Color(red: 0.39, green: 0.83, blue: 0.94) :
            Color(red: 0.04, green: 0.42, blue: 0.58)
    }

    var muted: Color {
        dark ? Color(red: 0.59, green: 0.67, blue: 0.77) :
            Color(red: 0.38, green: 0.45, blue: 0.54)
    }
}

struct EditorGroupBoxStyle: GroupBoxStyle {
    let palette: EditorPalette

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            configuration.label
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1.3)
                .foregroundStyle(palette.accent)
            configuration.content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.stroke, lineWidth: 1))
    }
}
