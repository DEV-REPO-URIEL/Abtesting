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

NS_ASSUME_NONNULL_BEGIN

@interface FIRInAppMessagingCardDisplay (Private)

@property(nonatomic, nullable, copy, readwrite) NSString *body;
@property(nonatomic, nullable, copy, readwrite) FIRInAppMessagingImageData *landscapeImageData;
@property(nonatomic, nullable, readwrite) FIRInAppMessagingActionButton *secondaryActionButton;
@property(nonatomic, nullable, readwrite) NSURL *secondaryActionURL;

- (instancetype)initWithMessageID:(NSString *)messageID
                     campaignName:(NSString *)campaignName
              renderAsTestMessage:(BOOL)renderAsTestMessage
                      triggerType:(FIRInAppMessagingDisplayTriggerType)triggerType
                        titleText:(NSString *)title
                        textColor:(UIColor *)textColor
                portraitImageData:(FIRInAppMessagingImageData *)portraitImageData
                  backgroundColor:(UIColor *)backgroundColor
              primaryActionButton:(FIRInAppMessagingActionButton *)primaryActionButton
                 primaryActionURL:(NSURL *)primaryActionURL;

@end

NS_ASSUME_NONNULL_END
