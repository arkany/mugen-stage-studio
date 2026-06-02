import Cocoa
import SwiftUI

class MainViewController: NSViewController {
    
    // MARK: - Properties
    
    private(set) var stageDocument = StageDocument()
    
    private var splitView: NSSplitView!
    private var layerSidebarView: LayerSidebarView!
    private var canvasViewController: CanvasViewController!
    private var inspectorHostingController: NSHostingController<InspectorView>!
    
    private var toolbar: NSToolbar!
    private var isPreviewMode = false
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplitView()
        setupToolbar()
    }
    
    // MARK: - Setup
    
    private func setupSplitView() {
        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)
        
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Left sidebar - Layer list
        layerSidebarView = LayerSidebarView(document: stageDocument)
        layerSidebarView.delegate = self
        let sidebarContainer = NSView()
        sidebarContainer.wantsLayer = true
        sidebarContainer.addSubview(layerSidebarView)
        layerSidebarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            layerSidebarView.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            layerSidebarView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            layerSidebarView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            layerSidebarView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor)
        ])
        
        // Set sidebar width
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.widthAnchor.constraint(equalToConstant: 180).isActive = true
        
        // Center - Canvas
        canvasViewController = CanvasViewController(document: stageDocument)
        canvasViewController.delegate = self
        
        // Right sidebar - Inspector (SwiftUI)
        let inspectorView = InspectorView(document: stageDocument, onDocumentChange: { [weak self] in
            self?.documentDidChange()
        })
        inspectorHostingController = NSHostingController(rootView: inspectorView)
        
        // Add views to split view
        splitView.addArrangedSubview(sidebarContainer)
        splitView.addArrangedSubview(canvasViewController.view)
        splitView.addArrangedSubview(inspectorHostingController.view)
        
        // Set holding priorities so sidebar and inspector don't resize with window
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)  // Sidebar - fixed
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)   // Canvas - flexible
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 2)  // Inspector - fixed
        
        // Add child view controllers
        addChild(canvasViewController)
        addChild(inspectorHostingController)
        
        // Set delegate to control min/max widths
        splitView.delegate = self
    }
    
    private func setupToolbar() {
        guard let window = view.window else { return }
        
        toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        
        window.toolbar = toolbar
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        setupToolbar()
        
        // Connect undo manager from window to document
        if let windowUndoManager = view.window?.undoManager {
            stageDocument.undoManager = windowUndoManager
        }
        
        // Set initial divider positions now that view is sized
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.splitView.setPosition(180, ofDividerAt: 0)
            self.splitView.setPosition(self.splitView.bounds.width - 260, ofDividerAt: 1)
        }
    }
    
    // MARK: - Actions
    
    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a background image for your stage"
        panel.prompt = "Import"
        
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadImage(from: url)
        }
    }
    
    func zoomIn() {
        canvasViewController.zoomIn()
    }
    
    func zoomOut() {
        canvasViewController.zoomOut()
    }
    
    func zoomToFit() {
        canvasViewController.zoomToFit()
    }
    
    func zoomActualSize() {
        canvasViewController.zoomToActualSize()
    }
    
    func exportStage() {
        // Validate first
        let validation = ValidationEngine.validate(stageDocument)
        
        if !validation.errors.isEmpty {
            showValidationErrors(validation.errors)
            return
        }
        
        if !validation.warnings.isEmpty {
            showValidationWarnings(validation.warnings) { [weak self] shouldContinue in
                if shouldContinue {
                    self?.performExport()
                }
            }
            return
        }
        
        performExport()
    }
    
    private func performExport() {
        let stageName = stageDocument.safeName
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "\(stageName).zip"
        panel.message = "Save your stage as a ZIP file to import via IKEMEN Lab"
        panel.prompt = "Export"
        
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.exportStageAsZip(to: url)
        }
    }
    
    private func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            showError("Failed to load image", message: "The selected file could not be opened as an image.")
            return
        }
        
        // Validate image size
        let size = image.size
        if size.width < 320 || size.height < 240 {
            showError("Image too small", message: "The image must be at least 320×240 pixels.")
            return
        }
        
        if size.width > 4096 || size.height > 4096 {
            showWarning("Large image", message: "Images over 4096 pixels may cause performance issues in IKEMEN GO.")
        }
        
        // Create background layer
        let layer = BackgroundLayer(
            name: url.deletingPathExtension().lastPathComponent,
            image: image
        )
        
        // Group all initial setup as a single undo action
        stageDocument.undoManager?.beginUndoGrouping()
        
        // Clear existing layers and add new one
        while !stageDocument.layers.isEmpty {
            stageDocument.removeLayer(at: 0, actionName: "Import Image")
        }
        stageDocument.addLayer(layer, actionName: "Import Image")
        
        // Set default name from filename if not set
        if stageDocument.name.isEmpty {
            stageDocument.name = url.deletingPathExtension().lastPathComponent
        }
        
        // Calculate initial values based on image
        stageDocument.applyDefaults(for: image.size)
        
        stageDocument.undoManager?.endUndoGrouping()
        stageDocument.undoManager?.setActionName("Import Image")
        
        // Refresh UI
        documentDidChange()
    }
    
    private func exportStageAsZip(to url: URL) {
        let stageName = stageDocument.safeName
        
        do {
            try ExportController.exportAsZip(stageDocument, to: url)
            showSuccess("Stage exported!", message: "Your stage '\(stageName)' has been saved as a ZIP file.\n\nImport it using IKEMEN Lab to add it to your game.")
        } catch {
            showError("Export failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Mode Toggle
    
    @objc func togglePreviewMode(_ sender: Any?) {
        isPreviewMode.toggle()
        canvasViewController.setPreviewMode(isPreviewMode)
        
        // Update toolbar button state
        if let item = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "previewMode" }) {
            item.image = NSImage(systemSymbolName: isPreviewMode ? "pencil" : "play.fill", accessibilityDescription: nil)
            item.label = isPreviewMode ? "Edit" : "Preview"
        }
    }
    
    // MARK: - Document Changes
    
    private func documentDidChange() {
        canvasViewController.refreshCanvas()
        layerSidebarView.refresh()
        
        // Update inspector
        let inspectorView = InspectorView(document: stageDocument, onDocumentChange: { [weak self] in
            self?.documentDidChange()
        })
        inspectorHostingController.rootView = inspectorView
    }
    
    // MARK: - Alerts
    
    private func showError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
    
    private func showWarning(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
    
    private func showSuccess(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
    
    private func showValidationErrors(_ errors: [ValidationResult.Issue]) {
        let message = errors.map { "• \($0.message)" }.joined(separator: "\n")
        showError("Cannot export stage", message: message)
    }
    
    private func showValidationWarnings(_ warnings: [ValidationResult.Issue], completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Export with warnings?"
        alert.informativeText = warnings.map { "• \($0.message)" }.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Export Anyway")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: view.window!) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }
}

// MARK: - NSSplitViewDelegate

extension MainViewController: NSSplitViewDelegate {
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        switch dividerIndex {
        case 0:
            return 150  // Minimum sidebar width
        case 1:
            return proposedMinimumPosition
        default:
            return proposedMinimumPosition
        }
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        switch dividerIndex {
        case 0:
            return 250  // Maximum sidebar width
        case 1:
            return splitView.bounds.width - 200  // Leave room for inspector
        default:
            return proposedMaximumPosition
        }
    }
    
    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false
    }
}

// MARK: - NSToolbarDelegate

extension MainViewController: NSToolbarDelegate {
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("importImage"),
            .flexibleSpace,
            NSToolbarItem.Identifier("zoomOut"),
            NSToolbarItem.Identifier("zoomFit"),
            NSToolbarItem.Identifier("zoomIn"),
            .flexibleSpace,
            NSToolbarItem.Identifier("previewMode"),
            .flexibleSpace,
            NSToolbarItem.Identifier("export")
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        switch itemIdentifier.rawValue {
        case "importImage":
            item.label = "Import"
            item.paletteLabel = "Import Image"
            item.toolTip = "Import a background image"
            item.image = NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: "Import")
            item.action = #selector(importImageAction)
            item.target = self
            
        case "zoomIn":
            item.label = "Zoom In"
            item.paletteLabel = "Zoom In"
            item.toolTip = "Zoom in on the canvas"
            item.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In")
            item.action = #selector(zoomInAction)
            item.target = self
            
        case "zoomOut":
            item.label = "Zoom Out"
            item.paletteLabel = "Zoom Out"
            item.toolTip = "Zoom out on the canvas"
            item.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out")
            item.action = #selector(zoomOutAction)
            item.target = self
            
        case "zoomFit":
            item.label = "Fit"
            item.paletteLabel = "Zoom to Fit"
            item.toolTip = "Zoom to fit the canvas"
            item.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fit")
            item.action = #selector(zoomFitAction)
            item.target = self
            
        case "previewMode":
            item.label = "Preview"
            item.paletteLabel = "Toggle Preview Mode"
            item.toolTip = "Toggle preview mode to see the stage in action"
            item.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Preview")
            item.action = #selector(togglePreviewMode)
            item.target = self
            
        case "export":
            item.label = "Export"
            item.paletteLabel = "Export Stage"
            item.toolTip = "Export stage to IKEMEN GO"
            item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export")
            item.action = #selector(exportStageAction)
            item.target = self
            
        default:
            return nil
        }
        
        return item
    }
    
    // MARK: - Toolbar Actions
    
    @objc private func importImageAction(_ sender: Any?) {
        importImage()
    }
    
    @objc private func zoomInAction(_ sender: Any?) {
        zoomIn()
    }
    
    @objc private func zoomOutAction(_ sender: Any?) {
        zoomOut()
    }
    
    @objc private func zoomFitAction(_ sender: Any?) {
        zoomToFit()
    }
    
    @objc private func exportStageAction(_ sender: Any?) {
        exportStage()
    }
}

// MARK: - LayerSidebarViewDelegate

extension MainViewController: LayerSidebarViewDelegate {
    
    func layerSidebarView(_ view: LayerSidebarView, didSelectLayer layer: BackgroundLayer?) {
        canvasViewController.selectedLayer = layer
        canvasViewController.refreshCanvas()
    }
    
    func layerSidebarView(_ view: LayerSidebarView, didToggleVisibility layer: BackgroundLayer) {
        if let index = stageDocument.layers.firstIndex(where: { $0.id == layer.id }) {
            var updatedLayer = stageDocument.layers[index]
            updatedLayer.visible.toggle()
            stageDocument.updateLayer(at: index, with: updatedLayer, actionName: "Toggle Layer Visibility")
            documentDidChange()
        }
    }
    
    func layerSidebarView(_ view: LayerSidebarView, didAddLayerWithImage image: NSImage, filename: String) {
        let layer = BackgroundLayer(name: filename, image: image)
        stageDocument.addLayer(layer, actionName: "Add Layer")
        documentDidChange()
    }
}

// MARK: - CanvasViewControllerDelegate

extension MainViewController: CanvasViewControllerDelegate {
    
    func canvasViewController(_ controller: CanvasViewController, didUpdateGroundLine y: CGFloat) {
        // groundLineY has built-in undo via didSet
        stageDocument.groundLineY = Int(y)
        documentDidChange()
    }
    
    func canvasViewController(_ controller: CanvasViewController, didUpdateCameraBounds bounds: CGRect) {
        stageDocument.setCameraBounds(bounds, actionName: "Resize Camera Bounds")
        documentDidChange()
    }
    
    func canvasViewController(_ controller: CanvasViewController, didUpdatePlayer1X x: CGFloat) {
        stageDocument.setPlayer1X(Int(x), actionName: "Move Player 1")
        documentDidChange()
    }
    
    func canvasViewController(_ controller: CanvasViewController, didUpdatePlayer2X x: CGFloat) {
        stageDocument.setPlayer2X(Int(x), actionName: "Move Player 2")
        documentDidChange()
    }
    
    func canvasViewControllerDidReceiveImageDrop(_ controller: CanvasViewController, image: NSImage, filename: String) {
        stageDocument.undoManager?.beginUndoGrouping()
        
        let layer = BackgroundLayer(name: filename, image: image)
        stageDocument.addLayer(layer, actionName: "Drop Image")
        
        if stageDocument.name.isEmpty {
            stageDocument.name = filename
        }
        
        stageDocument.applyDefaults(for: image.size)
        
        stageDocument.undoManager?.endUndoGrouping()
        stageDocument.undoManager?.setActionName("Drop Image")
        
        documentDidChange()
    }
}
