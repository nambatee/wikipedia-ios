//
//  Cancellable.swift
//  Wikipedia
//
//  Created by Brian Gerstle on 6/23/15.
//

import Foundation

@objc
public protocol Cancellable {
    func cancel() -> Void
}

extension NSOperation: Cancellable {}

extension NSURLConnection: Cancellable {}

extension NSURLSessionTask: Cancellable {}
