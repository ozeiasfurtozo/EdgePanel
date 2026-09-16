import Foundation
import SwiftUI

struct TimeZoneSelection: View {
    @Binding var identifier: String
    @State private var showingChooser = false

    var body: some View {
        HStack(spacing: 12) {
            Text(L("Fuso horário", "Time zone"))
            Spacer(minLength: 8)
            Button { showingChooser = true } label: {
                HStack(spacing: 6) {
                    Text(identifier == "local" ? L("Fuso do Mac", "Mac time zone") : identifier.replacingOccurrences(of: "_", with: " "))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingChooser) {
            TimeZoneChooser(identifier: $identifier)
        }
    }
}

private struct TimeZoneChooser: View {
    @Binding var identifier: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private static let allIdentifiers = TimeZone.knownTimeZoneIdentifiers
        .filter { $0 != "UTC" }
        .sorted()
    private static let common: [(id: String, label: String)] = [
        ("UTC", "UTC"),
        ("Europe/Lisbon", "Lisboa / Lisbon"),
        ("Europe/London", "Londres / London"),
        ("America/New_York", "Nova Iorque / New York"),
        ("America/Sao_Paulo", "São Paulo"),
        ("America/Los_Angeles", "Los Angeles"),
        ("Asia/Tokyo", "Tóquio / Tokyo")
    ]

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matchingCommon: [(id: String, label: String)] {
        Self.common.filter { query.isEmpty || $0.id.localizedStandardContains(query) || $0.label.localizedStandardContains(query) }
    }

    private var matchingIdentifiers: [String] {
        guard !query.isEmpty else { return Self.allIdentifiers }
        return Self.allIdentifiers.filter { $0.localizedStandardContains(query) ||
            $0.replacingOccurrences(of: "_", with: " ").localizedStandardContains(query) }
    }

    private var showLocal: Bool {
        query.isEmpty || TimeZone.current.identifier.localizedStandardContains(query) ||
            L("Fuso do Mac", "Mac time zone").localizedStandardContains(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Escolher fuso horário", "Choose time zone"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(L("Fechar", "Close")) { dismiss() }
            }
            TextField(L("Buscar cidade ou região", "Search city or region"), text: $search)
                .textFieldStyle(.roundedBorder)

            List {
                if showLocal || !matchingCommon.isEmpty {
                    Section(L("Fusos frequentes", "Common time zones")) {
                        if showLocal {
                            row("local", name: L("Fuso do Mac", "Mac time zone"), detail: TimeZone.current.identifier)
                        }
                        ForEach(matchingCommon, id: \.id) { zone in
                            row(zone.id, name: zone.label, detail: zone.id)
                        }
                    }
                }
                if !matchingIdentifiers.isEmpty {
                    Section(L("Todos os fusos", "All time zones")) {
                        ForEach(matchingIdentifiers, id: \.self) { id in
                            row(id, name: id.replacingOccurrences(of: "_", with: " "))
                        }
                    }
                } else if !query.isEmpty && !showLocal && matchingCommon.isEmpty {
                    Text(L("Nenhum fuso encontrado", "No time zone found"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 540)
    }

    private func row(_ id: String, name: String, detail: String? = nil) -> some View {
        let zone = id == "local" ? TimeZone.current : TimeZone(identifier: id) ?? .current
        return Button {
            identifier = id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).lineLimit(1)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(Self.offsetText(for: zone))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if identifier == id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func offsetText(for zone: TimeZone) -> String {
        let seconds = zone.secondsFromGMT(for: .now)
        let absolute = abs(seconds)
        return String(format: "UTC%@%02d:%02d", seconds >= 0 ? "+" : "−", absolute / 3600, absolute % 3600 / 60)
    }
}
