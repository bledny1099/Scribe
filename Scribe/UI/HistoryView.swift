import SwiftUI

/// History view showing all past transcriptions in liquid glass style.
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @State private var searchText = ""
    @State private var copiedId: UUID?
    
    var inSettings: Bool = false

    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return history.records
        }
        return history.records.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // Header
            if !inSettings {
            HStack {
                Text(appState.l("History"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                if !history.records.isEmpty {
                    Button(action: { history.clearAll() }) {
                        Text("Clear All")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { HistoryWindowManager.shared.closeWindow() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            }

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(appState.l("Search transcriptions…"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Content
            if filteredRecords.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.tertiary)

                    Text(appState.l(searchText.isEmpty ? "No transcriptions yet" : "No results found"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if searchText.isEmpty {
                        Text(appState.l("Record something with ⌥S to get started"))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRecords) { record in
                            HistoryRecordRow(
                                record: record,
                                isCopied: copiedId == record.id,
                                onCopy: { copyRecord(record) },
                                onDelete: { history.delete(id: record.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(maxWidth: inSettings ? .infinity : 440, maxHeight: inSettings ? .infinity : 560)
        .shadow(color: .black.opacity(0.3), radius: inSettings ? 0 : 20, x: 0, y: inSettings ? 0 : 10)
    }

    private func copyRecord(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        copiedId = record.id

        // Reset copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedId == record.id {
                copiedId = nil
            }
        }
    }
}

// MARK: - Record Row

struct HistoryRecordRow: View {
    @EnvironmentObject var appState: AppState
    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var formattedRelativeDate: String {
        let lang = appState.selectedUILanguage
        let code = (lang == "auto") ? (Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true ? "ru" : "en") : lang
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: code)
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Text content
            Text(record.text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metadata row
            HStack(spacing: 12) {
                // Date
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formattedRelativeDate)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                    Text(record.formattedDuration)
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(.tertiary)

                Spacer()

                // Actions
                if isHovered || isCopied {
                    HStack(spacing: 8) {
                        Button(action: onCopy) {
                            HStack(spacing: 4) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .medium))
                                Text(isCopied ? "Copied" : "Copy")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(isCopied ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(isHovered ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
