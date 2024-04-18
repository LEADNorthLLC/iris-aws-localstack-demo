Include DSDomain

Class DataService.DS.Data.Config.RuleDefn Extends (%Persistent, %XML.Adaptor, DataService.DS.Data.Abstract.TrackMetadata)
{

Property ReportingSubject As DataService.DS.Data.Config.ReportingSubject [ Required ];

Index ReportingSubject On ReportingSubject;

/// Proper full name of the rule.  This name is calulated as follows <ReportingSubject>: <ShortName>
Property Name As %String(MAXLEN = 500, XMLPROJECTION = "none") [ Calculated, SqlComputeCode = {Set {Name} = ##class(DataService.DS.Data.Config.RuleDefn).GetName({ReportingSubject},{ShortName})}, SqlComputed ];

Index Name On Name [ Unique ];

/// Name of the rule describing the action performed by the rule.  E.g.  "is populated", "is valid date/time", etc...
Property ShortName As %String(MAXLEN = 500) [ Required ];

Index ShortName On ShortName;

/// Pretty print version of the name used for UI display purposes
Property PPName As %String(MAXLEN = 500);

Property QualityDomain As %String(VALUELIST = ",Completeness,Uniqueness,Validity,Accuracy,Consistency,RefIntegrity");

Property Description As %String(MAXLEN = 2000);

/// Defaults to 1 if not otherwise defined in the template
Property DefaultWeight As %Float;

/// Provide a description of how the evaluation method is executed and the data that must be made available to it by the
/// associated JSON proxy Object.  The evaluation string must result in a boolean value
/// EXAMPLE
/// 		"This rule checks for the presence of any string in the "Value" property of the JSON proxy Object.  If a value is 
/// 			found it will return 1 otherwise 0"
Property EvaluationDescription As %String(MAXLEN = 2000);

/// Code executed against input data, which must return a boolean in the TestResult property.  The following variables are available
/// 		pRequest - DataService.DS.Prod.Msg.FieldEvalRequest containing the raw JSON of the Dynamic Object
/// 					and the RuleDefn for which the evaluation is being performed, the BatchId, Subject, and Field.
/// 		FieldData - Proxy Object created by FieldEvaluator
/// EXAMPLE
/// 	Set TestResult = FieldData.Value=""
Property CallbackSimple As %String(MAXLEN = 500);

/// The logic for rule definition execution can be contained as COS in the Evaluation property or maintained through an Evaluation Programming
/// point.   If both properties are defined the CallbackAdvanced will take precedence.
Property CallbackAdvanced As %String;

/// Indicates if this rule can accuratly be determined before the batch is completed
Property CalculationInBatch As %Boolean [ InitialExpression = 0 ];

Property RuleTemplate As %String(MAXLEN = 500);

Property Tags As list Of %String(MAXLEN = 50);

Index Tags On Tags(ELEMENTS);

Property SettingContext As DataService.DS.Data.Config.SettingsContext;

/// Helper method used to determine the proper name of a record given it's reporting subject and short name
ClassMethod GetName(pReportingSubject As %String, pShortName As %String) As %String
{
	Quit $REPLACE(pReportingSubject,"||","- ")_": "_pShortName
}

ClassMethod AddUpdateRuleDefn(pRuleShortName = "", pPPrintName = "", pWeight = "", pDescription = "", pQualDom = "", pCallbackSimple As %String = "", pCallbackAdvanced As %String = "", pEvaluationDescription = "", pSubject = "", pField = "", pBatchCalculation As %Boolean = 0, pRuleTemplate As %String = "", pCreatedBy As %String = "", pTags As %ListOfDataTypes = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set tReportingSubject = ##class(DataService.DS.Data.Config.ReportingSubject).SubjectFieldOpen(pSubject,pField)
		If '$ISOBJECT(tReportingSubject) {
			$$$ThrowOnError($$$ERROR("Subject:'"_pSubject_"',Field:'"_pField_"' not found"))
		}
		
		#; Retrieve the Rule Template and set the Rule Definition parameters to that of the template
		If (pRuleTemplate '= "")
		{
			#dim tTemplate As DataService.DS.Data.Config.RuleTemplate
			Set tTemplate = ##class(DataService.DS.Data.Config.RuleTemplate).GetRuleTemplate(pRuleTemplate)
			If ('$ISOBJECT(tTemplate)){
				$$$ThrowOnError($$$ERROR("Failed to retrieve Rule Template information for Template: "_pRuleTemplate))	
			} 
		Else {
				Set:pBatchCalculation="" pBatchCalculation = tTemplate.CalculationInBatch
				Set:pRuleShortName="" pRuleShortName = tTemplate.ShortName
				Set:pDescription="" pDescription =  ##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(tReportingSubject,tTemplate.Description)
				Set:pWeight="" pWeight = tTemplate.DefaultWeight
				Set:pQualDom="" pQualDom = tTemplate.QualityDomain
				Set:pCallbackAdvanced="" pCallbackAdvanced = tTemplate.CallbackAdvanced
				Set:pCallbackSimple="" pCallbackSimple = ##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(tReportingSubject, tTemplate.CallbackSimple)
				Set:pEvaluationDescription="" pEvaluationDescription = ##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(tReportingSubject, tTemplate.EvaluationDescription)
				Set:pPPrintName="" pPPrintName = ##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(tReportingSubject, tTemplate.PPName)
				Set:('$ISOBJECT(pTags)||(pTags.Count()=0)) pTags = tTemplate.Tags
			}
		}
		
		Set tRuleName = ..GetName(tReportingSubject.%Id(),pRuleShortName)
		If ##class(DataService.DS.Data.Config.RuleDefn).NameExists(tRuleName,.tRuleDefnId) {
			Set tRuleDefn = ##class(DataService.DS.Data.Config.RuleDefn).%OpenId(tRuleDefnId)
		} 
		Else {
			Set tRuleDefn = ##class(DataService.DS.Data.Config.RuleDefn).%New()
			Set tRuleDefn.ShortName = pRuleShortName
		}

		If (pCallbackAdvanced '= "") && ('##class(DataService.DS.Data.Config.RuleCallback).%ExistsId(pCallbackAdvanced)) {
			$$$ThrowOnError($$$ERROR("'"_pCallbackAdvanced_"' does not reference a valid rule programming point."))
		}
		
		Set tRuleDefn.DefaultWeight = $CASE(pWeight="",1:1,:pWeight)
		Set tRuleDefn.Description = pDescription
		Set tRuleDefn.CallbackSimple = pCallbackSimple
		Set tRuleDefn.CallbackAdvanced = pCallbackAdvanced
		Set tRuleDefn.EvaluationDescription = pEvaluationDescription		
		Set tRuleDefn.ReportingSubject = tReportingSubject
		Set tRuleDefn.QualityDomain = pQualDom
		Set tRuleDefn.CalculationInBatch = pBatchCalculation
		Set tRuleDefn.RuleTemplate = pRuleTemplate
		Set tRuleDefn.CreatedBy = pCreatedBy
		Set tRuleDefn.PPName = pPPrintName
		Set:$ISOBJECT(pTags) tRuleDefn.Tags = pTags
		
		$$$ThrowOnError(tRuleDefn.%Save())
		
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}	
	Quit tSC
}

/// Helper method called by DataService.DS.App.Utils used to import a single record based off it's import specs
ClassMethod ImportRecord(pRuleDefn As DataService.DS.Data.Config.RuleDefn, pAction As %String, ByRef pNewRecCt As %Integer, ByRef pUpdRecCt As %Integer, pVerbose As %Boolean)
{
	Set tSC = $$$OK
	Try {
		If '##class(DataService.DS.Data.Config.ReportingSubject).SubjectFieldExists(pRuleDefn.ReportingSubject.Subject,pRuleDefn.ReportingSubject.Field,.tReportingSubjectId) {
			$$$ThrowOnError($$$ERROR("Invalid reporting subject: "_pRuleDefn.ReportingSubject.Subject_":"_pRuleDefn.ReportingSubject.Field))
		}
		Set tReportingSubject = ##class(DataService.DS.Data.Config.ReportingSubject).%OpenId(tReportingSubjectId)
		
		#;Need short name to check for rule existance
		If pRuleDefn.ShortName="" && (pRuleDefn.RuleTemplate'="") {
			#Dim tTemplate as DataService.DS.Data.Config.RuleTemplate
			Set tTemplate = ##class(DataService.DS.Data.Config.RuleTemplate).GetRuleTemplate(pRuleDefn.RuleTemplate)
			Set pRuleDefn.ShortName = tTemplate.ShortName
		}
		Set tRuleName = ..GetName(tReportingSubject.%Id(),pRuleDefn.ShortName)
		If ((pAction = "IGNORE") && ..NameExists(tRuleName)) {
			Quit
		} ElseIf ((pAction = "UPDATE") && ..NameExists(tRuleName)) {
			If pVerbose Write !,"Retrieving profile:'"_tRuleName_"' for update"
			Set tCopyRuleDefn = pRuleDefn.%ConstructClone()
			$$$ThrowOnError(##class(DataService.DS.Data.Config.RuleDefn).AddUpdateRuleDefn(tCopyRuleDefn.ShortName,tCopyRuleDefn.PPName, tCopyRuleDefn.DefaultWeight,tCopyRuleDefn.Description,tCopyRuleDefn.QualityDomain,tCopyRuleDefn.CallbackSimple,tCopyRuleDefn.CallbackAdvanced,tCopyRuleDefn.EvaluationDescription,tCopyRuleDefn.ReportingSubject.Subject,tCopyRuleDefn.ReportingSubject.Field,tCopyRuleDefn.CalculationInBatch,tCopyRuleDefn.RuleTemplate,tCopyRuleDefn.CreatedBy, tCopyRuleDefn.Tags))
			Set pUpdRecCt = $INCREMENT(pUpdRecCt)
		} 
		Else {
			$$$ThrowOnError(##class(DataService.DS.Data.Config.RuleDefn).AddUpdateRuleDefn(pRuleDefn.ShortName,pRuleDefn.PPName ,pRuleDefn.DefaultWeight,pRuleDefn.Description,pRuleDefn.QualityDomain,pRuleDefn.CallbackSimple,pRuleDefn.CallbackAdvanced,pRuleDefn.EvaluationDescription,pRuleDefn.ReportingSubject.Subject,pRuleDefn.ReportingSubject.Field,pRuleDefn.CalculationInBatch,pRuleDefn.RuleTemplate,pRuleDefn.CreatedBy,pRuleDefn.Tags))
			
			Set pNewRecCt = $INCREMENT(pNewRecCt)
		}
		If pVerbose Write !,"Rule Defn:'"_tRuleName_"' imported"
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

Method FormatForExport() As %Status
{
	Set tSC = $$$OK
	Try {
		
		Set ..CreatedOn = ""
		Set ..LastUpdatedOn = ""
		Set ..ReportingSubject.CreatedBy = ""
		Set ..ReportingSubject.CreatedOn = ""
		Set ..ReportingSubject.LastUpdatedOn = ""
		Set ..ReportingSubject.IsPlural = ""
		Set ..ReportingSubject.DataType = ""
		Set ..ReportingSubject.ParentObjectType = ""
			
		If ..RuleTemplate '= "" {
			Set tTemplate = ##class(DataService.DS.Data.Config.RuleTemplate).%OpenId(..RuleTemplate)
			If (tTemplate.CalculationInBatch = ..CalculationInBatch) {
				Set ..CalculationInBatch = ""
			} ElseIf (tTemplate.CalculationInBatch = "") && (..CalculationInBatch=0) {
				Set ..CalculationInBatch = ""
			}
			If (tTemplate.DefaultWeight = ..DefaultWeight) Set ..DefaultWeight = ""
			If (##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(..ReportingSubject,tTemplate.Description) = ..Description) Set ..Description = ""
			If (##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(..ReportingSubject, tTemplate.CallbackSimple) = ..CallbackSimple) Set ..CallbackSimple = ""
			If (##class(DataService.DS.Data.Config.RuleTemplate).ReplaceKeysInDescription(..ReportingSubject, tTemplate.EvaluationDescription) = ..EvaluationDescription) Set ..EvaluationDescription = ""
			If (tTemplate.QualityDomain = ..QualityDomain) Set ..QualityDomain = ""
			If (tTemplate.ShortName = ..ShortName) Set ..ShortName = ""
			If (tTemplate.Tags.Count()>0) {
				#;Turn Template Tags into ordered string
				For i=1:1:tTemplate.Tags.Count() {
					Set tTempArrTag(tTemplate.Tags.GetAt(i))=1
				}
				Set tTag = "",tTempTagStr=""
				For {Set tTag = $ORDER(tTempArrTag(tTag))
					Quit:(tTag = "")
					Set tTempTagStr = tTempTagStr_"^"_tTag
				}
				#;Turn RuleDefn Tags into ordered string
				For i=1:1:..Tags.Count() {
					Set tRuleArrTag(..Tags.GetAt(i))=1
				}
				Set tTag = "",tRuleTagStr=""
				For {Set tTag = $ORDER(tRuleArrTag(tTag))
					Quit:(tTag = "")
					Set tRuleTagStr = tRuleTagStr_"^"_tTag
				}
				If tTempTagStr = tRuleTagStr $$$ThrowOnError(..Tags.Clear())
			}
		}		
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	
	Quit tSC
}

/// EXAMPLE
/// 	$$$ThrowOnError(##class(DataService.DS.Data.Config.RuleDefn).GetOrphanedRuleDefinitions(.tRules))
ClassMethod GetOrphanedRuleDefinitions(Output ResultList As %ListOfObjects) As %Status
{
	Set tSC = $$$OK
	Try
	{
		Set ResultList = ##class(%ListOfObjects).%New()
		Set statement=##class(%SQL.Statement).%New()
		$$$ThrowOnError(statement.%PrepareClassQuery("DataService.DS.Data.Config.RuleDefn","OrphanedRuleDefinitions"))
		
		
		Set rs = statement.%Execute()
		If rs.%SQLCODE < 0 {
			$$$ThrowOnError($$$ERROR("OrphanedRuleDefinitions query not successful - SQLCODE: "_rs.%SQLCODE))	
		}
		
		While rs.%Next() {
    		$$$ThrowOnError(ResultList.Insert(##class(DataService.DS.Data.Config.RuleDefn).%OpenId(rs.%Get("ID"))))
 		}
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()	
	}
	Quit tSC
}

/// Invokes the FindIncompleteBuild query, then builds a response object containing the
/// Rules/Reporting Subjects and their missing Record Representation Classes
/// Ex:
/// 		{"Rules":[
/// 			{"Name":"Patient- Addresses.State: All Have Full or Abbrev State", "ReportingSubject":"Patient||Addresses.State", "MissingRecRepClasses":"SDA"},
/// 			{"Name":"Allergies- Allergy: Is Valid", "ReportingSubject":"Allergies||Allergy", "MissingRecTypes":"HSHI"},
/// 			{"Name":"CarePlans- Organizations.ActionCode: Is Unique", "ReportingSubject":"CarePlans||Organizations.ActionCode", "MissingRecRepClasses":"HSHI,SDA"},
/// 		]}
/// 	The 2nd paramter controls exporting the data as either JSON or an XML enabled reporting class - DataService.DS.Data.Reports.IncompleteBuild
/// EXAMPLE
/// 		$$$ThrowOnError(##class(DataService.DS.Data.Config.RuleDefn).GetIncompleteBuild(.tRules,0))
ClassMethod GetIncompleteBuild(ByRef Rules As %ObjectHandle, pOutputAsJSON As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Set Rules = $$$NULLOREF
	
	Try
	{
		Set statement=##class(%SQL.Statement).%New()
		$$$ThrowOnError(statement.%PrepareClassQuery("DataService.DS.Data.Config.RuleDefn","FindIncompleteBuild"))
		
		
		Set rs = statement.%Execute()
		If rs.%SQLCODE < 0
		{
			$$$ThrowOnError($$$ERROR("FindIncompleteBuild query not successful - SQLCODE: "_rs.%SQLCODE))	
		}
		
		Set tRuleReport = ##class(DataService.DS.Data.Reports.IncompleteBuild).%New()
		If ('$ISOBJECT(tRuleReport))
		{
			$$$ThrowOnError($$$ERROR("Failed to instantiate report class. Last error: "_$SYSTEM.Status.GetErrorText(%objlasterror)))
				
		}
		
		Set RecordRepresentationClassesList = ""
		Set key = 1
		$$$ThrowOnError(##class(DataService.DS.Data.Config.FieldEvaluator).GetAllRecordRepresentationClasses(.RecordRepresentationClassesList))
		
		
		While rs.%Next() {
    		Set rsReportingSubject = rs.%Get("ReportingSubject")
    		Continue:rsReportingSubject=""
    		
    		Set pRule = ##class(DataService.DS.Data.Reports.IncompleteBuildRule).%New()
    		Set pRule.Name = rs.%Get("RuleName")
    		Set pRule.ReportingSubject = rsReportingSubject
    		Set tTempList = RecordRepresentationClassesList
    		
    		&sql(DECLARE FieldEval CURSOR FOR
    			SELECT RecordRepresentationClass INTO :feRecRepClass
    			FROM DataService_DS_Data_Config.FieldEvaluator
    			WHERE ReportingSubject = :rsReportingSubject)
    		&sql(OPEN FieldEval)
    		&sql(FETCH FieldEval)
    		While (SQLCODE = 0) {
	    		Set $LIST(tTempList,$LISTFIND(tTempList,feRecRepClass))=""
	    		&sql(FETCH FieldEval)
    		}
    		&sql(CLOSE FieldEval)
    		
    		Set ptr = 0
    		Set RecRepClassTemp = ""
    		While $LISTNEXT(tTempList,ptr,value) {
	    		If value '= "" {
		    		Set $LIST(RecRepClassTemp,*+1) = value
	    		}	
    		}
    		
    		Set pRule.MissingRecRepClasses = $LISTTOSTRING(RecRepClassTemp,",")
    		
    		$$$ThrowOnError(tRuleReport.Rules.SetAt(pRule,key))
    		
    		Set key = key + 1
 		}
	    If (pOutputAsJSON)
		{
    		$$$ThrowOnError(tRuleReport.GenerateJSONObject(.Rules))
    		
		}
		Else
		{
    		Set Rules = tRuleReport
		}
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked by the <METHOD>%Save</METHOD> method to 
/// provide notification that the object is being saved. It is called after 
/// the object's data has been successfully written to disk.
/// 
/// This method invalidates the sorted rule cache on the record profiles where this rule is in use.
Method %OnAfterSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSQL = "SELECT  c.RuleProfile "_
			"FROM DataService_DS_Data_Config.Rule r "_
			"LEFT JOIN DataService_DS_Data_Config.RuleProfile_IsSortedRuleCacheValid c ON r.RuleProfile = c.RuleProfile "_
			"WHERE r.RuleName = ? "_
			"AND (c.IsSortedRuleCacheValid IS NOT NULL OR c.IsSortedRuleCacheValid <> '') "_
			"GROUP BY c.RuleProfile"

	Set tRS = ##class(%SQL.Statement).%ExecDirect(,tSQL,..Name)	
	While tRS.%Next() {
		Set tRuleProfile = ##class(DataService.DS.Data.Config.RuleProfile).%OpenId(tRS.RuleProfile)
		Set tScratch = tRuleProfile.IsSortedRuleCacheValid.Clear()
		Set tScratch = tRuleProfile.%Save()
	}
	Quit $$$OK
}

/// ////////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////QUERIES///////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// 
Query OrphanedRuleDefinitions() As %SQLQuery(CONTAINID = 1, ROWSPEC = "ID:%ObjectIdentity,CallbackSimple:%String,ReportingSubject:%ObjectIdentity") [ SqlName = OrphanedRuleDefinitions, SqlProc ]
{
SELECT R.ID,R.CallbackSimple,R.ReportingSubject
FROM DataService_DS_Data_Config.RuleDefn as R
LEFT JOIN DataService_DS_Data_Config.FieldEvaluator as F
ON R.ReportingSubject = F.ReportingSubject
WHERE F.ReportingSubject IS NULL
}

/// This query identifies Rules/Reporting Subjects that do not have a complete set of 
/// Field Evaluators defined for them for each Record Type (i.e. HSHI, SDA, HL7) that
/// is currently being used in the FieldEvaluators table
/// This query relies on the assumption that there will only be a single Field Evaluator
/// for a given ReportingSubject and Record Type.  This is currently true given the unique index
/// on those two fields in the Field Evaluator class.
Query FindIncompleteBuild() As %SQLQuery(CONTAINID = 0, ROWSPEC = "RuleName:%String,ReportingSubject:%ObjectIdentity,Evaluators:%Integer") [ SqlName = FindIncompleteBuild, SqlProc ]
{
SELECT RuleName, ReportingSubject, Evaluators FROM (
SELECT R.Name As RuleName, R.ReportingSubject, COUNT(DISTINCT F.ID) As Evaluators FROM DataService_DS_Data_Config.RuleDefn As R
LEFT JOIN DataService_DS_Data_Config.FieldEvaluator As F
ON R.ReportingSubject = F.ReportingSubject
GROUP BY R.ReportingSubject
)
WHERE Evaluators NOT IN (SELECT COUNT(DISTINCT RecordRepresentationClass)
FROM DataService_DS_Data_Config.FieldEvaluator
)
}

/// Method found in all config classes used to define the export set created by a given user DataService
Query QueryExport(pCreatedBy As %String = "_SYSTEM", pRptSbj As %String) As %SQLQuery(CONTAINID = 1, ROWSPEC = "ID:%String") [ SqlName = RuleDefnQueryExport, SqlProc ]
{
	SELECT ID FROM DataService_DS_Data_Config.RuleDefn 
	WHERE CreatedBy = :pCreatedBy 
	and ReportingSubject->Subject = :pRptSbj 
	and ((RuleTemplate != 'Is Populated: Implied') OR (RuleTemplate IS NULL)) 
	ORDER BY ReportingSubject->Subject,ReportingSubject->Field
}

/// Query Method to export ruleDefinition info based on a given reportingSubject, irrespective of created by, with the option of using the CreatedBy
Query QueryExportAll(pCreatedBy As %String = "NULL", pRptSbj As %String) As %SQLQuery(CONTAINID = 1, ROWSPEC = "CreatedOn:%Library.DateTime,Description:%String,EvaluationDescription:%String,Name:%String,PPName:%String,QualityDomain:%String,ReportingSubject:%String,ShortName:%String") [ SqlName = RuleDefnQueryExportAll, SqlProc ]
{
	SELECT 
	CreatedOn, Description, EvaluationDescription,  Name, PPName, QualityDomain, ReportingSubject, ShortName 
	FROM DataService_DS_Data_Config.RuleDefn 	
	WHERE CreatedBy  = 
		CASE 
		WHEN :pCreatedBy = 'NULL' THEN CreatedBy ELSE :pCreatedBy 
		END
	AND ReportingSubject=:pRptSbj
	ORDER BY ID
}

/// Method found to define the export set of implied rules
Query QueryExportImplied(pCreatedBy As %String = "_SYSTEM") As %SQLQuery(CONTAINID = 1, ROWSPEC = "ID:%String") [ SqlName = RuleDefnQueryExportImplied, SqlProc ]
{
	SELECT ID FROM DataService_DS_Data_Config.RuleDefn 
	WHERE CreatedBy = :pCreatedBy 
	and (RuleTemplate = 'Is Populated: Implied') 
	ORDER BY ReportingSubject->Subject,ReportingSubject->Field
}

Storage Default
{
<Data name="RuleDefnDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CreatedBy</Value>
</Value>
<Value name="3">
<Value>CreatedOn</Value>
</Value>
<Value name="4">
<Value>LastUpdatedOn</Value>
</Value>
<Value name="5">
<Value>ShortName</Value>
</Value>
<Value name="6">
<Value>PPName</Value>
</Value>
<Value name="7">
<Value>QualityDomain</Value>
</Value>
<Value name="8">
<Value>Description</Value>
</Value>
<Value name="9">
<Value>DefaultWeight</Value>
</Value>
<Value name="10">
<Value>EvaluationDescription</Value>
</Value>
<Value name="11">
<Value>CallbackSimple</Value>
</Value>
<Value name="12">
<Value>CallbackAdvanced</Value>
</Value>
<Value name="13">
<Value>CalculationInBatch</Value>
</Value>
<Value name="14">
<Value>RuleTemplate</Value>
</Value>
<Value name="15">
<Value>Tags</Value>
</Value>
<Value name="16">
<Value>SettingContext</Value>
</Value>
<Value name="17">
<Value>ReportingSubject</Value>
</Value>
<Value name="18">
<Value>DefaultFailureCategory</Value>
</Value>
</Data>
<DataLocation>^DataService.DS.DaAAF0.RuleDefnD</DataLocation>
<DefaultData>RuleDefnDefaultData</DefaultData>
<ExtentSize>210</ExtentSize>
<IdLocation>^DataService.DS.DaAAF0.RuleDefnD</IdLocation>
<IndexLocation>^DataService.DS.DaAAF0.RuleDefnI</IndexLocation>
<Property name="%%CLASSNAME">
<AverageFieldSize>2</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,16,$lb("-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000"),$lb(21,21,21,21,21,21,21,21,21,21,21,21,21,21,21),$lb(758198320,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758198320))</Histogram>
<Selectivity>100.0000%</Selectivity>
</Property>
<Property name="%%ID">
<AverageFieldSize>3</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,1,0,$lb("1","14","28","42","56","70","84","98","112","126","140","154","168","182","196","210"),$lb(1,0,0,0,0,0,0,0,1,1,1,1,1,1,0),$lb(822083584,0,872415232,825491456,842530816,842530816,875692032,875692032,892731392,892731392,925892608,925892608,942931968,942931968,959971328,959971328,825307648,825360384,842399744,842399744,875560960,875560960,892600320,892600320,909639680,909639680,942800896,942800896,959840256,825832960,842084352,842084352))</Histogram>
<Selectivity>1</Selectivity>
</Property>
<Property name="CalculationInBatch">
<AverageFieldSize>2</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),$lb(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1),$lb(805306368,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,805306368))</Histogram>
<Selectivity>100.0000%</Selectivity>
</Property>
<Property name="CallbackAdvanced">
<AverageFieldSize>13.17</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" "," "," "," "," "," "," CODE IS POPULATED"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," EXTERNALID IS POPULATED"," ORG IS POPULATED"," TIMESTAMP OR INTERVAL IS VALID"," VALUE RANGE IS POPULATED"),$lb(2,2,2,2,2,1,3,14,14,14,14,1,1,1,1),$lb(536870912,0,0,0,0,0,0,0,0,0,0,0,1129268293,1145380937,1297108037,0,0,0,0,0,0,0,0,1129270608,1163416645,1163416645,1330792224,1330792224,1414090053,1414090053,1447119957,542523724))</Histogram>
<OutlierSelectivity>.361905:"Completeness"</OutlierSelectivity>
<Selectivity>3.5450%</Selectivity>
</Property>
<Property name="CallbackSimple">
<AverageFieldSize>51.05</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" "," "," "," "," "," "," "," "," "," "," SET TSC = ##CLASS(DataService.DS.APP.EVAL.CDAUTILS).ARENOSCHEMATRONERRORS(FIELDDATA,.TESTRESULT)"," SET TSC = ##CLASS(DataService.DS.APP.EVAL.SAMPLE).CHECKFORA1CTESTANDVALUE(FIELDDATA,.TESTRESULT)"," SET TSC = ##CLASS(DataService.DS.APP.RULES.DATATYPERULES).HASCODEINCODESYSTEM(FIELDDATA,PREQUEST.REPORTINGSUBJECT,.TEST"," SET TSC = ##CLASS(DataService.DS.APP.RULEUTILS).CODESYSTEMINCONFIGLISTRPTSBJ(PREQUEST.REPORTINGSUBJECT,FIELDDATA,$LB(""C"," SET TSC = ##CLASS(DataService.DS.APP.RULEUTILS).VALIDATETIMESTAMPFORMATRPTSBJ(PREQUEST,FIELDDATA,3,,,,.TESTRESULT)"," SET TSC = ##CLASS(DataService.LOCAL.APP.RULES.DATATYPERULES).ISPROVIDERVALID(FIELDDATA,PREQUEST.REPORTINGSUBJECT,.TESTR"),$lb(2,2,2,2,2,2,2,2,2,1,43,38,42,49,31),$lb(536870912,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1397052448,1128546645,1396788560,1163280716,1381321797,1395541057,1431587148,1129268293,1447119945,1146170945,1280262977,542328148))</Histogram>
<OutlierSelectivity>.657143:</OutlierSelectivity>
<Selectivity>0.8362%</Selectivity>
</Property>
<Property name="CreatedBy">
<AverageFieldSize>9.22</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" SAMPLE"," SAMPLEUSER"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"),$lb(7,1,9,9,9,9,9,9,9,9,9,9,9,9,9),$lb(542327117,0,1431520594,1396788560,1599297875,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,543118169))</Histogram>
<OutlierSelectivity>.919048:"_SYSTEM"</OutlierSelectivity>
<Selectivity>4.0476%</Selectivity>
</Property>
<Property name="CreatedOn">
<AverageFieldSize>21</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:35","2023-08-11 00:20:35"),$lb(20,20,20,20,20,20,20,20,20,20,20,20,20,18,20),$lb(842019379,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,855638016,889192448,0,0,842019379))</Histogram>
<OutlierSelectivity>.871429:"2023-08-11 00:20:33"</OutlierSelectivity>
<Selectivity>6.4286%</Selectivity>
</Property>
<Property name="DefaultWeight">
<AverageFieldSize>3.23</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(.001,.5,.5,.5,1,1,1,1,1,1,1,1,1,1,1,2),$lb(1,2,2,0,1,1,1,1,1,1,1,1,1,1,0),$lb(774910001,808464640,889192448,0,0,0,0,775225344,822083584,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,822083584,838860800,838860800))</Histogram>
<OutlierSelectivity>.766667:1</OutlierSelectivity>
<Selectivity>7.7778%</Selectivity>
</Property>
<Property name="Description">
<AverageFieldSize>82</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" CHECKS AT LEASTE ONE OF THE PROVIDERS HAS EITHER A NPI OR TAX ID ALONG WITH BOTH THE PROVIDERS FIRST AND LAST NAME"," RULE DETERMINES IF A ENCOUNTERS'S  ENCOUNTERTIME INTERVALSTART IS POPULATED."," RULE DETERMINES IF A LABORDERRESULTS'S  RESULTITEMS TESTITEMCODE IS POPULATED."," RULE DETERMINES IF A MEDICATIONS'S  EFFECTIVETIME INTERVALSTOP IS POPULATED."," RULE DETERMINES IF A OBSERVATIONS'S  OBSERVATIONVALUE  IS POPULATED."," RULE DETERMINES IF A PATIENT'S  ADDRESSES STREET IS POPULATED."," RULE DETERMINES IF A PATIENT'S  NAME  CONTAINS A COMPLETE NAME OBJECT."," RULE DETERMINES IF A PROBLEMS'S  OBSERVATIONEXTERNALID  CONTAINS A COMPLETE EXTERNALID OBJECT."," RULE DETERMINES IF A PROCEDURES'S  PROCEDURECODE  IS POPULATED."," RULE DETERMINES IF A RESULTOBSERVATION'S  RESULTINTERPRETATION  IS POPULATED."," RULE DETERMINES IF THE CODE SYSTEM IN USE IS LOINC OR SNOMED CT."," RULE DETERMINES IF THE CODE TABLE HAS CODE IN EITHER THE LOINC OR SNOMED CT CODE SYSTEM."," RULE DETERMINES IF THE COVERED MEMBER NUMBERS FOUND IN THE PAYERS SECTION CONTAINS A HICN CODE."," RULE DETERMINES IF THE SPECIFIED DATE OR TIMESTAMP IS IN THE PROPER FORMAT (YYYYMMDD, YYYYMMDD HHMMSS, ETC)."," RULE DETERMINES IF THE SPECIFIED TIMESTAMP, IF PRESENT, OCCURS WITHIN THE LAST 30 YEARS, AND IS NOT IN THE FUTURE"," VALIDATES THAT BOTH A SOURCE AND EXTRACTED REPRESENTATION WERE FOUND FOR THE ENTRY."),$lb(1,22,22,22,22,33,23,25,22,20,29,26,24,34,1),$lb(541280325,1128809795,1381321797,1162756943,1279345231,1279345231,1296385097,1296385097,1329746757,1329746757,1346458697,1094992978,1312902469,1096042821,1380926028,1112294733,1128612949,1347571523,1380275029,1092637253,1414022432,1398362964,1413562956,1145380948,1447383621,1129272901,1397769539,1145132101,1414090053,1381321797,1447119945,542523724))</Histogram>
<OutlierSelectivity>.061905:"Rule determines if the specified date or timestamp is in the proper format (yyyymmdd, yyyymmdd hhmmss, etc)."</OutlierSelectivity>
<Selectivity>0.5617%</Selectivity>
</Property>
<Property name="EvaluationDescription">
<AverageFieldSize>212.85</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" CHECK THE A1C RESULT VALUES"," THE RULE MAPS THE DOCUMENT SECTION IDS TO NAMES AND CHECKS THAT ONE OF THE RETURNED NAMES IS 'PROBLEMS'"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE SUPPORTS THE EVALUATION OF SINGULAR, PLURAL, SIMPLE, AND CODE TABLE OBJECTS HELD IN THE FIELDDATA VARIABLE.  T"," THE RULE USES THE SECTION IDENTIFIER AND THE DOCUMENT TYPE INFORMATION TO DETERMINE WHETHER EXTRACTION OF DISCRETE DATA"," THIS RULE PASSES THE OTHERORDERRESULTS'S RESULTTIME  HELD IN FIELDDATA TO A UTILITY FOR SYSTEM DATE TIME FORMAT VALIDAT"," THIS RULE PASSES THE SAMPLE'S ALLDATES  HELD IN FIELDDATA TO A UTILITY FOR SYSTEM DATE TIME RANGE VALIDATION. THE RULE "),$lb(1,10,121,121,121,121,121,121,121,121,121,121,10,3,22),$lb(541280325,1128809795,1414022432,1296126035,1398100048,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1398100048,1431520595,1159746133,1230184530,1330923589,1396788560,542394441))</Histogram>
<OutlierSelectivity>.766667:"The rule supports the evaluation of singular, plural, simple, and code table objects held in the FieldData variable.  The method uses the ReportingSubject to determine which field to use in its evaluation."</OutlierSelectivity>
<Selectivity>0.5556%</Selectivity>
</Property>
<Property name="LastUpdatedOn">
<AverageFieldSize>21</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:33","2023-08-11 00:20:35","2023-08-11 00:20:35"),$lb(20,20,20,20,20,20,20,20,20,20,20,20,20,18,20),$lb(842019379,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,855638016,889192448,0,0,842019379))</Histogram>
<OutlierSelectivity>.866667:"2023-08-11 00:20:33"</OutlierSelectivity>
<Selectivity>6.6667%</Selectivity>
</Property>
<Property name="Name">
<AverageFieldSize>49.7</AverageFieldSize>
<Selectivity>1</Selectivity>
</Property>
<Property name="PPName">
<AverageFieldSize>43.82</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" ","  ADDRESSES STREET: IS POPULATED.","  CATEGORY : HAS A SNOMED CT (2.16.840.1.113883.6.96) CODE.","  DOCUMENTTIME : IS POPULATED.","  ENCOUNTERTYPE : HAS A CPT-4 (2.16.840.1.113883.6.12) CODE.","  EXTERNALID : IS POPULATED.","  OBSERVATIONCODE : HAS A LOINC (2.16.840.1.113883.6.1) CODE.","  OBSERVATIONTIME INTERVALSTART: IS POPULATED.","  ORDERITEM : HAS A LOINC (2.16.840.1.113883.6.1) OR SNOMED CT (2.16.840.1.113883.6.96) CODE.","  PERFORMERS AND AUTHORS : HAS A NPI OR TAX CODE WITH FIRST AND LAST NAME.","  PROCEDURETIME : IS POPULATED.","  RESULTITEMS RESULTNORMALRANGE: IS POPULATED.","  RESULTSTATUS : IS POPULATED.","  RESULTVALUE : VALUE IS POPULATED."," ENTRY EXTRACTED AND MATCHED TO ITS SOURCE"," XSD XML SCHEMA VALIDATION"),$lb(1,2,2,2,3,2,13,3,2,3,2,8,8,1,1),$lb(536870912,0,541148228,1094992978,1128354885,1128354885,1146045269,1146045269,1162756943,1313034069,1481917778,1163416645,1329746757,1129268293,1414090053,1112753490,1380205906,1330791493,1346720326,1163019855,1380926277,1347571523,1380275029,1230259533,1398030676,1398030676,1447119957,542262611,1162761298,1162761298,1481851936,542659396))</Histogram>
<OutlierSelectivity>.038095:</OutlierSelectivity>
<Selectivity>0.5938%</Selectivity>
</Property>
<Property name="QualityDomain">
<AverageFieldSize>12.71</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," COMPLETENESS"," VALIDITY"," VALIDITY"," VALIDITY"," VALIDITY"," VALIDITY"),$lb(14,14,14,14,14,14,14,14,14,14,1,10,10,10,10),$lb(541282125,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1129270608,1447119945,0,0,0,0,0,0,0,0,542523724))</Histogram>
<OutlierSelectivity>.666667:"Completeness"</OutlierSelectivity>
<Selectivity>8.3333%</Selectivity>
</Property>
<Property name="ReportingSubject">
<AverageFieldSize>27.95</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("Allergies||Allergy","Document||Sections","Entry||Representation","LabOrderResults||ResultItems.TestItemCode","LabOrders||OrderItem","Medications||OrderItem","Observations||ObservationTime","OtherOrders||OrderItem","Patient||BirthTime","Patient||MaritalStatus","Problems||Category","Problems||ObservationTime.IntervalStart","Procedures||Performers","RadOrderResults||ResultTime","ResultObservation||ResultInterpretation","Section||Identifier"),$lb(0,0,0,8,0,0,1,0,9,1,10,3,0,1,0),$lb(1097624677,1097624677,1148150645,1148150645,1164866674,1164866674,1281450575,1382380405,1937538127,1281450575,1298490473,1298490473,1331852133,1651729778,1952998770,1333028965,1348564073,1114206836,1298231913,1635019109,1919902316,1130460261,1331852133,1651271021,1667589237,1349676899,1382114383,1633963890,1702065516,1382380405,1399153524,1399153524))</Histogram>
<OutlierSelectivity>.047619:"Document||Sections"</OutlierSelectivity>
<Selectivity>0.8985%</Selectivity>
</Property>
<Property name="RuleTemplate">
<AverageFieldSize>24.25</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" "," "," CODE SYSTEM IS LOINC OR SNOMED CT"," HAS LOINC OR SNOMED CT CODE"," IS POPULATED CODE"," IS POPULATED CONTACT INFO"," IS POPULATED TIMESTAMP OR INTERVAL"," IS POPULATED VALUE RANGE"," IS POPULATED: REQUIRED"," IS POPULATED: REQUIRED"," IS POPULATED: REQUIRED"," IS POPULATED: REQUIRED"," IS POPULATED: REQUIRED"," IS VALID STATE OR ABBR"," SYSTEMTIMESTAMPFORMAT: DATE OR TIME"," SYSTEMTIMESTAMPRANGE: 30 YEAR"),$lb(2,1,1,1,16,14,14,13,24,24,24,24,4,1,16),$lb(536870912,0,0,0,1129268293,1129268293,1212240672,1212240672,1230184528,1145372672,1314144579,1129270868,1414090053,1414090053,1447119957,542523724,975196741,0,0,0,0,0,0,0,0,1347375189,1447119945,1230184534,1398362964,1179603533,1380011591,542333267))</Histogram>
<OutlierSelectivity>.304762:"Is Populated: Required"</OutlierSelectivity>
<Selectivity>1.8296%</Selectivity>
</Property>
<Property name="SettingContext">
<AverageFieldSize>14,CodingSystemIsSignificant:2,DescriptionIsSignificant:2,IgnoreCodeCase:2,IgnoreCodingSystemCase:2,IgnoreDescriptionCase:2,IgnoreDescriptionWhiteSpace:2</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb($lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1),$lb(-1,-1,-1,-1,-1,-1)),$lb(22,22,22,22,22,22,22,22,22,22,22,22,22,22,22),$lb(33882629,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,33882629)),CodingSystemIsSignificant:$lb(.06666666666666666667,1,0,$lb(-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(758185984,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758185984)),DescriptionIsSignificant:$lb(.06666666666666666667,1,0,$lb(-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(758185984,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758185984)),IgnoreCodeCase:$lb(.06666666666666666667,1,0,$lb(-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(758185984,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758185984)),IgnoreCodingSystemCase:$lb(.06666666666666666667,1,0,$lb(-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(758185984,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758185984)),IgnoreDescriptionCase:$lb(.06666666666666666667,1,0,$lb(-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(758185984,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758185984)),IgnoreDescriptionWhiteSpace:$lb(.06666666666666666667,1,0,$lb(-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(758185984,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758185984))</Histogram>
<Selectivity>100.0000%,CodingSystemIsSignificant:100.0000%,DescriptionIsSignificant:100.0000%,IgnoreCodeCase:100.0000%,IgnoreCodingSystemCase:100.0000%,IgnoreDescriptionCase:100.0000%,IgnoreDescriptionWhiteSpace:100.0000%</Selectivity>
</Property>
<Property name="ShortName">
<AverageFieldSize>21.76</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" A1C NORMAL RANGE"," DOCUMENT HAS PROCEDURES SECTION"," HAS LOINC OR SNOMED CT"," IS NON-EMPTY"," IS POPULATED"," IS POPULATED"," IS POPULATED"," IS POPULATED"," IS POPULATED"," IS POPULATED CODE"," IS POPULATED EXTERNALID"," IS POPULATED TIMESTAMP OR INTERVAL"," IS VALID PROVIDER"," IS VALID SYSTEM DATE OR DATETIME"," IS VALID ZIP CODE FORMAT"," XSD VALIDATION SUCCEEDS"),$lb(1,1,1,4,14,14,14,14,13,14,14,4,10,10,1),$lb(541143363,1093747488,1146045269,1146045269,1212240672,1212240672,1230184526,1313820205,1347375189,0,0,0,0,0,0,0,0,0,541282116,1129268293,1163416645,1163416645,1414090053,1347375189,1447119945,1347571542,1398362964,1398362964,1514754080,1230184534,1481851936,542659396))</Histogram>
<OutlierSelectivity>.361905:"Is Populated"</OutlierSelectivity>
<Selectivity>1.1002%</Selectivity>
</Property>
<Property name="Tags">
<AverageFieldSize>7.63</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,8,$lb("-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000",$lb("Required"),$lb("Required"),$lb("Required"),$lb("Required"),$lb("Required"),$lb("Recommended"),$lb("Date or Time"),$lb("Date or Time")),$lb(21,21,21,21,21,21,21,0,15,15,15,15,7,5,19),$lb(758198320,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758198320,167858789,0,0,0,0,0,0,0,0,1919247360,1835363940,1869442405,1696624498,0,0,234964065))</Histogram>
<Selectivity>20.0000%</Selectivity>
</Property>
<SQLMap name="IDKEY">
<BlockCount>-72</BlockCount>
</SQLMap>
<SQLMap name="Name">
<BlockCount>-4</BlockCount>
</SQLMap>
<SQLMap name="ReportingSubject">
<BlockCount>-8</BlockCount>
</SQLMap>
<SQLMap name="ShortName">
<BlockCount>-4</BlockCount>
</SQLMap>
<SQLMap name="Tags">
<BlockCount>-4</BlockCount>
</SQLMap>
<StreamLocation>^DataService.DS.DaAAF0.RuleDefnS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
