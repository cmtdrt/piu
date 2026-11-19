import AppKit
import SwiftUI

struct PopupView: View {
    enum Page: Equatable {
        case list
        case detail(id: String)
        case settings
    }

    @EnvironmentObject private var store: PortStore
    @AppStorage(Language.storageKey) private var language: Language = .fr
    @State private var page: Page = .list

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            switch page {
            case .list: ListPage(onSelect: { page = .detail(id: $0.id) })
            case .detail(let id): DetailPage(id: id, onDone: { page = .list })
            case .settings: SettingsPage(onClose: { page = .list })
            }
        }
        .padding(14)
        .frame(width: 320)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.refresh()
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 6) {
            switch page {
            case .list:
                title(language.t("Ports utilisés", "Ports in use"))
                Spacer()
                refreshButton
                iconButton("gearshape", help: language.t("Réglages", "Settings")) { page = .settings }
            case .detail(let id):
                Button { page = .list } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        title(store.ports.first(where: { $0.id == id }).map { "\($0.port) · \($0.name)" }
                              ?? language.t("Ports utilisés", "Ports in use"))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                refreshButton
            case .settings:
                title(language.t("Réglages", "Settings"))
                Spacer()
                iconButton("xmark", help: language.t("Fermer", "Close")) { page = .list }
            }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
    }

    private var refreshButton: some View {
        Button(action: store.refresh) {
            Group {
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13))
                }
            }
            .frame(width: 22, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(store.isRefreshing)
        .help(language.t("Rafraîchir", "Refresh"))
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

// MARK: - List

private struct ListPage: View {
    var onSelect: (ListeningPort) -> Void

    @EnvironmentObject private var store: PortStore
    @AppStorage(Language.storageKey) private var language: Language = .fr

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let ports = store.visiblePorts
            if ports.isEmpty {
                Text(language.t("Aucun port de dev en cours", "No dev ports in use"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
            } else {
                let rows = VStack(spacing: 2) {
                    ForEach(ports) { port in
                        PortRow(port: port, stopping: store.stopping.contains(port.pid),
                                onSelect: { onSelect(port) }, onStop: { store.stop(port) })
                    }
                }
                // Long lists scroll; short ones size the popup to their content.
                if ports.count > 8 {
                    ScrollView { rows }.frame(height: 300)
                } else {
                    rows
                }
            }

            Button(store.showAll
                   ? language.t("Ports de dev seulement", "Dev ports only")
                   : language.t("Afficher tout (\(store.ports.count))", "Show all (\(store.ports.count))")) {
                store.showAll.toggle()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }
}

private struct PortRow: View {
    let port: ListeningPort
    let stopping: Bool
    let onSelect: () -> Void
    let onStop: () -> Void

    @AppStorage(Language.storageKey) private var language: Language = .fr
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text(String(port.port))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .frame(width: 46, alignment: .leading)
            Text(port.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(port.isDev ? .primary : .secondary)
            Spacer(minLength: 6)
            StopButton(port: port, stopping: stopping, action: onStop)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering ? 0.06 : 0)))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}

/// Minimal red cross; disabled (grey) for processes PIU must not stop.
private struct StopButton: View {
    let port: ListeningPort
    let stopping: Bool
    let action: () -> Void

    @AppStorage(Language.storageKey) private var language: Language = .fr

    var body: some View {
        if stopping {
            ProgressView().controlSize(.mini).frame(width: 20, height: 18)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(port.killable ? AnyShapeStyle(Color.red) : AnyShapeStyle(.quaternary))
                    .frame(width: 20, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!port.killable)
            .help(port.killable
                  ? language.t("Arrêter le programme (PID \(port.pid))", "Stop the program (PID \(port.pid))")
                  : unavailableReason(port, language))
        }
    }
}

private func unavailableReason(_ port: ListeningPort, _ language: Language) -> String {
    port.name == "Docker"
        ? language.t("Arrête le conteneur depuis Docker", "Stop the container from Docker")
        : language.t("Processus système ou d'un autre utilisateur", "System process or another user's process")
}

// MARK: - Detail

private struct DetailPage: View {
    let id: String
    var onDone: () -> Void

    @EnvironmentObject private var store: PortStore
    @AppStorage(Language.storageKey) private var language: Language = .fr

    var body: some View {
        if let port = store.ports.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    field(language.t("Programme", "Program"), port.executable.abbreviatingHome)
                    commandField(port.command.abbreviatingHome)
                    if let directory = port.directory {
                        field(language.t("Dossier", "Folder"), directory.abbreviatingHome)
                    }
                    field("PID", String(port.pid))
                    if let uptime = port.uptime {
                        field(language.t("Depuis", "Running for"), duration(uptime))
                    }
                    field(language.t("Écoute", "Listens on"), port.exposed
                          ? language.t("Ce Mac et le réseau local", "This Mac and the local network")
                          : language.t("Ce Mac uniquement", "This Mac only"))
                }

                Divider()

                if port.killable {
                    Button {
                        store.stop(port)
                        onDone()
                    } label: {
                        Label(language.t("Arrêter le programme", "Stop the program"), systemImage: "xmark")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text(unavailableReason(port, language))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.t("Ce port n'est plus utilisé.", "This port is no longer in use."))
                    .foregroundStyle(.secondary)
                Button(language.t("Retour à la liste", "Back to the list"), action: onDone)
            }
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.tertiary)
            Text(value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Commands can be very long (Java classpaths…): wrap them in a box that scrolls past a few lines.
    private func commandField(_ command: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(language.t("Commande", "Command")).font(.caption).foregroundStyle(.tertiary)
            let text = Text(command)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            Group {
                if command.count > 240 {
                    ScrollView { text }.frame(height: 110)
                } else {
                    text
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let days = s / 86_400, hours = s % 86_400 / 3600, minutes = s % 3600 / 60
        if days > 0 { return language.t("\(days) j \(hours) h", "\(days)d \(hours)h") }
        if hours > 0 { return language.t("\(hours) h \(minutes) min", "\(hours)h \(minutes)m") }
        if minutes > 0 { return "\(minutes) min" }
        return language.t("quelques secondes", "a few seconds")
    }
}

// MARK: - Settings

private struct SettingsPage: View {
    var onClose: () -> Void

    @EnvironmentObject private var store: PortStore
    @AppStorage(Language.storageKey) private var language: Language = .fr

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(language.t("Rafraîchissement", "Refresh")) {
                HStack(spacing: 6) {
                    Text(language.t("Toutes les", "Every"))
                    TextField("", value: $store.intervalSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 42)
                    Stepper("", value: $store.intervalSeconds, in: PortStore.intervalRange)
                        .labelsHidden()
                    Text(language.t("secondes", "seconds"))
                }
                .disabled(store.autoRefreshDisabled)
                .opacity(store.autoRefreshDisabled ? 0.45 : 1)

                Toggle(language.t("Désactiver le suivi automatique", "Turn off automatic refresh"),
                       isOn: $store.autoRefreshDisabled)
                    .toggleStyle(.checkbox)
            }

            section(language.t("Langue", "Language")) {
                Picker("", selection: $language) {
                    ForEach(Language.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Divider()

            HStack {
                Button(language.t("Quitter PIU", "Quit PIU")) { NSApp.terminate(nil) }
                Spacer()
                Button("OK", action: onClose).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold))
            content()
        }
    }
}

private extension String {
    var abbreviatingHome: String { replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}
