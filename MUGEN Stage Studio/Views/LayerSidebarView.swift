import Cocoa

protocol LayerSidebarViewDelegate: AnyObject {
    func layerSidebarView(_ view: LayerSidebarView, didSelectLayer layer: BackgroundLayer?)
    func layerSidebarView(_ view: LayerSidebarView, didToggleVisibility layer: BackgroundLayer)
    func layerSidebarView(_ view: LayerSidebarView, didAddLayerWithImage image: NSImage, filename: String)
}

class LayerSidebarView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: LayerSidebarViewDelegate?
    
    private let document: StageDocument
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    
    // MARK: - Initialization
    
    init(document: StageDocument) {
        self.document = document
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupHeader()
        setupTableView()
        setupAddButton()
    }
    
    private func setupHeader() {
        let headerLabel = NSTextField(labelWithString: "Layers")
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerLabel)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12)
        ])
    }
    
    private func setupTableView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("layer"))
        column.width = 160
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -50)
        ])
    }
    
    private func setupAddButton() {
        addButton = NSButton(title: "+ Add Layer", target: self, action: #selector(addLayerClicked))
        addButton.bezelStyle = .accessoryBarAction
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.isEnabled = false // Disabled in MVP (single layer only)
        addSubview(addButton)
        
        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func addLayerClicked(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an image for the new layer"
        panel.prompt = "Add Layer"
        
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            
            guard let image = NSImage(contentsOf: url) else {
                let alert = NSAlert()
                alert.messageText = "Could not load image"
                alert.informativeText = "The selected file could not be loaded as an image."
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
            
            let filename = url.deletingPathExtension().lastPathComponent
            self.delegate?.layerSidebarView(self, didAddLayerWithImage: image, filename: filename)
        }
    }
    
    @objc private func visibilityToggled(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0 && row < document.layers.count else { return }
        delegate?.layerSidebarView(self, didToggleVisibility: document.layers[row])
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

extension LayerSidebarView: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return document.layers.count
    }
}

// MARK: - NSTableViewDelegate

extension LayerSidebarView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < document.layers.count else { return nil }
        
        let layer = document.layers[row]
        
        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("LayerCell")
        
        // Visibility checkbox
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(visibilityToggled))
        checkbox.state = layer.visible ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(checkbox)
        
        // Layer name
        let textField = NSTextField(labelWithString: layer.name)
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(textField)
        cellView.textField = textField
        
        // Thumbnail
        let imageView = NSImageView()
        imageView.image = layer.image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(imageView)
        cellView.imageView = imageView
        
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            checkbox.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            
            imageView.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 20),
            
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < document.layers.count {
            delegate?.layerSidebarView(self, didSelectLayer: document.layers[selectedRow])
        } else {
            delegate?.layerSidebarView(self, didSelectLayer: nil)
        }
    }
}
