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

#import "CDVVoice.h"
#import "CDVFile.h"
#import <Cordova/NSArray+Comparisons.h>
#import <Cordova/CDVJSON.h>
#import "amrFileCodec.h"

#define DOCUMENTS_SCHEME_PREFIX @"documents://"
#define HTTP_SCHEME_PREFIX @"http://"
#define HTTPS_SCHEME_PREFIX @"https://"
#define CDVFILE_PREFIX @"cdvfile://"
#define RECORDING_WAV @"wav"
#define RECORDING_AMR @"amr"

@implementation CDVVoice

@synthesize voiceCache, avSession;

- (NSURL*)urlForResource:(NSString*)resourcePath
{
    NSURL* resourceURL = nil;
    NSString* filePath = nil;

    // first try to find HTTP:// or Documents:// resources

    if ([resourcePath hasPrefix:HTTP_SCHEME_PREFIX] || [resourcePath hasPrefix:HTTPS_SCHEME_PREFIX]) {
        // if it is a http url, use it
        NSLog(@"Will use resource '%@' from the Internet.", resourcePath);
        resourceURL = [NSURL URLWithString:resourcePath];
    } else if ([resourcePath hasPrefix:DOCUMENTS_SCHEME_PREFIX]) {
        NSString* docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        filePath = [resourcePath stringByReplacingOccurrencesOfString:DOCUMENTS_SCHEME_PREFIX withString:[NSString stringWithFormat:@"%@/", docsPath]];
        NSLog(@"Will use resource '%@' from the documents folder with path = %@", resourcePath, filePath);
    } else {
        // attempt to find file path in www directory
        filePath = [self.commandDelegate pathForResource:resourcePath];
        if (filePath != nil) {
            NSLog(@"Found resource '%@' in the web folder.", filePath);
        } else {
            filePath = resourcePath;
            NSLog(@"Will attempt to use file resource '%@'", filePath);
        }
    }
    // check that file exists for all but HTTP_SHEME_PREFIX
    if (filePath != nil) {
        // try to access file
        NSFileManager* fMgr = [[NSFileManager alloc] init];
        if (![fMgr fileExistsAtPath:filePath]) {
            resourceURL = nil;
            NSLog(@"Unknown resource '%@'", resourcePath);
        } else {
            // it's a valid file url, use it
            resourceURL = [NSURL fileURLWithPath:filePath];
        }
    }
    return resourceURL;
}

- (NSString*)filePathForResource:(NSString*)resourcePath
{
    NSString* docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString* filePath = nil;
    if ([resourcePath hasPrefix:DOCUMENTS_SCHEME_PREFIX]) {
       
        filePath = [resourcePath stringByReplacingOccurrencesOfString:DOCUMENTS_SCHEME_PREFIX withString:[NSString stringWithFormat:@"%@/", docsPath]];
    }else {

        NSString* tmpPath = [NSTemporaryDirectory() stringByStandardizingPath];
        BOOL isTmp = [resourcePath rangeOfString:tmpPath].location != NSNotFound;
        BOOL isDoc = [resourcePath rangeOfString:docsPath].location != NSNotFound;
        if (!isTmp && !isDoc) {
            // put in temp dir
            filePath = [NSString stringWithFormat:@"%@/%@", tmpPath, resourcePath];
        } else {
            filePath = resourcePath;
        }
    }

    return filePath;
    
}

// Maps a url for a resource path for recording
- (NSURL*)urlForRecording:(NSString*)resourcePath
{
    NSURL* resourceURL = nil;
    NSString* filePath = nil;
    NSString* docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];

    // first check for correct extension
    if ([[resourcePath pathExtension] caseInsensitiveCompare:RECORDING_WAV] != NSOrderedSame) {
        resourceURL = nil;
        NSLog(@"Resource for recording must have %@ extension", RECORDING_WAV);
    } else if ([resourcePath hasPrefix:DOCUMENTS_SCHEME_PREFIX]) {
        // try to find Documents:// resources
        filePath = [resourcePath stringByReplacingOccurrencesOfString:DOCUMENTS_SCHEME_PREFIX withString:[NSString stringWithFormat:@"%@/", docsPath]];
        NSLog(@"Will use resource '%@' from the documents folder with path = %@", resourcePath, filePath);
    } else if ([resourcePath hasPrefix:CDVFILE_PREFIX]) {
        CDVFile *filePlugin = [self.commandDelegate getCommandInstance:@"File"];
        CDVFilesystemURL *url = [CDVFilesystemURL fileSystemURLWithString:resourcePath];
        filePath = [filePlugin filesystemPathForURL:url];
        if (filePath == nil) {
            resourceURL = [NSURL URLWithString:resourcePath];
        }
    } else {
        // if resourcePath is not from FileSystem put in tmp dir, else attempt to use provided resource path
        NSString* tmpPath = [NSTemporaryDirectory()stringByStandardizingPath];
        BOOL isTmp = [resourcePath rangeOfString:tmpPath].location != NSNotFound;
        BOOL isDoc = [resourcePath rangeOfString:docsPath].location != NSNotFound;
        if (!isTmp && !isDoc) {
            // put in temp dir
            filePath = [NSString stringWithFormat:@"%@/%@", tmpPath, resourcePath];
        } else {
            filePath = resourcePath;
        }
    }

    if (filePath != nil) {
        // create resourceURL
        resourceURL = [NSURL fileURLWithPath:filePath];
    }
    return resourceURL;
}

// Maps a url for a resource path for playing
// "Naked" resource paths are assumed to be from the www folder as its base
- (NSURL*)urlForPlaying:(NSString*)resourcePath
{
    NSURL* resourceURL = nil;
    NSString* filePath = nil;

    // first try to find HTTP:// or Documents:// resources

    if ([resourcePath hasPrefix:HTTP_SCHEME_PREFIX] || [resourcePath hasPrefix:HTTPS_SCHEME_PREFIX]) {
        // if it is a http url, use it
        NSLog(@"Will use resource '%@' from the Internet.", resourcePath);
        resourceURL = [NSURL URLWithString:resourcePath];
    } else if ([resourcePath hasPrefix:DOCUMENTS_SCHEME_PREFIX]) {
        NSString* docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        filePath = [resourcePath stringByReplacingOccurrencesOfString:DOCUMENTS_SCHEME_PREFIX withString:[NSString stringWithFormat:@"%@/", docsPath]];
        NSLog(@"Will use resource '%@' from the documents folder with path = %@", resourcePath, filePath);
    } else if ([resourcePath hasPrefix:CDVFILE_PREFIX]) {
        CDVFile *filePlugin = [self.commandDelegate getCommandInstance:@"File"];
        CDVFilesystemURL *url = [CDVFilesystemURL fileSystemURLWithString:resourcePath];
        filePath = [filePlugin filesystemPathForURL:url];
        if (filePath == nil) {
            resourceURL = [NSURL URLWithString:resourcePath];
        }
    } else {
        // attempt to find file path in www directory or LocalFileSystem.TEMPORARY directory
        filePath = [self.commandDelegate pathForResource:resourcePath];
        if (filePath == nil) {
            // see if this exists in the documents/temp directory from a previous recording
            NSString* testPath = [NSString stringWithFormat:@"%@/%@", [NSTemporaryDirectory()stringByStandardizingPath], resourcePath];
            if ([[NSFileManager defaultManager] fileExistsAtPath:testPath]) {
                // inefficient as existence will be checked again below but only way to determine if file exists from previous recording
                filePath = testPath;
                NSLog(@"Will attempt to use file resource from LocalFileSystem.TEMPORARY directory");
            } else {
                // attempt to use path provided
                filePath = resourcePath;
                NSLog(@"Will attempt to use file resource '%@'", filePath);
            }
        } else {
            NSLog(@"Found resource '%@' in the web folder.", filePath);
        }
    }
    // if the resourcePath resolved to a file path, check that file exists
    if (filePath != nil) {
        // create resourceURL
        resourceURL = [NSURL fileURLWithPath:filePath];
        // try to access file
        NSFileManager* fMgr = [NSFileManager defaultManager];
        if (![fMgr fileExistsAtPath:filePath]) {
            resourceURL = nil;
            NSLog(@"Unknown resource '%@'", resourcePath);
        }
    }

    return resourceURL;
}

- (CDVVoiceFile*)voiceFileForResource:(NSString*)resourcePath withId:(NSString*)voiceId
{
    // will maintain backwards compatibility with original implementation
    return [self voiceFileForResource:resourcePath withId:voiceId doValidation:YES forRecording:NO];
}

// Creates or gets the cached audio file resource object
- (CDVVoiceFile*)voiceFileForResource:(NSString*)resourcePath withId:(NSString*)voiceId doValidation:(BOOL)bValidate forRecording:(BOOL)bRecord
{
    BOOL bError = NO;
    CDVVoiceError errcode = VOICE_ERR_NONE_SUPPORTED;
    NSString* errMsg = @"";
    NSString* jsString = nil;
    CDVVoiceFile* voiceFile = nil;
    NSURL* resourceURL = nil;

    if ([self voiceCache] == nil) {
        [self setVoiceCache:[NSMutableDictionary dictionaryWithCapacity:1]];
    } else {
        voiceFile = [[self voiceCache] objectForKey:voiceId];
    }
    if (voiceFile == nil) {
        // validate resourcePath and create
        if ((resourcePath == nil) || ![resourcePath isKindOfClass:[NSString class]] || [resourcePath isEqualToString:@""]) {
            bError = YES;
            errcode = VOICE_ERR_ABORTED;
            errMsg = @"invalid voice src argument";
        } else {
            voiceFile = [[CDVVoiceFile alloc] init];
            voiceFile.resourcePath = resourcePath;
            
            NSString* temp = [resourcePath stringByDeletingPathExtension];
            NSString* wavResourcePath = [temp stringByAppendingPathExtension:RECORDING_WAV];
            NSString* amrResourcePath = [temp stringByAppendingPathExtension:RECORDING_AMR];
            
            voiceFile.amrFilePath = [self filePathForResource:amrResourcePath];
            
            voiceFile.wavFilePath = [self filePathForResource:wavResourcePath];
            
            voiceFile.resourceURL = nil;  // validate resourceURL when actually play or record
            [[self voiceCache] setObject:voiceFile forKey:voiceId];
        }
    }
    if (bValidate && (voiceFile.resourceURL == nil)) {

        
        if (bRecord) {
            resourceURL = [self urlForRecording:voiceFile.wavFilePath];
        } else {
            [voiceFile amrToWav];
            resourceURL = [self urlForPlaying:voiceFile.wavFilePath];
        }

        
        if (resourceURL == nil) {
            bError = YES;
            errcode = VOICE_ERR_ABORTED;
            errMsg = [NSString stringWithFormat:@"Cannot use voice file from resource '%@'", resourcePath];
        } else {
            voiceFile.resourceURL = resourceURL;
        }
    }

    if (bError) {
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:errcode message:errMsg]];
        [self.commandDelegate evalJs:jsString];
    }

    return voiceFile;
}

// returns whether or not audioSession is available - creates it if necessary
- (BOOL)hasSession
{
    BOOL bSession = YES;

    if (!self.avSession) {
        NSError* error = nil;

        self.avSession = [AVAudioSession sharedInstance];
        if (error) {
            // is not fatal if can't get AVAudioSession , just log the error
            NSLog(@"error creating audio session: %@", [[error userInfo] description]);
            self.avSession = nil;
            bSession = NO;
        }
    }
    return bSession;
}

// helper function to create a error object string
- (NSString*)createVoiceErrorWithCode:(CDVVoiceError)code message:(NSString*)message
{
    NSMutableDictionary* errorDict = [NSMutableDictionary dictionaryWithCapacity:2];

    [errorDict setObject:[NSNumber numberWithUnsignedInteger:code] forKey:@"code"];
    [errorDict setObject:message ? message:@"" forKey:@"message"];
    return [errorDict JSONString];
}

- (void)create:(CDVInvokedUrlCommand*)command
{
    NSString* voiceId = [command.arguments objectAtIndex:0];
    NSString* resourcePath = [command.arguments objectAtIndex:1];

    CDVVoiceFile* voiceFile = [self voiceFileForResource:resourcePath withId:voiceId doValidation:NO forRecording:NO];

    if (voiceFile == nil) {
        NSString* errorMessage = [NSString stringWithFormat:@"Failed to initialize Media file with path %@", resourcePath];
        NSString* jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_ABORTED message:errorMessage]];
        [self.commandDelegate evalJs:jsString];
    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)setVolume:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    [self.commandDelegate runInBackground:^{
#pragma unused(callbackId)
    NSString* voiceId = [command.arguments objectAtIndex:0];
    NSNumber* volume = [command.arguments objectAtIndex:1 withDefault:[NSNumber numberWithFloat:1.0]];

    if ([self voiceCache] != nil) {
        CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
        if (voiceFile != nil) {
            voiceFile.volume = volume;
            if (voiceFile.player) {
                voiceFile.player.volume = [volume floatValue];
            }
            [[self voiceCache] setObject:voiceFile forKey:voiceId];
        }
    }
    }];

    // don't care for any callbacks
}

- (void)startPlaying:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;

#pragma unused(callbackId)
    NSString* voiceId = [command.arguments objectAtIndex:0];
    NSString* resourcePath = [command.arguments objectAtIndex:1];
    NSDictionary* options = [command.arguments objectAtIndex:2 withDefault:nil];
    
    [self.commandDelegate runInBackground:^{
        
    BOOL bError = NO;
    NSString* jsString = nil;

    CDVVoiceFile* voiceFile = [self voiceFileForResource:resourcePath withId:voiceId doValidation:YES forRecording:NO];
    if ((voiceFile != nil) && (voiceFile.resourceURL != nil)) {
        if (voiceFile.player == nil) {
            bError = [self prepareToPlay:voiceFile withId:voiceId];
        }
        if (!bError) {
            // voiceFile.player != nil  or player was successfully created
            // get the audioSession and set the category to allow Playing when device is locked or ring/silent switch engaged
            if ([self hasSession]) {
                NSError* __autoreleasing err = nil;
                NSNumber* playAudioWhenScreenIsLocked = [options objectForKey:@"playAudioWhenScreenIsLocked"];
                BOOL bPlayAudioWhenScreenIsLocked = YES;
                if (playAudioWhenScreenIsLocked != nil) {
                    bPlayAudioWhenScreenIsLocked = [playAudioWhenScreenIsLocked boolValue];
                }

                NSString* sessionCategory = bPlayAudioWhenScreenIsLocked ? AVAudioSessionCategoryPlayback : AVAudioSessionCategorySoloAmbient;
                [self.avSession setCategory:sessionCategory error:&err];
                if (![self.avSession setActive:YES error:&err]) {
                    // other audio with higher priority that does not allow mixing could cause this to fail
                    NSLog(@"Unable to play audio: %@", [err localizedFailureReason]);
                    bError = YES;
                }
            }
            if (!bError) {
                NSLog(@"Playing audio sample '%@'", voiceFile.resourcePath);
                NSNumber* loopOption = [options objectForKey:@"numberOfLoops"];
                NSInteger numberOfLoops = 0;
                if (loopOption != nil) {
                    numberOfLoops = [loopOption intValue] - 1;
                }
                voiceFile.player.numberOfLoops = numberOfLoops;
                if (voiceFile.player.isPlaying) {
                    [voiceFile.player stop];
                    voiceFile.player.currentTime = 0;
                }
                if (voiceFile.volume != nil) {
                    voiceFile.player.volume = [voiceFile.volume floatValue];
                }

                [voiceFile.player play];
                double position = round(voiceFile.player.duration * 1000) / 1000;
                jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%.3f);\n%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_DURATION, position, @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_RUNNING];
                [self.commandDelegate evalJs:jsString];
            }
        }
        if (bError) {
            /*  I don't see a problem playing previously recorded audio so removing this section - BG
            NSError* error;
            // try loading it one more time, in case the file was recorded previously
            voiceFile.player = [[ AVAudioPlayer alloc ] initWithContentsOfURL:voiceFile.resourceURL error:&error];
            if (error != nil) {
                NSLog(@"Failed to initialize AVAudioPlayer: %@\n", error);
                voiceFile.player = nil;
            } else {
                NSLog(@"Playing audio sample '%@'", voiceFile.resourcePath);
                voiceFile.player.numberOfLoops = numberOfLoops;
                [voiceFile.player play];
            } */
            // error creating the session or player
            // jsString = [NSString stringWithFormat: @"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR,  VOICE_ERR_NONE_SUPPORTED];
            jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_NONE_SUPPORTED message:nil]];
            [self.commandDelegate evalJs:jsString];
        }
    }
    // else voiceFile was nil - error already returned from voiceFile for resource
    return;
    }];
}

- (BOOL)prepareToPlay:(CDVVoiceFile*)voiceFile withId:(NSString*)voiceId
{
    BOOL bError = NO;
    NSError* __autoreleasing playerError = nil;

    // create the player
    NSURL* resourceURL = voiceFile.resourceURL;

    if ([resourceURL isFileURL]) {
        voiceFile.player = [[CDVVoicePlayer alloc] initWithContentsOfURL:resourceURL error:&playerError];
    } else {
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:resourceURL];
        NSString* userAgent = [self.commandDelegate userAgent];
        if (userAgent) {
            [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
        }

        NSURLResponse* __autoreleasing response = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&playerError];
        if (playerError) {
            NSLog(@"Unable to download audio from: %@", [resourceURL absoluteString]);
        } else {
            // bug in AVAudioPlayer when playing downloaded data in NSData - we have to download the file and play from disk
            CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
            CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
            NSString* filePath = [NSString stringWithFormat:@"%@/%@", [NSTemporaryDirectory()stringByStandardizingPath], uuidString];
            CFRelease(uuidString);
            CFRelease(uuidRef);

            [data writeToFile:filePath atomically:YES];
            NSURL* fileURL = [NSURL fileURLWithPath:filePath];
            voiceFile.player = [[CDVVoicePlayer alloc] initWithContentsOfURL:fileURL error:&playerError];
        }
    }

    if (playerError != nil) {
        NSLog(@"Failed to initialize AVAudioPlayer: %@\n", [playerError localizedDescription]);
        voiceFile.player = nil;
        if (self.avSession) {
            [self.avSession setActive:NO error:nil];
        }
        bError = YES;
    } else {
        voiceFile.player.voiceId = voiceId;
        voiceFile.player.delegate = self;
        bError = ![voiceFile.player prepareToPlay];
    }
    return bError;
}

- (void)stopPlaying:(CDVInvokedUrlCommand*)command
{
    
    NSString* voiceId = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
        
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    NSString* jsString = nil;

    if ((voiceFile != nil) && (voiceFile.player != nil)) {
        NSLog(@"Stopped playing voice '%@'", voiceFile.resourcePath);
        [voiceFile.player stop];
        voiceFile.player.currentTime = 0;
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_STOPPED];
    }  // ignore if no media playing
    if (jsString) {
        [self.commandDelegate evalJs:jsString];
    }
        
    }];
}

- (void)pausePlaying:(CDVInvokedUrlCommand*)command
{
    NSString* voiceId = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
    NSString* jsString = nil;
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];

    if ((voiceFile != nil) && (voiceFile.player != nil)) {
        NSLog(@"Paused playing voice '%@'", voiceFile.resourcePath);
        [voiceFile.player pause];
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_PAUSED];
    }
    // ignore if no media playing

    if (jsString) {
        [self.commandDelegate evalJs:jsString];
    }
    }];
}

- (void)seekTo:(CDVInvokedUrlCommand*)command
{
    // args:
    // 0 = Media id
    // 1 = path to resource
    // 2 = seek to location in milliseconds

    NSString* voiceId = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    double position = [[command.arguments objectAtIndex:1] doubleValue];

    if ((voiceFile != nil) && (voiceFile.player != nil)) {
        NSString* jsString;
        double posInSeconds = position / 1000;
        if (posInSeconds >= voiceFile.player.duration) {
            // The seek is past the end of file.  Stop media and reset to beginning instead of seeking past the end.
            [voiceFile.player stop];
            voiceFile.player.currentTime = 0;
            jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%.3f);\n%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_POSITION, 0.0, @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_STOPPED];
            // NSLog(@"seekToEndJsString=%@",jsString);
        } else {
            voiceFile.player.currentTime = posInSeconds;
            jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%f);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_POSITION, posInSeconds];
            // NSLog(@"seekJsString=%@",jsString);
        }

        [self.commandDelegate evalJs:jsString];
    }
    }];
}

- (void)release:(CDVInvokedUrlCommand*)command
{
    NSString* voiceId = [command.arguments objectAtIndex:0];

    if (voiceId != nil) {
        CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
        if (voiceFile != nil) {
            if (voiceFile.player && [voiceFile.player isPlaying]) {
                [voiceFile.player stop];
            }
            if (voiceFile.recorder && [voiceFile.recorder isRecording]) {
                [voiceFile.recorder stop];
            }
            if (self.avSession) {
                [self.avSession setActive:NO error:nil];
                self.avSession = nil;
            }
            [[self voiceCache] removeObjectForKey:voiceId];
            NSLog(@"Voice with id %@ released", voiceId);
        }
    }
}

- (void)getCurrentPosition:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSString* voiceId = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
#pragma unused(voiceId)
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    double position = -1;

    if ((voiceFile != nil) && (voiceFile.player != nil) && [voiceFile.player isPlaying]) {
        position = round(voiceFile.player.currentTime * 1000) / 1000;
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:position];
    NSString* jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%.3f);\n%@", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_POSITION, position, [result toSuccessCallbackString:callbackId]];
    [self.commandDelegate evalJs:jsString];
    }];
}

- (void)getPower:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = command.callbackId;
    NSString* voiceId = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
#pragma unused(voiceId)
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    double power = -1;
    
    if ((voiceFile != nil) && (voiceFile.recorder != nil) && [voiceFile.recorder isRecording]) {
        
        power  = pow(10, (0.05 * [voiceFile.recorder peakPowerForChannel:0]));
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:power];
    NSString* jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%.3f);\n%@", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_POWER, power, [result toSuccessCallbackString:callbackId]];
    [self.commandDelegate evalJs:jsString];
    }];
}


- (void)startRecording:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;

#pragma unused(callbackId)

    NSString* voiceId = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
         
    CDVVoiceFile* voiceFile = [self voiceFileForResource:[command.arguments objectAtIndex:1] withId:voiceId doValidation:YES forRecording:YES];
    __block NSString* jsString = nil;
    __block NSString* errorMsg = @"";

    if ((voiceFile != nil) && (voiceFile.resourceURL != nil)) {
        void (^startRecording)(void) = ^{
            NSError* __autoreleasing error = nil;
            
            if (voiceFile.recorder != nil) {
                [voiceFile.recorder stop];
                voiceFile.recorder = nil;
            }
            // get the audioSession and set the category to allow recording when device is locked or ring/silent switch engaged
            if ([self hasSession]) {
                [self.avSession setCategory:AVAudioSessionCategoryRecord error:nil];
                if (![self.avSession setActive:YES error:&error]) {
                    // other audio with higher priority that does not allow mixing could cause this to fail
                    errorMsg = [NSString stringWithFormat:@"Unable to record voice: %@", [error localizedFailureReason]];
                    // jsString = [NSString stringWithFormat: @"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, VOICE_ERR_ABORTED];
                    jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_ABORTED message:errorMsg]];
                    [self.commandDelegate evalJs:jsString];
                    return;
                }
            }
            
            // create a new recorder for each start record
            voiceFile.recorder = [[CDVVoiceRecorder alloc] initWithURL:voiceFile.resourceURL settings:[CDVVoice getRecorderSettings] error:&error];
            
            bool recordingSuccess = NO;
            if (error == nil) {
                voiceFile.recorder.delegate = self;
                voiceFile.recorder.voiceId = voiceId;
                recordingSuccess = [voiceFile.recorder record];
                if (recordingSuccess) {
                    NSLog(@"Started recording audio sample '%@'", voiceFile.resourcePath);
                    jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_RUNNING];
                    [self.commandDelegate evalJs:jsString];
                }
            }
            
            if ((error != nil) || (recordingSuccess == NO)) {
                if (error != nil) {
                    errorMsg = [NSString stringWithFormat:@"Failed to initialize AVAudioRecorder: %@\n", [error localizedFailureReason]];
                } else {
                    errorMsg = @"Failed to start recording using AVAudioRecorder";
                }
                voiceFile.recorder = nil;
                if (self.avSession) {
                    [self.avSession setActive:NO error:nil];
                }
                jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_ABORTED message:errorMsg]];
                [self.commandDelegate evalJs:jsString];
            }
        };
        
        SEL rrpSel = NSSelectorFromString(@"requestRecordPermission:");
        if ([self hasSession] && [self.avSession respondsToSelector:rrpSel])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.avSession performSelector:rrpSel withObject:^(BOOL granted){
                if (granted) {
                    startRecording();
                } else {
                    NSString* msg = @"Error creating audio session, microphone permission denied.";
                    NSLog(@"%@", msg);
                    voiceFile.recorder = nil;
                    if (self.avSession) {
                        [self.avSession setActive:NO error:nil];
                    }
                    jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_ABORTED message:msg]];
                    [self.commandDelegate evalJs:jsString];
                }
            }];
#pragma clang diagnostic pop
        } else {
            startRecording();
        }
        
    } else {
        // file did not validate
        NSString* errorMsg = [NSString stringWithFormat:@"Could not record audio at '%@'", voiceFile.resourcePath];
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_ABORTED message:errorMsg]];
        [self.commandDelegate evalJs:jsString];
    }
    }];
}

- (void)stopRecording:(CDVInvokedUrlCommand*)command
{
    NSString* voiceId = [command.arguments objectAtIndex:0];
    
    [self.commandDelegate runInBackground:^{

    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    
    
    NSString* jsString = nil;

    if ((voiceFile != nil) && (voiceFile.recorder != nil)) {
        NSLog(@"Stopped recording voice '%@'", voiceFile.resourcePath);
        [voiceFile.recorder stop];
        [voiceFile wavToAmr];
        // no callback - that will happen in audioRecorderDidFinishRecording
    }
    // ignore if no media recording
    if (jsString) {
        [self.commandDelegate evalJs:jsString];
    }
    }];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder*)recorder successfully:(BOOL)flag
{
    NSLog(@"audioRecorderDidFinishRecording");
    
    CDVVoiceRecorder* aRecorder = (CDVVoiceRecorder*)recorder;
    NSString* voiceId = aRecorder.voiceId;
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    NSString* jsString = nil;

    if (voiceFile != nil) {
        NSLog(@"Finished recording voice '%@'", voiceFile.resourcePath);
    }
    if (flag) {

        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_STOPPED];
    } else {
        // jsString = [NSString stringWithFormat: @"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, VOICE_ERR_DECODE];
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_DECODE message:nil]];
    }
    if (self.avSession) {
        [self.avSession setActive:NO error:nil];
    }
    [self.commandDelegate evalJs:jsString];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag
{
    CDVVoicePlayer* aPlayer = (CDVVoicePlayer*)player;
    NSString* voiceId = aPlayer.voiceId;
    CDVVoiceFile* voiceFile = [[self voiceCache] objectForKey:voiceId];
    NSString* jsString = nil;

    if (voiceFile != nil) {
        NSLog(@"Finished playing voice '%@'", voiceFile.resourcePath);
    }
    if (flag) {
        voiceFile.player.currentTime = 0;
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_STATE, VOICE_STOPPED];
    } else {
        // jsString = [NSString stringWithFormat: @"%@(\"%@\",%d,%d);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, VOICE_ERR_DECODE];
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('com.luhuiguo.cordova.voice.Voice').onStatus", voiceId, VOICE_ERROR, [self createVoiceErrorWithCode:VOICE_ERR_DECODE message:nil]];
    }
    if (self.avSession) {
        [self.avSession setActive:NO error:nil];
    }
    [self.commandDelegate evalJs:jsString];
}

- (void)onMemoryWarning
{
    [[self voiceCache] removeAllObjects];
    [self setVoiceCache:nil];
    [self setAvSession:nil];

    [super onMemoryWarning];
}

- (void)dealloc
{
    [[self voiceCache] removeAllObjects];
}

- (void)onReset
{
    for (CDVVoiceFile* voiceFile in [[self voiceCache] allValues]) {
        if (voiceFile != nil) {
            if (voiceFile.player != nil) {
                [voiceFile.player stop];
                voiceFile.player.currentTime = 0;
            }
            if (voiceFile.recorder != nil) {
                [voiceFile.recorder stop];
            }
        }
    }

    [[self voiceCache] removeAllObjects];
}

+ (NSDictionary*)getRecorderSettings
{
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: 8000.0],AVSampleRateKey, //采样率
                                   [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
                                   [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,//采样位数 默认 16
                                   [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,//通道的数目
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,//大端还是小端 是内存的组织方式
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,//采样信号是整数还是浮点数
                                   //                                   [NSNumber numberWithInt: AVAudioQualityMedium],AVEncoderAudioQualityKey,//音频编码质量
                                   nil];
    return settings;
}


@end

@implementation CDVVoiceFile

@synthesize resourcePath;
@synthesize wavFilePath;
@synthesize amrFilePath;
@synthesize resourceURL;
@synthesize player, volume;
@synthesize recorder;

- (int)amrToWav
{
    NSFileManager* fMgr = [[NSFileManager alloc] init];
    if (![fMgr fileExistsAtPath:wavFilePath]) {
        if (! DecodeAMRFileToWAVEFile([amrFilePath cStringUsingEncoding:NSUTF8StringEncoding], [wavFilePath cStringUsingEncoding:NSUTF8StringEncoding])){
            return 0;
        }
        
    }
    

    return 1;
}

- (int)wavToAmr
{
    NSFileManager* fMgr = [[NSFileManager alloc] init];
    if (![fMgr fileExistsAtPath:amrFilePath]) {
        if (EncodeWAVEFileToAMRFile([wavFilePath cStringUsingEncoding:NSUTF8StringEncoding], [amrFilePath cStringUsingEncoding:NSUTF8StringEncoding], 1, 16)){
            return 0;
        }
    }
    return 1;
}

@end
@implementation CDVVoicePlayer
@synthesize voiceId;

@end

@implementation CDVVoiceRecorder
@synthesize voiceId;

@end
