/*
 * Copyright 2018 Google
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

#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#import <XCTest/XCTest.h>
#import <absl/strings/str_cat.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTClasses.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::Precondition;
namespace testutil = firebase::firestore::testutil;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTLRUGarbageCollectorTests {
  FSTTargetID _previousTargetID;
  NSUInteger _previousDocNum;
  FSTObjectValue *_testValue;
  FSTObjectValue *_bigObjectValue;
}

- (id<FSTPersistence>)newPersistence {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (long)compactedSize:(id<FSTPersistence>)persistence {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (FSTLRUGarbageCollector *)gcForPersistence:(id<FSTPersistence>)persistence {
  id<FSTLRUDelegate> delegate = (id<FSTLRUDelegate>)persistence.referenceDelegate;
  return delegate.gc;
}

- (void)setUp {
  [super setUp];

  _previousTargetID = 500;
  _previousDocNum = 10;
  _testValue = FSTTestObjectValue(@{ @"baz" : @YES, @"ok" : @"fine" });
  NSString *bigString = [@"" stringByPaddingToLength:4096 withString:@"a" startingAtIndex:0];
  _bigObjectValue = FSTTestObjectValue(@{
          @"BigProperty": bigString
  });
}

- (BOOL)isTestBaseClass {
  return ([self class] == [FSTLRUGarbageCollectorTests class]);
}

- (FSTQueryData *)nextTestQuery:(id<FSTPersistence>)persistence {
  FSTTargetID targetID = ++_previousTargetID;
  FSTListenSequenceNumber listenSequenceNumber = persistence.currentSequenceNumber;
  FSTQuery *query = FSTTestQuery(absl::StrCat("path", targetID));
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:listenSequenceNumber
                                     purpose:FSTQueryPurposeListen];
}

- (FSTDocumentKey *)nextTestDocKey {
  NSString *path = [NSString stringWithFormat:@"docs/doc_%lu", (unsigned long)++_previousDocNum];
  return FSTTestDocKey(path);
}

- (FSTDocument *)nextTestDocumentWithValue:(FSTObjectValue *)value {
  FSTDocumentKey *key = [self nextTestDocKey];
  FSTTestSnapshotVersion version = 2;
  BOOL hasMutations = NO;
  return [FSTDocument documentWithData:value
                                   key:key
                               version:testutil::Version(version)
                     hasLocalMutations:hasMutations];
}

- (FSTDocument *)nextTestDocument {
  return [self nextTestDocumentWithValue:_testValue];
}

- (FSTDocument *)nextBigTestDocument {
  return [self nextTestDocumentWithValue:_bigObjectValue];
}

- (void)testPickSequenceNumberPercentile {
  if ([self isTestBaseClass]) return;

  const int numTestCases = 5;
  struct Case {
    // number of queries to cache
    int queries;
    // number expected to be calculated as 10%
    int expected;
  };
  struct Case testCases[numTestCases] = {{0, 0}, {10, 1}, {9, 0}, {50, 5}, {49, 4}};

  for (int i = 0; i < numTestCases; i++) {
    // Fill the query cache.
    int numQueries = testCases[i].queries;
    int expectedTenthPercentile = testCases[i].expected;
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("testPickSequenceNumberPercentile" + std::to_string(i), [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      for (int j = 0; j < numQueries; j++) {
        [queryCache addQueryData:[self nextTestQuery:persistence]];
      }
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      FSTListenSequenceNumber tenth = [gc queryCountForPercentile:10];
      XCTAssertEqual(expectedTenthPercentile, tenth, @"Total query count: %i", numQueries);
    });

    // TODO(gsoltis): technically should shutdown query cache, but it doesn't do anything anymore.
    [persistence shutdown];
  }
}

- (void)testSequenceNumberNoQueries {
  if ([self isTestBaseClass]) return;

  // Sequence numbers in this test start at 1001 and are incremented by one.

  // No queries... should get invalid sequence number (-1)
  id<FSTPersistence> persistence = [self newPersistence];
  persistence.run("no queries", [&]() {
    id<FSTQueryCache> queryCache = [persistence queryCache];
    [queryCache start];
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:0];
    XCTAssertEqual(kFSTListenSequenceNumberInvalid, highestToCollect);
  });
  [persistence shutdown];
}


- (void)testSequenceNumberForFiftyQueries {
  if ([self isTestBaseClass]) return;
  // 50 queries, want 10. Should get 10 past whatever the starting point is.
  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  FSTListenSequenceNumber initial = persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  for (int i = 0; i < 50; i++) {
    persistence.run("add query", [&]() {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    });
  }
  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(10 + initial, highestToCollect);
  });
  [persistence shutdown];
}

- (void)testSequenceNumberForMultipleQueriesInATransaction {
  // 50 queries, 9 with one transaction, incrementing from there. Should get second sequence number.
  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  FSTListenSequenceNumber initial = persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  persistence.run("9 queries in a batch", [&]() {
    for (int i = 0; i < 9; i++) {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    }
  });
  for (int i = 9; i < 50; i++) {
    persistence.run("sequential queries", [&]() {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    });
  }
  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(2 + initial, highestToCollect);
  });
  [persistence shutdown];
}

-(void)testAllCollectedQueriesInSingleTransaction {
  // 50 queries, 11 with one transaction, incrementing from there. Should get first sequence number.
  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  FSTListenSequenceNumber initial = persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  persistence.run("11 queries in a batch", [&]() {
    for (int i = 0; i < 11; i++) {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    }
  });
  for (int i = 11; i < 50; i++) {
    persistence.run("sequential queries", [&]() {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    });
  }
  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(1 + initial, highestToCollect);
  });
  [persistence shutdown];
}

- (void)testSequenceNumbersWithMutationAndSequentialQueries {
  // A mutated doc, then 50 queries. Should get 10 past initial (9 queries).
  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  FSTListenSequenceNumber initial = persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  persistence.run("Add mutated doc", [&]() {
    FSTDocumentKey *key = [self nextTestDocKey];
    [persistence.referenceDelegate removeMutationReference:key];
  });
  for (int i = 0; i < 50; i++) {
    persistence.run("sequential queries", [&]() {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    });
  }
  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(10 + initial, highestToCollect);
  });
  [persistence shutdown];
}


- (void)testSequenceNumbersWithMutationsInQueries {
  // Add mutated docs, then add one of them to a query target so it doesn't get GC'd.
  // Expect 3 past the initial value: the mutations not part of a query, and two queries
  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  FSTListenSequenceNumber initial = persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  FSTDocument *docInQuery = [self nextTestDocument];
  DocumentKeySet docInQuerySet{docInQuery.key};
  persistence.run("mark mutations", [&]() {
    // Adding 9 doc keys in a transaction. If we remove one of them, we'll have room for two actual
    // queries.
    [persistence.referenceDelegate removeMutationReference:docInQuery.key];
    for (int i = 0; i < 8; i++) {
      [persistence.referenceDelegate removeMutationReference:[self nextTestDocKey]];
    }
  });
  for (int i = 0; i < 49; i++) {
    persistence.run("sequential queries", [&]() {
      [queryCache addQueryData:[self nextTestQuery:persistence]];
    });
  }
  persistence.run("query with mutation", [&]() {
    FSTQueryData *queryData = [self nextTestQuery:persistence];
    [queryCache addQueryData:queryData];
    // This should bump one document out of the mutated documents cache.
    [queryCache addMatchingKeys:docInQuerySet forTargetID:queryData.targetID];
  });

  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    // This should catch the remaining 8 documents, plus the first two queries we added.
    XCTAssertEqual(3 + initial, highestToCollect);
  });
  [persistence shutdown];
}

- (void)testRemoveQueriesUpThroughSequenceNumber {
  if ([self isTestBaseClass]) return;

  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  FSTListenSequenceNumber initial = persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries =
      [[NSMutableDictionary alloc] init];
  for (int i = 0; i < 100; i++) {
    persistence.run("sequential queries", [&]() {
      FSTQueryData *queryData = [self nextTestQuery:persistence];
      // Mark odd queries as live so we can test filtering out live queries.
      if (queryData.targetID % 2 == 1) {
        liveQueries[@(queryData.targetID)] = queryData;
      }
      [queryCache addQueryData:queryData];
    });
  }
  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    // GC up through 15th query, which is 15%.
    // Expect to have GC'd 8 targets (even values of 2-16).
    NSUInteger removed = [gc removeQueriesUpThroughSequenceNumber:15 + initial liveQueries:liveQueries];
    XCTAssertEqual(7, removed);
  });
  [persistence shutdown];
}

- (void)testRemoveOrphanedDocuments {
  if ([self isTestBaseClass]) return;

  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  id<FSTRemoteDocumentCache> documentCache = [persistence remoteDocumentCache];
  User user("user");
  id<FSTMutationQueue> mutationQueue = [persistence mutationQueueForUser:user];
  FSTListenSequenceNumber initial = persistence.run("start tables", [&]() -> FSTListenSequenceNumber {
    [mutationQueue start];
    [queryCache start];
    return persistence.currentSequenceNumber;
  });
  // Add docs to mutation queue, as well as keep some queries. verify that correct documents are
  // removed.
  NSMutableSet<FSTDocumentKey *> *toBeRetained = [NSMutableSet set];
  NSMutableArray *mutations = [NSMutableArray arrayWithCapacity:2];
  persistence.run("add a target and add two documents to it", [&]() {
    // Add two documents to first target, queue a mutation on the second document
    FSTQueryData *queryData = [self nextTestQuery:persistence];
    [queryCache addQueryData:queryData];
    DocumentKeySet keySet{};
    FSTDocument *doc1 = [self nextTestDocument];
    [documentCache addEntry:doc1];
    keySet = keySet.insert(doc1.key);
    [toBeRetained addObject:doc1.key];
    FSTDocument *doc2 = [self nextTestDocument];
    [documentCache addEntry:doc2];
    keySet = keySet.insert(doc2.key);
    [toBeRetained addObject:doc2.key];
    [queryCache addMatchingKeys:keySet forTargetID:queryData.targetID];

    FSTObjectValue *newValue = [[FSTObjectValue alloc]
        initWithDictionary:@{@"foo" : [FSTStringValue stringValue:@"bar"]}];
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc2.key
                                                       value:newValue
                                                precondition:Precondition::None()]];
  });
  // Add a second query and register a document on it
  persistence.run("second query", [&]() {
    FSTQueryData *queryData = [self nextTestQuery:persistence];
    [queryCache addQueryData:queryData];
    DocumentKeySet keySet{};
    FSTDocument *doc1 = [self nextTestDocument];
    [documentCache addEntry:doc1];
    keySet = keySet.insert(doc1.key);
    [toBeRetained addObject:doc1.key];
    [queryCache addMatchingKeys:keySet forTargetID:queryData.targetID];
  });

  persistence.run("queue a mutation", [&]() {
    FSTDocument *doc1 = [self nextTestDocument];
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc1.key
                                                       value:doc1.data
                                                precondition:Precondition::None()]];
    [documentCache addEntry:doc1];
    [toBeRetained addObject:doc1.key];
  });

  persistence.run("actually register the mutations", [&]() {
    FIRTimestamp *writeTime = [FIRTimestamp timestamp];
    [mutationQueue addMutationBatchWithWriteTime:writeTime mutations:mutations];
  });

  NSUInteger expectedRemoveCount = 5;
  NSMutableSet<FSTDocumentKey *> *toBeRemoved =
          [NSMutableSet setWithCapacity:expectedRemoveCount];
  persistence.run("add orphaned docs (previously mutated, then ack'd)", [&]() {
    // Now add the docs we expect to get resolved.

    for (int i = 0; i < expectedRemoveCount; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [toBeRemoved addObject:doc.key];
      [documentCache addEntry:doc];
      [persistence.referenceDelegate removeMutationReference:doc.key];
    }
  });
  persistence.run("gc", [&]() {
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    NSUInteger removed = [gc removeOrphanedDocuments:documentCache
                               throughSequenceNumber:1000 // remove as much as possible
                                       mutationQueue:mutationQueue];

    XCTAssertEqual(expectedRemoveCount, removed);
    for (FSTDocumentKey *key in toBeRemoved) {
      XCTAssertNil([documentCache entryForKey:key]);
      XCTAssertFalse([queryCache containsKey:key]);
    }
    for (FSTDocumentKey *key in toBeRetained) {
      XCTAssertNotNil([documentCache entryForKey:key], @"Missing document %@", key);
    }
  });
  [persistence shutdown];
}
/*
// TODO(gsoltis): write a test that includes limbo documents

- (void)testRemoveTargetsThenGC {
  if ([self isTestBaseClass]) return;

  // Create 3 targets, add docs to all of them
  // Leave oldest target alone, it is still live
  // Remove newest target
  // Blind write 2 documents
  // Add one of the blind write docs to oldest target (preserves it)
  // Remove some documents from middle target (bumps sequence number)
  // Add some documents from newest target to oldest target (preserves them)
  // Update a doc from middle target
  // Remove middle target
  // Do a blind write
  // GC up to but not including the removal of the middle target
  //
  // Expect:
  // All docs in oldest target are still around
  // One blind write is gone, the first one not added to oldest target
  // Documents removed from middle target are gone, except ones added to oldest target
  // Documents from newest target are gone, except

  id<FSTPersistence> persistence = [self newPersistence];
  User user("user");
  id<FSTMutationQueue> mutationQueue = [persistence mutationQueueForUser:user];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  id<FSTRemoteDocumentCache> documentCache = [persistence remoteDocumentCache];

  NSMutableSet<FSTDocumentKey *> *expectedRetained = [NSMutableSet set];
  NSMutableSet<FSTDocumentKey *> *expectedRemoved = [NSMutableSet set];

  // Add oldest target and docs
  FSTQueryData *oldestTarget = [self nextTestQuery];
  persistence.run("Add oldest target and docs", [&]() {
    DocumentKeySet oldestDocs{};

    for (int i = 0; i < 5; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRetained addObject:doc.key];
      oldestDocs = oldestDocs.insert(doc.key);
      [documentCache addEntry:doc];
    }

    [queryCache addQueryData:oldestTarget];
    [queryCache addMatchingKeys:oldestDocs
                    forTargetID:oldestTarget.targetID
               atSequenceNumber:oldestTarget.sequenceNumber];
  });

  // Add middle target and docs. Some docs will be removed from this target later.
  FSTQueryData *middleTarget = [self nextTestQuery];
  DocumentKeySet middleDocsToRemove{};
  FSTDocumentKey *middleDocToUpdate = nil;
  persistence.run("Add middle target and docs", [&]() {
    [queryCache addQueryData:middleTarget];
    DocumentKeySet middleDocs{};
    // these docs will be removed from this target later
    for (int i = 0; i < 2; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRemoved addObject:doc.key];
      middleDocs = middleDocs.insert(doc.key);
      [documentCache addEntry:doc];
      middleDocsToRemove = middleDocsToRemove.insert(doc.key);
    }
    // these docs stay in this target and only this target
    for (int i = 2; i < 4; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRetained addObject:doc.key];
      middleDocs = middleDocs.insert(doc.key);
      [documentCache addEntry:doc];
    }
    // This doc stays in this target, but gets updated
    {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRetained addObject:doc.key];
      middleDocs = middleDocs.insert(doc.key);
      [documentCache addEntry:doc];
      middleDocToUpdate = doc.key;
    }
    [queryCache addMatchingKeys:middleDocs
                    forTargetID:middleTarget.targetID
               atSequenceNumber:middleTarget.sequenceNumber];

  });

  // Add newest target and docs.
  FSTQueryData *newestTarget = [self nextTestQuery];
  DocumentKeySet newestDocsToAddToOldest{};
  persistence.run("Add newest target and docs", [&]() {
    [queryCache addQueryData:newestTarget];
    DocumentKeySet newestDocs{};
    for (int i = 0; i < 3; i++) {
      FSTDocument *doc = [self nextBigTestDocument];
      [expectedRemoved addObject:doc.key];
      newestDocs = newestDocs.insert(doc.key);
      [documentCache addEntry:doc];
    }
    // docs to add to the oldest target, will be retained
    for (int i = 3; i < 5; i++) {
      FSTDocument *doc = [self nextBigTestDocument];
      [expectedRetained addObject:doc.key];
      newestDocs = newestDocs.insert(doc.key);
      newestDocsToAddToOldest = newestDocsToAddToOldest.insert(doc.key);
      [documentCache addEntry:doc];
    }
    [queryCache addMatchingKeys:newestDocs
                    forTargetID:newestTarget.targetID
               atSequenceNumber:newestTarget.sequenceNumber];
  });

  // newestTarget removed here, this should bump sequence number? maybe?
  // we don't really need the sequence number for anything, we just don't include it
  // in live queries.
  [self nextSequenceNumber];

  // 2 doc writes, add one of them to the oldest target.
  persistence.run("2 doc writes, add one of them to the oldest target", [&]() {
    // write two docs and have them ack'd by the server. can skip mutation queue
    // and set them in document cache. Add potentially orphaned first, also add one
    // doc to a target.
    DocumentKeySet docKeys{};

    FSTDocument *doc1 = [self nextTestDocument];
    [documentCache addEntry:doc1];
    docKeys = docKeys.insert(doc1.key);
    DocumentKeySet firstKey = docKeys;

    FSTDocument *doc2 = [self nextTestDocument];
    [documentCache addEntry:doc2];
    docKeys = docKeys.insert(doc2.key);

    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    for (const DocumentKey &key : docKeys)  {
      [persistence.referenceDelegate removeMutationReference:key sequenceNumber:sequenceNumber];
    };
    //[queryCache addPotentiallyOrphanedDocuments:docKeys atSequenceNumber:[self nextSequenceNumber]];

    NSData *token = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    sequenceNumber = [self nextSequenceNumber];
    oldestTarget = [oldestTarget queryDataByReplacingSnapshotVersion:oldestTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];
    [queryCache updateQueryData:oldestTarget];
    [queryCache addMatchingKeys:firstKey
                    forTargetID:oldestTarget.targetID
               atSequenceNumber:oldestTarget.sequenceNumber];
    // nothing is keeping doc2 around, it should be removed
    [expectedRemoved addObject:doc2.key];
    // doc1 should be retained by being added to oldestTarget.
    [expectedRetained addObject:doc1.key];
  });

  // Remove some documents from the middle target.
  persistence.run("Remove some documents from the middle target", [&]() {
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    NSData *token = [@"token" dataUsingEncoding:NSUTF8StringEncoding];
    middleTarget = [middleTarget queryDataByReplacingSnapshotVersion:middleTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];

    [queryCache updateQueryData:middleTarget];
    [queryCache removeMatchingKeys:middleDocsToRemove
                       forTargetID:middleTarget.targetID
                    sequenceNumber:sequenceNumber];
  });

  // Add a couple docs from the newest target to the oldest (preserves them past the point where
  // newest was removed)
  persistence.run("Add a couple docs from the newest target to the oldest", [&]() {
    NSData *token = [@"add documents" dataUsingEncoding:NSUTF8StringEncoding];
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    oldestTarget = [oldestTarget queryDataByReplacingSnapshotVersion:oldestTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];
    [queryCache updateQueryData:oldestTarget];
    [queryCache addMatchingKeys:newestDocsToAddToOldest
                    forTargetID:oldestTarget.targetID
               atSequenceNumber:oldestTarget.sequenceNumber];
  });

  // the sequence number right before middleTarget is updated, then removed.
  FSTListenSequenceNumber upperBound = [self nextSequenceNumber];

  // Update a doc in the middle target
  persistence.run("Update a doc in the middle target", [&]() {
    FSTTestSnapshotVersion version = 3;
    FSTDocument *doc = [FSTDocument documentWithData:_testValue
                                                 key:middleDocToUpdate
                                             version:testutil::Version(version)
                                   hasLocalMutations:NO];
    [documentCache addEntry:doc];
    NSData *token = [@"updated" dataUsingEncoding:NSUTF8StringEncoding];
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    middleTarget = [middleTarget queryDataByReplacingSnapshotVersion:middleTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];
    [queryCache updateQueryData:middleTarget];
  });

  // middleTarget removed here
  [self nextSequenceNumber];

  // Write a doc and get an ack, not part of a target
  persistence.run("Write a doc and get an ack, not part of a target", [&]() {
    FSTDocument *doc = [self nextTestDocument];

    [documentCache addEntry:doc];
    // This should be retained, it's too new to get removed.
    [expectedRetained addObject:doc.key];
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    //[queryCache addPotentiallyOrphanedDocuments:docKey atSequenceNumber:sequenceNumber];
    [persistence.referenceDelegate removeMutationReference:doc.key sequenceNumber:sequenceNumber];
  });


  // Finally, do the garbage collection, up to but not including the removal of middleTarget
  persistence.run(
      "do the garbage collection, up to but not including the removal of middleTarget", [&]() {
        NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries =
            [NSMutableDictionary dictionary];
        liveQueries[@(oldestTarget.targetID)] = oldestTarget;
        FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
        NSUInteger queriesRemoved =
            [gc removeQueriesUpThroughSequenceNumber:upperBound liveQueries:liveQueries];
        XCTAssertEqual(1, queriesRemoved, @"Expected to remove newest target");

        NSUInteger docsRemoved = [gc removeOrphanedDocuments:documentCache
                                       throughSequenceNumber:upperBound
                                               mutationQueue:mutationQueue];
        NSLog(@"Expected removed: %@", expectedRemoved);
        NSLog(@"Expected retained: %@", expectedRetained);
        XCTAssertEqual([expectedRemoved count], docsRemoved);

        for (FSTDocumentKey *key in expectedRemoved) {
          XCTAssertNil([documentCache entryForKey:key],
                       @"Did not expect to find %@ in document cache", key);
          XCTAssertFalse([queryCache containsKey:key], @"Did not expect to find %@ in queryCache",
                         key);
        }
        for (FSTDocumentKey *key in expectedRetained) {
          XCTAssertNotNil([documentCache entryForKey:key], @"Expected to find %@ in document cache",
                          key);
        }
      });

  [persistence shutdown];
}*/
@end

NS_ASSUME_NONNULL_END