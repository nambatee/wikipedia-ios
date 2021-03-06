import Foundation

public enum ImageOrigin: Int {
    case network = 0
    case disk = 1
    case memory = 2
    case unknown = 3
}

extension ImageOrigin {
    public var debugColor: UIColor {
        switch self {
        case .network:
            return UIColor.red
        case .disk:
            return UIColor.yellow
        case .memory:
            return UIColor.green
        case .unknown:
            return UIColor.black
        }
    }
}

public protocol ImageOriginConvertible {
    func asImageOrigin() -> ImageOrigin
}


public func asImageOrigin<T: ImageOriginConvertible>(_ c: T) -> ImageOrigin { return c.asImageOrigin() }

@objc(WMFImageDownload) open class ImageDownload: NSObject {
    // Exposing enums as string constants for ObjC compatibility
    open static let imageOriginNetwork = ImageOrigin.network.rawValue
    open static let imageOriginDisk = ImageOrigin.disk.rawValue
    open static let imageOriginMemory = ImageOrigin.memory.rawValue
    open static let imageOriginUnknown = ImageOrigin.unknown.rawValue
    
    open var url: URL
    open var image: UIImage
    open var origin: ImageOrigin
    open var data: Data?
    
    public init(url: URL, image: UIImage, origin: ImageOrigin, data: Data?) {
        self.url = url
        self.image = image
        self.origin = origin
        self.data = data
    }

    public init(url: URL, image: UIImage, originRawValue: Int, data: Data?) {
        self.url = url
        self.image = image
        self.origin = ImageOrigin(rawValue: originRawValue)!
        self.data = data
    }
}
