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

var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');

var voiceObjects = {};

/**
 * This class provides access to the device voice
 *
 * @constructor
 * @param src                   The file name or url to play
 * @param successCallback       The callback to be called when the file is done playing or recording.
 *                                  successCallback()
 * @param errorCallback         The callback to be called if there is an error.
 *                                  errorCallback(int errorCode) - OPTIONAL
 * @param statusCallback        The callback to be called when media status has changed.
 *                                  statusCallback(int statusCode) - OPTIONAL
 */
var Voice = function(src, successCallback, errorCallback, statusCallback) {
    argscheck.checkArgs('SFFF', 'Voice', arguments);
    this.id = utils.createUUID();
    voiceObjects[this.id] = this;
    this.src = src;
    this.successCallback = successCallback;
    this.errorCallback = errorCallback;
    this.statusCallback = statusCallback;
    this._duration = -1;
    this._position = -1;
    this._power = -1;
    exec(null, this.errorCallback, "Voice", "create", [this.id, this.src]);
};

// Voice messages
Voice.VOICE_STATE = 1;
Voice.VOICE_DURATION = 2;
Voice.VOICE_POSITION = 3;
Voice.VOICE_POWER = 4;
Voice.VOICE_ERROR = 9;

// Voice states
Voice.VOICE_NONE = 0;
Voice.VOICE_STARTING = 1;
Voice.VOICE_RUNNING = 2;
Voice.VOICE_PAUSED = 3;
Voice.VOICE_STOPPED = 4;
Voice.VOICE_MSG = ["None", "Starting", "Running", "Paused", "Stopped"];

// "static" function to return existing objs.
Voice.get = function(id) {
    return voiceObjects[id];
};

/**
 * Start or resume playing voice file.
 */
Voice.prototype.play = function(options) {
    exec(null, null, "Voice", "startPlaying", [this.id, this.src, options]);
};

/**
 * Stop playing voice file.
 */
Voice.prototype.stop = function() {
    var me = this;
    exec(function() {
        me._position = 0;
    }, this.errorCallback, "Voice", "stopPlaying", [this.id]);
};

/**
 * Seek or jump to a new time in the track..
 */
Voice.prototype.seekTo = function(milliseconds) {
    var me = this;
    exec(function(p) {
        me._position = p;
    }, this.errorCallback, "Voice", "seekTo", [this.id, milliseconds]);
};

/**
 * Pause playing voice file.
 */
Voice.prototype.pause = function() {
    exec(null, this.errorCallback, "Voice", "pausePlaying", [this.id]);
};

/**
 * Get duration of an voice file.
 * The duration is only set for voice that is playing, paused or stopped.
 *
 * @return      duration or -1 if not known.
 */
Voice.prototype.getDuration = function() {
    return this._duration;
};

/**
 * Get position of voice.
 */
Voice.prototype.getCurrentPosition = function(success, fail) {
    var me = this;
    exec(function(p) {
        me._position = p;
        success(p);
    }, fail, "Voice", "getCurrentPosition", [this.id]);
};

Voice.prototype.getPower = function(success, fail) {
    var me = this;
    exec(function(p) {
        me._power = p;
        success(p);
    }, fail, "Voice", "getPower", [this.id]);
};

/**
 * Start recording voice file.
 */
Voice.prototype.startRecord = function() {
    exec(null, this.errorCallback, "Voice", "startRecording", [this.id, this.src]);
};

/**
 * Stop recording voice file.
 */
Voice.prototype.stopRecord = function() {
    exec(null, this.errorCallback, "Voice", "stopRecording", [this.id]);
};

/**
 * Release the resources.
 */
Voice.prototype.release = function() {
    exec(null, this.errorCallback, "Voice", "release", [this.id]);
};

/**
 * Adjust the volume.
 */
Voice.prototype.setVolume = function(volume) {
    exec(null, null, "Voice", "setVolume", [this.id, volume]);
};

/**
 * Voice has status update.
 * PRIVATE
 *
 * @param id            The voice object id (string)
 * @param msgType       The 'type' of update this is
 * @param value         Use of value is determined by the msgType
 */
Voice.onStatus = function(id, msgType, value) {

    var voice = voiceObjects[id];

    if(voice) {
        switch(msgType) {
            case Voice.VOICE_STATE :
                voice.statusCallback && voice.statusCallback(value);
                if(value == Voice.VOICE_STOPPED) {
                    voice.successCallback && voice.successCallback();
                }
                break;
            case Voice.VOICE_DURATION :
                voice._duration = value;
                break;
            case Voice.VOICE_ERROR :
                voice.errorCallback && voice.errorCallback(value);
                break;
            case Voice.VOICE_POSITION :
                voice._position = Number(value);
                break;
            case Voice.VOICE_POWER :
                voice._power = Number(value);
                break;    
            default :
                console.error && console.error("Unhandled Voice.onStatus :: " + msgType);
                break;
        }
    }
    else {
         console.error && console.error("Received Voice.onStatus callback for unknown voice :: " + id);
    }

};

module.exports = Voice;
