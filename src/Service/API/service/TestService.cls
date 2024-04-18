Class DataService.API.service.TestService Extends %RegisteredObject
{

ClassMethod GetAll() As %Status
{
    quit $$$OK

    Set qry = "SELECT * FROM DOLPHIN_DB_Data.Facility"
    #dim tSC As %Status = $$$OK


    Set tStatement = ##class(%SQL.Statement).%New()  
    Set qStatus = tStatement.%Prepare(qry)
    If tSC'=1 {WRITE "%Prepare failed:" DO $System.Status.DisplayError(qStatus) QUIT}
    Set rset = tStatement.%Execute()
    
    Set %response.ContentType = ..#CONTENTTYPEJSON
    Set %response.Headers("Access-Control-Allow-Origin")="*"

    Set result = []

    While rset.%Next() {
        Set item = {}
        Set item.FacilityId = rset.FacilityId
        Set item.Name = rset.Name
        Set item.Contact = rset.Contact
        Do result.%Push(item)
    }

    Write result.%ToJSON()
    Quit tSC
}

ClassMethod GetOne(id As %String) As %Status
{
    quit $$$OK
    
    #dim tSC As %Status = $$$OK
    Set qry = "SELECT * FROM DOLPHIN_DB_Data.Facility WHERE FacilityId = '"_id_"'"


    Set tStatement = ##class(%SQL.Statement).%New()  
    Set qStatus = tStatement.%Prepare(qry)
    If tSC'=1 {WRITE "%Prepare failed:" DO $System.Status.DisplayError(qStatus) QUIT}
    Set rset = tStatement.%Execute()
    
    Set %response.ContentType = ..#CONTENTTYPEJSON
    Set %response.Headers("Access-Control-Allow-Origin")="*"

    Set result = []

    While rset.%Next() {
        Set item = {}
        Set item.FacilityId = rset.FacilityId
        Set item.Name = rset.Name
        Set item.Contact = rset.Contact
        Do result.%Push(item)
    }

    Write result.%ToJSON()
    Quit tSC
}

ClassMethod Create() As %Status
{
    quit $$$OK
    
    #dim tSC As %Status = $$$OK

    Set data = {}.%FromJSON(%request.Content)

    set FacilityId = data.FacilityId
    set Name = data.Name
    set Contact = data.Contact

    Set qry = "INSERT INTO DOLPHIN_DB_Data.Facility (FacilityId, Name, Contact) VALUES ('"_FacilityId_"', '"_Name_"', '"_Contact_"')"


    Set tStatement = ##class(%SQL.Statement).%New()  
    Set qStatus = tStatement.%Prepare(qry)
    If tSC'=1 {WRITE "%Prepare failed:" DO $System.Status.DisplayError(qStatus) QUIT}
    Set rset = tStatement.%Execute()
    
    Set %response.ContentType = ..#CONTENTTYPEJSON
    Set %response.Headers("Access-Control-Allow-Origin")="*"

    Set result = []

    While rset.%Next() {
        Set item = {}
        Set item.message = "Item created successfully"
        Do result.%Push(item)
    }

    Write result.%ToJSON()
    Quit tSC
}

ClassMethod Update(id As %String) As %Status
{
    quit $$$OK

    #dim tSC As %Status = $$$OK
    #; Set qry = "DELETE FROM DOLPHIN_DB_Data.Facility WHERE FacilityId = '"_id_"'"


    #; Set tStatement = ##class(%SQL.Statement).%New()  
    #; Set qStatus = tStatement.%Prepare(qry)
    #; If tSC'=1 {WRITE "%Prepare failed:" DO $System.Status.DisplayError(qStatus) QUIT}
    #; Set rset = tStatement.%Execute()
    
    Set %response.ContentType = ..#CONTENTTYPEJSON
    Set %response.Headers("Access-Control-Allow-Origin")="*"

    Set result = []
    
    Set item = {}
    Set item.message = "This is not working yet"

    Do result.%Push(item)

    Write result.%ToJSON()
    Quit tSC
}

ClassMethod Delete(id As %String) As %Status
{
    quit $$$OK
    
    #dim tSC As %Status = $$$OK
    Set qry = "DELETE FROM DOLPHIN_DB_Data.Facility WHERE FacilityId = '"_id_"'"


    Set tStatement = ##class(%SQL.Statement).%New()  
    Set qStatus = tStatement.%Prepare(qry)
    If tSC'=1 {WRITE "%Prepare failed:" DO $System.Status.DisplayError(qStatus) QUIT}
    Set rset = tStatement.%Execute()
    
    Set %response.ContentType = ..#CONTENTTYPEJSON
    Set %response.Headers("Access-Control-Allow-Origin")="*"

    Set result = []

    While rset.%Next() {
        Set item = {}
        Set item.message = "Item deleted successfully"
    }

    Write result.%ToJSON()
    Quit tSC
}

}

