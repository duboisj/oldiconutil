//
//  main.m
//  oldiconutil
//
//  Created by Uli Kusterer on 9/5/12.
//  Copyright (c) 2012 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>

#define JUST_PASS_THROUGH		0
#define FILTER_TOC_OUT			1


#define SYNTAX				"oldiconutil {--help|[--inplace [--compression <compression>]|--list] <icnsFilePath>}"
#define SUMMARY				"Convert a .icns icon file holding PNG-encoded icons (supported\nin 10.6) to JPEG 2000-encoded icons (supported in 10.5)."
#define PARAMDESCRIPTIONS	"--help - Show this message.\n" \
							"icnsFilePath - Path of input icns file. Output file will have _10_5 appended to its name, unless the --inplace option is given, in which case it'll replace the input file. If --list is given, oldiconutil will simply print a description of the file.\n" \
							"compression - One of the compression formats of tif, bmp, gif, jpg, png, jp2, immediately followed by a number from 0.0 (best compression) through 1.0 (no compression) indicating how much to compress. If you do not provide a format, the default is jp2 (JPEG 2000), if you do not specify a compression factor, it defaults to 1.0 (uncompressed). Note not all formats may be recognized by Mac OS X Finder (especially in 10.5), but are provided for people who want to experiment.\n"


int main(int argc, const char * argv[])
{
	if( argc < 2 )
	{
		fprintf( stderr, "Error: Syntax is " SYNTAX "\n" );
		return 1;
	}
	
	BOOL					convertInPlace = NO;
	BOOL					listOnly = NO;
	int						nameArgumentPosition = 1;
	NSNumber*				jpegCompressionObj = [NSNumber numberWithFloat: 1.0];
	NSBitmapImageFileType	compressionType = NSJPEG2000FileType;
	NSString*				destCompression = @"jp2";
	
	if( strcasecmp( argv[1], "--help" ) == 0 )
	{
		printf( "Syntax: " SYNTAX "\n" SUMMARY "\n\n" PARAMDESCRIPTIONS "\n\n(c) 2012 by Elgato Systems GmbH, all rights reserved.\n" );
		return 0;
	}
	else if( strcasecmp( argv[1], "--inplace" ) == 0 )
	{
		convertInPlace = YES;
		nameArgumentPosition ++;

		if( argc < (nameArgumentPosition +1) )
		{
			fprintf( stderr, "Error: Syntax is " SYNTAX "\n" );
			return 4;
		}
	}
	else if( strcasecmp( argv[1], "--list" ) == 0 )
	{
		listOnly = YES;
		nameArgumentPosition ++;

		if( argc < (nameArgumentPosition +1) )
		{
			fprintf( stderr, "Error: Syntax is " SYNTAX "\n" );
			return 4;
		}
	}
	
	if( strcasecmp( argv[nameArgumentPosition], "--compression" ) == 0 )
	{
		nameArgumentPosition ++;
		
		if( argc < (nameArgumentPosition +2) )
		{
			fprintf( stderr, "Error: Syntax is " SYNTAX "\n" );
			return 4;
		}
		
		NSString*		compStr = [[NSString stringWithUTF8String: argv[nameArgumentPosition] ] lowercaseString];
		nameArgumentPosition++;
		
		// Find compression prefix (if available) and remove it so only number is left:
		NSDictionary	*compressionTypes = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInteger: NSTIFFFileType], @"tif",
											 [NSNumber numberWithInteger: NSBMPFileType], @"bmp",
											 [NSNumber numberWithInteger: NSGIFFileType], @"gif",
											 [NSNumber numberWithInteger: NSJPEGFileType], @"jpg",
											 [NSNumber numberWithInteger: NSPNGFileType], @"png",
											 [NSNumber numberWithInteger: NSJPEG2000FileType], @"jp2", nil];
		for( NSString* prefix in compressionTypes.allKeys )
		{
			if( [compStr hasPrefix: prefix] )
			{
				destCompression = prefix;
				compressionType = [[compressionTypes objectForKey: prefix] integerValue];
				compStr = [compStr substringFromIndex: prefix.length];
				break;
			}
		}
		
		// If a compression level has been specified, parse it from the remaining string and use it:
		if( compStr.length > 0 )
		{
			float			theCompression = [compStr floatValue];
			jpegCompressionObj = [NSNumber numberWithFloat: theCompression];
		}
	}

	@autoreleasepool {
		NSString		*	inputPath = [NSString stringWithUTF8String: argv[nameArgumentPosition]];
		NSString		*	outputPath = convertInPlace ? inputPath : [[inputPath stringByDeletingPathExtension] stringByAppendingString: @"_10_5.icns"];
		BOOL				isDirectory = NO;
	    
		if( !inputPath || ![[NSFileManager defaultManager] fileExistsAtPath: inputPath isDirectory: &isDirectory] || isDirectory )
		{
			fprintf( stderr, "Error: Can't find input file.\n" );
			return 2;
		}
		
		NSData			*	inputData = [NSData dataWithContentsOfFile: inputPath];
		if( !inputData )
		{
			fprintf( stderr, "Error: Can't load input file.\n" );
			return 3;
		}
		
		NSMutableData	*	outputData = [NSMutableData dataWithLength: 0];
		const char* theBytes = [inputData bytes];
		NSUInteger	currOffs = 4;	// Skip 'icns'
		uint32_t	fileSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
		currOffs += 4;
		
		while( currOffs < fileSize )
		{
			@autoreleasepool
			{
				char		blockType[5] = { 0 };
				memmove( blockType, theBytes +currOffs, 4 );
				currOffs += 4;
				
				printf( "Found block '%s'\n", blockType );
				
#if FILTER_TOC_OUT
				if( strcmp(blockType,"TOC ") == 0 )
				{
					if( !listOnly )
					{
						uint32_t	blockSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
						printf( "\tSkipping %d (+4) bytes.\n", blockSize );
						currOffs += blockSize -4;
					}
				}
				else
#endif
				{
					uint32_t	blockSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
					currOffs += 4;
					NSData	*	currBlockData = [NSData dataWithBytes: theBytes +currOffs length: blockSize -8];
					currOffs += blockSize -8;
					uint32_t	startLong = *(uint32_t*)[currBlockData bytes];
					BOOL		shouldConvert = (startLong == 0x474E5089);	// PNG data starts with 'âPNG'.
					
                    if(!strcmp(blockType, "ic07"))
                        shouldConvert = YES;
                    else
                        shouldConvert = NO;

#if JUST_PASS_THROUGH

#endif

                    if(!shouldConvert || strcmp(blockType, "ic07"))
                        [outputData appendBytes: blockType length: 4];	// Copy the type.

					if( shouldConvert )
					{
                        if( !listOnly)
                        {
                            if( !strcmp(blockType, "ic07"))
                            {
                                printf("Doing special ic07 block processing.\n");

                                NSBitmapImageRep	*	theImage = [[NSBitmapImageRep alloc] initWithData: currBlockData];
                            
                                NSData				*	jp2Data;

                                IconFamilyHandle iconFamily = (IconFamilyHandle)NewHandle(0);
                                if (!iconFamily)
                                {
                                    NSLog(@"Couldn't allocate IconFamily handle\n");
                                    goto error;
                                }

                                [NSGraphicsContext saveGraphicsState];
                                    
                                Handle handle = NULL;
                                NSBitmapImageRep *bitmap = nil;

                                NSInteger bitsPerSample = [theImage bitsPerSample];

                                NSInteger width = [theImage pixelsWide];
                                NSInteger height = [theImage pixelsHigh];
                                NSInteger bytesPerPixel = 4;
                                NSInteger bytesPerRow = width * bytesPerPixel;

                                handle = NewHandle(height * bytesPerRow);

                                if (!handle)
                                {
                                    NSLog(@"Couldn't allocate bitamp handle of %d rows of %d bytes\n", height, bytesPerRow);
                                    goto error;
                                }

                                bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char**)handle
                                                                                 pixelsWide:width
                                                                                 pixelsHigh:[theImage pixelsHigh]
                                                                              bitsPerSample:bitsPerSample
                                                                            samplesPerPixel:bytesPerPixel
                                                                                   hasAlpha:YES
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSCalibratedRGBColorSpace
                                                                               bitmapFormat:NSAlphaFirstBitmapFormat
                                                                                bytesPerRow:bytesPerRow
                                                                               bitsPerPixel:bytesPerPixel * 8];
                            

                                if (!bitmap)
                                {
                                    NSLog(@"Couldn't create bitmap image rep\n");
                                    goto error;
                                }
                            
                                NSGraphicsContext* bitmapContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
                                if (!bitmapContext)
                                {
                                    NSLog(@"Couldn't create bitmap graphics context\n");
                                    goto error;
                                }
            
                                [NSGraphicsContext setCurrentContext:bitmapContext];
                                [theImage draw];

                                vImage_Buffer buffer;
                                buffer.data     = *handle;
                                buffer.width    = width;
                                buffer.height   = height;
                                buffer.rowBytes = bytesPerRow;
                                vImageUnpremultiplyData_ARGB8888(&buffer, &buffer, 0);

                                printf("Working with an image of h: %d, w: %d\n",
                                       width, height);

                                SetIconFamilyData(iconFamily, kIconServices128PixelDataARGB, handle);

                                [NSGraphicsContext restoreGraphicsState];                            

                                Size iconFamilySize = GetHandleSize((Handle)iconFamily) - 8;

                                if (iconFamilySize)
                                {
                                    printf("Length of iconFamilySize is : %d -- our len is %d\n",
                                           GetHandleSize((Handle)iconFamily),
                                           iconFamilySize);

                                    char *p = (char*) *iconFamily;

                                    p += 8;

                                    if( strcmp(p,"TOC ") == 0 )
                                    {
                                        p += 4;
                                        uint32_t	blockSize = NSSwapInt( *(uint32_t*)(p) );
                                        printf( "\tSkipping %d bytes in the ic07 icon header.\n", blockSize );
                                        p += blockSize -4;

                                        iconFamilySize = GetHandleSize((Handle)iconFamily) - (p - ((char*) *iconFamily));
                                    }

                                    printf("iconFamilySize : %d\n", iconFamilySize);

                                    jp2Data = [NSData dataWithBytesNoCopy:p length:(iconFamilySize) freeWhenDone:NO];

                                    if(!jp2Data)
                                    {
                                        printf("Failed to create data object.\n");
                                        goto error;
                                    }
                                }
                                else
                                {
                                    printf("handle size was zero.\n");
                                    goto error;
                                }
                            

                                [outputData appendData: jp2Data];

                                NSError* error = nil;
                                BOOL result = [jp2Data writeToFile:@"/Users/duboisj/tmp/experimentalIcon" options:NSAtomicWrite error:&error];
                                if (!result)
                                    printf("Failed to write to secondary file.\n");

                                NSData *rawData = [NSData dataWithBytesNoCopy:*iconFamily length:GetHandleSize((Handle)iconFamily) freeWhenDone:NO];

                                result = [rawData writeToFile:@"/Users/duboisj/tmp/rawicon.icns" options:NSAtomicWrite error:&error];
                                if (!result)
                                    printf("Failed to write to raw icon file.\n");

                                DisposeHandle((Handle)iconFamily);

                            }
                            else
                                printf( "\tNot of type ic07: not going to convert this one.\n");
                        }
					}
					else
					{
						if( !listOnly )
						{
							printf( "\tCopying data verbatim.\n" );
							blockSize = NSSwapInt( blockSize );
							[outputData appendBytes: &blockSize length: 4];	// Copy size.
							[outputData appendData: currBlockData];
						}
						else
						{
							printf( "\tData is RLE or JPEG\n" );
						}
					}
				}
			}
		}
		
		if( !listOnly )
		{
			[outputData replaceBytesInRange: NSMakeRange(0,0) withBytes: "icns" length: 4];
			uint32_t theSize = NSSwapInt( (uint32_t)[outputData length] +4 );
			[outputData replaceBytesInRange: NSMakeRange(4,0) withBytes: &theSize length: 4];
			 
			printf( "Writing out %ld bytes.\n", [outputData length] );
			[outputData writeToFile: outputPath atomically: NO];
		}
	}
    return 0;

 error:
    printf("Well, darn.  Something went wrong.  Bailing out entirely.\n");
    return 1;
}

