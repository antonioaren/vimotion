import AppKit

/// `NSAlert`-based dialogs for the updater.
final class AlertUpdatePrompter: UpdatePrompting {

    private static let maxSummaryLength = 1200

    func promptForUpdate(_ decision: UpdateDecision, current: AppVersion) -> UpdatePromptChoice {
        guard let release = decision.release else { return .later }

        let alert = NSAlert()
        var info: String
        switch decision {
        case .switchToStable:
            alert.messageText = "Switch back to stable vimotion \(release.version)?"
            info = "You're running beta \(current). The latest stable release, \(release.version), is older than your build."
        case .update, .upToDate:
            alert.messageText = "vimotion \(release.version) is available"
            info = "You have \(current)."
        }

        let summary = Self.plainText(fromMarkdown: release.summary)
        if !summary.isEmpty {
            let clipped = summary.count > Self.maxSummaryLength
                ? String(summary.prefix(Self.maxSummaryLength)) + "…"
                : summary
            info += "\n\n" + clipped
        }
        info += "\n\nvimotion will quit and relaunch. macOS may ask you to grant Accessibility access again."
        alert.informativeText = info

        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")

        switch run(alert) {
        case .alertFirstButtonReturn: return .install
        case .alertThirdButtonReturn: return .skip
        default: return .later
        }
    }

    func confirmJoinBeta() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Join the Beta channel?"
        alert.informativeText = """
        Beta builds are published from the beta/v<version>-dev branches. They get new features first \
        but may be unstable. You can go back to Stable at any time from Updates ▸ Stable Channel.
        """
        alert.addButton(withTitle: "Join Beta")
        alert.addButton(withTitle: "Cancel")
        return run(alert) == .alertFirstButtonReturn
    }

    func showUpToDate(current: AppVersion, channel: UpdateChannel) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "vimotion \(current) is the latest version on the \(channel.displayName) channel."
        run(alert)
    }

    func showDevelopmentBuild() {
        let alert = NSAlert()
        alert.messageText = "Updates aren't available"
        alert.informativeText = "This is a development build without an app version. Install a release, or build one with ./scripts/build_app.sh, to receive updates."
        run(alert)
    }

    func showError(_ error: Error, releasePage: URL?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't update vimotion"
        alert.informativeText = error.localizedDescription
        if let releasePage {
            alert.addButton(withTitle: "Open Release Page")
            alert.addButton(withTitle: "OK")
            if run(alert) == .alertFirstButtonReturn {
                NSWorkspace.shared.open(releasePage)
            }
        } else {
            run(alert)
        }
    }

    // MARK: - Helpers

    /// vimotion is a menu-bar agent, so it must activate to bring the alert forward.
    @discardableResult
    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    /// Release notes are markdown; alerts show plain text.
    static func plainText(fromMarkdown markdown: String) -> String {
        markdown
            .components(separatedBy: .newlines)
            .map { line -> String in
                var line = line
                while line.hasPrefix("#") { line.removeFirst() }
                return line
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
