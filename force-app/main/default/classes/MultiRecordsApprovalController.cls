public class MultiRecordsApprovalController {
    
    //Wrapper class to store the column values of data table
    public class SubmittedRecordsWrapper{
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String recordId;
        @AuraEnabled public String relatedTo;
        @AuraEnabled public String recordName;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public String submittercomment;
        @AuraEnabled public Date submittedDate;
        @AuraEnabled public String comments;
    }
    @AuraEnabled (cacheable=true)
    public static Integer gettotalcount()
    {
        Integer icount = 0;
        for(ProcessInstanceWorkitem ps : [SELECT Id FROM ProcessInstanceWorkitem WHERE OriginalActorId = : UserInfo.getUserId()]){
            if(ps!=null){
                icount++;
            }
        }
        return icount;
    }
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedRecords(Integer queryLimit, Integer queryOffset){
        system.debug('queryLimit'+queryLimit);
        system.debug('queryOffset'+queryOffset);
        List<SubmittedRecordsWrapper> lstSubmissionWrapper = new List<SubmittedRecordsWrapper>();
        

        for(ProcessInstanceWorkitem ps : [SELECT Id,ActorId, CreatedDate, ProcessInstance.ProcessDefinition.Name, 
            ProcessInstance.SubmittedBy.Name, ProcessInstance.SubmittedById, 
            ProcessInstance.TargetObject.Name, ProcessInstance.TargetObjectId, ProcessInstanceId FROM ProcessInstanceWorkitem ]){

                if(ps!=null){
                    SubmittedRecordsWrapper objSubmittedRecordsWrapper = new SubmittedRecordsWrapper();
                    objSubmittedRecordsWrapper.workItemId = ps.Id;
                    objSubmittedRecordsWrapper.recordId = ps.ProcessInstance.TargetObjectId;
                    objSubmittedRecordsWrapper.recordName = ps.ProcessInstance.TargetObject.Name;
                    objSubmittedRecordsWrapper.comments = '';
                    objSubmittedRecordsWrapper.submittedBy = ps.ProcessInstance.SubmittedBy.Name;
                    objSubmittedRecordsWrapper.relatedTo = getObjectName(ps.ProcessInstance.TargetObjectId);//get the object name using the record id
                    objSubmittedRecordsWrapper.submittedDate = Date.newInstance(ps.CreatedDate.year(),ps.CreatedDate.month(),ps.CreatedDate.day());
                    
                    lstSubmissionWrapper.add(objSubmittedRecordsWrapper);
                }
            }

           
               

               /*   if(!ps.steps.isEmpty()){
                    objSubmittedRecordsWrapper.submittedBy = ps.steps[0].OriginalActor.Name;
                    if(ps.steps[0].Comments == '' || ps.steps[0].Comments == null)
                    objSubmittedRecordsWrapper.submittercomment = 'No comments from submitter';
                    else
                    objSubmittedRecordsWrapper.submittercomment = ps.steps[0].Comments;
                   // lstSubmissionWrapper.add(objSubmittedRecordsWrapper);
                    
                }  */
                system.debug(lstSubmissionWrapper.size());
                
            
            return lstSubmissionWrapper;
        
        
    }
    
    public static String getObjectName(String recordId){
        //To get the label of the object name using Schema methods
        String keyPrefix = recordId.subString(0,3);
        String objectName = '';
        Map<String,Schema.SObjectType> sobjectTypeMap = Schema.getGlobalDescribe();
        for(String obj : sobjectTypeMap.keySet()){
            Schema.DescribeSObjectResult sobjectResult = sobjectTypeMap.get(obj).getDescribe();
            if(sobjectResult.getKeyPrefix() == keyPrefix){
                objectName = sobjectResult.getLabel();
                break;
            }
        }
        return objectName;
    }
    
    @AuraEnabled
    public static String processRecords(String processType,String strwraprecs){
        system.debug('processType'+processType);
        system.debug('wraprecs'+strwraprecs);
        List<SubmittedRecordsWrapper> wraprecs = (List<SubmittedRecordsWrapper>)System.JSON.deserialize(strwraprecs, List<SubmittedRecordsWrapper>.class);
        Map<string,SubmittedRecordsWrapper> mapSubmittedRecordsWrapper = new map<String,SubmittedRecordsWrapper>();
        List<String> lstWorkItemIds = new List<String>();
        for(SubmittedRecordsWrapper iwrap: wraprecs)
        {
            mapSubmittedRecordsWrapper.put(iwrap.workItemId,iwrap);
            lstWorkItemIds.add(iwrap.workItemId);
        }
        
        //Approve,reject the record programmatically
        String message = ''; 
        Integer recordsProcessed = 0;
        String comments = processType == 'Approve' ? 'Approved' : 'Rejected';
        List<Approval.ProcessWorkitemRequest> lstWorkItemRequest = new List<Approval.ProcessWorkitemRequest>();//ProcessWorkitemRequest class has methods to programmatically process submitted records
        for(String workItemId : lstWorkItemIds){
            Approval.ProcessWorkitemRequest objWorkItemRequest = new Approval.ProcessWorkitemRequest();
            if(mapSubmittedRecordsWrapper.containsKey(workItemId))
                objWorkItemRequest.setComments(mapSubmittedRecordsWrapper.get(workItemId).comments);
            else
                objWorkItemRequest.setComments(comments);
            objWorkItemRequest.setAction(processType);//approve or reject
            objWorkItemRequest.setWorkitemId(workItemId);
            lstWorkItemRequest.add(objWorkItemRequest);
        }
        Approval.ProcessResult[] lstProcessResult = Approval.process(lstWorkItemRequest,FALSE);//process method is used for approving/rejecting records depending on setAction attribute
        for(Approval.ProcessResult processResult : lstProcessResult){
            if(processResult.isSuccess()){
                recordsProcessed++;
            }
            else{
                for(Database.Error error : processResult.getErrors()){
                    message += error.getMessage();
                }
            }
        }
        if(recordsProcessed == lstWorkItemIds.size()){
            message = 'All records are '+comments+' successfully';
        }
        return message;
    }
}