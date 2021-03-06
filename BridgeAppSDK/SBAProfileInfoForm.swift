//
//  SBARegistrationForm.swift
//  BridgeAppSDK
//
//  Copyright © 2016 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import ResearchKit

public enum SBAProfileInfoOption : String {
    case email                  = "email"
    case password               = "password"
    case externalID             = "externalID"
    case name                   = "name"
    case birthdate              = "birthdate"
    case gender                 = "gender"
    case bloodType              = "bloodType"
    case fitzpatrickSkinType    = "fitzpatrickSkinType"
    case wheelchairUse          = "wheelchairUse"
}

enum SBAProfileInfoOptionsError: Error {
    case missingRequiredOptions
    case missingEmail
    case missingExternalID
    case missingName
    case notConsented
    case unrecognizedSurveyItemType
}

struct SBAExternalIDOptions {
    
    static let defaultAutocapitalizationType: UITextAutocapitalizationType = .allCharacters
    static let defaultKeyboardType: UIKeyboardType = .asciiCapable
    
    let autocapitalizationType: UITextAutocapitalizationType
    let keyboardType: UIKeyboardType
    
    init() {
        self.autocapitalizationType = SBAExternalIDOptions.defaultAutocapitalizationType
        self.keyboardType = SBAExternalIDOptions.defaultKeyboardType
    }
    
    init(autocapitalizationType: UITextAutocapitalizationType, keyboardType: UIKeyboardType) {
        self.autocapitalizationType = autocapitalizationType
        self.keyboardType = keyboardType
    }
    
    init(options: [AnyHashable: Any]?) {
        self.autocapitalizationType = {
            if let autocap = options?["autocapitalizationType"] as? String {
                 return UITextAutocapitalizationType(key: autocap)
            }
            else {
                return SBAExternalIDOptions.defaultAutocapitalizationType
            }
        }()
        self.keyboardType = {
            if let keyboard = options?["keyboardType"] as? String {
                return UIKeyboardType(key: keyboard)
            }
            else {
                return SBAExternalIDOptions.defaultKeyboardType
            }
        }()
    }
}

public struct SBAProfileInfoOptions {
    
    public let includes: [SBAProfileInfoOption]
    public let customOptions: [Any]
    let externalIDOptions: SBAExternalIDOptions
    
    public init(includes: [SBAProfileInfoOption]) {
        self.includes = includes
        self.externalIDOptions = SBAExternalIDOptions()
        self.customOptions = []
    }
    
    init(externalIDOptions: SBAExternalIDOptions) {
        self.includes = [.externalID]
        self.externalIDOptions = externalIDOptions
        self.customOptions = []
    }
    
    public init?(inputItem: SBASurveyItem?) {
        guard let surveyForm = inputItem as? SBAFormStepSurveyItem,
            let items = surveyForm.items else {
            return nil
        }
        
        // Map the includes, and if it is an external ID then also map the keyboard options
        var externalIDOptions = SBAExternalIDOptions(autocapitalizationType: .none, keyboardType: .default)
        var customOptions: [Any] = []
        self.includes = items.mapAndFilter({ (obj) -> SBAProfileInfoOption? in
            if let str = obj as? String {
                return SBAProfileInfoOption(rawValue: str)
            }
            else if let dictionary = obj as? [String : AnyObject],
                let identifier = dictionary["identifier"] as? String,
                let option = SBAProfileInfoOption(rawValue: identifier) {
                if option == .externalID {
                    externalIDOptions = SBAExternalIDOptions(options: dictionary)
                }
                return option
            }
            else {
                customOptions.append(obj)
            }
            return nil
        })
        self.externalIDOptions = externalIDOptions
        self.customOptions = customOptions
    }
    
    func makeFormItems(surveyItemType: SBASurveyItemType) -> [ORKFormItem] {
        
        var formItems: [ORKFormItem] = []
        
        for option in self.includes {
            switch option {
                
            case .email:
                let formItem = makeEmailFormItem(option)
                formItems.append(formItem)
            
            case .password:
                let (formItem, answerFormat) = makePasswordFormItem(option)
                formItems.append(formItem)
                
                // confirmation
                if (surveyItemType == .account(.registration)) {
                    let confirmFormItem = makeConfirmationFormItem(formItem, answerFormat: answerFormat)
                    formItems.append(confirmFormItem)
                }
                
            case .externalID:
                let formItem = makeExternalIDFormItem(option)
                formItems.append(formItem)
                
            case .name:
                let formItem = makeNameFormItem(option)
                formItems.append(formItem)
                
            case .birthdate:
                let formItem = makeBirthdateFormItem(option)
                formItems.append(formItem)
                
            case .gender:
                let formItem = makeGenderFormItem(option)
                formItems.append(formItem)
                
            case .bloodType:
                let formItem = makeBloodTypeFormItem(option)
                formItems.append(formItem)
                
            case .fitzpatrickSkinType:
                let formItem = makeFitzpatrickSkinTypeFormItem(option)
                formItems.append(formItem)
                
            case .wheelchairUse:
                let formItem = makeWheelchairUseFormItem(option)
                formItems.append(formItem)
            }
        }
        return formItems
    }
    
    func makeEmailFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        let answerFormat = ORKAnswerFormat.emailAnswerFormat()
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("EMAIL_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("EMAIL_FORM_ITEM_PLACEHOLDER")
        return formItem
    }
    
    func makePasswordFormItem(_ option: SBAProfileInfoOption) -> (ORKFormItem, ORKTextAnswerFormat) {
        let answerFormat = ORKAnswerFormat.textAnswerFormat()
        answerFormat.multipleLines = false
        answerFormat.isSecureTextEntry = true
        answerFormat.autocapitalizationType = .none
        answerFormat.autocorrectionType = .no
        answerFormat.spellCheckingType = .no
        
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("PASSWORD_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("PASSWORD_FORM_ITEM_PLACEHOLDER")
        
        return (formItem, answerFormat)
    }
    
    func makeConfirmationFormItem(_ formItem: ORKFormItem, answerFormat: ORKTextAnswerFormat) -> ORKFormItem {
        // If this is a registration, go ahead and set the default password verification
        let minLength = SBARegistrationStep.defaultPasswordMinLength
        let maxLength = SBARegistrationStep.defaultPasswordMaxLength
        answerFormat.validationRegex = "[[:ascii:]]{\(minLength),\(maxLength)}"
        answerFormat.invalidMessage = Localization.localizedStringWithFormatKey("SBA_REGISTRATION_INVALID_PASSWORD_LENGTH_%@_TO_%@", NSNumber(value: minLength), NSNumber(value: maxLength))
        
        // Add a confirmation field
        let confirmIdentifier = SBARegistrationStep.confirmationIdentifier
        let confirmText = Localization.localizedString("CONFIRM_PASSWORD_FORM_ITEM_TITLE")
        let confirmError = Localization.localizedString("CONFIRM_PASSWORD_ERROR_MESSAGE")
        let confirmFormItem = formItem.confirmationAnswer(withIdentifier: confirmIdentifier, text: confirmText,
                                                                                errorMessage: confirmError)
        
        confirmFormItem.placeholder = Localization.localizedString("CONFIRM_PASSWORD_FORM_ITEM_PLACEHOLDER")
        
        return confirmFormItem
    }
    
    func makeExternalIDFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        let answerFormat = ORKAnswerFormat.textAnswerFormat()
        answerFormat.multipleLines = false
        answerFormat.autocapitalizationType = self.externalIDOptions.autocapitalizationType
        answerFormat.autocorrectionType = .no
        answerFormat.spellCheckingType = .no
        answerFormat.keyboardType = self.externalIDOptions.keyboardType
        
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("SBA_REGISTRATION_EXTERNALID_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("SBA_REGISTRATION_EXTERNALID_PLACEHOLDER")
        
        return formItem
    }
    
    func makeNameFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        
        let answerFormat = ORKAnswerFormat.textAnswerFormat()
        answerFormat.multipleLines = false
        answerFormat.autocapitalizationType = .words
        answerFormat.autocorrectionType = .no
        answerFormat.spellCheckingType = .no
        answerFormat.keyboardType = .default
        
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("SBA_REGISTRATION_FULLNAME_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("SBA_REGISTRATION_FULLNAME_PLACEHOLDER")
        
        return formItem
    }
    
    func makeBirthdateFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        
        let characteristic = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let answerFormat = SBAHealthKitCharacteristicTypeAnswerFormat(characteristicType: characteristic)
        answerFormat.shouldRequestAuthorization = false
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("DOB_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("DOB_FORM_ITEM_PLACEHOLDER")
        
        return formItem
    }
    
    func makeGenderFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        
        let characteristic = HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
        let answerFormat = SBAHealthKitCharacteristicTypeAnswerFormat(characteristicType: characteristic)
        answerFormat.shouldRequestAuthorization = false
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("GENDER_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("GENDER_FORM_ITEM_PLACEHOLDER")
        
        return formItem
    }
    
    func makeBloodTypeFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        
        let characteristic = HKObjectType.characteristicType(forIdentifier: .bloodType)!
        let answerFormat = SBAHealthKitCharacteristicTypeAnswerFormat(characteristicType: characteristic)
        answerFormat.shouldRequestAuthorization = false
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("BLOOD_TYPE_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("BLOOD_TYPE_FORM_ITEM_PLACEHOLDER")
        
        return formItem
    }
    
    func makeFitzpatrickSkinTypeFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        
        let characteristic = HKObjectType.characteristicType(forIdentifier: .fitzpatrickSkinType)!
        let answerFormat = SBAHealthKitCharacteristicTypeAnswerFormat(characteristicType: characteristic)
        answerFormat.shouldRequestAuthorization = false
        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("FITZPATRICK_SKIN_TYPE_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        formItem.placeholder = Localization.localizedString("FITZPATRICK_SKIN_TYPE_FORM_ITEM_PLACEHOLDER")
        
        return formItem
    }
    
    func makeWheelchairUseFormItem(_ option: SBAProfileInfoOption) -> ORKFormItem {
        
        let answerFormat = ORKBooleanAnswerFormat()
        
//        if #available(iOS 10.0, *) {
//            let characteristic = HKObjectType.characteristicType(forIdentifier: .wheelchairUse)!
//            let answerFormat = SBAHealthKitCharacteristicTypeAnswerFormat(characteristicType: characteristic)
//            answerFormat.shouldRequestAuthorization = false
//        } else {
//            
//        }

        let formItem = ORKFormItem(identifier: option.rawValue,
                                   text: Localization.localizedString("WHEELCHAIR_USE_FORM_ITEM_TITLE"),
                                   answerFormat: answerFormat,
                                   optional: false)
        
        return formItem
    }
    
    
//    case wheelchairUse          = "wheelchairUse"
}

public protocol SBAFormProtocol : class {
    var identifier: String { get }
    var title: String? { get set }
    var text: String? { get set }
    var formItems: [ORKFormItem]? { get set }
    init(identifier: String)
}

extension SBAFormProtocol {
    public func formItemForIdentifier(_ identifier: String) -> ORKFormItem? {
        return self.formItems?.find({ $0.identifier == identifier })
    }
}

extension ORKFormStep: SBAFormProtocol {
}

public protocol SBAProfileInfoForm : SBAFormProtocol {
    var surveyItemType: SBASurveyItemType { get }
    func defaultOptions(_ inputItem: SBASurveyItem?) -> [SBAProfileInfoOption]
}

extension SBAProfileInfoForm {
    
    public var options: [SBAProfileInfoOption]? {
        return self.formItems?.mapAndFilter({ SBAProfileInfoOption(rawValue: $0.identifier) })
    }
    
    public func formItemForProfileInfoOption(_ profileInfoOption: SBAProfileInfoOption) -> ORKFormItem? {
        return self.formItems?.find({ $0.identifier == profileInfoOption.rawValue })
    }
    
    func commonInit(inputItem: SBASurveyItem?) {
        self.title = inputItem?.stepTitle
        self.text = inputItem?.stepText
        if let formStep = self as? ORKFormStep {
            formStep.footnote = inputItem?.stepFootnote
        }
        let options = SBAProfileInfoOptions(inputItem: inputItem) ?? SBAProfileInfoOptions(includes: defaultOptions(inputItem))
        self.formItems = options.makeFormItems(surveyItemType: self.surveyItemType)
    }
}

class SBAHealthKitCharacteristicTypeAnswerFormat: ORKHealthKitCharacteristicTypeAnswerFormat {
    override func implied() -> ORKAnswerFormat {
        let answerFormat = super.implied()
        if let choiceFormat = answerFormat as? ORKTextChoiceAnswerFormat {
            return ORKValuePickerAnswerFormat(textChoices: choiceFormat.textChoices)
        }
        else {
            return answerFormat
        }
    }
}

