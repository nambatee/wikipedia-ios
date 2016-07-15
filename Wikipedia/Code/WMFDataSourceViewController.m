#import "WMFDataSourceViewController.h"
#import "WMFDataSource.h"
#import "WMFCollectionViewTableLayout.h"

@interface WMFDataSourceViewController ()
@property (nonnull, nonatomic, strong) WMFDataSource *dataSource;
@property (nonatomic) WMFDataSourceViewControllerStyle style;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewLayout *collectionViewLayout;
@end

@implementation WMFDataSourceViewController

#pragma mark - Initializers

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil dataSource:(WMFDataSource *)dataSource style:(WMFDataSourceViewControllerStyle)style {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.style = style;
        self.dataSource = dataSource;
    }
    return self;
}

- (instancetype)initWithDataSource:(WMFDataSource *)dataSource style:(WMFDataSourceViewControllerStyle)style {
    return [self initWithNibName:nil bundle:nil dataSource:dataSource style:style];
}

- (instancetype)initWithDataSource:(WMFDataSource *)dataSource {
    return [self initWithDataSource:dataSource style:WMFDataSourceViewControllerStyleTable];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithDataSource:[WMFDataSource new] style:WMFDataSourceViewControllerStyleTable];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithNibName:nil bundle:nil];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    switch (self.style) {
        case WMFDataSourceViewControllerStyleCollection:
            [self setupCollectionView];
            break;
        default:
            [self setupTableView];
            break;
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (void)setupCollectionView {
    self.collectionViewLayout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.collectionViewLayout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.view addSubview:self.collectionView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.dataSource addObserver:self];
}


- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.dataSource removeObserver:self];
}

#pragma mark - WMFDataSourceViewController

- (void)configureCell:(WMFCell *)cell forItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
    
}

- (void)reloadCellsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    [self.collectionView reloadItemsAtIndexPaths:indexPaths];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSource.numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataSource numberOfItemsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [UITableViewCell new];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.dataSource.numberOfSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.dataSource numberOfItemsInSection:section];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
}

#pragma mark - WMFDataSourceObserver

- (void)dataSourceDidChangeContent:(WMFDataSource *)dataSource {
    [self.tableView reloadData];
}


@end
