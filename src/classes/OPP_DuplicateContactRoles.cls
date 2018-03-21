/*
    Copyright (c) 2018, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2018
* @group Opportunity Contact Role
* @group-content ../../ApexDocContent/Rollups.htm
* @description Domain Classes for the deletion of duplicate primary OCRs. 
*/

public with sharing class OPP_DuplicateContactRoles {

    @TestVisible private static final String ERROR_MESSAGE = '/{0}';

	/*******************************************************************************************************
    * @description The Duplicate Primary Opportunity Contact Roles Wrapper. It contains the logic that loads and 
    * manages the duplicate Primary OCRs and the related Opportunities.
    ********************************************************************************************************/
    public class DuplicatePrimaryOCRs {
        private Map<Id, Opportunity> opportunityRecords;
        private Map<Id, OpportunityContactRole> opportunityContactRoles;

        private Map<Id, Opportunity> opportunityRecordsToUpdate;
        private Map<Id, OpportunityContactRole> opportunityContactRolesToUpdate;
        private Map<Id, OpportunityContactRole> opportunityContactRolesToDelete;

        /*********************************************************************************************************
        * @description The Constructor of DuplicatePrimaryOCRs.
        * @param Integer The maximum records to load.
        */
        public DuplicatePrimaryOCRs(Integer ocrsLoadSize) {
            opportunityRecords = new Map<Id, Opportunity>(loadOpportunities(ocrsLoadSize));
            opportunityContactRoles = new Map<Id, OpportunityContactRole>(loadOpportunityContactRoles(opportunityRecords.values()));
            opportunityRecordsToUpdate = new Map<Id, Opportunity>();
            opportunityContactRolesToUpdate = new Map<Id, OpportunityContactRole>();
            opportunityContactRolesToDelete = new Map<Id, OpportunityContactRole>();
        }

        /*******************************************************************************************************
        * @description Gets the duplicate primary OCRs Opportunities. 
        * @return List<Opportunity> The duplicate primary OCRs Opportunities.
        ********************************************************************************************************/
        public List<Opportunity> getOpportunities() {
            return opportunityRecords.values();
        }

        /*******************************************************************************************************
        * @description Checks if this Object contains Opportunities and OCRs.
        * @return Boolean.
        ********************************************************************************************************/
        public Boolean isEmpty() {
            return opportunityRecords.isEmpty() || opportunityContactRoles.isEmpty();
        }

        /*******************************************************************************************************
        * @description Sets the OCR in paramater as a Primary OCR.
        * @param OpportunityContactRole the OCR to set as primary.
        * @return void.
        ********************************************************************************************************/
        public void makePrimary(OpportunityContactRole inputOCR) {
            OpportunityContactRole ocrToUpdate = opportunityContactRoles.get(inputOCR.Id);
            ocrToUpdate.IsPrimary = true;
            opportunityContactRolesToUpdate.put(ocrToUpdate.Id, ocrToUpdate);

            Opportunity opportunityToUpdate = opportunityRecords.get(inputOCR.OpportunityId);
            opportunityToUpdate.Primary_Contact__c = inputOCR.ContactId;
            opportunityRecordsToUpdate.put(opportunityToUpdate.Id, opportunityToUpdate);
        }

        /*******************************************************************************************************
        * @description Deletes the OCRs in paramater.
        * @param List<OpportunityContactRole> The OCRs to delete.
        * @return void.
        ********************************************************************************************************/
        public void deleteRecords(List<OpportunityContactRole> ocrsToDelete) {
            opportunityContactRolesToDelete.putAll(ocrsToDelete);
        }

        /*******************************************************************************************************
        * @description Commits the DMLs (delete/Update OCRs, update Opportunities)
        * @return void.
        ********************************************************************************************************/
        public void processDML() {
            delete opportunityContactRolesToDelete.values();
            update opportunityContactRolesToUpdate.values();
            update opportunityRecordsToUpdate.values();
        }

        /*******************************************************************************************************
        * @description Gets the duplicate primary OCRs Opportunity Ids. 
        * @param Integer The maximum records to load.
        * @return List<Opportunity> 
        ********************************************************************************************************/
        private List<Opportunity> loadOpportunities(Integer ocrsLoadSize) {
            Set<Id> opportunityIds = new Set<Id>();
            for (AggregateResult aggregateResult : [
                    SELECT OpportunityId 
                    FROM OpportunityContactRole 
                    WHERE IsPrimary = true 
                    GROUP BY OpportunityId 
                    HAVING COUNT(Id) > 1 
                    LIMIT :ocrsLoadSize
            ]) {
                opportunityIds.add((Id) aggregateResult.get('OpportunityId'));
            }
            return [
                SELECT Primary_Contact__c, (
                    SELECT OpportunityId, ContactId, Role, IsPrimary
                    FROM OpportunityContactRoles
                    WHERE IsPrimary = true
                )
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ];
        }

        /*******************************************************************************************************
        * @description Gets all the duplicate primary OCRs. 
        * @param List<Opportunity> The Opportunities with the related Primary OCRs.
        * @return List<OpportunityContactRole>
        ********************************************************************************************************/
        private List<OpportunityContactRole> loadOpportunityContactRoles(List<Opportunity> opportunityRecords) {
            List<OpportunityContactRole> result = new List<OpportunityContactRole>();
            for (Opportunity currentOpportunity : opportunityRecords) {
                result.addAll(currentOpportunity.OpportunityContactRoles);
            }
            return result;
        }
    }

    /*******************************************************************************************************
    * @description Duplicate Primary OCRs Opportunity Wrapper. It encapsulates an Opportunity and its related
    * duplicate Primary OCRs.
    ********************************************************************************************************/
    public class OpportunityPrimaryOCRs {
        private Opportunity record;

        /*********************************************************************************************************
        * @description The Constructor of OpportunityPrimaryOCRs.
        * @param Opportunity Opportunity with the related primary OCRs.
        */
        public OpportunityPrimaryOCRs(Opportunity currentOpportunity) {
            record = currentOpportunity;
        }

        /*******************************************************************************************************
        * @description Checks if the Opportunity has an OCR Role equals to the Role in the parameter.
        * @param String OCR Role.
        * @return Boolean.
        ********************************************************************************************************/
        public Boolean containsRole(String ocrRole) {
            for (OpportunityContactRole ocr : record.OpportunityContactRoles) {
                if (ocr.Role == ocrRole) {
                    return true;
                }
            }
            return false;
        }

        /*******************************************************************************************************
        * @description Gets the OCRs with blank role.
        * @return List<OpportunityContactRole> The OCRs with blank role.
        ********************************************************************************************************/
        public List<OpportunityContactRole> getBlankRole() {
            List<OpportunityContactRole> result = new List<OpportunityContactRole>();
            for (OpportunityContactRole ocr : record.OpportunityContactRoles) {
                if (String.isBlank(ocr.Role)) {
                    result.add(ocr);
                }
            }
            return result;
        }

        /*******************************************************************************************************
        * @description Gets the OCRs with Role equals to the Role in the parameter.
        * @param String OCR Role.
        * @return List<OpportunityContactRole> The OCRs with Role equals to the Role in the parameter.
        ********************************************************************************************************/
        public List<OpportunityContactRole> getRoleEquals(String ocrRole) {
            List<OpportunityContactRole> result = new List<OpportunityContactRole>();
            for (OpportunityContactRole ocr : record.OpportunityContactRoles) {
                if (ocr.Role == ocrRole) {
                    result.add(ocr);
                }
            }
            return result;
        }

        /*******************************************************************************************************
        * @description Gets the OCRs with Role not equals to the Role in the parameter.
        * @param String OCR Role.
        * @return List<OpportunityContactRole> The OCRs with Role not equals to the Role in the parameter.
        ********************************************************************************************************/
        public List<OpportunityContactRole> getRoleNotEquals(String ocrRole) {
            List<OpportunityContactRole> result = new List<OpportunityContactRole>();
            for (OpportunityContactRole ocr : record.OpportunityContactRoles) {
                if (ocr.Role != ocrRole) {
                    result.add(ocr);
                }
            }
            return result;
        }
    }

    /*******************************************************************************************************
    * @description Error Log. This class contains the logic that creates the error logs.
    ********************************************************************************************************/
    public class Errors {
        private List<Error__c> errors;
        private Set<Id> errorOpportunityRecords;

        /*********************************************************************************************************
        * @description The Constructor of Errors
        */
        public Errors() {
            errors = new List<Error__c>();
            errorOpportunityRecords = new Set<Id>();
        }

        /*******************************************************************************************************
        * @description Adds an error log for the Opportunity in the parameter.
        * @param Opportunity.
        * @return void.
        ********************************************************************************************************/
        public void add(Opportunity opportunityRecord) {
            errors.add(ERR_Handler.createJobError(
                String.format(ERROR_MESSAGE, new List<String>{opportunityRecord.Id}), 
                'DuplicateContactRoles',
                'Opportunity'
            ));
            errorOpportunityRecords.add(opportunityRecord.Id);
        }

        /*******************************************************************************************************
        * @description Checks if all the Opportunities in the parameter have error logs.
        * @param List<Opportunity>.
        * @return Boolean.
        ********************************************************************************************************/
        public Boolean containsAll(List<Opportunity> opportunityRecords) {
            return errorOpportunityRecords.containsAll((new Map<Id,Opportunity>(opportunityRecords)).keySet());
        }

        /*******************************************************************************************************
        * @description Commits the DMLs (delete/Update OCRs, update Opportunities)
        * @return void.
        ********************************************************************************************************/
        public void processDML() {
            insert errors;
        }
    }
}