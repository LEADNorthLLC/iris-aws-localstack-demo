Include DSDomain

/// Defines a subject and field standardizing the options available to 
Class DataService.DS.Data.Config.ReportingSubject Extends (%Persistent, %XML.Adaptor, HS.Util.CopyFrom, DataService.DS.Data.Abstract.TrackMetadata, DataService.DS.Data.Abstract.ReportingSubjectDetail)
{

/// Name of the template used to generate sub fields, if used
Property TemplateName As %String(MAXLEN = 500);

Index SubjectField On (Subject, Field) [ IdKey, Unique ];

/// returns the short name for this field, which is everything after the last dot in the field property
/// used as the field name when constructing composite objects
Method GetFieldShortName()
{
	Quit $PIECE(..Field,".",*)
}

Property ChildReportingSubjectIds As list Of %String(MAXLEN = 1000, XMLPROJECTION = "NONE");

Property ParentReportingSubjectId As %String(MAXLEN = 1000, XMLPROJECTION = "NONE");

Method %OnBeforeSave(tIsInsert As %Boolean) As %Status
{
	If (tIsInsert) {
		Quit ..IdentifyParent()
	}
	Quit $$$OK
}

Method IdentifyParent() As %Status
{
	If (..ParentObjectType'="") {
		#; find the parent reporting subject
		If ($LENGTH(..Field,".")=1) {
			Set tParentField = "."
		}
		Else {
			Set tParentField = $PIECE(..Field,".",1,*-1)	
		}
		
		Set tParent = ..SubjectFieldOpen(..Subject,tParentField)
		If (tParent="") {
			Quit $$$ERROR($$$GeneralError,"Error Creating Reporting Subject '"_..Subject_"' and Field '"_..Field_"': Expected to find parent reporting subject '"_..Subject_"' and field '"_tParentField_"'")	
		}
		ElseIf ('tParent.IsObject) {
			Quit $$$ERROR($$$GeneralError,"Error Creating Reporting Subject '"_..Subject_"' and Field '"_..Field_"': Parent reporting subject '"_..Subject_"' and field '"_tParentField_"' is not an object")	
		} 
		ElseIf (tParent.DataType'=..ParentObjectType) {
			Quit $$$ERROR($$$GeneralError,"Error Creating Reporting Subject '"_..Subject_"' and Field '"_..Field_"': Parent reporting subject '"_..Subject_"' and field '"_tParentField_"' does not have expected data type: expected '"_..ParentObjectType_"', got '"_tParent.DataType_"'")	
		}
		Else {
			Set ..ParentReportingSubjectId = tParent.%Id()
		}
	}
	
	Quit $$$OK
}

Method %OnAfterSave(tIsInsert As %Boolean) As %Status
{
	If (tIsInsert) {
		#; if there is a parent, add this Id to the parent's list of children if not already there
		If (..ParentReportingSubjectId'="") {
			Set tParent = ..%OpenId(..ParentReportingSubjectId)
			If (tParent.ChildReportingSubjectIds.Find(..%Id())="") {
				$$$QuitOnError(tParent.ChildReportingSubjectIds.Insert(..%Id()))	
				$$$QuitOnError(tParent.%Save())
			}
		}
	}
	Quit $$$OK
}

/// returns the parent reporting subject
/// if this has field X.[shortname], then the parent has field X
/// if there is no dot in the field, then there is no parent
Method GetParentReportingSubject()
{
	If (..ParentReportingSubjectId="") {
		Quit ""
	}
	Else {
		Quit ..%OpenId(..ParentReportingSubjectId)
	}
}

/// Creator methods for Reporting subject
ClassMethod AddUpdateReportingSubject(pSubject As %String, pField As %String, pDataType As %String, pIsObject As %String = "", pIsPlural As %Boolean, pParentObjectType As %String = "", pIsPluralInParent As %Boolean = "", pCreatedBy As %String = "", pTemplateName As %String, ByRef pReportingSubject = "") As %Status
{
	Set tSC = $$$OK
	Try {
		
		#; check and normalize some values
		Set tIsObjectNormalized = ##class(DataService.DS.App.Utils).NormalizeInputBoolean(pIsObject)
		If (tIsObjectNormalized="") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Error Importing Subject area:'"_pSubject_":"_pField_"': non-boolean value for IsObject: '"_pIsObject_"'"))
		}
		Set tIsPluralNormalized = ##class(DataService.DS.App.Utils).NormalizeInputBoolean(pIsPlural)
		If (tIsPluralNormalized="") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Error Importing Subject area:'"_pSubject_":"_pField_"': non-boolean value for IsPlural: '"_pIsPlural_"'"))
		}
		Set tIsPluralInParentNormalized = ##class(DataService.DS.App.Utils).NormalizeInputBoolean(pIsPluralInParent)
		If (tIsPluralInParentNormalized="") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Error Importing Subject area:'"_pSubject_":"_pField_"': non-boolean value for IsPluralInParent: '"_pIsPluralInParent_"'"))
		}
		
		If (pTemplateName'="") {
			
			#; generate this and children from a template
			Set tTemplate = ##class(DataService.DS.Data.Template.ReportingSubject).%OpenId(pTemplateName,,.tStatus)
			$$$ThrowOnError(tStatus)
			$$$ThrowOnError(tTemplate.InstantiateToDatabase(pField,pSubject,tIsPluralNormalized,pParentObjectType,tIsPluralInParentNormalized,pCreatedBy,1))
			Set pReportingSubject = ##class(DataService.DS.Data.Config.ReportingSubject).SubjectFieldOpen(pSubject,pField)
			If (pReportingSubject="") {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Template '"_pTemplateName_"' did not create expected reporting subject with subject '"_pSubject_"' and field '"_pField_"'"))	
			}
		}
		Else {
		
			If '##class(DataService.DS.Data.Config.ReportingSubject).SubjectFieldExists(pSubject,pField,.tReportingSubjectId) {
				Set tReportingSubject = ..%New()
				Set tReportingSubject.Subject = pSubject
				Set tReportingSubject.Field = pField
				Set tReportingSubject.DataType = pDataType
				Set tReportingSubject.IsObject = tIsObjectNormalized
				Set tReportingSubject.IsPlural = tIsPluralNormalized
				Set tReportingSubject.ParentObjectType = pParentObjectType
				Set tReportingSubject.IsPluralInParent = pIsPluralInParent
				Set tReportingSubject.TemplateName = pTemplateName
				Set tReportingSubject.CreatedBy = pCreatedBy
			} 
			Else {
				Set tReportingSubject = ..%OpenId(tReportingSubjectId)
				Set tReportingSubject.DataType = pDataType
				Set tReportingSubject.IsObject = tIsObjectNormalized
				Set tReportingSubject.IsPlural = tIsPluralNormalized
				Set tReportingSubject.ParentObjectType = pParentObjectType
				Set tReportingSubject.IsPluralInParent = pIsPluralInParent
				Set tReportingSubject.TemplateName = pTemplateName
			}
			$$$ThrowOnError(tReportingSubject.%Save())
		
			Set pReportingSubject = tReportingSubject
		}
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}	
	Quit tSC
}

/// Helper method called by DataService.DS.App.Utils used to import a single record based off it's import specs
ClassMethod ImportRecord(pRptSubj As DataService.DS.Data.Config.ReportingSubject, pAction As %String, ByRef pNewRecCt As %Integer, ByRef pUpdRecCt As %Integer, pVerbose As %Boolean)
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(..AddUpdateReportingSubject(pRptSubj.Subject,pRptSubj.Field,pRptSubj.DataType,pRptSubj.IsObject,pRptSubj.IsPlural,pRptSubj.ParentObjectType,pRptSubj.IsPluralInParent,pRptSubj.CreatedBy, pRptSubj.TemplateName))
		
		Set pNewRecCt = $INCREMENT(pNewRecCt)
		If pVerbose Write !,"Subject area:'"_pRptSubj.Subject_":"_pRptSubj.Field_"' imported"
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Helper method called by DataService.DS.App.Utils used to delete a single record based off it's import specs
ClassMethod DeleteRecord(pRptSubj As DataService.DS.Data.Config.ReportingSubject, ByRef pDeletedRecordCount, pVerbose As %Boolean)
{
	Set tSC = $$$OK
	Try {
		If (pRptSubj.TemplateName'="") {
			$$$ThrowOnError(##class(DataService.DS.Data.Template.ReportingSubject).DeleteInstancesFromDatabase(pRptSubj.Field,pRptSubj.Subject))
			
			If pVerbose Write !,"Subject area:'"_pRptSubj.Subject_":"_pRptSubj.Field_"' and children in template '"_pRptSubj.TemplateName_"' deleted"
		}
		Else {
			If ##class(DataService.DS.Data.Config.ReportingSubject).SubjectFieldExists(pRptSubj.Subject,pRptSubj.Field,.tReportingSubjectId) {
				$$$ThrowOnError(..%DeleteId(tReportingSubjectId))
				Set pDeletedRecordCount = $INCREMENT(pDeletedRecordCount)
				If pVerbose Write !,"Subject area:'"_pRptSubj.Subject_":"_pRptSubj.Field_"' deleted"
			}
		}
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
	Quit $$$OK
}

/// Method found in all config classes used to define the export set created by a given user DataService
Query QueryExport(pCreatedBy As %String = "_SYSTEM") As %SQLQuery(CONTAINID = 1, ROWSPEC = "ID:%String") [ SqlName = ReportingSubjectQueryExport, SqlProc ]
{
	SELECT ID FROM DataService_DS_Data_Config.ReportingSubject 
	WHERE CreatedBy = :pCreatedBy
	ORDER BY ID
}

/// Copy of QueryExport for the DS project, with an optional createdBy, exporting all subjects, getting ID, Subject, and Field.
Query QueryExportAll(pCreatedBy As %String = "NULL") As %SQLQuery(CONTAINID = 1, ROWSPEC = "ID:%String,Subject:%String,Field:%String") [ SqlName = ReportingSubjectQueryExportAll, SqlProc ]
{
	SELECT ID,Subject,Field FROM DataService_DS_Data_Config.ReportingSubject 	
	WHERE CreatedBy  = 
		CASE 
		WHEN :pCreatedBy = 'NULL' THEN CreatedBy ELSE :pCreatedBy 
		END
	ORDER BY ID
}

/// Determines whether this reporting subject is a composite object or part of a composite object
/// If it is, the root (parent) reporting subject of that composite object is returned
/// along with a List of all of the ReportingSubject Ids that are ancestors of the parent
Method IsObjectOrPart(Output pParent As DataService.DS.Data.Config.ReportingSubject, Output pCoveredReportingSubjectList As %ListOfDataTypes) As %Boolean
{

	If (..ParentReportingSubjectId'="") {
		#; recursive case: we're in a composite object, but not at the parent, so recurse upwards
		Quit ..%OpenId(..ParentReportingSubjectId).IsObjectOrPart(.pParent, .pCoveredReportingSubjectList)
	}
	ElseIf (..ChildReportingSubjectIds.Count()>0){
		#; base case: we're at the parent, so can get the complete list of covered reporting subjects
		Set pParent = $THIS
		$$$ThrowOnError(..GetCoveredReportingSubjects(.pCoveredReportingSubjectList))
		Quit 1
		
	} Else {
		#; not in an object
		Set pParent = ""
		Set pCoveredReportingSubjectList = ##class(%ListOfDataTypes).%New()
		Quit 0
	}
}

/// returns a list of reporting subject Ids that are ancestors of this reporting subject
Method GetCoveredReportingSubjects(ByRef pCoveredReportingSubjectList As %ListOfDataTypes) As %Status
{
	#; create list if it doesn't exist yet
	If ($GET(pCoveredReportingSubjectList)="") {
		Set pCoveredReportingSubjectList = ##class(%ListOfDataTypes).%New()
	}
	
	#; add self to the list
	$$$QuitOnError(pCoveredReportingSubjectList.Insert(..%Id()))
	
	#; recurse into children if present
	For tChildIndex=1:1:..ChildReportingSubjectIds.Count() {
		Set tChildReportingSubject = ..%OpenId(..ChildReportingSubjectIds.GetAt(tChildIndex))
		$$$ReturnOnError(tChildReportingSubject.GetCoveredReportingSubjects(.pCoveredReportingSubjectList))
	}
	
	Quit $$$OK
}

Storage Default
{
<Data name="ReportingSubjectDefaultData">
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
<Value>IsPlural</Value>
</Value>
<Value name="5">
<Value>ParentObject</Value>
</Value>
<Value name="6">
<Value>DataType</Value>
</Value>
<Value name="7">
<Value>LastUpdatedOn</Value>
</Value>
<Value name="8">
<Value>Object</Value>
</Value>
<Value name="9">
<Value>NestingLevel</Value>
</Value>
<Value name="10">
<Value>PluralInParent</Value>
</Value>
<Value name="11">
<Value>IsObject</Value>
</Value>
<Value name="12">
<Value>ParentObjectType</Value>
</Value>
<Value name="13">
<Value>IsPluralInParent</Value>
</Value>
<Value name="14">
<Value>TemplateName</Value>
</Value>
<Value name="15">
<Value>ParentReportingSubject</Value>
</Value>
<Value name="16">
<Value>ChildReportingSubjectIds</Value>
</Value>
<Value name="17">
<Value>ParentReportingSubjectId</Value>
</Value>
</Data>
<DataLocation>^DataQualitAAF0.ReportingSuA53FD</DataLocation>
<DefaultData>ReportingSubjectDefaultData</DefaultData>
<ExtentSize>5618</ExtentSize>
<IdLocation>^DataQualitAAF0.ReportingSuA53FD</IdLocation>
<IndexLocation>^DataQualitAAF0.ReportingSuA53FI</IndexLocation>
<Property name="%%CLASSNAME">
<AverageFieldSize>2</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,16,$lb("-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000"),$lb(21,21,21,21,21,21,21,21,21,21,21,21,21,21,21),$lb(758198320,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758198320))</Histogram>
<Selectivity>100.0000%</Selectivity>
</Property>
<Property name="%%ID">
<AverageFieldSize>44.79</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("Administrations||AdministeredAtLocation","Administrations||AdministrationStatus.AlternateCodes.CodingSystem","Alerts||Alert.Code","Encounters||Specialties.CodingSystemName","LabOrders||Comments","LabOrders||OrderCategory.CodingSystem","MedicalClaimLines||ClaimLineType.OriginalText","MemberEnrollments||Guarantor.SSN","MemberEnrollments||PlanSpecificSubscriberID","OtherOrderResults||ResultItems.Comments","OtherOrderResults||ResultItems.ObservationMethods.CodingSystemName","Patient||SupportContacts.Address.County","PhysicalExams||EnteredBy.AlternateCodes.Code","RadOrderResults||ResultItem.EnteredAt.AlternateCodes","Specimens||CollectionAmountUnits.CodingSystem","Vaccinations||Condition"),$lb(25,1,0,0,11,0,2,19,0,31,0,1,0,0,0),$lb(1097100649,1701995876,1918989417,1684892014,1818587764,1097622898,1164862319,1164862319,1281450575,1131375981,1332896869,1281450575,1298490473,1684628321,1835165042,1198874994,1349280110,1298492770,1333028965,1131375981,1331852133,1333028965,1348564073,1635019109,1752789865,1349024115,1382114383,1382114383,1399874915,1399874915,1449223011,1449223011))</Histogram>
<Selectivity>1</Selectivity>
</Property>
<Property name="ChildReportingSubjectIds">
<AverageFieldSize>31.81</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,14,$lb("-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000","-10000000000000000000",$lb("Administrations||AdministeredAtLocation.Code","Administrations||AdministeredAtLocation.CodingSystem","Administrations||AdministeredAtLocation.CodingSystemName","Administrations||AdministeredAtLocation.Description","Administrations||AdministeredAtLocation.OriginalText","Administrations||AdministeredAtLocation.AlternateCodes"),$lb("MedicalClaimLines||ClaimLineType.AlternateCodes.Code","MedicalClaimLines||ClaimLineType.AlternateCodes.CodingSystem","MedicalClaimLines||ClaimLineType.AlternateCodes.CodingSystemName","MedicalClaimLines||ClaimLineType.AlternateCodes.Description")),$lb(21,21,21,21,21,21,21,21,21,21,21,21,21,0,5),$lb(758198320,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,758198320,771834212,1768843635,1768120684,906055013))</Histogram>
<OutlierSelectivity>.871681:</OutlierSelectivity>
<Selectivity>0.0178%</Selectivity>
</Property>
<Property name="CreatedBy">
<AverageFieldSize>9</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"," _SYSTEM"),$lb(9,9,9,9,9,9,9,9,9,9,9,9,9,9,9),$lb(543118169,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,543118169))</Histogram>
<OutlierSelectivity>.992118:"_SYSTEM"</OutlierSelectivity>
<Selectivity>0.3941%</Selectivity>
</Property>
<Property name="CreatedOn">
<AverageFieldSize>21</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("2023-08-11 00:20:25","2023-08-11 00:20:25","2023-08-11 00:20:25","2023-08-11 00:20:26","2023-08-11 00:20:26","2023-08-11 00:20:26","2023-08-11 00:20:26","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:28","2023-08-11 00:20:28","2023-08-11 00:20:28"),$lb(20,20,18,20,20,20,18,20,20,20,20,20,18,20,20),$lb(842019379,0,0,0,0,889192448,905969664,0,0,0,0,0,0,905969664,922746880,0,0,0,0,0,0,0,0,0,0,922746880,939524096,0,0,0,0,842019379))</Histogram>
<Selectivity>25.0000%</Selectivity>
</Property>
<Property name="DataType">
<AverageFieldSize>8.79</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" ALTERNATECODE"," CODETABLE"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," STRING"," TIMESTAMP"),$lb(1,1,8,8,8,8,8,8,8,8,8,8,8,8,1),$lb(541150292,1095521349,1129268293,1129268293,1398035017,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1398035017,1414090053,542394701))</Histogram>
<OutlierSelectivity>.809735:"STRING"</OutlierSelectivity>
<Selectivity>2.5316%</Selectivity>
</Property>
<Property name="Field">
<AverageFieldSize>30.33</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("ATCCode.AlternateCodes","AdministrationSite.Description","Allergy","ClaimLineType.OriginalText","CollectionMethod.AlternateCodes.Code","EnteredAt.AlternateCodes","EnteredBy","EnteredBy.Description","Guarantor.Occupation.OriginalText","MPIID","OrderCategory.AlternateCodes","ResultItem.AnalysisTime","ResultItems.EnteredBy","Specialties.Code","SupportContacts.ContactType.AlternateCodes.CodingSystemName","VerifiedBy.CodingSystem"),$lb(1,1,0,1,0,7,9,0,0,0,0,10,0,1,0),$lb(1096041283,1413694319,1684892014,1684892014,1819043186,1097624677,1131176297,1818323309,1869376613,1131375724,1164866661,1098133057,1115226112,0,776234355,1164866661,1198874994,1198874994,1297107273,1297107273,1332896869,1332896869,1382380405,776040033,1932412270,1382380405,1399874915,1885692777,1970303087,1400205424,1449489001,1449489001))</Histogram>
<OutlierSelectivity>.013274:"EnteredAt.AlternateCodes.CodingSystemName"</OutlierSelectivity>
<Selectivity>0.0691%</Selectivity>
</Property>
<Property name="IsObject">
<AverageFieldSize>2.13</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1),$lb(1,1,1,1,1,1,1,1,1,1,1,1,1,0,1),$lb(805306368,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,805306368,822083584,0,0,822083584))</Histogram>
<OutlierSelectivity>.871681:0</OutlierSelectivity>
<Selectivity>12.8319%</Selectivity>
</Property>
<Property name="IsPlural">
<AverageFieldSize>2.51</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1),$lb(1,1,1,1,1,1,1,0,1,1,1,1,1,1,1),$lb(805306368,0,0,0,0,0,0,0,0,0,0,0,0,0,0,805306368,822083584,0,0,0,0,0,0,0,0,0,0,0,0,0,0,822083584))</Histogram>
<Selectivity>50.0000%</Selectivity>
</Property>
<Property name="IsPluralInParent">
<AverageFieldSize>2.06</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,3,$lb("-10000000000000000000","-10000000000000000000","-10000000000000000000",0,0,0,0,0,0,0,0,0,0,0,0,1),$lb(21,21,0,1,1,1,1,1,1,1,1,1,1,1,0),$lb(758198320,0,0,0,0,758198320,805306368,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,805306368,822083584,822083584))</Histogram>
<OutlierSelectivity>.80531:0</OutlierSelectivity>
<Selectivity>9.7345%</Selectivity>
</Property>
<Property name="LastUpdatedOn">
<AverageFieldSize>21</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("2023-08-11 00:20:25","2023-08-11 00:20:25","2023-08-11 00:20:25","2023-08-11 00:20:26","2023-08-11 00:20:26","2023-08-11 00:20:26","2023-08-11 00:20:26","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:27","2023-08-11 00:20:28","2023-08-11 00:20:28","2023-08-11 00:20:28"),$lb(20,20,18,20,20,20,18,20,20,20,20,20,18,20,20),$lb(842019379,0,0,0,0,889192448,905969664,0,0,0,0,0,0,905969664,922746880,0,0,0,0,0,0,0,0,0,0,922746880,939524096,0,0,0,0,842019379))</Histogram>
<Selectivity>25.0000%</Selectivity>
</Property>
<Property name="ParentObjectType">
<AverageFieldSize>9.99</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" "," "," "," "," ALTERNATECODE"," ALTERNATECODE"," ALTERNATECODE"," ALTERNATECODE"," CODETABLE"," CODETABLE"," CODETABLE"," CODETABLE"," CODETABLE"," CODETABLE"," CODETABLE"," NAME"),$lb(2,2,2,1,15,15,15,1,11,11,11,11,11,11,1),$lb(536870912,0,0,0,0,0,0,0,1095521349,0,0,0,0,0,0,1095521349,1129268293,0,0,0,0,0,0,0,0,0,0,0,0,1129268293,1312902469,541999437))</Histogram>
<OutlierSelectivity>.473451:"CODETABLE"</OutlierSelectivity>
<Selectivity>7.1684%</Selectivity>
</Property>
<Property name="ParentReportingSubjectId">
<AverageFieldSize>29.1</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" "," "," "," "," ADMINISTRATIONS||ADMINISTRATIONSTATUS.ALTERNATECODES"," ALERTS||ALERT.ALTERNATECODES"," FAMILYHISTORIES||ENTEREDBY"," LABORDERS||ORDERCATEGORY"," MEDICALCLAIMS||ADMISSIONTYPE"," MEMBERENROLLMENTS||HEALTHFUND.ENTEREDBY.ALTERNATECODES"," OTHERORDERRESULTS||ENTEREDBY"," OTHERORDERRESULTS||RESULTITEMS.PERFORMEDAT"," PATIENT||SUPPORTCONTACTS.CONTACTTYPE"," PROCEDURES||BODYSITE"," SPECIMENS||APPROPRIATENESS"," VACCINATIONS||COMPONENTMEDS.ALTERNATECODES"),$lb(2,2,2,1,2,1,1,1,3,1,20,1,2,1,1),$lb(536870912,0,0,0,0,0,0,0,1094995273,1145915726,1279611476,1095517522,1178684745,1178684745,1279345231,1279345231,1296385097,1145652033,1296188754,1296387394,1330923589,1162761285,1380275029,1330923589,1346458697,1096042821,1380926277,1347571523,1397769539,1397769539,1447117635,542523715))</Histogram>
<OutlierSelectivity>.207965:</OutlierSelectivity>
<Selectivity>0.5212%</Selectivity>
</Property>
<Property name="Subject">
<AverageFieldSize>14.46</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb("Administrations","Administrations","Alerts","Encounters","LabOrders","LabOrders","MedicalClaimLines","MemberEnrollments","MemberEnrollments","OtherOrderResults","OtherOrderResults","Patient","PhysicalExams","RadOrderResults","Specimens","Vaccinations"),$lb(16,1,0,0,10,0,2,18,0,18,0,1,0,0,0),$lb(1097100649,0,0,1684892014,1818587764,1097622898,1164862319,1164862319,1281450575,0,0,1281450575,1298490473,1684628321,1835165042,0,0,1298492770,1333028965,0,0,1333028965,1348564073,1635019109,1752789865,1349024115,1382114383,1382114383,1399874915,1399874915,1449223011,1449223011))</Histogram>
<Selectivity>5.5556%</Selectivity>
</Property>
<Property name="TemplateName">
<AverageFieldSize>2</AverageFieldSize>
<Histogram>$lb(.06666666666666666667,0,0,$lb(" "," "," "," "," "," "," "," "," "," "," "," "," "," "," "," "),$lb(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2),$lb(536870912,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,536870912))</Histogram>
<Selectivity>100.0000%</Selectivity>
</Property>
<SQLMap name="SubjectField">
<BlockCount>-584</BlockCount>
</SQLMap>
<StreamLocation>^DataQualitAAF0.ReportingSuA53FS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
