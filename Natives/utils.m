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

static UIColor *AmethystVisionTintColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.14, 0.54, 0.82, 0.35, 0.75, 0.95);
    });
    return color;
}

static UIColor *AmethystVisionGlassColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.94, 0.97, 1.00, 0.16, 0.20, 0.26);
    });
    return color;
}

static UIColor *AmethystVisionBorderColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(1.00, 1.00, 1.00, 0.78, 0.85, 0.95);
    });
    return color;
}

static UIColor *AmethystVisionSelectedColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = AmethystVisionDynamicColor(0.66, 0.84, 1.00, 0.36, 0.55, 0.76);
    });
    return color;
}

void AmethystApplyVisionAppearance(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIColor *tint = AmethystVisionTintColor();
        [UIView appearance].tintColor = tint;

        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *navAppearance = [UINavigationBarAppearance new];
            [navAppearance configureWithTransparentBackground];
            navAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
            navAppearance.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.42];
            navAppearance.shadowColor = UIColor.clearColor;
            navAppearance.titleTextAttributes = @{
                NSForegroundColorAttributeName: UIColor.labelColor,
                NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
            };
            navAppearance.largeTitleTextAttributes = @{
                NSForegroundColorAttributeName: UIColor.labelColor,
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
            toolbarAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
            toolbarAppearance.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.36];
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
    });
}

void AmethystApplyVisionBackground(UIView *view) {
    if (!view) {
        return;
    }

    static NSInteger const kVisionBackgroundTag = 0xA11E0;
    static NSInteger const kVisionBlurTag = 0xA11E1;
    static NSInteger const kVisionTintTag = 0xA11E2;

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
        tableView.separatorColor = [AmethystVisionBorderColor() colorWithAlphaComponent:0.22];
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

    UIVisualEffectView *blurView = (UIVisualEffectView *)[background viewWithTag:kVisionBlurTag];
    if (![blurView isKindOfClass:UIVisualEffectView.class]) {
        [blurView removeFromSuperview];
        blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
        blurView.tag = kVisionBlurTag;
        blurView.frame = background.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:blurView];
    }
    if (@available(iOS 13.0, *)) {
        blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }

    UIView *tintView = [background viewWithTag:kVisionTintTag];
    if (!tintView) {
        tintView = [[UIView alloc] initWithFrame:background.bounds];
        tintView.tag = kVisionTintTag;
        tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [background addSubview:tintView];
    }
    tintView.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.38];
}

void AmethystApplyVisionSurface(UIView *view, CGFloat cornerRadius) {
    if (!view) {
        return;
    }

    view.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.62];
    view.layer.cornerRadius = cornerRadius > 0 ? cornerRadius : 13.0;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [AmethystVisionBorderColor() colorWithAlphaComponent:0.24].CGColor;
    view.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    view.layer.shadowOpacity = 0.08f;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 10.0f;
    view.layer.masksToBounds = NO;
}

void AmethystApplyVisionCell(UITableViewCell *cell) {
    if (!cell) {
        return;
    }

    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;

    UIView *backgroundView = cell.backgroundView;
    if (!backgroundView) {
        backgroundView = [[UIView alloc] initWithFrame:cell.bounds];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        cell.backgroundView = backgroundView;
    }
    backgroundView.frame = cell.bounds;
    AmethystApplyVisionSurface(backgroundView, 12.0);

    UIView *selectedBackground = cell.selectedBackgroundView;
    if (!selectedBackground) {
        selectedBackground = [[UIView alloc] initWithFrame:cell.bounds];
        selectedBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        cell.selectedBackgroundView = selectedBackground;
    }
    selectedBackground.frame = cell.bounds;
    selectedBackground.backgroundColor = [AmethystVisionSelectedColor() colorWithAlphaComponent:0.55];
    selectedBackground.layer.cornerRadius = backgroundView.layer.cornerRadius;
    if (@available(iOS 13.0, *)) {
        selectedBackground.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

void AmethystApplyVisionInput(UITextField *textField) {
    if (!textField) {
        return;
    }

    textField.backgroundColor = [AmethystVisionGlassColor() colorWithAlphaComponent:0.66];
    textField.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) {
        textField.layer.cornerCurve = kCACornerCurveContinuous;
    }
    textField.layer.borderWidth = 1.0;
    textField.layer.borderColor = [AmethystVisionBorderColor() colorWithAlphaComponent:0.26].CGColor;
    textField.layer.masksToBounds = YES;
}

void AmethystApplyVisionPrimaryButton(UIButton *button) {
    if (!button) {
        return;
    }

    UIColor *tint = AmethystVisionTintColor();
    button.backgroundColor = [tint colorWithAlphaComponent:0.86];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.06 green:0.20 blue:0.34 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.18f;
    button.layer.shadowOffset = CGSizeMake(0, 5);
    button.layer.shadowRadius = 10.0f;
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
