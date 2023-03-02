/*
 * Copyright 2023 Google LLC
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

#include "Firestore/core/src/remote/bloom_filter.h"

#include <fstream>
#include <iostream>
#include <vector>

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/json_reader.h"
#include "Firestore/core/src/util/path.h"
#include "absl/strings/escaping.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {
using nlohmann::json;
using util::JsonReader;
using util::Path;
using util::Status;
using util::StatusOr;

TEST(BloomFilterUnitTest, CanInstantiateEmptyBloomFilter) {
  BloomFilter bloom_filter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_EQ(bloom_filter.bit_count(), 0);
}

TEST(BloomFilterUnitTest, CanInstantiateNonEmptyBloomFilter) {
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 0, 1);
    EXPECT_EQ(bloom_filter.bit_count(), 8);
  }
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 7, 1);
    EXPECT_EQ(bloom_filter.bit_count(), 1);
  }
}

TEST(BloomFilterUnitTest, CreateShouldReturnBloomFilterOnValidInputs) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 1);
  ASSERT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 7);
}

TEST(BloomFilterUnitTest, CreateShouldBeAbleToCreatEmptyBloomFilter) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{}, 0, 0);
  ASSERT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 0);
}

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusOnNegativePadding) {
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{}, -1, 0);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid padding: -1");
  }
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{1}, -1, 1);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid padding: -1");
  }
}

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusOnNegativeHashCount) {
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{}, 0, -1);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid hash count: -1");
  }
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{1}, 1, -1);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid hash count: -1");
  }
}

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusOnZeroHashCount) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 0);
  ASSERT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(),
            "Invalid hash count: 0");
}

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusIfPaddingIsTooLarge) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 8, 1);
  ASSERT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(), "Invalid padding: 8");
}

TEST(BloomFilterUnitTest, MightContainCanProcessNonStandardCharacters) {
  // A non-empty BloomFilter object with 1 insertion : "ÀÒ∑"
  BloomFilter bloom_filter(std::vector<uint8_t>{237, 5}, 5, 8);
  EXPECT_TRUE(bloom_filter.MightContain("ÀÒ∑"));
  EXPECT_FALSE(bloom_filter.MightContain("Ò∑À"));
}

TEST(BloomFilterUnitTest, MightContainOnEmptyBloomFilterShouldReturnFalse) {
  BloomFilter bloom_filter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_FALSE(bloom_filter.MightContain(""));
  EXPECT_FALSE(bloom_filter.MightContain("a"));
}

TEST(BloomFilterUnitTest,
     MightContainWithEmptyStringMightReturnFalsePositiveResult) {
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 1, 1);
    EXPECT_FALSE(bloom_filter.MightContain(""));
  }
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{255}, 0, 16);
    EXPECT_TRUE(bloom_filter.MightContain(""));
  }
}

class BloomFilterGoldenTest : public ::testing::Test {
 public:
  void RunGoldenTest(const std::string& test_file) {
    BloomFilter bloom_filter = GetBloomFilter(test_file);
    std::string membership_result = GetMembershipResult(test_file);

    for (size_t i = 0; i < membership_result.length(); i++) {
      bool expectedResult = membership_result[i] == '1';
      bool mightContainResult =
          bloom_filter.MightContain(kGoldenDocumentPrefix + std::to_string(i));

      EXPECT_EQ(mightContainResult, expectedResult);
    }
  }

 private:
  static const char* kGoldenDocumentPrefix;
  JsonReader reader;

  static Path GetGoldenTestFolder() {
    return Path::FromUtf8(__FILE__).Dirname().AppendUtf8(
        "bloom_filter_golden_test_data/");
  }

  json ReadFile(const std::string& file_name) {
    Path file_path = GetGoldenTestFolder().AppendUtf8(file_name);
    std::ifstream stream(file_path.native_value());
    HARD_ASSERT(stream.good());
    return nlohmann::json::parse(stream);
  }

  BloomFilter GetBloomFilter(const std::string& file_name) {
    json test_file = ReadFile(file_name);
    nlohmann::json bits = reader.OptionalObject("bits", test_file, {});
    std::string bitmap = reader.OptionalString("bitmap", bits, "");
    int padding = reader.OptionalInt("padding", bits, 0);
    int hash_count = reader.OptionalInt("hashCount", test_file, 0);
    std::string decoded;
    absl::Base64Unescape(bitmap, &decoded);
    std::vector<uint8_t> decoded_map(decoded.begin(), decoded.end());

    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::move(decoded_map), padding, hash_count);
    HARD_ASSERT(maybe_bloom_filter.ok(),
                "Bloom filter input file %s has invalid values.", file_name);
    BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();

    return bloom_filter;
  }

  std::string LocateResultFile(std::string file_name) {
    const std::string substring = "bloom_filter_proto";
    size_t start_pos = file_name.find(substring);
    HARD_ASSERT(start_pos != std::string::npos,
                "Test file name %s is not valid, expected to include "
                "\"bloom_filter_proto\".",
                file_name);

    return file_name.replace(start_pos, substring.size(),
                             "membership_test_result");
  }

  std::string GetMembershipResult(const std::string& file_name) {
    std::string result_file_name = LocateResultFile(file_name);
    json result_file = ReadFile(result_file_name);
    std::string membership_result = reader.OptionalString(
        "membershipTestResults", result_file, "[invalid]");
    HARD_ASSERT(
        membership_result != "[invalid]",
        "Membership result file %s doesn't contain \"membershipTestResults\".",
        result_file_name);
    return membership_result;
  }
};

const char* BloomFilterGoldenTest::kGoldenDocumentPrefix =
    "projects/project-1/databases/database-1/documents/coll/doc";

/**
 * Golden tests are generated by backend based on inserting n number of document
 * paths into a bloom filter.
 *
 * <p>Full document path is generated by concatenating documentPrefix and number
 * n, eg, projects/project-1/databases/database-1/documents/coll/doc12.
 *
 * <p>The test result is generated by checking the membership of documents from
 * documentPrefix+0 to documentPrefix+2n. The membership results from 0 to n is
 * expected to be true, and the membership results from n to 2n is expected to
 * be false with some false positive results.
 */
TEST_F(BloomFilterGoldenTest, GoldenTest1Document1FalsePositiveRate) {
  RunGoldenTest("Validation_BloomFilterTest_MD5_1_1_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest1Document01FalsePositiveRate) {
  RunGoldenTest("Validation_BloomFilterTest_MD5_1_01_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest1Document0001FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_1_0001_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest500Document1FalsePositiveRate) {
  RunGoldenTest("Validation_BloomFilterTest_MD5_500_1_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest500Document01FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_500_01_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest500Document0001FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_500_0001_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest5000Document1FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_5000_1_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest5000Document01FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_5000_01_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest5000Document0001FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_5000_0001_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest50000Document1FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_50000_1_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest50000Document01FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_50000_01_bloom_filter_proto.json");
}

TEST_F(BloomFilterGoldenTest, GoldenTest50000Document0001FalsePositiveRate) {
  RunGoldenTest(
      "Validation_BloomFilterTest_MD5_50000_0001_bloom_filter_proto.json");
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
