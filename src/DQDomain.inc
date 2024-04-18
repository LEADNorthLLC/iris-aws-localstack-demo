ROUTINE DSDomain [Type=INC]
#; Quality Domains
#define DSCompleteness   					"Completeness"
#define DSUniqueness   						"Uniqueness"
#define DSValidity   						"Validity"
#define DSAccuracy   						"Accuracy"
#define DSConsistency   					"Consistency"
#define DSIntegrity	 	  					"RefIntegrity"

#;Results settings
#define DSCubeName							"DSATRules"
#define DSCubeStatComplete					"COMPLETED"
#define DSCubeStatEdit						"EDITED"
#define DSCubeStatInbuild					"INBUILD"
#define DSCubeStatDelete					"DELETED"

#;Standard Record Types
#define DSRecTypeSDA						"SDAEntry"
#define DSRecTypeHSHI						"HSHI"
#define DSRecTypeCDA						"CDA"

#;PerformanceLogTypes
#define DSPerfLogRule						"Rule Evaluation"
#define DSPerfLogFieldEval					"Field Evaluation"
#define DSPerfLogLocationFetch				"Location Fetch"
#define DSPerfLogRecordEval					"Record Evaluation"
#define DSPerfLogGroupRecordEval			"Group Record Evaluation"
#define DSPerfLogRecordFetch				"Record Fetch"


#; Version checking
#define OpenClassDefinition(%classname)		##class(%Dictionary.ClassDefinition).%OpenId(%classname)
#;Force environment to run as pre HS16
#;define IsClassDefined(%classname)			$CASE("%Library.Array,%Library.Object,%Library.DynamicObject,%Library.DynamicArray"[%classname,1:0,:##class(%Dictionary.ClassDefinition).%ExistsId(%classname))
#;Force environment to run as HS16.1
#;define IsClassDefined(%classname)			$CASE("%Library.DynamicObject,%Library.DynamicArray"[%classname,1:0,:##class(%Dictionary.ClassDefinition).%ExistsId(%classname))
#;Run as current version
#define IsClassDefined(%classname)			##class(%Dictionary.ClassDefinition).%ExistsId(%classname)
	
#; Shorthand DynamicObject Access
#define DynamicArrayCount(%obj)				##class(DataService.DS.App.DynamicArray).Count(%obj)
#define DynamicArrayGet(%obj,%idx)			##class(DataService.DS.App.DynamicArray).GetAt(%obj,%idx)
#define DynamicArraySet(%obj,%idx,%val)		##class(DataService.DS.App.DynamicArray).SetAt(%obj,%idx,%val)
#define IsDynamicArray(%obj)				##class(DataService.DS.App.DynamicArray).IsDynamicArray(%obj)

#;Application Settings
#define APPSETPerfLogEnabled				"Performance Log Enabled"
#define APPSETReturnProcessingError			"Return Processing Error"

#define APPSETDescriptionIsSignificant		"Description Is Significant"
#define APPSETCodingSystemIsSignificant		"Coding System Is Significant"
#define APPSETIgnoreCodeCase				"Ignore Code Case"
#define APPSETIgnoreDescriptionCase			"Ignore Description Case"
#define	APPSETIgnoreDescriptionWhiteSpace	"Ignore Description White Space"
#define APPSETIgnoreCodingSystemCase		"Ignore Coding System Case"
#define APPSETRuleFailureCategoryPass		"Rule Failure Category Pass Category"
#define APPSETRuleFailureCategoryFail		"Rule Failure Category Default Category"

#; MISC
#define DSNA								"Not Applicable"
#define TESTMODE							$GET(^DSAT.TESTMODE)
#define LIBRARYDIR							$GET(^DSAT.LIBRARYDIR)
#define DSNoLocation						"**No Location**"

#; Better Unit Test Macros:  Can only be used in a class that extends DataService.DS.Test.Base
#def1arg DSAssertEquals(%args)      		..DSAssertEqualsViaMacro(##quote(%args),%args)
#def1arg DSAssertNotEquals(%args)   		..DSAssertNotEqualsViaMacro(##quote(%args),%args)
#def1arg DSAssertTrue(%args)				..DSAssertTrueViaMacro(##quote(%args),%args)
#def1arg DSAssertNotTrue(%args)				..DSAssertNotTrueViaMacro(##quote(%args),%args)
#def1arg DSAssertStatusEquals(%args)		..DSAssertStatusEqualsViaMacro(##quote(%args),%args)
#def1arg DSAssertStatusOK(%args) 			..DSAssertStatusOKViaMacro(##quote(%args),%args)
#def1arg DSAssertStatusNotOK(%args) 		..DSAssertStatusNotOKViaMacro(##quote(%args),%args)
#define DSLineBreak							..DSLineBreak()

#; Error Handling
#define ReturnOnError(%expr)  				Set sc=%expr Return:$$$ISERR(sc) sc
#define DSFieldEvaluationError(%rs,%text)	$$$ERROR($$$GeneralError,"FieldEvaluatorError - Field '"_%rs.Field_"' in Subject '"_%rs.Subject_"': "_%text)
 
