#include <iostream>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#include "pin.H"

UINT32 logPageSize;
UINT32 logPhysicalMemSize;

//Function to obtain physical page number given a virtual page number
static UINT32 getPhysicalPageNumber(UINT32 virtualPageNumber) {
	INT32 key = (INT32) virtualPageNumber;
	key = ~key + (key << 15); // key = (key << 15) - key - 1;
	key = key ^ (key >> 12);
	key = key + (key << 2);
	key = key ^ (key >> 4);
	key = key * 2057; // key = (key + (key << 3)) + (key << 11);
	key = key ^ (key >> 16);
	return (UINT32) (key&(((UINT32)(~0))>>(32-logPhysicalMemSize)));
}

// VA -> PA
static UINT32 getPhysicalAddress(UINT32 virtualAddress) {
	UINT32 offset = virtualAddress & ((1 << logPageSize) - 1);
	UINT32 virtualPageNumber = virtualAddress >> logPageSize;
	UINT32 ppn = getPhysicalPageNumber(virtualPageNumber);
	return (ppn << logPageSize) | offset;
}

class CacheModel {
 protected:
	UINT32   logNumRows;
	UINT32   logBlockSize;
	UINT32   associativity;
	UINT64   readReqs;
	UINT64   writeReqs;
	UINT64   readHits;
	UINT64   writeHits;
	UINT32** tags;
	bool**   validBits;

	UINT64 clock; // incremented on each read-& write, useful for LRU
	UINT64** lastUsed; // last time when a cache word was read or written
	UINT32 tagShift;
	UINT32 indexShift;
	UINT32 indexMask;
	// mask index to get the base of all rows that can have a physical address
	UINT32 physicalIndexMask;
	// add to masked index to get all rows that can have a physical address
	UINT32 physicalIndexStride;
	// mask virtual tag to get the bits that are part of the physical address
	UINT32 physicalTagMask;
	UINT32 numRows;

public:
	//Constructor for a cache
	CacheModel(UINT32 logNumRowsParam, UINT32 logBlockSizeParam,
			       UINT32 associativityParam) {
		logNumRows = logNumRowsParam;
		logBlockSize = logBlockSizeParam;
		associativity = associativityParam;
		readReqs = 0;
		writeReqs = 0;
		readHits = 0;
		writeHits = 0;
		lastUsed = new UINT64*[1U << logNumRows];
		tags = new UINT32*[1U << logNumRows];
		validBits = new bool*[1U << logNumRows];
		for (UINT32 i = 0; i < (1U << logNumRows); i++) {
			lastUsed[i] = new UINT64[associativity];
			tags[i] = new UINT32[associativity];
			validBits[i] = new bool[associativity];
			for (UINT32 j = 0; j < associativity; j++) {
				validBits[i][j] = false;
				lastUsed[i][j] = 0;
			}
		}

		clock = 0;
		tagShift = logBlockSize + logNumRows;
		indexShift = logBlockSize;
		indexMask = (1 << logNumRows) - 1;
		numRows = 1 << logNumRows;
		int physicalTagBits = logPageSize - (logBlockSize + logNumRows);
		if (physicalTagBits < 0) {
			physicalIndexStride = 1 << (logNumRows + physicalTagBits);
			physicalIndexMask = (1 << (logNumRows + physicalTagBits)) - 1;
			physicalTagMask = 0;
		}
		else {
			physicalIndexStride = numRows;
			physicalIndexMask = (1 << logNumRows) - 1;
			physicalTagMask = (1 << physicalTagBits) - 1;
		}
	}

	virtual bool cacheAccess(UINT32 va) {
		clock++;
		return false;
	}

	// Looks up a tag in a cache row.
	bool cacheLookup(UINT32 tag, UINT32 index) {
		for(UINT32 i = 0; i < associativity; i++) {
			if (tags[index][i] == tag && validBits[index][i]) {
				lastUsed[index][i] = clock;
				return true;
			}
		}
		return false;
	}

	// Sticks a tag in a cache row, using LRU.
	void cacheInsert(UINT32 tag, UINT32 index) {
		UINT32 lruTarget = ~0;
		UINT64 minLastUsed = ~(UINT64)0;
		for(UINT32 i = 0; i < associativity; i++) {
			if (!validBits[index][i]) {
				lruTarget = i;
				break;
			}
			if (minLastUsed > lastUsed[index][i]) {
				minLastUsed = lastUsed[index][i];
				lruTarget = i;
			}
		}
		validBits[index][lruTarget] = true;
    lastUsed[index][lruTarget] = clock;
		tags[index][lruTarget] = tag;
	}

	// Invalidates all the cache entries that could be storing the same physical
	// address.
	void cacheInvalidate(UINT32 tag, UINT32 index) {
		tag &= physicalTagMask;
		index &= physicalIndexMask;

		for (; index < numRows; index += physicalIndexStride) {
			for(UINT i = 0; i < associativity; i++) {
				if (validBits[index][i] &&
						((tags[index][i] & physicalTagMask) == tag)) {
					validBits[index][i] = false;
					lastUsed[index][i] = 0;
				}
			}
		}
	}

	//Call this function to update the cache state whenever data is read
	void readReq(UINT32 virtualAddr) {
		readReqs++;
		if (cacheAccess(virtualAddr)) {
			readHits++;
		}
	}

	//Call this function to update the cache state whenever data is written
	void writeReq(UINT32 virtualAddr) {
		writeReqs++;
		if (cacheAccess(virtualAddr)) {
			writeHits++;
		}
	}

	//Do not modify this function
	void dumpResults(FILE* outFile) {
		fprintf(outFile, "%llu,%llu,%llu,%llu\n",
				    readReqs, writeReqs, readHits, writeHits);
	}
};

CacheModel* cachePP;
CacheModel* cacheVP;
CacheModel* cacheVV;

class LruPhysIndexPhysTagCacheModel: public CacheModel {
 public:
  LruPhysIndexPhysTagCacheModel(UINT32 logNumRowsParam,
  		                          UINT32 logBlockSizeParam,
  		                          UINT32 associativityParam)
      : CacheModel(logNumRowsParam, logBlockSizeParam, associativityParam) {
  }

	virtual bool cacheAccess(UINT32 va) {
		CacheModel::cacheAccess(va);
		UINT32 pa = getPhysicalAddress(va);
		UINT32 tag = (pa >> tagShift);
		UINT32 index = (pa >> indexShift) & indexMask;
		if (cacheLookup(tag, index)) {
			return true;
		}
		// NOTE: no cache invalidation necessary with physical indexes and tags
		// cacheInvalidate(tag, index);
		cacheInsert(tag, index);
		return false;
	}
};

class LruVirIndexPhysTagCacheModel: public CacheModel {
 public:
  LruVirIndexPhysTagCacheModel(UINT32 logNumRowsParam, UINT32 logBlockSizeParam,
                               UINT32 associativityParam) :
    	CacheModel(logNumRowsParam, logBlockSizeParam, associativityParam) {
    tagShift = indexShift;

    physicalTagMask = ~0;  // The entire tag consists of physical bits.
    // The index is virtual, so the usual constants apply.
	}

	virtual bool cacheAccess(UINT32 va) {
		CacheModel::cacheAccess(va);
		UINT32 pa = getPhysicalAddress(va);
		UINT32 tag = (pa >> tagShift);
		UINT32 index = (va >> indexShift) & indexMask;
		if (cacheLookup(tag, index)) {
			return true;
		}
		cacheInvalidate(tag, index);
		cacheInsert(tag, index);
		return false;
	}
};

class LruVirIndexVirTagCacheModel: public CacheModel {
 public:
	LruVirIndexVirTagCacheModel(UINT32 logNumRowsParam, UINT32 logBlockSizeParam,
															UINT32 associativityParam) :
			CacheModel(logNumRowsParam, logBlockSizeParam, associativityParam) {
	}

	virtual bool cacheAccess(UINT32 va) {
		CacheModel::cacheAccess(va);
		UINT32 tag = (va >> tagShift);
		UINT32 index = (va >> indexShift) & indexMask;
		if (cacheLookup(tag, index)) {
			return true;
		}
		cacheInvalidate(tag, index);
		cacheInsert(tag, index);
		return false;
	}
};

//Cache analysis routine
void cacheLoad(UINT32 virtualAddr)
{
	//Here the virtual address is aligned to a word boundary
	virtualAddr = virtualAddr & (UINT32)~0x03;
	cachePP->readReq(virtualAddr);
	cacheVP->readReq(virtualAddr);
	cacheVV->readReq(virtualAddr);
}

//Cache analysis routine
void cacheStore(UINT32 virtualAddr)
{
	//Here the virtual address is aligned to a word boundary
	virtualAddr = virtualAddr & (UINT32)~0x03;
	cachePP->writeReq(virtualAddr);
	cacheVP->writeReq(virtualAddr);
	cacheVV->writeReq(virtualAddr);
}

// This knob will set the outfile name
KNOB<string> KnobOutputFile(KNOB_MODE_WRITEONCE, "pintool",
    "o", "results.out", "specify optional output file name");

// This knob will set the param logPhysicalMemSize
KNOB<UINT32> KnobLogPhysicalMemSize(KNOB_MODE_WRITEONCE, "pintool",
    "m", "16", "specify the log of physical memory size in bytes");

// This knob will set the param logPageSize
KNOB<UINT32> KnobLogPageSize(KNOB_MODE_WRITEONCE, "pintool",
    "p", "12", "specify the log of page size in bytes");

// This knob will set the cache param logNumRows
KNOB<UINT32> KnobLogNumRows(KNOB_MODE_WRITEONCE, "pintool",
    "r", "10", "specify the log of number of rows in the cache");

// This knob will set the cache param logBlockSize
KNOB<UINT32> KnobLogBlockSize(KNOB_MODE_WRITEONCE, "pintool",
    "b", "5", "specify the log of block size of the cache in bytes");

// This knob will set the cache param associativity
KNOB<UINT32> KnobAssociativity(KNOB_MODE_WRITEONCE, "pintool",
    "a", "2", "specify the associativity of the cache");

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
	fprintf(outfile, "physical index physical tag: ");
	cachePP->dumpResults(outfile);
	fprintf(outfile, "virtual index physical tag: ");
	cacheVP->dumpResults(outfile);
	fprintf(outfile, "virtual index virtual tag: ");
	cacheVV->dumpResults(outfile);
}

// argc, argv are the entire command line, including pin -t <toolname> -- ...
int main(int argc, char * argv[]) {
	// Initialize pin
	PIN_Init(argc, argv);

	logPageSize = KnobLogPageSize.Value();
	logPhysicalMemSize = KnobLogPhysicalMemSize.Value();

	cachePP = new LruPhysIndexPhysTagCacheModel(KnobLogNumRows.Value(),
			KnobLogBlockSize.Value(), KnobAssociativity.Value());
	cacheVP = new LruVirIndexPhysTagCacheModel(KnobLogNumRows.Value(),
			KnobLogBlockSize.Value(), KnobAssociativity.Value());
	cacheVV = new LruVirIndexVirTagCacheModel(KnobLogNumRows.Value(),
			KnobLogBlockSize.Value(), KnobAssociativity.Value());

	// Register Instruction to be called to instrument instructions
	INS_AddInstrumentFunction(Instruction, 0);

	// Register Fini to be called when the application exits
	PIN_AddFiniFunction(Fini, 0);

	// Start the program, never returns
	PIN_StartProgram();

	return 0;
}
