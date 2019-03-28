/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FIRMessaging.h"
#import "FIRMessagingRemoteNotificationsProxy.h"

#pragma mark - Expose Internal Methods for Testing
// Expose some internal properties and methods here, in order to test
@interface FIRMessagingRemoteNotificationsProxy ()

@property(readonly, nonatomic) BOOL hasSwizzledUserNotificationDelegate;
@property(readonly, nonatomic) BOOL isObservingUserNotificationDelegateChanges;

@property(strong, readonly, nonatomic) id userNotificationCenter;
@property(strong, readonly, nonatomic) id currentUserNotificationCenterDelegate;

- (void)listenForDelegateChangesInUserNotificationCenter:(id)notificationCenter;
- (void)swizzleUserNotificationCenterDelegate:(id)delegate;
- (void)unswizzleUserNotificationCenterDelegate:(id)delegate;

void FCM_swizzle_appDidReceiveRemoteNotificationWithHandler(
    id self, SEL _cmd, UIApplication *app, NSDictionary *userInfo,
    void (^handler)(UIBackgroundFetchResult));
void FCM_swizzle_willPresentNotificationWithHandler(
    id self, SEL _cmd, id center, id notification, void (^handler)(NSUInteger));
void FCM_swizzle_didReceiveNotificationResponseWithHandler(
    id self, SEL _cmd, id center, id response, void (^handler)());

@end

#pragma mark - Invalid App Delegate

@interface InvalidAppDelegate : NSObject
@end
@implementation InvalidAppDelegate
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
}
@end

#pragma mark - Incomplete App Delegate
@interface IncompleteAppDelegate : NSObject <UIApplicationDelegate>
@end
@implementation IncompleteAppDelegate
@end

#pragma mark - Fake AppDelegate
@interface FakeAppDelegate : NSObject <UIApplicationDelegate>
@property(nonatomic) BOOL remoteNotificationMethodWasCalled;
@property(nonatomic) BOOL remoteNotificationWithFetchHandlerWasCalled;
@end
@implementation FakeAppDelegate
#if TARGET_OS_IOS
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  self.remoteNotificationMethodWasCalled = YES;
}
#endif
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.remoteNotificationWithFetchHandlerWasCalled = YES;
}
@end

#pragma mark - Incompete UNUserNotificationCenterDelegate
@interface IncompleteUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@end
@implementation IncompleteUserNotificationCenterDelegate
@end

#pragma mark - Fake UNUserNotificationCenterDelegate

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FakeUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@property(nonatomic) BOOL willPresentWasCalled;
@property(nonatomic) BOOL didReceiveResponseWasCalled;
@end
@implementation FakeUserNotificationCenterDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))
    completionHandler {
  self.willPresentWasCalled = YES;
}
#if TARGET_OS_IOS
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
  self.didReceiveResponseWasCalled = YES;
}
#endif // TARGET_OS_IOS
@end
#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

#pragma mark - Local, Per-Test Properties

@interface FIRMessagingRemoteNotificationsProxyTest : XCTestCase

@property(nonatomic, strong) FIRMessagingRemoteNotificationsProxy *proxy;
@property(nonatomic, strong) id mockProxy;
@property(nonatomic, strong) id mockProxyClass;
@property(nonatomic, strong) id mockMessagingClass;
@property(nonatomic, strong) id mockSharedApplication;
@property(nonatomic, strong) id mockMessaging;

@end

@implementation FIRMessagingRemoteNotificationsProxyTest

- (void)setUp {
  [super setUp];
  _mockSharedApplication = OCMPartialMock([UIApplication sharedApplication]);

  _mockMessaging = OCMClassMock([FIRMessaging class]);
  OCMStub([_mockMessaging messaging]).andReturn(_mockMessaging);

  _proxy = [[FIRMessagingRemoteNotificationsProxy alloc] init];
  _mockProxy = OCMPartialMock(_proxy);
  _mockProxyClass = OCMClassMock([FIRMessagingRemoteNotificationsProxy class]);
  // Update +sharedProxy to always return our test instance
  OCMStub([_mockProxyClass sharedProxy]).andReturn(self.proxy);
}

- (void)tearDown {
  [_mockMessagingClass stopMocking];
  _mockMessagingClass = nil;

  [_mockProxyClass stopMocking];
  _mockProxyClass = nil;

  [_mockProxy stopMocking];
  _mockProxy = nil;

  [_mockMessaging stopMocking];
  _mockMessaging = nil;

  [_mockSharedApplication stopMocking];
  _mockSharedApplication = nil;

  _proxy = nil;
  [super tearDown];
}

#pragma mark - Method Swizzling Tests

- (void)testSwizzlingNonAppDelegate {
  InvalidAppDelegate *invalidAppDelegate = [[InvalidAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:invalidAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

  [invalidAppDelegate application:self.mockSharedApplication
     didReceiveRemoteNotification:@{}
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {}];
}

- (void)testSwizzledIncompleteAppDelegateRemoteNotificationMethod {
  IncompleteAppDelegate *incompleteAppDelegate = [[IncompleteAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:incompleteAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *notification = @{@"test" : @""};
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  [incompleteAppDelegate application:self.mockSharedApplication
        didReceiveRemoteNotification:notification];
}

- (void)testIncompleteAppDelegateRemoteNotificationWithFetchHandlerMethod {
  IncompleteAppDelegate *incompleteAppDelegate = [[IncompleteAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:incompleteAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  SEL remoteNotificationWithFetchHandler =
  @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
  XCTAssertFalse([incompleteAppDelegate respondsToSelector:remoteNotificationWithFetchHandler]);
  SEL remoteNotification = @selector(application:didReceiveRemoteNotification:);
  XCTAssertTrue([incompleteAppDelegate respondsToSelector:remoteNotification]);
}

- (void)testSwizzledAppDelegateRemoteNotificationMethods {
#if TARGET_OS_IOS
  FakeAppDelegate *appDelegate = [[FakeAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:appDelegate];
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *notification = @{@"test" : @""};

  // application:didReceiveRemoteNotification:

  // Verify our swizzled method was called
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  // Call the method
  [appDelegate application:self.mockSharedApplication
        didReceiveRemoteNotification:notification];

  // Verify our original method was called
  XCTAssertTrue(appDelegate.remoteNotificationMethodWasCalled);
  [self.mockMessaging verify];

  // application:didReceiveRemoteNotification:fetchCompletionHandler:

  // Verify our swizzled method was called
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  [appDelegate application:OCMClassMock([UIApplication class])
      didReceiveRemoteNotification:notification
      fetchCompletionHandler:^(UIBackgroundFetchResult result) {}];

  // Verify our original method was called
  XCTAssertTrue(appDelegate.remoteNotificationWithFetchHandlerWasCalled);
  [self.mockMessaging verify];
#endif
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

- (void)testListeningForDelegateChangesOnInvalidUserNotificationCenter {
  id randomObject = @"Random Object that is not a User Notification Center";
  [self.proxy listenForDelegateChangesInUserNotificationCenter:randomObject];
  XCTAssertFalse(self.proxy.isObservingUserNotificationDelegateChanges);
}

- (void)testSwizzlingInvalidUserNotificationCenterDelegate {
  id randomObject = @"Random Object that is not a User Notification Center Delegate";
  [self.proxy swizzleUserNotificationCenterDelegate:randomObject];
  XCTAssertFalse(self.proxy.hasSwizzledUserNotificationDelegate);
}

- (void)testSwizzlingUserNotificationsCenterDelegate {
  FakeUserNotificationCenterDelegate *delegate = [[FakeUserNotificationCenterDelegate alloc] init];
  [self.proxy swizzleUserNotificationCenterDelegate:delegate];
  XCTAssertTrue(self.proxy.hasSwizzledUserNotificationDelegate);
}

// Use a fake delegate that doesn't actually implement the needed delegate method.
// Our swizzled method should not be called.

- (void)testIncompleteUserNotificationCenterDelegateMethod {
  // Early exit if running on pre iOS 10
  if (![UNNotification class]) {
    return;
  }
  IncompleteUserNotificationCenterDelegate *delegate =
      [[IncompleteUserNotificationCenterDelegate alloc] init];
  [self.mockProxy swizzleUserNotificationCenterDelegate:delegate];
  // Because the incomplete delete does not implement either of the optional delegate methods, we
  // should swizzle nothing. If we had swizzled them, then respondsToSelector: would return YES
  // even though the delegate does not implement the methods.
  SEL willPresentSelector = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
  XCTAssertFalse([delegate respondsToSelector:willPresentSelector]);
  SEL didReceiveResponseSelector =
      @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);
  XCTAssertFalse([delegate respondsToSelector:didReceiveResponseSelector]);
}

// Use an object that does actually implement the optional methods. Both should be called.
- (void)testSwizzledUserNotificationsCenterDelegate {
  // Early exit if running on pre iOS 10
  if (![UNNotification class]) {
    return;
  }
  FakeUserNotificationCenterDelegate *delegate = [[FakeUserNotificationCenterDelegate alloc] init];
  [self.mockProxy swizzleUserNotificationCenterDelegate:delegate];
  // Invoking delegate method should also invoke our swizzled method
  // The swizzled method uses the +sharedProxy, which should be
  // returning our mocked proxy.
  // Use non-nil, proper classes, otherwise our SDK bails out.
  [delegate userNotificationCenter:OCMClassMock([UNUserNotificationCenter class])
           willPresentNotification:[self generateMockNotification]
             withCompletionHandler:^(NSUInteger options) {}];
  // Verify our swizzled method was called
  OCMVerify(FCM_swizzle_willPresentNotificationWithHandler);
  // Verify our original method was called
  XCTAssertTrue(delegate.willPresentWasCalled);
#if TARGET_OS_IOS
  [delegate userNotificationCenter:OCMClassMock([UNUserNotificationCenter class])
    didReceiveNotificationResponse:[self generateMockNotificationResponse]
             withCompletionHandler:^{}];
  // Verify our swizzled method was called
  OCMVerify(FCM_swizzle_appDidReceiveRemoteNotificationWithHandler);
  // Verify our original method was called
  XCTAssertTrue(delegate.didReceiveResponseWasCalled);
#endif
}

- (id)generateMockNotification {
  // Stub out: notification.request.content.userInfo
  id mockNotification = OCMClassMock([UNNotification class]);
  id mockRequest = OCMClassMock([UNNotificationRequest class]);
  id mockContent = OCMClassMock([UNNotificationContent class]);
  OCMStub([mockContent userInfo]).andReturn(@{});
  OCMStub([mockRequest content]).andReturn(mockContent);
  OCMStub([mockNotification request]).andReturn(mockRequest);
  return mockNotification;
}

- (id)generateMockNotificationResponse {
  // Stub out: response.[mock notification above]
#if TARGET_OS_IOS
  id mockNotificationResponse = OCMClassMock([UNNotificationResponse class]);
  id mockNotification = [self generateMockNotification];
  OCMStub([mockNotificationResponse notification]).andReturn(mockNotification);
  return mockNotificationResponse;
#else
  return nil;
#endif
}

#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

@end
