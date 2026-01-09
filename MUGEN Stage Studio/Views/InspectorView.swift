import SwiftUI

struct InspectorView: View {
    
    @ObservedObject var document: StageDocument
    var onDocumentChange: () -> Void
    
    @State private var showAdvanced = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stageSection
                
                if !document.layers.isEmpty {
                    cameraSection
                    playersSection
                    shadowSection
                    
                    advancedSection
                }
                
                Spacer()
            }
            .padding(12)
        }
        .frame(minWidth: 200, idealWidth: 260, maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Stage Section
    
    private var stageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stage")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Stage name", text: $document.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: document.name) { _, _ in
                        onDocumentChange()
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Resolution")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $document.resolution) {
                    ForEach(Resolution.allCases) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: document.resolution) { _, _ in
                    onDocumentChange()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Engine")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $document.targetEngine) {
                    ForEach(Engine.allCases) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: document.targetEngine) { _, _ in
                    onDocumentChange()
                }
            }
        }
    }
    
    // MARK: - Camera Section
    
    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Camera")
                .font(.headline)
            
            HStack {
                Text("Ground Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(document.groundLineY)")
                    .font(.caption.monospacedDigit())
            }
            
            HStack {
                Text("Bounds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("L:\(document.camera.boundLeft) R:\(document.camera.boundRight)")
                    .font(.caption.monospacedDigit())
            }
        }
    }
    
    // MARK: - Players Section
    
    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("P1 Position")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(document.players.p1X)")
                        .font(.caption.monospacedDigit())
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("P2 Position")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(document.players.p2X)")
                        .font(.caption.monospacedDigit())
                }
            }
        }
    }
    
    // MARK: - Shadow Section
    
    private var shadowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shadow")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $document.shadow.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: document.shadow.enabled) { _, _ in
                        onDocumentChange()
                    }
            }
            
            if document.shadow.enabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Intensity: \(document.shadow.intensity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { Double(document.shadow.intensity) },
                        set: { document.shadow.intensity = Int($0) }
                    ), in: 0...256, step: 1)
                    .onChange(of: document.shadow.intensity) { _, _ in
                        onDocumentChange()
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showAdvanced.toggle() }) {
                HStack {
                    Text("Advanced")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 8) {
                    // Tension
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Camera Tension: \(document.camera.tension)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(document.camera.tension) },
                            set: { document.camera.tension = Int($0) }
                        ), in: 0...200, step: 1)
                        .onChange(of: document.camera.tension) { _, _ in
                            onDocumentChange()
                        }
                    }
                    
                    // Vertical follow
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vertical Follow: \(String(format: "%.1f", document.camera.verticalFollow))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(document.camera.verticalFollow) },
                            set: { document.camera.verticalFollow = Float($0) }
                        ), in: 0...1, step: 0.1)
                        .onChange(of: document.camera.verticalFollow) { _, _ in
                            onDocumentChange()
                        }
                    }
                    
                    // Floor tension
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Floor Tension: \(document.camera.floorTension)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(document.camera.floorTension) },
                            set: { document.camera.floorTension = Int($0) }
                        ), in: 0...300, step: 1)
                        .onChange(of: document.camera.floorTension) { _, _ in
                            onDocumentChange()
                        }
                    }
                    
                    // Shadow Y scale
                    if document.shadow.enabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shadow Scale: \(String(format: "%.1f", document.shadow.yscale))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(document.shadow.yscale) },
                                set: { document.shadow.yscale = Float($0) }
                            ), in: 0...1, step: 0.1)
                            .onChange(of: document.shadow.yscale) { _, _ in
                                onDocumentChange()
                            }
                        }
                    }
                    
                    // Zoom settings (MUGEN 1.1+ / IKEMEN only)
                    // These control in-game camera behavior, not the editor view
                    if document.targetEngine.supportsZoom {
                        Divider()
                        
                        Toggle(isOn: $document.camera.zoomEnabled) {
                            Text("In-Game Zoom")
                                .font(.caption)
                        }
                        .onChange(of: document.camera.zoomEnabled) { _, _ in
                            onDocumentChange()
                        }
                        
                        Text("Controls camera zoom during gameplay")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                        
                        if document.camera.zoomEnabled {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Zoom Out (Min): \(String(format: "%.1f", document.camera.zoomMin))x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: Binding(
                                    get: { Double(document.camera.zoomMin) },
                                    set: { document.camera.zoomMin = Float($0) }
                                ), in: 0.25...1.0, step: 0.05)
                                .onChange(of: document.camera.zoomMin) { _, _ in
                                    onDocumentChange()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Zoom In (Max): \(String(format: "%.1f", document.camera.zoomMax))x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: Binding(
                                    get: { Double(document.camera.zoomMax) },
                                    set: { document.camera.zoomMax = Float($0) }
                                ), in: 1.0...2.0, step: 0.05)
                                .onChange(of: document.camera.zoomMax) { _, _ in
                                    onDocumentChange()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Zoom: \(String(format: "%.1f", document.camera.zoomStart))x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: Binding(
                                    get: { Double(document.camera.zoomStart) },
                                    set: { document.camera.zoomStart = Float($0) }
                                ), in: 0.5...1.5, step: 0.05)
                                .onChange(of: document.camera.zoomStart) { _, _ in
                                    onDocumentChange()
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InspectorView(document: StageDocument()) {
        // Preview callback
    }
}
