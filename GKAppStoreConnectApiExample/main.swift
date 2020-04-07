//
//  main.swift
//  GKAppStoreConnectApiExample
//
//  Created by Andrew Liakh on 29.01.20.
//  Copyright © 2020 Gikken. All rights reserved.
//

import Foundation
import GKAppStoreConnectApi

let commands = """
supported commands:
login

list apps
list iaps
list teams

select app [app_id]
select iap [iap_id]

app codes
iap codes

exit
"""

var proceed = true
var selectedApp: Int?
var selectedAppInfo: ASCAppPromoCodesInfo?
var selectedIap: Int?

func main() {
    print(commands)
    
    while(true) {
        if proceed {
            print("\nwhat's next?")
            guard let command = readLine() else { continue }
            
            if command == "login" {
                logIn()
            }
            else if command == "list apps" {
                listApps()
            }
            else if command.starts(with: "select app ") {
                selectApp(command: command)
            }
            else if command == "app codes" {
                generateTwoCodes()
            }
            else if command == "list iaps" {
                listIAPs()
            }
            else if command.starts(with: "select iap ") {
                selectIap(command: command)
            }
            else if command == "iap codes" {
                generateIapCodes()
            }
            else if command == "list teams" {
                listTeams()
            }
            else if command == "exit" {
                exit(EXIT_SUCCESS)
            }
            else {
                print("bad command")
            }
        }
        usleep(100000)
    }
}

func logIn() {
    print("username:")
    let username = readLine() ?? ""
    print("password:")
    let password = readLine() ?? ""
    proceed = false
    GKAppStoreConnectApi.shared.loginWith(username: username, password: password) { (loggedIn, needs2FA, info, error) in
        if error != nil {
            print(error!)
        }
        
        if loggedIn {
            print("Logged in")
            proceed = true
        } else if needs2FA {
            print("2FA needed")
            let didSendCode = info?["didSendCode"] as? Bool ?? false
            let phoneNumber = (info?["resendInfo"] as? [String: Any])?["phoneNumber"] as? String
            let usedTrustedDevices = info?["wasTrustedDeviceCode"] as? Bool ?? false
            var phoneId = (info?["resendInfo"] as? [String: Any])?["phoneID"] as? Int
            
            if didSendCode && (usedTrustedDevices || phoneNumber == nil) {
                print("Code was sent to your trusted devices")
            } else if didSendCode && phoneNumber != nil {
                print("Code was sent to \(phoneNumber!)")
            }
            
            print("Want to use another option? y/n")
            let another = readLine() == "y"
            
            if !didSendCode || another {
                print("Please select a phone number:")
                let phoneNumbers = (info?["phoneNumbers"] as? [[String: Any]]) ?? [[String: Any]]()
                for phoneNumber in phoneNumbers {
                    print("\(phoneNumber["id"] as? Int ?? -1): \(phoneNumber["numberWithDialCode"] as? String ?? "")")
                }
                let newPhoneId = readLine() ?? ""
                let intPhoneId = Int(newPhoneId) ?? -1
                phoneId = intPhoneId
                if intPhoneId != -1 {
                    GKAppStoreConnectApi.shared.resend2FACodeWith(phoneID: intPhoneId) { (codeSent, error) in
                        
                    }
                } else {
                    print("error")
                }
            }
            
            print("Enter code:")
            let code = readLine() ?? ""
            if !code.isEmpty {
                GKAppStoreConnectApi.shared.finish2FAWith(code: code, phoneID: phoneId) { (loggedIn, info, error) in
                    if loggedIn {
                        print("Successfully logged in")
                    } else {
                        print("Log in failed. Error: \(error?.localizedDescription ?? "")")
                    }
                    proceed = true
                }
            } else {
                print("error")
                proceed = true
            }
            
        } else if !loggedIn && !needs2FA {
            proceed = true
            return
        }
    }
}

func generateTwoCodes() {
    if selectedApp == nil || selectedAppInfo == nil {
        print("Please select an app")
        return
    }
    
    print("requesting codes, may take a while")
    proceed = false
    GKAppStoreConnectApi.shared.requestPromoCodesForAppWith(appID: selectedApp!, versionID: selectedAppInfo!.versionId, quantity: 2, contractFilename: selectedAppInfo!.contractFilename) { (codes, error) in
        guard let codes = codes, error == nil else {
            print("Error: \(error?.localizedDescription ?? "unknown")")
            proceed = true
            return
        }
        
        for code in codes {
            print(code.code)
        }
        
        proceed = true
    }
}

func listApps() {
    let apps = GKAppStoreConnectApi.shared.getApps()
    
    if apps.isEmpty {
        print("No apps")
    }
    
    for app in apps {
        print("\(app.id): \(app.name), \(app.platform)")
    }
}

func selectApp(command: String) {
    guard let appId = Int(command.replacingOccurrences(of: "select app ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return
    }
    
    selectedIap = nil
    
    proceed = false
    GKAppStoreConnectApi.shared.promoCodeInfoForAppWith(appID: appId) { (info, error) in
        guard let info = info, error == nil else {
            print("Error: \(error?.localizedDescription ?? "unknown")")
            proceed = true
            return
        }
        selectedApp = appId
        selectedAppInfo = info
        print("Promo codes left: \(info.codesLeft)")
        proceed = true
    }
}

func listIAPs() {
    if selectedApp == nil {
        print("Please select an app")
        return
    }

    proceed = false
    GKAppStoreConnectApi.shared.iapsForAppWith(appId: selectedApp!) { (iaps, error) in
        guard let iaps = iaps, error == nil else {
            print("Error: \(error?.localizedDescription ?? "unknown")")
            proceed = true
            return
        }
        
        for iap in iaps {
            print("\(iap.id): \(iap.name), codes left: \(iap.codesLeft)")
        }
        proceed = true
    }
}

func selectIap(command: String) {
    guard let iapId = Int(command.replacingOccurrences(of: "select iap ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return
    }
    
    selectedIap = iapId
    print("Selected")
}

func generateIapCodes() {
    if selectedApp == nil || selectedIap == nil {
        print("Please select an app and it's IAP")
        return
    }
    
    print("requesting codes, may take a while")
    proceed = false
    GKAppStoreConnectApi.shared.requestIapPromoCodesFor(iapID: selectedIap!, appID: selectedApp!, quantity: 2) { (codes, error) in
        guard let codes = codes, error == nil else {
            print("Error: \(error?.localizedDescription ?? "unknown")")
            proceed = true
            return
        }
        
        for code in codes {
            print(code.code)
        }
        
        proceed = true
    }
}

func listTeams() {
    guard let teams = GKAppStoreConnectApi.shared.getTeams() else {
        print("No teams")
        return
    }
    
    for team in teams {
        print("\(team.providerId): \(team.name)")
    }
}

main()
