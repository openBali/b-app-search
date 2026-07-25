//
//  AlipaySDKBridge.h
//  b-app-search
//
//  对 AlipaySDK 的薄封装：有 SDK 时走官方 auth_v2；未集成时可编译，由 Swift 层决定是否 Mock。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlipaySDKBridge : NSObject

+ (BOOL)isSDKAvailable;
+ (BOOL)isAlipayAppInstalled;

/// 发起支付宝授权登录。completion 在主线程回调。
+ (void)authWithInfo:(NSString *)authInfo
              scheme:(NSString *)scheme
          completion:(void (^)(NSDictionary *_Nullable result, NSError *_Nullable error))completion;

/// 处理支付宝回跳 URL（App 被杀后从支付宝返回时依赖 standbyCallback）。
+ (BOOL)handleOpenURL:(NSURL *)url
           completion:(void (^_Nullable)(NSDictionary *_Nullable result, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
