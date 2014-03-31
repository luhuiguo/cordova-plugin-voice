/*
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
*/

var _VoiceError = window.VoiceError;


if(!_VoiceError) {
    window.VoiceError = _VoiceError = function(code, msg) {
        this.code = (typeof code != 'undefined') ? code : null;
        this.message = msg || ""; // message is NON-standard! do not use!
    };
}

_VoiceError.VOICE_ERR_NONE_ACTIVE    = _VoiceError.VOICE_ERR_NONE_ACTIVE    || 0;
_VoiceError.VOICE_ERR_ABORTED        = _VoiceError.VOICE_ERR_ABORTED        || 1;
_VoiceError.VOICE_ERR_NETWORK        = _VoiceError.VOICE_ERR_NETWORK        || 2;
_VoiceError.VOICE_ERR_DECODE         = _VoiceError.VOICE_ERR_DECODE         || 3;
_VoiceError.VOICE_ERR_NONE_SUPPORTED = _VoiceError.VOICE_ERR_NONE_SUPPORTED || 4;

_VoiceError.VOICE_ERR_SRC_NOT_SUPPORTED = _VoiceError.VOICE_ERR_SRC_NOT_SUPPORTED || 4;

module.exports = _VoiceError;
