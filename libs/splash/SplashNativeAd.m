//
//  SplashNativeAd.m
//  IFLYAdSample
//
//  Created by JzProl.m.Qiezi on 2016/12/19.
//  Copyright © 2016年 iflytek. All rights reserved.
//

#import "SplashNativeAd.h"
#import "SkipButton.h"
#import <IFLYAd.h>
#define XH_OverIPhoneX  ([UIScreen mainScreen].bounds.size.height >= 812)
#define XH_ScreenH    [UIScreen mainScreen].bounds.size.height
#define XH_ScreenW    [UIScreen mainScreen].bounds.size.width

@interface SplashNativeAd ()<IFLYNativeAdDelegate>

@property (nonatomic, strong) IFLYNativeAd *nativeAd; // 讯飞nativeAd
@property (nonatomic, strong) IFLYAdData *nativeAdData;

@property (nonatomic, strong) UIView *fatherView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) SkipButton * skipButton;
@property (nonatomic, assign) NSInteger traceDuration;
@property (nonatomic, copy) dispatch_source_t skipTimer;
@property (nonatomic, assign) BOOL hasRemovedUI;
@property (nonatomic, assign) BOOL nativeAdIsShowing; // 广告是否正在展示

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, assign) BOOL attached;

@end

@implementation SplashNativeAd

#pragma mark -生命周期
-(instancetype)initWithLogo:(UIImage *)logo adUnitId:(NSString*)adUnitId{
    self = [super init];
    if (self) {
        [self initConfigWithlogo:logo adUnitId:adUnitId];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_nativeAd) {
        _nativeAd = nil;
    }
}

#pragma mark -私有方法
-(void)initConfigWithlogo:(UIImage *)logo adUnitId:(NSString*)adUnitId{
    
    // 1. fatherView
    UIView *fatherView = [[UIView alloc]init];
    
    CGFloat father_width = XH_ScreenW;
    CGFloat father_height = 0;
    if (XH_OverIPhoneX) {
        father_height = XH_ScreenW*16.0/9.0;
        if (father_height < XH_ScreenH *0.8) {
            father_height = XH_ScreenH*0.8;
            father_width  = father_height*9.0/16.0;
        }
    }else{
        father_height = XH_ScreenW*3.0/2.0;
        if (father_height < XH_ScreenH *0.8) {
            father_height = XH_ScreenH*0.8;
            father_width  = father_height*2.0/3.0;
        }
    }
    
    fatherView.frame = CGRectMake(-(father_width - XH_ScreenW)/2.0, 0, father_width, father_height);
    self.fatherView = fatherView;

    _nativeAd = [[IFLYNativeAd alloc]initWithAdUnitId:adUnitId];
    _nativeAd.delegate = self;

    [self.nativeAd setParamValue:[NSNumber numberWithBool:NO] forKey:IFLYAdKeyNeedLocation];
    [self.nativeAd setParamValue:[NSNumber numberWithBool:NO] forKey:IFLYAdKeyNeedAudio];
    
    // 竞价广告设置底价
//    [self.nativeAd setParamValue:@(5.0) forKey:IFLYAdKeyBIDFloor];
    
    // 私有订单，设置订单信息
    NSMutableArray<IFLYAdDeal*>* deals = [NSMutableArray<IFLYAdDeal*> arrayWithCapacity:1];
    IFLYAdDeal* deal1 = [[IFLYAdDeal alloc] init];
    deal1.id = @"sdktest01";
    deal1.bidFlool = 5.0;
    [deals addObject:deal1];

    IFLYAdDeal* deal2 = [[IFLYAdDeal alloc] init];
    deal2.id = @"sdktest02";
    deal2.bidFlool = 10.0;

    [deals addObject:deal2];
    [self.nativeAd setParamValue:deals forKey:IFLYAdKeyPMP];
        
    
    __weak typeof(self) weakself = self;
    self.nativeAd.didLeaveApp = ^{
        NSLog(@"didLeaveApp");
        [weakself removeUI];
    };
    
    self.nativeAd.dismissBlock = ^{
        NSLog(@"dismissBlock");
        [weakself removeUI];
    };
    
    
    // 3. containerView
    self.containerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, XH_ScreenW, XH_ScreenH)];
    self.containerView.backgroundColor = [UIColor blackColor];
    self.containerView.alpha = 0.0;
    self.containerView.hidden = YES;

    if (logo) {
        // 4. logoIV
        UIImageView *logoIV = [[UIImageView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.fatherView.frame), XH_ScreenW, XH_ScreenH - CGRectGetMaxY(self.fatherView.frame))];
        logoIV.contentMode = UIViewContentModeCenter;
        logoIV.image = logo;
        [self.containerView addSubview:logoIV];
    }
}

-(void)removeUI{
    
    if (self.hasRemovedUI == YES) {
        return;
    }
    
    self.hasRemovedUI = YES;
    self.nativeAdIsShowing = NO;
    
    if(_skipTimer){
        dispatch_source_cancel(_skipTimer);
        _skipTimer = nil;
    }
    
    if(_skipButton){
        [_skipButton removeFromSuperview];
        _skipButton =nil;
    }
    
    self.traceDuration = 0;
    
    if (_containerView) {
        [UIView animateWithDuration:0.2 animations:^{
            self.containerView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self removeOnly];
        }];
    }
}

-(void)removeOnly{
    
    if(_skipTimer){
        dispatch_source_cancel(_skipTimer);
        _skipTimer = nil;
    }
    
    if(_skipButton){
        [_skipButton removeFromSuperview];
        _skipButton =nil;
    }
    
    if (_containerView) {
        [_containerView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if(obj){
                [obj removeFromSuperview];
                obj=nil;
            }
        }];
        [_containerView removeFromSuperview];
        _containerView = nil;
    }
    
//    if (_nativeAd) {
//        _nativeAd = nil;
//    }
}

-(void)addSkipButton{
    
    SkipType skipType = SkipTypeTimeText;
    if (self.traceDuration <= 0) {
        skipType = SkipTypeText;
    }
    
    self.skipButton = [[SkipButton alloc] initWithSkipType:skipType];
    [self.skipButton addTarget:self action:@selector(skipButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipButton setTitleWithSkipType:skipType duration:self.traceDuration];
    [_containerView addSubview:self.skipButton];
    
    if (skipType == SkipTypeTimeText) {
        [self startSkipDispathTimerWithSkipType:skipType];
    }
    
}

- (void)viewTapped:(UITapGestureRecognizer *)gr {
    [_nativeAd clickAd:self.fatherView];
    [self.containerView removeFromSuperview];
}

-(void)skipButtonClick:(UIButton *)sender{
    [self removeUI];
}

-(void)startSkipDispathTimerWithSkipType:(SkipType)skipType{
    
    __weak __typeof__(self) weakSelf = self;
    
    NSTimeInterval period = 1.0;
    _skipTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_skipTimer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_skipTimer, ^{
        __strong __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            if(strongSelf.traceDuration<=0){
                [strongSelf removeUI];
                return;
            }
            
            [strongSelf.skipButton setTitleWithSkipType:skipType duration:self.traceDuration];
            strongSelf.traceDuration--;
        }
        
    });
    
    dispatch_resume(_skipTimer);
    
}

#pragma mark -外部方法
-(void)loadNativeAd{
    _nativeAd.currentViewController = [[[UIApplication sharedApplication] windows] objectAtIndex:0].rootViewController;
    [_nativeAd loadAd];
}

-(void)showNativeAd{
    
    __weak __typeof__(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
         __strong __typeof(self) strongSelf = weakSelf;
        if(!strongSelf){
            return;
        }
        
        /*开始渲染广告界面*/
        /*广告详情图*/
        UIImageView *imgV = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
        [strongSelf.fatherView addSubview:imgV];
    
//        NSURL *imageURL = [NSURL URLWithString:strongSelf.nativeAdData.img.url];
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
//            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                imgV.image =[UIImage imageWithData:imageData];
//            });
//        });
        
        [IFLYAdTool downloadImageFromURL:strongSelf.nativeAdData.img.url completed:^(UIImage * _Nonnull image, NSError * _Nonnull error, NSURL * _Nonnull imageURL) {
            if(!error){
                // 此处示例使用高斯模糊处理图片，不使用时 imgV.image =image;
//                imgV.image = [IFLYAdTool gaussianBlurImage:image withHeight:1590 andRadius:8.0];
                imgV.image =image;
            }
        }];
        
        /*广告Icon*/
        UIImageView *iconV = [[UIImageView alloc] initWithFrame:CGRectMake(10, 5, 60, 60)];
        [strongSelf.fatherView addSubview:iconV];
    
//        NSURL *iconURL = [NSURL URLWithString:strongSelf.nativeAdData.icon.url];
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
//            NSData *imageData = [NSData dataWithContentsOfURL:iconURL];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                iconV.image = [UIImage imageWithData:imageData];
//            });
//        });
        
        [IFLYAdTool downloadImageFromURL:strongSelf.nativeAdData.icon.url completed:^(UIImage * _Nonnull image, NSError * _Nonnull error, NSURL * _Nonnull imageURL) {
            if(!error){
                iconV.image = image;
            }
        }];
        
        /*广告标题*/
        UILabel *txt = [[UILabel alloc] initWithFrame:CGRectMake(80, 5, 100, 35)];
        txt.text = strongSelf.nativeAdData.title;
        [strongSelf.fatherView addSubview:txt];
        
        /*广告描述*/
        UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(80, 45, 200, 20)];
        desc.text = strongSelf.nativeAdData.content;
        [strongSelf.fatherView addSubview:desc];
        
        
        /*注册点击事件*/
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:strongSelf action:@selector(viewTapped:)];
        [strongSelf.fatherView addGestureRecognizer:tap];
        
        strongSelf.nativeAd.currentViewController = [[[UIApplication sharedApplication] windows] objectAtIndex:0].rootViewController;
    
        [strongSelf.containerView addSubview:strongSelf.fatherView];
        [[[[UIApplication sharedApplication] windows] objectAtIndex:0] addSubview:self.containerView];

        /*广告展示后，调用attachAd上报曝光*/
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionAllowUserInteraction  animations:^{
            strongSelf.containerView.alpha = 1.0;
            strongSelf.containerView.hidden = NO;
        }completion:^(BOOL finished) {
            [strongSelf.nativeAd attachWindowAd:strongSelf.containerView];
        }];

        [strongSelf addSkipButton];
    
        [[NSNotificationCenter defaultCenter] addObserver:strongSelf selector:@selector(onApplicationUnActive) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:strongSelf selector:@selector(onApplicationEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:strongSelf selector:@selector(onApplicationActive) name:UIApplicationWillEnterForegroundNotification object:nil];
    });
    
}

#pragma mark - 前后台系统通知的监听
- (void)onApplicationUnActive {
    NSLog(@"nativa ad 不再活跃");
}

- (void)onApplicationEnterBackground {
    NSLog(@"nativa ad 进入后台");
    if (self.nativeAdIsShowing == YES) {
        [self removeUI];
    }
}

- (void)onApplicationActive {
    NSLog(@"nativa ad 回到前台");
    if (self.nativeAdIsShowing == YES) {
        [self removeUI];
    }
}


#pragma mark - IFLYNativeAdDelegate
-(void)onNativeAdReceived:(IFLYAdData *)nativeAdData{
    NSLog(@"native onNativeAdReceived");
    
    _nativeAdData= nativeAdData;
    self.traceDuration = 6;
    
    // 竞价广告曝光前设置实际成交价
//    NSNumber* price =[_nativeAdData price];
//    if(price){
//        [self.nativeAd setParamValue:price forKey:IFLYAdKeyAuctionPrice];
//    }
    
    [self showNativeAd];
    
}

-(void)onNativeAdFailed:(IFLYAdError *)error{
    NSLog(@"native onNativeAdFailed error:%d",error.errorCode);
    [self removeOnly];
}

@end
