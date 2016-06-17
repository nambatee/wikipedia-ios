//
//  WMFLegacyImageDataMigration.swift
//  Wikipedia
//
//  Created by Brian Gerstle on 7/6/15.
//  Copyright (c) 2015 Wikimedia Foundation. All rights reserved.
//

import Foundation
import PromiseKit
import CocoaLumberjackSwift


enum LegacyImageDataMigrationError : CancellableErrorType {
    case Deinit

    var cancelled: Bool {
        return true
    }
}

/// Migrate legacy image data for saved pages into WMFImageController.
@objc
public class WMFLegacyImageDataMigration : NSObject {
    /// Image controller where data will be migrated.
    let imageController: WMFImageController

    /// Data store which provides articles and saves the entries after processing.
    let legacyDataStore: MWKDataStore

//    /// Background task manager which invokes the receiver's methods to migrate image data in the background.
//    private lazy var backgroundTaskManager: WMFBackgroundTaskManager<MWKSavedPageEntry> = {
//        
//        let next =  { [weak self] () -> MWKSavedPageEntry? in
//            return self?.unmigratedEntry()
//        }
//        
//        let processor =  { [weak self] (entry: MWKSavedPageEntry, failure: (ErrorType) -> Void, completion: () -> Void) in
//            self?.migrateEntry(entry, completion: completion)
//        }
//        
//        let finalize = { [weak self] (failure: (ErrorType) -> Void, completion: () -> Void) in
//            
//        }
//        
//        WMFBackgroundTaskManager(next: next, processor: processor, finalize: finalize)
//    }()

    /// Initialize a new migrator.
    public required init(imageController: WMFImageController = WMFImageController.sharedInstance(),
                         legacyDataStore: MWKDataStore) {
        self.imageController = imageController
        self.legacyDataStore = legacyDataStore
        super.init()
    }

    public func setupAndStart(failure: (ErrorType) -> Void, completion: () -> Void) {
        completion()
        //self.backgroundTaskManager.start(failure, completion: completion)
    }

    /// MARK: - Testable Methods

    func save() -> Promise<Void> {
        return firstly {
            return legacyDataStore.userDataStore.savedPageList.save()
        }.asVoid()
    }

    func unmigratedEntry() -> MWKSavedPageEntry? {
        var entry: MWKSavedPageEntry?
        let getUnmigratedEntry = {
            let allEntries = self.legacyDataStore.userDataStore.savedPageList.entries as! [MWKSavedPageEntry]
            entry = allEntries.filter() { $0.didMigrateImageData == false }.first
        }
        if NSThread.isMainThread() {
            getUnmigratedEntry()
        } else {
            dispatch_sync(dispatch_get_main_queue(), getUnmigratedEntry)
        }
        return entry
    }

    /// Migrate all images in `entry` into `imageController`, then mark it as migrated.
    func migrateEntry(entry: MWKSavedPageEntry, completion: () -> Void){
        DDLogDebug("Migrating entry \(entry)")
        migrateAllImagesInArticleWithTitle(entry.title) { [weak self] in
            self?.markEntryAsMigrated(entry)
            completion()
        }
    }

    /// Move an article's images into `imageController`, ignoring any errors.
    func migrateAllImagesInArticleWithTitle(title: MWKTitle, completion: () -> Void) {
        let group = dispatch_group_create()
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
        
        if let images = legacyDataStore.existingArticleWithTitle(title)?.allImageURLs() {
            for url in images {
                dispatch_group_enter(group)
                dispatch_async(queue) { [weak self] in
                    guard let `self` = self else {
                        DDLogDebug("deinit error")
                        dispatch_group_leave(group)
                        return
                    }
                    let filepath = self.legacyDataStore.pathForImageData(url.absoluteString, title: title)
                    let failure = { (error: ErrorType) in
                        DDLogDebug("image migration error: \(error)")
                        dispatch_group_leave(group)
                    }
                    
                    let completion = { () in
                        dispatch_group_leave(group)
                    }
                    self.imageController.importImage(fromFile: filepath, withURL: url, failure: failure,completion: completion)
                }
            }
        }
        
        dispatch_async(queue) {
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            completion()
        }
    }

    /// Mark the given entry as having its image data migrated.
    func markEntryAsMigrated(entry: MWKSavedPageEntry) {
        legacyDataStore.userDataStore.savedPageList.markImageDataAsMigratedForEntryWithTitle(entry.title)
    }
}