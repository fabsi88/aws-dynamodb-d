import std.stdio;

import vibe.d;

alias AttributeName = string;
alias Key = AttributeValue[AttributeName];
alias AttributeMap = AttributeValue[AttributeName];
alias StringAttributeValue = string;
alias NumberAttributeValue = string;
alias TableName = string;

/// <p>Represents the data for an attribute. You can set one, and only one, of the elements.</p> <p>Each attribute in an item is a name-value pair. An attribute can be single-valued or multi-valued set. For example, a book item can have title and authors attributes. Each book has one title but can have many authors. The multi-valued attribute is a set; duplicate values are not allowed.</p>
struct AttributeValue
{
	///
	StringAttributeValue S;
	///
	NumberAttributeValue N;
}

/// <p>Represents the input of a <i>GetItem</i> operation.</p>
struct GetItemInput
{
	/// The name of the table containing the requested item.
	TableName tableName;
	///
	Key key;
	//AttributesToGet....
}

///
struct GetItemOutput
{
	///
	AttributeMap item;
}

///
interface DynamoDBApi
{	
	import vibe.http.common:HTTPMethod;

	///
	@method(HTTPMethod.POST)
	GetItemOutput GetItem(GetItemInput input);
}

///
static DynamoDBApi createDynamoDBApi(string credentials,string signedheaders,string secret)
{
	import vibe.web.rest:RestInterfaceClient;
	import vibe.http.client:HTTPClientRequest;

	auto res = new RestInterfaceClient!DynamoDBApi("https://dynamodb.eu-central-1.amazonaws.com");

	return res;
}



/// see http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
string createAwsSigning(string secret, string date, string region, string service)
{
	import std.digest.hmac:hmac;
	import std.digest.sha:SHA256;
	import std.digest.digest:toHexString,LetterCase;

	auto kSecret = ("AWS4"~secret).representation;

	enum awsRequest = "aws4_request".representation;
	auto kDate = date.representation.hmac!SHA256(kSecret);
	auto kRegion = region.representation.hmac!SHA256(kDate);
	auto kService = service.representation.hmac!SHA256(kRegion);
	auto kSigning = awsRequest.hmac!SHA256(kService);

	return kSigning.toHexString!(LetterCase.lower).dup;
}

///
unittest
{
	immutable key = createAwsSigning("wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY","20150830","us-east-1","iam");
	assert(key == "c4afb1cc5771d871763a393e44b703571b55cc28424d1a5e86da6ed3c154a4b9");
}

enum service = "dynamodb";
enum host = "dynamodb.eu-central-1.amazonaws.com";
enum region = "eu-central-1";
enum endpoint = "https://dynamodb.eu-central-1.amazonaws.com/";

void main()
{
	//DynamoDBApi api = new RestInterfaceClient!DynamoDBApi("http://dynamodb.eu-west-1.amazonaws.com");
	import std.string;
	GetItemInput input;
	input.tableName = "alexa-telly-users";
	input.key["user-id"] = AttributeValue("bar");
	//writefln("%s",api.GetItem(input));

	auto contentType = "application/x-amz-json-1.0";
	enum canonicalUri = '/';

	auto accessKey = "";
	auto secretKey = "";

	auto time = Clock.currTime;
	auto amzDate = (cast(DateTime)time.toUTC()).toISOString() ~ "Z";
	writeln(amzDate);
	auto dateStamp = (cast(Date)time.toUTC()).toISOString();
	writeln(dateStamp);
	

	requestHTTP(endpoint,
		(scope HTTPClientRequest req) {
			import std.digest.sha:SHA256;
			import std.digest.digest:digest,toHexString;
			import std.string;
			req.method = HTTPMethod.POST;
			
			//auto requestParameters = serializeToJson(input).toPrettyString();
			//writeln(requestParameters);
			auto amzTarget = "DynamoDB_20120810.CreateTable";

			auto canonicalHeaders = .format("content-type:%s\nhost:%s\nx-amz-date:%s\nx-amz-target:%s\n",contentType,host,amzDate,amzTarget);
			enum signedHeaders = "content-type;host;x-amz-date;x-amz-target";

			auto request_parameters =  "{";
			request_parameters ~=  "\"KeySchema\": [{\"KeyType\": \"HASH\",\"AttributeName\": \"Id\"}],";
			request_parameters ~=  "\"TableName\": \"TestTable\",\"AttributeDefinitions\": [{\"AttributeName\": \"Id\",\"AttributeType\": \"S\"}],";
			request_parameters ~=  "\"ProvisionedThroughput\": {\"WriteCapacityUnits\": 5,\"ReadCapacityUnits\": 5}";
			request_parameters ~=  "}";
			auto canonicalQuerystring = "";
			//writeln(request_parameters);
		
			auto payloadHash = digest!SHA256(request_parameters).toHexString().toLower();
			//writeln(request_parameters);
			//writeln(payloadHash);
			auto canonical_request = .format("POST\n%s\n%s\n%s\n%s\n%s",canonicalUri,canonicalQuerystring,canonicalHeaders,signedHeaders,payloadHash);
			writeln("Canonical:"~canonical_request);
			
			string algorithm = "AWS4-HMAC-SHA256";
			string credential_scope = dateStamp ~ "/" ~ region ~ "/" ~ service ~ "/" ~ "aws4_request";
			auto sha = digest!SHA256(canonical_request).toHexString().toLower();
			writeln(sha);
			string string_to_sign = .format("%s\n%s\n%s\n%s",algorithm, amzDate, credential_scope, sha);
			writeln(string_to_sign);
			auto signature = createAwsSigning(secretKey,dateStamp,region,service);
			req.headers["Content-Type"] = contentType;
			req.headers["Authorization"] = .format("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",accessKey,credential_scope,signedHeaders,signature);
			req.headers["X-Amz-Target"] = amzTarget;
			req.headers["X-Amz-Date"] = amzDate;

			req.writeBody(cast(ubyte[])request_parameters);
		},
		(scope res) {
			logInfo("Response: %s", res.bodyReader.readAllUTF8());
			exitEventLoop();
		}
	);

	runEventLoop();
}
