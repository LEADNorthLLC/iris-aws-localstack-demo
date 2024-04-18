Include DSDomain

/// <BR> Used to query list of available lists and values in lists
Class DataService.DS.Prod.REST.Config Extends %CSP.REST
{

/** Change Log
2017-04-03 Aaron Miberger - code review
2017-04-27 Jon Trumble - Added CORS methods
2017-05-09 Jon Trumble - Added UseSession
2023-12-16 Chi Nguyen-Rettig - Hack to fix spaces in URL issue
**/
/// Require Cross-origin resource sharing handling.
Parameter HandleCorsRequest = 1;

/// Use Session for REST Services
Parameter UseSession = 1;

/// <BR> Mapped through DataService.DS.Prd.REST.ServiceMap
/// <BR> PREFIX:  /Config
/// <BR> EXAMPLES:
/// <BR> 	Method:GET
/// <BR> 	URL: http://localhost:57772/csp/DataService/DSAT/Config/:tableName
XData UrlMap
{
<Routes>
	<Route Url="/:tableName" Method="GET" Call="ConfigTableGet" />
	<Route Url="/" Method="GET" Call="ConfigTableList" />
	<Route Url="/RuleProfiles/:pActive" Method="GET" Call="RuleProfileList" />
	<Route Url="/Rules/" Method="GET" Call="RulesGet" /> 	
	<Route Url="/AddUpdateRuleProfile/:pProfileName" Method="POST" Call="AddUpdateRuleProfile" /> 
	</Routes>
}

/// Handle Cross-origin resource sharing
ClassMethod OnHandleCorsRequest(pURL As %String) As %Status
{
	
	#dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    
    #dim %request As %CSP.Request
    #dim %response As %CSP.Response
    
    #dim tOrigin,tHeaders,tMethod As %String
    
    Try {
        
        #; Get the origin
        Set tOrigin=$GET(%request.CgiEnvs("HTTP_ORIGIN"))
        
        Set tRestrictCORS=$GET(^DSAT.RESTRICTCORS,0) 
		Set tAllowedOrigin=$GET(^DSAT.ALLOWEDORIGIN,"http://localhost:57772") 
		If ((tAllowedOrigin=tOrigin) || (tRestrictCORS=0))
		{       
	        #; Allow requested origin
	        Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Origin",tOrigin)
	       
	        #; Set allow credentials to be true
	        Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Credentials","true")
	        
	        #; Allow requested headers
	        Set tHeaders=$GET(%request.CgiEnvs("HTTP_ACCESS_CONTROL_REQUEST_HEADERS"))
	        Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Headers",tHeaders)
	        
	        #; Allow requested method
	        Set tMethod=$GET(%request.CgiEnvs("HTTP_ACCESS_CONTROL_REQUEST_METHOD"))
	        Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Methods",tMethod)
		}
        
    } Catch (e) {
        Set tSC=e.AsStatus()
    }
    Quit tSC
}

/// <BR> Lookup the contents of a single config table.   Optionally pass RECURSIVE in the url parameters to retrieve all related config tables
ClassMethod ConfigTableGet(pTableName As %String) As %Status
{
	Set tSC = $$$OK
	Try {		

		//CNR: So hackish that I hate myself - using spaces in web params is not cool
		If pTableName = "EMR%20VERSION" {
			Set pTableName = "EMR VERSION"
		}
		If pTableName = "SECTION%20ICONS" {
			Set pTableName = "SECTION ICONS"
		}
		If pTableName = "UI%20TEMPLATES" {
			Set pTableName = "UI TEMPLATES"
		}


		Set tIsRecursive = $CASE($GET(%request.Data("RECURSIVE", 1)), 0:0, :1)

		#;Dispatch request to production
		$$$ThrowOnError(##class(DataService.DS.Prod.Service.ConfigService).ConfigTableGetManual(pTableName, tIsRecursive, .tResponse))
		#Dim tResponse as DataService.DS.Prod.Msg.ConfigTableGetResponse
		
		If $$$ISERR(tResponse.Status) {
			Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		}
		Set tResponse.Status = ""
		
		#;Write output 
		If $GET(%request.CgiEnvs("HTTP_ACCEPT"),"*/*") [ "application/xml" {
			Set %response.ContentType="application/xml"
			$$$ThrowOnError(tResponse.XMLExportToStream(.tStream))
		} 
		Else {
			Set %response.ContentType="application/json"
			Set tStream=##class(%Stream.GlobalCharacter).%New()		
			$$$ThrowOnError(##class(DataService.DS.App.DynamicObject).toJSON(tResponse, .tStream))
		}
		Do tStream.OutputToDevice()
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
		If $$$TESTMODE ZWrite tSC
		Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		Set tSC = $$$OK
	}
	Quit tSC
}

/// <BR> Create or replace
ClassMethod ConfigTableList() As %Status
{
	Set tSC = $$$OK
	Try {		
		#;Dispatch request to production
		$$$ThrowOnError(##class(DataService.DS.Prod.Service.ConfigService).ConfigTableListManual(.tResponse))		
		#Dim tResponse as DataService.DS.Prod.Msg.ConfigTableListResponse
	
		If $$$ISERR(tResponse.Status) {
			Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		}
		Set tResponse.Status = ""
		
		#;Write output 
		If $GET(%request.CgiEnvs("HTTP_ACCEPT"),"*/*") [ "application/xml" {
			Set %response.ContentType="application/xml"
			$$$ThrowOnError(tResponse.XMLExportToStream(.tStream))
		} 
		Else {
			Set %response.ContentType="application/json"
			Set tStream=##class(%Stream.GlobalCharacter).%New()		
			$$$ThrowOnError(##class(DataService.DS.App.DynamicObject).toJSON(tResponse, .tStream))
		}
		Do tStream.OutputToDevice()
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
		If $$$TESTMODE ZWrite tSC
		Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		Set tSC = $$$OK
	}
	Quit tSC
}

/// <BR> Return a list of Rule Profiles that are active or all rule profiles
ClassMethod RuleProfileList(pActive) As %Status
{
	
	Set tSC = $$$OK
	Try {		
		#;Dispatch request to production
		#Dim tResponse as DataService.DS.Prod.Msg.RuleProfileListResponse

		$$$ThrowOnError(##class(DataService.DS.Prod.Service.ConfigService).RuleProfileListManual(pActive,.tResponse))
	
		If $$$ISERR(tResponse.Status) {
			Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		}
		Set tResponse.Status = ""
		
		#;Write output 
		If $GET(%request.CgiEnvs("HTTP_ACCEPT"),"*/*") [ "application/xml" {
			Set %response.ContentType="application/xml"
			$$$ThrowOnError(tResponse.XMLExportToStream(.tStream))
		} 
		Else {
			Set %response.ContentType="application/json"
			Set tStream=##class(%Stream.GlobalCharacter).%New()		
			$$$ThrowOnError(##class(DataService.DS.App.DynamicObject).toJSON(tResponse, .tStream))
		}
		Do tStream.OutputToDevice()
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
		If $$$TESTMODE ZWrite tSC
		Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		Set tSC = $$$OK
	}
	Quit tSC
}

ClassMethod RulesGet() As %Status
{
	Set tSC = $$$OK
	Try {		
		#;Dispatch request to production
		#Dim tJSONRulesList as %DynamicObject

		$$$ThrowOnError(##class(DataService.DS.App.DSUtils).getRuleDefsJSONCollection(,.tJSONRulesList))
		
		#;Write output - you get JSON whether you want it or not. 
			Set %response.ContentType="application/json"
			Set tStream=##class(%Stream.GlobalCharacter).%New()		
			$$$ThrowOnError(##class(DataService.DS.App.DynamicObject).toJSON(tJSONRulesList, .tStream)) //I guess.
			//Set tJSONStr=tJSONRulesList.%ToJSON(tStream)
			//Set tStream="TEST"
			Do tStream.OutputToDevice()
	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
		If $$$TESTMODE ZWrite tSC
		Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		Set tSC = $$$OK
	}
	Quit tSC
}

ClassMethod AddUpdateRuleProfile(pProfileName) As %Status
{
	Set tSC = $$$OK
	Try {		
		If %request.ContentType = "application/json" {
			$$$ThrowOnError(##class(DataService.DS.App.DynamicObject).fromJSON(%request.Content,.tReqBody))
			$$$ThrowOnError(##class(DataService.DS.App.DSUtils).AddUpdateRuleProfile(pProfileName,tReqBody))
		} 
		Else {
			If $$$TESTMODE Write "Request header type not supported, change to 'application/json'"
			Set %response.Status = ..#HTTP406NOTACCEPTABLE
			Quit
		}


	} 
	Catch Ex {
		Set tSC = Ex.AsStatus()
		If $$$TESTMODE ZWrite tSC
		Set %response.Status = ..#HTTP500INTERNALSERVERERROR
		Set %response = tSC
		Set tSC = $$$OK
	}
	Quit tSC
}


}
