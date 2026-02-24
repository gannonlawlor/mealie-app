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

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("ShareExtension: viewDidLoad", log: log, type: .info)
        // Make the view transparent so the share sheet doesn't show a blank screen
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("ShareExtension: viewDidAppear", log: log, type: .info)
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            os_log("ShareExtension: no extensionContext or inputItems", log: log, type: .error)
            completeRequest()
            return
        }

        guard let attachments = extensionItem.attachments, !attachments.isEmpty else {
            os_log("ShareExtension: no attachments found", log: log, type: .error)
            completeRequest()
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
                            self?.completeRequest()
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
                                self?.completeRequest()
                            }
                        } else {
                            os_log("ShareExtension: plainText item was not a String, type: %{public}@", log: log, type: .error, String(describing: type(of: item)))
                            self?.completeRequest()
                        }
                    }
                }
                return
            }
        }

        os_log("ShareExtension: no matching attachment type found", log: log, type: .error)
        completeRequest()
    }

    private func saveAndDismiss(url: URL) {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(url.absoluteString, forKey: pendingURLKey)
            defaults.synchronize()
            // Verify the write
            let saved = defaults.string(forKey: pendingURLKey)
            os_log("ShareExtension: saved URL to App Group defaults. Verified: %{public}@", log: log, type: .info, saved ?? "nil")
        } else {
            os_log("ShareExtension: FAILED to open App Group UserDefaults with suite: %{public}@", log: log, type: .error, appGroupID)
        }
        completeRequest()
    }

    private func completeRequest() {
        os_log("ShareExtension: completing request", log: log, type: .info)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
