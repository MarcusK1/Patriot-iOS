//
//  PhotonManager.swift
//  Patriot
//
//  This class manages the collection of Photon devices
//
//  Discovery will search for all the Photon devices on the network.
//  When a new device is found, it will be added to the photons collection
//  and a delegate or notification sent.
//  This is the anticipated way of updating displays, etc.
//
//  The current activity state will be gleaned from the exposed Activities
//  properties of one or more Photons initially, but then tracked directly
//  after initialization by subscribing to particle events.
//  Subscribing to particle events will also allow detecting new Photons
//  as they come online and start issuing 'alive' events.
//
//  This file uses the Particle SDK: 
//      https://docs.particle.io/reference/ios/#common-tasks
//
//  Created by Ron Lisle on 11/13/16.
//  Copyright © 2016, 2017 Ron Lisle. All rights reserved.
//

import Foundation
import Particle_SDK
import PromiseKit


enum ParticleSDKError : Error
{
    case invalidUserPassword
    case invalidToken
}


class PhotonManager: NSObject, HwManager
{
    var subscribeHandler:   Any?
    var deviceDelegate:     DeviceNotifying?
    var activityDelegate:   ActivityNotifying?
    
    var photons: [String: Photon] = [: ]   // All the particle devices attached to logged-in user's account
    let eventName          = "patriot"
    var deviceNames:        [String] = []       // Names exposed by the "Devices" variables
    var supportedNames:     Set<String> = []    // Activity names exposed by the "Supported" variables
    var currentActivities:  [String: String] = [: ] // List of currently on activities reported by Master
    

    /**
    * Login to the particle.io account
    * The particle SDK will use the returned token in subsequent calls.
    * We don't have to save it.
    */
    func login(user: String, password: String) -> Promise<Void>
    {
        return Promise { fulfill, reject in
            ParticleCloud.sharedInstance().login(withUser: user, password: password) { (error) in
                if let error = error {
                    return reject(error)
                }
                return fulfill()
            }
        }
    }


    @discardableResult func discoverDevices() -> Promise<Void>
    {
        return getAllPhotonDevices()
//        return Promise { fulfill, reject in
//            print("PhotonManager performDiscovery")
//            self.getAllPhotonDevices().then { allPhotons in
//                return self.refreshCurrentActivities()
//            }.then { activities in
//                return self.getAllDeviceNames()
//            }.then { deviceNames -> Void in
//                return self.refreshSupportedNames()
//            }
//        }
    }
    
    
    /**
     * Locate all the particle.io devices
     */
    func getAllPhotonDevices() -> Promise<Void>
    {
        return Promise { fulfill, reject in
            ParticleCloud.sharedInstance().getDevices { (devices: [ParticleDevice]?, error: Error?) in
                if error != nil {
                    print("Error: \(error!)")
                    reject(error!)
                }
                else
                {
                    self.addAllPhotonsToCollection(devices: devices)
                    .then { _ -> Void in
                        print("1. addAllPhotonsToCollection .then")
                        self.activityDelegate?.supportedListChanged()
                        fulfill()
                    }.catch { error in
                        print("1b. error: \(error)")
                        reject(error)
                    }.always { print("1c. always")}
                }
            }
        }
    }


    func addAllPhotonsToCollection(devices: [ParticleDevice]?) -> Promise<Void>
    {
        self.photons = [: ]
        var promises = [Promise<Void>]()
        if let particleDevices = devices
        {
            for device in particleDevices
            {
                if isValidPhoton(device)
                {
                    if let name = device.name?.lowercased()
                    {
                        print("2. Adding photon \(name)")
                        let photon = Photon(device: device)
                        self.photons[name] = photon
                        self.deviceDelegate?.deviceFound(name: name)
                        let promise = photon.refresh()
                        print("2b. adding promise: \(promise)")
                        promises.append(promise)
                    }
                }
            }
            print("3. addAllPhotons... returning when \(promises)")
            return when(fulfilled: promises)
        }
        return Promise(error: NSError(domain: "No devices", code: 0, userInfo: nil))
    }
    
    
    func isValidPhoton(_ device: ParticleDevice) -> Bool
    {
        return device.connected
    }
    
    
    func getPhoton(named: String) -> Photon?
    {
        let lowerCaseName = named.lowercased()
        let photon = photons[lowerCaseName]
        
        return photon
    }

    
    func sendCommand(activity: String, percent: Int)
    {
        print("sendCommand: \(activity) percent: \(percent)")
        let data = activity + ":" + String(percent)
        print("Setting activity: \(data)")
        ParticleCloud.sharedInstance().publishEvent(withName: eventName, data: data, isPrivate: true, ttl: 60)
        { (error:Error?) in
            if let e = error
            {
                print("Error publishing event \(e.localizedDescription)")
            }
        }
    }
    
    func subscribeToEvents()
    {
        subscribeHandler = ParticleCloud.sharedInstance().subscribeToMyDevicesEvents(withPrefix: eventName, handler: { (event: ParticleEvent?, error: Error?) in
            if let _ = error {
                print("Error subscribing to events")
            }
            else
            {
                DispatchQueue.main.async(execute: {
                    print("DEBUG: received event with data \(String(describing: event?.data))")
                    if let eventData = event?.data {
                        let splitArray = eventData.components(separatedBy: ":")
                        let name = splitArray[0]
                        if let percent: Int = Int(splitArray[1]), percent >= 0, percent <= 100
                        {
                            self.activityDelegate?.activityChanged(name: name, index: 0, percent: percent)
                        }
                        else
                        {
                            print("Event data is not a valid number")
                        }
                    }
                    
                })
            }
        })
    }
}


extension PhotonManager
{
    func refreshSupportedNames()
    {
        print("4. refreshSupportedNames")
        supportedNames = []
        for (name, photon) in photons
        {
            let particleDevice = photon.particleDevice
            if particleDevice?.variables["Supported"] != nil
            {
                print("5.  reading Supported variable from \(name)")
                particleDevice?.getVariable("Supported") { (result: Any?, error: Error?) in
                    if error == nil
                    {
                        if let supported = result as? String, supported != ""
                        {
                            self.supportedNames = self.supportedNames.union(self.parseSupportedNames(supported))
                        }
                    } else {
                        print("Error reading Supported variable. Skipping this device.")
                    }
                    print("Updated Supported names = \(self.supportedNames)")
                    self.activityDelegate?.supportedListChanged()
                }
            }
        }
    }
    
    
    private func parseSupportedNames(_ supported: String) -> Set<String>
    {
        print("6. Parsing supported names: \(supported)")
        var newSupported: Set<String> = []
        let items = supported.components(separatedBy: ",")
        for item in items
        {
            let lcItem = item.localizedLowercase
            print("7. New supported = \(lcItem)")
            newSupported.insert(lcItem)
        }
        
        return newSupported
    }
    
    
    func refreshCurrentActivities()
    {
        print("8. refreshCurrentActivities")
        currentActivities = [: ]
        for (name, photon) in photons
        {
            let particleDevice = photon.particleDevice
            if particleDevice?.variables["Activities"] != nil
            {
                print("9.  reading Activities variable from \(name)")
                particleDevice?.getVariable("Activities") { (result: Any?, error: Error?) in
                    if error == nil
                    {
                        if let activities = result as? String, activities != ""
                        {
                            print("10. Activities = \(activities)")
                            let items = activities.components(separatedBy: ",")
                            for item in items
                            {
                                let parts = item.components(separatedBy: ":")
                                self.currentActivities[parts[0]] = parts[1]
//                                self.activityDelegate?.activityChanged(event: item)
                            }
                        }
                    } else {
                        print("Error reading Supported variable. Skipping this device.")
                    }
                    print("11. Updated Supported names = \(self.supportedNames)")
                    self.activityDelegate?.supportedListChanged()
                }
            }
        }
    }
}
