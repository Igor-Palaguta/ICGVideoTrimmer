//
//  ICGVideoTrimmerView.m
//  ICGVideoTrimmer
//
//  Created by Huong Do on 1/18/15.
//  Copyright (c) 2015 ichigo. All rights reserved.
//

#import "ICGVideoTrimmerView.h"
#import "ICGThumbView.h"
#import "ICGRulerView.h"

#import <AVFoundation/AVFoundation.h>

@interface ICGVideoTrimmerView() <UIScrollViewDelegate>

@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) UIView *frameView;
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) AVAssetImageGenerator *imageGenerator;

@property (strong, nonatomic) UIView *leftOverlayView;
@property (strong, nonatomic) UIView *rightOverlayView;
@property (strong, nonatomic) ICGThumbView *leftThumbView;
@property (strong, nonatomic) ICGThumbView *rightThumbView;

@property (strong, nonatomic) UIView *topBorder;
@property (strong, nonatomic) UIView *bottomBorder;

@property (strong, nonatomic) UIView* playbackPointerView;

@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval endTime;

@property (nonatomic) CGFloat widthPerSecond;

@property (nonatomic) CGPoint leftStartPoint;
@property (nonatomic) CGPoint rightStartPoint;
@property (nonatomic) CGFloat overlayWidth;

@end

@implementation ICGVideoTrimmerView

- (void)dealloc
{
    self.scrollView.delegate = nil;
}

#pragma mark - Initiation

- (instancetype)initWithAsset:(AVAsset *)asset
{
    return [self initWithFrame:CGRectZero asset:asset];
}

- (instancetype)initWithFrame:(CGRect)frame asset:(AVAsset *)asset
{
    self = [super initWithFrame:frame];
    if (self) {
        _asset = asset;
        [self resetSubviews];
    }
    return self;
}


#pragma mark - Private methods

- (CGFloat)thumbWidth
{
    return _thumbWidth ?: 10;
}

- (CGFloat)maxLength
{
    return _maxLength ?: 15;
}

- (CGFloat)minLength
{
    return _minLength ?: 3;
}

- (CGFloat)pointerWidth
{
    return _pointerWidth ?: 5;
}

- (UIColor *)borderColor
{
    return _borderColor ?: self.themeColor;
}

-(UIColor *)pointerColor
{
    return _pointerColor ?: [UIColor whiteColor];
}

- (UIColor*)overlayColor
{
    return _overlayColor ?: [UIColor colorWithWhite:0 alpha:0.8];
}

- (UIView*)playbackPointerView
{
   if (!_playbackPointerView) {
      CGRect pointerRect = CGRectMake(self.thumbWidth - self.pointerWidth / 2, 0, self.pointerWidth, CGRectGetMaxY(self.frameView.bounds));
      _playbackPointerView = [[UIView alloc] initWithFrame: pointerRect];
      _playbackPointerView.backgroundColor = self.pointerColor;
      _playbackPointerView.layer.cornerRadius = 3;
      _playbackPointerView.clipsToBounds = YES;
      _playbackPointerView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
   }
   return _playbackPointerView;
}

- (void)resetSubviews
{
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
    [self addSubview:self.scrollView];
    [self.scrollView setDelegate:self];
    [self.scrollView setShowsHorizontalScrollIndicator:NO];
    
    UITapGestureRecognizer* movePointerGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(movePointer:)];
    [self.scrollView addGestureRecognizer: movePointerGesture];
    
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.scrollView.frame), CGRectGetHeight(self.scrollView.frame))];
    [self.scrollView setContentSize:self.contentView.frame.size];
    [self.scrollView addSubview:self.contentView];
    
    CGFloat ratio = self.showsRulerView ? 0.7 : 1.0;
    self.frameView = [[UIView alloc] initWithFrame:CGRectMake(self.thumbWidth, 0, CGRectGetWidth(self.contentView.frame)-2*self.thumbWidth, CGRectGetHeight(self.contentView.frame)*ratio)];
    [self.frameView.layer setMasksToBounds:YES];
    [self.contentView addSubview:self.frameView];
    
    [self addFrames];
    
    if (self.showsRulerView) {
        CGRect rulerFrame = CGRectMake(0, CGRectGetHeight(self.contentView.frame)*ratio, CGRectGetWidth(self.contentView.frame)+self.thumbWidth, CGRectGetHeight(self.contentView.frame)*0.3);
        ICGRulerView *rulerView = [[ICGRulerView alloc] initWithFrame:rulerFrame widthPerSecond:self.widthPerSecond themeColor:self.themeColor];
        rulerView.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:rulerView];
    }
    
    // add borders
    self.topBorder = [[UIView alloc] init];
    [self.topBorder setBackgroundColor:self.borderColor];
    [self addSubview:self.topBorder];
    
    self.bottomBorder = [[UIView alloc] init];
    [self.bottomBorder setBackgroundColor:self.borderColor];
    [self addSubview:self.bottomBorder];
    
    // width for left and right overlay views
    self.overlayWidth =  CGRectGetWidth(self.frame) - (self.minLength * self.widthPerSecond);
    
    // add left overlay view
    self.leftOverlayView = [[UIView alloc] initWithFrame:CGRectMake(self.thumbWidth - self.overlayWidth, 0, self.overlayWidth, CGRectGetHeight(self.frameView.frame))];
    CGRect leftThumbFrame = CGRectMake(self.overlayWidth-self.thumbWidth, 0, self.thumbWidth, CGRectGetHeight(self.frameView.frame));
    if (self.leftThumbImage) {
        self.leftThumbView = [[ICGThumbView alloc] initWithFrame:leftThumbFrame thumbImage:self.leftThumbImage];
    } else {
        self.leftThumbView = [[ICGThumbView alloc] initWithFrame:leftThumbFrame color:self.borderColor right:NO];
    }
    [self.leftThumbView.layer setMasksToBounds:YES];
    [self.leftOverlayView addSubview:self.leftThumbView];
    [self.leftOverlayView setUserInteractionEnabled:YES];
    UIPanGestureRecognizer *leftPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveLeftOverlayView:)];
    [self.leftOverlayView addGestureRecognizer:leftPanGestureRecognizer];
    self.leftOverlayView.backgroundColor = self.overlayColor;
    [self addSubview:self.leftOverlayView];
    
    // add right overlay view
    CGFloat rightViewFrameX = CGRectGetMaxX(self.frameView.frame) < CGRectGetWidth(self.frame) ? CGRectGetMaxX(self.frameView.frame) : CGRectGetWidth(self.frame) - self.thumbWidth;
    self.rightOverlayView = [[UIView alloc] initWithFrame:CGRectMake(rightViewFrameX, 0, self.overlayWidth, CGRectGetHeight(self.frameView.frame))];
    if (self.rightThumbImage) {
        self.rightThumbView = [[ICGThumbView alloc] initWithFrame:CGRectMake(0, 0, self.thumbWidth, CGRectGetHeight(self.frameView.frame)) thumbImage:self.rightThumbImage];
    } else {
        self.rightThumbView = [[ICGThumbView alloc] initWithFrame:CGRectMake(0, 0, self.thumbWidth, CGRectGetHeight(self.frameView.frame)) color:self.borderColor right:YES];
    }
    [self.rightThumbView.layer setMasksToBounds:YES];
    [self.rightOverlayView addSubview:self.rightThumbView];
    [self.rightOverlayView setUserInteractionEnabled:YES];
    UIPanGestureRecognizer *rightPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveRightOverlayView:)];
    [self.rightOverlayView addGestureRecognizer:rightPanGestureRecognizer];
    self.rightOverlayView.backgroundColor = self.overlayColor;
    [self addSubview:self.rightOverlayView];
    
    [self updateBorderFrames];
    [self notifyDelegate];
}

- (void)updateBorderFrames
{
    CGFloat height = self.borderWidth ? self.borderWidth : 1;
    [self.topBorder setFrame:CGRectMake(CGRectGetMaxX(self.leftOverlayView.frame), 0, CGRectGetMinX(self.rightOverlayView.frame)-CGRectGetMaxX(self.leftOverlayView.frame), height)];
    [self.bottomBorder setFrame:CGRectMake(CGRectGetMaxX(self.leftOverlayView.frame), CGRectGetHeight(self.frameView.frame)-height, CGRectGetMinX(self.rightOverlayView.frame)-CGRectGetMaxX(self.leftOverlayView.frame), height)];
}

- (void)moveLeftOverlayView:(UIPanGestureRecognizer *)gesture
{
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.leftStartPoint = [gesture locationInView:self];
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint point = [gesture locationInView:self];
            
            int deltaX = point.x - self.leftStartPoint.x;
            
            CGPoint center = self.leftOverlayView.center;
            
            CGFloat newLeftViewMidX = center.x += deltaX;;
            CGFloat maxWidth = CGRectGetMinX(self.rightOverlayView.frame) - (self.minLength * self.widthPerSecond);
            CGFloat newLeftViewMinX = newLeftViewMidX - self.overlayWidth/2;
            if (newLeftViewMinX < self.thumbWidth - self.overlayWidth) {
                newLeftViewMidX = self.thumbWidth - self.overlayWidth + self.overlayWidth/2;
            } else if (newLeftViewMinX + self.overlayWidth > maxWidth) {
                newLeftViewMidX = maxWidth - self.overlayWidth / 2;
            }
            
            self.leftOverlayView.center = CGPointMake(newLeftViewMidX, self.leftOverlayView.center.y);
            self.leftStartPoint = point;
            [self updateBorderFrames];
            [self notifyDelegate];
            
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self didStopMove];
            break;
        default:
            break;
    }
    
    
}

- (void)moveRightOverlayView:(UIPanGestureRecognizer *)gesture
{
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.rightStartPoint = [gesture locationInView:self];
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint point = [gesture locationInView:self];
            
            int deltaX = point.x - self.rightStartPoint.x;
            
            CGPoint center = self.rightOverlayView.center;
            
            CGFloat newRightViewMidX = center.x += deltaX;
            CGFloat minX = CGRectGetMaxX(self.leftOverlayView.frame) + self.minLength * self.widthPerSecond;
            CGFloat maxX = CMTimeGetSeconds([self.asset duration]) <= self.maxLength + 0.5 ? CGRectGetMaxX(self.frameView.frame) : CGRectGetWidth(self.frame) - self.thumbWidth;
            if (newRightViewMidX - self.overlayWidth/2 < minX) {
                newRightViewMidX = minX + self.overlayWidth/2;
            } else if (newRightViewMidX - self.overlayWidth/2 > maxX) {
                newRightViewMidX = maxX + self.overlayWidth/2;
            }
            
            self.rightOverlayView.center = CGPointMake(newRightViewMidX, self.rightOverlayView.center.y);
            self.rightStartPoint = point;
            [self updateBorderFrames];
            [self notifyDelegate];
            
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self didStopMove];
            break;
        default:
            break;
    }
}

- (void)movePointer:(UITapGestureRecognizer *)gesture
{
    CGPoint pointerPoint = [gesture locationInView:self.scrollView];
    if ([self.delegate respondsToSelector:@selector(trimmerView:didMovePointerAtTime:)]) {
        [self.delegate trimmerView:self
              didMovePointerAtTime:CMTimeGetSeconds(self.asset.duration) * pointerPoint.x / (self.scrollView.contentSize.width - self.pointerWidth)];
    }
}

- (void)notifyDelegate
{
    self.startTime = CGRectGetMaxX(self.leftOverlayView.frame) / self.widthPerSecond + (self.scrollView.contentOffset.x -self.thumbWidth) / self.widthPerSecond;
    self.endTime = CGRectGetMinX(self.rightOverlayView.frame) / self.widthPerSecond + (self.scrollView.contentOffset.x - self.thumbWidth) / self.widthPerSecond;
    [self.delegate trimmerView:self didChangeLeftPosition:self.startTime rightPosition:self.endTime];
}

- (void)didStopMove
{
    if ([self.delegate respondsToSelector:@selector(trimmerView:didStopAnyMoveAtLeftPosition:rightPosition:)]) {
        [self.delegate trimmerView:self
      didStopAnyMoveAtLeftPosition:self.startTime
                     rightPosition:self.endTime];
   }
}

- (void)addFrames
{
    [self.imageGenerator cancelAllCGImageGeneration];

    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    self.imageGenerator.appliesPreferredTrackTransform = YES;
   
    AVAssetTrack* videoTrack = [[self.asset tracksWithMediaType: AVMediaTypeVideo] firstObject];
    CGRect videoRect = CGRectApplyAffineTransform(CGRectMake(0.f, 0.f, videoTrack.naturalSize.width, videoTrack.naturalSize.height), videoTrack.preferredTransform);

    CGSize size = videoRect.size;
    CGSize frameSize = CGSizeMake(self.frameView.bounds.size.height * (size.width / size.height), self.frameView.bounds.size.height);
   
    if ([self isRetina]){
        self.imageGenerator.maximumSize = CGSizeMake(frameSize.width * [ UIScreen mainScreen ].scale, frameSize.height * [ UIScreen mainScreen ].scale);
    } else {
        self.imageGenerator.maximumSize = frameSize;
    }

    Float64 duration = CMTimeGetSeconds([self.asset duration]);
    CGFloat screenWidth = CGRectGetWidth(self.frame) - 2*self.thumbWidth; // quick fix to make up for the width of thumb views
    NSInteger actualFramesNeeded;
    
    CGFloat frameViewFrameWidth = (duration / self.maxLength) * screenWidth;
    [self.frameView setFrame:CGRectMake(self.thumbWidth, 0, frameViewFrameWidth, CGRectGetHeight(self.frameView.frame))];
    CGFloat contentViewFrameWidth = CMTimeGetSeconds([self.asset duration]) <= self.maxLength + 0.5 ? screenWidth : frameViewFrameWidth;
    [self.contentView setFrame:CGRectMake(0, 0, contentViewFrameWidth + 2 * self.thumbWidth, CGRectGetHeight(self.contentView.frame))];
    [self.scrollView setContentSize:self.contentView.frame.size];
    NSInteger minFramesNeeded = screenWidth / frameSize.width + 1;
    actualFramesNeeded =  (duration / self.maxLength) * minFramesNeeded + 1;
    
    Float64 durationPerFrame = duration / (actualFramesNeeded*1.0);
    self.widthPerSecond = frameViewFrameWidth / duration;

    for (int i=0; i<actualFramesNeeded; i++){
        
        CMTime time = CMTimeMakeWithSeconds(i*durationPerFrame, 600);
       
        CGFloat width = i == actualFramesNeeded-1
           ? frameSize.width - 6
           : frameSize.width;
       
        UIImageView *tmp = [[UIImageView alloc] initWithFrame: CGRectMake(i*frameSize.width, 0.f, width, frameSize.height)];

       [self.imageGenerator generateCGImagesAsynchronouslyForTimes: @[[NSValue valueWithCMTime: time]] completionHandler:
        ^(CMTime requestedTime, CGImageRef imageRef, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error)
        {
           if (imageRef)
           {
              UIImage* image = [UIImage imageWithCGImage: imageRef];
              dispatch_async(dispatch_get_main_queue(), ^{
                 tmp.image = image;
              });
           }
        }];
       
       [self.frameView addSubview:tmp];
    }
}

- (BOOL)isRetina
{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
            ([UIScreen mainScreen].scale > 1.0));
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (CMTimeGetSeconds([self.asset duration]) <= self.maxLength + 0.5) {
        [UIView animateWithDuration:0.3 animations:^{
            [scrollView setContentOffset:CGPointZero];
        }];
    }
    [self notifyDelegate];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self didStopMove];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (decelerate == 0) {
        [self didStopMove];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self didStopMove];
}

@end

@implementation ICGVideoTrimmerView (ICGPlaybackTime)

- (void)movePlaybackPointerAtTime:(NSTimeInterval)timeInterval
{
    [self.scrollView addSubview: self.playbackPointerView];
    [self.scrollView bringSubviewToFront: self.playbackPointerView];
    CGRect pointerRect = self.playbackPointerView.frame;
    NSTimeInterval durationInSeconds = CMTimeGetSeconds(self.asset.duration);
    pointerRect.origin.x = self.thumbWidth - self.pointerWidth / 2 + (self.scrollView.contentSize.width - 2 * self.thumbWidth) * timeInterval / durationInSeconds;
    self.playbackPointerView.frame = pointerRect;
}

- (void)runPlaybackPointerAtTime:(NSTimeInterval)timeInterval
{
    [self.playbackPointerView.layer removeAllAnimations];
    
    [self movePlaybackPointerAtTime: timeInterval];
    
    NSTimeInterval durationInSeconds = CMTimeGetSeconds(self.asset.duration);
    [UIView animateWithDuration:durationInSeconds - timeInterval
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         [self movePlaybackPointerAtTime: durationInSeconds];
                     } completion:nil];
}

- (void)stopPlaybackPointerAtTime:(NSTimeInterval)timeInterval
{
    [self.playbackPointerView.layer removeAllAnimations];
    [self movePlaybackPointerAtTime: timeInterval];
}

@end
