/* -LICENSE-START-
 ** Copyright (c) 2011 Blackmagic Design
 **
 ** Permission is hereby granted, free of charge, to any person or organization
 ** obtaining a copy of the software and accompanying documentation covered by
 ** this license (the "Software") to use, reproduce, display, distribute,
 ** execute, and transmit the Software, and to prepare derivative works of the
 ** Software, and to permit third-parties to whom the Software is furnished to
 ** do so, all subject to the following:
 **
 ** The copyright notices in the Software and this entire statement, including
 ** the above license grant, this restriction and the following disclaimer,
 ** must be included in all copies of the Software, in whole or in part, and
 ** all derivative works of the Software, unless such copies or derivative
 ** works are solely in the form of machine-executable object code generated by
 ** a source language processor.
 **
 ** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 ** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 ** FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
 ** SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
 ** FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
 ** ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 ** DEALINGS IN THE SOFTWARE.
 ** -LICENSE-END-
 */

#import "AppDelegate.h"
#include <libkern/OSAtomic.h>
#import "OSCAddressPanel.h"
#import "SettingsWindow.h"
#import "OSCReceiver.h"

@implementation AppDelegate

@synthesize window;
@synthesize isConnectedToATEM;
@synthesize mMixEffectBlock;
@synthesize mMixEffectBlockMonitor;
@synthesize keyers;
@synthesize dsk;
@synthesize switcherTransitionParameters;
@synthesize mMediaPool;
@synthesize mMediaPlayers;
@synthesize mMacroPool;
@synthesize mSuperSource;
@synthesize mMacroControl;
@synthesize mSuperSourceBoxes;
@synthesize mInputs;
@synthesize mInputMonitors;
@synthesize mSwitcherInputAuxList;

@synthesize mAudioInputs;
@synthesize mAudioInputMonitors;
@synthesize mAudioMixer;
@synthesize mAudioMixerMonitor;

@synthesize mFairlightAudioSources;
@synthesize mFairlightAudioSourceMonitors;
@synthesize mFairlightAudioMixer;
@synthesize mFairlightAudioMixerMonitor;

@synthesize outPort;
@synthesize inPort;
@synthesize mSwitcher;
@synthesize mHyperdecks;
@synthesize mHyperdeckMonitors;
@synthesize endpoints;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self setupMenu];
	
	mSwitcherDiscovery = NULL;
	mSwitcher = NULL;
	mMixEffectBlock = NULL;
	mMediaPool = NULL;
	mMacroPool = NULL;
	mSuperSource = NULL;
	mMacroControl = NULL;
	mAudioMixer = NULL;
	
	isConnectedToATEM = NO;
	
	endpoints = [[NSMutableArray alloc] init];
	mOscReceiver = [[OSCReceiver alloc] initWithDelegate:self];
	
	
	[logTextView setTextColor:[NSColor whiteColor]];
	
	[(SettingsWindow *)window loadSettingsFromPreferences];
	
	mSwitcherDiscovery = CreateBMDSwitcherDiscoveryInstance();
	if (!mSwitcherDiscovery)
	{
		NSBeginAlertSheet(@"Could not create Switcher Discovery Instance.\nATEM Switcher Software may not be installed.\n",
						  @"OK", nil, nil, window, self, @selector(sheetDidEndShouldTerminate:returnCode:contextInfo:), NULL, window, @"");
	}
	else
	{
		[self switcherDisconnected];		// start with switcher disconnected
		
		manager = [[OSCManager alloc] init];
		[manager setDelegate:mOscReceiver];
		
		NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

		int incomingPort = 3333, outgoingPort = 4444;
		NSString *outIpStr = nil;
		if ([prefs integerForKey:@"outgoing"])
			outgoingPort = (int) [prefs integerForKey:@"outgoing"];
		if ([prefs integerForKey:@"incoming"])
			incomingPort = (int) [prefs integerForKey:@"incoming"];
		if ([prefs stringForKey:@"oscdevice"])
			outIpStr = [prefs stringForKey:@"oscdevice"];

		[self portChanged:incomingPort out:outgoingPort ip:outIpStr];
	}
	
	[self checkForUpdate];
}

- (void)setupMenu
{
	NSMenu* edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
	if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"orderFrontCharacterPalette:"))
		[edit removeItemAtIndex: [edit numberOfItems] - 1];
	if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"startDictation:"))
		[edit removeItemAtIndex: [edit numberOfItems] - 1];
	if ([[edit itemAtIndex: [edit numberOfItems] - 1] isSeparatorItem])
		[edit removeItemAtIndex: [edit numberOfItems] - 1];
}

- (void)setupMonitors
{
	mSwitcherMonitor = new SwitcherMonitor(self);
	mMonitors.push_back(mSwitcherMonitor);
	mDownstreamKeyerMonitor = new DownstreamKeyerMonitor(self);
	mMonitors.push_back(mDownstreamKeyerMonitor);
	mUpstreamKeyerMonitor = new UpstreamKeyerMonitor(self);
	mMonitors.push_back(mUpstreamKeyerMonitor);
	mUpstreamKeyerLumaParametersMonitor = new UpstreamKeyerLumaParametersMonitor(self);
	mMonitors.push_back(mUpstreamKeyerLumaParametersMonitor);
	mUpstreamKeyerChromaParametersMonitor = new UpstreamKeyerChromaParametersMonitor(self);
	mMonitors.push_back(mUpstreamKeyerChromaParametersMonitor);
	mTransitionParametersMonitor = new TransitionParametersMonitor(self);
	mMonitors.push_back(mTransitionParametersMonitor);
	mMixEffectBlockMonitor = new MixEffectBlockMonitor(self);
	mMonitors.push_back(mMixEffectBlockMonitor);
	mMacroPoolMonitor = new MacroPoolMonitor(self);
	mMonitors.push_back(mMacroPoolMonitor);
	mAudioMixerMonitor = new AudioMixerMonitor(self);
	mMonitors.push_back(mAudioMixerMonitor);
	mFairlightAudioMixerMonitor = new FairlightAudioMixerMonitor(self);
	mMonitors.push_back(mFairlightAudioMixerMonitor);
}

- (void)checkForUpdate
{
	// Check if new version available
	NSError *error = nil;
	NSString *url_string = [NSString stringWithFormat: @"https://api.github.com/repos/danielbuechele/atemOSC/releases/latest"];
	NSData *data = [NSData dataWithContentsOfURL: [NSURL URLWithString:url_string]];
	if (!error) {
		NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
		NSString *availableVersion = [[json objectForKey:@"name"] stringByReplacingOccurrencesOfString:@"v" withString:@""];
		NSString *installedVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSLog(@"version available: %@", availableVersion);
		NSLog(@"version installed: %@", installedVersion);
		if (![availableVersion isEqualToString:installedVersion])
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"New Version Available"];
			[alert setInformativeText:@"There is a new version of AtemOSC available!"];
			[alert addButtonWithTitle:@"Go to Download"];
			[alert addButtonWithTitle:@"Skip"];
			[alert beginSheetModalForWindow:[(AppDelegate *)[[NSApplication sharedApplication] delegate] window] completionHandler:^(NSInteger returnCode)
			 {
				 if ( returnCode == NSAlertFirstButtonReturn )
				 {
					 [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/danielbuechele/atemOSC/releases/latest"]];
				 }
			 }];
		}
	}
}

- (void)portChanged:(int)inPortValue out:(int)outPortValue ip:(NSString *)outIpStr
{
	if (inPort == nil)
		inPort = [manager createNewInputForPort:inPortValue withLabel:@"atemOSC"];
	else if (inPortValue != [inPort port])
		[inPort setPort:inPortValue];
	
	if (outPort == nil)
		outPort = [manager createNewOutputToAddress:outIpStr atPort:outPortValue withLabel:@"atemOSC"];
	else
	{
		if (![outIpStr isEqualToString: [outPort addressString]])
			[outPort setAddressString:outIpStr];
		if (outPortValue != [outPort port])
			[outPort setPort:outPortValue];
	}
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
	[self cleanUpConnection];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
	return YES;
}

- (void)sheetDidEndShouldTerminate:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[NSApp terminate:self];
}

- (IBAction)githubPageButtonPressed:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/danielbuechele/atemOSC/"]];
}

- (void)connectBMD
{
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString* address = [(SettingsWindow *)window switcherAddress];
		
		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
		dispatch_async(queue, ^{
			
			BMDSwitcherConnectToFailure            failReason;
			
			// Note that ConnectTo() can take several seconds to return, both for success or failure,
			// depending upon hostname resolution and network response times, so it may be best to
			// do this in a separate thread to prevent the main GUI thread blocking.
			HRESULT hr = mSwitcherDiscovery->ConnectTo((CFStringRef)address, &mSwitcher, &failReason);
			if (SUCCEEDED(hr))
			{
				[self switcherConnected];
			}
			else
			{
				NSString* reason;
				switch (failReason)
				{
					case bmdSwitcherConnectToFailureNoResponse:
						reason = @"No response from Switcher";
						break;
					case bmdSwitcherConnectToFailureIncompatibleFirmware:
						reason = @"Switcher has incompatible firmware";
						break;
					case bmdSwitcherConnectToFailureCorruptData:
						reason = @"Corrupt data was received during connection attempt";
						break;
					case bmdSwitcherConnectToFailureStateSync:
						reason = @"State synchronisation failed during connection attempt";
						break;
					case bmdSwitcherConnectToFailureStateSyncTimedOut:
						reason = @"State synchronisation timed out during connection attempt";
						break;
					default:
						reason = @"Connection failed for unknown reason";
				}
				//Delay 2 seconds before everytime connect/reconnect
				//Because the session ID from ATEM switcher will alive not more then 2 seconds
				//After 2 second of idle, the session will be reset then reconnect won't cause error
				double delayInSeconds = 2.0;
				dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
				dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
							   ^(void){
								   //To run in background thread
								   [self switcherDisconnected];
							   });
				[self logMessage:[NSString stringWithFormat:@"%@", reason]];
			}
		});
	});
}

- (void)switcherConnected
{
	HRESULT result;

	isConnectedToATEM = YES;
	
	if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)])
	{
		self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:0x00FFFFFF reason:@"receiving OSC messages"];
	}
	
	[self setupMonitors];
	
	OSCMessage *newMsg = [OSCMessage createWithAddress:@"/atem/led/green"];
	[newMsg addFloat:1.0];
	[outPort sendThisMessage:newMsg];
	newMsg = [OSCMessage createWithAddress:@"/atem/led/red"];
	[newMsg addFloat:0.0];
	[outPort sendThisMessage:newMsg];
	
	NSString* productName = @"N/A";
	if (FAILED(mSwitcher->GetProductName((CFStringRef*)&productName)))
	{
		[self logMessage:@"Could not get switcher product name"];
	}
	
	[(SettingsWindow *)window showSwitcherConnected:productName];
	
	mSwitcher->AddCallback(mSwitcherMonitor);
	
	// Get the mix effect block iterator
	IBMDSwitcherMixEffectBlockIterator* iterator = NULL;
	if (SUCCEEDED(mSwitcher->CreateIterator(IID_IBMDSwitcherMixEffectBlockIterator, (void**)&iterator)))
	{
		// Use the first Mix Effect Block
		if (S_OK == iterator->Next(&mMixEffectBlock))
		{
			mMixEffectBlock->AddCallback(mMixEffectBlockMonitor);
			mMixEffectBlockMonitor->updateSliderPosition();
			
			if (SUCCEEDED(mMixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionParameters, (void**)&switcherTransitionParameters)))
			{
				switcherTransitionParameters->AddCallback(mTransitionParametersMonitor);
			}
			else
			{
				[self logMessage:@"Could not get IBMDSwitcherTransitionParameters"];
			}
			
		}
		else
		{
			[self logMessage:@"Could not get the first IBMDSwitcherMixEffectBlock"];
		}
		
		iterator->Release();
	}
	else
	{
		[self logMessage:@"Could not create IBMDSwitcherMixEffectBlockIterator iterator"];
	}
	
	
	// Create an InputMonitor for each input so we can catch any changes to input names
	IBMDSwitcherInputIterator* inputIterator = NULL;
	if (SUCCEEDED(mSwitcher->CreateIterator(IID_IBMDSwitcherInputIterator, (void**)&inputIterator)))
	{
		IBMDSwitcherInput* input = NULL;
		
		// For every input, install a callback to monitor property changes on the input
		while (S_OK == inputIterator->Next(&input))
		{
			BMDSwitcherInputId inputId;
			input->GetInputId(&inputId);
			mInputs.insert(std::make_pair(inputId, input));
			InputMonitor *monitor = new InputMonitor(self, inputId);
			input->AddCallback(monitor);
			mMonitors.push_back(monitor);
			mInputMonitors.insert(std::make_pair(inputId, monitor));
			
			IBMDSwitcherInputAux* auxObj;
			result = input->QueryInterface(IID_IBMDSwitcherInputAux, (void**)&auxObj);
			if (SUCCEEDED(result))
			{
				BMDSwitcherInputId auxId;
				result = auxObj->GetInputSource(&auxId);
				if (SUCCEEDED(result))
				{
					mSwitcherInputAuxList.push_back(auxObj);
				}
			}
		}
		inputIterator->Release();
		inputIterator = NULL;
	}
	else
	{
		[self logMessage:@"Could not create IBMDSwitcherInputIterator iterator"];
	}
	
	
	//Upstream Keyer
	IBMDSwitcherKeyIterator* keyIterator = NULL;
	IBMDSwitcherKey* key = NULL;
	if (SUCCEEDED(mMixEffectBlock->CreateIterator(IID_IBMDSwitcherKeyIterator, (void**)&keyIterator)))
	{
		while (S_OK == keyIterator->Next(&key))
		{
			keyers.push_back(key);
			key->AddCallback(mUpstreamKeyerMonitor);
			
			IBMDSwitcherKeyLumaParameters* lumaParams;
			if (SUCCEEDED(key->QueryInterface(IID_IBMDSwitcherKeyLumaParameters, (void**)&lumaParams)))
				lumaParams->AddCallback(mUpstreamKeyerLumaParametersMonitor);
			
			IBMDSwitcherKeyChromaParameters* chromaParams;
			if (SUCCEEDED(key->QueryInterface(IID_IBMDSwitcherKeyChromaParameters, (void**)&chromaParams)))
				chromaParams->AddCallback(mUpstreamKeyerChromaParametersMonitor);
		}
		keyIterator->Release();
		keyIterator = NULL;
	}
	else
	{
		[self logMessage:@"Could not create IBMDSwitcherKeyIterator iterator"];
	}
	
	
	//Downstream Keyer
	IBMDSwitcherDownstreamKeyIterator* dskIterator = NULL;
	IBMDSwitcherDownstreamKey* downstreamKey = NULL;
	if (SUCCEEDED(mSwitcher->CreateIterator(IID_IBMDSwitcherDownstreamKeyIterator, (void**)&dskIterator)))
	{
		while (S_OK == dskIterator->Next(&downstreamKey))
		{
			dsk.push_back(downstreamKey);
			downstreamKey->AddCallback(mDownstreamKeyerMonitor);
		}
		dskIterator->Release();
		dskIterator = NULL;
	}
	else
	{
		[self logMessage:@"Could not create IBMDSwitcherDownstreamKeyIterator iterator"];
	}
	
	// Media Players
	IBMDSwitcherMediaPlayerIterator* mediaPlayerIterator = NULL;
	if (SUCCEEDED(mSwitcher->CreateIterator(IID_IBMDSwitcherMediaPlayerIterator, (void**)&mediaPlayerIterator)))
	{
		IBMDSwitcherMediaPlayer* mediaPlayer = NULL;
		while (S_OK == mediaPlayerIterator->Next(&mediaPlayer))
		{
			mMediaPlayers.push_back(mediaPlayer);
		}
		mediaPlayerIterator->Release();
		mediaPlayerIterator = NULL;
	}
	else
	{
		[self logMessage:@"Could not create IBMDSwitcherMediaPlayerIterator iterator"];
	}
	
	// get media pool
	if (FAILED(mSwitcher->QueryInterface(IID_IBMDSwitcherMediaPool, (void**)&mMediaPool)))
	{
		[self logMessage:@"Could not get IBMDSwitcherMediaPool interface"];
	}
	
	// get macro pool
	if (SUCCEEDED(mSwitcher->QueryInterface(IID_IBMDSwitcherMacroPool, (void**)&mMacroPool)))
	{
		mMacroPool->AddCallback(mMacroPoolMonitor);
	}
	else
	{
		[self logMessage:@"Could not get IID_IBMDSwitcherMacroPool interface"];
	}
	
	// get macro controller
	if (FAILED(mSwitcher->QueryInterface(IID_IBMDSwitcherMacroControl, (void**)&mMacroControl)))
	{
		[self logMessage:@"Could not get IID_IBMDSwitcherMacroControl interface"];
	}
	
	// Super source
	if (SUCCEEDED(mSwitcher->CreateIterator(IID_IBMDSwitcherInputSuperSource, (void**)&mSuperSource))) {
		IBMDSwitcherSuperSourceBoxIterator* superSourceIterator = NULL;
		if (SUCCEEDED(mSuperSource->CreateIterator(IID_IBMDSwitcherSuperSourceBoxIterator, (void**)&superSourceIterator)))
		{
			IBMDSwitcherSuperSourceBox* superSourceBox = NULL;
			while (S_OK == superSourceIterator->Next(&superSourceBox))
			{
				mSuperSourceBoxes.push_back(superSourceBox);
			}
			superSourceIterator->Release();
			superSourceIterator = NULL;
		}
		else
		{
			[self logMessage:@"Could not create IBMDSwitcherSuperSourceBoxIterator iterator"];
		}
	}
	else
	{
		[self logMessage:@"Could not get IBMDSwitcherInputSuperSource interface"];
	}
	
	// Audio Mixer (Output)
	if (SUCCEEDED(mSwitcher->QueryInterface(IID_IBMDSwitcherAudioMixer, (void**)&mAudioMixer)))
	{
		mAudioMixer->AddCallback(mAudioMixerMonitor);
		
		// Audio Inputs
		IBMDSwitcherAudioInputIterator* audioInputIterator = NULL;
		if (SUCCEEDED(mAudioMixer->CreateIterator(IID_IBMDSwitcherAudioInputIterator, (void**)&audioInputIterator)))
		{
			IBMDSwitcherAudioInput* audioInput = NULL;
			while (S_OK == audioInputIterator->Next(&audioInput))
			{
				BMDSwitcherAudioInputId inputId;
				audioInput->GetAudioInputId(&inputId);
				mAudioInputs.insert(std::make_pair(inputId, audioInput));
				AudioInputMonitor *monitor = new AudioInputMonitor(self, inputId);
				audioInput->AddCallback(monitor);
				mMonitors.push_back(monitor);
				mAudioInputMonitors.insert(std::make_pair(inputId, monitor));
			}
			audioInputIterator->Release();
			audioInputIterator = NULL;
		}
		else
		{
			[self logMessage:[NSString stringWithFormat:@"Could not create IBMDSwitcherAudioInputIterator iterator. code: %d", HRESULT_CODE(result)]];
		}
	}
	else
	{
		[self logMessage:@"Could not get IBMDSwitcherAudioMixer interface"];
	}
	
	// Fairlight Audio Mixer
	if (SUCCEEDED(mSwitcher->QueryInterface(IID_IBMDSwitcherFairlightAudioMixer, (void**)&mFairlightAudioMixer))) {
		mFairlightAudioMixer->AddCallback(mFairlightAudioMixerMonitor);
		
		// Audio Inputs
		IBMDSwitcherFairlightAudioSourceIterator* audioSourceIterator = NULL;
		if (SUCCEEDED(mFairlightAudioMixer->CreateIterator(IID_IBMDSwitcherFairlightAudioSourceIterator, (void**)&audioSourceIterator)))
		{
			IBMDSwitcherFairlightAudioSource* audioSource = NULL;
			while (S_OK == audioSourceIterator->Next(&audioSource))
			{
				BMDSwitcherFairlightAudioSourceId sourceId;
				audioSource->GetId(&sourceId);
				mFairlightAudioSources.insert(std::make_pair(sourceId, audioSource));
				FairlightAudioSourceMonitor *monitor = new FairlightAudioSourceMonitor(self, sourceId);
				audioSource->AddCallback(monitor);
				mMonitors.push_back(monitor);
				mFairlightAudioSourceMonitors.insert(std::make_pair(sourceId, monitor));
			}
			audioSourceIterator->Release();
			audioSourceIterator = NULL;
		}
		else
		{
			[self logMessage:[NSString stringWithFormat:@"Could not create IBMDSwitcherFairlightAudioSourceIterator iterator. code: %d", HRESULT_CODE(result)]];
		}
	}
	else
	{
		[self logMessage:@"Could not get IBMDSwitcherFairlightAudioMixer interface"];
	}
	
	// Hyperdeck Setup
	IBMDSwitcherHyperDeckIterator* hyperDeckIterator = NULL;
	if (SUCCEEDED(mSwitcher->CreateIterator(IID_IBMDSwitcherHyperDeckIterator, (void**)&hyperDeckIterator)))
	{
		IBMDSwitcherHyperDeck* hyperdeck = NULL;
		while (S_OK == hyperDeckIterator->Next(&hyperdeck))
		{
			BMDSwitcherHyperDeckId hyperdeckId;
			hyperdeck->GetId(&hyperdeckId);
			mHyperdecks.insert(std::make_pair(hyperdeckId, hyperdeck));
			HyperDeckMonitor *monitor = new HyperDeckMonitor(self, hyperdeckId);
			hyperdeck->AddCallback(monitor);
			mMonitors.push_back(monitor);
			mHyperdeckMonitors.insert(std::make_pair(hyperdeckId, monitor));
		}
		hyperDeckIterator->Release();
		hyperDeckIterator = NULL;
	}
	else
	{
		[self logMessage:[NSString stringWithFormat:@"Could not create IBMDSwitcherHyperDeckIterator iterator. code: %d", HRESULT_CODE(result)]];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[helpPanel setupWithDelegate: self];
	});
}

- (void)switcherDisconnected
{
	
	isConnectedToATEM = NO;
	if (self.activity)
		[[NSProcessInfo processInfo] endActivity:self.activity];
	
	self.activity = nil;
	
	if (outPort != nil)
	{
		OSCMessage *newMsg = [OSCMessage createWithAddress:@"/atem/led/green"];
		[newMsg addFloat:0.0];
		[outPort sendThisMessage:newMsg];
		newMsg = [OSCMessage createWithAddress:@"/atem/led/red"];
		[newMsg addFloat:1.0];
		[outPort sendThisMessage:newMsg];
	}
	
	
	[(SettingsWindow *)window showSwitcherDisconnected];
	
	[self cleanUpConnection];
	
	[self connectBMD];
}

- (void)cleanUpConnection
{
	if (mSwitcher)
	{
		mSwitcher->RemoveCallback(mSwitcherMonitor);
		mSwitcher->Release();
		mSwitcher = NULL;
		mSwitcherMonitor = NULL;
	}
	
	if (mMixEffectBlock)
	{
		mMixEffectBlock->RemoveCallback(mMixEffectBlockMonitor);
		mMixEffectBlock->Release();
		mMixEffectBlock = NULL;
		mMixEffectBlockMonitor = NULL;
	}
	
	if (switcherTransitionParameters)
	{
		switcherTransitionParameters->RemoveCallback(mTransitionParametersMonitor);
		switcherTransitionParameters->Release();
		switcherTransitionParameters = NULL;
		mTransitionParametersMonitor = NULL;
	}
	
	for (auto const& it : mInputs)
	{
		it.second->RemoveCallback(mInputMonitors.at(it.first));
		it.second->Release();
	}
	mInputs.clear();
	mInputMonitors.clear();
	
	while (mSwitcherInputAuxList.size())
	{
		mSwitcherInputAuxList.back()->Release();
		mSwitcherInputAuxList.pop_back();
	}
	
	while (keyers.size())
	{
		keyers.back()->Release();
		keyers.back()->RemoveCallback(mUpstreamKeyerMonitor);
		IBMDSwitcherKeyLumaParameters* lumaParams = nil;
		keyers.back()->QueryInterface(IID_IBMDSwitcherKeyLumaParameters, (void**)&lumaParams);
		if (lumaParams != nil)
			lumaParams->RemoveCallback(mUpstreamKeyerLumaParametersMonitor);
		IBMDSwitcherKeyChromaParameters* chromaParams = nil;
		keyers.back()->QueryInterface(IID_IBMDSwitcherKeyChromaParameters, (void**)&chromaParams);
		if (chromaParams != nil)
			chromaParams->RemoveCallback(mUpstreamKeyerChromaParametersMonitor);
		keyers.pop_back();
		mUpstreamKeyerMonitor = NULL;
		mUpstreamKeyerLumaParametersMonitor = NULL;
		mUpstreamKeyerChromaParametersMonitor = NULL;
	}
	
	while (dsk.size())
	{
		dsk.back()->RemoveCallback(mDownstreamKeyerMonitor);
		dsk.back()->Release();
		dsk.pop_back();
		mDownstreamKeyerMonitor = NULL;
	}
	
	while (mMediaPlayers.size())
	{
		mMediaPlayers.back()->Release();
		mMediaPlayers.pop_back();
	}
	
	if (mMediaPool)
	{
		mMediaPool->Release();
		mMediaPool = NULL;
	}
	
	if (mMacroPool)
	{
		mMacroPool->RemoveCallback(mMacroPoolMonitor);
		mMacroPool->Release();
		mMacroPool = NULL;
		mMacroPoolMonitor = NULL;
	}
	
	while (mSuperSourceBoxes.size())
	{
		mSuperSourceBoxes.back()->Release();
		mSuperSourceBoxes.pop_back();
	}
	
	if (mAudioMixer)
	{
		mAudioMixer->RemoveCallback(mAudioMixerMonitor);
		mAudioMixer->Release();
		mAudioMixer = NULL;
		mAudioMixerMonitor = NULL;
	}
	
	for (auto const& it : mAudioInputs)
	{
		it.second->RemoveCallback(mAudioInputMonitors.at(it.first));
		it.second->Release();
	}
	mAudioInputs.clear();
	mAudioInputMonitors.clear();
	
	if (mFairlightAudioMixer)
	{
		mFairlightAudioMixer->RemoveCallback(mFairlightAudioMixerMonitor);
		mFairlightAudioMixer->Release();
		mFairlightAudioMixer = NULL;
		mFairlightAudioMixerMonitor = NULL;
	}
	
	for (auto const& it : mFairlightAudioSources)
	{
		it.second->RemoveCallback(mFairlightAudioSourceMonitors.at(it.first));
		it.second->Release();
	}
	mFairlightAudioSources.clear();
	mFairlightAudioSourceMonitors.clear();
	
	for (auto const& it : mHyperdecks)
	{
		it.second->RemoveCallback(mHyperdeckMonitors.at(it.first));
		it.second->Release();
	}
	mHyperdecks.clear();
	mHyperdeckMonitors.clear();
	
	mMonitors.clear();
}

// We run this recursively so that we can get the
// delay from each command, and allow for variable
// wait times between sends
- (void)sendStatus
{
	if ([self isConnectedToATEM])
	{
		[self sendEachStatus:0];
	}
	else
	{
		[self logMessage:@"Cannot send status - Not connected to switcher"];
	}
}

- (void)sendEachStatus:(int)nextMonitor
{
	if (nextMonitor < mMonitors.size()) {
		int delay = mMonitors[nextMonitor]->sendStatus();
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self sendEachStatus:nextMonitor+1];
		});
	}
}

- (void)logMessage:(NSString *)message
{
	if (message) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self appendMessage:message];
			[(SettingsWindow *)window updateLogLabel:message];
		});
		NSLog(@"%@", message);
	}
}

- (void)appendMessage:(NSString *)message
{
	NSDate *now = [NSDate date];
	NSDateFormatter *formatter = nil;
	formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	
	NSString *messageWithNewLine = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:now], message];
	[formatter release];
	
	// Append string to textview
	[logTextView.textStorage appendAttributedString:[[NSAttributedString alloc]initWithString:messageWithNewLine]];
	
	[logTextView scrollRangeToVisible: NSMakeRange(logTextView.string.length, 0)];
	
	[logTextView setTextColor:[NSColor whiteColor]];
}

@end
