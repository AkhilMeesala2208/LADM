//
//  LADMAmbientLightSensorReader.swift
//  LADMCore
//
//  Created by Guilherme Rambo on 23/02/21.
//

import Foundation
import Combine
import OSLog

public final class LADMAmbientLightSensorReader: ObservableObject {
    
    private let log = Logger(subsystem: kLADMCoreSubsystemName, category: String(describing: LADMAmbientLightSensorReader.self))
    
    public enum UpdateFrequency: TimeInterval {
        case realtime = 0.1
        case fast = 5
        case slow = 10
    }
    
    let sensor: LADMAmbientLightSensor
    
    public var isSensorReady: Bool { sensor.isPresent }
    
    @Published public var ambientLightValue: Double = 0
    
    private var sensorObservation: NSKeyValueObservation?
    
    public init(frequency: UpdateFrequency = .fast, sensor: LADMAmbientLightSensor = LADMAmbientLightSensor()) {
        self.sensor = sensor
        self.sensor.updateInterval = frequency.rawValue
        
        sensorObservation = sensor.observe(\.value, options: [.initial, .new, .old]) { [weak self] sensor, change in
            guard let self = self else { return }
            guard change.oldValue != change.newValue else { return }
            self.ambientLightValue = sensor.value
        }
    }
    
    public func activate() {
        // Capture function name into a local so Logger interpolation satisfies Swift 6 capture rules
        let fn = #function
        log.debug("\(fn)")
        sensor.activate()
    }
    
    public func invalidate() {
        let fn = #function
        log.debug("\(fn)")
        sensor.invalidate()
    }
    
    public func update() {
        sensor.update()
    }
    
    deinit { invalidate() }
    
}
