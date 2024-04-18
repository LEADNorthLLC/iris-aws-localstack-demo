Class FHIR.Visualizer.Model.Record Extends (%Persistent, %XML.Adaptor)
{

/// Record holds possible streams
/// CCDA XML Content: CCDAContentXML
/// SDA XML Content: SDAContentXML
/// HL7 Content: HL7Content
/// FHIR JSON Content: FHIRContentJSON
/// This property will be populated if there was an error pulling this record durring evaluation.  No results will link to this record
Property Error As %Status [ InitialExpression = {$$$OK} ];

/// This property is populated along with Error
Property ErrorLoc As %String(MAXLEN = 500);

/// CCDA XML Content
Property CCDAContentXML As %Stream.Object;

/// SDA XML Content
Property SDAContentXML As %Stream.Object;

Storage Default
{
<Data name="RecordDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Error</Value>
</Value>
<Value name="3">
<Value>ErrorLoc</Value>
</Value>
<Value name="4">
<Value>CCDAContentXML</Value>
</Value>
<Value name="5">
<Value>SDAContentXML</Value>
</Value>
</Data>
<DataLocation>^HS.Local.Visualizer950B.RecordD</DataLocation>
<DefaultData>RecordDefaultData</DefaultData>
<IdLocation>^HS.Local.Visualizer950B.RecordD</IdLocation>
<IndexLocation>^HS.Local.Visualizer950B.RecordI</IndexLocation>
<StreamLocation>^HS.Local.Visualizer950B.RecordS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
