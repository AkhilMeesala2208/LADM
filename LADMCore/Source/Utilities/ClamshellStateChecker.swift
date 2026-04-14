//
//  ClamshellStateChecker.swift
//  LADMCore
//
//  Created by Guilherme Rambo on 25/02/21.
//

import Foundation

final class ClamshellStateChecker {
    
    static func isClamshellClosed() -> Bool {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState  | head -1"]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        // process.launch() was deprecated. process.run() is the modern replacement.
        // It also throws on failure rather than crashing, which is safer.
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        return String(decoding: data, as: UTF8.self).contains("Yes")
    }
    
}
