//
//  GPSValidLocationPicker.m
//  GPSLocationPicker
//
//  Created by long on 15/10/10.
//  Copyright © 2015年 long. All rights reserved.
//

#import "GPSValidLocationPicker.h"
#import "GPSLocationPicker.h"
#import "MBProgressHUD.h"
#import "MBProgressHUD+DetailLabelAlignment.h"

#define kDefaultValue -100

@interface GPSValidLocationPicker () <CLLocationManagerDelegate, MBProgressHUDDelegate>
{
    CLLocationAccuracy _nowPrecision;//定位拿到的精度
    CLLocationDistance _collectDistance;//当前采集到的点与用户传进来的点的距离
    NSTimer *_timer;
    
    MBProgressHUD *_waitView;
    int _totalTime;
    ValidLocationResult _locationResultBlock;
}

@end

@implementation GPSValidLocationPicker

static GPSValidLocationPicker *_ValidLocationPicker = nil;

+ (instancetype)shareGPSValidLocationPicker
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ValidLocationPicker = [[self alloc] init];
    });
    return _ValidLocationPicker;
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ValidLocationPicker = [super allocWithZone:zone];
    });
    return _ValidLocationPicker;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self resetDefaultVariable];
    }
    return self;
}

- (void)resetDefaultVariable
{
    _nowPrecision    = kDefaultValue;
    _timeoutPeriod   = kDefaultValue;
    _precision       = kDefaultValue;
    _validDistance   = kDefaultValue;
    _collectDistance = kDefaultValue;
    _mode = GPSValidLocationPickerModeDeterminateHorizontalBar;
    _showWaitView    = YES;
    _showLocTime     = YES;
    _showDetailInfo  = YES;
}

#pragma mark - 启动定位
- (void)startLocationAndCompletion:(ValidLocationResult)completion
{
    if (_locationResultBlock) {
        _locationResultBlock = nil;
    }
    _locationResultBlock = completion;
    
    _totalTime = self.timeoutPeriod;
    //显示等待视图
    if (self.showWaitView) {
        [self beginWaiting:@"定位中，请稍后。。。" mode:_totalTime>0?[self getMatchMode]:MBProgressHUDModeIndeterminate];
    }
    
    if (_timeoutPeriod > 0) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
    
    [self startGetLocation];
}

- (MBProgressHUDMode)getMatchMode
{
    switch (self.mode) {
        case GPSValidLocationPickerModeDeterminateHorizontalBar:
            return MBProgressHUDModeDeterminateHorizontalBar;
            
        case GPSValidLocationPickerModeAnnularDeterminate:
            return MBProgressHUDModeAnnularDeterminate;
            
        case GPSValidLocationPickerModeIndeterminate:
            return MBProgressHUDModeIndeterminate;
            
        case GPSValidLocationPickerModeDeterminate:
            return MBProgressHUDModeDeterminate;
        default:
            break;
    }
}

- (void)startGetLocation
{
    __weak typeof(self) weakSelf = self;
    [[GPSLocationPicker shareGPSLocationPicker] startLocationAndCompletion:^(CLLocation *location, NSError *error) {
        [weakSelf judgeNowLocationIsValid:location];
    }];
}

#pragma mark - 判断当前采集到的坐标是否符合标准
- (void)judgeNowLocationIsValid:(CLLocation *)pickCoord
{
    _nowPrecision = pickCoord.horizontalAccuracy;
    
    //首先判断坐标是否有效
    if ( pickCoord.coordinate.latitude == 0 || pickCoord.coordinate.longitude == 0) {
        if (_timeoutPeriod == kDefaultValue) {
            [self locationTimeOut:nil];
        }
        return;
    }
    
    if (_precision == kDefaultValue && _validDistance == kDefaultValue) {
        //没有精度和有效距离的限制,当前坐标有效
        [self locationSuccess:pickCoord];
        return;
    }
    
    BOOL coordIsValid = YES;
    
    if (_precision != kDefaultValue && _nowPrecision > _precision) {
        coordIsValid = NO;
    }
    if (_validDistance != kDefaultValue
        && _nowCoordinate.latitude != 0
        && _nowCoordinate.longitude != 0
        && [self coordIsValid:pickCoord] == NO) {
        coordIsValid = NO;
    }
    //如果坐标符合期望精度及有效距离
    if (coordIsValid) {
        NSLog(@"符合了标准:%d", coordIsValid);
        [self locationSuccess:pickCoord];
    } else {
        if (_timeoutPeriod == kDefaultValue) {
            [self locationTimeOut:nil];
        }
    }
}

#pragma mark - 显示更新定位进度
- (void)updateProgress
{
    if (_timeoutPeriod == -1) {
        //定位超时
        [self locationTimeOut:[NSError errorWithDomain:@"location failed" code:-1 userInfo:nil]];
        return;
    }
    _timeoutPeriod--;
    if (self.showWaitView) {
        if (!_waitView) {
            [self beginWaiting:@"定位中，请稍后。。。" mode:MBProgressHUDModeDeterminateHorizontalBar];
        }
        _waitView.detailsLabelText = [self getGPSDetailInfo];
    }
    
     //更新进度条
    if (_totalTime > 0) {
        _waitView.progress = (float)(_totalTime-_timeoutPeriod)/_totalTime;
    }
}

#pragma mark - 拿到符合标准的坐标
- (void)locationSuccess:(CLLocation *)coord
{
    NSLog(@"%s", __FUNCTION__);
    if (_timer && [_timer isValid]) {
        [_timer invalidate];
    }
    [_waitView hide:YES afterDelay:0];
    [[GPSLocationPicker shareGPSLocationPicker] stop];
    if (_locationResultBlock) {
        _locationResultBlock(coord, nil);
    }
}

#pragma mark - 定位超时
- (void)locationTimeOut:(NSError *)error
{
    NSLog(@"%s", __FUNCTION__);
    if (_timer && [_timer isValid]) {
        [_timer invalidate];
    }
    [[GPSLocationPicker shareGPSLocationPicker] stop];
    [_waitView hide:YES afterDelay:0];
    if (_locationResultBlock) {
        _locationResultBlock(kZeroLocation, kLocationFailedError);
    }
}

- (NSString *)getGPSDetailInfo
{
    //是否显示gps定位时间
    NSMutableString *detailStr = [NSMutableString string];
    if (self.showLocTime) {
        if (_timeoutPeriod != kDefaultValue) {
            if (_timeoutPeriod >= 0) {
                [detailStr appendString:[NSString stringWithFormat:@"等待时间:%d", _timeoutPeriod]];
            } else {
                [detailStr appendString:@"定位超时"];
            }
        }
    }
    
    //如果不显示详情，则直接返回
    if (self.showDetailInfo == NO) {
        return detailStr;
    }
    if (_precision != kDefaultValue) {
        [detailStr appendString:[NSString stringWithFormat:@"\n期望精度:%.0f米", self.precision]];
        if (_nowPrecision != kDefaultValue) {
            [detailStr appendString:[NSString stringWithFormat:@"\n当前精度:%.0f米", _nowPrecision]];
        }
    }
    if (_validDistance != kDefaultValue) {
        [detailStr appendString:[NSString stringWithFormat:@"\n期望距离:%.0f米", self.validDistance]];
        if (_collectDistance != kDefaultValue) {
            [detailStr appendString:[NSString stringWithFormat:@"\n当前距离:%.0f米", _collectDistance]];
        } else {
            [detailStr appendFormat:@"\n当前距离∞米"];
        }
    }
    NSString *info = [detailStr stringByTrimmingCharactersInSet:[NSCharacterSet  whitespaceAndNewlineCharacterSet]];
    return info.length == 0 ? @"" : info;
}

- (BOOL)coordIsValid:(CLLocation *)nowLocation
{
    if (nowLocation.coordinate.latitude == 0 || nowLocation.coordinate.longitude == 0) {
        return NO;
    }
    CLLocation *lastLocation = [[CLLocation alloc] initWithLatitude:self.nowCoordinate.latitude longitude:self.nowCoordinate.longitude];
    
    CLLocationDistance distance = [nowLocation distanceFromLocation:lastLocation];
    
    _collectDistance = distance;
    NSLog(@"距离:%f", distance);
    if (distance <= _validDistance) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - 显示等待视图
-(void)beginWaiting:(NSString *)message mode:(MBProgressHUDMode)mode
{
    if (!_waitView) {
        _waitView = [[MBProgressHUD alloc] initWithView:[UIApplication sharedApplication].keyWindow];
        [[UIApplication sharedApplication].keyWindow addSubview:_waitView];
        _waitView.delegate = self;
        _waitView.square = NO;
        _waitView.mode = mode;
        [_waitView setDetailLabelAlignment:NSTextAlignmentLeft];
    }
    
    _waitView.labelText = message;
    _waitView.detailsLabelText = [self getGPSDetailInfo];
    [_waitView show:YES];
}

- (void)hudWasHidden:(MBProgressHUD *)hud
{
    [_waitView removeFromSuperview];
    _waitView = nil;
}

@end
