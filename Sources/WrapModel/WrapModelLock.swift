//
//  WrapModelLock.swift
//  1stdibs
//
//  Created by Ken Worley on 1/3/19.
//  Copyright © 2019 1stdibs. All rights reserved.
//

import Foundation


public final class WrapModelLock {
    private let queue:DispatchQueue
    
    init() {
        queue = DispatchQueue(label: "WrapModel cache", qos: .userInitiated, attributes: .concurrent)
    }
    
    func reading<T>(_ block:()->T) -> T {
        return queue.sync {
            return block()
        }
    }
    
    func writing(_ block:()->Void) {
        queue.sync(flags: .barrier) {
            block()
        }
    }
}
