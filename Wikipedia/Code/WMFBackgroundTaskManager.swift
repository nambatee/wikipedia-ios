//
//  WMFBackgroundTaskManager.swift
//  Wikipedia
//
//  Created by Brian Gerstle on 7/6/15.
//  Copyright (c) 2015 Wikimedia Foundation. All rights reserved.
//

import Foundation

enum BackgroundTaskError : CancellableErrorType {
    case Deinit
    case TaskExpired
    case InvalidTask

    var cancelled: Bool {
        get {
            switch(self) {
            case .Deinit, .TaskExpired:
                return true
            case .InvalidTask:
                return false
            }
        }
    }
}

/// Serially process items returned by a function, managing a background task for each one.
public class WMFBackgroundTaskManager<T> {
    /**
    * Function called to retrieve the next item for processing.
    *
    * Returns: The next item to process, or `nil` if there aren't any items left to process.
    */
    private let next: ()->T?

    /**
    * Function called to process items. Call completion when processing completes
    */
    private let processor: (T, failure: (ErrorType) -> Void, completion: () -> Void) -> Void

    /**
    * Function called when the manager stops processing tasks, e.g. to do any necessary clean up work.
    *
    * This can be called after either:
    * - All items have been processed successfully
    * - One of the items failed to process, canceling all further processing
    * - One of the tasks' expiration handlers was invoked, canceling all further processing.
    */
    private let finalize: (failure: (ErrorType) -> Void, completion: () -> Void) -> Void

    /**
    * Dispatch queue where all of the above functions will be invoked.
    *
    * Defaults to the global queue with "background" priority.
    */
    private let queue: dispatch_queue_t

    /**
    * Initialize a new background task manager with the given functions and queue.
    *
    * See documentation for the corresponding properties.
    */
    public required init(next: ()->T?,
                         processor: (T, failure: (ErrorType) -> Void, completion: () -> Void) -> Void,
                         finalize: (failure: (ErrorType) -> Void, completion: () -> Void) -> Void,
                         queue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            self.next = next
            self.processor = processor
            self.finalize = finalize
            self.queue = queue
    }

    deinit {
    }

    /**
    * Start background tasks asynchronously.
    *
    */
    
    public func start (failure: (ErrorType) -> Void, completion: () -> Void) -> Void {
        // recursively process items until all are done or one fails
        dispatch_async(queue) {
            self.processNext(failure, completion: completion)
        }

    }

    private func processNext(failure: (ErrorType) -> Void, completion: () -> Void) {
        if let nextItem = next() {
            let processFailure = { [weak self] (error: ErrorType) -> Void in
                self?.finalize(failure: failure, completion: completion)
            }
            let processCompletion = { [weak self] () -> Void in
                self?.processNext(failure, completion: completion)
            }
            self.processNextItem(nextItem, failure: processFailure, completion: processCompletion)
        } else {
            completion()
        }
    }
    
    /// Start a background task and process `nextItem`, then invoke `processNext()` to continue recursive processing.
    private func processNextItem(nextItem: T, failure: (ErrorType) -> Void, completion: () -> Void) {
       
        // start a new background task, which will represent this "link" in the promise chain
        let taskId = self.dynamicType.startTask() {
            // if we run out of time, cancel this (and subsequent) tasks
            failure(BackgroundTaskError.TaskExpired)
        }

        // couldn't obtain valid taskID, don't process any more objects
        guard taskId != UIBackgroundTaskInvalid else {
            // stop immediately if we cannot get a valid task
            failure(BackgroundTaskError.InvalidTask)
            return
        }

        // grab ref to polymorphic stopTask function (mocked during testing)
        let stopTask = self.dynamicType.stopTask
        
        
        let always = {
            stopTask(taskId)
        }
        let combinedFailure = { (error: ErrorType) -> Void in
            always()
            failure(error)
        }
        let combinedCompletion = { () -> Void in
            always()
            completion()
        }
        processor(nextItem, failure: combinedFailure, completion: combinedCompletion)
    }

    // MARK: - Background Task Wrappers

    /// Create a background task (modified during testing).
    internal class func startTask(expirationHandler: ()->Void) -> UIBackgroundTaskIdentifier {
        return UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler(expirationHandler)
    }

    /// Stop a background task (modified during testing).
    internal class func stopTask(task: UIBackgroundTaskIdentifier) {
        UIApplication.sharedApplication().endBackgroundTask(task)
    }
}
