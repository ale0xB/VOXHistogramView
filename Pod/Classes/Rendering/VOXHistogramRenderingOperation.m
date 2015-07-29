//
// Created by Nickolay Sheika on 09.01.15.
// Copyright (c) 2015 Alterplay. All rights reserved.
//

#import "VOXHistogramRenderingOperation.h"
#import "VOXHistogramRenderingConfiguration.h"



@interface VOXHistogramRenderingOperation ()


@property(nonatomic, strong, readwrite) UIImage *image;
@property(nonatomic, copy) NSArray *levels;
@property(nonatomic, strong) VOXHistogramRenderingConfiguration *renderingConfiguration;

@end



@implementation VOXHistogramRenderingOperation


#pragma mark - Init

- (instancetype)initWithLevels:(NSArray *)levels
        renderingConfiguration:(VOXHistogramRenderingConfiguration *)renderingConfiguration
{
    NSParameterAssert(levels);
    NSParameterAssert(renderingConfiguration);

    self = [super init];
    if (self) {
        self.levels = levels;
        self.renderingConfiguration = renderingConfiguration;
    }
    return self;
}

+ (instancetype)operationWithLevels:(NSArray *)levels
             renderingConfiguration:(VOXHistogramRenderingConfiguration *)renderingConfiguration
{
    return [[self alloc] initWithLevels:levels renderingConfiguration:renderingConfiguration];
}

#pragma mark - NSOperation

- (void)main
{
    if ([self isCancelled]) {
        return;
    }

    NSArray *levels = self.levels;
    UIImage *renderedImage = [self renderedHistogramWithLevels:levels];

    if ([self isCancelled]) {
        return;
    }

    self.image = renderedImage;

    // call completion block with result
    if (self.completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completion(self.image);
        });
    }
}

#pragma mark - Rendering

- (UIImage *)rendredHistogramWithLevels:(NSArray *)levels shouldProduceFlippedImage:(BOOL)produceFlipped
{
    /* Get image size */
    CGSize outputImageSize = self.renderingConfiguration.outputImageSize;
    
    CGSize imageSize = produceFlipped ? CGSizeMake(self.renderingConfiguration.outputImageSize.width, self.renderingConfiguration.outputImageSize.height / 2.0) : outputImageSize;
    
    /* Creating image context */
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, [self scale]);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    /* Please, no antialiasing */
    CGContextSetShouldAntialias(context, NO);
    
    [levels enumerateObjectsUsingBlock:^(NSNumber *levelNumber, NSUInteger idx, BOOL *stop) {
        /* Check operation is cancelled */
        if ([self isCancelled]) {
            *stop = YES;
            return;
        }
        
        /* Get float from NSNumber */
        CGFloat levelFloat = [levelNumber floatValue];
        
        /* Calculate current peak offset */
        CGFloat peakOffset = idx * ([self onePeakWidth] + [self marginWidth]);
        
        /* Draw every line for peak width */
        for (int i = 0; i < [self linesCountInOnePeak]; i ++) {
            
            /* Calculate current line offset */
            CGFloat lineOffset = peakOffset + i * [self lineMinimumWidth];
            
            /* Get current line color */
            UIColor *lineColor = self.renderingConfiguration.peaksColor;
            
            CGRect rect = CGRectMake(0.0f, 0.0f, imageSize.width, imageSize.height);
            
            /* Lets draw */
            [self drawLineInContext:context
                             inRect:rect
                     withLeftOffset:lineOffset
                           andWidth:[self lineMinimumWidth]
                           andLevel:levelFloat
                           andColor:lineColor];
        }
    }];
    
    /* Check operation is cancelled */
    if ([self isCancelled]) {
        /* Context clean up */
        UIGraphicsEndImageContext();
        return nil;
    }
    
    /* Get result image from context */
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (!produceFlipped) {
        return [image imageWithRenderingMode:self.renderingConfiguration.renderingMode];
    }
    
    UIImage *flippedImage = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationDownMirrored];
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(outputImageSize.width, outputImageSize.height), NO, [self scale]);
    [image drawAtPoint:CGPointMake(0, 0)];
    
    [flippedImage drawAtPoint:CGPointMake(0, outputImageSize.height / 2.0f)];
    
    /* Check again */
    if ([self isCancelled]) {
        /* Context clean up */
        UIGraphicsEndImageContext();
        return nil;
    }
    
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    
    
    /* Context clean up */
    UIGraphicsEndImageContext();
    
    
    /* Return image in current rendering mode */
    return [finalImage imageWithRenderingMode:self.renderingConfiguration.renderingMode];
}

- (UIImage *)renderedHistogramWithLevels:(NSArray *)levels
{
    return [self rendredHistogramWithLevels:levels shouldProduceFlippedImage:self.renderingConfiguration.produceFlipped];
}

- (void)drawLineInContext:(CGContextRef)context
                   inRect:(CGRect)rect
           withLeftOffset:(CGFloat)leftOffset
                 andWidth:(CGFloat)width
                 andLevel:(CGFloat)level
                 andColor:(UIColor *)color
{
    // Set line color
    CGContextSetStrokeColorWithColor(context, color.CGColor);

    // Set line width
    CGContextSetLineWidth(context, width);

    // Maybe this will make lines beautiful, but i'm not sure
    CGContextSetLineCap(context, kCGLineCapButt);

    // Get current rect height
    CGFloat rectHeight = CGRectGetHeight(rect);

    // start to draw line at bottom point
    CGContextMoveToPoint(context, leftOffset, rectHeight);

    // calculating line height for level
    CGFloat lineHeight = floorf(level * rectHeight);

    // drawing line with calculated height
    CGContextAddLineToPoint(context, leftOffset, rectHeight - lineHeight);

    // draw stroke
    CGContextStrokePath(context);
}

#pragma mark - Helpers

- (CGFloat)lineMinimumWidth
{
    return 1 / [self scale];
}

- (CGFloat)onePeakWidth
{
    return [self lineMinimumWidth] * self.renderingConfiguration.peakWidth;
}

- (CGFloat)marginWidth
{
    return [self lineMinimumWidth] * self.renderingConfiguration.marginWidth;
}

- (NSUInteger)linesCountInOnePeak
{
    return (NSUInteger) ([self onePeakWidth] / [self lineMinimumWidth]);
}

- (CGFloat)scale
{
    return [UIScreen mainScreen].scale;
}

@end