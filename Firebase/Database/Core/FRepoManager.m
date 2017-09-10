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

#import "FRepoManager.h"
#import "FAtomicNumber.h"
#import "FIRDatabaseConfig_Private.h"
#import "FIRDatabaseQuery_Private.h"
#import "FIRDatabase_Private.h"
#import "FIRLogger.h"
#import "FRepo.h"

@implementation FRepoManager

+ (NSMutableDictionary *)configs {
    static dispatch_once_t pred = 0;
    static NSMutableDictionary *configs;
    dispatch_once(&pred, ^{
      configs = [NSMutableDictionary dictionary];
    });
    return configs;
}

/**
 * Used for legacy unit tests.  The public API should go through
 * FirebaseDatabase which calls createRepo.
 */
+ (FRepo *)getRepo:(FRepoInfo *)repoInfo config:(FIRDatabaseConfig *)config {
    [config freeze];
    NSString *repoHashString =
        [NSString stringWithFormat:@"%@_%@", repoInfo.host, repoInfo.namespace];
    NSMutableDictionary *configs = [FRepoManager configs];
    @synchronized(configs) {
        NSMutableDictionary *repos = configs[config.sessionIdentifier];
        if (!repos || repos[repoHashString] == nil) {
            // Calling this should create the repo.
            [FIRDatabase createDatabaseForTests:repoInfo config:config];
        }

        return configs[config.sessionIdentifier][repoHashString];
    }
}

+ (FRepo *)createRepo:(FRepoInfo *)repoInfo
               config:(FIRDatabaseConfig *)config
             database:(FIRDatabase *)database {
    [config freeze];
    NSString *repoHashString =
        [NSString stringWithFormat:@"%@_%@", repoInfo.host, repoInfo.namespace];
    NSMutableDictionary *configs = [FRepoManager configs];
    @synchronized(configs) {
        NSMutableDictionary *repos = configs[config.sessionIdentifier];
        if (!repos) {
            repos = [NSMutableDictionary dictionary];
            configs[config.sessionIdentifier] = repos;
        }
        FRepo *repo = repos[repoHashString];
        if (repo == nil) {
            repo = [[FRepo alloc] initWithRepoInfo:repoInfo
                                            config:config
                                          database:database];
            repos[repoHashString] = repo;
            return repo;
        } else {
            [NSException
                 raise:@"RepoExists"
                format:@"createRepo called for Repo that already exists."];
            return nil;
        }
    }
}

+ (void)interrupt:(FIRDatabaseConfig *)config {
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      NSMutableDictionary *configs = [FRepoManager configs];
      NSMutableDictionary *repos = configs[config.sessionIdentifier];
      for (FRepo *repo in [repos allValues]) {
          [repo interrupt];
      }
    });
}

+ (void)interruptAll {
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      NSMutableDictionary *configs = [FRepoManager configs];
      for (NSMutableDictionary *repos in [configs allValues]) {
          for (FRepo *repo in [repos allValues]) {
              [repo interrupt];
          }
      }
    });
}

+ (void)resume:(FIRDatabaseConfig *)config {
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      NSMutableDictionary *configs = [FRepoManager configs];
      NSMutableDictionary *repos = configs[config.sessionIdentifier];
      for (FRepo *repo in [repos allValues]) {
          [repo resume];
      }
    });
}

+ (void)resumeAll {
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      NSMutableDictionary *configs = [FRepoManager configs];
      for (NSMutableDictionary *repos in [configs allValues]) {
          for (FRepo *repo in [repos allValues]) {
              [repo resume];
          }
      }
    });
}

+ (void)disposeRepos:(FIRDatabaseConfig *)config {
    // Do this synchronously to make sure we release our references to LevelDB
    // before returning, allowing LevelDB to close and release its exclusive
    // locks.
    dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
      FFLog(@"I-RDB040001", @"Disposing all repos for Config with name %@",
            config.sessionIdentifier);
      NSMutableDictionary *configs = [FRepoManager configs];
      for (FRepo *repo in [configs[config.sessionIdentifier] allValues]) {
          [repo dispose];
      }
      [configs removeObjectForKey:config.sessionIdentifier];
    });
}

@end
