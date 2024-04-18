Include (Ensemble, DSDomain)

Class DataService.DS.Data.Config.RuleProfile Extends (%Persistent, %XML.Adaptor, DataService.DS.Data.Abstract.TrackMetadata)
{

/// Name of this rule profile record
Property Name As %String(MAXLEN = 255);

Index Name On Name [ IdKey, Unique ];

/// Description of the profile's use
Property Description As %String(MAXLEN = 500);

/// This property indicates if SortedRuleCache is invalid for a given RecordRepresentationClass.  An empty or false flag indicates the SortedRuleCache 
/// needs to be rebuilt.  This property is set durring library load activities that invalidate the SortedRuleCache
/// Array is built using the "RecordRepresentationClass" string
Property IsSortedRuleCacheValid As array Of %Boolean;

/// This property should not be set directly.  It is used to improve the performance of the RecordEvaluator by sorting field evalautors and rules in
/// a manner that reduces global hits.   This array is calculated and stored at runtime by the first message accessing the rule profile when 
/// the IsSortedRuleCacheValid is marked false.
/// Array is built using the "RecordRepresentationClass" string
Property SortedRuleCache As array Of DataService.DS.Data.Serial.SortedRecordRepresentationClass;

/// This property should not be set directly.   It is used in the maintaince of the the SortedRuleCache.
Property MaintainCache As %Boolean;

/// Instances of rules that are part of this profile
Relationship Rules As DataService.DS.Data.Config.Rule [ Cardinality = children, Inverse = RuleProfile ];

/// Determines whether to process SDAs that were automatically transformed from CDA documents
Property ProcessSDAEntries As %Boolean [ InitialExpression = 1 ];

/// Creator method for an empty rule profile
ClassMethod AddUpdateRuleProfile(pName, pDescription) As %Status
{
	Set tSC = $$$OK
	Try {
		If ##class(DataService.DS.Data.Config.RuleProfile).NameOpen(pName,.tRuleProfId) {
			Set tRuleProf = ##class(DataService.DS.Data.Config.RuleProfile).%OpenId(tRuleProfId)
		} 
		Else {
			Set tRuleProf = ##class(DataService.DS.Data.Config.RuleProfile).%New()
			Set tRuleProf.Name = pName
		}
		
		Set tRuleProf.Description = pDescription
		$$$ThrowOnError(tRuleProf.%Save())
		

	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}	
	Quit tSC
}

/// Method to safely add a rule and prevent duplication.
Method AddRule(pRule As DataService.DS.Data.Config.Rule) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tRuleDefnName = pRule.RuleDefn.Name
		
		Set tDup = 0
		For i=1:1:..Rules.Count() {
			If ..Rules.GetAt(i).RuleDefn.Name = tRuleDefnName {
				Set tDup = 1
			}
		}
		If 'tDup {
			$$$ThrowOnError(..Rules.Insert(pRule))
				
		}
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Helper method called by DataService.DS.App.Utils used to import a single record based off it's import specs
ClassMethod ImportRecord(pRuleProfile As DataService.DS.Data.Config.RuleProfile, pAction As %String, ByRef pNewRecCt As %Integer, ByRef pUpdRecCt As %Integer, pVerbose As %Boolean)
{
	Set tSC = $$$OK
	Try {
		If ((pAction = "IGNORE") && ..NameExists(pRuleProfile.Name)) {
			Quit
		} ElseIf ((pAction = "UPDATE") && ..NameExists(pRuleProfile.Name)) {
			If pVerbose Write !,"Retrieving profile:'"_pRuleProfile.Name_"' for update"
			Set tRuleCopy = pRuleProfile.%ConstructClone()
			Set pRuleProfile = ..NameOpen(pRuleProfile.Name)
			Set pRuleProfile.Description = tRuleCopy.Description
			Set pRuleProfile.CreatedBy = tRuleCopy.CreatedBy
			Set pRuleProfile.ProcessSDAEntries = tRuleCopy.ProcessSDAEntries
			Set tRuleList = tRuleCopy.Rules.%ConstructClone()
			$$$ThrowOnError(pRuleProfile.Rules.Clear())
			
			For i = 1:1:tRuleList.Count() {
				$$$ThrowOnError(pRuleProfile.AddRule(tRuleCopy.GetAt(i).RuleDefn.Name))
				
			}
			Set pUpdRecCt = $INCREMENT(pUpdRecCt)
			$$$ThrowOnError(pRuleProfile.%Save())
			
		} 
		Else {
			Set pNewRecCt = $INCREMENT(pNewRecCt)
			
			#;Lookup rules based on rule defn name (ignoring the full Rules XDatablock defn.)
			Set tRuleList = pRuleProfile.Rules.%ConstructClone()
			$$$ThrowOnError(pRuleProfile.Rules.Clear())
			
			For i = 1:1:tRuleList.Count() {
				$$$ThrowOnError(pRuleProfile.AddRule(tRuleList.GetAt(i).RuleDefn.Name))
				
			}
			$$$ThrowOnError(pRuleProfile.%Save())
			
		}
		If pVerbose Write !,"Rule profile:'"_pRuleProfile.Name_"' imported"
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Helper method called by DataService.DS.App.Utils used to import a single record based off it's import specs
ClassMethod ImportAssignment(pRuleAssign As DataService.DS.Data.Default.Loader.RuleAssignment, pAction As %String, ByRef pNewRecCt As %Integer, ByRef pUpdRecCt As %Integer, pVerbose As %Boolean)
{
	Set tSC = $$$OK
	Try {
		Set tProfile = ##class(DataService.DS.Data.Config.RuleProfile).NameOpen(pRuleAssign.RuleProfileName)
		If '$ISOBJECT(tProfile) $$$ThrowOnError($$$ERROR("Rule profile by the name:'"_pRuleAssign.RuleProfileName_"' cannot be found"))
	
		If pAction = "DELETE" {
			$$$ThrowOnError(tProfile.Rules.Clear())	
		}
		
		For i = 1:1:pRuleAssign.Rules.Count() {
			Set tLoadRule = pRuleAssign.Rules.GetAt(i)
			
			If tLoadRule.Name = "" {
				Set tReportingSubjectId = tLoadRule.ReportingSubject.Subject_"||"_tLoadRule.ReportingSubject.Field
				Set tLoadRule.Name = ##class(DataService.DS.Data.Config.RuleDefn).GetName(tReportingSubjectId,tLoadRule.ShortName)
			}
			#;Create Rule record
			$$$ThrowOnError(##class(DataService.DS.Data.Config.Rule).CreateRule(tLoadRule.Name,tLoadRule.Notes,tLoadRule.RuleWeight,tLoadRule.CreatedBy,.tRule,tLoadRule.RuleFailureCategory))
			
			#;Add rule to this profile
			$$$ThrowOnError(tProfile.AddRule(tRule))
			
			Set pUpdRecCt = $INCREMENT(pUpdRecCt)
		}
		$$$ThrowOnError(tProfile.%Save())
		
		Write:pVerbose !,pRuleAssign.RuleProfileName_" rule profile updated with rules"
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// ExportRuleAssignment exports rules belonging to a given profile to a directory
/// EXAMPLE
/// $$$ThrowOnError(##class(DataService.DS.Data.Config.RuleProfile).ExportRuleAssignment(tRS.ID,pBaseDir_"RuleAssignment",pVerbose))
ClassMethod ExportRuleAssignment(pRuleProfileId As %String = "", pFileDir As %String, pFileName As %String, pVerbose As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Check/create directory
		Set pFileDir = ##class(%File).NormalizeDirectory(pFileDir)
		If '##class(%File).DirectoryExists(pFileDir) {
			$$$ThrowOnError(##class(%File).CreateDirectory(pFileDir))
		}
		#;Create file
		Set tFileRef = ##class(%File).%New(pFileDir_pFileName)
		Do tFileRef.Open("WSN")

		Do tFileRef.WriteLine("<Container>")
		Do tFileRef.WriteLine("  <RuleProfile><RuleProfileName>"_pRuleProfileId_"</RuleProfileName>")
		Do tFileRef.WriteLine("    <Rules>")
		Set tSQL = "SELECT CreatedBy,Notes,RuleWeight,RuleDefn->Name FROM DataService_DS_Data_Config.Rule WHERE RuleProfile = ?"
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,.tSQL,pRuleProfileId)
		If tRS.%SQLCODE<0 Set tSC =$$$ERROR($$$GeneralError,"SQLERROR:"_tRS.%SQLCODE) Quit
		While tRS.%Next() {
			Do tFileRef.WriteLine("      <Rule>")
			If tRS.CreatedBy '="" Do tFileRef.WriteLine("          <CreatedBy>"_tRS.CreatedBy_"</CreatedBy>")
			If tRS.Notes '="" Do tFileRef.WriteLine("          <Notes>"_tRS.Notes_"</Notes>")
			If tRS.RuleWeight '="" Do tFileRef.WriteLine("          <RuleWeight>"_tRS.RuleWeight_"</RuleWeight>")
			Do tFileRef.WriteLine("          <Name>"_tRS.Name_"</Name>")
			Do tFileRef.WriteLine("      </Rule>")
		
		}
		Do tFileRef.WriteLine("    </Rules>")
		Do tFileRef.WriteLine("  </RuleProfile>")
		Do tFileRef.WriteLine("</Container>")
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

Method FormatForExport() As %Status
{
	Set ..CreatedOn = ""
	Set ..LastUpdatedOn = ""
	$$$ThrowOnError(..Rules.Clear())
	Quit $$$OK
}

/*
Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Set ^RAJ("RuleProfile","%OnBeforeSave")=1
	Set tSC = $$$OK
	If ..MaintainCache {
		Set ..MaintainCache = 0
	}
	Else {
		Set ^RAJ("RuleProfile","%OnBeforeSave","NotMaintainCache")=1
		Set tSC = ..IsSortedRuleCacheValid.Clear()
	}
	Quit tSC
}
*/
/// This callback method is invoked by the <METHOD>%Save</METHOD> method to 
/// provide notification that the object is being saved. It is called before 
/// any data is written to disk.
/// 
/// This method invalidates the sorted rule cache on the record profile
Method %OnAddToSaveSet(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	If ..MaintainCache {
		Set ..MaintainCache = 0
	}
	Else {
		Set tSC = ..IsSortedRuleCacheValid.Clear()
	}
	Quit tSC
}

/// Method found in all config classes used to define the export set created by a given user DataService
Query QueryExport(pCreatedBy As %String = "_SYSTEM") As %SQLQuery(CONTAINID = 1, ROWSPEC = "ID:%String") [ SqlName = RuleProfileQueryExport, SqlProc ]
{
	SELECT ID FROM DataService_DS_Data_Config.RuleProfile
	WHERE CreatedBy = :pCreatedBy
	ORDER BY ID
}



}
