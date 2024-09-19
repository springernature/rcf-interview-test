package {
import com.adobe.audio.format.WAVWriter;

import flash.display.LoaderInfo;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.SampleDataEvent;
import flash.events.StatusEvent;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import flash.media.Microphone;
import flash.media.Sound;
import flash.media.SoundChannel;
import flash.system.Security;
import flash.system.SecurityPanel;
import flash.utils.ByteArray;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;
import flash.utils.getTimer;

import ru.inspirit.net.MultipartURLLoader;

public class Recorder extends Sprite {
	protected static var sampleRate:Number = 44.1;

	public function Recorder() {
		this.logger = {
			log: function (msg:String):void {
				//ExternalInterface.call("console.log", msg);
				trace(msg);
			}
		};
		this.flashVars = LoaderInfo(this.root.loaderInfo).parameters;
		addExternalInterfaceCallbacks();
	}
	protected var isRecording:Boolean = false;
	protected var isPlaying:Boolean = false;
	protected var microphoneWasMuted:Boolean;
	protected var playingProgressTimer:Timer;
	protected var microphone:Microphone;
	protected var buffer:ByteArray = new ByteArray();
	protected var sound:Sound;
	protected var channel:SoundChannel;
	protected var recordingStartTime:Number = 0;
	protected var flashVars:Object;
	private var logger:Object;

	public function addExternalInterfaceCallbacks():void {

		ExternalInterface.marshallExceptions = true;
		if (ExternalInterface.available) {

			ExternalInterface.addCallback("record", this.record);
			ExternalInterface.addCallback("_stop", this.stop);
			ExternalInterface.addCallback("_play", this.play);
			ExternalInterface.addCallback("upload", this.upload);
			ExternalInterface.addCallback("audioData", this.audioData);
			ExternalInterface.addCallback("showFlash", this.showFlash);
			ExternalInterface.addCallback("recordingDuration", this.recordingDuration);
			ExternalInterface.addCallback("playDuration", this.playDuration);

			triggerEvent('initialized', {});
			logger.log("Recorder initialized");
		}
	}

	protected function record():void {
		if (!microphone) {
			setupMicrophone();
		}

		microphoneWasMuted = microphone.muted;
		if (microphoneWasMuted) {
			logger.log('showFlashRequired');
			triggerEvent('showFlash', '');
		} else {
			notifyRecordingStarted();
		}

		buffer = new ByteArray();
		microphone.addEventListener(SampleDataEvent.SAMPLE_DATA, recordSampleDataHandler);
	}

	protected function recordStop():int {
		logger.log('stopRecording');
		isRecording = false;
		triggerEvent('recordingStop', {duration: recordingDuration()});
		logger.log('recordingStop duration: ' + recordingDuration());
		microphone.removeEventListener(SampleDataEvent.SAMPLE_DATA, recordSampleDataHandler);
		return recordingDuration();
	}

	protected function play():void {
		logger.log('startPlaying');
		isPlaying = true;
		triggerEvent('playingStart', {});
		buffer.position = 0;
		sound = new Sound();
		sound.addEventListener(SampleDataEvent.SAMPLE_DATA, playSampleDataHandler);

		channel = sound.play();
		channel.addEventListener(Event.SOUND_COMPLETE, function (e:Event):void {
			playStop();
		});

		if (playingProgressTimer) {
			playingProgressTimer.reset();
		}
		playingProgressTimer = new Timer(250);
		var _this:Recorder = this;
		playingProgressTimer.addEventListener(TimerEvent.TIMER, function playingProgressTimerHandler(event:TimerEvent):void {
			triggerEvent('playingProgress', _this.playDuration());
		});
		playingProgressTimer.start();
	}

	protected function stop():int {
		if (isPlaying) {
			playStop();
			return this.playDuration();
		}
		if (isRecording) {
			return recordStop();
		}
		return 0;
	}

	protected function playStop():void {
		logger.log('stopPlaying');
		if (channel) {
			channel.stop();
			playingProgressTimer.reset();

			triggerEvent('playingStop', {});
			isPlaying = false;
		}
	}

	/* Networking functions */

	protected function upload(uri:String, audioParam:String, parameters:Array):void {
		logger.log("upload");
		buffer.position = 0;
		var wav:ByteArray = prepareWav();
		var ml:MultipartURLLoader = new MultipartURLLoader();
		ml.addEventListener(Event.COMPLETE, onReady);
		function onReady(e:Event):void {
			triggerEvent('uploadSuccess', externalInterfaceEncode(e.target.loader.data));
			logger.log('uploading done');
		}

		if (getQualifiedClassName(parameters.constructor) == "Array") {
			for (var i:Number = 0; i < parameters.length; i++) {
				ml.addVariable(parameters[i][0], parameters[i][1]);
			}
		} else {
			for (var k:String in parameters) {
				ml.addVariable(k, parameters[k]);
			}
		}

		ml.addFile(wav, 'audio.wav', audioParam);
		ml.load(uri, false);

	}

	protected function audioData(newData:String = null):String {
		var delimiter:String = ";";
		if (newData) {
			buffer = new ByteArray();
			var splittedData:Array = newData.split(delimiter);
			for (var i:Number = 0; i < splittedData.length; i++) {
				buffer.writeFloat(parseFloat(splittedData[i]));
			}
			return "";
		} else {
			var ret:String = "";
			buffer.position = 0;
			while (buffer.bytesAvailable > 0) {
				ret += buffer.readFloat().toString() + delimiter;
			}
			return ret;
		}
	}

	protected function showFlash():void {
		Security.showSettings(SecurityPanel.PRIVACY);
		triggerEvent('showFlash', '');
	}

	protected function setupMicrophone():void {
		logger.log('setupMicrophone');
		microphone = Microphone.getMicrophone();
		microphone.codec = "Nellymoser";
		microphone.setSilenceLevel(0);
		microphone.rate = sampleRate;
		microphone.gain = 50;
		microphone.addEventListener(StatusEvent.STATUS, function statusHandler(e:Event):void {
			logger.log('Microphone Status Change');
			if (microphone.muted) {
				triggerEvent('recordingCancel', '');
			} else {
				if (!isRecording) {
					notifyRecordingStarted();
				}
			}
		});

		logger.log('setupMicrophone done: ' + microphone.name + ' ' + microphone.muted);
	}

	/* Recording Helper */

	protected function notifyRecordingStarted():void {
		if (microphoneWasMuted) {
			microphoneWasMuted = false;
			triggerEvent('_defaultOnHideFlash', '');
		}
		recordingStartTime = getTimer();
		triggerEvent('recordingStart', {});
		logger.log('startRecording');
		isRecording = true;
	}

	protected function prepareWav():ByteArray {
		var wavData:ByteArray = new ByteArray();
		var wavWriter:WAVWriter = new WAVWriter();
		buffer.position = 0;
		wavWriter.numOfChannels = 1; // set the inital properties of the Wave Writer
		wavWriter.sampleBitRate = 16;
		wavWriter.samplingRate = sampleRate * 1000;
		wavWriter.processSamples(wavData, buffer, sampleRate * 1000, 1);
		return wavData;
	}

	/* Sample related */

	protected function recordingDuration():int {
		var duration:Number = int(getTimer() - recordingStartTime);
		return Math.max(duration, 0);
	}

	protected function playDuration():int {
		return int(channel.position);
	}

	protected function triggerEvent(eventName:String, arg0, arg1 = null):void {
		if (ExternalInterface.available) {
			try {
				logger.log("Calling window." + this.flashVars.globalVariable + "[" + this.flashVars.index + "].triggerEvent("+eventName+")");
				ExternalInterface.call("window." + this.flashVars.globalVariable + "[" + this.flashVars.index + "].triggerEvent", eventName, arg0, arg1);
			} catch (e:Error) {
				logger.log(e) ;
			} catch (e:SecurityError) {
				logger.log(e);
			}
		}
	}

	private function externalInterfaceEncode(data:String):String {
		return data.split("%").join("%25").split("\\").join("%5c").split("\"").join("%22").split("&").join("%26");
	}

	protected function recordSampleDataHandler(event:SampleDataEvent):void {
		while (event.data.bytesAvailable) {
			var sample:Number = event.data.readFloat();

			buffer.writeFloat(sample);
			if (buffer.length % 40000 == 0) {
				triggerEvent('recordingProgress', recordingDuration(), microphone.activityLevel);
			}
		}
	}

	/* ExternalInterface Communication */

	protected function playSampleDataHandler(event:SampleDataEvent):void {
		var expectedSampleRate:Number = 44.1;
		var writtenSamples:Number = 0;
		var channels:Number = 2;
		var maxSamples:Number = 8192 * channels;
		// if the sampleRate doesn't match the expectedSampleRate of flash.media.Sound (44.1) write the sample multiple times
		// this will result in a little down pitchshift.
		// also write 2 times for stereo channels
		while (writtenSamples < maxSamples && buffer.bytesAvailable) {
			var sample:Number = buffer.readFloat();
			for (var j:int = 0; j < channels * (expectedSampleRate / sampleRate); j++) {
				event.data.writeFloat(sample);
				writtenSamples++;
				if (writtenSamples >= maxSamples) {
					break;
				}
			}
		}
		logger.log("Wrote " + writtenSamples + " samples");
	}
}
}
