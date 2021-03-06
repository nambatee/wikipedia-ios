import UIKit
import MapKit
import WMF
import TUSafariActivity

class PlacesViewController: UIViewController, MKMapViewDelegate, UISearchBarDelegate, ArticlePopoverViewControllerDelegate, UITableViewDataSource, UITableViewDelegate, PlaceSearchSuggestionControllerDelegate, WMFLocationManagerDelegate, NSFetchedResultsControllerDelegate, UIPopoverPresentationControllerDelegate, EnableLocationViewControllerDelegate, ArticlePlaceViewDelegate, WMFAnalyticsViewNameProviding, ArticlePlaceGroupViewControllerDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var redoSearchButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var recenterOnUserLocationButton: UIButton!
    
    @IBOutlet weak var listAndSearchOverlayContainerView: UIView!
    @IBOutlet weak var listAndSearchOverlaySearchContainerView: RoundedCornerView!
    @IBOutlet weak var listAndSearchOverlaySearchBar: UISearchBar!
    @IBOutlet weak var listAndSearchOverlayBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var listAndSearchOverlayHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var listAndSearchOverlaySearchHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var listAndSearchOverlaySliderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var listAndSearchOverlaySearchCancelButtonHideConstraint: NSLayoutConstraint!
    @IBOutlet weak var listAndSearchOverlaySearchCancelButtonShowConstraint: NSLayoutConstraint!
    @IBOutlet weak var listAndSearchOverlaySliderView: RoundedCornerView!
    @IBOutlet weak var listView: UITableView!
    @IBOutlet weak var searchSuggestionView: UITableView!
    
    public var articleStore: WMFArticleDataStore!
    public var dataStore: MWKDataStore!

    private let locationSearchFetcher = WMFLocationSearchFetcher()
    private let searchFetcher = WMFSearchFetcher()
    private let previewFetcher = WMFArticlePreviewFetcher()
    private let wikidataFetcher = WikidataFetcher()
    private let locationManager = WMFLocationManager.fine()
    private let animationDuration = 0.6
    private let animationScale = CGFloat(0.6)
    private let popoverFadeDuration = 0.25
    private let searchHistoryCountLimit = 15
    private var searchSuggestionController: PlaceSearchSuggestionController!
    private var titleViewSearchBar: UISearchBar!
    private var searchBar: UISearchBar? {
        didSet {
            oldValue?.delegate = nil
            searchBar?.text = oldValue?.text
            searchBar?.delegate = self
        }
    }
    private var siteURL: URL = NSURL.wmf_URLWithDefaultSiteAndCurrentLocale()!
    private var segmentedControl: UISegmentedControl!
    private var segmentedControlBarButtonItem: UIBarButtonItem!
    private var closeBarButtonItem: UIBarButtonItem!
    private var currentGroupingPrecision: QuadKeyPrecision = 1
    private let searchHistoryGroup = "PlaceSearch"
    private var selectedArticlePopover: ArticlePopoverViewController?
    private var selectedArticleAnnotationView: MKAnnotationView?
    private var selectedArticleKey: String?
    private var articleKeyToSelect: String?
    private var currentSearchRegion: MKCoordinateRegion?
    private var performDefaultSearchOnNextMapRegionUpdate = false
    private var previouslySelectedArticlePlaceIdentifier: String?
    private var searching: Bool = false
    private let tracker = PiwikTracker.sharedInstance()
    private let mapTrackerContext: AnalyticsContext = "Places_map"
    private let listTrackerContext: AnalyticsContext = "Places_list"
    private let searchTrackerContext: AnalyticsContext = "Places_search"
    private let imageController = ImageController.shared
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        redoSearchButton.setTitle("    " + localizedStringForKeyFallingBackOnEnglish("places-search-this-area") + "    ", for: .normal)
        
        // Setup map view
        mapView.mapType = .standard
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.showsPointsOfInterest = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        
        // Setup location manager
        locationManager.delegate = self
        
        view.tintColor = .wmf_blueTint
        redoSearchButton.setTitleColor(view.tintColor, for: .normal)
        
        // Setup map/list toggle
        let map = #imageLiteral(resourceName: "places-map")
        let list = #imageLiteral(resourceName: "places-list")
        map.accessibilityLabel = localizedStringForKeyFallingBackOnEnglish("places-accessibility-show-as-map")
        list.accessibilityLabel = localizedStringForKeyFallingBackOnEnglish("places-accessibility-show-as-list")
        segmentedControl = UISegmentedControl(items: [map, list])
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(updateViewModeFromSegmentedControl), for: .valueChanged)
        segmentedControl.tintColor = .wmf_blueTint
        segmentedControlBarButtonItem = UIBarButtonItem(customView: segmentedControl)
        navigationItem.rightBarButtonItem = segmentedControlBarButtonItem
        
        let closeImage = #imageLiteral(resourceName: "close")
        closeBarButtonItem = UIBarButtonItem(image:  closeImage, style: .plain, target: self, action: #selector(closeSearch))
        closeBarButtonItem.accessibilityLabel = localizedStringForKeyFallingBackOnEnglish("places-accessibility-close-search")
        // Setup recenter button
        recenterOnUserLocationButton.accessibilityLabel = localizedStringForKeyFallingBackOnEnglish("places-accessibility-recenter-map-on-user-location")
        

        listAndSearchOverlaySearchContainerView.corners = [.topLeft, .topRight]
        listAndSearchOverlaySearchContainerView.radius = 5
        
        listAndSearchOverlaySliderView.corners = [.bottomLeft, .bottomRight]
        listAndSearchOverlaySliderView.radius = 5
        
        
        // Setup list view
        listView.dataSource = self
        listView.delegate = self
        listView.register(WMFNearbyArticleTableViewCell.wmf_classNib(), forCellReuseIdentifier: WMFNearbyArticleTableViewCell.identifier())
        listView.estimatedRowHeight = WMFNearbyArticleTableViewCell.estimatedRowHeight()
        
        // Setup search suggestions
        searchSuggestionController = PlaceSearchSuggestionController()
        searchSuggestionController.tableView = searchSuggestionView
        searchSuggestionController.delegate = self

        // Setup search bar
        let searchBarHeight: CGFloat = 32
        let searchBarLeftPadding: CGFloat = 7.5
        let searchBarRightPadding: CGFloat = 2.5
        titleViewSearchBar = UISearchBar(frame: CGRect(x: searchBarLeftPadding, y: 0, width: view.bounds.size.width - searchBarLeftPadding - searchBarRightPadding, height: 32))
        titleViewSearchBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: searchBarHeight))
        titleView.addSubview(titleViewSearchBar)
        navigationItem.titleView = titleView
        titleViewSearchBar.returnKeyType = .search
        titleViewSearchBar.searchBarStyle = .minimal
        
        listAndSearchOverlaySearchBar.returnKeyType = titleViewSearchBar.returnKeyType
        listAndSearchOverlaySearchBar.searchBarStyle = titleViewSearchBar.searchBarStyle
        
        searchBar = titleViewSearchBar
        
        viewMode = .map
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let defaults = UserDefaults.wmf_userDefaults()
        if !defaults.wmf_placesHasAppeared() {
            defaults.wmf_setPlacesHasAppeared(true)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        guard WMFLocationManager.isAuthorized() else {
            if !defaults.wmf_placesDidPromptForLocationAuthorization() {
                defaults.wmf_setPlacesDidPromptForLocationAuthorization(true)
                promptForLocationAccess()
            } else {
                performDefaultSearchOnNextMapRegionUpdate = currentSearch == nil
            }
            return
        }
        
        locationManager.startMonitoringLocation()
        mapView.showsUserLocation = true
        
        tracker?.wmf_logView(self)
        
        if isViewModeOverlay {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        locationManager.stopMonitoringLocation()
        mapView.showsUserLocation = false
    }
    
    // MARK: - MKMapViewDelegate
    
    private var isMovingToRegion = false
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        deselectAllAnnotations()
        isMovingToRegion = true
    }
    
    func selectVisibleArticle(articleKey: String) -> Bool {
        let annotations = mapView.annotations(in: mapView.visibleMapRect)
        for annotation in annotations {
            guard let place = annotation as? ArticlePlace,
                place.articles.count == 1,
                let article = place.articles.first,
                article.key == articleKey else {
                    continue
            }
            selectArticlePlace(place)
            return true
        }
        return false
    }

    func selectVisibleKeyToSelectIfNecessary() {
        guard !isMovingToRegion, countOfAnimatingAnnotations == 0, let keyToSelect = articleKeyToSelect else {
            return
        }
        guard selectVisibleArticle(articleKey: keyToSelect) else {
            return
        }
        articleKeyToSelect = nil

    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        _mapRegion = mapView.region
        guard performDefaultSearchOnNextMapRegionUpdate == false else {
            performDefaultSearchOnNextMapRegionUpdate = false
            performDefaultSearchIfNecessary(withRegion: nil)
            return
        }
        regroupArticlesIfNecessary(forVisibleRegion: mapView.region)

        showRedoSearchButtonIfNecessary(forVisibleRegion: mapView.region)
        
        isMovingToRegion = false
        
        selectVisibleKeyToSelectIfNecessary()
        
        updateShouldShowAllImagesIfNecessary()
    }
    
    func updateShouldShowAllImagesIfNecessary() {
        let visibleAnnotations = mapView.annotations(in: mapView.visibleMapRect)
        var visibleArticleCount = 0
        var visibleGroupCount = 0
        for annotation in visibleAnnotations {
            guard let place = annotation as? ArticlePlace else {
                continue
            }
            if place.articles.count == 1 {
                visibleArticleCount += 1
            } else {
                visibleGroupCount += 1
            }
        }
        let articlesPerSquarePixel = CGFloat(visibleArticleCount) / mapView.bounds.width * mapView.bounds.height
        let shouldShowAllImages = visibleGroupCount == 0 && visibleArticleCount > 0 && articlesPerSquarePixel < 40
        set(shouldShowAllImages: shouldShowAllImages)
    }
    
    func set(shouldShowAllImages: Bool) {
        if shouldShowAllImages != showingAllImages {
            for annotation in mapView.annotations {
                guard let view = mapView.view(for: annotation) as? ArticlePlaceView else {
                    continue
                }
                view.set(alwaysShowImage: shouldShowAllImages, animated: true)
            }
            showingAllImages = shouldShowAllImages
        }
    }

    var placeGroupVC: ArticlePlaceGroupViewController?
    var placeGroupAnnotationView: MKAnnotationView?
    
    func dismissGroup(andZoom: Bool) {
        dismissCurrentArticlePopover()
        guard let groupVC = placeGroupVC else {
            return
        }
        groupVC.hide {
            groupVC.willMove(toParentViewController: nil)
            groupVC.view.removeFromSuperview()
            groupVC.removeFromParentViewController()
            if andZoom {
                self.mapRegion = self.regionThatFits(articles: groupVC.articles)
            }
            self.placeGroupAnnotationView?.isHidden = false
            self.placeGroupVC = nil
            self.placeGroupAnnotationView = nil
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect annotationView: MKAnnotationView) {
        guard let place = annotationView.annotation as? ArticlePlace else {
            return
        }
        
        previouslySelectedArticlePlaceIdentifier = place.identifier
        
        guard place.articles.count == 1 else {
#if WMF_PLACES_GROUP_POPOVERS
            guard self.placeGroupVC == nil else {
                return
            }
            let placeGroupVC = ArticlePlaceGroupViewController(articles: place.articles)
            placeGroupVC.delegate = self
            placeGroupVC.view.tintColor = view.tintColor
            placeGroupVC.view.frame = view.bounds
            placeGroupVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            addChildViewController(placeGroupVC)
            view.insertSubview(placeGroupVC.view, aboveSubview: redoSearchButton)
            placeGroupVC.didMove(toParentViewController: self)
            
            
            let center = view.convert(annotationView.center, from: annotationView.superview)
            
            placeGroupVC.show(center: center)
        
            self.placeGroupVC = placeGroupVC
            annotationView.isHidden = true
            self.placeGroupAnnotationView = annotationView
            deselectAllAnnotations()
#else
            deselectAllAnnotations()
    
            var minDistance = CLLocationDistanceMax
            let center = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            for article in place.articles {
                guard let location = article.location else {
                    continue
                }
                let distance = location.distance(from: center)
                if distance < minDistance {
                    minDistance = distance
                    articleKeyToSelect = article.key
                }
            }
            mapRegion = regionThatFits(articles: place.articles)
#endif
            return
        }
        
        showPopover(forAnnotationView: annotationView)
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        selectedArticleKey = nil
        dismissCurrentArticlePopover()
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
    }
    
    var countOfAnimatingAnnotations = 0 {
        didSet {
            if countOfAnimatingAnnotations == 0 {
                selectVisibleKeyToSelectIfNecessary()
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        guard let place = annotation as? ArticlePlace else {
            // CRASH WORKAROUND 
            // The UIPopoverController that the map view presents from the default user location annotation is causing a crash. Using our own annotation view for the user location works around this issue.
            if let userLocation = annotation as? MKUserLocation {
                let userViewReuseIdentifier = "org.wikimedia.userLocationAnnotationView"
                let placeView = mapView.dequeueReusableAnnotationView(withIdentifier: userViewReuseIdentifier) as? UserLocationAnnotationView ?? UserLocationAnnotationView(annotation: userLocation, reuseIdentifier: userViewReuseIdentifier)
                placeView.annotation = userLocation
                return placeView
            }
            return nil
        }
        
        let reuseIdentifier = "org.wikimedia.articlePlaceView"
        var placeView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as! ArticlePlaceView?
        
        if placeView == nil {
            placeView = ArticlePlaceView(annotation: place, reuseIdentifier: reuseIdentifier)
        } else {
            placeView?.prepareForReuse()
            placeView?.annotation = place
        }
        
        placeView?.delegate = self
        
        if showingAllImages {
            placeView?.set(alwaysShowImage: true, animated: false)
        }
        
        if place.articles.count > 1 && place.nextCoordinate == nil {
            placeView?.alpha = 0
            placeView?.transform = CGAffineTransform(scaleX: animationScale, y: animationScale)
            dispatchOnMainQueue({
                self.countOfAnimatingAnnotations += 1
                UIView.animate(withDuration: self.animationDuration, delay: 0, options: .allowUserInteraction, animations: {
                    placeView?.transform = CGAffineTransform.identity
                    placeView?.alpha = 1
                }, completion: { (done) in
                    self.countOfAnimatingAnnotations -= 1
                })
            })
        } else if let nextCoordinate = place.nextCoordinate {
            placeView?.alpha = 0
            dispatchOnMainQueue({
                self.countOfAnimatingAnnotations += 1
                UIView.animate(withDuration: 2*self.animationDuration, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .allowUserInteraction, animations: {
                    place.coordinate = nextCoordinate
                }, completion: { (done) in
                    self.countOfAnimatingAnnotations -= 1
                })
                UIView.animate(withDuration: 0.5*self.animationDuration, delay: 0, options: .allowUserInteraction, animations: {
                    placeView?.alpha = 1
                }, completion: nil)
            })
        } else {
            placeView?.alpha = 0
            dispatchOnMainQueue({
                self.countOfAnimatingAnnotations += 1
                UIView.animate(withDuration: self.animationDuration, delay: 0, options: .allowUserInteraction, animations: {
                    placeView?.alpha = 1
                }, completion: { (done) in
                    self.countOfAnimatingAnnotations -= 1
                })
            })
        }
        
        return placeView
    }
    
    // MARK: - Keyboard
    
    func keyboardChanged(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let frameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else {
                return
        }
        let frame = frameValue.cgRectValue
        var inset = searchSuggestionView.contentInset
        inset.bottom = frame.size.height
        searchSuggestionView.contentInset = inset
    }
    
    // MARK: - Map Region
    
    private var _mapRegion: MKCoordinateRegion?
    
    private var mapRegion: MKCoordinateRegion? {
        set {
            guard let value = newValue else {
                _mapRegion = nil
                return
            }
            
            let region = mapView.regionThatFits(value)
            
            _mapRegion = region
            
            regroupArticlesIfNecessary(forVisibleRegion: region)
            showRedoSearchButtonIfNecessary(forVisibleRegion: region)
            
            
            let mapViewRegion = mapView.region
            guard mapViewRegion.center.longitude != region.center.longitude || mapViewRegion.center.latitude != region.center.latitude || mapViewRegion.span.longitudeDelta != region.span.longitudeDelta || mapViewRegion.span.latitudeDelta != region.span.latitudeDelta else {
                selectVisibleKeyToSelectIfNecessary()
                return
            }
            
            guard !isViewModeOverlay || overlayState == .min else {
                let factor = UIApplication.shared.wmf_isRTL ? 0.1 : -0.1
                let adjustedCenter = CLLocationCoordinate2DMake(region.center.latitude, region.center.longitude + factor * region.span.latitudeDelta)
                let adjustedRegion = MKCoordinateRegionMake(adjustedCenter, region.span)
                mapView.setRegion(adjustedRegion, animated: true)
                return
            }

            mapView.setRegion(region, animated: true)
        }
        
        get {
            return _mapRegion
        }
    }
    
    func regionThatFits(articles: [WMFArticle]) -> MKCoordinateRegion {
        let coordinates: [CLLocationCoordinate2D] =  articles.flatMap({ (article) -> CLLocationCoordinate2D? in
            return article.coordinate
        })
        return coordinates.wmf_boundingRegion
    }
    
    // MARK: - Searching
    
    var currentSearch: PlaceSearch? {
        didSet {
            guard let search = currentSearch else {
                return
            }
            
            searchBar?.text = search.localizedDescription
            performSearch(search)
            
            
            switch search.type {
            case .saved:
                break
            case .top:
                break
            case .location:
                guard !search.needsWikidataQuery else {
                    break
                }
                fallthrough
            default:
                saveToHistory(search: search)
            }
        }
    }
    
    func performDefaultSearchIfNecessary(withRegion region: MKCoordinateRegion?) {
        guard currentSearch == nil else {
            return
        }
        performDefaultSearch(withRegion: region)
    }
    
    func performDefaultSearch(withRegion region: MKCoordinateRegion?) {
        currentSearch = PlaceSearch(type: .top, sortStyle: .links, string: nil, region: region, localizedDescription: localizedStringForKeyFallingBackOnEnglish("places-search-top-articles"), searchResult: nil)
    }
    
    var articleFetchedResultsController = NSFetchedResultsController<WMFArticle>() {
        didSet {
            oldValue.delegate = nil
            for article in oldValue.fetchedObjects ?? [] {
                article.placesSortOrder = NSNumber(integerLiteral: 0)
            }
            do {
                try dataStore.viewContext.save()
                try articleFetchedResultsController.performFetch()
            } catch let fetchError {
                DDLogError("Error fetching articles for places: \(fetchError)")
            }
            updatePlaces()
            articleFetchedResultsController.delegate = self
        }
    }
    
    func showRedoSearchButtonIfNecessary(forVisibleRegion visibleRegion: MKCoordinateRegion) {
        guard let searchRegion = currentSearchRegion, let search = currentSearch, search.type != .saved else {
            redoSearchButton.isHidden = true
            return
        }
        let searchWidth = searchRegion.width
        let searchHeight = searchRegion.height
        let searchRegionMinDimension = min(searchWidth, searchHeight)
        
        let visibleWidth = visibleRegion.width
        let visibleHeight = visibleRegion.height
        
        let distance = CLLocation(latitude: visibleRegion.center.latitude, longitude: visibleRegion.center.longitude).distance(from: CLLocation(latitude: searchRegion.center.latitude, longitude: searchRegion.center.longitude))
        let widthRatio = visibleWidth/searchWidth
        let heightRatio = visibleHeight/searchHeight
        let ratio = min(widthRatio, heightRatio)
        redoSearchButton.isHidden = !(ratio > 1.33 || ratio < 0.67 || distance/searchRegionMinDimension > 0.33)
    }
    
    func performSearch(_ search: PlaceSearch) {
        guard !searching else {
            return
        }
        searching = true
        redoSearchButton.isHidden = true
        
        deselectAllAnnotations()
        
        let siteURL = self.siteURL
        var searchTerm: String? = nil
        let sortStyle = search.sortStyle
        let region = search.region ?? mapRegion ?? mapView.region
        currentSearchRegion = region
        
        switch search.type {
        case .saved:
            showSavedArticles()
            return
        case .top:
            tracker?.wmf_logAction("Top_article_search", inContext: searchTrackerContext, contentType: AnalyticsContent(siteURL))
            break
        case .location:
            guard search.needsWikidataQuery else {
                tracker?.wmf_logActionTapThrough(inContext: searchTrackerContext, contentType: AnalyticsContent(siteURL))
                fallthrough
            }
            performWikidataQuery(forSearch: search)
            return
        case .text:
            fallthrough
        default:
            searchTerm = search.string
        }
        
        let center = region.center
        let halfLatitudeDelta = region.span.latitudeDelta * 0.5
        let halfLongitudeDelta = region.span.longitudeDelta * 0.5
        let top = CLLocation(latitude: center.latitude + halfLatitudeDelta, longitude: center.longitude)
        let bottom = CLLocation(latitude: center.latitude - halfLatitudeDelta, longitude: center.longitude)
        let left =  CLLocation(latitude: center.latitude, longitude: center.longitude - halfLongitudeDelta)
        let right =  CLLocation(latitude: center.latitude, longitude: center.longitude + halfLongitudeDelta)
        let height = top.distance(from: bottom)
        let width = right.distance(from: left)
        
        let radius = round(0.5*max(width, height))
        let searchRegion = CLCircularRegion(center: center, radius: radius, identifier: "")
        
        let done = {
            self.searching = false
            self.progressView.setProgress(1.0, animated: true)
            self.isProgressHidden = true
        }
        isProgressHidden = false
        progressView.setProgress(0, animated: false)
        perform(#selector(incrementProgress), with: nil, afterDelay: 0.3)
        locationSearchFetcher.fetchArticles(withSiteURL: siteURL, in: searchRegion, matchingSearchTerm: searchTerm, sortStyle: sortStyle, resultLimit: 50, completion: { (searchResults) in
            self.updatePlaces(withSearchResults: searchResults.results)
            done()
        }) { (error) in
            WMFAlertManager.sharedInstance.showWarningAlert(error.localizedDescription, sticky: false, dismissPreviousAlerts: true, tapCallBack: nil)
            done()
        }
    }
    
    func performWikidataQuery(forSearch search: PlaceSearch) {
        let fail = {
            dispatchOnMainQueue({
                if let region = search.region {
                    self.mapRegion = region
                }
                self.searching = false
                var newSearch = search
                newSearch.needsWikidataQuery = false
                self.currentSearch = newSearch
            })
        }
        guard let articleURL = search.searchResult?.articleURL(forSiteURL: siteURL) else {
            fail()
            return
        }
        
        wikidataFetcher.wikidataBoundingRegion(forArticleURL: articleURL, failure: { (error) in
            DDLogError("Error fetching bounding region from Wikidata: \(error)")
            fail()
        }, success: { (region) in
            dispatchOnMainQueue({
                self.mapRegion = region
                self.searching = false
                var newSearch = search
                newSearch.needsWikidataQuery = false
                newSearch.region = region
                self.currentSearch = newSearch
            })
        })
    }
    
    func updatePlaces(withSearchResults searchResults: [MWKLocationSearchResult]) {
        if let searchSuggestionArticleURL = currentSearch?.searchResult?.articleURL(forSiteURL: siteURL),
            let searchSuggestionArticleKey = (searchSuggestionArticleURL as NSURL?)?.wmf_articleDatabaseKey { // the user tapped an article in the search suggestions list, so we should select that
            articleKeyToSelect = searchSuggestionArticleKey
        } else if currentSearch?.type == .top {
            if let centerCoordinate = currentSearch?.region?.center ?? mapRegion?.center {
                let center = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                var minDistance = CLLocationDistance(Double.greatestFiniteMagnitude)
                var resultToSelect: MWKLocationSearchResult?
                for result in searchResults {
                    guard let location = result.location else {
                        continue
                    }
                    let distance = location.distance(from: center)
                    if distance < minDistance {
                        minDistance = distance
                        resultToSelect = result
                    }
                }
                let resultURL = resultToSelect?.articleURL(forSiteURL: siteURL)
                articleKeyToSelect = (resultURL as NSURL?)?.wmf_articleDatabaseKey
            } else {
                let firstResultURL = searchResults.first?.articleURL(forSiteURL: siteURL)
                articleKeyToSelect = (firstResultURL as NSURL?)?.wmf_articleDatabaseKey
            }
        }
        
        var foundKey = false
        var keysToFetch: [String] = []
        var sort = 1
        for result in searchResults {
            guard let displayTitle = result.displayTitle,
                let articleURL = (siteURL as NSURL).wmf_URL(withTitle: displayTitle),
                let article = self.articleStore?.addPreview(with: articleURL, updatedWith: result),
                let _ = article.quadKey,
                let articleKey = article.key else {
                    continue
            }
            article.placesSortOrder = NSNumber(value: sort)
            if articleKeyToSelect != nil && articleKeyToSelect == articleKey {
                foundKey = true
            }
            keysToFetch.append(articleKey)
            sort += 1
        }
        
        if !foundKey, let keyToFetch = articleKeyToSelect, let URL = URL(string: keyToFetch), let searchResult = currentSearch?.searchResult {
            articleStore.addPreview(with: URL, updatedWith: searchResult)
            keysToFetch.append(keyToFetch)
        }
        
        let request = WMFArticle.fetchRequest()
        request.predicate = NSPredicate(format: "key in %@", keysToFetch)
        request.sortDescriptors = [NSSortDescriptor(key: "placesSortOrder", ascending: true)]
        articleFetchedResultsController = NSFetchedResultsController<WMFArticle>(fetchRequest: request, managedObjectContext: dataStore.viewContext, sectionNameKeyPath: nil, cacheName: nil)
    }
    
    func updatePlaces() {
        listView.reloadData()
        currentGroupingPrecision = 0
        regroupArticlesIfNecessary(forVisibleRegion: mapRegion ?? mapView.region)
        if currentSearch?.region == nil { // this means the search was done in the curent map region and the map won't move
            selectVisibleKeyToSelectIfNecessary()
        }
    }
    
    @IBAction func redoSearch(_ sender: Any) {
        guard let search = currentSearch else {
            return
        }
        
        redoSearchButton.isHidden = true
        
        guard search.type != .location && search.type != .saved else {
            performDefaultSearch(withRegion: mapView.region)
            return
        }
        
        currentSearch = PlaceSearch(type: search.type, sortStyle: search.sortStyle, string: search.string, region: nil, localizedDescription: search.localizedDescription, searchResult: search.searchResult)
    }
    
    // MARK: - Display Actions
    
    func deselectAllAnnotations() {
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
    
    var useOverlay: Bool {
        get {
            return traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular
        }
    }
    
    func updateLayout(_ traitCollection: UITraitCollection, animated: Bool) {
        if useOverlay {
            switch viewMode {
            case .search:
                viewMode = .searchOverlay
            case .list:
                fallthrough
            case .map:
                viewMode = .listOverlay
            default:
                break
            }
        } else {
            switch viewMode {
            case .searchOverlay:
                viewMode = .search
            case .listOverlay:
                viewMode = .map
            default:
                break
            }
        }
    }
    
    enum ViewMode {
        case none
        case map
        case list
        case search
        case listOverlay
        case searchOverlay
    }
    
    private var overlaySliderPanGestureRecognizer: UIPanGestureRecognizer?
    
    func addSearchBarToNavigationBar(animated: Bool) {
        titleViewSearchBar.isHidden = false
        segmentedControl.isHidden = false
        searchBar = titleViewSearchBar
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let panGR = overlaySliderPanGestureRecognizer {
            view.removeGestureRecognizer(panGR)
        }
    }
    
    func removeSearchBarFromNavigationBar(animated: Bool) {
        titleViewSearchBar.isHidden = true
        segmentedControl.isHidden = true
        searchBar = listAndSearchOverlaySearchBar
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        let panGR = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panGR.delegate = self
        view.addGestureRecognizer(panGR)
        overlaySliderPanGestureRecognizer = panGR
    }
    
    var initialOverlayHeightForPan: CGFloat?
    
    
    let overlayMidHeight: CGFloat = 388
    var overlayMinHeight: CGFloat {
        get {
            return listAndSearchOverlaySearchHeightConstraint.constant + listAndSearchOverlaySliderHeightConstraint.constant
        }
    }
    var overlayMaxHeight: CGFloat {
        get {
            return view.bounds.size.height - listAndSearchOverlayContainerView.frame.minY - listAndSearchOverlayBottomConstraint.constant
        }
    }

    enum OverlayState {
        case min
        case mid
        case max
    }
    
    func set(overlayState: OverlayState, withVelocity velocity: CGFloat, animated: Bool) {
        let currentHeight = listAndSearchOverlayHeightConstraint.constant
        let newHeight: CGFloat
        switch overlayState {
        case .min:
            newHeight = overlayMinHeight
        case .max:
            newHeight = overlayMaxHeight
        default:
            newHeight = overlayMidHeight
        }
        let springVelocity = velocity / (newHeight - currentHeight)
        self.view.layoutIfNeeded()
        let animations = {
            self.listAndSearchOverlayHeightConstraint.constant = newHeight
            self.view.layoutIfNeeded()
        }
        let duration: TimeInterval = 0.5
        self.overlayState = overlayState
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: springVelocity, options: [.allowUserInteraction], animations: animations, completion: { (didFinish) in
            if overlayState == .max {
                self.listAndSearchOverlayHeightConstraint.isActive = false
                self.listAndSearchOverlayBottomConstraint.isActive = true
            } else {
                self.listAndSearchOverlayHeightConstraint.isActive = true
                self.listAndSearchOverlayBottomConstraint.isActive = false
            }
        })
    }
    
    var overlayState = OverlayState.mid
    
    
    func handlePanGesture(_ panGR: UIPanGestureRecognizer) {
        let minHeight = overlayMinHeight
        let maxHeight = overlayMaxHeight
        let midHeight = overlayMidHeight
        switch panGR.state {
        case .possible:
            fallthrough
        case .began:
            fallthrough
        case .changed:
            let initialHeight: CGFloat
            if let height = initialOverlayHeightForPan {
                initialHeight = height
            } else {
                if (overlayState == .max) {
                    listAndSearchOverlayHeightConstraint.constant = listAndSearchOverlayContainerView.frame.height
                }
                initialHeight = listAndSearchOverlayHeightConstraint.constant
                initialOverlayHeightForPan = initialHeight
                listAndSearchOverlayHeightConstraint.isActive = true
                listAndSearchOverlayBottomConstraint.isActive = false
            }
            listAndSearchOverlayHeightConstraint.constant = max(minHeight, initialHeight + panGR.translation(in: view).y)
        case .ended:
            fallthrough
        case .failed:
            fallthrough
        case .cancelled:
            let currentHeight = listAndSearchOverlayHeightConstraint.constant
            let newState: OverlayState
            if currentHeight <= midHeight {
                newState = currentHeight - minHeight <= midHeight - currentHeight ? .min : .mid
            } else {
                let mid = currentHeight - midHeight <= maxHeight - currentHeight
                newState = mid ? .mid : .max
            }
            set(overlayState: newState, withVelocity: panGR.velocity(in: view).y, animated: true)
            initialOverlayHeightForPan = nil
            break
        }
    }
    
    var isSearchBarInNavigationBar: Bool? {
        didSet{
            guard let newValue = isSearchBarInNavigationBar, oldValue != newValue else {
                return
            }
            if newValue {
                addSearchBarToNavigationBar(animated: false)
            } else {
                removeSearchBarFromNavigationBar(animated: false)
            }
        }
    }
    
    
    private func updateTraitBasedViewMode() {
        //forces an update
        let oldViewMode = self.viewMode
        self.viewMode = .none
        self.viewMode = oldViewMode
    }
    
    var isOverlaySearchButtonHidden = true {
        didSet {
            let isHidden = isOverlaySearchButtonHidden
            let animations = {
                self.listAndSearchOverlaySearchCancelButtonHideConstraint.isActive = isHidden
                self.listAndSearchOverlaySearchCancelButtonShowConstraint.isActive = !isHidden
            }
            if (isHidden)  {
                animations()
            } else {
                listAndSearchOverlayContainerView.layoutIfNeeded()
                UIView.animate(withDuration: 0.3) {
                    animations()
                    self.listAndSearchOverlayContainerView.layoutIfNeeded()
                }
            }
        }
    }
    
    var isViewModeOverlay: Bool {
        get {
            return traitBasedViewMode == .listOverlay || traitBasedViewMode == .searchOverlay
        }
    }
    
    var traitBasedViewMode: ViewMode = .none {
        didSet {
            guard oldValue != traitBasedViewMode else {
                return
            }
            if oldValue == .search && viewMode != .search {
                navigationItem.setRightBarButton(segmentedControlBarButtonItem, animated: true)
            } else if oldValue != .search && viewMode == .search {
                navigationItem.setRightBarButton(closeBarButtonItem, animated: true)
            }
            switch traitBasedViewMode {
            case .listOverlay:
                isSearchBarInNavigationBar = false
                deselectAllAnnotations()
                updateDistanceFromUserOnVisibleCells()
                logListViewImpressionsForVisibleCells()
                mapView.isHidden = false
                listView.isHidden = false
                searchSuggestionView.isHidden = true
                listAndSearchOverlayContainerView.isHidden = false
                isOverlaySearchButtonHidden = true
            case .list:
                isSearchBarInNavigationBar = true
                deselectAllAnnotations()
                updateDistanceFromUserOnVisibleCells()
                logListViewImpressionsForVisibleCells()
                mapView.isHidden = true
                listView.isHidden = false
                searchSuggestionView.isHidden = true
                listAndSearchOverlayContainerView.isHidden = false
            case .searchOverlay:
                if overlayState == .min {
                    set(overlayState: .mid, withVelocity: 0, animated: true)
                }
                isOverlaySearchButtonHidden = false
                isSearchBarInNavigationBar = false
                mapView.isHidden = false
                listView.isHidden = true
                searchSuggestionView.isHidden = false
                listAndSearchOverlayContainerView.isHidden = false
            case .search:
                isSearchBarInNavigationBar = true
                mapView.isHidden = true
                listView.isHidden = true
                searchSuggestionView.isHidden = false
                listAndSearchOverlayContainerView.isHidden = false
            case .map:
                fallthrough
            default:
                isSearchBarInNavigationBar = true
                mapView.isHidden = false
                listView.isHidden = true
                searchSuggestionView.isHidden = true
                listAndSearchOverlayContainerView.isHidden = true
            }
            recenterOnUserLocationButton.isHidden = mapView.isHidden
            redoSearchButton.isHidden = mapView.isHidden
        }
    }

    var viewMode: ViewMode = .none {
        didSet {
            guard oldValue != viewMode, viewMode != .none else {
                return
            }
            switch viewMode {
            case .list:
                traitBasedViewMode = useOverlay ? .listOverlay : .list
            case .search:
                traitBasedViewMode = useOverlay ? .searchOverlay : .search
            case .map:
                fallthrough
            default:
                traitBasedViewMode = useOverlay ? .listOverlay : .map
            }
        }
    }

    func updateViewModeFromSegmentedControl() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            viewMode = .map
        default:
            viewMode = .list
        }
    }
    
    func selectArticlePlace(_ articlePlace: ArticlePlace) {
        mapView.selectAnnotation(articlePlace, animated: articlePlace.identifier != previouslySelectedArticlePlaceIdentifier)
        previouslySelectedArticlePlaceIdentifier = articlePlace.identifier
    }

    // MARK: - Search History
    
    func saveToHistory(search: PlaceSearch) {
        do {
            let moc = dataStore.viewContext
            if let keyValue = keyValue(forPlaceSearch: search, inManagedObjectContext: moc) {
                keyValue.date = Date()
            } else if let entity = NSEntityDescription.entity(forEntityName: "WMFKeyValue", in: moc) {
                let keyValue =  WMFKeyValue(entity: entity, insertInto: moc)
                keyValue.key = search.key
                keyValue.group = searchHistoryGroup
                keyValue.date = Date()
                keyValue.value = search.dictionaryValue as NSObject
            }
            try moc.save()
        } catch let error {
            DDLogError("error saving to place search history: \(error.localizedDescription)")
        }
    }
    
    func clearSearchHistory() {
        do {
            let moc = dataStore.viewContext
            let request = WMFKeyValue.fetchRequest()
            request.predicate = NSPredicate(format: "group == %@", searchHistoryGroup)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            let results = try moc.fetch(request)
            for result in results {
                moc.delete(result)
            }
            try moc.save()
        } catch let error {
            DDLogError("Error clearing recent place searches: \(error)")
        }
    }
    
    func keyValue(forPlaceSearch placeSearch: PlaceSearch, inManagedObjectContext moc: NSManagedObjectContext) -> WMFKeyValue? {
        var keyValue: WMFKeyValue?
        do {
            let key = placeSearch.key
            let request = WMFKeyValue.fetchRequest()
            request.predicate = NSPredicate(format: "key == %@ && group == %@", key, searchHistoryGroup)
            request.fetchLimit = 1
            let results = try moc.fetch(request)
            keyValue = results.first
        } catch let error {
            DDLogError("Error fetching place search key value: \(error.localizedDescription)")
        }
        return keyValue
    }
    
    // MARK: - Location Access
    
    func promptForLocationAccess() {
        let enableLocationVC = EnableLocationViewController(nibName: "EnableLocationViewController", bundle: nil)
        enableLocationVC.view.tintColor = view.tintColor
        enableLocationVC.modalPresentationStyle = .popover
        enableLocationVC.preferredContentSize = enableLocationVC.view.systemLayoutSizeFitting(CGSize(width: enableLocationVC.view.bounds.size.width, height: UILayoutFittingCompressedSize.height), withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
        enableLocationVC.popoverPresentationController?.delegate = self
        enableLocationVC.popoverPresentationController?.sourceView = view
        enableLocationVC.popoverPresentationController?.canOverlapSourceViewRect = true
        enableLocationVC.popoverPresentationController?.sourceRect = view.bounds
        enableLocationVC.popoverPresentationController?.permittedArrowDirections = []
        enableLocationVC.delegate = self
        present(enableLocationVC, animated: true, completion: {
            
        })
    }
    
    // MARK: - Saved Articles
    
    func showSavedArticles() {
        tracker?.wmf_logAction("Saved_article_search", inContext: searchTrackerContext, contentType: AnalyticsContent(siteURL))
        let moc = dataStore.viewContext
        isProgressHidden = false
        progressView.setProgress(0, animated: false)
        let done = { (articlesToShow: [WMFArticle]) -> Void in
            let request = WMFArticle.fetchRequest()
            request.predicate = NSPredicate(format: "savedDate != NULL && signedQuadKey != NULL")
            request.sortDescriptors = [NSSortDescriptor(key: "savedDate", ascending: false)]
            self.articleFetchedResultsController = NSFetchedResultsController<WMFArticle>(fetchRequest: request, managedObjectContext: self.dataStore.viewContext, sectionNameKeyPath: nil, cacheName: nil)
            if articlesToShow.count > 0 {
                self.mapRegion = self.regionThatFits(articles: articlesToShow)
            }
            self.searching = false
            if articlesToShow.count == 0 {
                self.wmf_showAlertWithMessage(localizedStringForKeyFallingBackOnEnglish("places-no-saved-articles-have-location"))
            }
            self.progressView.setProgress(1.0, animated: true)
            self.isProgressHidden = true
        }
        
        do {
            let savedPagesWithLocation = try moc.fetch(fetchRequestForSavedArticlesWithLocation)
            guard savedPagesWithLocation.count >= 99 else {
                let savedPagesWithoutLocationRequest = WMFArticle.fetchRequest()
                savedPagesWithoutLocationRequest.predicate = NSPredicate(format: "savedDate != NULL && signedQuadKey == NULL")
                savedPagesWithoutLocationRequest.sortDescriptors = [NSSortDescriptor(key: "savedDate", ascending: false)]
                savedPagesWithoutLocationRequest.propertiesToFetch = ["key"]
                let savedPagesWithoutLocation = try moc.fetch(savedPagesWithoutLocationRequest)
                guard savedPagesWithoutLocation.count > 0 else {
                    done(savedPagesWithLocation)
                    return
                }
                let urls = savedPagesWithoutLocation.flatMap({ (article) -> URL? in
                    return article.url
                })
                
                previewFetcher.fetchArticlePreviewResults(forArticleURLs: urls, siteURL: siteURL, completion: { (searchResults) in
                    var resultsByKey: [String: MWKSearchResult] = [:]
                    for searchResult in searchResults {
                        guard let title = searchResult.displayTitle, searchResult.location != nil else {
                            continue
                        }
                        guard let url = (self.siteURL as NSURL).wmf_URL(withTitle: title)  else {
                            continue
                        }
                        guard let key = (url as NSURL).wmf_articleDatabaseKey else {
                            continue
                        }
                        resultsByKey[key] = searchResult
                    }
                    guard resultsByKey.count > 0 else {
                        done(savedPagesWithLocation)
                        return
                    }
                    let articlesToUpdateFetchRequest = WMFArticle.fetchRequest()
                    articlesToUpdateFetchRequest.predicate = NSPredicate(format: "key IN %@", Array(resultsByKey.keys))
                    do {
                        var allArticlesWithLocation = savedPagesWithLocation
                        let articlesToUpdate = try moc.fetch(articlesToUpdateFetchRequest)
                        for articleToUpdate in articlesToUpdate {
                            guard let key = articleToUpdate.key,
                                let result = resultsByKey[key] else {
                                    continue
                            }
                            self.articleStore.updatePreview(articleToUpdate, with: result)
                            allArticlesWithLocation.append(articleToUpdate)
                        }
                        try moc.save()
                        done(allArticlesWithLocation)
                    } catch let error {
                        DDLogError("Error fetching saved articles: \(error.localizedDescription)")
                        done(savedPagesWithLocation)
                    }
                }, failure: { (error) in
                    DDLogError("Error fetching saved articles: \(error.localizedDescription)")
                    done(savedPagesWithLocation)
                })
                return
            }
        } catch let error {
            DDLogError("Error fetching saved articles: \(error.localizedDescription)")
        }
        done([])
    }
    
    
    var fetchRequestForSavedArticles: NSFetchRequest<WMFArticle> {
        get {
            let savedRequest = WMFArticle.fetchRequest()
            savedRequest.predicate = NSPredicate(format: "savedDate != NULL")
            return savedRequest
        }
    }
    
    var fetchRequestForSavedArticlesWithLocation: NSFetchRequest<WMFArticle> {
        get {
            let savedRequest = WMFArticle.fetchRequest()
            savedRequest.predicate = NSPredicate(format: "savedDate != NULL && signedQuadKey != NULL")
            return savedRequest
        }
    }
    
    
    // MARK: - Progress
    
    func incrementProgress() {
        guard !isProgressHidden && progressView.progress <= 0.69 else {
            return
        }
        
        let rand = 0.15 + Float(arc4random_uniform(15))/100
        progressView.setProgress(progressView.progress + rand, animated: true)
        perform(#selector(incrementProgress), with: nil, afterDelay: 0.3)
    }
    
    func hideProgress() {
        UIView.animate(withDuration: 0.3, animations: { self.progressView.alpha = 0 } )
    }
    
    func showProgress() {
        progressView.alpha = 1
    }
    
    var isProgressHidden: Bool = false {
        didSet{
            if isProgressHidden {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(showProgress), object: nil)
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(incrementProgress), object: nil)
                perform(#selector(hideProgress), with: nil, afterDelay: 0.7)
            } else {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideProgress), object: nil)
                showProgress()
            }
        }
    }
    
    // MARK: - Place Grouping
    
    private var groupingTaskGroup: WMFTaskGroup?
    private var needsRegroup = false
    private var showingAllImages = false
    private var greaterThanOneArticleGroupCount = 0
    
    struct ArticleGroup {
        var articles: [WMFArticle] = []
        var latitudeSum: QuadKeyDegrees = 0
        var longitudeSum: QuadKeyDegrees = 0
        var latitudeAdjustment: QuadKeyDegrees = 0
        var longitudeAdjustment: QuadKeyDegrees = 0
        var baseQuadKey: QuadKey = 0
        var baseQuadKeyPrecision: QuadKeyPrecision = 0
        var location: CLLocation {
            get {
                return CLLocation(latitude: (latitudeSum + latitudeAdjustment)/CLLocationDegrees(articles.count), longitude: (longitudeSum + longitudeAdjustment)/CLLocationDegrees(articles.count))
            }
        }
        
        init () {
            
        }
        
        init(article: WMFArticle) {
            articles = [article]
            latitudeSum = article.coordinate?.latitude ?? 0
            longitudeSum = article.coordinate?.longitude ?? 0
            baseQuadKey = article.quadKey ?? 0
            baseQuadKeyPrecision = QuadKeyPrecision.maxPrecision
        }
    }

    
    func merge(group: ArticleGroup, key: String, groups: [String: ArticleGroup], groupingDistance: CLLocationDistance) -> Set<String> {
        var toMerge = Set<String>()
        if let keyToSelect = articleKeyToSelect, group.articles.first?.key == keyToSelect {
            //no grouping with the article to select
            return toMerge
        }
        
        let baseQuadKey = group.baseQuadKey
        let baseQuadKeyPrecision = group.baseQuadKeyPrecision
        let baseQuadKeyCoordinate = QuadKeyCoordinate(quadKey: baseQuadKey, precision: baseQuadKeyPrecision)
        
        if baseQuadKeyCoordinate.latitudePart > 2 && baseQuadKeyCoordinate.longitudePart > 1 {
            for t: Int64 in -1...1 {
                for n: Int64 in -1...1 {
                    guard t != 0 || n != 0 else {
                        continue
                    }
                    let latitudePart = QuadKeyPart(Int64(baseQuadKeyCoordinate.latitudePart) + 2*t)
                    let longitudePart = QuadKeyPart(Int64(baseQuadKeyCoordinate.longitudePart) + n)
                    let adjacentBaseQuadKey = QuadKey(latitudePart: latitudePart, longitudePart: longitudePart, precision: baseQuadKeyPrecision)
                    let adjacentKey = "\(adjacentBaseQuadKey)|\(adjacentBaseQuadKey + 1)"
                    guard let adjacentGroup = groups[adjacentKey] else {
                        continue
                    }
                    if let keyToSelect = articleKeyToSelect, adjacentGroup.articles.first?.key == keyToSelect {
                        //no grouping with the article to select
                        continue
                    }
                    guard group.articles.count > 1 || adjacentGroup.articles.count > 1 else {
                        continue
                    }
                    let location = group.location
                    let distance = adjacentGroup.location.distance(from: location)
                    let distanceToCheck = group.articles.count == 1 || adjacentGroup.articles.count == 1 ? 0.25*groupingDistance : groupingDistance
                    if distance < distanceToCheck {
                        toMerge.insert(adjacentKey)
                        var newGroups = groups
                        newGroups.removeValue(forKey: key)
                        let others = merge(group: adjacentGroup, key: adjacentKey, groups: newGroups, groupingDistance: groupingDistance)
                        toMerge.formUnion(others)
                    }
                }
            }
        }
        return toMerge
    }
    
    func regroupArticlesIfNecessary(forVisibleRegion visibleRegion: MKCoordinateRegion) {
        guard groupingTaskGroup == nil else {
            needsRegroup = true
            return
        }
        assert(Thread.isMainThread)
        
        guard let searchRegion = currentSearchRegion else {
            return
        }
        
        let deltaLon = visibleRegion.span.longitudeDelta
        let lowestPrecision = QuadKeyPrecision(deltaLongitude: deltaLon)
        let searchDeltaLon = searchRegion.span.longitudeDelta
        let lowestSearchPrecision = QuadKeyPrecision(deltaLongitude: searchDeltaLon)
        var groupingAggressiveness: CLLocationDistance = 0.67
        let groupingPrecisionDelta: QuadKeyPrecision = isViewModeOverlay ? 5 : 4
        let maxPrecision: QuadKeyPrecision = isViewModeOverlay ? 18 : 17
        let minGroupCount = 3
        if lowestPrecision + groupingPrecisionDelta <= lowestSearchPrecision {
            groupingAggressiveness += 0.3
        }
        let currentPrecision = lowestPrecision + groupingPrecisionDelta
        let groupingPrecision = min(maxPrecision, currentPrecision)

        guard groupingPrecision != currentGroupingPrecision else {
            return
        }
        
        let taskGroup = WMFTaskGroup()
        groupingTaskGroup = taskGroup
        
        let groupingDeltaLatitude = groupingPrecision.deltaLatitude
        let groupingDeltaLongitude = groupingPrecision.deltaLongitude
        
        let centerLat = searchRegion.center.latitude
        let centerLon = searchRegion.center.longitude
        let groupingDistanceLocation = CLLocation(latitude:centerLat + groupingDeltaLatitude, longitude: centerLon + groupingDeltaLongitude)
        let centerLocation = CLLocation(latitude:centerLat, longitude: centerLon)
        let groupingDistance = groupingAggressiveness * groupingDistanceLocation.distance(from: centerLocation)
        
        var previousPlaceByArticle: [String: ArticlePlace] = [:]
        
        var annotationsToRemove: [String:ArticlePlace] = [:]
        
        for annotation in mapView.annotations {
            guard let place = annotation as? ArticlePlace else {
                continue
            }
            
            annotationsToRemove[place.identifier] = place
            
            for article in place.articles {
                guard let key = article.key else {
                    continue
                }
                previousPlaceByArticle[key] = place
            }
        }
        
        var groups: [String: ArticleGroup] = [:]
        var splittableGroups: [String: ArticleGroup] = [:]
        for article in articleFetchedResultsController.fetchedObjects ?? [] {
            guard let quadKey = article.quadKey else {
                continue
            }
            var group: ArticleGroup
            let adjustedQuadKey: QuadKey
            var key: String
            if groupingPrecision < maxPrecision && (articleKeyToSelect == nil || article.key != articleKeyToSelect) {
                adjustedQuadKey = quadKey.adjusted(downBy: QuadKeyPrecision.maxPrecision - groupingPrecision)
                let baseQuadKey = adjustedQuadKey - adjustedQuadKey % 2
                key = "\(baseQuadKey)|\(baseQuadKey + 1)" // combine neighboring vertical keys
                group = groups[key] ?? ArticleGroup()
                group.baseQuadKey = baseQuadKey
                group.baseQuadKeyPrecision = groupingPrecision
            } else {
                group = ArticleGroup()
                adjustedQuadKey = quadKey
                key = "\(adjustedQuadKey)"
                if var existingGroup = groups[key] {
                    let existingGroupArticleKey = existingGroup.articles.first?.key ?? ""
                    let existingGroupTitle = existingGroup.articles.first?.displayTitle ?? ""
                    existingGroup.latitudeAdjustment = 0.0001 * CLLocationDegrees(existingGroupArticleKey.hash) / CLLocationDegrees(Int.max)
                    existingGroup.longitudeAdjustment = 0.0001 * CLLocationDegrees(existingGroupTitle.hash) / CLLocationDegrees(Int.max)
                    groups[key] = existingGroup
                    
                    let articleKey = article.key ?? ""
                    let articleTitle = article.displayTitle ?? ""
                    group.latitudeAdjustment = 0.0001 * CLLocationDegrees(articleKey.hash) / CLLocationDegrees(Int.max)
                    group.longitudeAdjustment = 0.0001 * CLLocationDegrees(articleTitle.hash) / CLLocationDegrees(Int.max)
                    key = articleKey
                }
                group.baseQuadKey = quadKey
                group.baseQuadKeyPrecision = QuadKeyPrecision.maxPrecision
            }
            group.articles.append(article)
            let coordinate = QuadKeyCoordinate(quadKey: quadKey)
            group.latitudeSum += coordinate.latitude
            group.longitudeSum += coordinate.longitude
            groups[key] = group
            if group.articles.count > 1 {
                if group.articles.count < minGroupCount {
                    splittableGroups[key] = group
                } else {
                    splittableGroups[key] = nil
                }
            }
        }
        
        
        for (key, group) in splittableGroups {
            for (index, article) in group.articles.enumerated() {
                groups[key + ":\(index)"] = ArticleGroup(article: article)
            }
            groups.removeValue(forKey: key)
        }
        
        greaterThanOneArticleGroupCount = 0
        let keys = groups.keys
        for key in keys {
            guard var group = groups[key] else {
                continue
            }
            
            if groupingPrecision < maxPrecision {
                let toMerge = merge(group: group, key: key, groups: groups, groupingDistance: groupingDistance)
                for adjacentKey in toMerge {
                    guard let adjacentGroup = groups[adjacentKey] else {
                        continue
                    }
                    group.articles.append(contentsOf: adjacentGroup.articles)
                    group.latitudeSum += adjacentGroup.latitudeSum
                    group.longitudeSum += adjacentGroup.longitudeSum
                    groups.removeValue(forKey: adjacentKey)
                }
                
                
                if group.articles.count > 1 {
                    greaterThanOneArticleGroupCount += 1
                }
            }
            
            var nextCoordinate: CLLocationCoordinate2D?
            var coordinate = group.location.coordinate
            
            let identifier = ArticlePlace.identifierForArticles(articles: group.articles)
            
            //check for identical place already on the map
            if let _ = annotationsToRemove.removeValue(forKey: identifier) {
                continue
            }
            
            if group.articles.count == 1 {
                if let article = group.articles.first, let key = article.key, let previousPlace = previousPlaceByArticle[key] {
                    nextCoordinate = coordinate
                    coordinate = previousPlace.coordinate
                    if let thumbnailURL = article.thumbnailURL {
                        imageController.prefetch(withURL: thumbnailURL)
                    }
                }
                
            } else {
                let groupCount = group.articles.count
                for article in group.articles {
                    guard let key = article.key,
                        let previousPlace = previousPlaceByArticle[key] else {
                            continue
                    }
                    
                    guard previousPlace.articles.count < groupCount else {
                            nextCoordinate = coordinate
                            coordinate = previousPlace.coordinate
                        break
                    }
                    
                    guard annotationsToRemove.removeValue(forKey: previousPlace.identifier) != nil else {
                        continue
                    }
                    
                    let placeView = mapView.view(for: previousPlace)
                    taskGroup.enter()
                    self.countOfAnimatingAnnotations += 1
                    UIView.animate(withDuration:animationDuration, delay: 0, options: [.allowUserInteraction], animations: {
                        placeView?.alpha = 0
                        if (previousPlace.articles.count > 1) {
                            placeView?.transform = CGAffineTransform(scaleX: self.animationScale, y: self.animationScale)
                        }
                        previousPlace.coordinate = coordinate
                    }, completion: { (finished) in
                        taskGroup.leave()
                        self.mapView.removeAnnotation(previousPlace)
                        self.countOfAnimatingAnnotations -= 1
                    })
                }
            }

            
            guard let place = ArticlePlace(coordinate: coordinate, nextCoordinate: nextCoordinate, articles: group.articles, identifier: identifier) else {
                continue
            }
            
            mapView.addAnnotation(place)
            
            groups.removeValue(forKey: key)
        }
        
        for (_, annotation) in annotationsToRemove {
            let placeView = mapView.view(for: annotation)
            taskGroup.enter()
            self.countOfAnimatingAnnotations += 1
            UIView.animate(withDuration: 0.5*animationDuration, animations: {
                placeView?.transform = CGAffineTransform(scaleX: self.animationScale, y: self.animationScale)
                placeView?.alpha = 0
            }, completion: { (finished) in
                taskGroup.leave()
                self.mapView.removeAnnotation(annotation)
                self.countOfAnimatingAnnotations -= 1
            })
        }
        currentGroupingPrecision = groupingPrecision
        if greaterThanOneArticleGroupCount > 0 {
            set(shouldShowAllImages: false)
        }
        taskGroup.waitInBackground {
            self.groupingTaskGroup = nil
            self.selectVisibleKeyToSelectIfNecessary()
            if (self.needsRegroup) {
                self.needsRegroup = false
                self.regroupArticlesIfNecessary(forVisibleRegion: self.mapRegion ?? self.mapView.region)
            }
        }
    }
    
    // MARK: - Article Popover
    
    func showPopover(forAnnotationView annotationView: MKAnnotationView) {
        guard let place = annotationView.annotation as? ArticlePlace else {
            return
        }
        
        guard let article = place.articles.first,
            let coordinate = article.coordinate,
            let articleKey = article.key else {
                return
        }
        
        guard selectedArticlePopover == nil else {
            return
        }
        
        if isViewModeOverlay, let indexPath = articleFetchedResultsController.indexPath(forObject: article) {
            listView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
        
        let articleVC = ArticlePopoverViewController(article)
        articleVC.delegate = self
        articleVC.view.tintColor = view.tintColor
        articleVC.configureView(withTraitCollection: traitCollection)
        
        let articleLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if locationManager.isUpdating {
            let userLocation = locationManager.location
            let distance = articleLocation.distance(from: userLocation)
            let distanceString = MKDistanceFormatter().string(fromDistance: distance)
            articleVC.descriptionLabel.text = distanceString
        } else {
            articleVC.descriptionLabel.text = nil
        }
        
        articleVC.view.alpha = 0
        addChildViewController(articleVC)
    
        view.insertSubview(articleVC.view, aboveSubview: placeGroupVC?.view ?? mapView)
        articleVC.didMove(toParentViewController: self)
        
        let size = articleVC.view.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        articleVC.preferredContentSize = size
        selectedArticlePopover = articleVC
        selectedArticleAnnotationView = annotationView
        selectedArticleKey = articleKey
    
        
        adjustLayout(ofPopover: articleVC, withSize:size, viewSize:view.bounds.size, forAnnotationView: annotationView)
        articleVC.view.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        articleVC.view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: popoverFadeDuration) {
            articleVC.view.transform = CGAffineTransform.identity
            articleVC.view.alpha = 1
        }
        
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, articleVC.view)

        tracker?.wmf_logActionImpression(inContext: mapTrackerContext, contentType: article)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            if let groupVC = self.placeGroupVC, let annotationView = self.placeGroupAnnotationView  {
                let center = self.view.convert(annotationView.center, from: annotationView.superview)
                groupVC.layout(center: center)
            }
            
            if let popover = self.selectedArticlePopover,
                let annotationView = self.selectedArticleAnnotationView {
                self.adjustLayout(ofPopover: popover, withSize: popover.preferredContentSize, viewSize: size, forAnnotationView: annotationView)
            }
            self.updateTraitBasedViewMode()
        }, completion: nil)
    }
    
    func dismissCurrentArticlePopover() {
        guard let popover = selectedArticlePopover else {
            return
        }
        UIView.animate(withDuration: popoverFadeDuration, animations: {
            popover.view.alpha = 0
            popover.view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { (done) in
            popover.willMove(toParentViewController: nil)
            popover.view.removeFromSuperview()
            popover.removeFromParentViewController()
        }
        selectedArticlePopover = nil
        selectedArticleAnnotationView = nil
    }
    
    func articlePopoverViewController(articlePopoverViewController: ArticlePopoverViewController, didSelectAction action: WMFArticleAction) {
        perform(action: action, onArticle: articlePopoverViewController.article)
    }
    
    func perform(action: WMFArticleAction, onArticle article: WMFArticle) {
        guard let url = article.url else {
            return
        }
        let context = viewMode == .list ? listTrackerContext : mapTrackerContext
        switch action {
        case .read:
            tracker?.wmf_logActionTapThrough(inContext: context, contentType: article)
            wmf_pushArticle(with: url, dataStore: dataStore, previewStore: articleStore, animated: true)
            if navigationController?.isNavigationBarHidden ?? false {
                navigationController?.setNavigationBarHidden(false, animated: true)
            }

            break
        case .save:
            let didSave = dataStore.savedPageList.toggleSavedPage(for: url)
            if didSave {
                tracker?.wmf_logActionSave(inContext: context, contentType: article)
            }else {
                tracker?.wmf_logActionUnsave(inContext: context, contentType: article)
            }
            break
        case .share:
            tracker?.wmf_logActionShare(inContext: context, contentType: article)
            var activityItems : [Any] = [url]
            if let mapItem = article.mapItem {
                activityItems.append(mapItem)
            }
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: [TUSafariActivity(), WMFOpenInMapsActivity(), WMFGetDirectionsInMapsActivity()])
            activityVC.popoverPresentationController?.sourceView = view
            var sourceRect = view.bounds
            if let shareButton = selectedArticlePopover?.shareButton {
                sourceRect = view.convert(shareButton.frame, from: shareButton.superview)
            }
            activityVC.popoverPresentationController?.sourceRect = sourceRect
            present(activityVC, animated: true, completion: nil)
            break
        case .none:
            fallthrough
        default:
            break
        }
    }
    
    enum PopoverLocation {
        case top
        case bottom
        case left
        case right
    }
    
    func adjustLayout(ofPopover articleVC: ArticlePopoverViewController, withSize popoverSize: CGSize, viewSize: CGSize, forAnnotationView annotationView: MKAnnotationView) {
        var preferredLocations = [PopoverLocation]()
        
        
        let annotationSize = annotationView.frame.size
        let spacing: CGFloat = 5
        let annotationCenter = view.convert(annotationView.center, from: mapView)
        
        if let groupAnnotationView = placeGroupAnnotationView {
            let adjustedCenter = view.convert(annotationView.center, from: annotationView.superview)
            let adjustedGroupCenter = view.convert(groupAnnotationView.center, from: groupAnnotationView.superview)
            let dx = adjustedGroupCenter.x - adjustedCenter.x
            let dy = adjustedGroupCenter.y - adjustedCenter.y
            
            if dy <= 0 && dx <= 0 {
                if dy < dx {
                    preferredLocations = [.bottom, .right]
                } else {
                    preferredLocations = [.right, .bottom]
                }
            } else if dy > 0 && dx <= 0 {
                if dy > abs(dx) {
                    preferredLocations = [.top, .right]
                } else {
                    preferredLocations = [.right, .top]
                }
            } else if dy <= 0 && dx > 0 {
                if abs(dy) > dx {
                    preferredLocations = [.bottom, .left]
                } else {
                    preferredLocations = [.left, .bottom]
                }
            } else if dy > 0 && dx > 0 {
                if dy > dx {
                    preferredLocations = [.top, .left]
                } else {
                    preferredLocations = [.left, .top]
                }
            }
        } else if isViewModeOverlay {
            if UIApplication.shared.wmf_isRTL {
                if annotationCenter.x >= listAndSearchOverlayContainerView.frame.minX {
                    preferredLocations = [.bottom, .left, .right, .top]
                } else {
                    preferredLocations = [.left, .bottom, .top, .right]
                }
            } else {
                if annotationCenter.x <= listAndSearchOverlayContainerView.frame.maxX {
                    preferredLocations = [.bottom, .right, .left, .top]
                } else {
                    preferredLocations = [.right, .bottom, .top, .left]
                }
            }
        }
    
        let viewCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    
        let popoverDistanceFromAnnotationCenterY = 0.5 * annotationSize.height + spacing
        let totalHeight = popoverDistanceFromAnnotationCenterY + popoverSize.height + spacing
        let top = totalHeight - annotationCenter.y
        let bottom = annotationCenter.y + totalHeight - viewSize.height
        
        let popoverDistanceFromAnnotationCenterX = 0.5 * annotationSize.width + spacing
        let totalWidth = popoverDistanceFromAnnotationCenterX + popoverSize.width + spacing
        let left = totalWidth - annotationCenter.x
        let right = annotationCenter.x + totalWidth - viewSize.width
        
        var x = annotationCenter.x > viewCenter.x ? viewSize.width - popoverSize.width - spacing : spacing
        var y = annotationCenter.y > viewCenter.y ? viewSize.height - popoverSize.height - spacing : spacing

        let canFitTopOrBottom = viewSize.width - annotationCenter.x > 0.5*popoverSize.width && annotationCenter.x > 0.5*popoverSize.width
        let fitsTop = top < 0 && canFitTopOrBottom
        let fitsBottom = bottom < 0 && canFitTopOrBottom
        
        let canFitLeftOrRight = viewSize.height - annotationCenter.y > 0.5*popoverSize.height && annotationCenter.y > 0.5*popoverSize.width
        let fitsLeft = left < 0 && canFitLeftOrRight
        let fitsRight = right < 0 && canFitLeftOrRight
        
        var didFitPreferredLocation = false
        for preferredLocation in preferredLocations {
            didFitPreferredLocation = true
            if preferredLocation == .top && fitsTop {
                x = annotationCenter.x - 0.5 * popoverSize.width
                y = annotationCenter.y - totalHeight
            } else if preferredLocation == .bottom && fitsBottom {
                x = annotationCenter.x - 0.5 * popoverSize.width
                y = annotationCenter.y + popoverDistanceFromAnnotationCenterY
            } else if preferredLocation == .left && fitsLeft {
                x = annotationCenter.x - totalWidth
                y = annotationCenter.y - 0.5 * popoverSize.height
            } else if preferredLocation == .right && fitsRight {
                x = annotationCenter.x + popoverDistanceFromAnnotationCenterX
                y = annotationCenter.y - 0.5 * popoverSize.height
            } else if preferredLocation == .top && top < 0 {
                y = annotationCenter.y - totalHeight
            } else if preferredLocation == .bottom && bottom < 0 {
                y = annotationCenter.y + popoverDistanceFromAnnotationCenterY
            } else if preferredLocation == .left && left < 0 {
                x = annotationCenter.x - totalWidth
            } else if preferredLocation == .right && right < 0 {
                x = annotationCenter.x + popoverDistanceFromAnnotationCenterX
            } else {
                didFitPreferredLocation = false
            }
            
            if didFitPreferredLocation {
                break
            }
        }
        
        if (!didFitPreferredLocation) {
            if (fitsTop || fitsBottom) {
                x = annotationCenter.x - 0.5 * popoverSize.width
                y = annotationCenter.y + (top < bottom ? 0 - totalHeight : popoverDistanceFromAnnotationCenterY)
            } else if (fitsLeft || fitsRight) {
                x = annotationCenter.x + (left < right ? 0 - totalWidth : popoverDistanceFromAnnotationCenterX)
                y = annotationCenter.y - 0.5 * popoverSize.height
            } else if (top < 0) {
                y = annotationCenter.y - totalHeight
            } else if (bottom < 0) {
                y = annotationCenter.y + popoverDistanceFromAnnotationCenterY
            } else if (left < 0) {
                x = annotationCenter.x - totalWidth
            } else if (right < 0) {
                x = annotationCenter.x + popoverDistanceFromAnnotationCenterX
            }
        }
       
        articleVC.view.frame = CGRect(origin: CGPoint(x: x, y: y), size: popoverSize)
    }
    
    // MARK: - Search Suggestions & Completions
    
    func updateSearchSuggestions(withCompletions completions: [PlaceSearch]) {
        guard let currentSearchString = searchBar?.text?.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines), currentSearchString != "" || completions.count > 0 else {
            let topNearbySuggestion = PlaceSearch(type: .top, sortStyle: .links, string: nil, region: nil, localizedDescription: localizedStringForKeyFallingBackOnEnglish("places-search-top-articles"), searchResult: nil)
            
            var suggestedSearches = [topNearbySuggestion]
            var recentSearches: [PlaceSearch] = []
            do {
                let moc = dataStore.viewContext
                if try moc.count(for: fetchRequestForSavedArticles) > 0 {
                    let saved = PlaceSearch(type: .saved, sortStyle: .none, string: nil, region: nil, localizedDescription: localizedStringForKeyFallingBackOnEnglish("places-search-saved-articles"), searchResult: nil)
                    suggestedSearches.append(saved)
                }
                
                let request = WMFKeyValue.fetchRequest()
                request.predicate = NSPredicate(format: "group == %@", searchHistoryGroup)
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                let results = try moc.fetch(request)
                let count = results.count
                if count > searchHistoryCountLimit {
                    for result in results[searchHistoryCountLimit..<count] {
                        moc.delete(result)
                    }
                }
                let limit = min(count, searchHistoryCountLimit)
                recentSearches = try results[0..<limit].map({ (kv) -> PlaceSearch in
                    guard let ps = PlaceSearch(object: kv.value) else {
                            throw NSError()
                    }
                    return ps
                })
            } catch let error {
                DDLogError("Error fetching recent place searches: \(error)")
            }
            
            searchSuggestionController.searches = [suggestedSearches, recentSearches, [], []]
            return
        }
        
        guard currentSearchString != "" else {
            searchSuggestionController.searches = [[], [], [], completions]
            return
        }
        
        let currentStringSuggeston = PlaceSearch(type: .text, sortStyle: .links, string: currentSearchString, region: nil, localizedDescription: currentSearchString, searchResult: nil)
        searchSuggestionController.searches = [[], [], [currentStringSuggeston], completions]
    }
    
    func handleCompletion(searchResults: [MWKSearchResult]) -> [PlaceSearch] {
        var set = Set<String>()
        let completions = searchResults.flatMap { (result) -> PlaceSearch? in
            guard let location = result.location,
                let dimension = result.geoDimension?.doubleValue,
                let title = result.displayTitle,
                let url = (self.siteURL as NSURL).wmf_URL(withTitle: title),
                let key = (url as NSURL).wmf_articleDatabaseKey,
                !set.contains(key) else {
                    return nil
            }
            set.insert(key)
            let region = MKCoordinateRegionMakeWithDistance(location.coordinate, dimension, dimension)
            return PlaceSearch(type: .location, sortStyle: .links, string: nil, region: region, localizedDescription: result.displayTitle, searchResult: result)
        }
        updateSearchSuggestions(withCompletions: completions)
        return completions
    }
    
    @objc public func showArticleURL(_ articleURL: URL) {
        guard let article = articleStore.item(for: articleURL), let title = (articleURL as NSURL).wmf_title,
            let _ = view else { // force view instantiation
            return
        }

        var region: MKCoordinateRegion? = nil
        if let coordinate = article.coordinate {
            region = MKCoordinateRegionMakeWithDistance(coordinate, 5000, 5000)
        }
        let searchResult = MWKSearchResult(articleID: 0, revID: 0, displayTitle: title, wikidataDescription: article.wikidataDescription, extract: article.snippet, thumbnailURL: article.thumbnailURL, index: nil, isDisambiguation: false, isList: false, titleNamespace: nil)
        currentSearch = PlaceSearch(type: .location, sortStyle: .links, string: nil, region: region, localizedDescription: title, searchResult: searchResult)
    }

    func updateSearchCompletionsFromSearchBarText() {
        guard let text = searchBar?.text?.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines), text != "" else {
            updateSearchSuggestions(withCompletions: [])
            return
        }
        searchFetcher.fetchArticles(forSearchTerm: text, siteURL: siteURL, resultLimit: 24, failure: { (error) in
            guard text == self.searchBar?.text else {
                return
            }
            self.updateSearchSuggestions(withCompletions: [])
        }) { (searchResult) in
            guard text == self.searchBar?.text else {
                return
            }
            
            let completions = self.handleCompletion(searchResults: searchResult.results ?? [])
            guard completions.count < 10 else {
                return
            }
            
            let center = self.mapView.userLocation.coordinate
            let region = CLCircularRegion(center: center, radius: 40075000, identifier: "world")
            self.locationSearchFetcher.fetchArticles(withSiteURL: self.siteURL, in: region, matchingSearchTerm: text, sortStyle: .links, resultLimit: 24, completion: { (locationSearchResults) in
                guard text == self.searchBar?.text else {
                    return
                }
                var combinedResults: [MWKSearchResult] = searchResult.results ?? []
                let newResults = locationSearchResults.results as [MWKSearchResult]
                combinedResults.append(contentsOf: newResults)
                let _ = self.handleCompletion(searchResults: combinedResults)
            }) { (error) in
                guard text == self.searchBar?.text else {
                    return
                }
            }
        }
    }
    
    @IBAction func closeSearch(_ sender: Any) {
        searchBar?.endEditing(true)
        searchBar?.text = currentSearch?.localizedDescription
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if let type = currentSearch?.type, type == .top || type == .saved {
            searchBar.text = nil
        }
        viewMode = .search
        updateSearchSuggestions(withCompletions: [])
        deselectAllAnnotations()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateSearchSuggestions(withCompletions: searchSuggestionController.searches[3])
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(updateSearchCompletionsFromSearchBarText), with: nil, afterDelay: 0.2)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        currentSearch = PlaceSearch(type: .text, sortStyle: .links, string: searchBar.text, region: nil, localizedDescription: searchBar.text, searchResult: nil)
        searchBar.endEditing(true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        updateViewModeFromSegmentedControl()
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return articleFetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articleFetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard viewMode == .list else {
            return
        }
        logListViewImpression(forIndexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WMFNearbyArticleTableViewCell.identifier(), for: indexPath) as? WMFNearbyArticleTableViewCell else {
            return UITableViewCell()
        }
        
        let article = articleFetchedResultsController.object(at: indexPath)
        
        cell.titleText = article.displayTitle
        cell.descriptionText = article.wikidataDescription
        cell.setImageURL(article.thumbnailURL)
        cell.articleLocation = article.location
        
        var userLocation: CLLocation?
        var userHeading: CLHeading?
        
        if locationManager.isUpdating {
            userLocation = locationManager.location
            userHeading = locationManager.heading
        }
        update(userLocation: userLocation, heading: userHeading, onLocationCell: cell)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let article = articleFetchedResultsController.object(at: indexPath)
        let title = article.savedDate == nil ? localizedStringForKeyFallingBackOnEnglish("action-save") : localizedStringForKeyFallingBackOnEnglish("action-saved")
        let saveForLaterAction = UITableViewRowAction(style: .default, title: title) { (action, indexPath) in
            CATransaction.begin()
            CATransaction.setCompletionBlock({
                let article = self.articleFetchedResultsController.object(at: indexPath)
                self.perform(action: .save, onArticle: article)
            })
            tableView.setEditing(false, animated: true)
            CATransaction.commit()
        }
        saveForLaterAction.backgroundColor = .wmf_darkBlueTint
        
        let shareAction = UITableViewRowAction(style: .default, title: localizedStringForKeyFallingBackOnEnglish("action-share")) { (action, indexPath) in
            tableView.setEditing(false, animated: true)
            let article = self.articleFetchedResultsController.object(at: indexPath)
            self.perform(action: .share, onArticle: article)
        }
        shareAction.backgroundColor = .wmf_blueTint
        return [saveForLaterAction, shareAction]
    }
    
    func update(userLocation: CLLocation?, heading: CLHeading?, onLocationCell cell: WMFNearbyArticleTableViewCell) {
        guard let articleLocation = cell.articleLocation, let userLocation = userLocation else {
            cell.configureForUnknownDistance()
            return
        }
        
        let distance = articleLocation.distance(from: userLocation)
        cell.setDistance(distance)
        
        if let heading = heading  {
            let bearing = userLocation.wmf_bearing(to: articleLocation, forCurrentHeading: heading)
            cell.setBearing(bearing)
        } else {
            let bearing = userLocation.wmf_bearing(to: articleLocation)
            cell.setBearing(bearing)
        }
    }
    
    func logListViewImpression(forIndexPath indexPath: IndexPath) {
        let article = articleFetchedResultsController.object(at: indexPath)
        tracker?.wmf_logActionImpression(inContext: listTrackerContext, contentType: article)
    }
    
    func logListViewImpressionsForVisibleCells() {
        for indexPath in listView.indexPathsForVisibleRows ?? [] {
            logListViewImpression(forIndexPath: indexPath)
        }
    }
    
    func updateDistanceFromUserOnVisibleCells() {
        guard !listView.isHidden else {
            return
        }
        let heading = locationManager.heading
        let location = locationManager.location
        for cell in listView.visibleCells {
            guard let locationCell = cell as? WMFNearbyArticleTableViewCell else {
                continue
            }
            update(userLocation: location, heading: heading, onLocationCell: locationCell)
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = articleFetchedResultsController.object(at: indexPath)
        perform(action: .read, onArticle: article)
    }
    
    // MARK: - PlaceSearchSuggestionControllerDelegate
    
    func placeSearchSuggestionController(_ controller: PlaceSearchSuggestionController, didSelectSearch search: PlaceSearch) {
        currentSearch = search
        searchBar?.endEditing(true)
    }
    
    func placeSearchSuggestionControllerClearButtonPressed(_ controller: PlaceSearchSuggestionController) {
        clearSearchHistory()
        updateSearchSuggestions(withCompletions: [])
    }
    
    func placeSearchSuggestionController(_ controller: PlaceSearchSuggestionController, didDeleteSearch search: PlaceSearch) {
        let moc = dataStore.viewContext
        guard let kv = keyValue(forPlaceSearch: search, inManagedObjectContext: moc) else {
            return
        }
        moc.delete(kv)
        do {
            try moc.save()
        } catch let error {
            DDLogError("Error removing kv: \(error.localizedDescription)")
        }
        updateSearchSuggestions(withCompletions: [])
    }
    
    // MARK: - WMFLocationManagerDelegate
    
    func updateUserLocationAnnotationViewHeading(_ heading: CLHeading) {
        guard let view = mapView.view(for: mapView.userLocation) as? UserLocationAnnotationView else {
            return
        }
        view.isHeadingArrowVisible = heading.headingAccuracy > 0 && heading.headingAccuracy < 90
        view.heading = heading.trueHeading
    }
    
    func zoomAndPanMapView(toLocation location: CLLocation) {
        let region = MKCoordinateRegionMakeWithDistance(location.coordinate, 5000, 5000)
        mapRegion = region
        performDefaultSearchIfNecessary(withRegion: region)
    }
    
    var panMapToNextLocationUpdate = true
    
    func locationManager(_ controller: WMFLocationManager, didUpdate location: CLLocation) {
        updateDistanceFromUserOnVisibleCells()
        guard panMapToNextLocationUpdate else {
            return
        }
        panMapToNextLocationUpdate = false
        zoomAndPanMapView(toLocation: location)
    }
    
    func locationManager(_ controller: WMFLocationManager, didReceiveError error: Error) {
    }
    
    func locationManager(_ controller: WMFLocationManager, didUpdate heading: CLHeading) {
        updateUserLocationAnnotationViewHeading(heading)
        updateDistanceFromUserOnVisibleCells()
    }
    
    func locationManager(_ controller: WMFLocationManager, didChangeEnabledState enabled: Bool) {
        if enabled {
            panMapToNextLocationUpdate = currentSearch == nil
            locationManager.startMonitoringLocation()
        } else {
            panMapToNextLocationUpdate = false
            locationManager.stopMonitoringLocation()
            performDefaultSearchIfNecessary(withRegion: nil)
        }
    }
    
    @IBAction func recenterOnUserLocation(_ sender: Any) {
        guard WMFLocationManager.isAuthorized() else {
            promptForLocationAccess()
            return
        }
        zoomAndPanMapView(toLocation: locationManager.location)
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updatePlaces()
    }
    
    // MARK: - UIPopoverPresentationDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: - EnableLocationViewControllerDelegate
    
    func enableLocationViewController(_ enableLocationViewController: EnableLocationViewController, didFinishWithShouldPromptForLocationAccess shouldPromptForLocationAccess: Bool) {
        guard shouldPromptForLocationAccess else {
            performDefaultSearchIfNecessary(withRegion: nil)
            return
        }
        guard WMFLocationManager.isAuthorizationNotDetermined() else {
            UIApplication.shared.wmf_openAppSpecificSystemSettings()
            return
        }
        locationManager.startMonitoringLocation()
    }
    
    // MARK: - ArticlePlaceViewDelegate
    
    func articlePlaceViewWasTapped(_ articlePlaceView: ArticlePlaceView) {
        guard let article = selectedArticlePopover?.article else {
            return
        }
        perform(action: .read, onArticle: article)
    }
    
    // MARK: - WMFAnalyticsViewNameProviding
    
    public func analyticsName() -> String {
        return "Places"
    }

    
    // MARK: - ArticlePlaceGroupViewControllerDelegate
    
    func articlePlaceGroupViewControllerDidDismiss(_ aticlePlaceGroupViewController: ArticlePlaceGroupViewController) {
        dismissGroup(andZoom: false)
    }
    
    func articlePlaceGroupViewController(_ aticlePlaceGroupViewController: ArticlePlaceGroupViewController, didDeselectPlaceView: ArticlePlaceView) {
        dismissCurrentArticlePopover()
    }
    
    func articlePlaceGroupViewController(_ aticlePlaceGroupViewController: ArticlePlaceGroupViewController, didSelectPlaceView: ArticlePlaceView) {
        showPopover(forAnnotationView: didSelectPlaceView)
    }
    
    func articlePlaceGroupViewControllerDidSelectZoom(_ aticlePlaceGroupViewController: ArticlePlaceGroupViewController) {
        dismissGroup(andZoom: true)
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === overlaySliderPanGestureRecognizer else {
            return false
        }
        
        let location = touch.location(in: view)
        let shouldReceive = location.x < listAndSearchOverlayContainerView.frame.maxX && abs(location.y - listAndSearchOverlayContainerView.frame.maxY - 10) < 32
        return shouldReceive
    }
}

