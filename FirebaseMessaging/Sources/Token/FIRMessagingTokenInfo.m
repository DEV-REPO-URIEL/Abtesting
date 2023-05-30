/*
 * Copyright 2019 Google
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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

/**
 *  @enum Token Info Dictionary Key Constants
 *  @discussion The keys that are checked when a token info is
 *              created from a dictionary. The same keys are used
 *              when decoding/encoding an archive.
 */
/// Specifies a dictonary key whose value represents the authorized entity, or
/// Sender ID for the token.
static NSString *const kFIRInstanceIDAuthorizedEntityKey = @"authorized_entity";
/// Specifies a dictionary key whose value represents the scope of the token,
/// typically "*".
static NSString *const kFIRInstanceIDScopeKey = @"scope";
/// Specifies a dictionary key which represents the token value itself.
static NSString *const kFIRInstanceIDTokenKey = @"token";
/// Specifies a dictionary key which represents the app version associated
/// with the token.
static NSString *const kFIRInstanceIDAppVersionKey = @"app_version";
/// Specifies a dictionary key which represents the GMP App ID associated with
/// the token.
static NSString *const kFIRInstanceIDFirebaseAppIDKey = @"firebase_app_id";
/// Specifies a dictionary key representing an archive for a
/// `FIRInstanceIDAPNSInfo` object.
static NSString *const kFIRInstanceIDAPNSInfoKey = @"apns_info";
/// Specifies a dictionary key representing the "last cached" time for the token.
static NSString *const kFIRInstanceIDCacheTimeKey = @"cache_time";
/// Default interval that token stays fresh.
static const NSTimeInterval kDefaultFetchTokenInterval = 7 * 24 * 60 * 60;  // 7 days.

@implementation FIRMessagingTokenInfo

- (instancetype)initWithAuthorizedEntity:(NSString *)authorizedEntity
                                   scope:(NSString *)scope
                                   token:(NSString *)token
                              appVersion:(NSString *)appVersion
                           firebaseAppID:(NSString *)firebaseAppID {
  self = [super init];
  if (self) {
    _authorizedEntity = [authorizedEntity copy];
    _scope = [scope copy];
    _token = [token copy];
    _appVersion = [appVersion copy];
    _firebaseAppID = [firebaseAppID copy];
  }
  return self;
}

- (BOOL)isFreshWithIID:(NSString *)IID {
  // Last fetch token cache time could be null if token is from legacy storage format. Then token is
  // considered not fresh and should be refreshed and overwrite with the latest storage format.
  if (!IID) {
    return NO;
  }
  if (!_cacheTime) {
    return NO;
  }

  // Check if it's consistent with IID
  if (![self.token hasPrefix:IID]) {
    return NO;
  }

  if ([self hasBlacklistedScope]) {
    return NO;
  }

  // Check if app has just been updated to a new version.
  NSString *currentAppVersion = FIRMessagingCurrentAppVersion();
  if (!_appVersion || ![_appVersion isEqualToString:currentAppVersion]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenManager004,
                            @"Invalidating cached token for %@ (%@) due to app version change.",
                            _authorizedEntity, _scope);
    return NO;
  }

  // Check if GMP App ID has changed
  NSString *currentFirebaseAppID = FIRMessagingFirebaseAppID();
  if (!_firebaseAppID || ![_firebaseAppID isEqualToString:currentFirebaseAppID]) {
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeTokenInfoFirebaseAppIDChanged,
        @"Invalidating cached token due to Firebase App IID change from %@ to %@", _firebaseAppID,
        currentFirebaseAppID);
    return NO;
  }

  // Check whether locale has changed, if yes, token needs to be updated with server for locale
  // information.
  if (FIRMessagingHasLocaleChanged()) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenInfoLocaleChanged,
                            @"Invalidating cached token due to locale change");
    return NO;
  }

  // Locale is not changed, check whether token has been fetched within 7 days.
  NSTimeInterval lastFetchTokenTimestamp = [_cacheTime timeIntervalSince1970];
  NSTimeInterval currentTimestamp = FIRMessagingCurrentTimestampInSeconds();
  NSTimeInterval timeSinceLastFetchToken = currentTimestamp - lastFetchTokenTimestamp;
  return (timeSinceLastFetchToken < kDefaultFetchTokenInterval);
}

- (BOOL)hasBlacklistedScope {
  if ([self.scope isEqualToString:kFIRMessagingFIAMTokenScope]) {
    return YES;
  }

  return NO;
}

- (BOOL)isDefaultToken {
  return [self.scope isEqualToString:kFIRMessagingDefaultTokenScope];
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  // These value cannot be nil

  id authorizedEntity = [aDecoder decodeObjectForKey:kFIRInstanceIDAuthorizedEntityKey];
  if (![authorizedEntity isKindOfClass:[NSString class]]) {
    return nil;
  }

  id scope = [aDecoder decodeObjectForKey:kFIRInstanceIDScopeKey];
  if (![scope isKindOfClass:[NSString class]]) {
    return nil;
  }

  id token = [aDecoder decodeObjectForKey:kFIRInstanceIDTokenKey];
  if (![token isKindOfClass:[NSString class]]) {
    return nil;
  }

  // These values are nullable, so only fail the decode if the type does not match

  id appVersion = [aDecoder decodeObjectForKey:kFIRInstanceIDAppVersionKey];
  if (appVersion && ![appVersion isKindOfClass:[NSString class]]) {
    return nil;
  }

  id firebaseAppID = [aDecoder decodeObjectForKey:kFIRInstanceIDFirebaseAppIDKey];
  if (firebaseAppID && ![firebaseAppID isKindOfClass:[NSString class]]) {
    return nil;
  }

  id rawAPNSInfo = [aDecoder decodeObjectForKey:kFIRInstanceIDAPNSInfoKey];
  if (rawAPNSInfo && ![rawAPNSInfo isKindOfClass:[NSData class]]) {
    return nil;
  }

  FIRMessagingAPNSInfo *APNSInfo = nil;
  if (rawAPNSInfo) {
    // TODO(chliangGoogle: Use the new API and secureCoding protocol.
    @try {
      [NSKeyedUnarchiver setClass:[FIRMessagingAPNSInfo class]
                     forClassName:@"FIRInstanceIDAPNSInfo"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      APNSInfo = [NSKeyedUnarchiver unarchiveObjectWithData:rawAPNSInfo];
#pragma clang diagnostic pop
    } @catch (NSException *exception) {
      FIRMessagingLoggerInfo(kFIRMessagingMessageCodeTokenInfoBadAPNSInfo,
                             @"Could not parse raw APNS Info while parsing archived token info.");
      APNSInfo = nil;
    } @finally {
    }
  }

  id cacheTime = [aDecoder decodeObjectForKey:kFIRInstanceIDCacheTimeKey];
  if (cacheTime && ![cacheTime isKindOfClass:[NSDate class]]) {
    return nil;
  }

  self = [super init];
  if (self) {
    _authorizedEntity = [authorizedEntity copy];
    _scope = [scope copy];
    _token = [token copy];
    _appVersion = [appVersion copy];
    _firebaseAppID = [firebaseAppID copy];
    _APNSInfo = [APNSInfo copy];
    _cacheTime = cacheTime;
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:kFIRInstanceIDAuthorizedEntityKey];
  [aCoder encodeObject:self.scope forKey:kFIRInstanceIDScopeKey];
  [aCoder encodeObject:self.token forKey:kFIRInstanceIDTokenKey];
  [aCoder encodeObject:self.appVersion forKey:kFIRInstanceIDAppVersionKey];
  [aCoder encodeObject:self.firebaseAppID forKey:kFIRInstanceIDFirebaseAppIDKey];
  NSData *rawAPNSInfo;
  if (self.APNSInfo) {
    // TODO(chliangGoogle: Use the new API and secureCoding protocol.
    [NSKeyedArchiver setClassName:@"FIRInstanceIDAPNSInfo" forClass:[FIRMessagingAPNSInfo class]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    rawAPNSInfo = [NSKeyedArchiver archivedDataWithRootObject:self.APNSInfo];
#pragma clang diagnostic pop

    [aCoder encodeObject:rawAPNSInfo forKey:kFIRInstanceIDAPNSInfoKey];
  }
  [aCoder encodeObject:self.cacheTime forKey:kFIRInstanceIDCacheTimeKey];
}

@end
