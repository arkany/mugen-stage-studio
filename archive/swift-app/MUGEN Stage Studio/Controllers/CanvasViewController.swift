import Cocoa

protocol CanvasViewControllerDelegate: AnyObject {
    func canvasViewController(_ controller: CanvasViewController, didUpdateGroundLine y: CGFloat)
    func canvasViewController(_ controller: CanvasViewController, didUpdateCameraBounds bounds: CGRect)
    func canvasViewController(_ controller: CanvasViewController, didUpdatePlayer1X x: CGFloat)
    func canvasViewController(_ controller: CanvasViewController, didUpdatePlayer2X x: CGFloat)
    func canvasViewControllerDidReceiveImageDrop(_ controller: CanvasViewController, image: NSImage, filename: String)
}

class CanvasViewController: NSViewController {
    
    // MARK: - Properties
    
    weak var delegate: CanvasViewControllerDelegate?
    
    private let document: StageDocument
    private var canvasView: CanvasView!
    private var scrollView: NSScrollView!
    private var zoomLabel: NSTextField!
    
    var selectedLayer: BackgroundLayer?
    
    private var isPreviewMode = false
    private var previewTimer: Timer?
    private var previewProgress: CGFloat = 0
    
    // Zoom
    private var zoomLevel: CGFloat = 1.0 {
        didSet {
            applyZoom()
            updateZoomLabel()
        }
    }
    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 3.0
    
    // MARK: - Initialization
    
    init(document: StageDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupCanvasView()
        setupDropTarget()
        setupZoomControls()
        setupGestureRecognizers()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        scrollView.borderType = .noBorder
        scrollView.allowsMagnification = true
        scrollView.minMagnification = minZoom
        scrollView.maxMagnification = maxZoom
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Observe magnification changes from scroll view
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(magnificationDidChange(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )
        
        // Also observe live magnification for smooth label updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(liveMagnificationChanged(_:)),
            name: NSScrollView.willStartLiveMagnifyNotification,
            object: scrollView
        )
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func magnificationDidChange(_ notification: Notification) {
        zoomLevel = scrollView.magnification
    }
    
    @objc private func liveMagnificationChanged(_ notification: Notification) {
        // Start a timer to update zoom label during live magnification
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            self.updateZoomLabel()
            // Stop when magnification gesture ends
            if abs(self.scrollView.magnification - self.zoomLevel) < 0.001 {
                timer.invalidate()
            }
        }
    }
    
    private func setupCanvasView() {
        canvasView = CanvasView(document: document)
        canvasView.delegate = self
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = canvasView
        
        // Set initial canvas size
        updateCanvasSize()
    }
    
    private func setupDropTarget() {
        canvasView.registerForDraggedTypes([.fileURL, .png, .tiff])
    }
    
    private func setupZoomControls() {
        // Zoom label in bottom-left corner
        zoomLabel = NSTextField(labelWithString: "100%")
        zoomLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        zoomLabel.textColor = .secondaryLabelColor
        zoomLabel.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        zoomLabel.drawsBackground = true
        zoomLabel.isBezeled = false
        zoomLabel.alignment = .center
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(zoomLabel)
        
        NSLayoutConstraint.activate([
            zoomLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            zoomLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            zoomLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    private func setupGestureRecognizers() {
        // Pinch to zoom
        let magnification = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnification(_:)))
        scrollView.addGestureRecognizer(magnification)
    }
    
    @objc private func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
        let newZoom = zoomLevel * (1 + gesture.magnification)
        zoomLevel = max(minZoom, min(maxZoom, newZoom))
        gesture.magnification = 0
    }
    
    // MARK: - Public Methods
    
    func refreshCanvas() {
        updateCanvasSize()
        canvasView.needsDisplay = true
    }
    
    func setPreviewMode(_ enabled: Bool) {
        isPreviewMode = enabled
        canvasView.setPreviewMode(enabled)
        
        if enabled {
            startPreviewAnimation()
        } else {
            stopPreviewAnimation()
        }
    }
    
    func zoomIn() {
        let newZoom = min(maxZoom, zoomLevel * 1.25)
        animateZoom(to: newZoom)
    }
    
    func zoomOut() {
        let newZoom = max(minZoom, zoomLevel / 1.25)
        animateZoom(to: newZoom)
    }
    
    func zoomToFit() {
        guard let imageSize = document.imageSize else { return }
        
        let padding: CGFloat = 100
        let canvasSize = NSSize(
            width: imageSize.width + padding * 2,
            height: imageSize.height + padding * 2
        )
        
        let availableSize = scrollView.bounds.size
        let scaleX = availableSize.width / canvasSize.width
        let scaleY = availableSize.height / canvasSize.height
        
        let targetZoom = min(scaleX, scaleY, 1.0)  // Don't zoom above 100%
        animateZoom(to: targetZoom)
    }
    
    func zoomToActualSize() {
        animateZoom(to: 1.0)
    }
    
    private func animateZoom(to targetZoom: CGFloat) {
        // Start tracking zoom label updates during animation
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateZoomLabelFromScrollView()
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.animator().magnification = targetZoom
        } completionHandler: { [weak self] in
            timer.invalidate()
            self?.zoomLevel = targetZoom
        }
    }
    
    private func updateZoomLabelFromScrollView() {
        let percentage = Int(scrollView.magnification * 100)
        zoomLabel.stringValue = "\(percentage)%"
    }
    
    // MARK: - Private Methods
    
    private func updateCanvasSize() {
        if let imageSize = document.imageSize {
            // Canvas is the size of the image plus some padding
            let padding: CGFloat = 100
            let canvasSize = NSSize(
                width: imageSize.width + padding * 2,
                height: imageSize.height + padding * 2
            )
            canvasView.frame = NSRect(origin: .zero, size: canvasSize)
            
            // Auto-fit zoom for new images
            DispatchQueue.main.async { [weak self] in
                self?.zoomToFit()
            }
        } else {
            // When empty, fill the scroll view's visible area so empty state is centered
            updateEmptyCanvasSize()
        }
    }
    
    private func updateEmptyCanvasSize() {
        // Make canvas fill the scroll view when empty
        let scrollBounds = scrollView.bounds
        canvasView.frame = NSRect(origin: .zero, size: scrollBounds.size)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Keep empty canvas sized to scroll view
        if document.layers.isEmpty {
            updateEmptyCanvasSize()
            canvasView.needsDisplay = true
        }
    }
    
    private func applyZoom() {
        scrollView.magnification = zoomLevel
    }
    
    private func updateZoomLabel() {
        let percentage = Int(zoomLevel * 100)
        zoomLabel.stringValue = "\(percentage)%"
    }
    
    private func startPreviewAnimation() {
        previewProgress = 0
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updatePreviewAnimation()
        }
    }
    
    private func stopPreviewAnimation() {
        previewTimer?.invalidate()
        previewTimer = nil
        previewProgress = 0
        canvasView.setPreviewOffset(0)
    }
    
    private func updatePreviewAnimation() {
        // Animate camera pan across full bounds (2 second loop)
        previewProgress += 1.0 / 120.0  // 2 seconds at 60fps
        if previewProgress > 1.0 {
            previewProgress = 0
        }
        
        // Sinusoidal motion for smooth camera pan
        let normalizedProgress = sin(previewProgress * .pi * 2) * 0.5 + 0.5
        let panRange = CGFloat(document.camera.boundRight - document.camera.boundLeft)
        let offset = CGFloat(document.camera.boundLeft) + panRange * normalizedProgress
        
        canvasView.setPreviewOffset(offset)
    }
}

// MARK: - CanvasViewDelegate

extension CanvasViewController: CanvasViewDelegate {
    
    func canvasView(_ view: CanvasView, didDragGroundLineTo y: CGFloat) {
        delegate?.canvasViewController(self, didUpdateGroundLine: y)
    }
    
    func canvasView(_ view: CanvasView, didDragCameraBoundsTo bounds: CGRect) {
        delegate?.canvasViewController(self, didUpdateCameraBounds: bounds)
    }
    
    func canvasView(_ view: CanvasView, didDragPlayer1To x: CGFloat) {
        delegate?.canvasViewController(self, didUpdatePlayer1X: x)
    }
    
    func canvasView(_ view: CanvasView, didDragPlayer2To x: CGFloat) {
        delegate?.canvasViewController(self, didUpdatePlayer2X: x)
    }
    
    func canvasView(_ view: CanvasView, didReceiveDroppedImage image: NSImage, filename: String) {
        delegate?.canvasViewControllerDidReceiveImageDrop(self, image: image, filename: filename)
    }
}
