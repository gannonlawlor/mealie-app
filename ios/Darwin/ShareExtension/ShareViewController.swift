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

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.jackabee.mealie"
    private let pendingURLKey = "pendingImportURL"

    private let toastLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let iv = UIImageView()
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        toastContainer.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            toastContainer.widthAnchor.constraint(equalToConstant: 180),
            toastContainer.heightAnchor.constraint(equalToConstant: 180),

            iconView.centerXAnchor.constraint(equalTo: toastContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor, constant: -16),

            toastLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 12),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -12),
        ])
    }

    private func showToast(success: Bool, message: String) {
        let symbolName = success ? "checkmark.circle.fill" : "xmark.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: config)
        toastLabel.text = message

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.toastContainer.alpha = 1
            self.toastContainer.transform = .identity
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UIView.animate(withDuration: 0.2) {
                    self.toastContainer.alpha = 0
                } completion: { _ in
                    self.completeRequest()
                }
            }
        }
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            os_log("ShareExtension: no extensionContext or inputItems", log: log, type: .error)
            showToast(success: false, message: "Nothing to save")
            return
        }

        guard let attachments = extensionItem.attachments, !attachments.isEmpty else {
            os_log("ShareExtension: no attachments found", log: log, type: .error)
            showToast(success: false, message: "Nothing to save")
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
                            self?.saveAndDismiss(url: url)
                        } else if let url = item as? NSURL, let swiftURL = url as URL? {
                            os_log("ShareExtension: got NSURL, converted: %{public}@", log: log, type: .info, swiftURL.absoluteString)
                            self?.saveAndDismiss(url: swiftURL)
                        } else {
                            os_log("ShareExtension: URL item was not a URL, type: %{public}@", log: log, type: .error, String(describing: type(of: item)))
                            self?.showToast(success: false, message: "Invalid URL")
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
                                self?.saveAndDismiss(url: url)
                            } else {
                                os_log("ShareExtension: text is not a valid HTTP URL", log: log, type: .error)
                                self?.showToast(success: false, message: "Not a valid URL")
                            }
                        } else {
                            os_log("ShareExtension: plainText item was not a String, type: %{public}@", log: log, type: .error, String(describing: type(of: item)))
                            self?.showToast(success: false, message: "Could not read content")
                        }
                    }
                }
                return
            }
        }

        os_log("ShareExtension: no matching attachment type found", log: log, type: .error)
        showToast(success: false, message: "No URL found")
    }

    private func saveAndDismiss(url: URL) {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(url.absoluteString, forKey: pendingURLKey)
            defaults.synchronize()
            let saved = defaults.string(forKey: pendingURLKey)
            os_log("ShareExtension: saved URL to App Group defaults. Verified: %{public}@", log: log, type: .info, saved ?? "nil")
            showToast(success: true, message: "Saved to Cookbook")
        } else {
            os_log("ShareExtension: FAILED to open App Group UserDefaults with suite: %{public}@", log: log, type: .error, appGroupID)
            showToast(success: false, message: "Failed to save")
        }
    }

    private func completeRequest() {
        os_log("ShareExtension: completing request", log: log, type: .info)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
