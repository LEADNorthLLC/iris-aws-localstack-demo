Include (Ensemble, DSDomain)

/// Helper methods specifically for the DS project. 
Class DataService.DS.App.DSUtils Extends %RegisteredObject
{

/// Get a list of ReportingSubjects
ClassMethod GetReportingSubjects(Output pOutput As %ListOfObjects) As %Status
{
    Set tSC = $$$OK

    Set tRSubjects = ##class(%ListOfObjects).%New()

    Set SQLStatement = ##class(%SQL.Statement).%New()
    Set tSC = SQLStatement.%PrepareClassQuery("DataService.DS.Data.Config.ReportingSubject","QueryExportAll")
    If $$$ISERR(tSC) {Do $SYSTEM.Status.DisplayError(tSC) Quit tSC}
    Set rset = SQLStatement.%Execute()
    If (rset.%SQLCODE '= 0) {Quit tSC}

    While rset.%Next()
    {
        Set tRSubj = ##class(%ArrayOfDataTypes).%New()
       Set tSC = tRSubj.SetAt(rset.%Get("ID"),"ID")
       Set tSC = tRSubj.SetAt(rset.%Get("Subject"),"Subject")
       Set tSC = tRSubj.SetAt(rset.%Get("Field"),"Field")

       Set tSC = tRSubjects.Insert(tRSubj)
    }
    
    Set pOutput = tRSubjects
    Return tSC
}

/// Method to get all rule definitions as a list of those rule defs.
/// pCreator is optional, NULL is used to facilitate the class query to allow either no creator or a creator in the query.
ClassMethod GetRuleDefinitions(pCreator As %String = "NULL", pReportingSubject As %String, Output pOutput As %ListOfObjects)
{
    Set tSC = $$$OK
    Set tRuleDefs = ##class(%ListOfObjects).%New()

    Set SQLStatement = ##class(%SQL.Statement).%New()
    Set tSC = SQLStatement.%PrepareClassQuery("DataService.DS.Data.Config.RuleDefn","QueryExportAll")
    If $$$ISERR(tSC) {Do $SYSTEM.Status.DisplayError(tSC) Quit tSC}
    Set rset = SQLStatement.%Execute(pCreator,pReportingSubject)
    If (rset.%SQLCODE '= 0) {Quit tSC}

    While rset.%Next()
    {
        Set tRule = ##class(%ArrayOfDataTypes).%New()
        Set tSC = tRule.SetAt(rset.%Get("CreatedOn"),"CreatedOn")
        Set tSC = tRule.SetAt(rset.%Get("Description"),"Description")
        Set tSC = tRule.SetAt(rset.%Get("EvaluationDescription"),"EvaluationDescription")
        Set tSC = tRule.SetAt(rset.%Get("Name"),"Name")
        Set tSC = tRule.SetAt(rset.%Get("PPName"),"PPName")
        Set tSC = tRule.SetAt(rset.%Get("QualityDomain"),"QualityDomain")
        Set tSC = tRule.SetAt(rset.%Get("ShortName"),"ShortName")
        Set tSC = tRuleDefs.Insert(tRule)

    }
    
    Set pOutput=tRuleDefs
    Return tSC
}

/// Get a JSON object of rule definitions for the DS API. 
/// pCreator is optional.  
ClassMethod getRuleDefsJSON(pCreator As %String = "NULL", Output pJSONObj As %DynamicObject) As %Status
{

    /*for testing:
    w ##class(DataService.DS.App.DSUtils).getRuleDefsJSON(,.tJSON)

    */
    Set tSC = $$$OK
    Set tJSON = ##class(%Library.DynamicObject).%New() //parent json
    Set tJSON.RulesList={}


    //get the reporting subjects info.
    Set tRepSubjArray = []
    Set tReportingSubjects = ##class(%ListOfObjects).%New() 
    Set tSC = ..GetReportingSubjects(.tReportingSubjects)
    For i = 1:1:tReportingSubjects.Count() {
        //for each reporting subject, get the rule(s) with that reporting subject
        
        //set the JSON array value
        
        Set tRuleSubJSON = {}
        Set tRuleSubJSON.Subject=tReportingSubjects.GetAt(i).GetAt("Subject")
        Set tRuleSubJSON.Field=tReportingSubjects.GetAt(i).GetAt("Field")
        Set tRuleSubJSON.ReportingSubjectID=tReportingSubjects.GetAt(i).GetAt("ID")
        
        Set tRuleDefArray=[]

        
        Set tRuleDefs = ##class(%ListOfObjects).%New() 
        
        Set tSubj = tReportingSubjects.GetAt(i).GetAt("ID")
        Set tSC = ..GetRuleDefinitions(,tSubj,.tRuleDefs) 
        If (tRuleDefs.Count()>0){
            //Write !,"RAJ: subject: "_tReportingSubjects.GetAt(i).GetAt("ID")
           // Write !,"RAJ: tRuleDefs size: "_tRuleDefs.Count()
        }
        If (tRuleDefs.Count()>0){
            //loop through the ruleDefs:
            For j = 1:1:tRuleDefs.Count() {
            
                Set tRuleDefJSON = {}
                Set tRuleDefJSON.CreatedOn = tRuleDefs.GetAt(j).GetAt("CreatedOn")
                Set tRuleDefJSON.Description = tRuleDefs.GetAt(j).GetAt("Description")
                Set tRuleDefJSON.EvaluationDescription = tRuleDefs.GetAt(j).GetAt("EvaluationDescription")
                Set tRuleDefJSON.Name = tRuleDefs.GetAt(j).GetAt("Name")
                Set tRuleDefJSON.PPName = tRuleDefs.GetAt(j).GetAt("PPName")
                Set tRuleDefJSON.QualityDomain = tRuleDefs.GetAt(j).GetAt("QualityDomain")
                Set tRuleDefJSON.ShortName = tRuleDefs.GetAt(j).GetAt("ShortName")

                //add the JSON to the array.
                Set tSC = tRuleDefArray.%Push(tRuleDefJSON)
            // Write !,"RAJ: tRuleDefArray JSON: "_tRuleDefArray.%ToJSON()

            } //foreach ruleDef


            //add the array to the Subject JSON Obj
            Set tRuleSubJSON.Rules = tRuleDefArray

            //add the subject obj to the rulesList array
            Set tSC = tRepSubjArray.%Push(tRuleSubJSON)
        }
    } //foreach subject 

    //add the subject array to the parent JSON obj
    Set tJSON.RulesList=tRepSubjArray

    Set pJSONObj= tJSON
    Quit tSC
}

/// Get a JSON object of rule definitions for the DS API. 
/// pCreator is optional.  
/// MUCH Faster than the non-collection version.
ClassMethod getRuleDefsJSONCollection(pCreator As %String = "NULL", Output pJSONObj As %DynamicObject) As %Status
{
    //Set tStart = $PIECE($NOW(),",",2)
    Set tSC = $$$OK
    //need to update to include creator. 
     Set tSQL = "SELECT rd.ID as rdID  , rs.ID  as rsID , rd.CreatedOn, Description, EvaluationDescription,  Name, PPName, QualityDomain, ReportingSubject, ShortName,rs.Field as field ,rs.Subject as subject FROM DataService_DS_Data_Config.RuleDefn rd JOIN DataService_DS_Data_Config.ReportingSubject rs on rd.reportingSubject=rs.ID order by ReportingSubject"
    Set SQLStatement = ##class(%SQL.Statement).%New()    
    Set tSC = SQLStatement.%Prepare(.tSQL)
    Set rset = SQLStatement.%Execute()
    If (rset.%SQLCODE '= 0) {Quit tSC}

    Set tRuleDefs = ##class(%ArrayOfObjects).%New() 
    //array of objects lets you have named indexes, but not insert. 
    //listOfObjects lets you insert objects, but only at int indexes. 
  
    While rset.%Next()
    {
        //use collections, setting key = rs.ReportingSubject
        
        //create a listOfDatatypes from the RS. 
        Set tRuleDefRSArray = ##class(%ArrayOfDataTypes).%New()
        Set tRuleDefListOfObj = ##class(%ListOfObjects).%New()
        
        
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("field"),"field")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("subject"),"subject")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("CreatedOn"),"CreatedOn")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("Description"),"Description")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("EvaluationDescription"),"EvaluationDescription")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("Name"),"Name")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("PPName"),"PPName")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("QualityDomain"),"QualityDomain")
        Set tSC = tRuleDefRSArray.SetAt(rset.%Get("ShortName"),"ShortName")
       
        //we need to maintain the arrayOfObjects, and insert the rset to the ListOfObjects within the arrayofobjs("Subject") key.
        
        //Set tRuleDef = rset
        //Set tRSKey = $REPLACE(rset.%Get("rsID"),"||","~")
        Set tRSKey = rset.%Get("rsID")

        If (tRuleDefs.IsDefined(tRSKey))
        {
            Set tRuleDefListOfObj = tRuleDefs.GetAt(tRSKey)
        }
            Set tSC = tRuleDefListOfObj.Insert(tRuleDefRSArray)
           
            Set tSC = tRuleDefs.SetAt(tRuleDefListOfObj,tRSKey)
        
        
        
    }

    //zw tObj.GetAt("Document~Sections").GetAt(1).GetAt("PPName")

    //then, now that we have the reportingsubject ID as the key, just build the JSON like before, but with one loop? Should be faster since we're not doing multiple repeated sql queries?
    Set tJSON = ##class(%Library.DynamicObject).%New() //parent json
    Set tJSON.RulesList={}
    Set tRepSubjArray = []

    Set tRuleDefsKey = ""
    For {
        Set tRuleDefsObj= tRuleDefs.GetNext(.tRuleDefsKey)
        Quit:tRuleDefsKey=""
        // process array(key)
                 Set tRuleSubJSON = {}
        Set tRuleSubJSON.Subject=tRuleDefsObj.GetAt(1).GetAt("subject")
        Set tRuleSubJSON.Field=tRuleDefsObj.GetAt(1).GetAt("field")
        Set tRuleSubJSON.ReportingSubjectID=tRuleDefsKey
        
        Set tRuleDefArray=[]

        For i = 1:1:tRuleDefsObj.Count(){        



        
        Set tRuleDefJSON = {}
        Set tRuleDefJSON.CreatedOn =tRuleDefsObj.GetAt(i).GetAt("CreatedOn")
        Set tRuleDefJSON.Description = tRuleDefsObj.GetAt(i).GetAt("Description")
        Set tRuleDefJSON.EvaluationDescription =tRuleDefsObj.GetAt(i).GetAt("EvaluationDescription")
        Set tRuleDefJSON.Name =tRuleDefsObj.GetAt(i).GetAt("Name")
        Set tRuleDefJSON.PPName = tRuleDefsObj.GetAt(i).GetAt("PPName")
        Set tRuleDefJSON.QualityDomain = tRuleDefsObj.GetAt(i).GetAt("QualityDomain")
        Set tRuleDefJSON.ShortName =tRuleDefsObj.GetAt(i).GetAt("ShortName")

        //add the JSON to the array.
        Set tSC = tRuleDefArray.%Push(tRuleDefJSON)
       
        } 
     //for each rule.
         //add the array to the Subject JSON Obj
            Set tRuleSubJSON.Rules = tRuleDefArray

            //add the subject obj to the rulesList array
            Set tSC = tRepSubjArray.%Push(tRuleSubJSON)
    }
    //foreach subject 

    //add the subject array to the parent JSON obj
    Set tJSON.RulesList=tRepSubjArray
    Set pJSONObj= tJSON
    //Set tEnd = $PIECE($NOW(),",",2)
  //  Set tDuration = tEnd-tStart
  //  Write "Time: "_+tDuration
    Quit tSC
}

/// Add a ruleprofile and a list of rules to it. If the ruleprofile exists, just add the rules. If it doesn't exist, create and add. 
/// Rules is a list in JSON format, expecting rule Definition name. 
///         Example JSON: (using a list of rules with keyvalues to support adding new rules/ruledefs in the future.
///        {
///       Rules:[
///               {
///                   RuleDefName:"Allergies- Allergy: Is Populated"
///               },
///               {
///                   RuleDefName:"Documents- DocumentTime: Is Populated"
///               }
///           ]
///        }
ClassMethod AddUpdateRuleProfile(pRuleProfileName As %String, pRules As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    // do something

    //check if ruleprofile exists. Copying from RuleProfile.AddUpdateRuleProfile
    Try {
		If ##class(DataService.DS.Data.Config.RuleProfile).NameOpen(pRuleProfileName) {
          //  Write !,"rule profile ID: "_tRuleProfId
          //  Write !,"rule profile name: "_pRuleProfileName,!
			Set tRuleProf = ##class(DataService.DS.Data.Config.RuleProfile).NameOpen(pRuleProfileName)
         //   ZWrite tRuleProf
		} 
		Else {
           // Write !,"trying to create new"
			Set tRuleProf = ##class(DataService.DS.Data.Config.RuleProfile).%New()
			Set tRuleProf.Name = pRuleProfileName
		}
    

        //check if ruledef exists is done as part of CreateRule.

            
            

        //iterate over the RulesArray.
        Set tRuleArray = ##class(%DynamicArray).%New()
        Set tRuleArray = pRules.Rules
        Set tRuleIter = tRuleArray.%GetIterator()
        While tRuleIter.%GetNext(.key,.value){
            $$$ThrowOnError(##class(DataService.DS.Data.Config.Rule).CreateRule(value.RuleDefName,,,,.tRule)) 
            $$$ThrowOnError(tRuleProf.AddRule(tRule))
            $$$ThrowOnError(tRuleProf.%Save())
        }
    }
        Catch Ex {
		Set tSC = Ex.AsStatus()
	}	
    
    Return tSC
}

ClassMethod SendReportToDynamoDB(pRequest As DataService.DS.Prod.Msg.RecordResultRequest, pReport As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{

    Set tSC = $$$OK
   $$$LOGINFO("Building report to Dynamo")
   Set tSC = ..TransformRecEvalResponseToDynamoJSON(pRequest,pReport,.tJSONObj)

    $$$LOGINFO("JSON Report")
    $$$LOGINFO(tJSONObj.%ToJSON())

    Try {
        $$$LOGINFO("RAJ1")
         $$$ThrowOnError(##class(DS.Util).writeToDynamoDB("DS_Result",tJSONObj))
         $$$LOGINFO("RAJ2")
    }
    Catch ex {
        Set tSC=ex.AsStatus()
        $$$LOGERROR("Error writing to DynamoDB: "_tSC)
        
    }
       
    Quit tSC
}

/* RuleName (String) 
MessageId (String) - Unique identifier_YYYYMMDDHHMM This should be an id generated and passed from the UI
RuleName (String) 
RuleFailureCategory(String) - Fail, Warning - The thought was this would set whether we wanted to "Fail" the message based on that rule. The value is either "Fail" or "Warning"
Status (String) - Pass or Fail - Wow, that's an interesting logic puzzle. Yes, let's translate to Pass or Fail. 
SourceProfileName (String) - Concatenated source and profile name  - Concat SourceProvider and RuleProfileName. Any separator? Maybe underscore between them for easy parsing? 
DataType (String) - CCD or HL7 - Pulling from doctype: "CCDA" Ok? OK
BatchId (String) - Contains batch id or snapshot value - From Request.
FieldValue (String) - Contains value of evaluated field - What are we looking for here? Field Evaluator ID? (Ex. Allergies||Allergy||HS.SDA3.Allergy) 
SuccessTarget(String) - Not sure what this is? Hardcoded to S3:cvs_valid_msgs?
FailTarget(String) - See SuccessTarget
FailTarget(String) - See SuccessTarget */
/// Transform the RecEvalResponse to a JSON object for DynamoDB submission..
/// /// Modify result. Takes in a DataService.DS.Prod.Msg.RecEvalResponse, and creates a JSON object with the results.
/// JSON object is in the format:
/// {
///     "Item": [
///         {
///          RULE...
///         },
///         {
///         RULE...
///          }
///    ]
/// 
/// 
/// MessageId (String) - Unique identifier_YYYYMMDDHHMM Coming from Request,  OriginalFileName?
ClassMethod TransformRecEvalResponseToDynamoJSON(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, pResponse As DataService.DS.Prod.Msg.RecEvalResponse, Output pJSONObj As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    
    //create the JSON object
    Set tJSONObj = ##class(%DynamicObject).%New()
    Set tJSONObj={} //top level object
    Set tJSONObj.Item=[]

    //iterate over the response record tree, and get the rules.
    Set tRules = ##class(%DynamicArray).%New()
    Set tSC = ..GetRulesFromRecordTree(pResponse.RecordTree,.tRules)
        //Testing the ojbect
    Set iterator=tRules.%GetIterator()
    Set tStr = ""
    While iterator.%GetNext(.key,.val) { Set tStr = tStr_"Property name: """_key_""", value: "_val.RuleName_" Result:"_val.Result }

    $$$LOGINFO("Rules: "_tStr)
    //values that are reused.

    //messageID - unique identifier_YYYYMMDDHHMM - Using the test name for now.  This should be an id generated and passed from the UI
    Set tMessageID = pRequest.RecordName_"_"_$ZSTRIP($ZDATETIME($HOROLOG, 3), "*p") 
    Set tDataType = $PIECE(pRequest.RecordRepresentationClass,":",2) //CCDA or HL7, getting the subpart of the recordRepresenationClass
    Set tSourceProfileName = pRequest.SourceProvider_"_"_pRequest.RuleProfileName
    Set tBatchID = pRequest.BatchId
    Set tSuccessTarget = "S3:cvs_valid_msgs"
    Set tFailureTarget = "S3:cvs_invalid_msgs"

    Set rIterator=tRules.%GetIterator()
    While rIterator.%GetNext(.key,.tRule) {
        $$$LOGINFO("RuleName: "_tRule.RuleName)
      

        //build the JSON object for each rule. 
        Set tRuleJSON = ##class(%Library.DynamicObject).%New()
        
        //in each rule, there individual items are objects, Value is "S" for string.
        Set tRuleJSON.RuleResultID={}.%Set("S",tMessageID_tRule.RuleName_key) //Unique identifier, messageID+RuleName+Iterator. Should be unique.
        Set tRuleJSON.MessageID={}.%Set("S",tMessageID) 
        
        Set tRuleJSON.RuleName={}.%Set("S",tRule.RuleName)
        Set tRuleJSON.RuleFailureCategory={}.%Set("S",tRule.Category) //IDK if this is right, but it's what we have.
        Set tRuleJSON.Status={}.%Set("S", $SELECT(tRule.Result=0:"False", 1:"True")) //True or false.
        Set tRuleJSON.SourceProfileName={}.%Set("S",tSourceProfileName) //Rule Profile
        Set tRuleJSON.DataType={}.%Set("S",tDataType) //CCDA or HL7
        Set tRuleJSON.BatchId={}.%Set("S",tBatchID) //Batch ID
        Set tRuleJSON.FieldValue={}.%Set("S",tRule.FieldEvaluatorId) //Field evaluator ID

        Set tRuleJSON.LocationInOriginal={}.%Set("S",..GetFieldLocationByFieldEvaluatorID(tRule.FieldEvaluatorId)) //Location in original CDA. Ideally we'd want the full path, but that's not possible right now. 
        //This is going to have to be the relative location for now. Use FieldEvaluatorID to get the Location. 
        Set tRuleJSON.SuccessTarget={}.%Set("S",tSuccessTarget) //Success Target - AWS S3 D
        Set tRuleJSON.FailTarget={}.%Set("S",tFailureTarget) //Fail Target


        //add the rule to the JSON object.
        Set tSC = tJSONObj.Item.%Push(tRuleJSON)
    }

  
    Set pJSONObj = tJSONObj
    Quit tSC
}

/// Class method to get the location from a field evaluator ID.
ClassMethod GetFieldLocationByFieldEvaluatorID(pFieldEvalID As %String) As %String
{
    Set tSC = $$$OK
    Set tEval = ##class(DataService.DS.Data.Config.FieldEvaluator).%OpenId(pFieldEvalID)
    Quit tEval.Location
}

/// Get the rules in the response record tree
/// Similar to ##class(DataService.DS.App.ResultUtils).GetRuleArrayFromRecordTree, but instead of just getting the rule name, return the full rule result.
ClassMethod GetRulesFromRecordTree(pRecordTree As DataService.DS.Data.Serial.RecordTreeRef, ByRef pRules As %DynamicArray) As %Status
{
    Set tSC = $$$OK

	Try {
		$$$LOGINFO("RecordReporesenationClass: "_pRecordTree.RecordRepresentationClass)
		If $CLASSNAME(pRecordTree) '= "DataService.DS.Data.Serial.RecordTreeRef" {
			$$$ThrowOnError($$$ERROR("Invalid record tree submit"))
		}
        $$$LOGINFO("RuleErrorCount: "_pRecordTree.RuleErrors.Count())
		For i=1:1:pRecordTree.RuleErrors.Count() {
            $$$LOGINFO("RuleErrorName: "_pRecordTree.RuleErrors.GetAt(i).RuleName)
            Set tSC = pRules.%Push(pRecordTree.RuleErrors.GetAt(i))
			//Set tRules(pRecordTree.RuleErrors.GetAt(i).RuleName) = pRecordTree.RuleErrors.GetAt(i)		
		}
        $$$LOGINFO("RuleCount: "_pRecordTree.Rules.Count())
		For i=1:1:pRecordTree.Rules.Count() {
            $$$LOGINFO("Rule Name: "_pRecordTree.Rules.GetAt(i).RuleName)
            Set tSC = pRules.%Push(pRecordTree.Rules.GetAt(i))
			//Set tRules(pRecordTree.Rules.GetAt(i).RuleName) = pRecordTree.Rules.GetAt(i)			
		}
        $$$LOGINFO("RecordChildrenCount: "_pRecordTree.RecordChildren.Count())
		For i=1:1:pRecordTree.RecordChildren.Count() {
            $$$LOGINFO("Getting RecordChildren")
			Set tSC= ..GetRulesFromRecordTree(pRecordTree.RecordChildren.GetAt(i),.pRules)
		}
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}

	Quit tSC
}

/// Helper method to get zwrite output into a string.
/// https://community.intersystems.com/post/get-zw-display-variable#comment-252986
ClassMethod ZWritetostring(pObj = "") As %String
{
 #Dim result as %String
 #Dim i,lineCount as %Integer
 
 Kill ^SPOOL($JOB)
 Open 2:$JOB
 Use 2
 ZWrite pObj
 Set result=""
 Set lineCount=$SELECT($DATA(var):$ZA-1,1:$ZA-2)
 Close 2
 For i=1:1:lineCount Set result=result_^SPOOL($JOB,i)	
 Return result
}

}
