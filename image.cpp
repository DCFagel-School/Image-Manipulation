// CS 218 - Provided C++ program
//	This programs calls assembly language routines.

//  Must ensure g++ compiler is installed:
//	sudo apt install g++

// ***************************************************************************

#include <cstdlib>
#include <iostream>
#include <sstream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <iomanip>

using namespace std;

// ***************************************************************
//  Prototypes for external functions.
//	The "C" specifies to use the standard C/C++ style
//	calling convention.

extern "C" bool getArguments(int, char* [], char *, FILE **, FILE **);
extern "C" bool readHeader(FILE *, FILE *, unsigned int *,
				unsigned int *, unsigned int *);
extern "C" bool getRow(FILE *, int, unsigned char []);
extern "C" bool writeRow(FILE *, int, unsigned char []);
extern "C" void imageCvtToBW(int, unsigned char []);
extern "C" void imageBrighten(int, unsigned char []);
extern "C" void imageDarken(int, unsigned char []);

// ***************************************************************
//  C++ program (does not use any objects).

int main(int argc, char* argv[])
{

// --------------------------------------------------------------------
//  Define constants and declare variables
//	By default, C++ integers are doublewords (32-bits).

	static const int	MAXWIDTH = 10000;

	unsigned int	fileSize;
	unsigned int	picWidth;
	unsigned int	picHeight;
	unsigned char	rowBuffer[MAXWIDTH*3];
	char		imgOption;

	FILE	*inputFile;
	FILE	*outputFile;

// --------------------------------------------------------------------
//  If file opens successful
//	read/write header info
//	verify header info

	if (getArguments(argc, argv, &imgOption, &inputFile, &outputFile)) {

		if (readHeader(inputFile, outputFile, &fileSize,
			&picWidth, &picHeight)) {

			while (getRow(inputFile, picWidth, rowBuffer)) {

				if (imgOption == 'g')
					imageCvtToBW(picWidth, rowBuffer);
				if (imgOption == 'b')
					imageBrighten(picWidth, rowBuffer);
				if (imgOption == 'd')
					imageDarken(picWidth, rowBuffer);

				if(!writeRow(outputFile, picWidth, rowBuffer))
					break;
			}
		}
	}

// --------------------------------------------------------------------
//  Note, file are closed automatically by OS.
//  All done...

	return 0;
}

