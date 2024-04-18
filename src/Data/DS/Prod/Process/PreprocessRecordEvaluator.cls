Include (Ensemble, DSDomain)

/// Used to perform standard preprocessing on evaluation requests. 
Class DataService.DS.Prod.Process.PreprocessRecordEvaluator Extends (Ens.BusinessProcess, DataService.DS.Prod.Process.RecordEvaluatorAbstract)
{

/// Upload directory location for processing batch files
Property UploadDirectory As %String [ InitialExpression = "c:/validator/upload" ];

/// Callback method executed after each record is fetched, allowing for additional/custom programming.
/// <BR> 		Set the value the name of a class method in the format &ltclassname&gt:&ltmethod&gt
/// <BR> 		The method must have the signature ClassMethod Name (ByRef pRequest as DataService.DS.Prod.Msg.RecEvalRequest,ByRef pObj as <XX>) as %Status
/// <BR> 				where <XX> = object provided by FetchRecordClass
/// <BR> 	e.g.   Custom.DataService:Test
Property PostRecordFetchMethod As %String(MAXLEN = 500);

/// Process target used perform actual record evaluation requests<br>
/// The process is used to handle transfer request. <br>
Property ProcessTarget As Ens.DataType.ConfigName [ InitialExpression = "Record Evaluator" ];

/// Business operation which handles the filing of errors and results
Property ResultTarget As Ens.DataType.ConfigName [ InitialExpression = "File Results Operation" ];

/// Business operation used to handle the caching of rule sort order.
Property ConfigTarget As Ens.DataType.ConfigName [ InitialExpression = "Config Operation" ];

/// Business operation which handles the filing of errors and results
Property ResultOperations As Ens.DataType.ConfigName [ InitialExpression = "Result Operation" ];

Parameter SETTINGS = "ClearQuickStreams,ProcessTarget,ResultTarget,ConfigTarget,ResultOperations,PostRecordFetchMethod,UploadDirectory";

/// Used for performance tracking
Property EvalStartTime As %TimeStamp;

/// List of QuickStream Ids that need to be cleaned up at the end of processing
Property QuickStreamList As list Of %String;

/// Flag to clean up QuickStreams at the end of processing
Property ClearQuickStreams As %Boolean [ InitialExpression = 0 ];

/// Handle request
Method OnRequest(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	#;Record start time of record evaluator
	Set tSC = $$$OK
	Try {
		#;Create a new batch or determine if existing batch is still valid for testing
		If ##class(DataService.DS.Data.Config.Batch).BatchIdExists(pRequest.BatchId,.tBatchId) {
			Set tBatch = ##class(DataService.DS.Data.Config.Batch).%OpenId(tBatchId)
			If (tBatch.RuleProfileName '= pRequest.RuleProfileName) && tBatch.IsLocked {
				$$$ThrowOnError($$$ERROR("Rule profile may not be updated on a locked batch"))
			}
			$$$ThrowOnError(tBatch.LockBatch())
			#; We should use the batch grouper from the config setting since it cannot be edited after creation.	
			If pRequest.BatchGrouper '= tBatch.BatchGrouper {
				Set pRequest.BatchGrouper = tBatch.BatchGrouper
				$$$ThrowOnError(pRequest.%Save())
				$$$LOGWARNING("Request message updated to use saved BatchGrouper")
			}
		} 
		Else {
			$$$ThrowOnError(##class(DataService.DS.Data.Config.Batch).AddUpdateBatch(pRequest.BatchGrouper,pRequest.BatchId,pRequest.RuleProfileName,1,1,pRequest.SourceProvider,.tBatch))
		}
		
		If 'tBatch.AllowResubmission {
			If ##class(DataService.DS.Data.Result.Record).BatchRecordKeyExists(tBatch.BatchId,pRequest.RecordRepresentationClass,pRequest.RecordSource,pRequest.RecordSourceKey) {
				$$$ThrowOnError($$$ERROR("Batch configuration does not allow for evaluating a record multiple times"))				
			}
		}
		
		Set tRuleProfile = tBatch.RuleProfile
		If '$ISOBJECT(tRuleProfile) Set tRuleProfile = ##class(DataService.DS.Data.Config.RuleProfile).NameOpen(tBatch.RuleProfileName)
		#; Default processing if we fail to identify the profile(?)
		Set pRequest.ProcessSDAEntries = $SELECT($ISOBJECT(tRuleProfile) : tRuleProfile.ProcessSDAEntries, 1 : 1)
		Kill tRuleProfile
		
		If ($PIECE(pRequest.RecordRepresentationClass,":",1)="DataService.DS.App.Record.DocumentText") {
			$$$LOGINFO("HERE in DocumentText processing")
			Set ..EvalStartTime =##class(DataService.DS.Data.Result.PerformanceLog).GetFormatTime()
			$$$ThrowOnError(..DocumentTextProcessing(pRequest,.pResponse))
		}
		ElseIf (##class(DataService.DS.App.Record.Abstract.Document).IsDocumentClass(pRequest.RecordRepresentationClass)) {
			$$$LOGINFO("HERE in Document processing")
			Set ..EvalStartTime =##class(DataService.DS.Data.Result.PerformanceLog).GetFormatTime()
			$$$ThrowOnError(..DocumentProcessing(pRequest,.pResponse))
		}
		ElseIf (##class(DataService.DS.App.Record.Abstract.Section).IsSectionClass(pRequest.RecordRepresentationClass)) {
			$$$LOGINFO("HERE in Section processing")
			Set ..EvalStartTime =##class(DataService.DS.Data.Result.PerformanceLog).GetFormatTime()
			$$$ThrowOnError(..SectionProcessing(pRequest,.pResponse))
		}
		ElseIf (##class(DataService.DS.App.Record.Abstract.Entry).IsEntryClass(pRequest.RecordRepresentationClass)) {
			$$$LOGINFO("HERE in Entry processing")
			Set ..EvalStartTime =##class(DataService.DS.Data.Result.PerformanceLog).GetFormatTime()
			$$$ThrowOnError(..EntryProcessing(pRequest,.pResponse))
		}
		Else {
			$$$ThrowOnError(..DefaultProcessing(pRequest,.pResponse))
		}
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
		#; no guarantee that pResponse created, so reset it and add status
		Do ##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse)
		Set pResponse.Status = tSC
		
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tSC))
		#; clean up quick streams so they are not leaked if OnComplete dosn't get called.
		Do ..CleanupQuickStreamList()
	}
	
	#; return error in the response
	Quit $$$OK
}

Method DocumentTextProcessing(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		
		#; record cleanup in case this is a resubmit
		#; if so, we need to remove all existing result children since the set of children generated
		#; in this run will be different than those in the earlier run and 
		#; so won't overwrite them
		Set tDeleteRequest = ##class(DataService.DS.Prod.Msg.DeleteRecordRequest).%New()
		Set tDeleteRequest.BatchId = pRequest.BatchId
		Set tDeleteRequest.RecordSource = pRequest.RecordSource
		Set tDeleteRequest.RecordSourceKey = pRequest.RecordSourceKey
		Set tDeleteRequest.RecordRepresentationClass = pRequest.RecordRepresentationClass
		$$$ThrowOnError(..SendRequestSync(..ResultOperations,tDeleteRequest))
		
		#; get the Document text to use to build the more complex document representation
		$$$ThrowOnError(##class(DataService.DS.App.RecordUtils).FetchRecordFromRequest("DataService.DS.App.RecordFetchMapper", ..PostRecordFetchMethod , pRequest, .tDocumentText))
		Set tDocBuildStartTime = ##class(DataService.DS.Data.Result.PerformanceLog).GetFormatTime()
		$$$ThrowOnError(tDocumentText.BuildDocument(.tDocument,pRequest.ProcessSDAEntries))
		$$$ThrowOnError(##class(DataService.DS.Data.Result.PerformanceLog).CreatePerformanceLog(tDocBuildStartTime,,"Document Build",pRequest.GetUniqueBatchRecordProcessingKey()))
				
		#;Build cache of field evaluators and rules for document
		Set tDocRuleCacheStartTime = ##class(DataService.DS.Data.Result.PerformanceLog).GetFormatTime()
		$$$ThrowOnError(..OnBeforeDocumentTextSend(.tDocument,pRequest.RuleProfileName,pRequest.RecordRepresentationClass,.tFilterRecordFromProcess))
		$$$ThrowOnError(##class(DataService.DS.Data.Result.PerformanceLog).CreatePerformanceLog(tDocRuleCacheStartTime,,"Document Rule Cache",pRequest.GetUniqueBatchRecordProcessingKey()))
		
		
		#; add all quick streams that were created to the cleanup list
		$$$ThrowOnError(tDocument.GetQuickStreams(.tDocumentQuickStreamList))
		For tQSIndex = 1:1:tDocumentQuickStreamList.Count() {
			$$$ThrowOnError(..QuickStreamList.Insert(tDocumentQuickStreamList.GetAt(tQSIndex)))
		}
		
		#; submit the raw document text for normal processing
		#; if for no other purpose this record will serve as the oldest parent from which all other records branch
		$$$ThrowOnError(..SendRequestAsync(..ProcessTarget,pRequest,1))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))	
		
		#; create a subrequest for the Document processing
		Set tDocumentStream = ##class(HS.SDA3.QuickStream).%New()
		$$$ThrowOnError(tDocument.XMLExportToStream(.tDocumentStream))
		$$$ThrowOnError(..QuickStreamList.Insert(tDocumentStream.%Id()))
		#dim tDocumentRequest as DataService.DS.Prod.Msg.RecEvalRequest
		$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest, .tDocumentRequest, tDocument.%ClassName(1), "QuickStream", tDocumentStream.%Id(), tDocument.Title, tDocument.AbsoluteLocation, tDocument.LocationRelativeToParent, tDocument.RecordWarnings))
		
		
		#; CNR: CAll save data profile
		$$$ThrowOnError(..SaveDataProfile(tDocument,tDocumentRequest))
		
		#; Continue processing of the complex document structure
		$$$ThrowOnError(..DoProcessDocument(tDocument,tDocumentRequest))
		
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus	
	}
	
	Quit tStatus
}

Method DocumentProcessing(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		
		#; record cleanup in case this is a resubmit
		#; if so, we need to remove all existing result children since the set of children generated
		#; in this run will be different than those in the earlier run and 
		#; so won't overwrite them
		Set tDeleteRequest = ##class(DataService.DS.Prod.Msg.DeleteRecordRequest).%New()
		Set tDeleteRequest.BatchId = pRequest.BatchId
		Set tDeleteRequest.RecordSource = pRequest.RecordSource
		Set tDeleteRequest.RecordSourceKey = pRequest.RecordSourceKey
		Set tDeleteRequest.RecordRepresentationClass = pRequest.RecordRepresentationClass
		$$$ThrowOnError(..SendRequestSync(..ResultOperations,tDeleteRequest))
		
		#; get the record (Submitter responsible for cleaning quickstreams)
		$$$ThrowOnError(##class(DataService.DS.App.RecordUtils).FetchRecordFromRequest("DataService.DS.App.RecordFetchMapper", ..PostRecordFetchMethod , pRequest, .tDocument))
		
		$$$LOGINFO("Calling routine to save data profile info")
		#; CNR: Record Data Profile before prcoessing
		$$$ThrowOnError(..SaveDataProfile(tDocument,pRequest))
		
		#; kick off the main processing logic
		$$$ThrowOnError(..DoProcessDocument(tDocument,pRequest,.pResponse))
		
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus	
	}
	
	Quit tStatus
}

Method SectionProcessing(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		
		#; record cleanup in case this is a resubmit
		#; if so, we need to remove all existing result children since the set of children generated
		#; in this run will be different than those in the earlier run and 
		#; so won't overwrite them
		Set tDeleteRequest = ##class(DataService.DS.Prod.Msg.DeleteRecordRequest).%New()
		Set tDeleteRequest.BatchId = pRequest.BatchId
		Set tDeleteRequest.RecordSource = pRequest.RecordSource
		Set tDeleteRequest.RecordSourceKey = pRequest.RecordSourceKey
		Set tDeleteRequest.RecordRepresentationClass = pRequest.RecordRepresentationClass
		$$$ThrowOnError(..SendRequestSync(..ResultOperations,tDeleteRequest))
		
		#; get the record and record the quick streams we'll need to clean from it when we're done
		$$$ThrowOnError(##class(DataService.DS.App.RecordUtils).FetchRecordFromRequest("DataService.DS.App.RecordFetchMapper", ..PostRecordFetchMethod, pRequest, .tSection))
		$$$ThrowOnError(tSection.GetQuickStreams(.tSectionQuickStreamList))
		For tQSIndex = 1:1:tSectionQuickStreamList.Count() {
			$$$ThrowOnError(..QuickStreamList.Insert(tSectionQuickStreamList.GetAt(tQSIndex)))
		}
		
		#; kick off the main processing logic
		$$$ThrowOnError(..DoProcessSection(tSection,pRequest,.pResponse))
		
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus	
	}
	
	Quit tStatus
}

Method EntryProcessing(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		
		#; record cleanup in case this is a resubmit
		#; if so, we need to remove all existing result children since the set of children generated
		#; in this run will be different than those in the earlier run and 
		#; so won't overwrite them
		Set tDeleteRequest = ##class(DataService.DS.Prod.Msg.DeleteRecordRequest).%New()
		Set tDeleteRequest.BatchId = pRequest.BatchId
		Set tDeleteRequest.RecordSource = pRequest.RecordSource
		Set tDeleteRequest.RecordSourceKey = pRequest.RecordSourceKey
		Set tDeleteRequest.RecordRepresentationClass = pRequest.RecordRepresentationClass
		$$$ThrowOnError(..SendRequestSync(..ResultOperations,tDeleteRequest))
		
		#; get the record and record the quick streams we'll need to clean from it when we're done
		$$$ThrowOnError(##class(DataService.DS.App.RecordUtils).FetchRecordFromRequest("DataService.DS.App.RecordFetchMapper", ..PostRecordFetchMethod, pRequest, .tEntry))
		$$$ThrowOnError(tEntry.GetQuickStreams(.tEntryQuickStreamList))
		For tQSIndex = 1:1:tEntryQuickStreamList.Count() {
			$$$ThrowOnError(..QuickStreamList.Insert(tEntryQuickStreamList.GetAt(tQSIndex)))
		}
		
		#; kick off the main processing logic
		$$$ThrowOnError(..DoProcessEntry(tEntry,pRequest,.pResponse))
		
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus	
	}
	
	Quit tStatus
}

Method DefaultProcessing(pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set tSC =..SendRequestAsync(..ProcessTarget,pRequest,1)
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tSC))
	}
	Set pResponse.Status = tSC
	Quit tSC
}

ClassMethod GetXMLSourceDocument(Output pXPathDocument) As %Status
{
	$$$QuitOnError(##class(DataService.DS.App.Utils).GetXData("XMLSource",..%ClassName(1),.tXMLStream))
	Set pXPathDocument = ""
	$$$QuitOnError(##class(HS.IHE.Util).GetXPathDocument(.pXPathDocument,tXMLStream))
	Quit $$$OK
}

/***** Called independent of Document Processing to record profiling info ****/
Method SaveDataProfile(pDocument As DataService.DS.App.Record.Abstract.Document, pRequest As DataService.DS.Prod.Msg.RecEvalRequest) As %Status
{
	
	Set tStatus = $$$OK
	Try {
		
		Set tSummary = ##class(DataService.DS.Prod.Msg.DataProfiler.RecordSummaryData).%New()
		#;Filter submission of current record along with all children
		If pDocument.FilterRecordFromProcess {
			$$$LOGINFO("Document filtered")
			Quit	
		}
	
	
		#;Process header
		Set tHeaderObject = pDocument.Header
		Set tHeaderStream = ##class(HS.SDA3.QuickStream).%New()
		$$$ThrowOnError(tHeaderObject.XMLExportToStream(.tHeaderStream))

		Set tSummary.MessageType = tHeaderObject.NormalizedTitle
		Set tSummary.BatchId = pRequest.BatchId 
		Set tSummary.BatchGrouper = pRequest.BatchGrouper
		Set tSummary.RecordName = pRequest.RecordName
		
		
		#; Find OID under Header
		//This is where it gets sticky - we need to parse the Document and get the OID
		// How do I get an XPath Document from pDocument? 
		// Header has an XPath Document property -- can we use it? 
		
		//set tFetchLocation = "/ClinicalDocument/custodian/assignedCustodian/representedCustodianOrganization/id/@root"
		Set tFetchLocation = "/hl7:ClinicalDocument/hl7:custodian/hl7:assignedCustodian/hl7:representedCustodianOrganization/hl7:id"
		Set tFetchItem = "@root"
		

		$$$ThrowOnError(##class(HS.IHE.Util).GetXPathExpression(pDocument.GetDocumentStream(),tFetchLocation,tFetchItem ,.tResults,.txDocument))
		
		Set tResultCount = tResults.Count()
		If (tResultCount = 1) {
			Set tSummary.OID = tResults.GetAt(1).Value
		} 
				

		#; Process sections
		For tSectionIdx = 1:1:pDocument.Sections.Count() {
			Set tSectionObject = pDocument.Sections.GetAt(tSectionIdx)
			Set tSectionStream = ##class(HS.SDA3.QuickStream).%New()
			If tSectionObject.IsDuplicate {
				#;Duplication warning captured and sent on the document
				Continue	
			}
		
			$$$ThrowOnError(tSectionObject.XMLExportToStream(.tSectionStream))
	
			
			#; include normalized section name if present
			If (tSectionObject.NormalizedTitle '= "") {
				/// Set Section if found
				$$$LOGINFO("Section name: "_tSectionObject.Identifier)
				$$$LOGINFO("Section title: "_tSectionObject.Title)
				$$$LOGINFO("Section normalized title: "_tSectionObject.NormalizedTitle)

				
				If (tSectionObject.NormalizedTitle = "Patient") {
					Set tSummary.PatientSection = 1
					}
				ElseIf (tSectionObject.NormalizedTitle = "Allergies") {
					Set tSummary.AllergiesSection = 1
					}
				
				ElseIf (tSectionObject.NormalizedTitle = "Advanced Directives") {
					Set tSummary.AdvancedDirectivesSection = 1
					}
				ElseIf (tSectionObject.NormalizedTitle = "Plan Of Care") {
					Set tSummary.CarePlanSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Procedures") {
					Set tSummary.ProceduresSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Diagnosis") {
					Set tSummary.DiagnosisSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Encounters") {
					Set tSummary.EncountersSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Family History") {
					Set tSummary.FamilyHistorySection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Goals") {
					Set tSummary.GoalsSection  = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Health Concerns") {
					Set tSummary.HealthConcernsSection = 1
				}
				/// Need to check if this is correct normalized title for section
				ElseIf (tSectionObject.NormalizedTitle = "History of Illness") {
					Set tSummary.IllnessHistorySection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Medications") {
					Set tSummary.MedicationSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Problems") {
					Set tSummary.ProblemsSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Observations") {
					Set tSummary.ObservationsSection  = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Results") {
					Set tSummary.LabsSection = 1
				}
				/// Need to check normalized title for radiology results
				ElseIf (tSectionObject.NormalizedTitle = "Radiology Results") {
					Set tSummary.RadsSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Social History") {
					Set tSummary.SocialHistorySection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Immunizations") {
					Set tSummary.VaccinationsSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Documents") {
					Set tSummary.DocumentsSection = 1
				}
				ElseIf (tSectionObject.NormalizedTitle = "Vital Signs") {
					Set tSummary.VitalsSection = 1
				}
				/// Check for Normalized title for this section
				ElseIf (tSectionObject.NormalizedTitle = "Payers") {
					Set tSummary.InsuranceSection = 1
				}
			}
		}
		$$$ThrowOnError(tSummary.%Save())
		
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))

	}
	
	Quit tStatus
}

/***** Document Processing Methods *****/
/// Executes the Document processing once we've fetched the document
Method DoProcessDocument(pDocument As DataService.DS.App.Record.Abstract.Document, pRequest As DataService.DS.Prod.Msg.RecEvalRequest, ByRef pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		#;Filter submission of current record along with all children
		If pDocument.FilterRecordFromProcess {
			$$$LOGINFO("Document filtered")
			Quit	
		}
		
		#; submit whole document
		$$$ThrowOnError(..SendRequestAsync(..ProcessTarget,pRequest,1))	
		
		#;Process header
		Set tHeaderObject = pDocument.Header
		Set tHeaderStream = ##class(HS.SDA3.QuickStream).%New()
		$$$ThrowOnError(tHeaderObject.XMLExportToStream(.tHeaderStream))
		$$$ThrowOnError(..QuickStreamList.Insert(tHeaderStream.%Id()))
		$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest,.tHeaderRequest,tHeaderObject.%ClassName(1),"QuickStream",tHeaderStream.%Id(),tHeaderObject.Title,tHeaderObject.LocationRelativeToParent,tHeaderObject.RecordWarnings))
				
		#; include normalized header name if present
		If (tHeaderObject.NormalizedTitle '= "") {
			$$$ThrowOnError(tHeaderRequest.RecordContext.SetAt(tHeaderObject.NormalizedTitle,"NormalizedSectionName"))
		}
		$$$ThrowOnError(..DoProcessSection(tHeaderObject, tHeaderRequest))
			
		#; Process sections
		For tSectionIdx = 1:1:pDocument.Sections.Count() {
			Set tSectionObject = pDocument.Sections.GetAt(tSectionIdx)
			Set tSectionStream = ##class(HS.SDA3.QuickStream).%New()
			If tSectionObject.IsDuplicate {
				#;Duplication warning captured and sent on the document
				Continue	
			}
		
			$$$ThrowOnError(tSectionObject.XMLExportToStream(.tSectionStream))
			$$$ThrowOnError(..QuickStreamList.Insert(tSectionStream.%Id()))
			$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest,.tSectionRequest, tSectionObject.%ClassName(1), "QuickStream", tSectionStream.%Id(), tSectionObject.Title, tSectionObject.AbsoluteLocation, tSectionObject.LocationRelativeToParent, tSectionObject.RecordWarnings))
			
			#; include normalized section name if present
			If (tSectionObject.NormalizedTitle '= "") {
				$$$ThrowOnError(tSectionRequest.RecordContext.SetAt(tSectionObject.NormalizedTitle,"NormalizedSectionName"))
			}
			$$$ThrowOnError(..DoProcessSection(tSectionObject, tSectionRequest))
		}
			
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus
	}
	
	Quit tStatus
}

/// Executes the Section processing once we've fetched the document
Method DoProcessSection(pSection As DataService.DS.App.Record.Abstract.Section, pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		#;Filter submission of current record along with all children
		If pSection.FilterRecordFromProcess {
			$$$LOGINFO(pSection.%ClassName(1)_":"_pSection.NormalizedTitle_" filtered")
			Quit	
		}
		
		#; Do not process the section if the section is not in the list of sections to be processed.
		#dim tProcessSection As %Boolean = 0
		$$$ThrowOnError(..ProcessSection(pSection.Identifier, .tProcessSection))
		If (tProcessSection=0) Quit
			
		
		#; submit whole section
		$$$ThrowOnError(..SendRequestAsync(..ProcessTarget,pRequest,1))	
		For i=1:1:pSection.Entries.Count() {
			Set tEntryObject = pSection.Entries.GetAt(i)
			Set tEntryStream = ##class(HS.SDA3.QuickStream).%New()
			
			#;If tEntryObject.IsDuplicate {
			#;	If ..ProcessSDAEntries {
			#;		$$$ThrowOnError($$$ERROR("Document cannot be processed on account of duplicate entries.   The source document contains duplicate entries for the ID='"_tEntryObject.EntryIdentifier_"'"))
			#;	}
			#;}
			
			$$$ThrowOnError(tEntryObject.XMLExportToStream(.tEntryStream))
			$$$ThrowOnError(..QuickStreamList.Insert(tEntryStream.%Id()))
			
			#; remove normalized section name if present not needed on entry
			If (pSection.NormalizedTitle '= "") {
				Do pRequest.RecordContext.RemoveAt("NormalizedSectionName")
			}
			
			$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest, .tEntryRequest, tEntryObject.%ClassName(1), "QuickStream", tEntryStream.%Id(), tEntryObject.EntryIdentifier, tEntryObject.AbsoluteLocation, tEntryObject.LocationRelativeToParent, tEntryObject.RecordWarnings))
			$$$ThrowOnError(..DoProcessEntry(tEntryObject, tEntryRequest))

		}
	} Catch Ex {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus
	}
	Quit tStatus
}

/// Executes the Section processing once we've fetched the document
Method DoProcessEntry(pEntry As DataService.DS.App.Record.Abstract.Entry, pRequest As DataService.DS.Prod.Msg.RecEvalRequest, Output pResponse As DataService.DS.Prod.Msg.RecEvalResponse) As %Status
{
	Set tStatus = $$$OK
	Try {
		#;Filter submission of current record along with all children
		If pEntry.FilterRecordFromProcess {
			$$$LOGINFO(pEntry.%ClassName(1)_":"_pEntry.GetRecordRepresentationClass()_" filtered")
			Quit	
		}
		
		#;If the record is necessary for the tree, but we want to guarantee no rules executed against the entry, we can send an entry directly to the 
		#;  results operation
		If 'pEntry.FilterRecordFromProcess && pEntry.SkipEntryProcessing {
			$$$ThrowOnError(##class(DataService.DS.Prod.Msg.SaveRecResultsRequest).CreateFromRecEvalRequest(pRequest,.tTreeStubMsg))
			$$$ThrowOnError(..SendRequestAsync(..ResultTarget,tTreeStubMsg,1))
		}
		
		#; submit whole abstracted entry, unless skipping it
		If ('pEntry.SkipEntryProcessing) {
			$$$ThrowOnError(..SendRequestAsync(..ProcessTarget,pRequest,1))	
		}
		
		If $ISOBJECT(pEntry.TemplatedText) {
			#;Filter submission of current record along with all children
			If pEntry.TemplatedText.FilterRecordFromProcess {
				$$$LOGINFO(pEntry.TemplatedText.%ClassName(1)_":"_pEntry.TemplatedText.GetRecordRepresentationClass(pEntry.SDAClass)_" filtered")	
			}
			Else {
				Set tTemplatedTextStream = ##class(HS.SDA3.QuickStream).%New()
				$$$ThrowOnError(pEntry.TemplatedText.XMLExportToStream(.tTemplatedTextStream))
				$$$ThrowOnError(..QuickStreamList.Insert(tTemplatedTextStream.%Id()))
				
				Set tRecordRepClass = pEntry.TemplatedText.GetRecordRepresentationClass(pEntry.SDAClass)
				$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest, .tTemplatedTextRequest, tRecordRepClass, "QuickStream", tTemplatedTextStream.%Id(), pEntry.TemplatedText.TemplateName, pEntry.TemplatedText.AbsoluteLocation, pEntry.TemplatedText.LocationRelativeToParent, pEntry.TemplatedText.RecordWarnings))
			
				#; submit this subset
				$$$ThrowOnError(..SendRequestAsync(..ProcessTarget,tTemplatedTextRequest,1))	
			}
		}
		
		#; submit sub entries
		For i=1:1:pEntry.SubEntries.Count() {
			Set tSubEntryObject = pEntry.SubEntries.GetAt(i)
			Set tSubEntryStream = ##class(HS.SDA3.QuickStream).%New()
			
			$$$ThrowOnError(tSubEntryObject.XMLExportToStream(.tSubEntryStream))
			$$$ThrowOnError(..QuickStreamList.Insert(tSubEntryStream.%Id()))
			
			$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest, .tSubEntryRequest, tSubEntryObject.%ClassName(1), "QuickStream", tSubEntryStream.%Id(), tSubEntryObject.EntryIdentifier, tSubEntryObject.AbsoluteLocation, tSubEntryObject.LocationRelativeToParent, tSubEntryObject.RecordWarnings))
			$$$ThrowOnError(..DoProcessEntry(tSubEntryObject, tSubEntryRequest))
		}
		
		#; process SDA entry representation
		If ((pEntry.FoundInSDA()) && (pRequest.ProcessSDAEntries)) {
			$$$ThrowOnError(##class(DataService.DS.Prod.Msg.RecEvalRequest).CreateChild(pRequest, .tSDARequest, pEntry.SDAClass, "QuickStream", pEntry.SDAEntryStreamId, pRequest.RecordName, "", "", pEntry.RecordWarnings))
			$$$ThrowOnError(##class(DataService.DS.App.Eval.SDAUtils).GetSDAContainerLocation(pEntry.SDAClass,pEntry.EntryIdentifier,.tSDAAddress))
			Set tSDARequest.AbsoluteLocation = tSDAAddress
			#; location not relative to the parent
			Set tSDARequest.LocationInParent = ""
			$$$ThrowOnError(..SendRequestAsync(..ProcessTarget,tSDARequest,1))
		}
		
	} Catch (Ex) {
		Set tStatus = Ex.AsStatus()
		$$$LOGERROR($SYSTEM.Status.GetErrorText(tStatus))
		$$$ThrowOnError(##class(DataService.DS.App.Utils).CopyXMLClass(pRequest,"RecEvalRequest","DataService.DS.Prod.Msg.RecEvalResponse",.pResponse))
		Set pResponse.Status = tStatus
	}
	
	Quit tStatus
}

/***** OnBefore Document Send *******/
/// Method traverses the document structure caches field evaluators with rules and determines which records 
/// 		need evaluation based upon rule existance and inheritance. 
Method OnBeforeDocumentTextSend(ByRef pDocument As DataService.DS.App.Record.DocumentText, pRuleProfileName As %String, pRecordRepresentationClass As %String, Output pFilterRecordFromProcess = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Note: no record filtering at this level, we want to keep a track of documents submitted independent of any rules
		
		#;Continue to traverse document structure and determine which records need evaluation based upon rule existance and inheritance. 
		$$$ThrowOnError(..OnBeforeDocumentSend(.pDocument,pRuleProfileName,pDocument.GetRecordRepresentationClass(),.pFilterRecordFromProcess))
			
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Method traverses the document structure caches field evaluators with rules and determines which records 
/// 		need evaluation based upon rule existance and inheritance. 
Method OnBeforeDocumentSend(ByRef pDocument As DataService.DS.App.Record.Abstract.Document, pRuleProfileName As %String, pRecordRepresentationClass As %String, Output pFilterRecordFromProcess) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Calling method may pass a default that is incorrect
		Set pFilterRecordFromProcess = 0
		
		#; Gather document field eval and rules cache
		$$$ThrowOnError(..CacheRulesByFieldEvaluators(pRuleProfileName,pRecordRepresentationClass,.tFieldEvaluatorsWithRules))
		
		#;Continue to traverse document structure and determine which records need evaluation based upon rule existance and inheritance. 
		Set tHeader = pDocument.Header
		$$$ThrowOnError(..OnBeforeHeaderSend(.tHeader,pRuleProfileName,tHeader.GetRecordRepresentationClass(),.tFilterHeaderRecordFromProcess))
			
		#;Continue to traverse document structure and determine which records need evaluation based upon rule existance and inheritance.
		#Dim tSection as DataService.DS.App.Record.Abstract.Section
		Set tFilterSectionRecordCt = 0
		For tSectionIdx=1:1:pDocument.Sections.Count() {
			Set tSection = pDocument.Sections.GetAt(tSectionIdx)
			
			$$$ThrowOnError(..OnBeforeSectionSend(.tSection,pRuleProfileName,tSection.GetRecordRepresentationClass(),.tFilterSectionRecord))
			Set tFilterSectionRecordCt = tFilterSectionRecordCt + tFilterSectionRecord
			
			#;Check for duplicate sections in document
			If 'tFilterSectionRecord && tSection.IsDuplicate {
				$$$ThrowOnError(##class(DataService.DS.Data.Serial.RecordWarning).AddWarningToObject(.pDocument,,"Duplicate section with the ID='"_pDocument.Sections.GetAt(tSectionIdx).Identifier_"' found.  Skipping this duplicated section"))
			}
		}
		
		#;Mark record for filtering if no rules exist at this level and no levels below it
		If (tFieldEvaluatorsWithRules.FieldEvaluators.Count() = 0) && (tFilterSectionRecordCt = pDocument.Sections.Count()) && tFilterHeaderRecordFromProcess {
			Set pFilterRecordFromProcess = 1
			Set pDocument.FilterRecordFromProcess = 1
		}	
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Method traverses the document structure caches field evaluators with rules and determines which records 
/// 		need evaluation based upon rule existance and inheritance. 
Method OnBeforeHeaderSend(ByRef pHeader As DataService.DS.App.Record.Abstract.Header, pRuleProfileName As %String, pRecordRepresentationClass As %String, Output pFilterRecordFromProcess) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Calling method may pass a default that is incorrect
		Set pFilterRecordFromProcess = 0
		
		#; Gather header field eval and rules cache
		$$$ThrowOnError(..CacheRulesByFieldEvaluators(pRuleProfileName,pRecordRepresentationClass,.tFieldEvaluatorsWithRules))
		
		#;Mark Record for filtering if no rules exist at this level and no levels below it
		If ((tFieldEvaluatorsWithRules.FieldEvaluators.Count() = 0)) {
			Set pFilterRecordFromProcess = 1
			Set pHeader.FilterRecordFromProcess = 1
		}	
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Method traverses the document structure caches field evaluators with rules and determines which records 
/// 		need evaluation based upon rule existance and inheritance. 
Method OnBeforeSectionSend(ByRef pSection As DataService.DS.App.Record.Abstract.Section, pRuleProfileName As %String, pRecordRepresentationClass As %String, Output pFilterRecordFromProcess) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Calling method may pass a default that is incorrect
		Set pFilterRecordFromProcess = 0
		
		#; Gather section field eval and rules cache
		$$$ThrowOnError(..CacheRulesByFieldEvaluators(pRuleProfileName,pRecordRepresentationClass,.tFieldEvaluatorsWithRules))
		
		#; Gather section field eval and rules cache
		#Dim tEntry as DataService.DS.App.Record.Abstract.Entry

		#;Continue to traverse document structure and determine which records need evaluation based upon rule existance and inheritance.
		Set tFilterEntryRecordCt = 0
		For tEntryIdx=1:1:pSection.Entries.Count() {
			Set tEntry = pSection.Entries.GetAt(tEntryIdx)
			$$$ThrowOnError(..OnBeforeEntrySend(.tEntry,pRuleProfileName,tEntry.GetRecordRepresentationClass(),.tFilterEntryRecord))
			Set tFilterEntryRecordCt = tFilterEntryRecordCt + tFilterEntryRecord
		}
		
		#;Mark Record for filtering if no rules exist at this level and no levels below it
		If (tFieldEvaluatorsWithRules.FieldEvaluators.Count() = 0) && (tFilterEntryRecordCt = pSection.Entries.Count()) {
			Set pFilterRecordFromProcess = 1
			Set pSection.FilterRecordFromProcess = 1
		}		
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Method traverses the document structure caches field evaluators with rules and determines which records 
/// 		need evaluation based upon rule existance and inheritance. 
Method OnBeforeEntrySend(ByRef pEntry As DataService.DS.App.Record.Abstract.Entry, pRuleProfileName As %String, pRecordRepresentationClass As %String, Output pFilterRecordFromProcess) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Calling method may pass a default that is incorrect
		Set pFilterRecordFromProcess = 0
		
		#Dim tTemplatedText as DataService.DS.App.Record.Abstract.TemplatedText
		#Dim tSubEntry as DataService.DS.App.Record.Abstract.Entry
		Set tHasChildren = 0
		#; Gather entry field eval and rules cache
		$$$ThrowOnError(..CacheRulesByFieldEvaluators(pRuleProfileName,pRecordRepresentationClass,.tFieldEvaluatorsWithRules))
		
		Set tFilterTemplatedTextRecord = 1
		If $ISOBJECT(pEntry.TemplatedText) {
			Set tHasChildren = 1
			Set tTemplatedText = pEntry.TemplatedText
			$$$ThrowOnError(..OnBeforeTemplatedTextSend(.tTemplatedText,pRuleProfileName,tTemplatedText.GetRecordRepresentationClass(pEntry.SDAClass),.tFilterTemplatedTextRecord))
		}

		Set tFilterSubEntryRecordCt = 0		
		For tSubEntryIdx = 1:1:pEntry.SubEntries.Count() {
			Set tHasChildren = 1
			Set tSubEntry = pEntry.SubEntries.GetAt(tSubEntryIdx)
			$$$ThrowOnError(..OnBeforeEntrySend(.tSubEntry,pRuleProfileName,tSubEntry.GetRecordRepresentationClass(),.tFilterSubEntryRecord))
			
			Set tFilterSubEntryRecordCt = tFilterSubEntryRecordCt + tFilterSubEntryRecord
		}
		
		#;Mark Record for filtering if no rules exist at this level and no levels below it
		If (tFieldEvaluatorsWithRules.FieldEvaluators.Count() = 0) && ('pEntry.FoundInSDA()) {
			#;We can potentially filter if no rules exist for this record
			If 'tHasChildren {
				#; We can filter if this record has no children
				Set pFilterRecordFromProcess = 1
				Set pEntry.FilterRecordFromProcess = 1	
			}
			ElseIf '$ISOBJECT(pEntry.TemplatedText) {
				#; No templated text exists, evaluate the sub entries only
				If tFilterSubEntryRecordCt = pEntry.SubEntries.Count() {
					#; Filter entry because all SubEntries were filtered
					Set pFilterRecordFromProcess = 1
					Set pEntry.FilterRecordFromProcess = 1	
				}
			}
			ElseIf ($GET(tFilterTemplatedTextRecord) && (tFilterSubEntryRecordCt = pEntry.SubEntries.Count())) {
				#; Templated text exists, evaluate templated text and sub-entries
				Set pFilterRecordFromProcess = 1
				Set pEntry.FilterRecordFromProcess = 1	
			}
		}
		
		#;If this entry is skipped (i.e. the rules are NA) prevent indirect submission of the record by the preprocessor
		#; if it has no children or all it's children are filtered
		If pEntry.SkipEntryProcessing && 'tHasChildren {
			Set pFilterRecordFromProcess = 1
			Set pEntry.FilterRecordFromProcess = 1	
		}
		ElseIf pEntry.SkipEntryProcessing && $GET(tFilterTemplatedTextRecord) && (tFilterSubEntryRecordCt = pEntry.SubEntries.Count()){
			Set pFilterRecordFromProcess = 1
			Set pEntry.FilterRecordFromProcess = 1	
		}
		
		#;Add warning to duplicate entries that are not filtered		
		If pEntry.IsDuplicate {
			$$$ThrowOnError(##class(DataService.DS.Data.Serial.RecordWarning).AddWarningToObject(pEntry,,"Duplicate entry with the ID='"_pEntry.EntryIdentifier_"' identified."))		
		}
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/// Method traverses the document structure caches field evaluators with rules and determines which records 
/// 		need evaluation based upon rule existance and inheritance. 
Method OnBeforeTemplatedTextSend(ByRef pTemplatedText As DataService.DS.App.Record.Abstract.TemplatedText, pRuleProfileName As %String, pRecordRepresentationClass As %String, Output pFilterRecordFromProcess) As %Status
{
	Set tSC = $$$OK
	Try {
		#;Calling method may pass a default that is incorrect
		Set pFilterRecordFromProcess =0
		
		#; Gather TemplatedText field eval and rules cache
		$$$ThrowOnError(..CacheRulesByFieldEvaluators(pRuleProfileName,pRecordRepresentationClass,.tFieldEvaluatorsWithRules))
	
		#;Mark Record for filtering if no rules exist at this level and no levels below it
		If (tFieldEvaluatorsWithRules.FieldEvaluators.Count() = 0) {
			Set pFilterRecordFromProcess = 1
			Set pTemplatedText.FilterRecordFromProcess = 1
		}
	}
	Catch Ex {
		Set tSC = Ex.AsStatus()
	}
	Quit tSC
}

/***** Response handling *****/
Method OnResponse(request As %Library.Persistent, ByRef pResponse As %Library.Persistent, callrequest As %Library.Persistent, pCallResponse As %Library.Persistent, pCompletionKey As %String) As %Status
{
	#;Identify error in async processing.  Move the first error into the Preprocessor response
	If $$$ISERR(pCallResponse.Status) && (pResponse.Status="") {
		Set pResponse.Status = pCallResponse.Status
	}
	#; only used in ASYNC mode, when we aren't collecting results to return anyway, so nothing to do.
    Quit $$$OK
}

/*** Cleanup Quick Streams in QuickStreamList  ***/
Method CleanupQuickStreamList() As %Status
{
	If ..ClearQuickStreams {
		Set tStreamClearedCount = 0
		Set tStreamListCount = ..QuickStreamList.Count()
		#; clean up quick streams
	    For tQuickStreamIndex = 1:1:tStreamListCount {
		 	Set tStreamToClear = ##class(HS.SDA3.QuickStream).%OpenId(..QuickStreamList.GetAt(tQuickStreamIndex))   
	 		If ($ISOBJECT(tStreamToClear)) {
		 		Do tStreamToClear.Clear(1)
		 		Set tStreamClearedCount = tStreamClearedCount + 1
		 	}
	    }
	    $$$TRACE(tStreamClearedCount_" of "_tStreamListCount_" QuickStreams Cleared.")
	}
    
    Quit $$$OK
}

Method OnComplete(request As %Library.Persistent, ByRef response As %Library.Persistent) As %Status
{
    #; clean up quick streams
	Do ..CleanupQuickStreamList()
	
	If ('$ISOBJECT($GET(response))) || (response.Status = "") || $$$ISOK(response.Status) {
		 #; if this is a synchronous call, we need to get the results
		If (request.ProcessMode = "SYNC") {
			Set tGetResultsRequest = ##class(DataService.DS.Prod.Msg.RecordResultRequest).%New()
			Set tGetResultsRequest.BatchId = request.BatchId
			Set tGetResultsRequest.RecordSource = request.RecordSource
			Set tGetResultsRequest.RecordRepresentationClass = request.RecordRepresentationClass
			Set tGetResultsRequest.RecordSourceKey = request.RecordSourceKey
			Set tGetResultsRequest.ResponseContext = request.ResponseContext
			Set tGetResultsRequest.ResultInterpretation = request.ResultInterpretation
			$$$ThrowOnError(..SendRequestSync(..ResultOperations,tGetResultsRequest,.response))

			//RAJ: Send to DynamoDB
			$$$ThrowOnError(##class(DataService.DS.App.DSUtils).SendReportToDynamoDB(request,response))
		}
	}
	Else {
		#;Note StatusErrorText is not stored in result structure
		Do DecomposeStatus^%apiOBJ(response.Status,.err,"-d") 
		Set tResultErrorTxt = ""
		For i=1:1:err {
			Set tResultErrorTxt = tResultErrorTxt_" "_err(i)
		}
		Set response.StatusErrorText =tResultErrorTxt
		Set response.Status = $$$ERROR($$$GeneralError,"Processing Failed: "_tResultErrorTxt)
	}
	
    #;Record execution time
    If (..EvalStartTime'="") {
	    Quit ##class(DataService.DS.Data.Result.PerformanceLog).CreatePerformanceLog(..EvalStartTime,,$$$DSPerfLogGroupRecordEval,response.GetUniqueBatchRecordProcessingKey())
    } 
    Quit $$$OK
}

ClassMethod ProcessSection(pSectionIdentifier As %String(MAXLEN=255), Output pProcessSection As %Boolean = 0) As %Status
{
	
 #dim eException As %Exception.AbstractException
 #dim tSC As %Status = $$$OK
 Try {
 	
 	// Always Process the Patient and Header.
 	If ((pSectionIdentifier="Header") || (pSectionIdentifier="Patient")) 
 	{
	 	Set pProcessSection = 1
	 	Quit
 	}
 	
	#dim tStatement As %SQL.Statement = ##class(%SQL.Statement).%New()
	#dim tSQL As %String = "SELECT 1 FROM DataService_DS_Data.ConfigTable where SetName IN ('ProcessSection-CDA-CCDA', 'ProcessSection-CDA-C32') AND Item=?"
	$$$THROWONERROR(tSC,tStatement.%Prepare(tSQL))
	#dim tRS As %ResultSet = tStatement.%Execute(pSectionIdentifier)
	Set pProcessSection = tRS.%Next() // Return 0 if there are no records, otherwise return 1 (process this section).

 }
 Catch eException
 {
    Set tSC = eException.AsStatus()
 }
 Quit tSC
}

}
