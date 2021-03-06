//
//  ViewController.swift
//  BasicFreewheelPlayer
//
//  Copyright © 2018 Brightcove, Inc. All rights reserved.
//

import UIKit
import BrightcoveFW

struct ConfigConstants {
    static let PolicyKey = "BCpkADawqM1W-vUOMe6RSA3pA6Vw-VWUNn5rL0lzQabvrI63-VjS93gVUugDlmBpHIxP16X8TSe5LSKM415UHeMBmxl7pqcwVY_AZ4yKFwIpZPvXE34TpXEYYcmulxJQAOvHbv2dpfq-S_cm"
    static let AccountID = "3636334163001"
    static let VideoID = "3666678807001"
    static let SlotID = "300x250"
}

class ViewController: UIViewController {

    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var adSlot: UIView!
    
    private var adContext: BCOVFWContext?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private lazy var adManager: FWAdManager? = {
        let _adManager = newAdManager()
        _adManager?.setNetworkId(90750)
        return _adManager
    }()
    
    private lazy var adContextPolicy: BCOVFWSessionProviderAdContextPolicy? = {
        weak var weakSelf = self
        
        return { video, source, videoDuration in
            
            // This block will get called before every session is delivered. The source,
            // video, and videoDuration are provided in case you need to use them to
            // customize the these settings.
            // The values below are specific to this sample app, and should be changed
            // appropriately. For information on what values need to be provided,
            // please refer to your Freewheel documentation or contact your Freewheel
            // account executive. Basic information is provided below.
            guard let strongSelf = weakSelf, let adManager = strongSelf.adManager, let adContext = adManager.newContext() else {
                return nil
            }
            
            // These are player/app-specific and asset-specific values.
            let adRequestConfig = FWRequestConfiguration(serverURL: "http://demo.v.fwmrm.net", playerProfile: "90750:3pqa_ios")
            adRequestConfig.siteSectionConfiguration = FWSiteSectionConfiguration(siteSectionId: "brightcove_ios", idType: .custom)
            adRequestConfig.videoAssetConfiguration = FWVideoAssetConfiguration(videoAssetId: "brightcove_demo_video", idType: .custom, duration: videoDuration, durationType: .exact, autoPlayType: .attended)
            
            // This is the view where the ads will be rendered.
            adContext.setVideoDisplayBase(strongSelf.playerView?.contentOverlayView)
            
            // This registers a companion view slot with size 300x250. If you don't
            // need companion ads, this can be removed.
            adRequestConfig.add(FWNonTemporalSlotConfiguration(customId: ConfigConstants.SlotID, adUnit: FWAdUnitOverlay, width: 300, height: 250))
            
            adRequestConfig.add(FWTemporalSlotConfiguration(customId: "midroll60", adUnit: FWAdUnitMidroll, timePosition: 60.0))
            adRequestConfig.add(FWTemporalSlotConfiguration(customId: "midroll120", adUnit: FWAdUnitMidroll, timePosition: 120.0))
            
            // We save the adContext to the class so that we can access outside the
            // block. In this case, we will need to retrieve the companion ad slot.
            let bcovAdContext = BCOVFWContext(adContext: adContext, requestConfiguration: adRequestConfig)
            
            self.adContext = bcovAdContext
            
            return bcovAdContext
        }
    }()
    
    private lazy var playbackController: BCOVPlaybackController? = {
        
        guard let _playbackController = BCOVPlayerSDKManager.shared()?.createFWPlaybackController(adContextPolicy: adContextPolicy, viewStrategy: nil) else {
            return nil
        }
        
        return _playbackController
    }()
    
    private lazy var playerView: BCOVPUIPlayerView? = {
        
        let options = BCOVPUIPlayerViewOptions()
        options.presentingViewController = self
        
        // Create PlayerUI views with normal VOD controls.
        let controlView = BCOVPUIBasicControlView.withVODLayout()
        guard let _playerView = BCOVPUIPlayerView(playbackController: nil, options: options, controlsView: controlView) else {
            return nil
        }
        
        // Make the player view frame match its parent
        _playerView.frame = self.videoContainerView.bounds
        _playerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        // Add to parent view
        self.videoContainerView.addSubview(_playerView)
        
        return _playerView
    }()
    
    private lazy var playbackService: BCOVPlaybackService? = {
        let _playbackService = BCOVPlaybackService(accountId: ConfigConstants.AccountID, policyKey: ConfigConstants.PolicyKey)
        return _playbackService
    }()
    
    // MARK: - View Lifecyle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        playerView?.playbackController = playbackController
        requestContentFromPlaybackService()
    }

    // MARK: - Misc
    
    private func requestContentFromPlaybackService() {
         // In order to play back content, we are going to request a video from the playback service.
        playbackService?.findVideo(withVideoID: ConfigConstants.VideoID, parameters: nil
            , completion: { [weak self] (video: BCOVVideo?, jsonResponse: [AnyHashable : Any]?, error: Error?) in
                guard let video = video else {
                    if let error = error {
                        print("ViewController Debug - Error retrieving video playlist: \(error.localizedDescription)")
                    }
                    return
                }
                
                self?.playbackController?.setVideos([video] as NSFastEnumeration)
        })
    }
    
}

// MARK: - BCOVPlaybackControllerDelegate

extension ViewController: BCOVPlaybackControllerDelegate {
    
    func playbackController(_ controller: BCOVPlaybackController!, didAdvanceTo session: BCOVPlaybackSession!) {
        
        print("ViewController Debug - Advanced to new session.")
        
        // This is an example of displaying a companion ad. We registered this companion
        // ad id in the -[ViewController adContextPolicy] block. When the session
        // gets delivered, we check to see if the slot got populated with an ad,
        // and add it to our companion ad container.
        // If not using companion ads, this is not needed
        guard let slot = adContext?.adContext.getSlotByCustomId(ConfigConstants.SlotID) else {
            return
        }
        
        slot.slotBase()?.frame = adSlot.bounds
        slot.slotBase()?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        adSlot.addSubview(slot.slotBase())
    }
    
}
