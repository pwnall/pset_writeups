#include <iostream>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#include "pin.H"

static UINT64 alignedReads = 0, totalReads = 0;
static UINT64 alignedWrites = 0, totalWrites = 0;

//Cache analysis routine
void cacheLoad(UINT32 virtualAddr) {
	totalReads++;
	if ((virtualAddr & 0x03) == 0)
		alignedReads++;
}

//Cache analysis routine
void cacheStore(UINT32 virtualAddr) {
	totalWrites++;
	if ((virtualAddr & 0x03) == 0)
		alignedWrites++;
}

// This knob will set the outfile name
KNOB<string> KnobOutputFile(KNOB_MODE_WRITEONCE, "pintool",
    "o", "results.out", "specify optional output file name");

// Pin calls this function every time a new instruction is encountered
VOID Instruction(INS ins, VOID *v) {
  if(INS_IsMemoryRead(ins)) {
		INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)cacheLoad,
									 IARG_MEMORYREAD_EA, IARG_END);
  }
	if(INS_IsMemoryWrite(ins)) {
			INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)cacheStore,
										 IARG_MEMORYWRITE_EA, IARG_END);
	}
}

// This function is called when the application exits
VOID Fini(INT32 code, VOID *v) {
	FILE* outfile;
	assert(outfile = fopen(KnobOutputFile.Value().c_str(),"w"));
	fprintf(outfile, "%llu,%llu,%llu,%llu\n",
			    totalReads, totalWrites, alignedReads, alignedWrites);
}

// argc, argv are the entire command line, including pin -t <toolname> -- ...
int main(int argc, char * argv[]) {
	// Initialize pin
	PIN_Init(argc, argv);

	// Register Instruction to be called to instrument instructions
	INS_AddInstrumentFunction(Instruction, 0);

	// Register Fini to be called when the application exits
	PIN_AddFiniFunction(Fini, 0);

	// Start the program, never returns
	PIN_StartProgram();

	return 0;
}
