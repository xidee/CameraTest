//
//  ViewController.m
//  cameraTest
//
//  Created by XI_DEE on 16/5/11.
//  Copyright © 2016年 XI_DEE All rights reserved.
//

#import "ViewController.h"
#import "CameraSlider.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource,AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic ,strong) AVCaptureSession *session;
@property (nonatomic ,strong) AVCaptureDeviceInput *input;
@property (nonatomic ,strong) AVCaptureStillImageOutput *output;
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *layer;
@property (nonatomic ,strong) AVCaptureDevice *device;

#pragma mark - UI
@property (nonatomic ,strong) UIView *pointView;
@property (weak, nonatomic) IBOutlet UITableView *selectorView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //输入输出流数据传递
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    //创建输入流
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (device.position == AVCaptureDevicePositionBack) {
            //初始化后置摄像头
            self.device = device;
            self.input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
            break;
        }
    }
    if (!self.input) {
        [UIAlertAction actionWithTitle:@"初始化摄像头失败" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];
    }
    //创建输出流
    self.output = [[AVCaptureStillImageOutput alloc] init];
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
//    if ([self.session canAddOutput:self.output]) {
//        [self.session addOutput:self.output];
//    }
    
    //创建扫描输出
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", NULL);
    [dataOutput setSampleBufferDelegate:self queue:queue];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    dataOutput.videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
    if ([self.session canAddOutput:dataOutput]) {
        [self.session addOutput:dataOutput];
    }
    
    //相机预览图层
    self.layer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    self.layer.frame = self.view.bounds;
    //照片方向？
    self.layer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer insertSublayer:self.layer atIndex:0];
    
    self.pointView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [self.view addSubview:self.pointView];
    self.pointView.layer.borderColor = [UIColor redColor].CGColor;
    self.pointView.layer.borderWidth = 1;
    self.pointView.alpha = 0.5f;
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.session stopRunning];
}

- (IBAction)takeAPicture:(UIButton *)sender {
   
    AVCaptureConnection * videoConnection = [self.output connectionWithMediaType:AVMediaTypeVideo];
    if (!videoConnection) {
        NSLog(@"take photo failed!");
        return;
    }
    
    [self.output captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == NULL) {
            return;
        }
        NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage * image = [UIImage imageWithData:imageData];
        NSLog(@"image size = %@",NSStringFromCGSize(image.size));
        //保存至相册
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        
    }];
}

- (IBAction)tapToFocusPoint:(UITapGestureRecognizer *)sender {
    //设置对焦点
    [self setFocusPoint:[sender locationInView:self.view]];
}

#pragma mark - setFocusPoint
- (void)setFocusPoint:(CGPoint )point
{
    /*
     typedef NS_ENUM(NSInteger, AVCaptureFocusMode) {
     AVCaptureFocusModeLocked              = 0,     //锁定焦点
     AVCaptureFocusModeAutoFocus           = 1,     //自动对焦一次然后锁定
     AVCaptureFocusModeContinuousAutoFocus = 2,     //需要时自动对焦
     } NS_AVAILABLE(10_7, 4_0) __TVOS_PROHIBITED;
     */
    CGPoint pointOfInterest = CGPointMake( point.y /self.view.frame.size.height ,1-point.x/self.view.frame.size.width);;
    //先进行判断是否支持控制对焦
    if (self.device.isFocusPointOfInterestSupported &&[self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        
        NSError *error = nil;
        //对cameraDevice进行操作前，需要先锁定，防止其他线程访问，
        [self.device lockForConfiguration:&error];
        
        if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [self.device setFocusPointOfInterest:pointOfInterest];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        //设置曝光点
        if([self.device isExposurePointOfInterestSupported] && [self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [self.device setExposurePointOfInterest:pointOfInterest];
            [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        
        self.pointView.center = point;
        //操作完成后unlock。
        [self.device unlockForConfiguration];
    }
}

#pragma mark - setWhiteBalance

//自动白平衡
- (IBAction)autoWhiteBalanceAction:(UIButton *)sender {
    /*
     typedef NS_ENUM(NSInteger, AVCaptureWhiteBalanceMode) {
     AVCaptureWhiteBalanceModeLocked				        = 0,    //锁定白平衡
     AVCaptureWhiteBalanceModeAutoWhiteBalance	        = 1,        //自动白平衡一次然后锁定
     AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance = 2,       //自动白平衡
     } NS_AVAILABLE(10_7, 4_0) __TVOS_PROHIBITED;
    */
    if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
        NSError *error = nil;
        //对cameraDevice进行操作前，需要先锁定，防止其他线程访问，
        [self.device lockForConfiguration:&error];
        [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        //操作完成后unlock。
        [self.device unlockForConfiguration];
    }
}

//显示白平衡手动模式
- (IBAction)showSelector:(UIButton *)sender {
    self.selectorView.hidden = !self.selectorView.hidden;
}

//白平衡手动模式 iOS8.0以上支持
- (IBAction)slideValueDidChange:(UISlider *)sender {
    
    AVCaptureWhiteBalanceGains whiteBalancegains = self.device.deviceWhiteBalanceGains;
    CameraSlider *slider = (CameraSlider *)sender;
    if (slider.indexPath.section == 0) {
        if (slider.indexPath.row == 0) {
            whiteBalancegains.redGain = sender.value;
        }else if (slider.indexPath.row == 1)
        {
            whiteBalancegains.greenGain = sender.value;
        }else if (slider.indexPath.row == 2)
        {
            whiteBalancegains.blueGain = sender.value;
        }
    }else if (slider.indexPath.section == 1){
        if (slider.indexPath.row == 0) {
            AVCaptureWhiteBalanceChromaticityValues chromaticityValues = [self.device chromaticityValuesForDeviceWhiteBalanceGains:whiteBalancegains];
            chromaticityValues.x = sender.value;
            whiteBalancegains = [self.device deviceWhiteBalanceGainsForChromaticityValues:chromaticityValues];
        }else if (slider.indexPath.row == 1)
        {   AVCaptureWhiteBalanceChromaticityValues chromaticityValues = [self.device chromaticityValuesForDeviceWhiteBalanceGains:whiteBalancegains];
            chromaticityValues.y = sender.value;
            whiteBalancegains = [self.device deviceWhiteBalanceGainsForChromaticityValues:chromaticityValues];
            
        }
    }else if (slider.indexPath.section == 2){
        if (slider.indexPath.row == 0) {
            AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTintValues = [self.device temperatureAndTintValuesForDeviceWhiteBalanceGains:whiteBalancegains];
            temperatureAndTintValues.temperature = sender.value;
            whiteBalancegains = [self.device deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTintValues];
        }else if (slider.indexPath.row == 1)
        {
            AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTintValues = [self.device temperatureAndTintValuesForDeviceWhiteBalanceGains:whiteBalancegains];
            temperatureAndTintValues.tint = sender.value;
            whiteBalancegains = [self.device deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTintValues];
        }
    }
    
    whiteBalancegains.redGain = (whiteBalancegains.redGain > self.device.maxWhiteBalanceGain) ? self.device.maxWhiteBalanceGain : whiteBalancegains.redGain;
    whiteBalancegains.redGain = (whiteBalancegains.redGain < 1) ? 1 : whiteBalancegains.redGain;
    whiteBalancegains.greenGain = (whiteBalancegains.greenGain > self.device.maxWhiteBalanceGain) ? self.device.maxWhiteBalanceGain : whiteBalancegains.greenGain;
    whiteBalancegains.greenGain = (whiteBalancegains.greenGain < 1) ? 1 : whiteBalancegains.greenGain;
    whiteBalancegains.blueGain = (whiteBalancegains.blueGain > self.device.maxWhiteBalanceGain) ? self.device.maxWhiteBalanceGain : whiteBalancegains.blueGain;
    whiteBalancegains.blueGain = (whiteBalancegains.blueGain < 1) ? 1 : whiteBalancegains.blueGain;
    
    
    [self setWhiteBalance:whiteBalancegains];
}
//通过RGB设置白平衡
- (void)setWhiteBalance:(AVCaptureWhiteBalanceGains )gains
{
    if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
        NSError *error = nil;
        //对cameraDevice进行操作前，需要先锁定，防止其他线程访问，
        [self.device lockForConfiguration:&error];
        [self.device setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:nil];
        [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
        //操作完成后unlock。
        [self.device unlockForConfiguration];
    }
}

#pragma mark - UITableViewDelegate,UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? 3 : 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"selectorCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    UILabel *label = [cell viewWithTag:355];
    CameraSlider *slide = [cell viewWithTag:366];
    slide.indexPath = indexPath;
    //这里偷懒，用maximumTrackTintColor来区分slide
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            label.text = @"R";
        }else if (indexPath.row == 1)
        {
            label.text = @"G";
        }else{
            label.text = @"B";
        }
        slide.maximumValue = self.device.maxWhiteBalanceGain;
        slide.minimumValue = 1;
    }else if (indexPath.section == 1){
        if (indexPath.row == 0) {
            label.text = @"ChromaticityValues X";
        }else{
            label.text = @"ChromaticityValues Y";
        }
        slide.maximumValue = 0.8;
        slide.minimumValue = 0.F;
    }else
    {
        if (indexPath.row == 0) {
            label.text = @"temperature";
        }else{
            label.text = @"tint";
        }
        slide.maximumValue = 150;
        slide.minimumValue = -150;
    }
    
    return cell;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //截取视频流的图像
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t* baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t width  = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bytesPerRow * height, NULL);
    
    CGImageRef imageRef = CGImageCreate(width, height, 8, 32, bytesPerRow, colorSpace,
                                        kCGBitmapByteOrder32Little|kCGImageAlphaPremultipliedFirst,
                                        provider, NULL, false, kCGRenderingIntentDefault);
    
    CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef, CGRectMake((640-360)/2, 0, 360, 480));
    
    
    UIImage *image = [UIImage imageWithCGImage:subImageRef];
    NSData* imageData =  UIImagePNGRepresentation(image);
    UIImage* newImage = [UIImage imageWithData:imageData];
    UIImageWriteToSavedPhotosAlbum(newImage, nil, nil, nil);
    
    size_t subWidth  = 360 ;
    size_t subHeight = 480  ;
    
    CGContextRef context = CGBitmapContextCreate(NULL, subWidth, subHeight,
                                                 CGImageGetBitsPerComponent(subImageRef), 0,
                                                 CGImageGetColorSpace(subImageRef),
                                                 CGImageGetBitmapInfo(subImageRef));
    
    
    CGContextTranslateCTM(context, 0, subHeight);
    CGContextRotateCTM(context, -M_PI/2);
    
    CGContextDrawImage(context, CGRectMake(0, 0, subHeight, subWidth), subImageRef);
    
    uint8_t* data = (uint8_t*)CGBitmapContextGetData(context);
    
    CGContextRelease(context);
    CGImageRelease(imageRef);
    CGImageRelease(subImageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

@end
