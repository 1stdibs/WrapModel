//
//  WrapModelLock.swift
//  1stdibs
//
//  Created by Ken Worley on 1/3/19.
//  Copyright © 2019 1stdibs. All rights reserved.
//

import Foundation
import os

public final class WrapModelLock {

    private let lock: OSAllocatedUnfairLock<Int>
    
    // MARK: - Initializer
    
    public init() {
        self.lock = OSAllocatedUnfairLock(initialState: 0)
    }

    // MARK: - Generic Swift API

    /// Executes the reading closure while holding the unfair lock.
    /// Returns any value calculated or extracted inside the closure.
    public func reading<R>(_ block: ()->R) -> R {
        lock.withLock { _ in
            block()
        }
    }

    /// Executes the writing closure while holding the unfair lock for exclusive access.
    public func writing(_ block: ()->Void) {
        lock.withLock { _ in
            block()
        }
    }
}
