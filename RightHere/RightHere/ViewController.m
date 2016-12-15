//
//  ViewController.m
//  RightHere
//
//  Created by Alastair Tse on 11/11/16.
//  Copyright © 2016 liquidx. All rights reserved.
//

#import "ViewController.h"
#import "MapService.h"
#import "MaterialFlexibleHeader.h"
#import "MaterialPalettes.h"

@interface ViewController ()
@property MapService *service;
@property NSArray *places;
@property MDCFlexibleHeaderViewController *headerViewController;
@property UIImageView *imageView;
@end

@implementation ViewController

- (id)init {
  self = [super init];
  if (self) {
    _headerViewController = [MDCFlexibleHeaderViewController new];
    [self addChildViewController:_headerViewController];
  }
  return self;
}


- (void)viewDidLoad {
  [super viewDidLoad];

  self.styler.cellStyle = MDCCollectionViewCellStyleDefault;
  [self.collectionView registerClass:[MDCCollectionViewTextCell class]
          forCellWithReuseIdentifier:@"cell"];

  _headerViewController.view.frame = self.view.bounds;
  [self.view addSubview:_headerViewController.view];
  [_headerViewController didMoveToParentViewController:self];

  self.headerViewController.headerView.backgroundColor = [MDCPalette yellowPalette].tint500;
  self.headerViewController.headerView.minimumHeight = 160;
  self.headerViewController.headerView.maximumHeight = 160;

  self.headerViewController.headerView.trackingScrollView = self.collectionView;
  self.headerViewController.headerView.shiftBehavior = MDCFlexibleHeaderShiftBehaviorEnabled;

  self.imageView = [[UIImageView alloc] initWithFrame:self.headerViewController.headerView.bounds];
  self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  self.imageView.clipsToBounds = YES;
  [self.headerViewController.headerView addSubview:self.imageView];


  self.service = [[MapService alloc] init];
  __weak ViewController *weakSelf = self;
  self.service.placesDidUpdate = ^(NSArray *places, NSError *error) {
    weakSelf.places = places;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf.collectionView reloadData];
      [weakSelf.collectionView setNeedsDisplay];
    });
  };
  [self.service fetchLocation];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return self.places.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return 1;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView cellHeightAtIndexPath:(NSIndexPath *)indexPath {
  return 72;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
  MDCCollectionViewTextCell *textCell = (MDCCollectionViewTextCell *)cell;
  textCell.textLabel.text = self.places[indexPath.row][@"name"];
  textCell.detailTextLabel.text = self.places[indexPath.row][@"vicinity"];
  return textCell;
}



- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (scrollView == self.headerViewController.headerView.trackingScrollView) {
    [self.headerViewController.headerView trackingScrollViewDidScroll];
  }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  if (scrollView == self.headerViewController.headerView.trackingScrollView) {
    [self.headerViewController.headerView trackingScrollViewDidEndDecelerating];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
  if (scrollView == self.headerViewController.headerView.trackingScrollView) {
    [self.headerViewController.headerView trackingScrollViewDidEndDraggingWillDecelerate:decelerate];
  }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
  if (scrollView == self.headerViewController.headerView.trackingScrollView) {
    [self.headerViewController.headerView trackingScrollViewWillEndDraggingWithVelocity:velocity
                                                                    targetContentOffset:targetContentOffset];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  [super collectionView:collectionView didSelectItemAtIndexPath:indexPath];
  NSDictionary *place = [self.places objectAtIndex:indexPath.row];
  NSString *lat = place[@"geometry"][@"location"][@"lat"];
  NSString *lng = place[@"geometry"][@"location"][@"lng"];
  CLLocation *location = [[CLLocation alloc] initWithLatitude:[lat doubleValue]
                                                    longitude:[lng doubleValue]];
  [self.service fetchMapAtLocation:location callback:^(UIImage *image, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.headerViewController.headerView shiftHeaderOnScreenAnimated:YES];
      self.imageView.image = image;
      [self.imageView setNeedsDisplay];
    });
  }];
}

@end