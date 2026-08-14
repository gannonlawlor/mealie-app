//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Gannon Lawlor on 2/23/26.
//

import UIKit
import UniformTypeIdentifiers
import os.log

private let log = OSLog(subsystem: "com.jackabee.mealie.ShareExtension", category: "Share")

/// What actually happened to the shared link. The toast reports this verbatim
/// — it never claims a recipe was saved unless the server confirmed it.
private enum ImportOutcome {
    /// The server created the recipe.
    case created(slug: String)
    /// Not sent (or not deliverable); the app will import it on next launch.
    case queued(message: String)
    /// The server refused it and retrying would fail the same way.
    case rejected(message: String)
    /// Sent, but no answer in time — it may still be processing server-side,
    /// so it is deliberately not queued (that would risk a double import).
    case unconfirmed(message: String)
}

class ShareViewController: UIViewController {

    // MARK: - Shared storage
    // These mirror MealieModel's AuthService/SharedImportQueue keys. The
    // extension does not link MealieModel, so they are repeated here — keep
    // both sides in sync.

    private let appGroupID = "group.com.jackabee.mealie"
    private let appModeKey = "mealie_app_mode"
    private let serverURLKey = "mealie_server_url"
    private let tokenKey = "mealie_access_token"
    private let emailKey = "mealie_email"
    private let passwordKey = "mealie_password"
    private let pendingURLsKey = "pendingImportURLs"
    private let legacyPendingURLKey = "pendingImportURL"
    private let completedSlugsKey = "completedImportSlugs"

    private lazy var sharedDefaults = UserDefaults(suiteName: appGroupID)

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Toast UI

    private let toastLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private let toastContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        v.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("ShareExtension: viewDidLoad", log: log, type: .info)
        view.backgroundColor = .clear
        setupToast()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("ShareExtension: viewDidAppear", log: log, type: .info)
        handleSharedContent()
    }

    private func setupToast() {
        view.addSubview(toastContainer)
        toastContainer.addSubview(iconView)
        toastContainer.addSubview(spinner)
        toastContainer.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            toastContainer.widthAnchor.constraint(equalToConstant: 240),
            toastContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),

            iconView.centerXAnchor.constraint(equalTo: toastContainer.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 34),

            spinner.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            toastLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 16),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -16),
            toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -20),
        ])
    }

    private func presentToastIfNeeded() {
        guard toastContainer.alpha < 1 else { return }
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.toastContainer.alpha = 1
            self.toastContainer.transform = .identity
        }
    }

    /// In-progress state: spinner plus a neutral message, no dismissal yet.
    private func showBusy(message: String) {
        iconView.image = nil
        spinner.startAnimating()
        toastLabel.text = message
        presentToastIfNeeded()
    }

    /// Terminal state: swap in the result and dismiss. Anything the user needs
    /// to read (a failure, a "will finish later") stays up longer.
    private func showResult(symbolName: String, message: String, duration: TimeInterval) {
        spinner.stopAnimating()
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: config)
        toastLabel.text = message
        presentToastIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.2) {
                self.toastContainer.alpha = 0
            } completion: { _ in
                self.completeRequest()
            }
        }
    }

    private func show(_ outcome: ImportOutcome) {
        switch outcome {
        case .created:
            showResult(symbolName: "checkmark.circle.fill", message: "Saved to Mealie", duration: 1.0)
        case .queued(let message):
            showResult(symbolName: "clock.fill", message: message, duration: 2.2)
        case .rejected(let message):
            showResult(symbolName: "xmark.circle.fill", message: message, duration: 2.5)
        case .unconfirmed(let message):
            showResult(symbolName: "questionmark.circle.fill", message: message, duration: 2.5)
        }
    }

    // MARK: - Extracting the shared URL

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            os_log("ShareExtension: no extensionContext or inputItems", log: log, type: .error)
            show(.rejected(message: "Nothing to save"))
            return
        }

        guard let attachments = extensionItem.attachments, !attachments.isEmpty else {
            os_log("ShareExtension: no attachments found", log: log, type: .error)
            show(.rejected(message: "Nothing to save"))
            return
        }

        os_log("ShareExtension: found %d attachment(s)", log: log, type: .info, attachments.count)

        for (index, attachment) in attachments.enumerated() {
            let typeIDs = attachment.registeredTypeIdentifiers
            os_log("ShareExtension: attachment[%d] types: %{public}@", log: log, type: .info, index, typeIDs.joined(separator: ", "))

            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                os_log("ShareExtension: loading URL type from attachment[%d]", log: log, type: .info, index)
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, error in
                    if let error = error {
                        os_log("ShareExtension: error loading URL item: %{public}@", log: log, type: .error, error.localizedDescription)
                    }
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            os_log("ShareExtension: got URL: %{public}@", log: log, type: .info, url.absoluteString)
                            self?.importShared(url: url)
                        } else if let url = item as? NSURL, let swiftURL = url as URL? {
                            os_log("ShareExtension: got NSURL, converted: %{public}@", log: log, type: .info, swiftURL.absoluteString)
                            self?.importShared(url: swiftURL)
                        } else {
                            os_log("ShareExtension: URL item was not a URL, type: %{public}@", log: log, type: .error, String(describing: type(of: item)))
                            self?.show(.rejected(message: "Invalid URL"))
                        }
                    }
                }
                return
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                os_log("ShareExtension: loading plainText type from attachment[%d]", log: log, type: .info, index)
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, error in
                    if let error = error {
                        os_log("ShareExtension: error loading plainText item: %{public}@", log: log, type: .error, error.localizedDescription)
                    }
                    DispatchQueue.main.async {
                        if let text = item as? String {
                            os_log("ShareExtension: got text: %{public}@", log: log, type: .info, text)
                            if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                                os_log("ShareExtension: parsed URL from text: %{public}@", log: log, type: .info, url.absoluteString)
                                self?.importShared(url: url)
                            } else {
                                os_log("ShareExtension: text is not a valid HTTP URL", log: log, type: .error)
                                self?.show(.rejected(message: "Not a valid URL"))
                            }
                        } else {
                            os_log("ShareExtension: plainText item was not a String, type: %{public}@", log: log, type: .error, String(describing: type(of: item)))
                            self?.show(.rejected(message: "Could not read content"))
                        }
                    }
                }
                return
            }
        }

        os_log("ShareExtension: no matching attachment type found", log: log, type: .error)
        show(.rejected(message: "No URL found"))
    }

    // MARK: - Importing

    /// Imports against the server when there is a session to use, and only
    /// falls back to the app's queue otherwise.
    private func importShared(url: URL) {
        guard let defaults = sharedDefaults else {
            os_log("ShareExtension: FAILED to open App Group UserDefaults with suite: %{public}@", log: log, type: .error, appGroupID)
            show(.rejected(message: "Couldn't save — reinstall Mealie"))
            return
        }

        let mode = defaults.string(forKey: appModeKey) ?? "server"
        let server = (defaults.string(forKey: serverURLKey) ?? "").trimmingCharacters(in: .whitespaces)
        let token = defaults.string(forKey: tokenKey) ?? ""

        guard mode == "server", !server.isEmpty, !token.isEmpty else {
            // Local mode keeps recipes in the app's own store, which the
            // extension cannot write to, so the app has to do this one.
            os_log("ShareExtension: no server session (mode=%{public}@) — queueing", log: log, type: .info, mode)
            enqueue(url.absoluteString)
            show(.queued(message: mode == "server"
                ? "Sign in to Mealie to finish saving"
                : "Saved — opening Mealie will finish the import"))
            return
        }

        showBusy(message: "Saving to Mealie…")

        Task { [weak self] in
            guard let self = self else { return }
            let outcome = await self.createRecipe(server: server, token: token, url: url.absoluteString)
            await MainActor.run {
                switch outcome {
                case .created(let slug):
                    self.appendCompleted(slug: slug)
                    os_log("ShareExtension: created recipe %{public}@", log: log, type: .info, slug)
                case .queued:
                    self.enqueue(url.absoluteString)
                default:
                    break
                }
                self.show(outcome)
            }
        }
    }

    /// POST /api/recipes/create/url, refreshing the session once on a 401.
    private func createRecipe(server: String, token: String, url: String) async -> ImportOutcome {
        let base = server.hasSuffix("/") ? String(server.dropLast()) : server
        guard let endpoint = URL(string: "\(base)/api/recipes/create/url") else {
            return .rejected(message: "Server address is invalid")
        }

        var currentToken = token
        var didRetry = false

        while true {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": url, "includeTags": true])

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    return .queued(message: "Couldn't reach Mealie — saved for later")
                }
                os_log("ShareExtension: create/url responded %d", log: log, type: .info, http.statusCode)

                switch http.statusCode {
                case 200...299:
                    return .created(slug: Self.parseSlug(from: data))

                case 401 where !didRetry:
                    didRetry = true
                    guard let refreshed = await reauthenticate(base: base) else {
                        return .queued(message: "Sign in to Mealie to finish saving")
                    }
                    currentToken = refreshed
                    continue

                case 401, 403:
                    return .queued(message: "Sign in to Mealie to finish saving")

                case 400...499:
                    let body = String(data: data, encoding: .utf8) ?? ""
                    os_log("ShareExtension: import rejected: %{public}@", log: log, type: .error, String(body.prefix(300)))
                    return .rejected(message: "Mealie couldn't import that page")

                default:
                    return .queued(message: "Mealie had an error — saved for later")
                }
            } catch let error as URLError where error.code == .timedOut {
                // It may well have been created; queueing could duplicate it.
                os_log("ShareExtension: create/url timed out", log: log, type: .error)
                return .unconfirmed(message: "Still importing — check Mealie in a moment")
            } catch {
                os_log("ShareExtension: create/url failed: %{public}@", log: log, type: .error, error.localizedDescription)
                return .queued(message: "Couldn't reach Mealie — saved for later")
            }
        }
    }

    /// Re-login with the saved credentials, storing the fresh token for the app too.
    private func reauthenticate(base: String) async -> String? {
        guard let defaults = sharedDefaults,
              let email = defaults.string(forKey: emailKey),
              let password = defaults.string(forKey: passwordKey),
              let endpoint = URL(string: "\(base)/api/auth/token") else {
            os_log("ShareExtension: no saved credentials to re-authenticate with", log: log, type: .info)
            return nil
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password
        request.httpBody = "username=\(encodedEmail)&password=\(encodedPassword)".data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                os_log("ShareExtension: re-authentication rejected", log: log, type: .error)
                return nil
            }
            // The token endpoint is the one snake_case response in the API.
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String, !token.isEmpty else {
                os_log("ShareExtension: re-authentication response had no access_token", log: log, type: .error)
                return nil
            }
            defaults.set(token, forKey: tokenKey)
            os_log("ShareExtension: re-authenticated", log: log, type: .info)
            return token
        } catch {
            os_log("ShareExtension: re-authentication failed: %{public}@", log: log, type: .error, error.localizedDescription)
            return nil
        }
    }

    /// The create endpoints answer with a bare JSON string (the new slug).
    private static func parseSlug(from data: Data) -> String {
        if let slug = try? JSONDecoder().decode(String.self, from: data) {
            return slug
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r "))
    }

    // MARK: - App hand-off

    private func enqueue(_ urlString: String) {
        guard let defaults = sharedDefaults, !urlString.isEmpty else { return }
        var urls = defaults.stringArray(forKey: pendingURLsKey) ?? []
        if let legacy = defaults.string(forKey: legacyPendingURLKey), !legacy.isEmpty {
            urls.append(legacy)
            defaults.removeObject(forKey: legacyPendingURLKey)
        }
        guard !urls.contains(urlString) else { return }
        urls.append(urlString)
        defaults.set(urls, forKey: pendingURLsKey)
        os_log("ShareExtension: queued %{public}@ (%d pending)", log: log, type: .info, urlString, urls.count)
    }

    private func appendCompleted(slug: String) {
        guard let defaults = sharedDefaults, !slug.isEmpty else { return }
        var slugs = defaults.stringArray(forKey: completedSlugsKey) ?? []
        guard !slugs.contains(slug) else { return }
        slugs.append(slug)
        defaults.set(slugs, forKey: completedSlugsKey)
    }

    private func completeRequest() {
        os_log("ShareExtension: completing request", log: log, type: .info)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
