//
//  SBAActivityArchive.swift
//  BridgeAppSDK
//
// Copyright © 2016 Sage Bionetworks. All rights reserved.
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

import Foundation

private let kSurveyCreatedOnKey               = "surveyCreatedOn"
private let kSurveyGuidKey                    = "surveyGuid"
private let kSchemaRevisionKey                = "schemaRevision"
private let kTaskIdentifierKey                = "taskIdentifier"
private let kScheduledActivityGuidKey         = "scheduledActivityGuid"
private let kTaskRunUUIDKey                   = "taskRunUUID"
private let kStartDate                        = "startDate"
private let kEndDate                          = "endDate"
private let kDataGroups                       = "dataGroups"
private let kMetadataFilename                 = "metadata.json"

open class SBAActivityArchive: SBADataArchive, SBASharedInfoController {
    
    lazy open var sharedAppDelegate: SBAAppInfoDelegate = {
        return UIApplication.shared.delegate as! SBAAppInfoDelegate
    }()

    fileprivate var metadata = [String: AnyObject]()
    
    public init?(result: SBAActivityResult, jsonValidationMapping: [String: NSPredicate]? = nil) {
        super.init(reference: result.schemaIdentifier, jsonValidationMapping: jsonValidationMapping)
        
        // set up the activity metadata
        // -- always set scheduledActivityGuid and taskRunUUID
        self.metadata[kScheduledActivityGuidKey] = result.schedule.scheduleIdentifier as AnyObject?
        self.metadata[kTaskRunUUIDKey] = result.taskRunUUID.uuidString as AnyObject?
        
        // -- if it's a task, also set the taskIdentifier
        if let taskReference = result.schedule.activity.task {
            self.metadata[kTaskIdentifierKey] = taskReference.identifier as AnyObject?
        }
        
        // -- add the start/end date
        self.metadata[kStartDate] = (result.startDate as NSDate).iso8601String() as AnyObject?
        self.metadata[kEndDate] = (result.endDate as NSDate).iso8601String() as AnyObject?
        
        // -- add data groups
        if let dataGroups = sharedUser.dataGroups {
            self.metadata[kDataGroups] = dataGroups.joined(separator: ",") as AnyObject?
        }
        
        // set up the info.json
        // -- always set the schemaRevision
        self.setArchiveInfoObject(result.schemaRevision, forKey: kSchemaRevisionKey)

        // -- if it's a survey, also set the survey's guid and createdOn
        if let surveyReference = result.schedule.activity.survey {
            // Survey schema is better matched by created date and survey guid
            self.setArchiveInfoObject(surveyReference.guid as SBAJSONObject, forKey: kSurveyGuidKey)
            let createdOn = surveyReference.createdOn ?? Date()
            self.setArchiveInfoObject((createdOn as NSDate).iso8601String() as SBAJSONObject, forKey: kSurveyCreatedOnKey)
        }
        
        if !self.buildArchiveForResult(result) {
            self.remove()
            return nil
        }
    }

    func buildArchiveForResult(_ activityResult: SBAActivityResult) -> Bool {
        
        // exit early with false if nothing to archive
        guard let activityResultResults = activityResult.results as? [ORKStepResult]
            , activityResultResults.count > 0
        else {
            return false
        }
        
        // (although there _still_ might be nothing to archive, if none of the stepResults have any results.)
        for stepResult in activityResultResults {
            if let stepResultResults = stepResult.results {
                for result in stepResultResults {
                    if !insert(result: result, stepResult: stepResult, activityResult: activityResult) {
                        return false
                    }
                }
            }
        }
        
        // don't insert the metadata if the archive is otherwise empty
        let builtArchive = !isEmpty()
        if builtArchive {
            insertDictionary(intoArchive: self.metadata, filename: kMetadataFilename)
        }

        return builtArchive
    }
    
    /**
    * Method for inserting a result into an archive. Allows for override by subclasses
    */
    open func insert(result: ORKResult, stepResult: ORKStepResult, activityResult: SBAActivityResult) -> Bool {
        
        guard let archiveableResult = result.bridgeData(stepResult.identifier) else {
            assertionFailure("Something went wrong getting result to archive from result \(result.identifier) of step \(stepResult.identifier) of activity result \(activityResult.identifier)")
            return false
        }
        
        if let urlResult = archiveableResult.result as? NSURL {
            self.insertURL(intoArchive: urlResult as URL, fileName: archiveableResult.filename)
        } else if let dictResult = archiveableResult.result as? [AnyHashable: Any] {
            self.insertDictionary(intoArchive: dictResult, filename: archiveableResult.filename)
        } else if let dataResult = archiveableResult.result as? NSData {
            self.insertData(intoArchive: dataResult as Data, filename: archiveableResult.filename)
        } else {
            let className = NSStringFromClass(archiveableResult.result.classForCoder)
            assertionFailure("Unsupported archiveable result type: \(className)")
            return false
        }
        
        return true
    }
    
}
