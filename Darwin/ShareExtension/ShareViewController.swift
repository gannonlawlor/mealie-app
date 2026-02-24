//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Gannon Lawlor on 2/23/26.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.jackabee.mealie"
    private let pendingURLKey = "pendingImportURL"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeRequest()
            return
        }

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.saveAndDismiss(url: url)
                        } else {
                            self?.completeRequest()
                        }
                    }
                }
                return
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let text = item as? String, let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                            self?.saveAndDismiss(url: url)
                        } else {
                            self?.completeRequest()
                        }
                    }
                }
                return
            }
        }

        completeRequest()
    }

    private func saveAndDismiss(url: URL) {
        // Save URL to shared App Group UserDefaults for the main app to pick up
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(url.absoluteString, forKey: pendingURLKey)
            defaults.synchronize()
        }
        completeRequest()
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
