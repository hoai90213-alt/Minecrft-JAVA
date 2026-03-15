#import <SafariServices/SafariServices.h>
#import <QuartzCore/QuartzCore.h>

#include "jni.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>

#include "utils.h"
#include "LauncherPreferences.h"

CFTypeRef SecTaskCopyValueForEntitlement(void* task, NSString* entitlement, CFErrorRef  _Nullable *error);
void* SecTaskCreateFromSelf(CFAllocatorRef allocator);

BOOL getEntitlementValue(NSString *key) {
    void *secTask = SecTaskCreateFromSelf(NULL);
    if (!secTask) {
        return NO;
    }

    CFTypeRef value = SecTaskCopyValueForEntitlement(secTask, key, nil);
    BOOL result = NO;
    if (value != nil) {
        result = [(__bridge id)value boolValue];
        CFRelease(value);
    }
    CFRelease(secTask);
    return result;
}

BOOL isJITEnabled(BOOL checkCSFlags) {
    if (!checkCSFlags && (getEntitlementValue(@"dynamic-codesigning") || isJailbroken)) {
        return YES;
    }

    int flags;
    csops(getpid(), 0, &flags, sizeof(flags));
    return (flags & CS_DEBUGGED) != 0;
}

void openLink(UIViewController* sender, NSURL* link) {
    if (NSClassFromString(@"SFSafariViewController") == nil) {
        NSData *data = [link.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
        CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
        [filter setValue:data forKey:@"inputMessage"];
        UIImage *image = [UIImage imageWithCIImage:filter.outputImage scale:1.0 orientation:UIImageOrientationUp];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(300, 300), NO, 0.0);
        CGRect frame = CGRectMake(0, 0, 300, 300);
        [image drawInRect:frame];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:frame];
        imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
            message:link.absoluteString
            preferredStyle:UIAlertControllerStyleAlert];

        UIViewController *vc = UIViewController.new;
        vc.view = imageView;
        [alert setValue:vc forKey:@"contentViewController"];

        UIAlertAction* doneAction = [UIAlertAction actionWithTitle:localize(@"Done", nil) style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:doneAction];
        [sender presentViewController:alert animated:YES completion:nil];
    } else {
        SFSafariViewController *vc = [[SFSafariViewController alloc] initWithURL:link];
        [sender presentViewController:vc animated:YES completion:nil];
    }
}

NSMutableDictionary* parseJSONFromFile(NSString *path) {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];
    if (data == nil) {
        NSLog(@"[ParseJSON] Error: could not read %@: %@", path, error.localizedDescription);
        return @{@"NSErrorObject": error}.mutableCopy;
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error || ![json isKindOfClass:NSDictionary.class]) {
        if (!error) {
            error = [NSError errorWithDomain:@"AmethystParseJSONErrorDomain"
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Top-level JSON object is not a dictionary"}];
        }
        NSLog(@"[ParseJSON] Error: could not parse JSON: %@", error.localizedDescription);
        return @{@"NSErrorObject": error}.mutableCopy;
    }

    return [json mutableCopy];
}

NSError* saveJSONToFile(NSDictionary *dict, NSString *path) {
    // TODO: handle rename
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (jsonData == nil) {
        return error;
    }
    BOOL success = [jsonData writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!success) {
        return error;
    }
    return nil;
}

NSString* localize(NSString* key, NSString* comment) {
    NSString *value = NSLocalizedString(key, nil);
    if (![NSLocale.preferredLanguages[0] isEqualToString:@"en"] && [value isEqualToString:key]) {
        NSString* path = [NSBundle.mainBundle pathForResource:@"en" ofType:@"lproj"];
        NSBundle* languageBundle = [NSBundle bundleWithPath:path];
        value = [languageBundle localizedStringForKey:key value:nil table:nil];

        if ([value isEqualToString:key]) {
            value = [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:nil table:nil];
        }
    }

    return value;
}

static NSInteger const kVisionBackgroundTag = 0xA11E0;
static NSInteger const kVisionImageTag = 0xA11E1;
static NSInteger const kVisionBlurTag = 0xA11E2;
static NSInteger const kVisionTintTag = 0xA11E3;
static NSInteger const kVisionShadeTag = 0xA11E4;
static NSString * const kVisionBaseGradientName = @"amethyst.dashboard.base.gradient";
static NSString * const kVisionOrbGradientName = @"amethyst.dashboard.orb.gradient";

static UIColor *AmethystVisionDynamicColor(CGFloat lr, CGFloat lg, CGFloat lb, CGFloat dr, CGFloat dg, CGFloat db) {
    UIColor *light = [UIColor colorWithRed:lr green:lg blue:lb alpha:1.0];
    UIColor *dark = [UIColor colorWithRed:dr green:dg blue:db alpha:1.0];
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
            return trait.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    return light;
}

static CGFloat AmethystDashboardPrefNumber(NSString *key, CGFloat fallback, CGFloat minValue, CGFloat maxValue) {
    id value = getPrefObject(key);
    if (!value) {
        return fallback;
    }
    CGFloat number = [value floatValue];
    return clamp(number, minValue, maxValue);
}

static NSString *AmethystDashboardWallpaperStoragePath(void) {
    NSString *root = getenv("POJAV_HOME") ? @(getenv("POJAV_HOME")) : NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [root stringByAppendingPathComponent:@"ui"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"dashboard_wallpaper.jpg"];
}

static NSString *AmethystDashboardWallpaperPathFromPrefs(void) {
    NSString *mode = getPrefObject(@"general.dashboard_background_mode");
    NSString *path = getPrefObject(@"general.dashboard_background_path");
    if (![mode isKindOfClass:NSString.class] || ![mode isEqualToString:@"custom"]) {
        return nil;
    }
    if (![path isKindOfClass:NSString.class] || path.length == 0) {
        return nil;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
}

static UIColor *AmethystVisionTintColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.45, 0.74, 0.95, 0.62, 0.83, 0.99);
    });
    return color;
}

static UIColor *AmethystVisionGlassColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.30, 0.33, 0.37, 0.12, 0.15, 0.20);
    });
    return color;
}

static UIColor *AmethystVisionBorderColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.98, 0.98, 1.0, 0.92, 0.94, 1.0);
    });
    return color;
}

static UIColor *AmethystVisionSelectedColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.52, 0.66, 0.86, 0.40, 0.58, 0.82);
    });
    return color;
}

NSError* AmethystSaveDashboardWallpaperFromImage(UIImage *image) {
    if (!image) {
        return [NSError errorWithDomain:@"AmethystDashboardTheme"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey: @"Could not decode selected image."}];
    }

    NSString *storagePath = AmethystDashboardWallpaperStoragePath();
    NSData *imageData = UIImageJPEGRepresentation(image, 0.86);
    if (!imageData) {
        imageData = UIImagePNGRepresentation(image);
    }
    if (!imageData) {
        return [NSError errorWithDomain:@"AmethystDashboardTheme"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey: @"Could not encode selected image."}];
    }

    NSError *error = nil;
    if (![imageData writeToFile:storagePath options:NSDataWritingAtomic error:&error]) {
        return error;
    }

    setPrefObject(@"general.dashboard_background_mode", @"custom");
    setPrefObject(@"general.dashboard_background_path", storagePath);
    return nil;
}

NSError* AmethystSaveDashboardWallpaperFromFileURL(NSURL *fileURL) {
    if (!fileURL) {
        return [NSError errorWithDomain:@"AmethystDashboardTheme"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey: @"No file URL was provided."}];
    }

    BOOL hasSecurityAccess = [fileURL startAccessingSecurityScopedResource];
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:&readError];
    if (hasSecurityAccess) {
        [fileURL stopAccessingSecurityScopedResource];
    }
    if (!data) {
        return readError ?: [NSError errorWithDomain:@"AmethystDashboardTheme"
                                                code:4
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not read image file."}];
    }

    UIImage *image = [UIImage imageWithData:data];
    return AmethystSaveDashboardWallpaperFromImage(image);
}

NSError* AmethystResetDashboardWallpaper(void) {
    NSString *path = getPrefObject(@"general.dashboard_background_path");
    if ([path isKindOfClass:NSString.class] && path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path]) {
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    } else {
        NSString *fallback = AmethystDashboardWallpaperStoragePath();
        [NSFileManager.defaultManager removeItemAtPath:fallback error:nil];
    }

    setPrefObject(@"general.dashboard_background_mode", @"default");
    setPrefObject(@"general.dashboard_background_path", @"");
    return nil;
}

void AmethystApplyVisionAppearance(void) {
    CGFloat glassIntensity = AmethystDashboardPrefNumber(@"general.dashboard_glass_intensity", 76.0, 20.0, 100.0) / 100.0;
    UIColor *tint = AmethystVisionTintColor();
    [UIView appearance].tintColor = tint;

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *navAppearance = [UINavigationBarAppearance new];
        [navAppearance configureWithTransparentBackground];
        navAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        navAppearance.backgroundColor = [[UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.26 + glassIntensity * 0.28];
        navAppearance.shadowColor = UIColor.clearColor;
        navAppearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: UIColor.whiteColor,
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
        };
        navAppearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: UIColor.whiteColor,
            NSFontAttributeName: [UIFont systemFontOfSize:32 weight:UIFontWeightBold]
        };

        UINavigationBar *navBar = [UINavigationBar appearance];
        navBar.tintColor = tint;
        navBar.prefersLargeTitles = YES;
        navBar.standardAppearance = navAppearance;
        navBar.compactAppearance = navAppearance;
        navBar.scrollEdgeAppearance = navAppearance;

        UIToolbarAppearance *toolbarAppearance = [UIToolbarAppearance new];
        [toolbarAppearance configureWithTransparentBackground];
        toolbarAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        toolbarAppearance.backgroundColor = [[UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.20 + glassIntensity * 0.22];
        toolbarAppearance.shadowColor = UIColor.clearColor;

        UIToolbar *toolbar = [UIToolbar appearance];
        toolbar.tintColor = tint;
        if (@available(iOS 15.0, *)) {
            toolbar.standardAppearance = toolbarAppearance;
            toolbar.scrollEdgeAppearance = toolbarAppearance;
        } else {
            toolbar.barTintColor = toolbarAppearance.backgroundColor;
        }

        UISegmentedControl *segmented = [UISegmentedControl appearance];
        segmented.selectedSegmentTintColor = [tint colorWithAlphaComponent:0.82];
        [segmented setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.secondaryLabelColor}
                                 forState:UIControlStateNormal];
        [segmented setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor}
                                 forState:UIControlStateSelected];
    }
}

void AmethystApplyVisionBackground(UIView *view) {
    if (!view) {
        return;
    }

    UITableView *tableView = [view isKindOfClass:UITableView.class] ? (UITableView *)view : nil;
    UIView *background = nil;
    if (tableView) {
        background = tableView.backgroundView;
        if (!background || background.tag != kVisionBackgroundTag) {
            background = [[UIView alloc] initWithFrame:tableView.bounds];
            background.tag = kVisionBackgroundTag;
            background.userInteractionEnabled = NO;
            background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tableView.backgroundView = background;
        }
        tableView.backgroundColor = UIColor.clearColor;
    } else {
        background = [view viewWithTag:kVisionBackgroundTag];
        if (!background) {
            background = [[UIView alloc] initWithFrame:view.bounds];
            background.tag = kVisionBackgroundTag;
            background.userInteractionEnabled = NO;
            background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [view insertSubview:background atIndex:0];
        }
    }
    background.frame = view.bounds;

    UIImageView *imageView = (UIImageView *)[background viewWithTag:kVisionImageTag];
    if (![imageView isKindOfClass:UIImageView.class]) {
        [imageView removeFromSuperview];
        imageView = [[UIImageView alloc] initWithFrame:background.bounds];
        imageView.tag = kVisionImageTag;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [background addSubview:imageView];
    }

    UIVisualEffectView *blurView = (UIVisualEffectView *)[background viewWithTag:kVisionBlurTag];
    if (![blurView isKindOfClass:UIVisualEffectView.class]) {
        [blurView removeFromSuperview];
        blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
        blurView.tag = kVisionBlurTag;
        blurView.frame = background.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:blurView];
    }

    UIView *tintView = [background viewWithTag:kVisionTintTag];
    if (!tintView) {
        tintView = [[UIView alloc] initWithFrame:background.bounds];
        tintView.tag = kVisionTintTag;
        tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:tintView];
    }

    UIView *shadeView = [background viewWithTag:kVisionShadeTag];
    if (!shadeView) {
        shadeView = [[UIView alloc] initWithFrame:background.bounds];
        shadeView.tag = kVisionShadeTag;
        shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:shadeView];
    }

    CAGradientLayer *baseGradient = nil;
    CAGradientLayer *orbGradient = nil;
    for (CALayer *layer in background.layer.sublayers) {
        if ([layer.name isEqualToString:kVisionBaseGradientName]) {
            baseGradient = (CAGradientLayer *)layer;
        } else if ([layer.name isEqualToString:kVisionOrbGradientName]) {
            orbGradient = (CAGradientLayer *)layer;
        }
    }
    if (!baseGradient) {
        baseGradient = [CAGradientLayer layer];
        baseGradient.name = kVisionBaseGradientName;
        [background.layer insertSublayer:baseGradient atIndex:0];
    }
    if (!orbGradient) {
        orbGradient = [CAGradientLayer layer];
        orbGradient.name = kVisionOrbGradientName;
        [background.layer insertSublayer:orbGradient above:baseGradient];
    }

    CGFloat blurStrength = AmethystDashboardPrefNumber(@"general.dashboard_blur_strength", 74.0, 25.0, 100.0) / 100.0;
    CGFloat glassIntensity = AmethystDashboardPrefNumber(@"general.dashboard_glass_intensity", 76.0, 20.0, 100.0) / 100.0;
    NSString *wallpaperPath = AmethystDashboardWallpaperPathFromPrefs();
    if (wallpaperPath) {
        imageView.hidden = NO;
        imageView.image = [UIImage imageWithContentsOfFile:wallpaperPath];
        baseGradient.hidden = YES;
        orbGradient.hidden = YES;
    } else {
        imageView.hidden = YES;
        imageView.image = nil;
        baseGradient.hidden = NO;
        orbGradient.hidden = NO;
    }

    baseGradient.frame = background.bounds;
    baseGradient.startPoint = CGPointMake(0.0, 0.0);
    baseGradient.endPoint = CGPointMake(1.0, 1.0);
    baseGradient.colors = @[
        (id)[UIColor colorWithRed:0.19 green:0.18 blue:0.20 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.15 green:0.15 blue:0.17 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.11 blue:0.14 alpha:1.0].CGColor
    ];
    baseGradient.locations = @[@0.0, @0.45, @1.0];

    orbGradient.frame = background.bounds;
    orbGradient.startPoint = CGPointMake(0.15, 0.0);
    orbGradient.endPoint = CGPointMake(0.95, 0.95);
    orbGradient.colors = @[
        (id)[UIColor colorWithRed:0.47 green:0.60 blue:0.78 alpha:0.30].CGColor,
        (id)[UIColor colorWithRed:0.46 green:0.34 blue:0.22 alpha:0.24].CGColor,
        (id)UIColor.clearColor.CGColor
    ];
    orbGradient.locations = @[@0.0, @0.56, @1.0];

    if (@available(iOS 13.0, *)) {
        blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    } else {
        blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    blurView.alpha = 0.55 + blurStrength * 0.35;

    tintView.backgroundColor = [[UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0]
        colorWithAlphaComponent:0.20 + glassIntensity * 0.32];

    shadeView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.12 + blurStrength * 0.18];

    if (tableView) {
        tableView.separatorColor = [AmethystVisionBorderColor() colorWithAlphaComponent:0.16 + glassIntensity * 0.08];
    }
}

void AmethystApplyVisionSidebar(UITableView *tableView) {
    if (!tableView) {
        return;
    }
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.contentInset = UIEdgeInsetsMake(10, 8, 16, 8);
    tableView.rowHeight = 64.0;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0;
    }
    AmethystApplyVisionBackground(tableView);
}

void AmethystApplyVisionContentTable(UITableView *tableView) {
    if (!tableView) {
        return;
    }
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.contentInset = UIEdgeInsetsMake(12, 6, 18, 6);
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 72.0;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 8.0;
    }
    AmethystApplyVisionBackground(tableView);
}

void AmethystApplyVisionSurface(UIView *view, CGFloat cornerRadius) {
    if (!view) {
        return;
    }

    CGFloat glassIntensity = AmethystDashboardPrefNumber(@"general.dashboard_glass_intensity", 76.0, 20.0, 100.0) / 100.0;
    view.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.28 + glassIntensity * 0.48];
    view.layer.cornerRadius = cornerRadius > 0 ? cornerRadius : 15.0;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [AmethystVisionBorderColor() colorWithAlphaComponent:0.16 + glassIntensity * 0.22].CGColor;
    view.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    view.layer.shadowOpacity = 0.18f;
    view.layer.shadowOffset = CGSizeMake(0, 10);
    view.layer.shadowRadius = 18.0f;
    view.layer.masksToBounds = NO;
}

void AmethystApplyVisionCell(UITableViewCell *cell) {
    if (!cell) {
        return;
    }

    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;

    UIView *backgroundView = cell.backgroundView;
    if (!backgroundView) {
        backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        cell.backgroundView = backgroundView;
    }
    backgroundView.frame = CGRectInset(cell.bounds, 8.0, 4.0);
    AmethystApplyVisionSurface(backgroundView, 14.0);

    UIView *selectedBackground = cell.selectedBackgroundView;
    if (!selectedBackground) {
        selectedBackground = [[UIView alloc] initWithFrame:CGRectZero];
        cell.selectedBackgroundView = selectedBackground;
    }
    selectedBackground.frame = backgroundView.frame;
    selectedBackground.backgroundColor = [AmethystVisionSelectedColor() colorWithAlphaComponent:0.45];
    selectedBackground.layer.cornerRadius = backgroundView.layer.cornerRadius;
    if (@available(iOS 13.0, *)) {
        selectedBackground.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

void AmethystApplyVisionInput(UITextField *textField) {
    if (!textField) {
        return;
    }

    CGFloat glassIntensity = AmethystDashboardPrefNumber(@"general.dashboard_glass_intensity", 76.0, 20.0, 100.0) / 100.0;
    textField.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.30 + glassIntensity * 0.42];
    textField.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) {
        textField.layer.cornerCurve = kCACornerCurveContinuous;
    }
    textField.layer.borderWidth = 1.0;
    textField.layer.borderColor = [AmethystVisionBorderColor() colorWithAlphaComponent:0.18 + glassIntensity * 0.18].CGColor;
    textField.layer.masksToBounds = YES;
    textField.textColor = UIColor.whiteColor;
}

void AmethystApplyVisionPrimaryButton(UIButton *button) {
    if (!button) {
        return;
    }

    UIColor *tint = AmethystVisionTintColor();
    button.backgroundColor = [tint colorWithAlphaComponent:0.90];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.layer.cornerRadius = 13.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.03 green:0.10 blue:0.20 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.24f;
    button.layer.shadowOffset = CGSizeMake(0, 8);
    button.layer.shadowRadius = 14.0f;
    button.clipsToBounds = NO;
}

void customNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...)
{
    va_list ap; 
    va_start (ap, format);
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    printf("%s", [body UTF8String]);
    if (![format hasSuffix:@"\n"]) {
        printf("\n");
    }
    va_end (ap);
}

CGFloat MathUtils_dist(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) {
    const CGFloat x = (x2 - x1);
    const CGFloat y = (y2 - y1);
    return (CGFloat) hypot(x, y);
}

//Ported from https://www.arduino.cc/reference/en/language/functions/math/map/
CGFloat MathUtils_map(CGFloat x, CGFloat in_min, CGFloat in_max, CGFloat out_min, CGFloat out_max) {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

CGFloat dpToPx(CGFloat dp) {
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    return dp * screenScale;
}

CGFloat pxToDp(CGFloat px) {
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    return px / screenScale;
}

void setButtonPointerInteraction(UIButton *button) {
    button.pointerInteractionEnabled = YES;
    button.pointerStyleProvider = ^ UIPointerStyle* (UIButton* button, UIPointerEffect* proposedEffect, UIPointerShape* proposedShape) {
        UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:button];
        return [NSClassFromString(@"UIPointerStyle") styleWithEffect:[NSClassFromString(@"UIPointerHighlightEffect") effectWithPreview:preview] shape:proposedShape];
    };
}

__attribute__((noinline,optnone,naked))
void* JIT26CreateRegionLegacy(size_t len) {
    asm("brk #0x69 \n"
        "ret");
}
__attribute__((noinline,optnone,naked))
void* JIT26PrepareRegion(void *addr, size_t len) {
    asm("mov x16, #1 \n"
        "brk #0xf00d \n"
        "ret");
}
__attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
   asm("mov x16, #2 \n"
       "brk #0xf00d \n"
       "ret");
}
__attribute__((noinline,optnone,naked))
void JIT26SetDetachAfterFirstBr(BOOL value) {
   asm("mov x16, #3 \n"
       "brk #0xf00d \n"
       "ret");
}
__attribute__((noinline,optnone,naked))
void JIT26PrepareRegionForPatching(void *addr, size_t size) {
   asm("mov x16, #4 \n"
       "brk #0xf00d \n"
       "ret");
}
void JIT26SendJITScript(NSString* script) {
    NSCAssert(script, @"Script must not be nil");
    BreakSendJITScript((char*)script.UTF8String, script.length);
}
BOOL DeviceRequiresTXMWorkaround(void) {
    if (@available(iOS 26.0, *)) {
        DIR *d = opendir("/private/preboot");
        if(!d) return NO;
        struct dirent *dir;
        char txmPath[PATH_MAX];
        while ((dir = readdir(d)) != NULL) {
            if(strlen(dir->d_name) == 96) {
                snprintf(txmPath, sizeof(txmPath), "/private/preboot/%s/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", dir->d_name);
                break;
            }
        }
        closedir(d);
        return access(txmPath, F_OK) == 0;
    }
    return NO;
}
