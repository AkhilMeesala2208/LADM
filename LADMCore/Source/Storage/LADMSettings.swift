//
//  LADMSettings.swift
//  LADMCore
//
//  Created by Guilherme Rambo on 23/02/21.
//

import Foundation
import SwiftUI
import ServiceManagement

public final class LADMSettings: ObservableObject {
    
    private struct Keys {
        static let darknessThreshold = "darknessThreshold"
        static let isChangeSystemAppearanceBasedOnAmbientLightEnabled = "isChangeSystemAppearanceBasedOnAmbientLightEnabled"
        static let darknessThresholdIntervalInSeconds = "darknessThresholdIntervalInSeconds"
        static let ambientLightSmoothingConstant = "ambientLightSmoothingConstant"
        static let hasLaunchedAppBefore = "hasLaunchedAppBefore"
        static let disableAppearanceChangeInClamshellMode = "disableAppearanceChangeInClamshellMode"
        static let enableImmediateChangeOnComputerWake = "enableImmediateChangeOnComputerWake"
        static let extraThresholdBeforeRevertingToLightMode = "extraThresholdBeforeRevertingToLightMode"
        
        static let defaultDarknessThreshold: Double = {
            LADMAmbientLightSensor.hardwareUsesLegacySensor() ? 20.0 : 52.0
        }()

        static let defaultAmbientLightSmoothingConstant: Double = {
            LADMAmbientLightSensor.hardwareUsesLegacySensor() ? 5.0 : 3.0
        }()
        
        static let defaultExtraThresholdBeforeRevertingToLightMode: Double = {
            LADMAmbientLightSensor.hardwareUsesLegacySensor() ? 30.0 : 10.0
        }()

        static let defaultDarknessThresholdIntervalInSeconds = 60.0
    }
    
    private let defaults: UserDefaults

    let isPreviewing: Bool
    
    public init(forPreview isPreviewing: Bool = false, defaults: UserDefaults = .standard) {
        self.isPreviewing = isPreviewing
        self.defaults = defaults
        
        defaults.register(defaults: [
            Keys.darknessThreshold: Keys.defaultDarknessThreshold,
            Keys.isChangeSystemAppearanceBasedOnAmbientLightEnabled: true,
            Keys.darknessThresholdIntervalInSeconds: Keys.defaultDarknessThresholdIntervalInSeconds,
            Keys.ambientLightSmoothingConstant: Keys.defaultAmbientLightSmoothingConstant,
            Keys.disableAppearanceChangeInClamshellMode: true,
            Keys.enableImmediateChangeOnComputerWake: true,
            Keys.extraThresholdBeforeRevertingToLightMode: Keys.defaultExtraThresholdBeforeRevertingToLightMode
        ])
        
        self.isChangeSystemAppearanceBasedOnAmbientLightEnabled = defaults.bool(forKey: Keys.isChangeSystemAppearanceBasedOnAmbientLightEnabled)
        self.hasLaunchedAppBefore = defaults.bool(forKey: Keys.hasLaunchedAppBefore)
        self.darknessThreshold = defaults.optionalDoubleValue(forKey: Keys.darknessThreshold) ?? Keys.defaultDarknessThreshold
        self.darknessThresholdIntervalInSeconds = defaults.optionalDoubleValue(forKey: Keys.darknessThresholdIntervalInSeconds) ?? Keys.defaultDarknessThresholdIntervalInSeconds
        self.ambientLightSmoothingConstant = defaults.optionalDoubleValue(forKey: Keys.ambientLightSmoothingConstant) ?? Keys.defaultAmbientLightSmoothingConstant
        self.extraThresholdBeforeRevertingToLightMode = defaults.optionalDoubleValue(forKey: Keys.extraThresholdBeforeRevertingToLightMode) ?? Keys.defaultExtraThresholdBeforeRevertingToLightMode
        
        if isPreviewing {
            self.isLaunchAtLoginEnabled = false
        } else {
            self.isLaunchAtLoginEnabled = Self.isAppInLoginItems
            
            // On macOS 12 and earlier, we use the legacy SharedFileList to watch for
            // external login-item changes (e.g. the user toggling it in System Prefs).
            // On macOS 13+, SMAppService handles this automatically.
            if #unavailable(macOS 13.0) {
                SharedFileList.sessionLoginItems().changeHandler = { [weak self] _ in
                    self?.updateLaunchAtLoginEnabled()
                }
            }
        }
    }
    
    var isDisableAppearanceChangeInClamshellModeEnabled: Bool {
        defaults.bool(forKey: Keys.disableAppearanceChangeInClamshellMode)
    }
    
    var isImmediateChangeOnComputerWakeEnabled: Bool {
        defaults.bool(forKey: Keys.enableImmediateChangeOnComputerWake)
    }
    
    @Published public var hasLaunchedAppBefore: Bool {
        didSet {
            defaults.set(
                hasLaunchedAppBefore,
                forKey: Keys.hasLaunchedAppBefore
            )
        }
    }
    
    /// Whether to change system appearance automatically based on ambient light.
    @Published public var isChangeSystemAppearanceBasedOnAmbientLightEnabled: Bool {
        didSet {
            defaults.set(
                isChangeSystemAppearanceBasedOnAmbientLightEnabled,
                forKey: Keys.isChangeSystemAppearanceBasedOnAmbientLightEnabled
            )
        }
    }
    
    /// The threshold below which the ambient light is considered "dark".
    @Published public var darknessThreshold: Double {
        didSet {
            defaults.set(
                darknessThreshold,
                forKey: Keys.darknessThreshold
            )
        }
    }
    
    /// For how long the ambient light must be below `darknessThreshold` or above
    /// it for the system appearance to be changed based on that.
    @Published public var darknessThresholdIntervalInSeconds: TimeInterval {
        didSet {
            defaults.set(
                darknessThresholdIntervalInSeconds,
                forKey: Keys.darknessThresholdIntervalInSeconds
            )
        }
    }
    
    /// Changes in ambient light will be ignored if the change is less than this amount.
    /// Not currently exposed in the UI.
    @Published public var ambientLightSmoothingConstant: Double {
        didSet {
            defaults.set(
                ambientLightSmoothingConstant,
                forKey: Keys.ambientLightSmoothingConstant
            )
        }
    }
    
    /// When reverting from Dark Mode to Light Mode, the ambient light level must be
    /// above the user's `darknessThreshold` plus this additional threshold,
    /// in order to prevent frequent changes when at the edge of the transition.
    @Published public var extraThresholdBeforeRevertingToLightMode: Double {
        didSet {
            defaults.set(
                extraThresholdBeforeRevertingToLightMode,
                forKey: Keys.extraThresholdBeforeRevertingToLightMode
            )
        }
    }
    
    // MARK: - Launch at login
    
    /// Checks whether the app is currently registered to launch at login.
    /// On macOS 13+ we use the modern SMAppService API (the "new fax machine").
    /// On older systems we fall back to the legacy SharedFileList (the "old fax machine").
    private static var isAppInLoginItems: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return SharedFileList.sessionLoginItems().containsItem(Self.appURL)
        }
    }
    
    private func updateLaunchAtLoginEnabled() {
        isLaunchAtLoginEnabled = Self.isAppInLoginItems
    }
    
    private static var appURL: URL { Bundle.main.bundleURL }
    
    @Published public var isLaunchAtLoginEnabled: Bool {
        didSet {
            guard !isPreviewing else { return }

            guard isLaunchAtLoginEnabled != oldValue else { return }

            if isLaunchAtLoginEnabled {
                if #available(macOS 13.0, *) {
                    // Modern API: register with the system's login items service.
                    try? SMAppService.mainApp.register()
                } else {
                    SharedFileList.sessionLoginItems().addItem(Self.appURL)
                }
            } else {
                if #available(macOS 13.0, *) {
                    // Modern API: remove from the system's login items service.
                    try? SMAppService.mainApp.unregister()
                } else {
                    SharedFileList.sessionLoginItems().removeItem(Self.appURL)
                }
            }
        }
    }
    
}

fileprivate extension UserDefaults {
    func optionalDoubleValue(forKey key: String) -> Double? {
        guard let number = object(forKey: key) as? NSNumber else { return nil }
        return number.doubleValue
    }
}
