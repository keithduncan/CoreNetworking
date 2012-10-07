//
//  AFHTTPMessageAccept.m
//  CoreNetworking
//
//  Created by Keith Duncan on 07/10/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFHTTPMessageAccept.h"

#import <objc/runtime.h>

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
	
	NSMutableArray * (^_charactersToBeSkippedStackForScanner)(NSScanner *) = ^ NSMutableArray * (NSScanner *scanner) {
		AFNETWORK_NSSTRING_CONTEXT(_AFHTTPMessageAcceptScannerCharactersToBeSkippedStackAssociationContext);
		
		NSMutableArray *stack = objc_getAssociatedObject(scanner, &_AFHTTPMessageAcceptScannerCharactersToBeSkippedStackAssociationContext);
		if (stack == nil) {
			stack = [NSMutableArray array];
			objc_setAssociatedObject(scanner, &_AFHTTPMessageAcceptScannerCharactersToBeSkippedStackAssociationContext, stack, OBJC_ASSOCIATION_RETAIN);
		}
		
		return stack;
	};
	void (^_popCharactersToBeSkipped)(NSScanner *) = ^ void (NSScanner *scanner) {
		NSMutableArray *charactersToBeSkippedStack = _charactersToBeSkippedStackForScanner(scanner);
		NSCParameterAssert([charactersToBeSkippedStack count] > 0);
		NSCharacterSet *characterSet = [charactersToBeSkippedStack lastObject];
		[scanner setCharactersToBeSkipped:(![characterSet isEqual:[NSNull null]] ? characterSet : nil)];
		[charactersToBeSkippedStack removeLastObject];
	};
	void (^(^pushCharactersToBeSkipped)(NSScanner *, NSCharacterSet *))(void) = ^ (NSScanner *scanner, NSCharacterSet *charactersToBeSkipped) {
		NSMutableArray *charactersToBeSkippedStack = _charactersToBeSkippedStackForScanner(scanner);
		[charactersToBeSkippedStack addObject:([scanner charactersToBeSkipped] ? : [NSNull null])];
		[scanner setCharactersToBeSkipped:charactersToBeSkipped];
		
		return (void (^)(void))[[^ void (void) {
			_popCharactersToBeSkipped(scanner);
		} copy] autorelease];
	};
	
	NSString * (^tryAtomicScanGroup)(NSScanner *, NSString * (^)(NSScanner *)) = ^ NSString * (NSScanner *scanner, NSString * (^scan)(NSScanner *)) {
		NSUInteger startScanLocation = [scanner scanLocation];
		NSString *string = scan(scanner);
		if (string == nil) {
			[scanner setScanLocation:startScanLocation];
			return nil;
		}
		
		return string;
	};
	
	NSMutableCharacterSet *charCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[charCharacterSet addCharactersInRange:NSMakeRange(0, 128)];
	
	NSCharacterSet *controlCharacterSet = [NSCharacterSet controlCharacterSet];
	
	NSMutableCharacterSet *separatorsCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[separatorsCharacterSet addCharactersInString:@"()<>@,;:\\\"/[]?={} \t"];
	
	NSMutableCharacterSet *tokenExceptCharacterSet = [[charCharacterSet mutableCopy] autorelease];
	[tokenExceptCharacterSet formIntersectionWithCharacterSet:[controlCharacterSet invertedSet]];
	[tokenExceptCharacterSet formIntersectionWithCharacterSet:[separatorsCharacterSet invertedSet]];
	
	NSString * (^scanToken)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
		NSString *token = nil;
		BOOL scan = [scanner scanCharactersFromSet:tokenExceptCharacterSet intoString:&token];
		if (!scan) {
			return nil;
		}
		
		if ([token length] < 1) {
			return nil;
		}
		
		return token;
	};
	
	NSString * (^scanType)(NSScanner *) = scanToken;
	
	NSString * (^scanMediaRange)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
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
	
	NSString * (^scanAttribute)(NSScanner *) = scanToken;
	
	NSRange (^makeCharacterRange)(NSUInteger, NSUInteger) = ^ NSRange (NSUInteger start, NSUInteger end) {
		return NSMakeRange(start, end - start);
	};
	
	NSMutableCharacterSet *obstextCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[obstextCharacterSet addCharactersInRange:makeCharacterRange(0x80, 0xFF)];
	
	NSMutableCharacterSet *qdtextCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[qdtextCharacterSet addCharactersInString:@" \t"];
	[qdtextCharacterSet addCharactersInRange:NSMakeRange(0x21, 1)];
	[qdtextCharacterSet addCharactersInRange:makeCharacterRange(0x23, 0x5b)];
	[qdtextCharacterSet addCharactersInRange:makeCharacterRange(0x5d, 0x7e)];
	[qdtextCharacterSet formUnionWithCharacterSet:obstextCharacterSet];
	
	NSMutableCharacterSet *vcharCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[vcharCharacterSet addCharactersInRange:makeCharacterRange(0x21, 0x7e)];
	
	NSMutableCharacterSet *quotedPairCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	[quotedPairCharacterSet addCharactersInString:@"\t "];
	[quotedPairCharacterSet formUnionWithCharacterSet:vcharCharacterSet];
	[quotedPairCharacterSet formUnionWithCharacterSet:obstextCharacterSet];
	
	NSString * (^scanCharacterFromSet)(NSScanner *, NSCharacterSet *) = ^ NSString * (NSScanner *scanner, NSCharacterSet *characterSet) {
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
	
	NSString * (^scanQuotedPair)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
		return tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
			if (![scanner1 scanString:@"\\" intoString:NULL]) {
				return nil;
			}
			
			NSString *escape = scanCharacterFromSet(scanner1, quotedPairCharacterSet);
			if (escape == nil) {
				return nil;
			}
			
			return escape;
		});
	};
	
	NSString * (^scanQuotedString)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
		return tryAtomicScanGroup(scanner, ^ NSString * (NSScanner *scanner1) {
			NSString *dquote = @"\"";
			if (![scanner1 scanString:dquote intoString:NULL]) {
				return nil;
			}
			
			af_scoped_block_t pop = pushCharactersToBeSkipped(scanner1, nil);
			
			NSMutableString *string = [NSMutableString string];
			while (1) {
				NSString *qdtext = scanCharacterFromSet(scanner1, qdtextCharacterSet);
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
	
	NSString * (^scanValue)(NSScanner *) = ^ NSString * (NSScanner *scanner) {
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
	
	NSDictionary * (^_scanParameters)(NSScanner *, NSString *) = ^ NSDictionary * (NSScanner *scanner, NSString *terminatingParameter) {
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
			AFHTTPMessageAccept *accept = [[[AFHTTPMessageAccept alloc] initWithType:mediaRange parameters:parameters acceptParameters:acceptParameters] autorelease];
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
	NSSortDescriptor *qualitySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:AFHTTPMessageAcceptAcceptParametersKey ascending:NO comparator:^ NSComparisonResult (id obj1, id obj2) {
		NSString *obj1Quality = _AFHTTPMessageQualityFromParameters(obj1);
		NSString *obj2Quality = _AFHTTPMessageQualityFromParameters(obj2);
		
		return [obj1Quality compare:obj2Quality options:NSNumericSearch];
	}];
	
	// more specific > less specific
	NSSortDescriptor *specificitySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:AFHTTPMessageAcceptParametersKey ascending:NO comparator:^ NSComparisonResult (id obj1, id obj2) {
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

NSString *AFHTTPMessageChooseContentTypeForAccepts(NSArray *accepts, NSArray *serverTypePreference) {
	NSArray *clientPreference = _AFHTTPMessageOrderAcceptTypesByQuality(accepts);
	for (AFHTTPMessageAccept *currentAccept in clientPreference) {
		NSString *serverType = _AFHTTPMessageFirstAcceptMatching([currentAccept type], serverTypePreference);
		if (serverType == nil) {
			continue;
		}
		
		return serverType;
	}
	
	return nil;
}

NSString *const AFHTTPMessageAcceptParametersKey = @"parameters";
NSString *const AFHTTPMessageAcceptAcceptParametersKey = @"acceptParameters";

@implementation AFHTTPMessageAccept

@synthesize type=_type;
@synthesize parameters=_parameters, acceptParameters=_acceptParameters;

- (id)initWithType:(NSString *)type parameters:(NSDictionary *)parameters acceptParameters:(NSDictionary *)acceptParameters {
	NSParameterAssert(type != nil);
	
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_type = [type copy];
	_parameters = [parameters copy];
	_acceptParameters = [acceptParameters copy];
	
	return self;
}

- (void)dealloc {
	[_type release];
	[_parameters release];
	[_acceptParameters release];
	
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ %@", [super description], [self type]];
}

@end
