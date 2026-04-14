//
//  LADMSystemAppearanceSwitcher.swift
//  LADMCore
//
//  Created by Guilherme Rambo on 23/02/21.
//

import Cocoa
import Combine
import OSLog

public final class LADMSystemAppearanceSwitcher: ObservableObject {
    
    enum Appearance: Int32, CustomStringConvertible {
        case light
        case dark
        
        var description: String {
            switch self {
            case .dark:  return "Dark"
            case .light: return "Light"
            }
        }
        
        static var current: Appearance { Appearance(rawValue: SLSGetAppearanceThemeLegacy()) ?? .light }
    }
    
    private let log = Logger(subsystem: kLADMCoreSubsystemName, category: String(describing: LADMSystemAppearanceSwitcher.self))
    
    let settings: LADMSettings
    let reader: LADMAmbientLightSensorReader
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(settings: LADMSettings,
                reader: LADMAmbientLightSensorReader = LADMAmbientLightSensorReader(frequency: .fast))
    {
        self.settings = settings
        self.reader = reader
    }
    
    public func activate() {
        reader.$ambientLightValue.sink { [weak self] newValue in
            self?.ambientLightChanged(to: newValue)
        }.store(in: &cancellables)
        
        settings.$darknessThresholdIntervalInSeconds.sink { [weak self] _ in
            self?.reset()
        }.store(in: &cancellables)
        
        settings.$darknessThreshold.sink { [weak self] _ in
            self?.reset()
        }.store(in: &cancellables)
        
        setupUpdateAppearanceOnWake()
        reader.activate()
    }
    
    private func setupUpdateAppearanceOnWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.attemptAppearanceChangeOnWake()
            }
        }
    }
    
    private func attemptAppearanceChangeOnWake() {
        guard settings.isImmediateChangeOnComputerWakeEnabled else { return }
        reader.update()
        // Capture into locals so Swift 6 closure capture rules are satisfied
        let lightValue = reader.ambientLightValue
        log.debug("attemptAppearanceChangeOnWake \(lightValue)")
        if lightValue < settings.darknessThreshold {
            changeSystemAppearance(to: .dark)
        } else {
            changeSystemAppearance(to: .light)
        }
    }
    
    private func reset() {
        candidateAppearance = nil
        cancelScheduledApperanceChange()
        evaluateAmbientLight(with: reader.ambientLightValue)
    }
    
    private var candidateAppearance: Appearance?
    private var changeAppearanceWorkItem: DispatchWorkItem?
    
    private func ambientLightChanged(to value: Double) {
        guard abs(value - reader.ambientLightValue) > settings.ambientLightSmoothingConstant else { return }
        log.debug("ambientLightChanged \(value)")
        evaluateAmbientLight(with: value)
    }
    
    private func cancelScheduledApperanceChange() {
        guard changeAppearanceWorkItem != nil else { return }
        changeAppearanceWorkItem?.cancel()
        changeAppearanceWorkItem = nil
        log.debug("Cancelled scheduled appearance change")
    }
    
    private func evaluateAmbientLight(with value: Double) {
        #if DEBUG
        log.debug("evaluateAmbientLight \(value)")
        #endif
        
        guard value != -1 else { return }
        
        let newAppearance: Appearance
        if value < settings.darknessThreshold {
            newAppearance = .dark
        } else {
            if Appearance.current == .dark {
                guard value > (settings.darknessThreshold + settings.extraThresholdBeforeRevertingToLightMode) else { return }
            }
            newAppearance = .light
        }
        
        guard newAppearance != candidateAppearance else { return }
        candidateAppearance = newAppearance
        
        cancelScheduledApperanceChange()
        guard newAppearance != .current else { return }
        
        log.debug("New candidate appearance: \(newAppearance.description)")
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.changeSystemAppearance(to: newAppearance)
        }
        changeAppearanceWorkItem = workItem
        
        let interval = settings.darknessThresholdIntervalInSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
        
        // Capture values into locals so Swift 6 closure-capture rules are satisfied
        let desc     = newAppearance.description
        let future   = Date().addingTimeInterval(interval).description
        log.debug("Scheduled change to \(desc) at \(future), interval=\(interval)")
    }
    
    private func changeSystemAppearance(to newAppearance: Appearance) {
        guard newAppearance != .current else { return }
        
        if settings.isDisableAppearanceChangeInClamshellModeEnabled {
            guard !ClamshellStateChecker.isClamshellClosed() else {
                log.debug("Skipping: Mac is in clamshell mode")
                return
            }
        }
        
        log.debug("changeSystemAppearance \(newAppearance.description)")
        
        guard settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled else {
            log.debug("Automatic appearance change disabled in settings")
            return
        }
        
        SLSSetAppearanceThemeLegacy(newAppearance.rawValue)
    }
}
