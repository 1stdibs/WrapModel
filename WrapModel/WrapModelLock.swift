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
        queue = WrapModelDispatchQueueRecycler.queue()
    }
    
    deinit {
        WrapModelDispatchQueueRecycler.recycle(queue: queue)
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

/// A private class used to manage a pool of recycled WrapModelLocks
fileprivate class WrapModelDispatchQueueRecycler {
    private static var queuePool = [DispatchQueue]()
    private static let poolLock = DispatchQueue(label: "WrapModelDispatchQueueRecycler pool")
    #if DEBUG
    private static var queuesCreated = 0
    private static var activeQueues = 0
    #endif
    
    fileprivate class func queue() -> DispatchQueue {
        return poolLock.sync {
            #if DEBUG
            activeQueues += 1
            #endif
            let q:DispatchQueue
            if !queuePool.isEmpty {
                q = queuePool.removeLast()
            } else {
                #if DEBUG
                queuesCreated += 1
                #endif
                q = DispatchQueue(label: "WrapModel cache", qos: .userInitiated, attributes: .concurrent)
            }
            #if DEBUG
//            print("WrapModel lock recycler: \(activeQueues) active queues of total \(queuesCreated) created")
            #endif
            return q
        }
    }
    
    fileprivate class func recycle(queue:DispatchQueue) {
        poolLock.sync {
            #if DEBUG
            activeQueues -= 1
//            print("WrapModel lock recycler: \(activeQueues) active queues of total \(queuesCreated) created")
            #endif
            queuePool.append(queue)
        }
    }
}

