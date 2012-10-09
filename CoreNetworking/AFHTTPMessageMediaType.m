//
//  AFHTTPMessageAccept.m
//  CoreNetworking
//
//  Created by Keith Duncan on 07/10/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFHTTPMessageMediaType.h"

#import <objc/runtime.h>

NSString *const AFHTTPMessageMediaTypeTypeKey = @"type";
NSString *const AFHTTPMessageMediaTypeParametersKey = @"parameters";

@implementation AFHTTPMessageMediaType

@synthesize type=_type;
@synthesize parameters=_parameters;

- (id)initWithType:(NSString *)type parameters:(NSDictionary *)parameters {
	NSParameterAssert(type != nil);
	
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_type = [type copy];
	_parameters = [parameters copy];
	
	return self;
}

- (void)dealloc {
	[_type release];
	[_parameters release];
	
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ %@", [super description], [self type]];
}

@end

NSString *const AFHTTPMessageAcceptTypeAcceptParametersKey = @"acceptParameters";

@implementation AFHTTPMessageAcceptType

@synthesize acceptParameters=_acceptParameters;

- (id)initWithType:(NSString *)type parameters:(NSDictionary *)parameters acceptParameters:(NSDictionary *)acceptParameters {
	self = [self initWithType:type parameters:parameters];
	if (self == nil) {
		return nil;
	}
	
	_acceptParameters = [acceptParameters copy];
	
	return self;
}

- (void)dealloc {
	[_acceptParameters release];
	
	[super dealloc];
}

@end

#pragma mark - Scanners

static NSMutableArray * (^_charactersToBeSkippedStackForScanner)(NSScanner *) = ^ NSMutableArray * (NSScanner *scanner) {
	AFNETWORK_NSSTRING_CONTEXT(_AFHTTPMessageAcceptScannerCharactersToBeSkippedStackAssociationContext);
	
	NSMutableArray *stack = objc_getAssociatedObject(scanner, &_AFHTTPMessageAcceptScannerCharactersToBeSkippedStackAssociationContext);
	if (stack == nil) {
		stack = [NSMutableArray array];
		objc_setAssociatedObject(scanner, &_AFHTTPMessageAcceptScannerCharactersToBeSkippedStackAssociationContext, stack, OBJC_ASSOCIATION_RETAIN);
	}
	
	return stack;
};
static void (^_popCharactersToBeSkipped)(NSScanner *) = ^ void (NSScanner *scanner) {
	NSMutableArray *charactersToBeSkippedStack = _charactersToBeSkippedStackForScanner(scanner);
	NSCParameterAssert([charactersToBeSkippedStack count] > 0);
	NSCharacterSet *characterSet = [charactersToBeSkippedStack lastObject];
	[scanner setCharactersToBeSkipped:(![characterSet isEqual:[NSNull null]] ? characterSet : nil)];
	[charactersToBeSkippedStack removeLastObject];
};
static void (^(^pushCharactersToBeSkipped)(NSScanner *, NSCharacterSet *))(void) = ^ (NSScanner *scanner, NSCharacterSet *charactersToBeSkipped) {
	NSMutableArray *charactersToBeSkippedStack = _charactersToBeSkippedStackForScanner(scanner);
	[charactersToBeSkippedStack addObject:([scanner charactersToBeSkipped] ? : [NSNull null])];
	[scanner setCharactersToBeSkipped:charactersToBeSkipped];
	
	return (void (^)(void))[[^ void (void) {
		_popCharactersToBeSkipped(scanner);
	} copy] autorelease];
};

static NSString * (^tryAtomicScanGroup)(NSScanner *, NSString * (^)(NSScanner *)) = ^ NSString * (NSScanner *scanner, NSString * (^scan)(NSScanner *)) {
	NSUInteger startScanLocation = [scanner scanLocation];
	NSString *string = scan(scanner);
	if (string == nil) {
		[scanner setScanLocation:startScanLocation];
		return nil;
	}
	
	return string;
};

static NSCharacterSet * (^getTokenExceptCharacterSet)(void) = ^ NSCharacterSet * (void) {
	NSMutableCharacterSet *charCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[charCharacterSet addCharactersInRange:NSMakeRange(0, 128)];
	
	NSCharacterSet *controlCharacterSet = [NSCharacterSet controlCharacterSet];
	
	NSMutableCharacterSet *separatorsCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[separatorsCharacterSet addCharactersInString:@"()<>@,;:\\\"/[]?={} \t"];
	
	NSMutableCharacterSet *tokenExceptCharacterSet = [[charCharacterSet mutableCopy] autorelease];
	[tokenExceptCharacterSet formIntersectionWithCharacterSet:[controlCharacterSet invertedSet]];
	[tokenExceptCharacterSet formIntersectionWithCharacterSet:[separatorsCharacterSet invertedSet]];
	return tokenExceptCharacterSet;
};

static NSString * (^scanToken)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	NSString *token = nil;
	BOOL scan = [scanner scanCharactersFromSet:getTokenExceptCharacterSet() intoString:&token];
	if (!scan) {
		return nil;
	}
	
	if ([token length] < 1) {
		return nil;
	}
	
	return token;
};

static NSString * (^scanType)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	return scanToken(scanner);
};

static NSString * (^scanMediaRange)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	NSString *fullWildcardType = @"*/*";
	if ([scanner scanString:fullWildcardType intoString:NULL]) {
		return fullWildcardType;
	}
	
	NSString *wildcardSubtype = tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
		NSString *type = scanType(scanner1);
		if (type == nil) {
			return nil;
		}
		
		af_scoped_block_t pop = pushCharactersToBeSkipped(scanner1, nil);
		
		NSString *slash = @"/";
		if (![scanner1 scanString:slash intoString:NULL]) {
			return nil;
		}
		
		NSString *wildcard = @"*";
		if (![scanner1 scanString:wildcard intoString:NULL]) {
			return nil;
		}
		
		return [[NSArray arrayWithObjects:type, slash, wildcard, nil] componentsJoinedByString:@""];
	});
	if (wildcardSubtype != nil) {
		return wildcardSubtype;
	}
	
	NSString *typeSubtype = tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
		NSString *type = scanType(scanner1);
		if (type == nil) {
			return nil;
		}
		
		af_scoped_block_t pop = pushCharactersToBeSkipped(scanner1, nil);
		
		NSString *slash = @"/";
		if (![scanner1 scanString:slash intoString:NULL]) {
			return nil;
		}
		
		NSString *subtype = scanType(scanner1);
		if (subtype == nil) {
			return nil;
		}
		
		return [[NSArray arrayWithObjects:type, slash, subtype, nil] componentsJoinedByString:@""];
	});
	if (typeSubtype != nil) {
		return typeSubtype;
	}
	
	return nil;
};

static NSString * (^scanAttribute)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	return scanToken(scanner);
};

static NSRange (^makeCharacterRange)(NSUInteger, NSUInteger) = ^ NSRange (NSUInteger start, NSUInteger end) {
	return NSMakeRange(start, end - start);
};

static NSCharacterSet * (^getObstextCharacterSet)(void) = ^ NSCharacterSet * (void) {
	NSMutableCharacterSet *obstextCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[obstextCharacterSet addCharactersInRange:makeCharacterRange(0x80, 0xFF)];
	return obstextCharacterSet;
};

static NSCharacterSet * (^getQdtextCharacterSet)(void) = ^ NSCharacterSet * (void) {
	NSMutableCharacterSet *qdtextCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[qdtextCharacterSet addCharactersInString:@" \t"];
	[qdtextCharacterSet addCharactersInRange:NSMakeRange(0x21, 1)];
	[qdtextCharacterSet addCharactersInRange:makeCharacterRange(0x23, 0x5b)];
	[qdtextCharacterSet addCharactersInRange:makeCharacterRange(0x5d, 0x7e)];
	[qdtextCharacterSet formUnionWithCharacterSet:getObstextCharacterSet()];
	return qdtextCharacterSet;
};

static NSCharacterSet * (^getQuotedPairCharacterSet)(void) = ^ NSCharacterSet * (void) {
	NSMutableCharacterSet *vcharCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[vcharCharacterSet addCharactersInRange:makeCharacterRange(0x21, 0x7e)];
	
	NSMutableCharacterSet *quotedPairCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[quotedPairCharacterSet addCharactersInString:@"\t "];
	[quotedPairCharacterSet formUnionWithCharacterSet:vcharCharacterSet];
	[quotedPairCharacterSet formUnionWithCharacterSet:getObstextCharacterSet()];
	return quotedPairCharacterSet;
};

static NSString * (^scanCharacterFromSet)(NSScanner *, NSCharacterSet *) = ^ NSString * (NSScanner *scanner, NSCharacterSet *characterSet) {
	NSUInteger startScanLocation = [scanner scanLocation];
	
	/*
		Note
		
		NSString stores its data in UTF-16
	 */
	NSRange composedCharacterRange = [[scanner string] rangeOfComposedCharacterSequenceAtIndex:startScanLocation];
	NSString *characterString = [[scanner string] substringWithRange:composedCharacterRange];
	if (![characterSet isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:characterString]]) {
		return nil;
	}
	
	[scanner setScanLocation:(startScanLocation + composedCharacterRange.length)];
	return characterString;
};

static NSString * (^scanQuotedPair)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	return tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
		if (![scanner1 scanString:@"\\" intoString:NULL]) {
			return nil;
		}
		
		NSString *escape = scanCharacterFromSet(scanner1, getQuotedPairCharacterSet());
		if (escape == nil) {
			return nil;
		}
		
		return escape;
	});
};

static NSString * (^scanQuotedString)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	return tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
		NSString *dquote = @"\"";
		if (![scanner1 scanString:dquote intoString:NULL]) {
			return nil;
		}
		
		af_scoped_block_t pop = pushCharactersToBeSkipped(scanner1, nil);
		
		NSMutableString *string = [NSMutableString string];
		while (1) {
			NSString *qdtext = scanCharacterFromSet(scanner1, getQdtextCharacterSet());
			if (qdtext != nil) {
				[string appendString:qdtext];
				continue;
			}
			
			NSString *escapedQuotedPair = scanQuotedPair(scanner1);
			if (escapedQuotedPair != nil) {
				[string appendString:escapedQuotedPair];
				continue;
			}
			
			break;
		}
		
		if (![scanner1 scanString:dquote intoString:NULL]) {
			return nil;
		}
		
		return [[NSArray arrayWithObjects:dquote, string, dquote, nil] componentsJoinedByString:@""];
	});
};

static NSString * (^scanValue)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
	NSString *token = scanToken(scanner);
	if (token != nil) {
		return token;
	}
	
	NSString *quotedString = scanQuotedString(scanner);
	if (quotedString != nil) {
		return quotedString;
	}
	
	return nil;
};

static NSDictionary * (^_scanParameters)(NSScanner *, NSString *) = ^ NSDictionary * (NSScanner *scanner, NSString *terminatingParameter) {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	
	while (1) {
		NSString *parameterPair = tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
			if (![scanner scanString:@";" intoString:NULL]) {
				return nil;
			}
			
			NSString *attribute = scanAttribute(scanner1);
			if (attribute == nil) {
				return nil;
			}
			
			if ([attribute isEqualToString:terminatingParameter]) {
				return nil;
			}
			
			af_scoped_block_t pop = pushCharactersToBeSkipped(scanner1, nil);
			
			NSString *equals = @"=";
			if (![scanner1 scanString:equals intoString:NULL]) {
				return nil;
			}
			
			NSString *value = scanValue(scanner1);
			if (value == nil) {
				return nil;
			}
			
			[parameters setObject:value forKey:attribute];
			
			return [[NSArray arrayWithObjects:attribute, equals, value, nil] componentsJoinedByString:@""];
		});
		if (parameterPair == nil) {
			break;
		}
	}
	
	if ([parameters count] == 0) {
		return nil;
	}
	
	return parameters;
};

#pragma mark - Functions

/*
	\brief
	ABNF from <http://tools.ietf.org/html/rfc2616#section-3.7>
	
	media-type     = type "/" subtype *( ";" parameter )
	type           = token
	subtype        = token
 */
AFHTTPMessageMediaType *AFHTTPMessageParseContentTypeHeader(NSString *contentTypeHeader) {
	NSScanner *contentTypeHeaderScanner = [NSScanner scannerWithString:contentTypeHeader];
	[contentTypeHeaderScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
	
	NSString *mediaRange = scanMediaRange(contentTypeHeaderScanner);
	if (mediaRange == nil) {
		return nil;
	}
	
	__block NSDictionary *parameters = nil;
	tryAtomicScanGroup(contentTypeHeaderScanner, ^ NSString * (NSScanner *scanner) {
		parameters = _scanParameters(scanner, nil);
		if (parameters == nil) {
			return nil;
		}
		
		return @"";
	});
	
	return [[[AFHTTPMessageMediaType alloc] initWithType:mediaRange parameters:parameters] autorelease];
}

/*
	\brief
	ABNF is from <http://tools.ietf.org/html/rfc2616#section-14.1>
	
	Accept				= "Accept" ":"
						#( media-range [ accept-params ] )
	
	media-range			= ( "*" "/" "*"
						| ( type "/" "*" )
						| ( type "/" subtype )
						) *( ";" parameter )
    accept-params		= ";" "q" "=" qvalue *( accept-extension )
    accept-extension	= ";" token [ "=" ( token | quoted-string ) ]
	
	<n>#<m>element		= element <n-1>*<m-1>( OWS "," OWS element )
	#element			= [ ( "," / element ) *( OWS "," [ OWS element ] ) ]
	
	OWS					= *( SP / HTAB )
						; "optional" whitespace
	RWS					= 1*( SP / HTAB )
						; "required" whitespace
	BWS					= OWS
						; "bad" whitespace
	
	type				= token
	subtype				= token
	
	token				= 1*<any CHAR except CTLs or separators>
	
	CHAR				= <any US-ASCII character (octets 0 - 127)>
	
	CTL					= <any US-ASCII control character
						(octets 0 - 31) and DEL (127)>
	
	separators			= "(" | ")" | "<" | ">" | "@"
						| "," | ";" | ":" | "\" | <">
						| "/" | "[" | "]" | "?" | "="
						| "{" | "}" | SP  | HT
	
	SP					= <US-ASCII SP, space (32)>
	HT					= <US-ASCII HT, horizontal-tab (9)>
	
	parameter			= attribute "=" value
	attribute			= token
	value				= token | quoted-string
	
	quoted-string		= DQUOTE *( qdtext / quoted-pair ) DQUOTE
	qdtext				= OWS / %x21 / %x23-5B / %x5D-7E / obs-text
	obs-text			= %x80-FF
	quoted-pair			= "\" ( HTAB / SP / VCHAR / obs-text )
 */
NSArray *AFHTTPMessageParseAcceptHeader(NSString *acceptHeader) {
	NSMutableArray *accepts = [NSMutableArray array];
	
	NSDictionary * (^scanParameters)(NSScanner *) = ^ NSDictionary * (NSScanner *scanner) {
		return _scanParameters(scanner, @"q");
	};
	
	NSDictionary * (^scanAcceptParameters)(NSScanner *) = ^ NSDictionary * (NSScanner *scanner) {
		return _scanParameters(scanner, nil);
	};
	
	NSScanner *acceptHeaderScanner = [NSScanner scannerWithString:acceptHeader];
	[acceptHeaderScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
	
	while (![acceptHeaderScanner isAtEnd]) {
		NSUInteger startScanLocation = [acceptHeaderScanner scanLocation];
		
		NSString *mediaRange = scanMediaRange(acceptHeaderScanner);
		
		__block NSDictionary *parameters = nil;
		__block NSDictionary *acceptParameters = nil;
		
		if (mediaRange != nil) {
			tryAtomicScanGroup(acceptHeaderScanner, ^ NSString * (NSScanner *scanner) {
				parameters = scanParameters(scanner);
				if (parameters == nil) {
					return nil;
				}
				
				return @"";
			});
			tryAtomicScanGroup(acceptHeaderScanner, ^ NSString * (NSScanner *scanner) {
				acceptParameters = scanAcceptParameters(scanner);
				if (acceptParameters == nil) {
					return nil;
				}
				
				return @"";
			});
		}
		
		if (mediaRange != nil) {
			AFHTTPMessageAcceptType *accept = [[[AFHTTPMessageAcceptType alloc] initWithType:mediaRange parameters:parameters acceptParameters:acceptParameters] autorelease];
			[accepts addObject:accept];
		}
		
		[acceptHeaderScanner scanString:@"," intoString:NULL];
		
		/*
			Note
			
			if we haven't advanced our scan location after a pass through the loop we have an infite loop
		 */
		if (startScanLocation == [acceptHeaderScanner scanLocation]) {
			break;
		}
	}
	
	if ([accepts count] == 0) {
		return nil;
	}
	
	return accepts;
}

static NSString *_AFHTTPMessageQualityFromParameters(NSDictionary *parameters) {
	return [parameters objectForKey:@"q"] ? : @"1";
}

static NSArray *_AFHTTPMessageOrderAcceptTypesByQuality(NSArray *accepts) {
	NSSortDescriptor *qualitySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:AFHTTPMessageAcceptTypeAcceptParametersKey ascending:NO comparator:^ NSComparisonResult (id obj1, id obj2) {
		NSString *obj1Quality = _AFHTTPMessageQualityFromParameters(obj1);
		NSString *obj2Quality = _AFHTTPMessageQualityFromParameters(obj2);
		
		return [obj1Quality compare:obj2Quality options:NSNumericSearch];
	}];
	
	// more specific > less specific
	NSSortDescriptor *specificitySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:AFHTTPMessageMediaTypeParametersKey ascending:NO comparator:^ NSComparisonResult (id obj1, id obj2) {
		NSUInteger count1 = [obj1 count];
		NSUInteger count2 = [obj2 count];
		if (count1 == count2) {
			return NSOrderedSame;
		}
		return (count1 < count2 ? NSOrderedAscending : NSOrderedDescending);
	}];
	
	return [accepts sortedArrayUsingDescriptors:[NSArray arrayWithObjects:qualitySortDescriptor, specificitySortDescriptor, nil]];
}

/*!
	\brief
	Modeled on UTTypeConformsTo but for MIME types
 */
static BOOL _AFHTTPMessageTypeConformsTo(NSString *type, NSString *conformsTo) {
	NSString *slash = @"/";
	NSArray *typeComponents = [type componentsSeparatedByString:slash];
	if ([typeComponents count] != 2) {
		return NO;
	}
	
	NSArray *conformsToComponents = [conformsTo componentsSeparatedByString:slash];
	if ([conformsToComponents count] != 2) {
		return NO;
	}
	
	if (/* full wildcard */ [[conformsToComponents objectAtIndex:0] isEqualToString:@"*"]) {
		return YES;
	}
	if (! /* same type */ [[conformsToComponents objectAtIndex:0] isEqualToString:[typeComponents objectAtIndex:0]]) {
		return NO;
	}
	
	if (/* subtype wildcard */ [[conformsToComponents objectAtIndex:1] isEqualToString:@"*"]) {
		return YES;
	}
	if (! /* same subtype */ [[conformsToComponents objectAtIndex:1] isEqualToString:[typeComponents objectAtIndex:1]]) {
		return NO;
	}
	
	// full match
	return YES;
}

static NSString *_AFHTTPMessageFirstAcceptMatching(NSString *typeMaybeWildcard, NSArray *types) {
	for (NSString *currentType in types) {
		if (!_AFHTTPMessageTypeConformsTo(currentType, typeMaybeWildcard)) {
			continue;
		}
		
		return currentType;
	}
	
	return nil;
}

NSString *AFHTTPMessageChooseContentTypeForAcceptTypes(NSArray *accepts, NSArray *serverContentTypePreference) {
	NSArray *clientPreference = _AFHTTPMessageOrderAcceptTypesByQuality(accepts);
	for (AFHTTPMessageAcceptType *currentAccept in clientPreference) {
		NSString *serverType = _AFHTTPMessageFirstAcceptMatching([currentAccept type], serverContentTypePreference);
		if (serverType == nil) {
			continue;
		}
		
		return serverType;
	}
	
	return nil;
}
