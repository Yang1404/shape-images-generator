//
//  ViewController.m
//  Figure_generator
//
//  Created by Vasiliy Kotov on 23.04.17.
//  Copyright © 2017 Kotov Home. All rights reserved.
//

#import "ViewController.h"

static NSString * const kPicFileNamePrefix = @"img";
static NSString * const kPicFileNameExtension = @"png";
static NSString * const kPicsDirecoryName = @"images";
static NSString * const kMetadataFileName = @"metadata";
static NSString * const kBaseDirectoryName = @"data";

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *countTextField;
@property (weak, nonatomic) IBOutlet UITextField *imageSizeTextField;
@property (weak, nonatomic) IBOutlet UITextField *figureSizeTextField;
@property (weak, nonatomic) IBOutlet UITextField *rotationThrottleTextField;
@property (weak, nonatomic) IBOutlet UITextField *scaleThrottleTextField;
@property (weak, nonatomic) IBOutlet UIButton *button;

@property (nonatomic, assign) int imageSizeValue;
@property (nonatomic, assign) int figureSizeValue;
@property (nonatomic, assign) int rotateRandomBounds;
@property (nonatomic, assign) float scaleRandomBounds;

@end

@implementation ViewController

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self __createBaseDirectoriesIfNeed];
}

#pragma mark - Actions

- (IBAction)generateAction {
    if ([self __validateFieldsData])
    {
        _imageSizeValue = _imageSizeTextField.text.intValue;
        _figureSizeValue = _figureSizeTextField.text.intValue;
        _rotateRandomBounds = _rotationThrottleTextField.text.intValue;
        _scaleRandomBounds = _scaleThrottleTextField.text.floatValue;
        
    } else {
        NSLog(@"Invalide input data");
        return;
    }
    
    [self __clearBaseDirectory];
    
    _button.enabled = NO;
    
    int count = _countTextField.text.intValue;
    int percentOfProcessing = 0;
    
    NSMutableDictionary *metadata = [NSMutableDictionary new];
    
    NSString *directory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
                           stringByAppendingPathComponent:kBaseDirectoryName];
    
    for (int i = 0; i < count; i++)
    {
        @autoreleasepool {
            percentOfProcessing = i * 100 / count;
            NSLog(@"Processing... %d", percentOfProcessing);
            
            NSString *figureKey = nil;
            NSString *colorKey = nil;
            
            UIImage *image = [self __generateImageWithMetadata:&colorKey figureKey:&figureKey];
            NSString *fileName = [NSString stringWithFormat:@"%@%d", kPicFileNamePrefix, i];
            
            NSString *path = [[[directory stringByAppendingPathComponent:kPicsDirecoryName]
                               stringByAppendingPathComponent:fileName]
                              stringByAppendingPathExtension:kPicFileNameExtension];
            
            if ([self __saveData:UIImagePNGRepresentation(image) inPath:path] && figureKey && colorKey)
            {
//                metadata[fileName] = @{ @"color" : colorKey, @"shape" : figureKey };
                metadata[fileName] = @{ @"color" : @([[self __colors] indexOfObject:colorKey]/10.f), @"shape" : @([[self __figures] indexOfObject:figureKey]/10.f) };
            }
        }
    }
    
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:metadata
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:NULL];
    [self __saveData:jsonData inPath:[[directory stringByAppendingPathComponent:kMetadataFileName]
                                      stringByAppendingPathExtension:@"json"]];
    
    
    _button.enabled = YES;
    
    NSLog(@"path:%@", directory);
}

#pragma mark - Private Methods

#pragma mark CG

- (UIImage *)__generateImageWithMetadata:(NSString **)colorK figureKey:(NSString **)figureK
{
    //color
    int colorsCount = [self __colors].count;
    NSString *colorKey = [self __colors][arc4random_uniform(colorsCount)];
    if (colorK)
        *colorK = colorKey;
    
    UIColor *color = [self __colorsMap][colorKey];
    
    //figure
    int figuresCount = [self __figures].count;
    NSString *figureKey = [self __figures][arc4random_uniform(figuresCount)];
    if (figureK)
        *figureK = figureKey;
    
    UIBezierPath *figurePath = [[self __figuresMap][figureKey] copy];
    
    CGRect bounds = CGPathGetBoundingBox(figurePath.CGPath);
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    
    CGAffineTransform toOrigin = CGAffineTransformMakeTranslation(-center.x, -center.y);
    [figurePath applyTransform:toOrigin];
    
    int angle = _rotateRandomBounds - arc4random_uniform(2 * _rotateRandomBounds);
    [figurePath applyTransform:CGAffineTransformMakeRotation(
                                                             M_PI * (angle) / 180.0
                                                             )];
    
    CGFloat scaleFactor = 1 + _scaleRandomBounds - arc4random_uniform(2 * _scaleRandomBounds * 100)/100.f;
    [figurePath applyTransform:CGAffineTransformMakeScale(
                                                          scaleFactor,
                                                          scaleFactor
                                                          )];
    
    CGAffineTransform fromOrigin = CGAffineTransformMakeTranslation(center.x, center.y);
    [figurePath applyTransform:fromOrigin];
    
    //drawings
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(_imageSizeValue, _imageSizeValue), NO, 0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 3 - arc4random_uniform(3));
    
    [figurePath fill];
    [figurePath stroke];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}

#pragma mark - FM

- (BOOL)__saveData:(NSData *)data inPath:path
{
    if (![data writeToFile:path atomically:YES])
    {
        NSLog(@"Error: data writing failed");
        return NO;
    }
    return YES;
}

- (void)__createBaseDirectoriesIfNeed
{
    NSString *directoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
                               stringByAppendingPathComponent:kBaseDirectoryName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:NO attributes:nil error:NULL];
    
    NSString *imagesPath = [directoryPath stringByAppendingPathComponent:kPicsDirecoryName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:imagesPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:imagesPath withIntermediateDirectories:NO attributes:nil error:NULL];
}

- (void)__clearBaseDirectory
{
    NSError *error = nil;
    
    NSString *directoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
                               stringByAppendingPathComponent:kBaseDirectoryName];
    NSArray* filesPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error)
    {
        NSLog(@"Error: %@", error.localizedDescription);
        return;
    }
    
    for (NSString *path in filesPaths)
    {
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error])
        {
            NSLog(@"Error: %@", error.localizedDescription);
        }
    }
}

#pragma mark - Static data

- (NSArray *)__colors
{
    static NSArray *colors = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        colors = @[@"white",
                   @"blue",
                   @"black",
                   @"red",
                   @"yellow"];
    });
    
    return colors;
}

- (NSDictionary <NSString *, UIColor *> *)__colorsMap
{
    static NSDictionary *colorsMap = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        colorsMap = [NSDictionary dictionaryWithObjects:@[[UIColor whiteColor],
                                                          [UIColor blueColor],
                                                          [UIColor blackColor],
                                                          [UIColor redColor],
                                                          [UIColor yellowColor]]
                                                forKeys:[self __colors]];
        
    });
    
    return colorsMap;
}

- (NSArray *)__figures
{
    static NSArray *figures = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        figures = @[@"triangle",
                   @"circle",
                   @"square"];
    });
    
    return figures;
}

- (NSDictionary <NSString *, UIBezierPath *> *)__figuresMap
{
    static NSDictionary *figuresMap = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        figuresMap = [NSDictionary dictionaryWithObjects:@[[self __trianglePath],
                                                          [self __squarePath],
                                                          [self __circlePath]]
                                                forKeys:[self __figures]];

    });
    
    return figuresMap;
}

- (UIBezierPath *)__squarePath
{
    return [UIBezierPath bezierPathWithRect:CGRectMake(
                                                       0.5f * (_imageSizeValue - _figureSizeValue),
                                                       0.5f * (_imageSizeValue - _figureSizeValue),
                                                       _figureSizeValue,
                                                       _figureSizeValue
            )];
}

- (UIBezierPath *)__circlePath
{
    return [UIBezierPath bezierPathWithOvalInRect:CGRectMake(
                                                             0.5f * (_imageSizeValue - _figureSizeValue),
                                                             0.5f * (_imageSizeValue - _figureSizeValue),
                                                             _figureSizeValue,
                                                             _figureSizeValue)];
}

- (UIBezierPath *)__trianglePath
{
    CGFloat padding = 0.5f * (_imageSizeValue - _figureSizeValue);
    
    CGPoint startPoint = CGPointMake(padding, _imageSizeValue - padding);
    CGPoint endPoint = CGPointMake(_imageSizeValue - padding, _imageSizeValue - padding);
    
    CGFloat angle = M_PI/3;
    CGPoint v1 = CGPointMake(endPoint.x - startPoint.x, endPoint.y - startPoint.y);
    CGPoint v2 = CGPointMake(cosf(angle) * v1.x - sinf(angle) * v1.y,
                             sinf(angle) * v1.x + cosf(angle) * v1.y);
    CGPoint thirdPoint = CGPointMake(startPoint.x + v2.x, startPoint.y - v2.y);
    
    UIBezierPath *triangle = [UIBezierPath bezierPath];
    [triangle moveToPoint:startPoint];
    [triangle addLineToPoint:endPoint];
    [triangle addLineToPoint:thirdPoint];
    [triangle closePath];
    
    return triangle;
}

#pragma mark - Helpers

- (BOOL)__validateFieldsData
{
    BOOL valid = YES;
    
    if (!_countTextField.text.length || _countTextField.text.intValue < 1)
    {
        valid = NO;
    }
    if (!_imageSizeTextField.text.length || _imageSizeTextField.text.intValue < 1)
    {
        valid = NO;
    }
    if (!_figureSizeTextField.text.length || _figureSizeTextField.text.intValue < 1)
    {
        valid = NO;
    }
    if (!_rotationThrottleTextField.text.length)
    {
        valid = NO;
    }
    if (!_scaleThrottleTextField.text.length)
    {
        valid = NO;
    }
    
    return valid;
}

@end
