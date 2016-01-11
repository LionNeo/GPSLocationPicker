//
//  GPSLocationPicker.h
//  vsfa
//
//  Created by long on 15/8/13.
//  Copyright (c) 2015年 AZYK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#define kZeroLocation [[CLLocation alloc] initWithLatitude:0 longitude:0]
#define kLocationFailedError [NSError errorWithDomain:@"location failed" code:-100 userInfo:nil]

typedef void (^LocationResult)(CLLocation *location, NSError *error);

@interface GPSLocationPicker : NSObject

+ (instancetype)shareGPSLocationPicker;
/**
 * @brief 启动定位，并设置定位成功回调
 */
- (void)startLocationAndCompletion:(LocationResult)completion;

/**
 * @brief 停止定位
 */
- (void)stop;

/**
 * @brief 反地理编码，根据传入坐标，解析地理位置
 */
- (void)geocodeAddressWithCoordinate:(CLLocationCoordinate2D)loc completion:(void (^) (NSString *address))completion;

@end
