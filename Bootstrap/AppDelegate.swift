//
//  AppDelegate.swift
//  LADM
//
//  Created by Guilherme Rambo on 23/02/21.
//

import Cocoa
import SwiftUI
import LADMCore
import Combine
import Sparkle

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var settingsObservation: AnyCancellable?
    
    
    let settings = LADMSettings()

    lazy var switcher: LADMSystemAppearanceSwitcher = {
        LADMSystemAppearanceSwitcher(settings: settings)
    }()
    
    private var shouldShowUI: Bool {
        !settings.hasLaunchedAppBefore
        || shouldShowSettingsOnNextLaunch
        || UserDefaults.standard.bool(forKey: "ShowSettings")
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        SUUpdater.shared()?.delegate = self
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updateStatusItem()
        
        settingsObservation = settings.$showMenuBarIcon.sink { [weak self] _ in
            self?.updateStatusItem()
        }
        
        if shouldShowUI {
            settings.hasLaunchedAppBefore = true
            showSettingsWindow(nil)
        }
        
        switcher.activate()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(receivedShutdownNotification),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }
    
    private lazy var sensorReader = LADMAmbientLightSensorReader(frequency: .realtime)

    @IBAction func showSettingsWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 385, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Settings")
        window.titlebarAppearsTransparent = true
        window.title = "LADM Settings"
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.isReleasedWhenClosed = false
        
        let view = SettingsView()
            .environmentObject(sensorReader)
            .environmentObject(settings)
        
        window.contentView = NSHostingView(rootView: view)
        
        window.makeKeyAndOrderFront(nil)
        window.center()
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func terminate(_ sender: Any?) {
        // No need to confirm on quit if the user's Mac is not supported.
        shouldSkipTerminationConfirmation = !sensorReader.isSensorReady
        
        NSApp.terminate(sender)
    }

    private var isShowingSettingsWindow: Bool {
        guard let window = window else { return false }
        return window.isVisible
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isShowingSettingsWindow else { return true }
        
        showSettingsWindow(nil)
        
        return true
    }
    
    private var shouldShowSettingsOnNextLaunch: Bool {
        get {
            let value = UserDefaults.standard.bool(forKey: #function)
            
            if value {
                // Reset flag
                UserDefaults.standard.set(false, forKey: #function)
            }
            
            return value
        }
        set {
            // Note: synchronize() was deprecated and is now a no-op — removed.
            UserDefaults.standard.set(newValue, forKey: #function)
        }
    }
    
    private var shouldSkipTerminationConfirmation = false
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !shouldSkipTerminationConfirmation else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit LADM?"
        alert.informativeText = "If you quit LADM, it won't be able to monitor your ambient light level and change the system theme automatically. Would you like to hide LADM instead?"
        alert.addButton(withTitle: "Hide LADM")
        alert.addButton(withTitle: "Quit")

        let result = alert.runModal()

        if result == .alertSecondButtonReturn {
            return .terminateNow
        } else {
            window?.close()
            
            return .terminateCancel
        }
    }
    
    @objc func receivedShutdownNotification(_ note: Notification) {
        shouldSkipTerminationConfirmation = true
    }

    // MARK: - Menu Bar Popover Logic
    
    private func updateStatusItem() {
        if settings.showMenuBarIcon {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = statusItem.button {
                    button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "LADM")
                    button.action = #selector(togglePopover(_:))
                    button.target = self
                }
                
                if popover == nil {
                    let popoverView = MenuBarPopoverView(openSettingsAction: { [weak self] in
                        guard let self = self else { return }
                        self.closePopover(sender: nil)
                        self.showSettingsWindow(nil)
                    })
                    .environmentObject(sensorReader)
                    .environmentObject(settings)
                    
                    popover = NSPopover()
                    popover.contentSize = NSSize(width: 280, height: 180)
                    popover.behavior = .transient
                    popover.contentViewController = NSHostingController(rootView: popoverView)
                }
            }
        } else {
            if let targetStatusItem = statusItem {
                NSStatusBar.system.removeStatusItem(targetStatusItem)
                statusItem = nil
            }
        }
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    private func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let strongSelf = self, strongSelf.popover.isShown {
                    strongSelf.closePopover(sender: event)
                }
            }
        }
    }
    
    private func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
    }
}

extension AppDelegate: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        window = nil
    }
    
}

extension AppDelegate: SUUpdaterDelegate {
    
    func updaterWillRelaunchApplication(_ updater: SUUpdater) {
        shouldSkipTerminationConfirmation = true
        shouldShowSettingsOnNextLaunch = true
    }
    
    func updater(_ updater: SUUpdater, didCancelInstallUpdateOnQuit item: SUAppcastItem) {
        shouldSkipTerminationConfirmation = false
    }
    
}

// MARK: - Popover SwiftUI View
struct MenuBarPopoverView: View {
    @EnvironmentObject var reader: LADMAmbientLightSensorReader
    @EnvironmentObject var settings: LADMSettings
    
    var openSettingsAction: () -> Void
    private let darknessInterval: ClosedRange<Double> = 0...100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            
            Slider(value: $settings.darknessThreshold, in: darknessInterval)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 280)
    }
}
