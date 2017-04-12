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
#import <XCTest/XCTest.h>

#import "Phone/FIRPhoneAuthCredential_Internal.h"
#import "FIRAuthBackend.h"
#import "FIRAuthErrors.h"
#import "FIRVerifyPhoneNumberRequest.h"
#import "FIRVerifyPhoneNumberResponse.h"
#import "FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kVerificationCode
    @brief Fake verification code used for testing.
 */
static NSString *const kVerificationCode = @"12345678";

/** @var kVerificationID
    @brief Fake verification ID for testing.
 */
static NSString *const kVerificationID = @"55432";

/** @var kfakeRefreshToken
    @brief Fake refresh token for testing.
 */
static NSString *const kfakeRefreshToken = @"refreshtoken";

/** @var klocalID
    @brief Fake local ID for testing.
 */
static NSString *const klocalID = @"localID";

/** @var kfakeIDToken
    @brief Fake ID Token for testing.
 */
static NSString *const kfakeIDToken = @"idtoken";

/** @var kTestExpiresIn
    @brief Fake token expiration time.
 */
static NSString *const kTestExpiresIn = @"12345";

/** @var kInvalidVerificationCodeErrorMessage
    @brief This is the error message the server will respond with if an invalid verification code
        provided.
 */
static NSString *const kInvalidVerificationCodeErrorMessage = @"INVALID_VERIFICATION_CODE";

/** @var kInvalidVerificationIDErrorMessage
    @brief This is the error message the server will respond with if an invalid verification ID
        provided.
 */
static NSString *const kInvalidVerificationIDErrorMessage = @"INVALID_VERIFICATION_ID";

/** @var kFakePhoneNumber
    @brief The fake user phone number.
 */
static NSString *const kFakePhoneNumber = @"12345658";

/** @var kFakeTemporaryProof
    @brief The fake temporary proof.
 */
static NSString *const kFakeTemporaryProof = @"12345658";

/** @var kEpsilon
    @brief Allowed difference when comparing floating point numbers.
 */
static const double kEpsilon = 1e-3;

/** @class FIRVerifyPhoneNumberResponseTests
    @brief Tests for @c FIRVerifyPhoneNumberResponse.
 */
@interface FIRVerifyPhoneNumberResponseTests : XCTestCase

@end

@implementation FIRVerifyPhoneNumberResponseTests {
  /** @var _RPCIssuer
      @brief This backend RPC issuer is used to fake network responses for each test in the suite.
          In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;
}

- (void)setUp {
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
}

- (void)tearDown {
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testInvalidVerificationCodeError
    @brief Tests invalid verification code error.
 */
- (void)testInvalidVerificationCodeError {
  FIRVerifyPhoneNumberRequest *request =
      [[FIRVerifyPhoneNumberRequest alloc] initWithVerificationID:kVerificationID
                                                 verificationCode:kVerificationCode
                                                           APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRVerifyPhoneNumberResponse *RPCResponse;
  __block NSError *RPCError;


  [FIRAuthBackend verifyPhoneNumber:request
                           callback:^(FIRVerifyPhoneNumberResponse *_Nullable response,
                                      NSError *_Nullable error) {
    RPCResponse = response;
    RPCError = error;
    callbackInvoked = YES;
  }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidVerificationCodeErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidVerificationCode);
}

/** @fn testInvalidVerificationIDError
    @brief Tests invalid verification code error.
 */
- (void)testInvalidVerificationIDError {
  FIRVerifyPhoneNumberRequest *request =
      [[FIRVerifyPhoneNumberRequest alloc] initWithVerificationID:kVerificationID
                                                 verificationCode:kVerificationCode
                                                           APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRVerifyPhoneNumberResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend verifyPhoneNumber:request
                           callback:^(FIRVerifyPhoneNumberResponse *_Nullable response,
                                      NSError *_Nullable error) {
    RPCResponse = response;
    RPCError = error;
    callbackInvoked = YES;
  }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidVerificationIDErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidVerificationID);
}

/** @fn testSuccessfulVerifyPhoneNumberResponse
    @brief Tests a succesful to verify phone number flow.
 */
- (void)testSuccessfulVerifyPhoneNumberResponse {
  FIRVerifyPhoneNumberRequest *request =
      [[FIRVerifyPhoneNumberRequest alloc] initWithVerificationID:kVerificationID
                                                 verificationCode:kVerificationCode
                                                           APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRVerifyPhoneNumberResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend verifyPhoneNumber:request
                           callback:^(FIRVerifyPhoneNumberResponse *_Nullable response,
                                      NSError *_Nullable error) {
    RPCResponse = response;
    RPCError = error;
    callbackInvoked = YES;
  }];

  [_RPCIssuer respondWithJSON:@{
    @"idToken" : kfakeIDToken,
    @"refreshToken" : kfakeRefreshToken,
    @"localID" : klocalID,
    @"expiresIn" : kTestExpiresIn,
    @"isNewUser" : @YES // Set new user flag to true.
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kfakeIDToken);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kfakeRefreshToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertLessThanOrEqual(fabs(expiresIn - [kTestExpiresIn doubleValue]), kEpsilon);
  XCTAssertTrue(RPCResponse.isNewUser);
}

/** @fn testSuccessfulVerifyPhoneNumberResponseWithTemporaryProof
    @brief Tests a succesful to verify phone number flow with temporary proof response.
 */
- (void)testSuccessfulVerifyPhoneNumberResponseWithTemporaryProof {
  FIRVerifyPhoneNumberRequest *request =
      [[FIRVerifyPhoneNumberRequest alloc] initWithTemporaryProof:kFakeTemporaryProof
                                                      phoneNumber:kFakePhoneNumber
                                                           APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRVerifyPhoneNumberResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend verifyPhoneNumber:request
                           callback:^(FIRVerifyPhoneNumberResponse *_Nullable response,
                                      NSError *_Nullable error) {
    RPCResponse = response;
    RPCError = error;
    callbackInvoked = YES;
  }];

  [_RPCIssuer respondWithJSON:@{
    @"temporaryProof" : kFakeTemporaryProof,
    @"phoneNumber" : kFakePhoneNumber
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  FIRPhoneAuthCredential *credential = RPCError.userInfo[FIRAuthUpdatedCredentialKey];
  XCTAssertEqualObjects(credential.temporaryProof, kFakeTemporaryProof);
  XCTAssertEqualObjects(credential.phoneNumber, kFakePhoneNumber);
}

@end
