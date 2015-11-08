//
//  OTPScannerViewController.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OTPScannerViewController.h"
@import AVFoundation;
@import OneTimePasswordLegacy;
#import "Authenticator-Swift.h"


@interface OTPScannerViewController () <ScannerDelegate, TokenEntryFormDelegate>

@property (nonatomic, strong) Scanner *scanner;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoLayer;

@end


@implementation OTPScannerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self createCaptureSession];
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    self.title = @"Scan Token";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(addTokenManually)];

    self.videoLayer = [AVCaptureVideoPreviewLayer layer];
    self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.videoLayer];
    self.videoLayer.frame = self.view.layer.bounds;

    OTPScannerOverlayView *overlayView = [[OTPScannerOverlayView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:overlayView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.scanner start];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    [self.scanner stop];
}


#pragma mark - Target Actions

- (void)cancel
{
    [self.delegate tokenSourceDidCancel:self];
}

- (void)addTokenManually
{
    TokenFormViewController *entryController = [TokenFormViewController entryControllerWithDelegate:self];
    [self.navigationController pushViewController:entryController animated:YES];
}


#pragma mark - Video Capture

- (void)createCaptureSession
{
    dispatch_queue_t async_queue = dispatch_queue_create("OTPScannerViewController createCaptureSession", NULL);
    dispatch_async(async_queue, ^{
        Scanner *scanner = [[Scanner alloc] init];
        scanner.delegate = self;
        [scanner start];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.scanner = scanner;
            self.videoLayer.session = scanner.captureSession;
        });
    });
}

- (void)showErrorWithStatus:(NSString *)statusString
{
    // Ensure this executes on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showErrorWithStatus:statusString];
    });
}


#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)handleDecodedText:(NSString *)decodedText
{
    // Attempt to create a token from the decoded text
    NSURL *url = [NSURL URLWithString:decodedText];
    OTPToken *token = [OTPToken tokenWithURL:url];

    if (token) {
        // Halt the video capture
        [self.scanner stop];

        // Inform the delegate that an auth URL was captured
        id <OTPTokenSourceDelegate> delegate = self.delegate;
        [delegate tokenSource:self didCreateToken:token];
    } else {
        // Show an error message
        [SVProgressHUD showErrorWithStatus:@"Invalid Token"];
    }
}

- (void)handleError:(NSError *)error {
    NSLog(@"Error: %@", error);
    [self showErrorWithStatus:@"Capture Failed"];
}


#pragma mark - TokenEntryFormDelegate

- (void)entryFormDidCancel:(nonnull TokenEntryForm *)form
{
    [self.delegate tokenSourceDidCancel:form];
}

- (void)form:(nonnull TokenEntryForm *)form didCreateToken:(nonnull OTPToken *)token
{
    // Forward didCreateToken on to the scanner's delegate
    [self.delegate tokenSource:form didCreateToken:token];
}

@end
