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

#import "BMDSwitcherAPI.h"
#import <list>
#include <vector>

#import <Cocoa/Cocoa.h>
#import "VVOSC/VVOSC.h"
#import "AMSerialPort.h"

class MixEffectBlockMonitor;
class SwitcherMonitor;
class InputMonitor;

@interface SwitcherPanelAppDelegate : NSObject <NSApplicationDelegate, OSCDelegateProtocol, NSTextFieldDelegate>
{
	NSWindow *window;
	
	IBOutlet NSTextField*		mAddressTextField;
	IBOutlet NSButton*			mConnectButton;
	IBOutlet NSTextField*		mSwitcherNameLabel;

	IBMDSwitcherDiscovery*		mSwitcherDiscovery;
	IBMDSwitcher*				mSwitcher;
	IBMDSwitcherMixEffectBlock*	mMixEffectBlock;
	MixEffectBlockMonitor*		mMixEffectBlockMonitor;
    IBMDSwitcherTransitionParameters* switcherTransitionParameters;
    IBMDSwitcherKeyFlyParameters*	mDVEControl;
	SwitcherMonitor*			mSwitcherMonitor;
	IBMDSwitcherMediaPool*		mMediaPool;
    IBMDSwitcherStills*			mStills;
	std::vector<IBMDSwitcherMediaPlayer*>	mMediaPlayers;
	std::list<InputMonitor*>	mInputMonitors;
    std::list<IBMDSwitcherKey*>	keyers;
    std::list<IBMDSwitcherDownstreamKey*>	dsk;

	bool						mMoveSliderDownwards;
	bool						mCurrentTransitionReachedHalfway;
    
    OSCManager					*manager;
	OSCInPort					*inPort;
	OSCOutPort					*outPort;
    IBOutlet NSTextField*       incoming;
    IBOutlet NSTextField*       outgoing;
    IBOutlet NSTextField*       oscdevice;
    
    IBOutlet NSLevelIndicator *redLight;
    IBOutlet NSLevelIndicator *greenLight;
    
    IBOutlet NSLevelIndicator *tallyRedLight;
    IBOutlet NSLevelIndicator *tallyGreenLight;
    
    IBOutlet NSPopUpButton *tallyA;
    IBOutlet NSPopUpButton *tallyB;
    IBOutlet NSPopUpButton *tallyC;
    IBOutlet NSPopUpButton *tallyD;
    
    IBOutlet NSButton *helpButton;
    IBOutlet NSPanel *helpPanel;
    IBOutlet NSTextView *heltTextView;
    
    
    AMSerialPort *port;
    IBOutlet NSPopUpButton	*serialSelectMenu;
    IBOutlet NSButton		*connectButton;
}

@property (assign) IBOutlet NSWindow *window;
@property (strong) id activity;

- (IBAction)connectButtonPressed:(id)sender;
- (IBAction)portChanged:(id)sender;
- (IBAction)helpButtonPressed:(id)sender;

- (void)switcherConnected;
- (void)switcherDisconnected;

- (void)updatePopupButtonItems;
- (void)updateProgramButtonSelection;
- (void)updatePreviewButtonSelection;
- (void)updateInTransitionState;
- (void)updateSliderPosition;
- (void)updateTransitionFramesTextField;
- (void)updateFTBFramesTextField;
- (void)mixEffectBlockBoxSetEnabled:(bool)enabled;


// Serial Port Methods
- (AMSerialPort *)port;
- (void)setPort:(AMSerialPort *)newPort;
- (void)listDevices;

- (IBAction)initPort:(id)sender;

@end
