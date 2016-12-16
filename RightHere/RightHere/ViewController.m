/*
 Copyright 2016 Google Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#import "ViewController.h"
#import "MapService.h"
#import "MaterialFlexibleHeader.h"
#import "MaterialPalettes.h"

@interface ViewController ()
@property MapService *service;
@property NSArray *places;
@property MDCFlexibleHeaderViewController *headerViewController;
@property UIImageView *imageView;
@property UILabel *pizza;

@property CLLocation *targetLocation;
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

  CGSize pizzaSize = CGSizeMake(96, 96);
  self.pizza = [[UILabel alloc] initWithFrame:CGRectMake(self.imageView.bounds.size.width / 2 - pizzaSize.width / 2,
                                                         self.imageView.bounds.size.height / 2 - pizzaSize.height / 2,
                                                         pizzaSize.width,
                                                         pizzaSize.height)];
  self.pizza.font = [UIFont systemFontOfSize:72];
  self.pizza.textAlignment = NSTextAlignmentCenter;
  self.pizza.text = @"🍕";
  [self.headerViewController.headerView addSubview:self.pizza];


  self.service = [[MapService alloc] init];
  __weak ViewController *weakSelf = self;
  self.service.placesDidUpdate = ^(NSArray *places, NSError *error) {
    weakSelf.places = places;

    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf.collectionView reloadData];
      [weakSelf.collectionView setNeedsDisplay];
      [weakSelf updatePizzaOrientation:weakSelf.service.currentHeading];
    });
  };
  self.service.headingDidUpdate = ^(CLHeading *heading) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf updatePizzaOrientation:heading];
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
  self.targetLocation = location;

  [self updatePizzaOrientation:self.service.currentHeading];

  [self.service fetchMapAtLocation:location callback:^(UIImage *image, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.headerViewController.headerView shiftHeaderOnScreenAnimated:YES];
      self.imageView.image = image;
      [self.imageView setNeedsDisplay];
    });
  }];
}

#pragma mark - Angle calculations

double RadiansToDegrees(double radian) {
  return radian / M_PI *  180;
}

double DegreesToRadians(double degrees) {
  return degrees / 180 * M_PI;
}

- (void)updatePizzaOrientation:(CLHeading *)heading {
  double pizzaOrientation = DegreesToRadians(205.0);

  if (!heading || !self.targetLocation || !self.service.currentLocation) {
    self.pizza.transform = CGAffineTransformMakeRotation(pizzaOrientation);
    return;
  }

  double targetAngleRadians = [self radiansFrom:self.service.currentLocation to:self.targetLocation];
  double orientationRadians = DegreesToRadians(heading.magneticHeading);

  self.pizza.transform = CGAffineTransformMakeRotation(targetAngleRadians - orientationRadians - pizzaOrientation);
}

- (double)radiansFrom:(CLLocation *)oneLocation to:(CLLocation *)anotherLocation {
  double lat1 = oneLocation.coordinate.latitude; double lng1 = oneLocation.coordinate.longitude;
  double lat2 = anotherLocation.coordinate.latitude; double lng2 = anotherLocation.coordinate.longitude;

  double angle = atan2(lat2 - lat1, lng2 - lng1);
  return angle;
}

@end
