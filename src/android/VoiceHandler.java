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
package com.luhuiguo.cordova.voice;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaResourceApi;

import android.content.Context;
import android.media.AudioManager;
import android.net.Uri;

import java.util.ArrayList;

import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import java.util.HashMap;

/**
 * This class called by CordovaActivity to play and record voice.
 * The file can be local or over a network using http.
 *
 */
public class VoiceHandler extends CordovaPlugin {

    public static String TAG = "VoiceHandler";
    HashMap<String, VoicePlayer> players;	// Audio player object
    ArrayList<VoicePlayer> pausedForPhone;     // Audio players that were paused when phone call came in

    /**
     * Constructor.
     */
    public AudioHandler() {
        this.players = new HashMap<String, VoicePlayer>();
        this.pausedForPhone = new ArrayList<VoicePlayer>();
    }

    /**
     * Executes the request and returns PluginResult.
     * @param action 		The action to execute.
     * @param args 			JSONArry of arguments for the plugin.
     * @param callbackContext		The callback context used when calling back into JavaScript.
     * @return 				A PluginResult object with a status and message.
     */
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        CordovaResourceApi resourceApi = webView.getResourceApi();
        PluginResult.Status status = PluginResult.Status.OK;
        String result = "";

        if (action.equals("startRecording")) {
            String target = args.getString(1);
            String fileUriStr;
            try {
                Uri targetUri = resourceApi.remapUri(Uri.parse(target));
                fileUriStr = targetUri.toString();
            } catch (IllegalArgumentException e) {
                fileUriStr = target;
            }
            this.startRecording(args.getString(0), VoiceHandler.stripFileProtocol(fileUriStr));
        }
        else if (action.equals("stopRecording")) {
            this.stopRecordingAudio(args.getString(0));
        }
        else if (action.equals("startPlaying")) {
            String target = args.getString(1);
            String fileUriStr;
            try {
                Uri targetUri = resourceApi.remapUri(Uri.parse(target));
                fileUriStr = targetUri.toString();
            } catch (IllegalArgumentException e) {
                fileUriStr = target;
            }
            this.startPlaying(args.getString(0), VoiceHandler.stripFileProtocol(fileUriStr));
        }
        else if (action.equals("seekTo")) {
            this.seekTo(args.getString(0), args.getInt(1));
        }
        else if (action.equals("pausePlaying")) {
            this.pausePlaying(args.getString(0));
        }
        else if (action.equals("stopPlaying")) {
            this.stopPlaying(args.getString(0));
        } else if (action.equals("setVolume")) {
           try {
               this.setVolume(args.getString(0), Float.parseFloat(args.getString(1)));
           } catch (NumberFormatException nfe) {
               //no-op
           }
        } else if (action.equals("getCurrentPosition")) {
            float f = this.getCurrentPosition(args.getString(0));
            callbackContext.sendPluginResult(new PluginResult(status, f));
            return true;
        }
        else if (action.equals("getDuration")) {
            float f = this.getDuration(args.getString(0), args.getString(1));
            callbackContext.sendPluginResult(new PluginResult(status, f));
            return true;
        }
        else if (action.equals("create")) {
            String id = args.getString(0);
            String src = VoiceHandler.stripFileProtocol(args.getString(1));
            VoicePlayer voice = new VoicePlayer(this, id, src);
            this.players.put(id, voice);
        }
        else if (action.equals("release")) {
            boolean b = this.release(args.getString(0));
            callbackContext.sendPluginResult(new PluginResult(status, b));
            return true;
        }
        else { // Unrecognized action.
            return false;
        }

        callbackContext.sendPluginResult(new PluginResult(status, result));

        return true;
    }

    /**
     * Stop all voice players and recorders.
     */
    public void onDestroy() {
        for (VoicePlayer voice : this.players.values()) {
            voice.destroy();
        }
        this.players.clear();
    }

    /**
     * Stop all voice players and recorders on navigate.
     */
    @Override
    public void onReset() {
        onDestroy();
    }

    /**
     * Called when a message is sent to plugin.
     *
     * @param id            The message id
     * @param data          The message data
     * @return              Object to stop propagation or null
     */
    public Object onMessage(String id, Object data) {

        // If phone message
        if (id.equals("telephone")) {

            // If phone ringing, then pause playing
            if ("ringing".equals(data) || "offhook".equals(data)) {

                // Get all voice players and pause them
                for (VoicePlayer voice : this.players.values()) {
                    if (voice.getState() == VoicePlayer.STATE.VOICE_RUNNING.ordinal()) {
                        this.pausedForPhone.add(voice);
                        voice.pausePlaying();
                    }
                }

            }

            // If phone idle, then resume playing those players we paused
            else if ("idle".equals(data)) {
                for (VoicePlayer voice : this.pausedForPhone) {
                    voice.startPlaying(null);
                }
                this.pausedForPhone.clear();
            }
        }
        return null;
    }

    //--------------------------------------------------------------------------
    // LOCAL METHODS
    //--------------------------------------------------------------------------

    /**
     * Release the voice player instance to save memory.
     * @param id				The id of the voice player
     */
    private boolean release(String id) {
        if (!this.players.containsKey(id)) {
            return false;
        }
        VoicePlayer voice = this.players.get(id);
        this.players.remove(id);
        voice.destroy();
        return true;
    }

    /**
     * Start recording and save the specified file.
     * @param id				The id of the voice player
     * @param file				The name of the file
     */
    public void startRecording(String id, String file) {
        VoicePlayer voice = this.players.get(id);
        if ( voice == null) {
            voice = new VoicePlayer(this, id, file);
            this.players.put(id, voice);
        }
        voice.startRecording(file);
    }

    /**
     * Stop recording and save to the file specified when recording started.
     * @param id				The id of the voice player
     */
    public void stopRecording(String id) {
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            voice.stopRecording();
        }
    }

    /**
     * Start or resume playing voice file.
     * @param id				The id of the voice player
     * @param file				The name of the voice file.
     */
    public void startPlaying(String id, String file) {
        VoicePlayer voice = this.players.get(id);
        if (voice == null) {
            voice = new VoicePlayer(this, id, file);
            this.players.put(id, voice);
        }
        voice.startPlaying(file);
    }

    /**
     * Seek to a location.
     * @param id				The id of the voice player
     * @param milliseconds		int: number of milliseconds to skip 1000 = 1 second
     */
    public void seekTo(String id, int milliseconds) {
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            voice.seekToPlaying(milliseconds);
        }
    }

    /**
     * Pause playing.
     * @param id				The id of the voice player
     */
    public void pausePlaying(String id) {
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            voice.pausePlaying();
        }
    }

    /**
     * Stop playing the voice file.
     * @param id				The id of the voice player
     */
    public void stopPlaying(String id) {
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            voice.stopPlaying();
            //voice.destroy();
            //this.players.remove(id);
        }
    }

    /**
     * Get current position of playback.
     * @param id				The id of the voice player
     * @return 					position in msec
     */
    public float getCurrentPosition(String id) {
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            return (voice.getCurrentPosition() / 1000.0f);
        }
        return -1;
    }

    /**
     * Get the duration of the voice file.
     * @param id				The id of the voice player
     * @param file				The name of the voice file.
     * @return					The duration in msec.
     */
    public float getDuration(String id, String file) {

        // Get voice file
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            return (voice.getDuration(file));
        }

        // If not already open, then open the file
        else {
            voice = new VoicePlayer(this, id, file);
            this.players.put(id, voice);
            return (voice.getDuration(file));
        }
    }

    /**
     * Set the voice device to be used for playback.
     *
     * @param output			1=earpiece, 2=speaker
     */
    @SuppressWarnings("deprecation")
    public void setVoiceOutputDevice(int output) {
        AudioManager audiMgr = (AudioManager) this.cordova.getActivity().getSystemService(Context.AUDIO_SERVICE);
        if (output == 2) {
            audiMgr.setSpeakerphoneOn(true);
        }
        else if (output == 1) {
            audiMgr.setSpeakerphoneOn(false);
         }
        else {
            System.out.println("VoiceHandler.setVoiceOutputDevice() Error: Unknown output device.");
        }
    }

    /**
     * Get the voice device to be used for playback.
     *
     * @return					1=earpiece, 2=speaker
     */
    public int getVoiceOutputDevice() {
        AudioManager audiMgr = (AudioManager) this.cordova.getActivity().getSystemService(Context.AUDIO_SERVICE);
        if (audiMgr.isSpeakerphoneOn()) {
            return 2;
        }
        else {
            return 1;
        }
    }

    /**
     * Set the volume for an voice device
     *
     * @param id				The id of the audio player
     * @param volume            Volume to adjust to 0.0f - 1.0f
     */
    public void setVolume(String id, float volume) {
        VoicePlayer voice = this.players.get(id);
        if (voice != null) {
            voice.setVolume(volume);
        } else {
            System.out.println("VoiceHandler.setVolume() Error: Unknown Voice Player " + id);
        }
    }

    /**
     * Removes the "file://" prefix from the given URI string, if applicable.
     * If the given URI string doesn't have a "file://" prefix, it is returned unchanged.
     *
     * @param uriString the URI string to operate on
     * @return a path without the "file://" prefix
     */
    public static String stripFileProtocol(String uriString) {
        if (uriString.startsWith("file://")) {
            return Uri.parse(uriString).getPath();
        }
        return uriString;
    }
}
