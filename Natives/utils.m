#import <SafariServices/SafariServices.h>
#import <QuartzCore/QuartzCore.h>

#include "jni.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>

#include "utils.h"

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

static UIColor* AmethystDynamicColor(CGFloat rLight, CGFloat gLight, CGFloat bLight, CGFloat rDark, CGFloat gDark, CGFloat bDark) {
    UIColor *light = [UIColor colorWithRed:rLight green:gLight blue:bLight alpha:1.0];
    UIColor *dark = [UIColor colorWithRed:rDark green:gDark blue:bDark alpha:1.0];
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
            return trait.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    return light;
}

static UIColor* AmethystResolveColor(UIColor *color, UITraitCollection *trait) {
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:trait];
    }
    return color;
}

UIColor* AmethystColorAccent(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystDynamicColor(0.11, 0.58, 0.45, 0.24, 0.77, 0.61);
    });
    return color;
}

UIColor* AmethystColorAccentMuted(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystDynamicColor(0.79, 0.90, 0.85, 0.21, 0.30, 0.27);
    });
    return color;
}

UIColor* AmethystColorPanel(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystDynamicColor(0.97, 0.98, 0.98, 0.11, 0.13, 0.15);
    });
    return color;
}

void AmethystApplyGlobalAppearance(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIColor *accent = AmethystColorAccent();
        UIColor *panel = AmethystColorPanel();

        [UIView appearance].tintColor = accent;

        UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
        [navAppearance configureWithOpaqueBackground];
        navAppearance.backgroundColor = [panel colorWithAlphaComponent:0.96];
        navAppearance.shadowColor = UIColor.clearColor;
        navAppearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: UIColor.labelColor,
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
        };
        navAppearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: UIColor.labelColor,
            NSFontAttributeName: [UIFont systemFontOfSize:33 weight:UIFontWeightBold]
        };

        UINavigationBar *navBar = [UINavigationBar appearance];
        navBar.tintColor = accent;
        navBar.prefersLargeTitles = YES;
        navBar.standardAppearance = navAppearance;
        navBar.compactAppearance = navAppearance;
        navBar.scrollEdgeAppearance = navAppearance;

        UIToolbarAppearance *toolbarAppearance = [[UIToolbarAppearance alloc] init];
        [toolbarAppearance configureWithTransparentBackground];
        toolbarAppearance.backgroundColor = [panel colorWithAlphaComponent:0.90];
        toolbarAppearance.shadowColor = UIColor.clearColor;
        UIToolbar *toolbar = [UIToolbar appearance];
        toolbar.tintColor = accent;
        if (@available(iOS 15.0, *)) {
            toolbar.standardAppearance = toolbarAppearance;
        } else {
            toolbar.barTintColor = toolbarAppearance.backgroundColor;
        }

        UISegmentedControl *segmented = [UISegmentedControl appearance];
        segmented.selectedSegmentTintColor = accent;
        [segmented setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.secondaryLabelColor}
                                 forState:UIControlStateNormal];
        [segmented setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor}
                                 forState:UIControlStateSelected];
    });
}

void AmethystApplyParallaxEffect(UIView *view, CGFloat amount) {
    if (!view) {
        return;
    }
    if (UIAccessibilityIsReduceMotionEnabled() || amount <= 0) {
        return;
    }

    while (view.motionEffects.count > 0) {
        [view removeMotionEffect:view.motionEffects.lastObject];
    }

    UIInterpolatingMotionEffect *xEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x"
                                                                                             type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    xEffect.minimumRelativeValue = @(-amount);
    xEffect.maximumRelativeValue = @(amount);

    UIInterpolatingMotionEffect *yEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y"
                                                                                             type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    yEffect.minimumRelativeValue = @(-amount);
    yEffect.maximumRelativeValue = @(amount);

    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[xEffect, yEffect];
    [view addMotionEffect:group];
}

void AmethystApplyCardStyle(UIView *view) {
    if (!view) {
        return;
    }

    UIColor *panel = AmethystResolveColor(AmethystColorPanel(), view.traitCollection);
    UIColor *border = [AmethystResolveColor(AmethystColorAccentMuted(), view.traitCollection) colorWithAlphaComponent:0.62];
    UIColor *shadowColor = AmethystResolveColor(AmethystDynamicColor(0.07, 0.20, 0.29, 0.01, 0.03, 0.05), view.traitCollection);
    UIColor *glossTop = [UIColor colorWithWhite:1.0 alpha:0.65];
    UIColor *glossBottom = [UIColor colorWithWhite:1.0 alpha:0.03];

    view.backgroundColor = [panel colorWithAlphaComponent:0.92];
    view.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = border.CGColor;
    view.layer.masksToBounds = NO;
    view.layer.shadowColor = shadowColor.CGColor;
    view.layer.shadowOpacity = 0.34f;
    view.layer.shadowOffset = CGSizeMake(0, 18);
    view.layer.shadowRadius = 28.0f;

    static NSString * const kGlossLayerName = @"amethyst.card.gloss";
    NSMutableArray<CALayer *> *layersToRemove = [NSMutableArray array];
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer.name isEqualToString:kGlossLayerName]) {
            [layersToRemove addObject:layer];
        }
    }
    for (CALayer *layer in layersToRemove) {
        [layer removeFromSuperlayer];
    }

    CAGradientLayer *gloss = [CAGradientLayer layer];
    gloss.name = kGlossLayerName;
    gloss.frame = view.bounds;
    gloss.cornerRadius = view.layer.cornerRadius;
    gloss.startPoint = CGPointMake(0.0, 0.0);
    gloss.endPoint = CGPointMake(0.9, 1.0);
    gloss.colors = @[(id)glossTop.CGColor, (id)glossBottom.CGColor];
    gloss.locations = @[@0.0, @0.58];
    gloss.needsDisplayOnBoundsChange = YES;
    gloss.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    [view.layer insertSublayer:gloss atIndex:0];

    AmethystApplyParallaxEffect(view, 6.5);
}

void AmethystApplyPrimaryButtonStyle(UIButton *button) {
    if (!button) {
        return;
    }
    UIColor *accent = AmethystColorAccent();
    UIColor *shadowColor = AmethystResolveColor(AmethystDynamicColor(0.04, 0.31, 0.22, 0.00, 0.15, 0.10), button.traitCollection);
    button.backgroundColor = accent;
    button.layer.cornerRadius = 14.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    button.layer.shadowColor = shadowColor.CGColor;
    button.layer.shadowOpacity = 0.52f;
    button.layer.shadowOffset = CGSizeMake(0, 14);
    button.layer.shadowRadius = 22.0f;
    button.clipsToBounds = NO;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    AmethystApplyParallaxEffect(button, 8.0);
}

void AmethystApplyPanelBackground(UIView *view) {
    if (!view) {
        return;
    }

    static NSInteger const kBackgroundTag = 91429;
    UITableView *tableView = [view isKindOfClass:UITableView.class] ? (UITableView *)view : nil;
    UIView *background = tableView ? tableView.backgroundView : [view viewWithTag:kBackgroundTag];
    CAGradientLayer *baseLayer = nil;
    CAGradientLayer *glowLayer = nil;
    CAGradientLayer *orbLayer = nil;
    if (!background) {
        background = [[UIView alloc] initWithFrame:view.bounds];
        background.tag = kBackgroundTag;
        background.userInteractionEnabled = NO;
        background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        if (tableView) {
            tableView.backgroundView = background;
        } else {
            [view insertSubview:background atIndex:0];
        }

        baseLayer = [CAGradientLayer layer];
        [background.layer addSublayer:baseLayer];

        glowLayer = [CAGradientLayer layer];
        [background.layer addSublayer:glowLayer];
        orbLayer = [CAGradientLayer layer];
        [background.layer addSublayer:orbLayer];
    } else if (background.layer.sublayers.count >= 3) {
        baseLayer = (CAGradientLayer *)background.layer.sublayers[0];
        glowLayer = (CAGradientLayer *)background.layer.sublayers[1];
        orbLayer = (CAGradientLayer *)background.layer.sublayers[2];
    } else {
        [background.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
        baseLayer = [CAGradientLayer layer];
        glowLayer = [CAGradientLayer layer];
        orbLayer = [CAGradientLayer layer];
        [background.layer addSublayer:baseLayer];
        [background.layer addSublayer:glowLayer];
        [background.layer addSublayer:orbLayer];
    }

    background.frame = view.bounds;

    UIColor *topColor = AmethystResolveColor(AmethystDynamicColor(0.92, 0.96, 0.99, 0.07, 0.09, 0.12), view.traitCollection);
    UIColor *middleColor = AmethystResolveColor(AmethystDynamicColor(0.87, 0.95, 0.93, 0.05, 0.08, 0.09), view.traitCollection);
    UIColor *bottomColor = AmethystResolveColor(AmethystDynamicColor(0.84, 0.91, 0.95, 0.03, 0.04, 0.06), view.traitCollection);
    UIColor *glowColor = [AmethystResolveColor(AmethystColorAccent(), view.traitCollection) colorWithAlphaComponent:0.28];
    UIColor *orbStrong = [AmethystResolveColor(AmethystColorAccent(), view.traitCollection) colorWithAlphaComponent:0.34];

    baseLayer.frame = background.bounds;
    baseLayer.startPoint = CGPointMake(0, 0);
    baseLayer.endPoint = CGPointMake(1, 1);
    baseLayer.colors = @[(id)topColor.CGColor, (id)middleColor.CGColor, (id)bottomColor.CGColor];
    baseLayer.locations = @[@0.0, @0.45, @1.0];

    glowLayer.frame = background.bounds;
    glowLayer.startPoint = CGPointMake(0.15, 0.0);
    glowLayer.endPoint = CGPointMake(0.85, 1.0);
    glowLayer.colors = @[(id)glowColor.CGColor, (id)UIColor.clearColor.CGColor];

    orbLayer.frame = background.bounds;
    orbLayer.startPoint = CGPointMake(0.96, 0.05);
    orbLayer.endPoint = CGPointMake(0.3, 0.8);
    orbLayer.colors = @[(id)orbStrong.CGColor, (id)UIColor.clearColor.CGColor];
    orbLayer.locations = @[@0.0, @0.62];
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
