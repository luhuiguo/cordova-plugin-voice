/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioServices.h>
#import <AVFoundation/AVFoundation.h>

#import <Cordova/CDVPlugin.h>

enum CDVVoiceError {
    VOICE_ERR_ABORTED = 1,
    VOICE_ERR_NETWORK = 2,
    VOICE_ERR_DECODE = 3,
    VOICE_ERR_NONE_SUPPORTED = 4
};
typedef NSUInteger CDVVoiceError;

enum CDVVoiceStates {
    VOICE_NONE = 0,
    VOICE_STARTING = 1,
    VOICE_RUNNING = 2,
    VOICE_PAUSED = 3,
    VOICE_STOPPED = 4
};
typedef NSUInteger CDVVoiceStates;

enum CDVVoiceMsg {
    VOICE_STATE = 1,
    VOICE_DURATION = 2,
    VOICE_POSITION = 3,
    VOICE_POWER = 4,
    VOICE_ERROR = 9
};
typedef NSUInteger CDVVoiceMsg;

@interface CDVVoicePlayer : AVAudioPlayer
{
    NSString* voiceId;
}
@property (nonatomic, copy) NSString* voiceId;
@end

@interface CDVVoiceRecorder : AVAudioRecorder
{
    NSString* voiceId;
}
@property (nonatomic, copy) NSString* voiceId;
@end

@interface CDVVoiceFile : NSObject
{
    NSString* resourcePath;
    NSString* wavFilePath;
    NSString* amrFilePath;
    NSURL* resourceURL;
    CDVVoicePlayer* player;
    CDVVoiceRecorder* recorder;
    NSNumber* volume;
}

@property (nonatomic, strong) NSString* resourcePath;
@property (nonatomic, strong) NSString* wavFilePath;
@property (nonatomic, strong) NSString* amrFilePath;
@property (nonatomic, strong) NSURL* resourceURL;
@property (nonatomic, strong) CDVVoicePlayer* player;
@property (nonatomic, strong) NSNumber* volume;

@property (nonatomic, strong) CDVVoiceRecorder* recorder;

- (int)amrToWav;

- (int)wavToAmr;

@end

@interface CDVVoice : CDVPlugin <AVAudioPlayerDelegate, AVAudioRecorderDelegate>
{
    NSMutableDictionary* voiceCache;
    AVAudioSession* avSession;
}
@property (nonatomic, strong) NSMutableDictionary* voiceCache;
@property (nonatomic, strong) AVAudioSession* avSession;

- (void)startPlaying:(CDVInvokedUrlCommand*)command;
- (void)pausePlaying:(CDVInvokedUrlCommand*)command;
- (void)stopPlaying:(CDVInvokedUrlCommand*)command;
- (void)seekTo:(CDVInvokedUrlCommand*)command;
- (void)release:(CDVInvokedUrlCommand*)command;
- (void)getCurrentPosition:(CDVInvokedUrlCommand*)command;

- (BOOL)hasSession;

// helper methods
- (NSURL*)urlForRecording:(NSString*)resourcePath;
- (NSURL*)urlForPlaying:(NSString*)resourcePath;

- (CDVVoiceFile*)voiceFileForResource:(NSString*)resourcePath withId:(NSString*)voiceId doValidation:(BOOL)bValidate forRecording:(BOOL)bRecord;
- (BOOL)prepareToPlay:(CDVVoiceFile*)voiceFile withId:(NSString*)voiceId;
- (NSString*)createVoiceErrorWithCode:(CDVVoiceError)code message:(NSString*)message;

- (void)startRecording:(CDVInvokedUrlCommand*)command;
- (void)stopRecording:(CDVInvokedUrlCommand*)command;
- (void)getPower:(CDVInvokedUrlCommand*)command;

- (void)setVolume:(CDVInvokedUrlCommand*)command;

+ (NSDictionary*)getRecorderSettings;


@end
