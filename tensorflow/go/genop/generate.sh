#!/usr/bin/env bash
# Copyright 2016 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

set -e

go get -d google.golang.org/protobuf/proto
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest

if [ -z "${GOPATH}" ]
then
  GOPATH=$(go env GOPATH)
fi

if [ -z "${GOOS}" ]
then
  GOOS=$(go env GOOS)
fi

# convert GOPATH's Windows style to UNIX style
if [[ $GOOS == "windows" ]]; then
  # eg: convert "D:\go-14;D:\go-13" to "D\go-14;D\go-13"
  GOPATH=${GOPATH//:\\/\\}
  # eg: convert "D\go-14;D\go-13" to "\D\go-14:\D\go-13"
  GOPATH=\\${GOPATH//;/:\\}
  # eg: convert "\D\go-14:\D\go-13" to "/D/go-14:/D/go-13"
  GOPATH=${GOPATH//\\/\/}
fi

cd $(dirname $0)
for g in $(echo "${GOPATH//:/ }"); do
    TF_DIR="${g}/src/github.com/galeone/tensorflow"
    PROTOC="${TF_DIR}/bazel-out/host/bin/external/protobuf/protoc"
    if [ -x "${PROTOC}" ]; then
        break
    fi
done

if [ ! -x "${PROTOC}" ]
then
  set +e
  PATH_PROTOC=$(which protoc)
  if [ ! -x "${PATH_PROTOC}" ]
  then
    echo "Protocol buffer compiler protoc not found in PATH or in ${PROTOC}"
    echo "Perhaps build it using:"
    echo "bazel build --config opt @com_google_protobuf//:protoc"
    exit 1
  fi
  PROTOC=$PATH_PROTOC
  set -e
fi

# Ensure that protoc-gen-go is available in $PATH
# Since ${PROTOC} will require it.
export PATH=$PATH:${GOPATH}/bin
for FILE in ${TF_DIR}/tensorflow/core/framework/*.proto \
    ${TF_DIR}/tensorflow/core/protobuf/*.proto \
    ${TF_DIR}/tensorflow/compiler/xla/pjrt/distributed/*.proto \
    ${TF_DIR}/tensorflow/stream_executor/*.proto; do
  ${PROTOC} \
    -I ${TF_DIR} \
    --go_out=${GOPATH}/src \
    $FILE
done
