import MapKit
import Mapbox

extension Array { // seems you can no longer do extension [CLLocationCoordinate2D] ?
    var wmf_boundingRegion: MGLCoordinateRegion {
        get {
            var rect: MKMapRect?
            
            for element in self {
                guard let coordinate = element as? CLLocationCoordinate2D else {
                    continue
                }
                let point = MKMapPointForCoordinate(coordinate)
                let size = MKMapSize(width: 0, height: 0)
                let coordinateRect = MKMapRect(origin: point, size: size)
                guard let currentRect = rect else {
                    rect = coordinateRect
                    continue
                }
                rect = MKMapRectUnion(currentRect, coordinateRect)
            }
            
            guard let finalRect = rect else {
                return MGLCoordinateRegion()
            }
            
            let mkRegion = MKCoordinateRegionForMapRect(finalRect)
            var region = MGLCoordinateRegion(center: mkRegion.center, span: MGLCoordinateSpan(latitudeDelta: mkRegion.span.latitudeDelta, longitudeDelta: mkRegion.span.longitudeDelta))
            let adjustedLatitudeDelta = 1.3*region.span.latitudeDelta
            let adjustedLongitudeDelta = 1.3*region.span.longitudeDelta
            region.span.latitudeDelta = adjustedLatitudeDelta > 0.1 ? adjustedLatitudeDelta : 0.1 //max( is complaining about an extra param for some reason?
            region.span.longitudeDelta = adjustedLongitudeDelta > 0.1 ? adjustedLongitudeDelta : 0.1
            return region
        }
    }
}

