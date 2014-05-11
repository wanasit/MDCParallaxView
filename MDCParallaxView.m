//  MDCParallaxView.m
//
//  Copyright (c) 2012, 2014 to present, Brian Gesiak @modocache
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//


#import "MDCParallaxView.h"


static void * kMDCForegroundViewObservationContext = &kMDCForegroundViewObservationContext;
static void * kMDCBackgroundViewObservationContext = &kMDCBackgroundViewObservationContext;
static CGFloat const kMDCParallaxViewDefaultBackgroundHeight = 150.0f;
static CGFloat const kMDCParallaxViewDefaultBackgroundExpanedHeight = 400;
static CGFloat const kMDCParallaxViewDefaultBackgroundExpandThreshold = 60;
static CGFloat const kMDCParallaxViewDefaultBackgroundShrinkThreshold = 30;

@interface MDCParallaxView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *backgroundScrollView;
@property (nonatomic, strong) UIScrollView *foregroundScrollView;
@property (nonatomic, assign) CGFloat currentBackgroundHeight;
@end


@implementation MDCParallaxView


#pragma mark - Object Lifecycle

- (id)init{
    
    if (self = [super init]) {
        _currentBackgroundHeight = kMDCParallaxViewDefaultBackgroundHeight;
        _backgroundHeight        = kMDCParallaxViewDefaultBackgroundHeight;
        _backgroundExpandedHeight  = kMDCParallaxViewDefaultBackgroundExpanedHeight;
        _backgroundExpandThreshold = kMDCParallaxViewDefaultBackgroundExpandThreshold;
        _backgroundShrinkThreshold = kMDCParallaxViewDefaultBackgroundShrinkThreshold;
    }
    
    return self;
}

- (id)initWithBackgroundView:(UIView *)backgroundView foregroundView:(UIView *)foregroundView {
    self = [self init];
    if (self) {
        self.backgroundView = backgroundView;
        self.foregroundView = foregroundView;
    }
    return self;
}

- (void)dealloc {
    [self removeFrameObservers];
}

- (void)checkAndPrepareScrollViews {
    
    if (!_foregroundScrollView) {
        _backgroundScrollView = [UIScrollView new];
        [self addSubview:_backgroundScrollView];
        _backgroundScrollView.backgroundColor = [UIColor clearColor];
        _backgroundScrollView.showsHorizontalScrollIndicator = NO;
        _backgroundScrollView.showsVerticalScrollIndicator = NO;
        _backgroundScrollView.scrollsToTop = NO;
        _backgroundScrollView.canCancelContentTouches = YES;
        
        
        _foregroundScrollView = [UIScrollView new];
        [self addSubview:_foregroundScrollView];
        _foregroundScrollView.showsVerticalScrollIndicator = NO;
        _foregroundScrollView.backgroundColor = [UIColor clearColor];
        _foregroundScrollView.delegate = self;
        
        [self addFrameObservers];
    }
}

- (void)setBackgroundView:(UIView *)backgroundView {
    
    [self checkAndPrepareScrollViews];
    
    if (_backgroundView) {
        [_backgroundView removeFromSuperview];
    }
    
    _backgroundView = backgroundView;
    [_backgroundScrollView addSubview:_backgroundView];
    [self updateBackgroundFrame];
    [self updateForegroundFrame];
}


- (void)setForegroundView:(UIView *)foregroundView {

    [self checkAndPrepareScrollViews];
    
    if (_foregroundView) {
        [_foregroundView removeFromSuperview];
    }
    
    _foregroundView = foregroundView;
    [_foregroundScrollView addSubview:_foregroundView];
    [self updateBackgroundFrame];
    [self updateForegroundFrame];
}


#pragma mark - NSKeyValueObserving Protocol Methods

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (context == kMDCForegroundViewObservationContext) {
        CGRect oldFrame = [self frameForObject:[change objectForKey:NSKeyValueChangeOldKey]];
        [self updateForegroundFrameIfDifferent:oldFrame];
    } else if (context == kMDCBackgroundViewObservationContext) {
        CGRect oldFrame = [self frameForObject:[change objectForKey:NSKeyValueChangeOldKey]];
        [self updateBackgroundFrameIfDifferent:oldFrame];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - NSObject Overrides

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([self.scrollViewDelegate respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:self.scrollViewDelegate];
    } else {
        [super forwardInvocation:anInvocation];
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return ([super respondsToSelector:aSelector] ||
            [self.scrollViewDelegate respondsToSelector:aSelector]);
}


#pragma mark - UIView Overrides

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self updateBackgroundFrame];
    [self updateForegroundFrame];
    [self updateContentOffset];
}

- (void)setAutoresizingMask:(UIViewAutoresizing)autoresizingMask {
    [super setAutoresizingMask:autoresizingMask];
    self.backgroundView.autoresizingMask = autoresizingMask;
    self.backgroundScrollView.autoresizingMask = autoresizingMask;
    self.foregroundView.autoresizingMask = autoresizingMask;
    self.foregroundScrollView.autoresizingMask = autoresizingMask;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if ([self.backgroundView pointInside:point withEvent:event] && _backgroundInteractionEnabled) {
        CGFloat visibleBackgroundViewHeight =
            self.currentBackgroundHeight - self.foregroundScrollView.contentOffset.y;
        if (point.y < visibleBackgroundViewHeight){
            return [self.backgroundView hitTest:point withEvent:event];
        }
    }

    return [super hitTest:point withEvent:event];
}


#pragma mark - UIScrollViewDelegate Protocol Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    
    CGFloat offsetY   = self.foregroundScrollView.contentOffset.y;
    CGFloat pullbackOffset = offsetY - (self.backgroundExpandedHeight - self.backgroundHeight);
    if (self.backgroundExpaneded && pullbackOffset > 0){
        [self setBackgroundExpaneded:NO animated:NO];
        [self.foregroundScrollView setContentOffset:CGPointMake(0, pullbackOffset)
                                           animated:NO];
    }
    
    
    [self updateContentOffset];
    if ([self.scrollViewDelegate respondsToSelector:_cmd]) {
        [self.scrollViewDelegate scrollViewDidScroll:scrollView];
    }
}



- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
    
    CGFloat offsetY   = self.foregroundScrollView.contentOffset.y;
    if (self.backgroundExpaneded && offsetY > self.backgroundShrinkThreshold) {
        [self setBackgroundExpaneded:NO animated:YES];
    }
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {

    CGFloat offsetY   = self.foregroundScrollView.contentOffset.y;
    NSLog(@"Decelerating %f", offsetY);
    if (!self.backgroundExpaneded && offsetY < -self.backgroundExpandThreshold) {
        [self setBackgroundExpaneded:YES animated:YES];
    }
}


#pragma mark - Public Interface

- (UIScrollView *)scrollView {
    return self.foregroundScrollView;
}

- (void)setBackgroundHeight:(CGFloat)backgroundHeight {
    _currentBackgroundHeight = backgroundHeight;
    _backgroundHeight = backgroundHeight;
    [self updateBackgroundFrame];
    [self updateForegroundFrame];
    [self updateContentOffset];
}


- (void)setBackgroundExpaneded:(BOOL)backgroundExpaneded animated:(BOOL)animated {

    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            
            if (backgroundExpaneded) {
                self.currentBackgroundHeight = self.backgroundExpandedHeight;
                self.backgroundExpaneded = YES;
            } else {
                self.currentBackgroundHeight = self.backgroundHeight;
                self.backgroundExpaneded = NO;
            }
            [self updateBackgroundFrame];
            [self updateForegroundFrame];
            
            [self.foregroundScrollView setContentOffset:CGPointMake(0, 0)
                                               animated:NO];
        }];
    } else {
    
        if (backgroundExpaneded) {
            self.currentBackgroundHeight = self.backgroundExpandedHeight;
            self.backgroundExpaneded = YES;
        } else {
            self.currentBackgroundHeight = self.backgroundHeight;
            self.backgroundExpaneded = NO;
        }
        [self updateBackgroundFrame];
        [self updateForegroundFrame];
        [self updateContentOffset];
    }
}


#pragma mark - Internal Methods

#pragma mark Key-Value Observing

- (void)addFrameObservers {
    [self addObserver:self forKeyPath:@"foregroundView.frame"
              options:NSKeyValueObservingOptionOld
              context:kMDCForegroundViewObservationContext];
    [self addObserver:self forKeyPath:@"backgroundView.frame"
              options:NSKeyValueObservingOptionOld
              context:kMDCBackgroundViewObservationContext];
}

- (void)removeFrameObservers {
    [self removeObserver:self forKeyPath:@"foregroundView.frame"];
    [self removeObserver:self forKeyPath:@"backgroundView.frame"];
}

- (void)updateForegroundFrameIfDifferent:(CGRect)oldFrame {
    if (!CGRectEqualToRect(self.foregroundView.frame, oldFrame)) {
        [self updateForegroundFrame];
    }
}

- (void)updateBackgroundFrameIfDifferent:(CGRect)oldFrame {
    if (!CGRectEqualToRect(self.backgroundView.frame, oldFrame)) {
        [self updateBackgroundFrame];
    }
}

- (CGRect)frameForObject:(id)frameObject {
    return frameObject == [NSNull null] ? CGRectNull : [frameObject CGRectValue];
}

#pragma mark Parallax Effect

- (void)updateBackgroundFrame {
    self.backgroundScrollView.frame = self.bounds;
    self.backgroundScrollView.contentSize = self.bounds.size;
    self.backgroundScrollView.contentOffset	= CGPointZero;

    self.backgroundView.frame =
        CGRectMake(0.0f,
                   floorf((self.currentBackgroundHeight -  CGRectGetHeight(self.backgroundView.frame))/2),
                   CGRectGetWidth(self.frame),
                   CGRectGetHeight(self.backgroundView.frame));
}

- (void)updateForegroundFrame {
    self.foregroundView.frame = CGRectMake(0.0f,
                                           self.currentBackgroundHeight,
                                           CGRectGetWidth(self.foregroundView.frame),
                                           CGRectGetHeight(self.foregroundView.frame));
    
    self.foregroundScrollView.frame = self.bounds;
    
    if (self.backgroundExpaneded) {
        self.foregroundScrollView.alwaysBounceVertical = YES;
        self.foregroundScrollView.contentSize =
            CGSizeMake(CGRectGetWidth(self.foregroundView.frame),
                   CGRectGetHeight(self.foregroundScrollView.frame));
    }else{
        self.foregroundScrollView.contentSize =
            CGSizeMake(CGRectGetWidth(self.foregroundView.frame),
                   CGRectGetHeight(self.foregroundView.frame) + self.currentBackgroundHeight);
    }
    
}

- (void)updateContentOffset {
    CGFloat offsetY   = self.foregroundScrollView.contentOffset.y;
    CGFloat threshold = CGRectGetHeight(self.backgroundView.frame) - self.currentBackgroundHeight;

    if (offsetY < -threshold && offsetY < 0.0f) {
        self.backgroundScrollView.contentOffset = CGPointMake(0.0f, offsetY + floorf(threshold/2));
    } else {
        self.backgroundScrollView.contentOffset = CGPointMake(0.0f, floorf(offsetY/2));
    }
}

@end
