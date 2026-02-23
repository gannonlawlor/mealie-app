//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Gannon Lawlor on 2/23/26.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

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
                    if let url = item as? URL {
                        self?.openMainApp(with: url)
                    } else {
                        self?.completeRequest()
                    }
                }
                return
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                    if let text = item as? String, let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                        self?.openMainApp(with: url)
                    } else {
                        self?.completeRequest()
                    }
                }
                return
            }
        }

        completeRequest()
    }

    private func openMainApp(with url: URL) {
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let appURL = URL(string: "mealie://import?url=\(encoded)") else {
            completeRequest()
            return
        }

        // Use the responder chain to open the URL
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: appURL)
                break
            }
            responder = r.next
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.completeRequest()
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
