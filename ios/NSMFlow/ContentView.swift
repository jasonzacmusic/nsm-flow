import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var session: FlowSession
    @State private var signoff = Shared.emailSignoff
    @State private var history = Shared.history

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statusCard
                } footer: {
                    Text(footerText)
                }

                if let problem = session.problem {
                    Section { Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }

                Section("Set up the keyboard") {
                    step(1, "Open Settings › General › Keyboard › Keyboards › Add New Keyboard and pick NSM Flow.")
                    step(2, "Tap NSM Flow in that list and turn on Allow Full Access, so the keyboard can talk to this app.")
                    step(3, "In any app, hold the globe key and choose NSM Flow.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section {
                    TextEditor(text: $signoff)
                        .frame(minHeight: 110)
                        .font(.body)
                        .onChange(of: signoff) { _, value in Shared.emailSignoff = value }
                } header: {
                    Text("Email sign-off")
                } footer: {
                    Text("Added after every email you dictate with the keyboard set to Email.")
                }

                if !history.isEmpty {
                    Section("Everything you dictated") {
                        ForEach(history.prefix(50), id: \.self) { item in
                            Text(item).font(.callout).textSelection(.enabled)
                                .contextMenu {
                                    Button("Copy") { UIPasteboard.general.string = item }
                                }
                        }
                    }
                }
            }
            .navigationTitle("NSM Flow")
            .onReceive(session.$lastText) { _ in history = Shared.history }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(statusColour).frame(width: 12, height: 12)
                Text(statusTitle).font(.headline)
            }
            if session.phase == .off {
                Button {
                    Task { await session.openSession() }
                } label: {
                    Label("Start Flow session", systemImage: "mic.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if session.phase == .recording {
                Button {
                    session.stopRecording()
                } label: {
                    Label("Stop and transcribe", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.red)
            } else {
                HStack {
                    Button {
                        session.startRecording()
                    } label: {
                        Label("Dictate here", systemImage: "mic").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button("End session", role: .destructive) { session.closeSession() }
                        .buttonStyle(.bordered)
                }
            }
            if !session.lastText.isEmpty {
                Text(session.lastText).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusTitle: String {
        switch session.phase {
        case .off: return "Flow session is off"
        case .ready: return "Ready — use the keyboard's mic key"
        case .recording: return "Listening…"
        case .processing: return "Writing it up…"
        }
    }

    private var statusColour: Color {
        switch session.phase {
        case .off: return .gray
        case .ready: return .green
        case .recording: return .red
        case .processing: return .orange
        }
    }

    private var footerText: String {
        session.phase == .recording
            ? "Go back to your app with ◀ at the top-left. Tap the mic key on the keyboard to finish."
            : "A session keeps the microphone ready for five minutes so the keyboard can start dictation instantly."
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)").font(.headline).frame(width: 22)
            Text(text).font(.callout)
        }
    }
}
