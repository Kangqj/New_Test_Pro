//
//  WebViewViewController.m
//  WebPro
//
//  Created by 康起军 on 2018/8/3.
//  Copyright © 2018年 Kangqijun. All rights reserved.
//
//https://blog.csdn.net/q644419002/article/details/77980130

#import "WebViewViewController.h"
#import <WebKit/WebKit.h>
#import "UIImageView+WebCache.h"

@interface WebViewViewController () <WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate>
{
    WKWebView *_webView;
    
    NSMutableArray *allUrlArray;
    UIScrollView   *bgView;
    float CurrentScreenWidth;
    float CurrentScreenHeight;
}

@end

@implementation WebViewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    CurrentScreenWidth = self.view.bounds.size.width;
    CurrentScreenHeight = self.view.bounds.size.height - 64;
    
    WKWebViewConfiguration *confifg = [[WKWebViewConfiguration alloc] init];
    confifg.selectionGranularity = WKSelectionGranularityCharacter;
    _webView = [[WKWebView alloc] initWithFrame:CGRectMake(14, 64, CurrentScreenWidth - 28, CurrentScreenHeight - 64) configuration:confifg];
    _webView.opaque = NO;
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
    _webView.scrollView.bounces=NO;
    _webView.backgroundColor=[UIColor whiteColor];
    _webView.scrollView.decelerationRate=UIScrollViewDecelerationRateNormal;
    NSMutableURLRequest *request =[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://image.baidu.com/search/index?tn=baiduimage&ps=1&ct=201326592&lm=-1&cl=2&nc=1&ie=utf-8&word=%E5%87%A4%E5%87%B0%E7%BD%91"]];//百度随便找个地址 主要验证demo使用
    [_webView loadRequest:request];
    _webView.scrollView.delegate = self;
    [self.view addSubview:_webView];
}


- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{ //加载页面完成
    
    //js方法遍历图片添加点击事件 返回图片个数
    /*这块我着重说几句
     逻辑:
     1.遍历获取全部的图片;
     2.生成一个Srting为所有图片的拼接,拼接时拿到所处数组下标;
     3.为图片添加点击事件,并添加数组所处下标
     注意点:
     1.如果仅仅拿到url而无下标的话,网页中如果有多张相同地址的图片 则会发生位置错乱
     2.声明时不要用 var yong let  不然方法添加的i 永远是length的值
     */
    static  NSString * const jsGetImages =
    @"function getImages(){\
    var objs = document.getElementsByTagName(\"img\");\
    var imgScr = '';\
    for(let i=0;i<objs.length;i++){\
    imgScr = imgScr + objs[i].src +'LQXindex'+ i +'L+Q+X';\
    objs[i].onclick=function(){\
    document.location=\"myweb:imageClick:\"+this.src + 'LQXindex' + i;\
    };\
    };\
    return imgScr;\
    };";
    [webView evaluateJavaScript:jsGetImages completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
    }];
    //注入自定义的js方法后别忘了调用 否则不会生效（不调用也一样生效了，，，不明白）
    
    [webView evaluateJavaScript:@"getImages()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSString *urlResurlt = result;
        allUrlArray = [NSMutableArray arrayWithArray:[urlResurlt componentsSeparatedByString:@"L+Q+X"]];
        if (allUrlArray.count >= 2) {
            [allUrlArray removeLastObject];// 此时数组为每一个图片的url
        }
    }];
    
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *requestString = [[navigationAction.request URL] absoluteString];
    //hasPrefix 判断创建的字符串内容是否以pic:字符开始
    if ([requestString hasPrefix:@"myweb:imageClick:"]) {
        NSString *imageUrl = [requestString substringFromIndex:@"myweb:imageClick:".length];
        if (bgView) {
            //设置不隐藏，还原放大缩小，显示图片
            bgView.hidden = NO;
            NSArray *imageIndex = [NSMutableArray arrayWithArray:[imageUrl componentsSeparatedByString:@"LQXindex"]];
            int i = [imageIndex.lastObject intValue];
            [bgView setContentOffset:CGPointMake(CurrentScreenWidth *i, 0)];
        }else{
            [self showBigImage:imageUrl];//创建视图并显示图片
        }
        
    }
    
    
    decisionHandler(WKNavigationActionPolicyAllow);
    
}
#pragma mark 显示大图片
-(void)showBigImage:(NSString *)imageUrl{
    //创建灰色透明背景，使其背后内容不可操作
    bgView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CurrentScreenWidth, CurrentScreenHeight)];
    [bgView setBackgroundColor:[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.7]];
    bgView.contentSize = CGSizeMake(CurrentScreenWidth *allUrlArray.count, CurrentScreenHeight);
    bgView.pagingEnabled = YES;
    [self.view addSubview:bgView];
    
    //创建关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.backgroundColor = [UIColor redColor];
    [closeBtn addTarget:self action:@selector(removeBigImage) forControlEvents:UIControlEventTouchUpInside];
    [closeBtn setFrame:CGRectMake(CurrentScreenWidth/2.0 - 13, 200, 26, 26)];
    [self.view addSubview:closeBtn];
    
    //创建显示图像视图
    for (int i = 0; i < allUrlArray.count; i++) {
        UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(CurrentScreenWidth *i, (CurrentScreenHeight - 240)/2.0, CurrentScreenWidth-20, 240)];
        [bgView addSubview:borderView];
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, CGRectGetWidth(borderView.frame)-20, CGRectGetHeight(borderView.frame)-20)];
        imgView.userInteractionEnabled = YES;
        
        NSArray *imageIndex = [NSMutableArray arrayWithArray:[allUrlArray[i] componentsSeparatedByString:@"LQXindex"]];
        
        [imgView sd_setImageWithURL:[NSURL URLWithString:imageIndex.firstObject] placeholderImage:nil];
        
        [borderView addSubview:imgView];
        
    }
    NSArray *imageIndex = [NSMutableArray arrayWithArray:[imageUrl componentsSeparatedByString:@"LQXindex"]];
    
    
    int i = [imageIndex.lastObject intValue];
    [bgView setContentOffset:CGPointMake(CurrentScreenWidth *i, 0)];
    
}


//关闭按钮
-(void)removeBigImage
{
    bgView.hidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
