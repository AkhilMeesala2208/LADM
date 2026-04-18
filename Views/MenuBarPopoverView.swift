//
//  MenuBarPopoverView.swift
//  LADM
//

import SwiftUI
import LADMCore

struct MenuBarPopoverView: View {
    @EnvironmentObject var reader: LADMAmbientLightSensorReader
    @EnvironmentObject var settings: LADMSettings
    
    // Action to open settings
    var openSettingsAction: () -> Void
    
    private let darknessInterval: ClosedRange<Double> = 0...100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                Text("LADM Ambient Light")
                    .font(.headline)
                Spacer()
                Button(action: openSettingsAction) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .help("Settings")
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .help("Quit LADM")
            }
            
            Divider()
            
            // Text values
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Current Ambient Light:")
                    Spacer()
                    Text("\(reader.ambientLightValue.formattedNoFractionDigits)%")
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack(alignment: .firstTextBaseline) {
                    Text("Go Dark Below:")
                    Spacer()
                    Text("\(settings.darknessThreshold.formattedNoFractionDigits)%")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .font(.subheadline)
            
            // Slider
            Slider(value: $settings.darknessThreshold, in: darknessInterval)
                .frame(maxWidth: .infinity)
            
        }
        .padding()
        .frame(width: 280)
    }
}
