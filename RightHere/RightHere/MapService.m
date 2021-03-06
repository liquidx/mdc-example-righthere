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

#import "MapService.h"
#import <CoreLocation/CoreLocation.h>
#import "MaterialSnackbar.h"

@interface MapService () <CLLocationManagerDelegate>
@property NSString *apiKey;
@property NSString *nearbySearchURL;
@property CLLocationManager *locationManager;
@property CLLocation *currentLocation;
@property CLHeading *currentHeading;
@property NSDate *lastUpdate;
@end

@implementation MapService

- (id)init {
  self = [super init];
  if (self) {
    self.apiKey = @"AIzaSyDzsVC2dPUq_3McD0EFnbdzVJ18Uti1BwE";
    self.nearbySearchURL = @"https://maps.googleapis.com/maps/api/place/nearbysearch/json";
    self.currentLocation = [[CLLocation alloc] initWithLatitude:40.740000 longitude:-74.000000];
    self.lastUpdate = nil;
  }
  return self;
}

- (void)fetchLocation {
  self.locationManager = [[CLLocationManager alloc] init];
  self.locationManager.delegate = self;
  [self.locationManager requestWhenInUseAuthorization];

  [self.locationManager requestLocation];

  self.locationManager.distanceFilter = 100;
  [self.locationManager startUpdatingLocation];
  [self.locationManager startUpdatingHeading];
}


- (void)nearbyPlaces:(void (^)(NSArray *places, NSError *error))callback {
  NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
  NSURLComponents *components = [NSURLComponents componentsWithString:_nearbySearchURL];
  components.query = [NSString stringWithFormat:
                          @"key=%@&location=%f,%f&keyword=pizza",
                          _apiKey,
                          _currentLocation.coordinate.latitude,
                          _currentLocation.coordinate.longitude];

  [[session dataTaskWithURL:components.URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    if (error) {
      callback(nil, error);
      return;
    }

    NSError *jsonError = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError) {
      callback(nil, error);
      return;
    }

    if ([result isKindOfClass:[NSDictionary class]]) {
      NSDictionary *resultDictionary = (NSDictionary *)result;
      if (![resultDictionary[@"status"] isEqualToString:@"OK"]) {
        callback(nil, nil);
        return;
      }

      callback(resultDictionary[@"results"], nil);
      return;
    }

    callback(nil, nil);
  }] resume];

}

- (void)fetchMapAtLocation:(CLLocation *)location callback:(void (^)(UIImage *image, NSError *error))callback {
  NSString *baseURL = @"https://maps.googleapis.com/maps/api/staticmap";
  NSString *parameters =
    @"&key=%@"
    @"&center=%f,%f"
    @"&zoom=17"
    @"&size=640x320"
    //@"&style=element:labels|visibility:off"
    @"&style=feature:landscape|element:geometry|saturation:-100"
    @"&style=feature:water|saturation:-100|invert_lightness:true";


  NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
  NSURLComponents *components = [NSURLComponents componentsWithString:baseURL];
  components.query = [NSString stringWithFormat:parameters,
                      _apiKey,
                      location.coordinate.latitude,
                      location.coordinate.longitude];
  [[session dataTaskWithURL:components.URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    UIImage *image = [UIImage imageWithData:data scale:[[UIScreen mainScreen] scale]];
    callback(image, error);
  }] resume];
}


- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  self.currentLocation = [locations firstObject];
  if (self.lastUpdate && -[self.lastUpdate timeIntervalSinceNow] < 30) {
    return;  // Too frequent.
  }
  if (self.currentLocation) {
    NSString *debugMessage = [NSString stringWithFormat:@"Lat Lng: %f, %f", self.currentLocation.coordinate.latitude, self.currentLocation.coordinate.longitude];
    [self nearbyPlaces:self.placesDidUpdate];
    [MDCSnackbarManager showMessage:[MDCSnackbarMessage messageWithText:debugMessage]];
    self.lastUpdate = [NSDate date];
  }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
  self.currentHeading = newHeading;
  if (self.headingDidUpdate) {
    self.headingDidUpdate(newHeading);
  }
}


- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  NSLog(@"Location Error: %@", [error localizedDescription]);
}

@end
