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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "benchmark/benchmark.h"

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::DatabaseId;

// Pre-existing document size
static const int kDocumentSize = 1024 * 2;  // 2 kb

static std::string DocumentData() {
  return std::string(kDocumentSize, 'a');
}

static std::string UpdatedDocumentData(int documentSize) {
  return std::string(documentSize, 'b');
}

static NSString *LevelDBDir() {
  NSError *error;
  NSFileManager *files = [NSFileManager defaultManager];
  NSString *dir =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"FSTPersistenceTestHelpers"];
  if ([files fileExistsAtPath:dir]) {
    // Delete the directory first to ensure isolation between runs.
    BOOL success = [files removeItemAtPath:dir error:&error];
    if (!success) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"Failed to clean up leveldb path %@: %@", dir, error];
    }
  }
  return dir;
}

static FSTLevelDB *LevelDBPersistence() {
  // This owns the DatabaseIds since we do not have FirestoreClient instance to own them.
  static DatabaseId database_id{"p", "d"};

  NSString *dir = LevelDBDir();
  FSTSerializerBeta *remoteSerializer = [[FSTSerializerBeta alloc] initWithDatabaseID:&database_id];
  FSTLocalSerializer *serializer =
      [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];
  FSTLevelDB *db = [[FSTLevelDB alloc] initWithDirectory:dir serializer:serializer];
  NSError *error;
  BOOL success = [db start:&error];
  if (!success) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to create leveldb path %@: %@", dir, error];
  }

  return db;
}

class LevelDBFixture : public benchmark::Fixture {
  virtual void SetUp(benchmark::State &state) {
    _db = LevelDBPersistence();
    FillDB();
  }

  virtual void TearDown(benchmark::State &state) {
    _db = nil;
  }

  void FillDB() {
    LevelDbTransaction txn(_db.ptr, "benchmark");

    for (int i = 0; i < _numDocuments; i++) {
      FSTDocumentKey *docKey =
          [FSTDocumentKey keyWithPathString:[NSString stringWithFormat:@"docs/doc_%i", i]];
      std::string docKeyString = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:docKey];
      txn.Put(docKeyString, DocumentData());
      WriteIndex(txn, docKey);
    }
    txn.Commit();
    // Force a write to disk to simulate startup situation
    _db.ptr->CompactRange(NULL, NULL);
  }

 protected:
  void WriteIndex(LevelDbTransaction &txn, FSTDocumentKey *docKey) {
    txn.Put([FSTLevelDBDocumentTargetKey keyWithDocumentKey:docKey targetID:_targetID],
            _emptyBuffer);
    txn.Put([FSTLevelDBTargetDocumentKey keyWithTargetID:_targetID documentKey:docKey],
            _emptyBuffer);
  }

  FSTLevelDB *_db;
  // Arbitrary target ID
  FSTTargetID _targetID = 1;
  int _numDocuments = 10;
  std::string _emptyBuffer;
};

// Plan: write a bunch of key/value pairs w/ empty strings (index entries)
// Write a couple large values (documents)
// In each test, either overwrite index entries and documents, or just documents

BENCHMARK_DEFINE_F(LevelDBFixture, RemoteEvent)(benchmark::State &state) {
  bool writeIndexes = (bool)state.range(0);
  int64_t documentSize = state.range(1);
  int64_t docsToUpdate = state.range(2);
  std::string documentUpdate = UpdatedDocumentData((int)documentSize);
  for (auto _ : state) {
    LevelDbTransaction txn(_db.ptr, "benchmark");
    for (int i = 0; i < docsToUpdate; i++) {
      FSTDocumentKey *docKey =
          [FSTDocumentKey keyWithPathString:[NSString stringWithFormat:@"docs/doc_%i", i]];
      if (writeIndexes) WriteIndex(txn, docKey);
      std::string docKeyString = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:docKey];
      txn.Put(docKeyString, documentUpdate);
    }
    txn.Commit();
  }
}

/**
 * Adjust ranges to control what test cases run. Outermost loop controls whether or
 * not indexes are written, the inner loops control size of document writes and number
 * of document writes.
 */
static void TestCases(benchmark::internal::Benchmark *b) {
  for (int writeIndexes = 0; writeIndexes <= 1; writeIndexes++) {
    for (int documentSize = 1 << 10; documentSize <= 1 << 20; documentSize *= 4) {
      for (int docsToUpdate = 1; docsToUpdate <= 5; docsToUpdate++) {
        b->Args({writeIndexes, documentSize, docsToUpdate});
      }
    }
  }
}

BENCHMARK_REGISTER_F(LevelDBFixture, RemoteEvent)
    ->Apply(TestCases)
    ->Unit(benchmark::kMicrosecond)
    ->Repetitions(5);

@interface FSTLevelDBBenchmarkTests : XCTestCase
@end

@implementation FSTLevelDBBenchmarkTests

- (void)testRunBenchmarks {
  // Enable to run benchmarks.
  char *argv[3] = {const_cast<char *>("Benchmarks"),
                   const_cast<char *>("--benchmark_out=/tmp/leveldb_benchmark"),
                   const_cast<char *>("--benchmark_out_format=csv")};
  int argc = 3;
  benchmark::Initialize(&argc, argv);
  benchmark::RunSpecifiedBenchmarks();
}

@end

NS_ASSUME_NONNULL_END
