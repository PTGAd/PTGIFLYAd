//
//  SplashNativeAd.h
//  IFLYAdSample
//
//  Created by JzProl.m.Qiezi on 2016/12/19.
//  Copyright © 2016年 iflytek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SplashNativeAd : NSObject

-(instancetype)initWithLogo:(UIImage *)logo adUnitId:(NSString*)adUnitId;
-(void)loadNativeAd;

@end

