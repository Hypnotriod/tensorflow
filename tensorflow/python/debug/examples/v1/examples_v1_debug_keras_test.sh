#!/bin/bash
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
#
# Bash unit tests for TensorFlow Debugger (tfdbg) Python examples that do not
# involve downloading data.
#
# Command-line flags:
#   --virtualenv: (optional) If set, will test the examples and binaries
#     against pip install of TensorFlow in a virtualenv.

set -e

# Filter out LOG(INFO)
export TF_CPP_MIN_LOG_LEVEL=1

IS_VIRTUALENV=0
PYTHON_BIN_PATH=""
while true; do
  if [[ -z "$1" ]]; then
    break
  elif [[ "$1" == "--virtualenv" ]]; then
    IS_VIRTUALENV=1
    PYTHON_BIN_PATH=$(which python)
    echo
    echo "IS_VIRTUALENV = ${IS_VIRTUALENV}"
    echo "PYTHON_BIN_PATH = ${PYTHON_BIN_PATH}"
    echo "Will test tfdbg debug_keras against virtualenv pip install."
    echo
  fi
  shift 1
done

if [[ -z "${PYTHON_BIN_PATH}" ]]; then
  DEBUG_KERAS_BIN="$TEST_SRCDIR/org_galeone/tensorflow/python/debug/examples/v1/debug_keras"
else
  DEBUG_KERAS_BIN="${PYTHON_BIN_PATH} -m tensorflow.python.debug.examples.v1.debug_keras"
fi

# Override the default ui_type=curses to allow the test to pass in a tty-less
# test environment.

# Test debugging of tf.keras.
cat << EOF | ${DEBUG_KERAS_BIN} --debug --ui_type=readline --use_random_config_path
run -f has_inf_or_nan
EOF

# Test debugging of tf.keras, with non-debug runs included.
cat << EOF | ${DEBUG_KERAS_BIN} --debug --ui_type=readline --use_random_config_path
run -t 11
EOF

echo
echo "SUCCESS: tfdbg debug_keras test PASSED"
