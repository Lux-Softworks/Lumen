import UIKit
import WebKit

final class LumenWebView: WKWebView {
    private var pendingRemoveAnnotationID: String?

    @available(iOS 16.0, *)
    private lazy var removeMenuInteraction: UIEditMenuInteraction = {
        let interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        return interaction
    }()

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(lumenHighlight(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func lumenHighlight(_ sender: Any?) {
        evaluateJavaScript(
            "window.__lumenCaptureHighlight && window.__lumenCaptureHighlight()",
            completionHandler: nil
        )
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        if #available(iOS 16.0, *) {
            let cmd = UICommand(
                title: "Highlight",
                action: #selector(lumenHighlight(_:))
            )
            builder.insertChild(
                UIMenu(options: .displayInline, children: [cmd]),
                atStartOfMenu: .standardEdit
            )
        }
        super.buildMenu(with: builder)
    }

    @MainActor
    func showRemoveHighlightMenu(rect: CGRect, annotationID: String) {
        guard #available(iOS 16.0, *) else { return }
        pendingRemoveAnnotationID = annotationID
        let point = CGPoint(x: rect.midX, y: rect.maxY)
        let config = UIEditMenuConfiguration(
            identifier: "lumen-remove-highlight" as NSString,
            sourcePoint: point
        )
        removeMenuInteraction.presentEditMenu(with: config)
    }
}

@available(iOS 16.0, *)
extension LumenWebView: UIEditMenuInteractionDelegate {
    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard (configuration.identifier as? String) == "lumen-remove-highlight",
              let id = pendingRemoveAnnotationID else { return nil }
        let remove = UIAction(
            title: "Remove Highlight",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            guard let self else { return }
            self.pendingRemoveAnnotationID = nil
            Task { [weak self] in
                try? await KnowledgeStorage.shared.deleteAnnotation(id: id)
                guard let self else { return }
                await MainActor.run { AnnotationHandler.applyAll(webView: self) }
            }
        }
        return UIMenu(children: [remove])
    }
}
