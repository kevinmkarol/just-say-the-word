// ABOUTME: The History section: every recent transcript, searchable, each with a button to copy it again, and above
// ABOUTME: them any recordings whose transcription failed, each with a button to retry.
import JustSayTheWordCore
import SwiftUI

struct HistoryView: View {
    let model: AppModel
    @State private var search = ""

    private var transcripts: [Transcript] {
        guard !search.isEmpty else { return model.transcripts }
        return model.transcripts.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if !model.failedRecordings.isEmpty {
                Section("Recordings that could not be transcribed") {
                    ForEach(model.failedRecordings, id: \.self) { clip in
                        HStack {
                            Label(clip.deletingPathExtension().lastPathComponent, systemImage: "waveform")
                            Spacer()
                            Button("Retry") { model.retry(clip) }
                        }
                    }
                }
            }
            Section {
                ForEach(Array(transcripts.enumerated()), id: \.offset) { _, transcript in
                    TranscriptRow(transcript: transcript)
                }
            }
        }
        .overlay {
            if transcripts.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "No transcripts yet" : "No transcripts match",
                    systemImage: "text.bubble",
                    description: Text(search.isEmpty ? "What you dictate is kept here." : "Try a different search.")
                )
            }
        }
        .searchable(text: $search, prompt: "Search transcripts")
        .navigationTitle("History")
    }
}

private struct TranscriptRow: View {
    let transcript: Transcript
    @State private var wasCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transcript.text)
                    .textSelection(.enabled)
                Text("\(transcript.time) · \(transcript.seconds, format: .number.precision(.fractionLength(1))) s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Paster.copy(transcript.text)
                wasCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { wasCopied = false }
            } label: {
                Image(systemName: wasCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy this transcript")
        }
        .padding(.vertical, 4)
    }
}
