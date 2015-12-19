//
//  ImageQualityAnalyzerTests.m
//  TBScope
//
//  Created by Jason Ardell on 10/1/15.
//  Copyright (c) 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "TBScopeCamera.h"
#import "ImageQualityAnalyzer.h"
#import <GPUImage/GPUImage.h>
#import <PromiseKit/Promise.h>
#import <PromiseKit/Promise+Hang.h>

@interface ImageQualityAnalyzerTests : XCTestCase
@end

@implementation ImageQualityAnalyzerTests

static int const kLastBoundaryImageIndex = 10;
static int const kLastContentImageIndex = 8;
static int const kLastEmptyImageIndex = 11;

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testThatFocusedBrightfieldImageIsSharperThanBlurryBrightfield {
    [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];

    ImageQuality focusedIQ = [self _imageQualityForImageNamed:@"bf_focused"];
    ImageQuality blurryIQ = [self _imageQualityForImageNamed:@"bf_blurry"];

    // Expect bf_focused_sharpness > bf_blurry_sharpness
    XCTAssert(focusedIQ.tenengrad3 > blurryIQ.tenengrad3);
}

- (void)testThatFocusedFluorescenceImagesHaveHigherContrastThanBlurryFluorescence {
    // Calculate focus metrics
    NSDecimalNumber *beads_500_01_001 = [self _focusMetricForImageAtPath:@"IMG_001.JPG"];
    NSDecimalNumber *beads_500_01_002 = [self _focusMetricForImageAtPath:@"IMG_002.JPG"];
    NSDecimalNumber *beads_500_01_003 = [self _focusMetricForImageAtPath:@"IMG_003.JPG"];
    NSDecimalNumber *beads_500_01_004 = [self _focusMetricForImageAtPath:@"IMG_004.JPG"];
    NSDecimalNumber *beads_500_01_005 = [self _focusMetricForImageAtPath:@"IMG_005.JPG"];
    NSDecimalNumber *beads_500_01_006 = [self _focusMetricForImageAtPath:@"IMG_006.JPG"];
    NSDecimalNumber *beads_500_01_007 = [self _focusMetricForImageAtPath:@"IMG_007.JPG"];
    NSDecimalNumber *beads_500_02_3041 = [self _focusMetricForImageAtPath:@"IMG_3041.JPG"];
    NSDecimalNumber *beads_500_02_3042 = [self _focusMetricForImageAtPath:@"IMG_3042.JPG"];
    NSDecimalNumber *beads_500_02_3043 = [self _focusMetricForImageAtPath:@"IMG_3043.JPG"];
    NSDecimalNumber *beads_500_02_3044 = [self _focusMetricForImageAtPath:@"IMG_3044.JPG"];
    NSDecimalNumber *beads_500_02_3045 = [self _focusMetricForImageAtPath:@"IMG_3045.JPG"];
    NSDecimalNumber *beads_500_02_3046 = [self _focusMetricForImageAtPath:@"IMG_3046.JPG"];
    NSDecimalNumber *beads_500_02_3047 = [self _focusMetricForImageAtPath:@"IMG_3047.JPG"];
    NSDecimalNumber *beads_500_02_3048 = [self _focusMetricForImageAtPath:@"IMG_3048.JPG"];
    NSDecimalNumber *beads_500_02_3049 = [self _focusMetricForImageAtPath:@"IMG_3049.JPG"];
    NSDecimalNumber *beads_500_03_3427 = [self _focusMetricForImageAtPath:@"IMG_3427.JPG"];
    NSDecimalNumber *beads_500_03_3428 = [self _focusMetricForImageAtPath:@"IMG_3428.JPG"];
    NSDecimalNumber *beads_500_03_3429 = [self _focusMetricForImageAtPath:@"IMG_3429.JPG"];
    NSDecimalNumber *beads_500_03_3430 = [self _focusMetricForImageAtPath:@"IMG_3430.JPG"];
    NSDecimalNumber *beads_500_03_3431 = [self _focusMetricForImageAtPath:@"IMG_3431.JPG"];
    NSDecimalNumber *beads_500_03_3432 = [self _focusMetricForImageAtPath:@"IMG_3432.JPG"];
    NSDecimalNumber *beads_500_03_3433 = [self _focusMetricForImageAtPath:@"IMG_3433.JPG"];
    NSDecimalNumber *beads_500_03_3434 = [self _focusMetricForImageAtPath:@"IMG_3434.JPG"];
    NSDecimalNumber *beads_500_03_3435 = [self _focusMetricForImageAtPath:@"IMG_3435.JPG"];
    NSDecimalNumber *beads_500_03_3436 = [self _focusMetricForImageAtPath:@"IMG_3436.JPG"];
    NSDecimalNumber *beads_500_03_3437 = [self _focusMetricForImageAtPath:@"IMG_3437.JPG"];
    NSDecimalNumber *beads_500_03_3438 = [self _focusMetricForImageAtPath:@"IMG_3438.JPG"];
    NSDecimalNumber *beads_500_03_3439 = [self _focusMetricForImageAtPath:@"IMG_3439.JPG"];
    NSDecimalNumber *beads_500_03_3440 = [self _focusMetricForImageAtPath:@"IMG_3440.JPG"];
    NSDecimalNumber *beads_500_03_3441 = [self _focusMetricForImageAtPath:@"IMG_3441.JPG"];
    NSDecimalNumber *beads_500_03_3442 = [self _focusMetricForImageAtPath:@"IMG_3442.JPG"];
    NSDecimalNumber *beads_500_03_3443 = [self _focusMetricForImageAtPath:@"IMG_3443.JPG"];
    NSDecimalNumber *beads_500_03_3444 = [self _focusMetricForImageAtPath:@"IMG_3444.JPG"];
    NSDecimalNumber *beads_500_03_3445 = [self _focusMetricForImageAtPath:@"IMG_3445.JPG"];
    NSDecimalNumber *beads_500_03_3446 = [self _focusMetricForImageAtPath:@"IMG_3446.JPG"];
    NSDecimalNumber *beads_500_03_3447 = [self _focusMetricForImageAtPath:@"IMG_3447.JPG"];
    NSDecimalNumber *beads_500_03_3448 = [self _focusMetricForImageAtPath:@"IMG_3448.JPG"];
    NSDecimalNumber *beads_500_03_3449 = [self _focusMetricForImageAtPath:@"IMG_3449.JPG"];
    NSDecimalNumber *beads_500_03_3450 = [self _focusMetricForImageAtPath:@"IMG_3450.JPG"];
    NSDecimalNumber *beads_500_03_3451 = [self _focusMetricForImageAtPath:@"IMG_3451.JPG"];
    NSDecimalNumber *beads_500_03_3452 = [self _focusMetricForImageAtPath:@"IMG_3452.JPG"];
    NSDecimalNumber *beads_100_01_3500 = [self _focusMetricForImageAtPath:@"IMG_3500.JPG"];
    NSDecimalNumber *beads_100_01_3501 = [self _focusMetricForImageAtPath:@"IMG_3501.JPG"];
    NSDecimalNumber *beads_100_01_3502 = [self _focusMetricForImageAtPath:@"IMG_3502.JPG"];
    NSDecimalNumber *beads_100_01_3503 = [self _focusMetricForImageAtPath:@"IMG_3503.JPG"];
    NSDecimalNumber *beads_100_01_3504 = [self _focusMetricForImageAtPath:@"IMG_3504.JPG"];
    NSDecimalNumber *beads_100_01_3505 = [self _focusMetricForImageAtPath:@"IMG_3505.JPG"];
    NSDecimalNumber *beads_100_01_3506 = [self _focusMetricForImageAtPath:@"IMG_3506.JPG"];
    NSDecimalNumber *beads_100_01_3507 = [self _focusMetricForImageAtPath:@"IMG_3507.JPG"];
    NSDecimalNumber *beads_100_01_3508 = [self _focusMetricForImageAtPath:@"IMG_3508.JPG"];
    NSDecimalNumber *beads_100_01_3509 = [self _focusMetricForImageAtPath:@"IMG_3509.JPG"];
    NSDecimalNumber *beads_100_01_3510 = [self _focusMetricForImageAtPath:@"IMG_3510.JPG"];
    NSDecimalNumber *beads_100_01_3511 = [self _focusMetricForImageAtPath:@"IMG_3511.JPG"];
    NSDecimalNumber *beads_100_01_3512 = [self _focusMetricForImageAtPath:@"IMG_3512.JPG"];
    NSDecimalNumber *beads_100_01_3513 = [self _focusMetricForImageAtPath:@"IMG_3513.JPG"];
    NSDecimalNumber *beads_100_01_3514 = [self _focusMetricForImageAtPath:@"IMG_3514.JPG"];
    NSDecimalNumber *beads_100_01_3515 = [self _focusMetricForImageAtPath:@"IMG_3515.JPG"];
    NSDecimalNumber *beads_100_01_3516 = [self _focusMetricForImageAtPath:@"IMG_3516.JPG"];
    NSDecimalNumber *beads_100_01_3517 = [self _focusMetricForImageAtPath:@"IMG_3517.JPG"];
    NSDecimalNumber *beads_100_01_3518 = [self _focusMetricForImageAtPath:@"IMG_3518.JPG"];
    NSDecimalNumber *beads_100_01_3519 = [self _focusMetricForImageAtPath:@"IMG_3519.JPG"];
    NSDecimalNumber *beads_100_01_3520 = [self _focusMetricForImageAtPath:@"IMG_3520.JPG"];
    NSDecimalNumber *beads_100_01_3521 = [self _focusMetricForImageAtPath:@"IMG_3521.JPG"];
    NSDecimalNumber *beads_100_01_3522 = [self _focusMetricForImageAtPath:@"IMG_3522.JPG"];
    NSDecimalNumber *beads_100_01_3523 = [self _focusMetricForImageAtPath:@"IMG_3523.JPG"];
    NSDecimalNumber *beads_100_01_3524 = [self _focusMetricForImageAtPath:@"IMG_3524.JPG"];
    NSDecimalNumber *beads_100_01_3525 = [self _focusMetricForImageAtPath:@"IMG_3525.JPG"];
    NSDecimalNumber *beads_100_01_3526 = [self _focusMetricForImageAtPath:@"IMG_3526.JPG"];
    NSDecimalNumber *beads_100_01_3527 = [self _focusMetricForImageAtPath:@"IMG_3527.JPG"];
    NSDecimalNumber *beads_100_01_3528 = [self _focusMetricForImageAtPath:@"IMG_3528.JPG"];
    NSDecimalNumber *beads_100_01_3529 = [self _focusMetricForImageAtPath:@"IMG_3529.JPG"];
    NSDecimalNumber *beads_100_01_3530 = [self _focusMetricForImageAtPath:@"IMG_3530.JPG"];
    NSDecimalNumber *beads_100_01_3531 = [self _focusMetricForImageAtPath:@"IMG_3531.JPG"];
    NSDecimalNumber *beads_100_01_3532 = [self _focusMetricForImageAtPath:@"IMG_3532.JPG"];
    NSDecimalNumber *beads_100_01_3533 = [self _focusMetricForImageAtPath:@"IMG_3533.JPG"];
    NSDecimalNumber *beads_100_01_3534 = [self _focusMetricForImageAtPath:@"IMG_3534.JPG"];
    NSDecimalNumber *beads_100_01_3535 = [self _focusMetricForImageAtPath:@"IMG_3535.JPG"];
    NSDecimalNumber *beads_100_01_3536 = [self _focusMetricForImageAtPath:@"IMG_3536.JPG"];
    NSDecimalNumber *beads_100_01_3537 = [self _focusMetricForImageAtPath:@"IMG_3537.JPG"];
    NSDecimalNumber *beads_100_01_3538 = [self _focusMetricForImageAtPath:@"IMG_3538.JPG"];
    NSDecimalNumber *beads_100_01_3539 = [self _focusMetricForImageAtPath:@"IMG_3539.JPG"];
    NSDecimalNumber *beads_100_01_3540 = [self _focusMetricForImageAtPath:@"IMG_3540.JPG"];
    NSDecimalNumber *beads_100_01_3541 = [self _focusMetricForImageAtPath:@"IMG_3541.JPG"];
    NSDecimalNumber *beads_100_01_3542 = [self _focusMetricForImageAtPath:@"IMG_3542.JPG"];
    NSDecimalNumber *beads_100_01_3543 = [self _focusMetricForImageAtPath:@"IMG_3543.JPG"];
    NSDecimalNumber *beads_100_01_3544 = [self _focusMetricForImageAtPath:@"IMG_3544.JPG"];
    NSDecimalNumber *beads_100_01_3545 = [self _focusMetricForImageAtPath:@"IMG_3545.JPG"];
    NSDecimalNumber *beads_100_01_3546 = [self _focusMetricForImageAtPath:@"IMG_3546.JPG"];
    NSDecimalNumber *beads_100_01_3547 = [self _focusMetricForImageAtPath:@"IMG_3547.JPG"];
    NSDecimalNumber *beads_100_01_3548 = [self _focusMetricForImageAtPath:@"IMG_3548.JPG"];
    NSDecimalNumber *beads_100_01_3549 = [self _focusMetricForImageAtPath:@"IMG_3549.JPG"];
    NSDecimalNumber *beads_100_01_3550 = [self _focusMetricForImageAtPath:@"IMG_3550.JPG"];
    NSDecimalNumber *beads_100_01_3551 = [self _focusMetricForImageAtPath:@"IMG_3551.JPG"];
    NSDecimalNumber *beads_100_01_3552 = [self _focusMetricForImageAtPath:@"IMG_3552.JPG"];
    NSDecimalNumber *beads_100_01_3553 = [self _focusMetricForImageAtPath:@"IMG_3553.JPG"];
    NSDecimalNumber *beads_100_01_3554 = [self _focusMetricForImageAtPath:@"IMG_3554.JPG"];
    NSDecimalNumber *beads_100_01_3555 = [self _focusMetricForImageAtPath:@"IMG_3555.JPG"];
    NSDecimalNumber *beads_100_01_3556 = [self _focusMetricForImageAtPath:@"IMG_3556.JPG"];
    NSDecimalNumber *beads_100_01_3557 = [self _focusMetricForImageAtPath:@"IMG_3557.JPG"];
    NSDecimalNumber *beads_100_01_3558 = [self _focusMetricForImageAtPath:@"IMG_3558.JPG"];
    NSDecimalNumber *beads_100_01_3559 = [self _focusMetricForImageAtPath:@"IMG_3559.JPG"];
    NSDecimalNumber *beads_100_01_3560 = [self _focusMetricForImageAtPath:@"IMG_3560.JPG"];
    NSDecimalNumber *beads_100_01_3561 = [self _focusMetricForImageAtPath:@"IMG_3561.JPG"];
    NSDecimalNumber *beads_100_01_3562 = [self _focusMetricForImageAtPath:@"IMG_3562.JPG"];
    NSDecimalNumber *beads_100_01_3563 = [self _focusMetricForImageAtPath:@"IMG_3563.JPG"];
    NSDecimalNumber *beads_100_01_3564 = [self _focusMetricForImageAtPath:@"IMG_3564.JPG"];
    NSDecimalNumber *beads_100_01_3565 = [self _focusMetricForImageAtPath:@"IMG_3565.JPG"];
    NSDecimalNumber *beads_100_01_3566 = [self _focusMetricForImageAtPath:@"IMG_3566.JPG"];
    NSDecimalNumber *beads_100_01_3567 = [self _focusMetricForImageAtPath:@"IMG_3567.JPG"];
    NSDecimalNumber *beads_100_01_3568 = [self _focusMetricForImageAtPath:@"IMG_3568.JPG"];
    NSDecimalNumber *beads_100_01_3569 = [self _focusMetricForImageAtPath:@"IMG_3569.JPG"];
    NSDecimalNumber *beads_100_01_3570 = [self _focusMetricForImageAtPath:@"IMG_3570.JPG"];
    NSDecimalNumber *beads_100_01_3571 = [self _focusMetricForImageAtPath:@"IMG_3571.JPG"];
    NSDecimalNumber *beads_100_01_3572 = [self _focusMetricForImageAtPath:@"IMG_3572.JPG"];
    NSDecimalNumber *beads_100_01_3573 = [self _focusMetricForImageAtPath:@"IMG_3573.JPG"];
    NSDecimalNumber *beads_100_01_3574 = [self _focusMetricForImageAtPath:@"IMG_3574.JPG"];
    NSDecimalNumber *beads_100_01_3575 = [self _focusMetricForImageAtPath:@"IMG_3575.JPG"];
    NSDecimalNumber *beads_100_01_3576 = [self _focusMetricForImageAtPath:@"IMG_3576.JPG"];
    NSDecimalNumber *beads_100_01_3577 = [self _focusMetricForImageAtPath:@"IMG_3577.JPG"];
    NSDecimalNumber *beads_100_01_3578 = [self _focusMetricForImageAtPath:@"IMG_3578.JPG"];
    NSDecimalNumber *beads_100_01_3579 = [self _focusMetricForImageAtPath:@"IMG_3579.JPG"];
    NSDecimalNumber *beads_100_01_3580 = [self _focusMetricForImageAtPath:@"IMG_3580.JPG"];
    NSDecimalNumber *beads_100_01_3581 = [self _focusMetricForImageAtPath:@"IMG_3581.JPG"];
    NSDecimalNumber *beads_100_01_3582 = [self _focusMetricForImageAtPath:@"IMG_3582.JPG"];
    NSDecimalNumber *beads_100_01_3583 = [self _focusMetricForImageAtPath:@"IMG_3583.JPG"];
    NSDecimalNumber *beads_100_01_3584 = [self _focusMetricForImageAtPath:@"IMG_3584.JPG"];
    NSDecimalNumber *beads_100_01_3585 = [self _focusMetricForImageAtPath:@"IMG_3585.JPG"];
    NSDecimalNumber *beads_100_01_3586 = [self _focusMetricForImageAtPath:@"IMG_3586.JPG"];
    NSDecimalNumber *beads_100_01_3587 = [self _focusMetricForImageAtPath:@"IMG_3587.JPG"];
    NSDecimalNumber *beads_100_01_3588 = [self _focusMetricForImageAtPath:@"IMG_3588.JPG"];
    NSDecimalNumber *beads_100_01_3589 = [self _focusMetricForImageAtPath:@"IMG_3589.JPG"];
    NSDecimalNumber *beads_100_01_3590 = [self _focusMetricForImageAtPath:@"IMG_3590.JPG"];
    NSDecimalNumber *beads_100_01_3591 = [self _focusMetricForImageAtPath:@"IMG_3591.JPG"];
    NSDecimalNumber *beads_100_01_3592 = [self _focusMetricForImageAtPath:@"IMG_3592.JPG"];
    NSDecimalNumber *beads_100_01_3593 = [self _focusMetricForImageAtPath:@"IMG_3593.JPG"];
    NSDecimalNumber *beads_100_01_3594 = [self _focusMetricForImageAtPath:@"IMG_3594.JPG"];
    NSDecimalNumber *beads_100_01_3595 = [self _focusMetricForImageAtPath:@"IMG_3595.JPG"];
    NSDecimalNumber *beads_100_01_3596 = [self _focusMetricForImageAtPath:@"IMG_3596.JPG"];
    NSDecimalNumber *beads_100_01_3597 = [self _focusMetricForImageAtPath:@"IMG_3597.JPG"];
    NSDecimalNumber *beads_100_01_3598 = [self _focusMetricForImageAtPath:@"IMG_3598.JPG"];
    NSDecimalNumber *beads_100_01_3599 = [self _focusMetricForImageAtPath:@"IMG_3599.JPG"];
    NSDecimalNumber *beads_100_01_3600 = [self _focusMetricForImageAtPath:@"IMG_3600.JPG"];
    NSDecimalNumber *beads_100_01_3601 = [self _focusMetricForImageAtPath:@"IMG_3601.JPG"];
    NSDecimalNumber *beads_100_01_3602 = [self _focusMetricForImageAtPath:@"IMG_3602.JPG"];
    NSDecimalNumber *beads_100_01_3603 = [self _focusMetricForImageAtPath:@"IMG_3603.JPG"];
    NSDecimalNumber *beads_100_01_3604 = [self _focusMetricForImageAtPath:@"IMG_3604.JPG"];

    NSArray *testCases = @[
        // Blurrier image       Sharper image
        @[ beads_500_01_001,    beads_500_01_002    ],
        @[ beads_500_01_002,    beads_500_01_003    ],
        @[ beads_500_01_003,    beads_500_01_004    ],
        @[ beads_500_01_004,    beads_500_01_005    ],
        @[ beads_500_01_005,    beads_500_01_006    ],
        @[ beads_500_01_006,    beads_500_01_007    ],
        @[ beads_500_02_3041,   beads_500_02_3042   ],
        @[ beads_500_02_3042,   beads_500_02_3043   ],
        @[ beads_500_02_3043,   beads_500_02_3044   ],
        @[ beads_500_02_3044,   beads_500_02_3045   ],
        @[ beads_500_02_3045,   beads_500_02_3046   ],
        @[ beads_500_02_3046,   beads_500_02_3047   ],
        @[ beads_500_02_3047,   beads_500_02_3048   ],
        @[ beads_500_02_3048,   beads_500_02_3049   ],
        @[ beads_500_03_3427,   beads_500_03_3428   ],
        @[ beads_500_03_3428,   beads_500_03_3429   ],
        @[ beads_500_03_3429,   beads_500_03_3430   ],
        @[ beads_500_03_3430,   beads_500_03_3431   ],
        @[ beads_500_03_3431,   beads_500_03_3432   ],
        @[ beads_500_03_3432,   beads_500_03_3433   ],
        @[ beads_500_03_3433,   beads_500_03_3434   ],
        @[ beads_500_03_3434,   beads_500_03_3435   ],
        @[ beads_500_03_3435,   beads_500_03_3436   ],
        @[ beads_500_03_3436,   beads_500_03_3437   ],
        @[ beads_500_03_3437,   beads_500_03_3438   ],
        @[ beads_500_03_3438,   beads_500_03_3439   ],
        @[ beads_500_03_3439,   beads_500_03_3440   ],
        @[ beads_500_03_3440,   beads_500_03_3441   ],
        @[ beads_500_03_3441,   beads_500_03_3442   ],
        @[ beads_500_03_3442,   beads_500_03_3443   ],
        @[ beads_500_03_3443,   beads_500_03_3444   ],
        @[ beads_500_03_3444,   beads_500_03_3445   ],
        @[ beads_500_03_3445,   beads_500_03_3446   ],
        @[ beads_500_03_3446,   beads_500_03_3447   ],
        @[ beads_500_03_3447,   beads_500_03_3448   ],
        @[ beads_500_03_3448,   beads_500_03_3449   ],
        @[ beads_500_03_3449,   beads_500_03_3450   ],
        @[ beads_500_03_3450,   beads_500_03_3451   ],
        @[ beads_500_03_3451,   beads_500_03_3452   ],
        @[ beads_100_01_3500,   beads_100_01_3501   ],
        @[ beads_100_01_3501,   beads_100_01_3502   ],
        @[ beads_100_01_3502,   beads_100_01_3503   ],
        @[ beads_100_01_3503,   beads_100_01_3504   ],
        @[ beads_100_01_3504,   beads_100_01_3505   ],
        @[ beads_100_01_3505,   beads_100_01_3506   ],
        @[ beads_100_01_3506,   beads_100_01_3507   ],
        @[ beads_100_01_3507,   beads_100_01_3508   ],
        @[ beads_100_01_3508,   beads_100_01_3509   ],
        @[ beads_100_01_3509,   beads_100_01_3510   ],
        @[ beads_100_01_3510,   beads_100_01_3511   ],
        @[ beads_100_01_3511,   beads_100_01_3512   ],
        @[ beads_100_01_3512,   beads_100_01_3513   ],
        @[ beads_100_01_3513,   beads_100_01_3514   ],
        @[ beads_100_01_3514,   beads_100_01_3515   ],
        @[ beads_100_01_3515,   beads_100_01_3516   ],
        @[ beads_100_01_3516,   beads_100_01_3517   ],
        @[ beads_100_01_3517,   beads_100_01_3518   ],
        @[ beads_100_01_3518,   beads_100_01_3519   ],
        @[ beads_100_01_3519,   beads_100_01_3520   ],
        @[ beads_100_01_3520,   beads_100_01_3521   ],
        @[ beads_100_01_3521,   beads_100_01_3522   ],
        @[ beads_100_01_3522,   beads_100_01_3523   ],
        @[ beads_100_01_3523,   beads_100_01_3524   ],
        @[ beads_100_01_3524,   beads_100_01_3525   ],
        @[ beads_100_01_3525,   beads_100_01_3526   ],
        @[ beads_100_01_3526,   beads_100_01_3527   ],
        @[ beads_100_01_3527,   beads_100_01_3528   ],
        @[ beads_100_01_3528,   beads_100_01_3529   ],
        @[ beads_100_01_3529,   beads_100_01_3530   ],
        @[ beads_100_01_3530,   beads_100_01_3531   ],
        @[ beads_100_01_3531,   beads_100_01_3532   ],
        @[ beads_100_01_3532,   beads_100_01_3533   ],
        @[ beads_100_01_3533,   beads_100_01_3534   ],
        @[ beads_100_01_3534,   beads_100_01_3535   ],
        @[ beads_100_01_3535,   beads_100_01_3536   ],
        @[ beads_100_01_3536,   beads_100_01_3537   ],
        @[ beads_100_01_3537,   beads_100_01_3538   ],
        @[ beads_100_01_3538,   beads_100_01_3539   ],
        @[ beads_100_01_3539,   beads_100_01_3540   ],
        @[ beads_100_01_3540,   beads_100_01_3541   ],
        @[ beads_100_01_3541,   beads_100_01_3542   ],
        @[ beads_100_01_3542,   beads_100_01_3543   ],
        @[ beads_100_01_3543,   beads_100_01_3544   ],
        @[ beads_100_01_3544,   beads_100_01_3545   ],
        @[ beads_100_01_3545,   beads_100_01_3546   ],
        @[ beads_100_01_3546,   beads_100_01_3547   ],
        @[ beads_100_01_3547,   beads_100_01_3548   ],
        @[ beads_100_01_3548,   beads_100_01_3549   ],
        @[ beads_100_01_3549,   beads_100_01_3550   ],
        @[ beads_100_01_3550,   beads_100_01_3551   ],
        @[ beads_100_01_3551,   beads_100_01_3552   ],
        @[ beads_100_01_3552,   beads_100_01_3553   ],
        @[ beads_100_01_3553,   beads_100_01_3554   ],
        @[ beads_100_01_3554,   beads_100_01_3555   ],
        @[ beads_100_01_3555,   beads_100_01_3556   ],
        @[ beads_100_01_3556,   beads_100_01_3557   ],
        @[ beads_100_01_3557,   beads_100_01_3558   ],
        @[ beads_100_01_3558,   beads_100_01_3559   ],
        @[ beads_100_01_3559,   beads_100_01_3560   ],
        @[ beads_100_01_3560,   beads_100_01_3561   ],
        @[ beads_100_01_3561,   beads_100_01_3562   ],
        @[ beads_100_01_3562,   beads_100_01_3563   ],
        @[ beads_100_01_3563,   beads_100_01_3564   ],
        @[ beads_100_01_3564,   beads_100_01_3565   ],
        @[ beads_100_01_3565,   beads_100_01_3566   ],
        @[ beads_100_01_3566,   beads_100_01_3567   ],
        @[ beads_100_01_3567,   beads_100_01_3568   ],
        @[ beads_100_01_3568,   beads_100_01_3569   ],
        @[ beads_100_01_3569,   beads_100_01_3570   ],
        @[ beads_100_01_3570,   beads_100_01_3571   ],
        @[ beads_100_01_3571,   beads_100_01_3572   ],
        @[ beads_100_01_3572,   beads_100_01_3573   ],
        @[ beads_100_01_3573,   beads_100_01_3574   ],
        @[ beads_100_01_3574,   beads_100_01_3575   ],
        @[ beads_100_01_3575,   beads_100_01_3576   ],
        @[ beads_100_01_3576,   beads_100_01_3577   ],
        @[ beads_100_01_3577,   beads_100_01_3578   ],
        @[ beads_100_01_3578,   beads_100_01_3579   ],
        @[ beads_100_01_3579,   beads_100_01_3580   ],
        @[ beads_100_01_3580,   beads_100_01_3581   ],
        @[ beads_100_01_3581,   beads_100_01_3582   ],
        @[ beads_100_01_3582,   beads_100_01_3583   ],
        @[ beads_100_01_3583,   beads_100_01_3584   ],
        @[ beads_100_01_3584,   beads_100_01_3585   ],
        @[ beads_100_01_3585,   beads_100_01_3586   ],
        @[ beads_100_01_3586,   beads_100_01_3587   ],
        @[ beads_100_01_3587,   beads_100_01_3588   ],
        @[ beads_100_01_3588,   beads_100_01_3589   ],
        @[ beads_100_01_3589,   beads_100_01_3590   ],
        @[ beads_100_01_3590,   beads_100_01_3591   ],
        @[ beads_100_01_3591,   beads_100_01_3592   ],
        @[ beads_100_01_3592,   beads_100_01_3593   ],
        @[ beads_100_01_3593,   beads_100_01_3594   ],
        @[ beads_100_01_3594,   beads_100_01_3595   ],
        @[ beads_100_01_3595,   beads_100_01_3596   ],
        @[ beads_100_01_3596,   beads_100_01_3597   ],
        @[ beads_100_01_3597,   beads_100_01_3598   ],
        @[ beads_100_01_3598,   beads_100_01_3599   ],
        @[ beads_100_01_3599,   beads_100_01_3600   ],
        @[ beads_100_01_3600,   beads_100_01_3601   ],
        @[ beads_100_01_3601,   beads_100_01_3602   ],
        @[ beads_100_01_3602,   beads_100_01_3603   ],
        @[ beads_100_01_3603,   beads_100_01_3604   ],
    ];
    for (NSArray *testCase in testCases) {
        NSDecimalNumber *blurrierContrast = testCase[0];
        NSDecimalNumber *sharperContrast  = testCase[1];
        XCTAssertGreaterThan([sharperContrast doubleValue], [blurrierContrast doubleValue]);
    }
}

- (void)testThatBoundaryDetectionWorks {
    NSMutableArray *testCases = [[NSMutableArray alloc] init];

    // Calculate content scores for all images
    NSDictionary *scores = @{
                             @"boundary" : [[NSMutableDictionary alloc] init],
                             @"content"  : [[NSMutableDictionary alloc] init],
                             @"empty"    : [[NSMutableDictionary alloc] init],
                             };
    for (int i=1; i<=kLastBoundaryImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_boundary_%02d", i];
        NSDecimalNumber *score = [self _boundaryScoreForImageNamed:imageName];
        [scores[@"boundary"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }
    for (int i=1; i<=kLastContentImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_content_%02d", i];
        NSDecimalNumber *score = [self _boundaryScoreForImageNamed:imageName];
        [scores[@"content"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }
    for (int i=1; i<=kLastEmptyImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_empty_%02d", i];
        NSDecimalNumber *score = [self _boundaryScoreForImageNamed:imageName];
        [scores[@"empty"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }

    for (int boundaryIndex=1; boundaryIndex<=kLastBoundaryImageIndex; boundaryIndex++) {
        // Boundary images have higher boundary score than content images
        for (int contentIndex=1; contentIndex<=kLastContentImageIndex; contentIndex++) {
            NSArray *testCase = @[
                                  scores[@"boundary"][[NSNumber numberWithInt:boundaryIndex]],
                                  scores[@"content"][[NSNumber numberWithInt:contentIndex]],
                                  ];
            [testCases addObject:testCase];
        }

        // Boundary images have higher boundary score than empty images
        for (int emptyIndex=1; emptyIndex<=kLastEmptyImageIndex; emptyIndex++) {
            NSArray *testCase = @[
                                  scores[@"boundary"][[NSNumber numberWithInt:boundaryIndex]],
                                  scores[@"empty"][[NSNumber numberWithInt:emptyIndex]],
                                  ];
            [testCases addObject:testCase];
        }
    }

    for (NSArray *testCase in testCases) {
        NSDecimalNumber *higherContentScore = testCase[0];
        NSDecimalNumber *lowerContentScore = testCase[1];
        XCTAssertGreaterThan([higherContentScore doubleValue], [lowerContentScore doubleValue]);
    }
}

- (void)testThatContentDetectionWorks {
    NSMutableArray *testCases = [[NSMutableArray alloc] init];

    // Set focus mode to FL so ImageQuality calculates contrast
    int focusMode = TBScopeCameraFocusModeContrast;
    [[TBScopeCamera sharedCamera] setFocusMode:focusMode];

    // Calculate content scores for all images
    NSDictionary *scores = @{
                             @"content"  : [[NSMutableDictionary alloc] init],
                             @"empty"    : [[NSMutableDictionary alloc] init],
                             };
    for (int i=1; i<=kLastContentImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_content_%02d", i];
        NSDecimalNumber *score = [self _contentScoreForImageNamed:imageName];
        [scores[@"content"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }
    for (int i=1; i<=kLastEmptyImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_empty_%02d", i];
        NSDecimalNumber *score = [self _contentScoreForImageNamed:imageName];
        [scores[@"empty"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }

    for (int contentIndex=1; contentIndex<=kLastContentImageIndex; contentIndex++) {
        // Content images have higher content score than empty images
        for (int emptyIndex=1; emptyIndex<=kLastEmptyImageIndex; emptyIndex++) {
            NSArray *testCase = @[
                                  scores[@"content"][[NSNumber numberWithInt:contentIndex]],
                                  scores[@"empty"][[NSNumber numberWithInt:emptyIndex]],
                                  ];
            [testCases addObject:testCase];
        }
    }

    for (NSArray *testCase in testCases) {
        NSDecimalNumber *higherContentScore = testCase[0];
        NSDecimalNumber *lowerContentScore = testCase[1];
        XCTAssertGreaterThan([higherContentScore doubleValue], [lowerContentScore doubleValue]);
    }
}

#pragma helper methods

- (NSDecimalNumber *)_focusMetricForImageAtPath:(NSString *)imagePath {
    // Load the image
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] resourcePath];
    NSString *filePath = [bundlePath stringByAppendingPathComponent:imagePath];
    UIImage *image = [UIImage imageWithContentsOfFile:filePath];

    // Convert image to GPU input
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:image];

    // Discard all but green channel
    GPUImageColorMatrixFilter *colorFilter = [[GPUImageColorMatrixFilter alloc] init];
    [colorFilter setColorMatrix:(GPUMatrix4x4){
        { 0.f, 0.f, 0.f, 0.f },
        { 0.f, 1.f, 0.f, 0.f },
        { 0.f, 0.f, 0.f, 0.f },
        { 0.f, 0.f, 0.f, 1.f },
    }];
    [stillImageSource addTarget:colorFilter];

    // Crop the image to a square
    double captureWidth = 1920.0;
    double captureHeight = 1080.0;
    double targetWidth = 1080;
    double targetHeight = 1080;
    double cropFromLeft = (captureWidth - targetWidth) / captureWidth / 2.0;
    double cropFromTop = (captureHeight - targetHeight) / captureHeight / 2.0;
    double width = 1.0 - 2.0 * cropFromLeft;
    double height = 1.0 - 2.0 * cropFromTop;
    CGRect cropRect = CGRectMake(cropFromLeft, cropFromTop, width, height);
    GPUImageCropFilter *cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
    [colorFilter addTarget:cropFilter];

    // Crop out a circle
    UIImage *maskImage = [UIImage imageNamed:@"circular_mask_1080x1080"];
    GPUImagePicture *maskImageSource = [[GPUImagePicture alloc] initWithImage:maskImage smoothlyScaleOutput:YES];
    [maskImageSource processImage];
    GPUImageAlphaBlendFilter *alphaMaskFilter = [[GPUImageAlphaBlendFilter alloc] init];
    alphaMaskFilter.mix = 1.0f;
    [cropFilter addTarget:alphaMaskFilter atTextureLocation:0];
    [maskImageSource addTarget:alphaMaskFilter atTextureLocation:1];

    // Calculate convoluation p = g(i-1,j)
    GPUImage3x3ConvolutionFilter *p = [[GPUImage3x3ConvolutionFilter alloc] init];
    [p setConvolutionKernel:(GPUMatrix3x3){
        { 0.0f, 0.0f, 0.0f},
        { 1.0f, 0.0f, 0.0f},
        { 0.0f, 0.0f, 0.0f}
    }];
    [alphaMaskFilter addTarget:p];

    // Calculate convoluation q = g(i+1,j)
    GPUImage3x3ConvolutionFilter *q = [[GPUImage3x3ConvolutionFilter alloc] init];
    [q setConvolutionKernel:(GPUMatrix3x3){
        { 0.0f, 0.0f, 0.0f},
        { 0.0f, 0.0f, 1.0f},
        { 0.0f, 0.0f, 0.0f}
    }];
    [alphaMaskFilter addTarget:q];

    // Calculate r = p*o (o = original)
    GPUImageMultiplyBlendFilter *r = [[GPUImageMultiplyBlendFilter alloc] init];
    [p addTarget:r];
    [alphaMaskFilter addTarget:r];

    // Calculate s = p*q
    GPUImageMultiplyBlendFilter *s = [[GPUImageMultiplyBlendFilter alloc] init];
    [p addTarget:s];
    [q addTarget:s];

    // Calculate v = r-s
    GPUImageDifferenceBlendFilter *v = [[GPUImageDifferenceBlendFilter alloc] init];
    [r addTarget:v];
    [s addTarget:v];

    // Increase exposure to brighten the bright pixels more than the dark pixels
    GPUImageExposureFilter *exposureFilter = [[GPUImageExposureFilter alloc] init];
    exposureFilter.exposure = 3.75;
    [v addTarget:exposureFilter];

    // Get the metric
    GPUImageAverageColor *averageColorFilter = [[GPUImageAverageColor alloc] init];
    __block double focusMetric;
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [averageColorFilter setColorAverageProcessingFinishedBlock:^(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CMTime frameTime) {
            focusMetric = green;
            resolve(nil);
        }];
    }];
    [exposureFilter useNextFrameForImageCapture];
    [exposureFilter addTarget:averageColorFilter];

    // Wait for metric
    [stillImageSource processImage];
    [PMKPromise hang:promise];

    NSLog(@"Image %@ has focus metric %3.6f", imagePath, focusMetric);
    return [[NSDecimalNumber alloc] initWithDouble:focusMetric];
}

- (NSDecimalNumber *)_boundaryScoreForImageNamed:(NSString *)imageName {
    ImageQuality imageQuality =[self _imageQualityForImageNamed:imageName];
    double boundaryScore = imageQuality.boundaryScore;
    NSLog(@"Image %@ has boundaryScore %3.3f", imageName, boundaryScore);
    return [[NSDecimalNumber alloc] initWithDouble:boundaryScore];
}

- (NSDecimalNumber *)_contentScoreForImageNamed:(NSString *)imageName {
    ImageQuality imageQuality =[self _imageQualityForImageNamed:imageName];
    double boundaryScore = imageQuality.contentScore;
    NSLog(@"Image %@ has contentScore %3.3f", imageName, boundaryScore);
    return [[NSDecimalNumber alloc] initWithDouble:boundaryScore];
}

- (ImageQuality)_imageQualityForImageNamed:(NSString *)imageName {
    // Load up UIImage
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
    UIImage *uiImage = [UIImage imageWithContentsOfFile:filePath];

    // Convert UIImage to an IplImage
    IplImage *iplImage = [[self class] createIplImageFromUIImage:uiImage];
    ImageQuality iq = [ImageQualityAnalyzer calculateFocusMetricFromIplImage:iplImage];

    // Release an nullify iplImage
    // cvReleaseImage(&iplImage);  // not sure why this crashes
    iplImage = NULL;

    return iq;
}

+ (IplImage *)createIplImageFromUIImage:(UIImage *)image {
    // Getting CGImage from UIImage
    CGImageRef imageRef = image.CGImage;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // Creating temporal IplImage for drawing
    IplImage *iplImage = cvCreateImage(
                                       cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4
                                       );
    // Creating CGContext for temporal IplImage
    CGContextRef contextRef = CGBitmapContextCreate(
                                                    iplImage->imageData, iplImage->width, iplImage->height,
                                                    iplImage->depth, iplImage->widthStep,
                                                    colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault
                                                    );
    // Drawing CGImage to CGContext
    CGContextDrawImage(
                       contextRef,
                       CGRectMake(0, 0, image.size.width, image.size.height),
                       imageRef
                       );
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    // Creating result IplImage
    IplImage *converted = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, converted, CV_RGBA2BGR);
    cvReleaseImage(&iplImage);

    // Crop IplImage
    int cropDim = CROP_WINDOW_SIZE;
    IplImage *cropped = 0;
    cvSetImageROI(converted, cvRect(converted->width/2-(cropDim/2), converted->height/2-(cropDim/2), cropDim, cropDim));
    cropped = cvCreateImage(cvGetSize(converted),
                            converted->depth,
                            converted->nChannels);
    cvCopy(converted, cropped, NULL);
    cvReleaseImage(&converted);
    
    return cropped;
}

@end
