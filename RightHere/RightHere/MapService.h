//
//  MapService.h
//  RightHere
//
//  Created by Alastair Tse on 11/11/16.
//  Copyright © 2016 liquidx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface MapService : NSObject

@property (nonatomic, copy) void (^placesDidUpdate)(NSArray *places, NSError *error);
@property (nonatomic, copy) void (^headingDidUpdate)(CLHeading *heading);
@property (nonatomic, readonly) CLLocation *currentLocation;
@property (nonatomic, readonly) CLHeading *currentHeading;

- (void)fetchLocation;
- (void)nearbyPlaces:(void (^)(NSArray *places, NSError *error))callback;
- (void)fetchMapAtLocation:(CLLocation *)location callback:(void (^)(UIImage *image, NSError *error))callback;

@end
