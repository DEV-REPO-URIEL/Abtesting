# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Within Travis, installs prerequisites for a build.

# Examines the following configured environment variables that should be
# specified in an env: block
#   - PROJECT - only Firestore is supported for now
#   - METHOD - xcodebuild or cmake

case "$PROJECT-$METHOD" in
  Firestore-xcodebuild)
    bundle install
    gem install xcpretty
    ./scripts/if_changed.sh bundle exec pod install \
        --project-directory=Firestore/Example --repo-update
    ;;

  Firestore-cmake)
      bundle install
      # xcpretty is helpful for the intermediate step which builds FirebaseCore
      # using xcodebuild.
      gem install xcpretty
      brew install cmake
      brew install go # Somehow the build for Abseil requires this.
      ./scripts/if_changed.sh bundle exec pod install \
          --project-directory=Example --repo-update
      ./scripts/if_changed.sh bundle exec pod install \
          --project-directory=Firestore/Example --no-repo-update
    ;;

  *)
    echo "Unknown project-method combo" 1>&2
    echo "  PROJECT=$PROJECT" 1>&2
    echo "  METHOD=$METHOD" 1>&2
    echo "Only Firestore is supported now."
    exit 1
    ;;
esac
