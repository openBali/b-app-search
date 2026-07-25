//
//  AlipaySDKBridge.m
//  b-app-search
//

#import "AlipaySDKBridge.h"
#import <UIKit/UIKit.h>

#if __has_include(<AlipaySDK/AlipaySDK.h>)
#import <AlipaySDK/AlipaySDK.h>
#define BAPP_ALIPAY_SDK_AVAILABLE 1
#else
#define BAPP_ALIPAY_SDK_AVAILABLE 0
#endif

@implementation AlipaySDKBridge

+ (BOOL)isSDKAvailable {
#if BAPP_ALIPAY_SDK_AVAILABLE
  return YES;
#else
  return NO;
#endif
}

+ (BOOL)isAlipayAppInstalled {
  NSURL *alipayURL = [NSURL URLWithString:@"alipay://"];
  NSURL *alipaysURL = [NSURL URLWithString:@"alipays://"];
  UIApplication *app = UIApplication.sharedApplication;
  return [app canOpenURL:alipayURL] || [app canOpenURL:alipaysURL];
}

+ (void)authWithInfo:(NSString *)authInfo
              scheme:(NSString *)scheme
          completion:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion
{
#if BAPP_ALIPAY_SDK_AVAILABLE
  [[AlipaySDK defaultService] auth_V2WithInfo:authInfo
                                   fromScheme:scheme
                                     callback:^(NSDictionary *resultDic) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion) {
        completion(resultDic, nil);
      }
    });
  }];
#else
  if (completion) {
    NSError *error = [NSError errorWithDomain:@"AlipaySDKBridge"
                                         code:-1000
                                     userInfo:@{
                                       NSLocalizedDescriptionKey:
                                         @"未集成 AlipaySDK，请运行 Scripts/download-alipay-sdk.sh 后重新编译。"
                                     }];
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(nil, error);
    });
  }
#endif
}

+ (BOOL)handleOpenURL:(NSURL *)url
           completion:(void (^_Nullable)(NSDictionary *_Nullable, NSError *_Nullable))completion
{
#if BAPP_ALIPAY_SDK_AVAILABLE
  if ([url.host isEqualToString:@"safepay"] ||
      [url.absoluteString containsString:@"auth_v2"] ||
      [url.absoluteString containsString:@"authcode"] ||
      [url.scheme length] > 0)
  {
    [[AlipaySDK defaultService] processAuth_V2Result:url
                                     standbyCallback:^(NSDictionary *resultDic) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
          completion(resultDic, nil);
        }
      });
    }];
    return YES;
  }
  return NO;
#else
  (void)url;
  (void)completion;
  return NO;
#endif
}

@end
