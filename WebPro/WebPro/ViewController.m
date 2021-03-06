//
//  ViewController.m
//  WebPro
//
//  Created by kangqijun on 2018/7/30.
//  Copyright © 2018年 Kangqijun. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
#import "UIImage+InsetEdge.h"
#import "FSActionSheet.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import "WebViewViewController.h"

static char imgUrlArrayKey;

@interface WKWebView (imageArr)

@end

@implementation WKWebView (imageArr)

- (void)setMethod:(NSArray *)imgUrlArray
{
    objc_setAssociatedObject(self, &imgUrlArrayKey, imgUrlArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)getImgUrlArray
{
    return objc_getAssociatedObject(self, &imgUrlArrayKey);
}
@end

@interface ViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate, PHPhotoLibraryChangeObserver>
{
    UIImage *_saveImage;
    NSString *_qrCodeString;
    
}

@property (nonatomic,strong)WKWebView *webView;
@property (nonatomic,strong) UIProgressView *progress;
@property (nonatomic, strong) PHFetchResult *assetsFetchResults;
@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, 40)];
    textField.returnKeyType = UIReturnKeyGo;
    textField.borderStyle = UITextBorderStyleNone;
    textField.placeholder = @"Search or enter website name";
    textField.delegate = self;
    [self.view addSubview:textField];
    textField.text = @"http://www.baidu.com";
    [textField becomeFirstResponder];
    
    /*
     _docSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f,0.0f, kScreenWidth, 44.0f)];
     _docSearchBar.autocorrectionType = UITextAutocorrectionTypeNo;
     _docSearchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
     _docSearchBar.keyboardType = UIKeyboardTypeDefault;
     _docSearchBar.delegate = self;
     
     UIView *searchBK = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 44)];
     [searchBK setBackgroundColor:[UIColor colorWithRed:236.f/255.f green:236.f/255.f blue:236.f/255.f alpha:1]];
     [_docSearchBar insertSubview:searchBK atIndex:1];
     [searchBK release];

     */
    
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 60, self.view.bounds.size.width, self.view.bounds.size.height - 60)];
    [self.view  addSubview:self.webView];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    
    UIView *lineView = [[UIView alloc]initWithFrame:CGRectMake(0, 60, CGRectGetWidth(self.view.frame), 1)];
    lineView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:lineView];
    
    UILongPressGestureRecognizer * longPressed = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
    longPressed.delegate = self;
    longPressed.minimumPressDuration = 0.1;
    longPressed.allowableMovement = self.view.bounds.size.width;
    [self.webView addGestureRecognizer:longPressed];
    
    [self startManager];
}


- (void)startManager { //注册相册的监听
    dispatch_async(dispatch_queue_create(0, 0), ^{
        self.dataSource = [[NSMutableArray alloc] init];
        self.assetsFetchResults = [[PHFetchResult alloc] init];
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
        self.assetsFetchResults = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:[self getFetchPhotosOptions]];
    });
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    //注：监听到动作之后要在主线程做处理
    dispatch_async(dispatch_get_main_queue(), ^{
        // 监听相册视频发生变化
        PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:self.assetsFetchResults];
        if (collectionChanges) {
            if ([collectionChanges hasIncrementalChanges]) {
                //监听相册视频的增删
                //增加了
                if (collectionChanges.insertedObjects.count > 0) {
                    NSMutableArray *mArr = [[NSMutableArray alloc] initWithArray:collectionChanges.insertedObjects];
                    if (mArr.count > 0)
                    {
                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                            [PHAssetChangeRequest deleteAssets:mArr];
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            NSLog(@"删除完毕:%d", success);
                        }];
                    }
                    
                    NSLog(@"add a picture:%d", mArr.count);
                }
                //删除了
                if (collectionChanges.removedObjects.count > 0) {
                    NSMutableArray *mArr = [[NSMutableArray alloc] initWithArray:collectionChanges.removedObjects];
                    
                    NSLog(@"delete a picture");
                }
                
                /*监听完一次更新一下监听对象*/
                self.assetsFetchResults = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:[self getFetchPhotosOptions]];
            }
        }
    });
}

//筛选的规则和范围
- (PHFetchOptions *)getFetchPhotosOptions{
    PHFetchOptions *allPhotosOptions = [[PHFetchOptions alloc]init];
    //排序的方式为：按时间排序
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    return allPhotosOptions;
}

- (void)stopManager { //注销相册的监听
    dispatch_async(dispatch_queue_create(0, 0), ^{
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    });
}

- (UIProgressView *)progress
{
    if (_progress == nil)
    {
        _progress = [[UIProgressView alloc]initWithFrame:CGRectMake(0, 60, self.view.bounds.size.width, 2)];
        _progress.tintColor = [UIColor blueColor];
        _progress.backgroundColor = [UIColor lightGrayColor];
        [self.view addSubview:_progress];
    }
    return _progress;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"estimatedProgress"])
    {
        if (object == self.webView)
        {
            NSLog(@"%f", self.webView.estimatedProgress);
            
            [self.progress setAlpha:1.0f];
            [self.progress setProgress:self.webView.estimatedProgress animated:YES];
            if(self.webView.estimatedProgress >= 1.0f)
            {
                [UIView animateWithDuration:0.5f
                                      delay:0.3f
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                                     [self.progress setAlpha:0.0f];
                                 }
                                 completion:^(BOOL finished) {
                                     [self.progress setProgress:0.0f animated:NO];
                                 }];
            }
        }
        else
        {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    }
}

- (void)longPressed:(UILongPressGestureRecognizer *)sender{
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint touchPoint = [sender locationInView:self.webView];
    // 获取长按位置对应的图片url的JS代码
    NSString *imgJS = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", touchPoint.x, touchPoint.y];
    // 执行对应的JS代码 获取url
    [self.webView evaluateJavaScript:imgJS completionHandler:^(id _Nullable imgUrl, NSError * _Nullable error) {
        
        NSLog(@"%@", imgUrl);
        
        if (imgUrl) {
            
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imgUrl]];
            UIImage *image = [UIImage imageWithData:data];
            if (!image) {
                NSLog(@"读取图片失败");
                return;
            }
            _saveImage = image;
            FSActionSheet *actionSheet = nil;
            if ([self isAvailableQRcodeIn:image]) {
                actionSheet = [[FSActionSheet alloc] initWithTitle:nil
                                                          delegate:self
                                                 cancelButtonTitle:@"取消"
                                            highlightedButtonTitle:nil
                                                 otherButtonTitles:@[@"保存图片", @"打开二维码"]];
            } else {
                actionSheet = [[FSActionSheet alloc] initWithTitle:nil
                                                          delegate:self
                                                 cancelButtonTitle:@"取消"
                                            highlightedButtonTitle:nil
                                                 otherButtonTitles:@[@"保存图片"]];
            }
            [actionSheet show];
        }
    }];
}

//可以识别多个手势
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.text && textField.text.length > 0)
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:textField.text]];
        [self.webView loadRequest:request];
        
        [textField resignFirstResponder];
    }
    
    WebViewViewController *vc = [[WebViewViewController alloc] init];
    [self presentViewController:vc animated:YES completion:NULL];
    
    return YES;
}

- (BOOL)isAvailableQRcodeIn:(UIImage *)img{
    UIImage *image = [img imageByInsetEdge:UIEdgeInsetsMake(-20, -20, -20, -20) withColor:[UIColor lightGrayColor]];
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{}];
    NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
    if (features.count >= 1) {
        CIQRCodeFeature *feature = [features objectAtIndex:0];
        _qrCodeString = [feature.messageString copy];
        NSLog(@"二维码信息:%@", _qrCodeString);
        return YES;
    } else {
        NSLog(@"无可识别的二维码");
        return NO;
    }
}


#pragma mark - FSActionSheetDelegate
- (void)FSActionSheet:(FSActionSheet *)actionSheet selectedIndex:(NSInteger)selectedIndex{
    switch (selectedIndex) {
        case 0:
        {
            UIImageWriteToSavedPhotosAlbum(_saveImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }
            break;
        case 1:
        {
            NSURL *qrUrl = [NSURL URLWithString:_qrCodeString];
            // Safari打开
            if ([[UIApplication sharedApplication] canOpenURL:qrUrl]) {
                [[UIApplication sharedApplication] openURL:qrUrl];
            }
            // 内部应用打开
            [self.webView loadRequest:[NSURLRequest requestWithURL:qrUrl]];
        }
            break;
            
        default:
            break;
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    NSString *message = @"Succeed";
    if (error) {
        message = @"Fail";
    }
    NSLog(@"save result :%@", message);
}

- (void)dealloc
{
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
