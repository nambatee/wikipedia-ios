import Foundation
import CocoaLumberjackSwift
import ImageIO

@objc(WMFImageControllerError) public enum ImageControllerError: Int, Error {
    case dataNotFound
    case invalidOrEmptyURL
    case invalidImageCache
    case invalidResponse
    case duplicateRequest
    case fileError
    case dbError
    case `deinit`
}

@objc(WMFTypedImageData)
open class TypedImageData: NSObject {
    open let data:Data?
    open let MIMEType:String?
    
    public init(data data_: Data?, MIMEType type_: String?) {
        data = data_
        MIMEType = type_
    }
}

fileprivate extension Error {
    var isCancellationError: Bool {
        get {
            let potentialCancellationError = self as NSError
            return potentialCancellationError.domain == NSURLErrorDomain && potentialCancellationError.code == NSURLErrorCancelled
        }
    }
}

let WMFExtendedFileAttributeNameMIMEType = "org.wikimedia.MIMEType"

@objc(WMFImageController)
open class ImageController : NSObject {
    // MARK: - Initialization
    
    @objc(sharedInstance) public static let shared: ImageController = {
        let session = URLSession.shared
        let cache = URLCache.shared
        let fileManager = FileManager.default
        var permanentStorageDirectory = fileManager.wmf_containerURL().appendingPathComponent("Permanent Image Cache", isDirectory: true)
        var didGetDirectoryExistsError = false
        do {
            try fileManager.createDirectory(at: permanentStorageDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            DDLogError("Error creating permanent cache: \(error)")
        }
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try permanentStorageDirectory.setResourceValues(values)
        } catch let error {
            DDLogError("Error excluding from backup: \(error)")
        }
        return ImageController(session: session, cache: cache, fileManager: fileManager, permanentStorageDirectory: permanentStorageDirectory)
    }()
    
    
    public static func temporaryController() -> ImageController {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let imageControllerDirectory = temporaryDirectory.appendingPathComponent("ImageController-" + UUID().uuidString)
        let config = URLSessionConfiguration.default
        let cache = URLCache(memoryCapacity: 1000000000, diskCapacity: 1000000000, diskPath: imageControllerDirectory.path)
        config.urlCache = cache
        let session = URLSession(configuration: config)
        let fileManager = FileManager.default
        let permanentStorageDirectory = imageControllerDirectory.appendingPathComponent("Permanent Image Cache", isDirectory: true)
        do {
            try fileManager.createDirectory(at: permanentStorageDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            DDLogError("Error creating permanent cache: \(error)")
        }
        return ImageController(session: session, cache: cache, fileManager: fileManager, permanentStorageDirectory: permanentStorageDirectory)
    }
    
    
    fileprivate let session: URLSession
    fileprivate let cache: URLCache
    fileprivate let permanentStorageDirectory: URL
    fileprivate let managedObjectContext: NSManagedObjectContext
    fileprivate let persistentStoreCoordinator: NSPersistentStoreCoordinator
    fileprivate let fileManager: FileManager
    fileprivate let memoryCache: NSCache<NSString, UIImage>
    
    fileprivate var permanentCacheCompletionManager = ImageControllerCompletionManager<ImageControllerPermanentCacheCompletion>()
    fileprivate var dataCompletionManager = ImageControllerCompletionManager<ImageControllerDataCompletion>()
    
    public required init(session: URLSession, cache: URLCache, fileManager: FileManager, permanentStorageDirectory: URL) {
        self.session = session
        self.cache = cache
        self.fileManager = fileManager
        self.permanentStorageDirectory = permanentStorageDirectory
        memoryCache = NSCache<NSString, UIImage>()
        memoryCache.totalCostLimit = 10000000 //pixel count
        let bundle = Bundle(identifier: "org.wikimedia.WMF")!
        let modelURL = bundle.url(forResource: "Cache", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        let containerURL = permanentStorageDirectory
        let dbURL = containerURL.appendingPathComponent("Cache.sqlite", isDirectory: false)
        let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options = [NSMigratePersistentStoresAutomaticallyOption: NSNumber(booleanLiteral: true), NSInferMappingModelAutomaticallyOption: NSNumber(booleanLiteral: true)]
        do {
            try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
        } catch {
            do {
                try FileManager.default.removeItem(at: dbURL)
            } catch {
                
            }
            do {
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
            } catch {
                abort()
            }
        }
        persistentStoreCoordinator = psc
        managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        super.init()
    }
    
    
    fileprivate func cacheKeyForURL(_ url: URL) -> String {
        guard let host = url.host, let imageName = WMFParseImageNameFromSourceURL(url) else {
            return url.absoluteString.precomposedStringWithCanonicalMapping
        }
        return (host + "__" + imageName).precomposedStringWithCanonicalMapping
    }
    
    fileprivate func variantForURL(_ url: URL) -> Int64 { // A return value of 0 indicates the original size
        let sizePrefix = WMFParseSizePrefixFromSourceURL(url)
        return Int64(sizePrefix == NSNotFound ? 0 : sizePrefix)
    }
    
    fileprivate func identifierForURL(_ url: URL) -> String {
        let key = cacheKeyForURL(url)
        let variant = variantForURL(url)
        return "\(key)__\(variant)".precomposedStringWithCanonicalMapping
    }
    
    fileprivate func identifierForKey(_ key: String, variant: Int64) -> String {
        return "\(key)__\(variant)".precomposedStringWithCanonicalMapping
    }
    
    fileprivate func permanentCacheFileURL(key: String, variant: Int64) -> URL {
        let identifier = identifierForKey(key, variant: variant)
        return self.permanentStorageDirectory.appendingPathComponent(identifier, isDirectory: false)
    }
    
    fileprivate func fetchCacheItem(key: String, variant: Int64, moc: NSManagedObjectContext) -> CacheItem? {
        let itemRequest: NSFetchRequest<CacheItem> = CacheItem.fetchRequest()
        itemRequest.predicate = NSPredicate(format: "key == %@ && variant == %lli", key, variant)
        itemRequest.fetchLimit = 1
        do {
            let items = try moc.fetch(itemRequest)
            return items.first
        } catch let error {
            DDLogError("Error fetching cache item: \(error)")
        }
        return nil
    }
    
    fileprivate func fetchCacheGroup(key: String, moc: NSManagedObjectContext) -> CacheGroup? {
        let groupRequest: NSFetchRequest<CacheGroup> = CacheGroup.fetchRequest()
        groupRequest.predicate = NSPredicate(format: "key == %@", key)
        groupRequest.fetchLimit = 1
        do {
            let groups = try moc.fetch(groupRequest)
            return groups.first
        } catch let error {
            DDLogError("Error fetching cache group: \(error)")
        }
        return nil
    }
    
    fileprivate func createCacheItem(key: String, variant: Int64, moc: NSManagedObjectContext) -> CacheItem? {
        guard let entity = NSEntityDescription.entity(forEntityName: "CacheItem", in: moc) else {
            return nil
        }
        let item = CacheItem(entity: entity, insertInto: moc)
        item.key = key
        item.variant = variant
        item.date = NSDate()
        return item
    }
    
    fileprivate func createCacheGroup(key: String, moc: NSManagedObjectContext) -> CacheGroup? {
        guard let entity = NSEntityDescription.entity(forEntityName: "CacheGroup", in: moc) else {
            return nil
        }
        let group = CacheGroup(entity: entity, insertInto: moc)
        group.key = key
        return group
    }
    
    fileprivate func fetchOrCreateCacheItem(key: String, variant: Int64, moc: NSManagedObjectContext) -> CacheItem? {
        return fetchCacheItem(key: key, variant: variant, moc:moc) ?? createCacheItem(key: key, variant: variant, moc: moc)
    }
    
    fileprivate func fetchOrCreateCacheGroup(key: String, moc: NSManagedObjectContext) -> CacheGroup? {
        return fetchCacheGroup(key: key, moc: moc) ?? createCacheGroup(key: key, moc: moc)
    }
    
    
    fileprivate func save(moc: NSManagedObjectContext) {
        guard moc.hasChanges else {
            return
        }
        do {
            try moc.save()
        } catch let error {
            DDLogError("Error saving cache moc: \(error)")
        }
    }
    
    fileprivate func updateCachedFileMimeTypeAtPath(_ path: String, toMIMEType MIMEType: String?) {
        if let MIMEType = MIMEType {
            do {
                try self.fileManager.wmf_setValue(MIMEType, forExtendedFileAttributeNamed: WMFExtendedFileAttributeNameMIMEType, forFileAtPath: path)
            } catch let error {
                DDLogError("Error setting extended file attribute for MIME Type: \(error)")
            }
        }
    }
    
    public func permanentlyCache(url: URL, groupKey: String, priority: Float = 0, failure: @escaping (Error) -> Void, success: @escaping () -> Void) {
        let key = self.cacheKeyForURL(url)
        let variant = self.variantForURL(url)
        let identifier = self.identifierForKey(key, variant: variant)
        let completion = ImageControllerPermanentCacheCompletion(success: success, failure: failure)
        guard permanentCacheCompletionManager.add(completion, forIdentifier: identifier) else {
            return
        }
        let moc = self.managedObjectContext
        moc.perform {
            if let item = self.fetchCacheItem(key: key, variant: variant, moc: moc) {
                if let group = self.fetchOrCreateCacheGroup(key: groupKey, moc: moc) {
                    group.addToCacheItems(item)
                }
                self.save(moc: moc)
                self.permanentCacheCompletionManager.complete(groupKey, identifier: identifier, enumerator: { (completion) in
                    completion.success()
                })
                return
            }
            let schemedURL = (url as NSURL).wmf_urlByPrependingSchemeIfSchemeless() as URL
            let task = self.session.downloadTask(with: schemedURL, completionHandler: { (fileURL, response, error) in
                guard !self.isCancellationError(error) else {
                    return
                }
                guard let fileURL = fileURL, let response = response else {
                    let err = error ?? ImageControllerError.invalidResponse
                    self.permanentCacheCompletionManager.complete(groupKey, identifier: identifier, enumerator: { (completion) in
                        completion.failure(err)
                    })
                    return
                }
                let permanentCacheFileURL = self.permanentCacheFileURL(key: key, variant: variant)
                var createItem = false
                do {
                    try self.fileManager.moveItem(at: fileURL, to: permanentCacheFileURL)
                    self.updateCachedFileMimeTypeAtPath(permanentCacheFileURL.path, toMIMEType: response.mimeType)
                    createItem = true
                } catch let error as NSError {
                    if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { // file exists
                        createItem = true
                    } else {
                        DDLogError("Error moving cached file: \(error)")
                    }
                } catch let error {
                    DDLogError("Error moving cached file: \(error)")
                }
                moc.perform {
                    guard createItem else {
                        self.permanentCacheCompletionManager.complete(groupKey, identifier: identifier, enumerator: { (completion) in
                            completion.failure(ImageControllerError.fileError)
                        })
                        return
                    }
                    guard let item = self.fetchOrCreateCacheItem(key: key, variant: variant, moc: moc), let group = self.fetchOrCreateCacheGroup(key: groupKey, moc: moc) else {
                        self.permanentCacheCompletionManager.complete(groupKey, identifier: identifier, enumerator: { (completion) in
                            completion.failure(ImageControllerError.dbError)
                        })
                        return
                    }
                    group.addToCacheItems(item)
                    self.save(moc: moc)
                    self.permanentCacheCompletionManager.complete(groupKey, identifier: identifier, enumerator: { (completion) in
                        completion.success()
                    })
                }
            })
            task.priority = priority
            self.permanentCacheCompletionManager.add(task, forGroup: groupKey, identifier: identifier)
            task.resume()
        }
    }
    
    public func permanentlyCacheInBackground(urls: [URL], groupKey: String,  failure: @escaping (Error) -> Void, success: @escaping () -> Void) {
        let cacheGroup = WMFTaskGroup()
        var errors = [NSError]()
        
        for url in urls {
            cacheGroup.enter()
            
            let failure = { (error: Error) in
                errors.append(error as NSError)
                cacheGroup.leave()
            }
            
            let success = {
                cacheGroup.leave()
            }
            
            permanentlyCache(url: url, groupKey: groupKey, failure: failure, success: success)
        }
        cacheGroup.waitInBackground {
            if let error = errors.first {
                failure(error)
            } else {
                success()
            }
        }
    }
    
    public func removePermanentlyCachedImages(groupKey: String, completion: @escaping () -> Void) {
        let moc = self.managedObjectContext
        let fm = self.fileManager
        moc.perform {
            self.permanentCacheCompletionManager.cancel(group: groupKey)
            guard let group = self.fetchCacheGroup(key: groupKey, moc: moc) else {
                return
            }
            for item in group.cacheItems ?? [] {
                guard let item = item as? CacheItem, let key = item.key, item.cacheGroups?.count == 1 else {
                    continue
                }
                do {
                    let fileURL = self.permanentCacheFileURL(key: key, variant: item.variant)
                    try fm.removeItem(at: fileURL)
                } catch let error {
                    DDLogError("Error removing from permanent cache: \(error)")
                }
                moc.delete(item)
            }
            moc.delete(group)
            self.save(moc: moc)
            completion()
        }
    }
    
    public func permanentlyCachedTypedDiskDataForImage(withURL url: URL?) -> TypedImageData {
        guard let url = url else {
            return TypedImageData(data: nil, MIMEType: nil)
        }
        let key = cacheKeyForURL(url)
        let variant = variantForURL(url)
        let fileURL = permanentCacheFileURL(key: key, variant: variant)
        let mimeType: String? = fileManager.wmf_value(forExtendedFileAttributeNamed: WMFExtendedFileAttributeNameMIMEType, forFileAtPath: fileURL.path)
        let data = fileManager.contents(atPath: fileURL.path)
        return TypedImageData(data: data, MIMEType: mimeType)
    }
    
    public func permanentlyCachedData(withURL url: URL) -> Data? {
        let key = cacheKeyForURL(url)
        let variant = variantForURL(url)
        let fileURL = permanentCacheFileURL(key: key, variant: variant)
        return fileManager.contents(atPath: fileURL.path)
    }
    
    public func sessionCachedData(withURL url: URL) -> Data? {
        let requestURL = (url as NSURL).wmf_urlByPrependingSchemeIfSchemeless()
        let request = URLRequest(url: requestURL as URL)
        guard let cachedResponse = URLCache.shared.cachedResponse(for: request) else {
            return nil
        }
        return cachedResponse.data
    }
    
    public func data(withURL url: URL) -> Data? {
        return sessionCachedData(withURL: url) ?? permanentlyCachedData(withURL: url)
    }
    
    public func memoryCachedImage(withURL url: URL) -> UIImage? {
        let identifier = identifierForURL(url) as NSString
        return memoryCache.object(forKey: identifier)
    }
    
    public func addToMemoryCache(_ image: UIImage, url: URL) {
        guard image.images == nil || image.images?.count == 1 else { // don't cache gifs
            return
        }
        let identifier = identifierForURL(url) as NSString
        memoryCache.setObject(image, forKey: identifier, cost: Int(image.size.width * image.size.height))
    }
    
    fileprivate func createImage(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let options = [kCGImageSourceShouldCache as String: NSNumber(value: true)] as CFDictionary
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        return image
    }
    
    fileprivate func createImage(fileURL: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let options = [kCGImageSourceShouldCache as String: NSNumber(value: true)] as CFDictionary
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        return image
    }
    
    public func permanentlyCachedImage(withURL url: URL) -> UIImage? {
        if let memoryCachedImage = memoryCachedImage(withURL: url) {
            return memoryCachedImage
        }
        let key = cacheKeyForURL(url)
        let variant = variantForURL(url)
        let fileURL = permanentCacheFileURL(key: key, variant: variant)
        guard let image = createImage(fileURL: fileURL) else {
            return nil
        }
        addToMemoryCache(image, url: url)
        return image
    }
    
    public func sessionCachedImage(withURL url: URL?) -> UIImage? {
        guard let url = url else {
            return nil
        }
        if let memoryCachedImage = memoryCachedImage(withURL: url) {
            return memoryCachedImage
        }
        guard let data = sessionCachedData(withURL: url) else {
            return nil
        }
        guard let image = createImage(data: data) else {
            return nil
        }
        addToMemoryCache(image, url: url)
        return image
    }
    
    public func cachedImage(withURL url: URL?) -> UIImage? {
        guard let url = url else {
            return nil
        }
        return sessionCachedImage(withURL: url) ?? permanentlyCachedImage(withURL: url)
    }
    
    fileprivate func isCancellationError(_ error: Error?) -> Bool {
        return error?.isCancellationError ?? false
    }
    
    public func fetchData(withURL url: URL?, priority: Float, failure: @escaping (Error) -> Void, success: @escaping (Data, URLResponse) -> Void) {
        guard let url = url else {
            failure(ImageControllerError.invalidOrEmptyURL)
            return
        }
        let identifier = identifierForURL(url)
        let completion = ImageControllerDataCompletion(success: success, failure: failure)
        guard dataCompletionManager.add(completion, forIdentifier: identifier) else {
            return
        }
        let schemedURL = (url as NSURL).wmf_urlByPrependingSchemeIfSchemeless() as URL
        let task = session.dataTask(with: schemedURL) { (data, response, error) in
            guard !self.isCancellationError(error) else {
                return
            }
            self.dataCompletionManager.complete(identifier, enumerator: { (completion) in
                guard let data = data, let response = response else {
                    completion.failure(error ?? ImageControllerError.invalidResponse)
                    return
                }
                completion.success(data, response)
            })
        }
        task.priority = priority
        dataCompletionManager.add(task, forIdentifier: identifier)
        task.resume()
    }
    
    public func fetchData(withURL url: URL?, failure: @escaping (Error) -> Void, success: @escaping (Data, URLResponse) -> Void) {
        fetchData(withURL: url, priority: 0.5, failure: failure, success: success)
    }
    
    public func fetchImage(withURL url: URL?, priority: Float, failure: @escaping (Error) -> Void, success: @escaping (ImageDownload) -> Void) {
        guard let url = url else {
            failure(ImageControllerError.invalidOrEmptyURL)
            return
        }
        if let memoryCachedImage = memoryCachedImage(withURL: url) {
            success(ImageDownload(url: url, image: memoryCachedImage, origin: .memory, data: nil))
            return
        }
        fetchData(withURL: url, priority: priority, failure: failure) { (data, response) in
            guard let image = self.createImage(data: data) else {
                failure(ImageControllerError.invalidResponse)
                return
            }
            self.addToMemoryCache(image, url: url)
            success(ImageDownload(url: url, image: image, origin: .unknown, data: data))
        }
    }
    
    public func fetchImage(withURL url: URL?, failure: @escaping (Error) -> Void, success: @escaping (ImageDownload) -> Void) {
        fetchImage(withURL: url, priority: 0.5, failure: failure, success: success)
    }
    
    public func cancelFetch(withURL url: URL?) {
        guard let url = url else {
            return
        }
        let identifier = identifierForURL(url)
        dataCompletionManager.cancel(identifier)
    }
    
    public func prefetch(withURL url: URL?) {
        prefetch(withURL: url) { }
    }
    
    public func prefetch(withURL url: URL?, completion: @escaping () -> Void) {
        guard let url = url, memoryCachedImage(withURL: url) == nil else {
            completion()
            return
        }
        fetchData(withURL: url, priority: 0, failure: { (error) in
            completion()
        }) { (data, response) in
            defer {
                completion()
            }
            guard let image = self.createImage(data: data) else {
                return
            }
            self.addToMemoryCache(image, url: url)
        }
    }
    
    public func deleteTemporaryCache() {
        cache.removeAllCachedResponses()
    }
    
    // MARK: - Migration from SDWebImage
    
    fileprivate var legacyCacheFolderURL: URL {
        get {
            return fileManager.wmf_containerURL().appendingPathComponent("Cache").appendingPathComponent("com.hackemist.SDWebImageCache.default")
        }
    }
    
    public func migrateLegacyImageURLs(_ imageURLs: [URL], intoGroup group: String, completion: @escaping () -> Void) {
        let moc = self.managedObjectContext
        let legacyCacheFolderURL = self.legacyCacheFolderURL
        let legacyCacheFolderPath = legacyCacheFolderURL.path
        moc.perform {
            let group = self.fetchOrCreateCacheGroup(key: group, moc: moc)
            for imageURL in imageURLs {
                let key = self.cacheKeyForURL(imageURL)
                let variant = self.variantForURL(imageURL)
                if let existingItem = self.fetchCacheItem(key: key, variant: variant, moc: moc) {
                    group?.addToCacheItems(existingItem)
                    continue
                }
                guard let legacyKey = (imageURL as NSURL).wmf_schemelessURLString(),
                    let legacyPath = WMFLegacyImageCache.cachePath(forKey: legacyKey, inPath: legacyCacheFolderPath) else {
                        continue
                }
                
                let fileURL = self.permanentCacheFileURL(key: key, variant: variant)
                let legacyFileURL = URL(fileURLWithPath: legacyPath, isDirectory: false)
                var createItem = false
                do {
                    try self.fileManager.moveItem(at: legacyFileURL, to: fileURL)
                    createItem = true
                } catch let error as NSError {
                    if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { // file exists
                        createItem = true
                    } else {
                        DDLogError("Error moving cached file: \(error)")
                    }
                } catch let error {
                    DDLogError("Error moving cached file: \(error)")
                }
                guard createItem else {
                    continue
                }
                if let item = self.fetchOrCreateCacheItem(key: key, variant: variant, moc: moc) {
                    group?.addToCacheItems(item)
                }
            }
            self.save(moc: moc)
            completion()
        }
    }
    
    public func removeLegacyCache() {
        do {
            try fileManager.removeItem(at: legacyCacheFolderURL)
        } catch let error {
            DDLogError("Error migrating from legacy cache \(error)")
        }
    }
}
