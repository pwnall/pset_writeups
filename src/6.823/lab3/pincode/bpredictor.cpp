#include <iostream>
#include <stdio.h>
#include <assert.h>
#include "pin.H"

// **
// ** Failed attempt: perceptron.
// **

class Perceptron {
  static const int tableSize = 150;
  static const int globalSize = 28;
  static const int features = globalSize + 1;
  int globalHistory[globalSize];
  int trons[tableSize][features];
 public:
  Perceptron() {
    for (int i = 0; i < globalSize; i++)
      globalHistory[i] = 1; // All taken.
    for (int i = 0; i < tableSize; i++) {
      for (int j = 0; j < features; j++) {
        trons[i][j] = 0;
      }
    }
  }

  inline int tron(int i, int j) {
    if (j >= globalSize)
      return 1;
    return globalHistory[j];
  }

  inline int tronSum(int i) {
    int sum = 0;
    for (int j = 0; j < features; j++) {
      sum += trons[i][j] * tron(i, j);
    }
    return sum;
  }

  inline int addressHash(ADDRINT address) {
    return address % tableSize;
  }

  BOOL makePrediction(ADDRINT address) {
    return tronSum(addressHash(address)) >= 0;
  }

  void makeUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    int i = addressHash(address);

    int sum = tronSum(i);
    if ((takenActually != takenPredicted) || (sum >= 69 || sum < -69)) {
      int delta = takenActually ? 1 : -1;
      for (int j = 0; j < features; j++) {
        int newValue = trons[i][j] + delta * tron(i, j);

        // 9-bit signed integer: -128..127; saturate symmetrically
        if (newValue >= 128) newValue = 127;
        if (newValue <= -128) newValue = -127;
        trons[i][j] = newValue;
      }
    }

    for (int j = 1; j < globalSize; j++)
      globalHistory[j] = globalHistory[j - 1];
    globalHistory[0] = takenActually ? 1 : -1;
  }
};

// **
// ** Building blocks.
// **

// B-bit saturating counter.
template<int B> class SatCounter {
 protected:
  static const int maxValue = (1 << B) - 1;
  static const int takenThreshold = (1 << (B - 1));

  int _state;

 public:
  bool isTaken() const {
    return _state >= takenThreshold;
  }
  void setWeakTaken() {
    _state = takenThreshold;
  }

  SatCounter() {
    _state = 0;
  }
  SatCounter<B>& operator ++() {
    if (_state < maxValue) ++_state;
    return *this;
  }
  SatCounter<B>& operator --() {
    if (_state) --_state;
    return *this;
  }

  void update(bool isTaken) {
    if (isTaken) {
      ++(*this);
    } else {
      --(*this);
    }
  }
};

// Rotating B-bit history of branch resolutions.
template<int B> class History {
 protected:
  static const int maxValue = (1 << B) - 1;

  int _state;

 public:
  operator int() const {
    return _state;
  }

  History<B>& operator <<=(bool isTaken) {
    _state = ((_state << 1) | isTaken) & maxValue;
    return *this;
  }

  History() {
    _state = 0;
  }

  void setAllTaken() {
    _state = maxValue;
  }
};

// **
// ** Building block predictors.
// **

// Maintains a table of saturating counters, each PC hashes to a table entry.
template<int pcSize, int counterSize> class LocalCounters {
 protected:
  SatCounter<counterSize> table[1 << pcSize];

 public:
  LocalCounters() {
    for (int i = 0; i < (1 << pcSize); i++) {
      table[i].setWeakTaken();
    }
  }

  BOOL makePrediction(ADDRINT address) {
    return table[address & ((1 << pcSize) - 1)].isTaken();
  }

  void makeUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    table[address & ((1 << pcSize) - 1)].update(takenActually);
  }
};

// Global history register indexing into a table of saturating counters.
template<int globalSize, int counterSize> class Gshare {
 protected:
  // globalSize bits
  History<globalSize> globalHistory;
  // 2 * (2 ^ globalSize) bits
  SatCounter<counterSize> table[1 << globalSize];

 public:
  Gshare() {
    globalHistory.setAllTaken();
    for (int i = 0; i < (1 << globalSize); i++) {
      table[i].setWeakTaken();
    }
  }

  BOOL makePrediction(ADDRINT address) {
    return table[globalHistory].isTaken();
  }

  void makeUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    table[globalHistory].update(takenActually);
    globalHistory <<= takenActually;
  }
};

// Local history table (per-PC) indexing into a table of saturating counters.
template<int localSize, int pcSize, int counterSize> class Lshare {
 protected:
  // localSize * (2 ** pcSize) bits
  History<localSize> localHistory[1 << pcSize];
  // 2 * (2 ^ localSize) bits
  SatCounter<counterSize> table[1 << localSize];

 public:
  Lshare() {
    for (int i = 0; i < (1 << pcSize); i++) {
      localHistory[i].setAllTaken();
    }
    for (int i = 0; i < (1 << localSize); i++) {
      table[i].setWeakTaken();
    }
  }

  BOOL makePrediction(ADDRINT address) {
    return table[localHistory[address & ((1 << pcSize) - 1)]].isTaken();
  }

  void makeUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    table[localHistory[address & ((1 << pcSize) - 1)]].update(takenActually);
    localHistory[address & ((1 << pcSize) - 1)] <<= takenActually;
  }
};

// Tournament predictor: chooses between 2 predictors using a selector.
template<typename Predictor1, typename Predictor2, typename Selector>
class Tournament {
 protected:
  Predictor1 predictor1;
  Predictor2 predictor2;
  Selector selector;

 public:
  Tournament() : predictor1(), predictor2(), selector() {
  }

  BOOL makePrediction(ADDRINT address) {
    return (selector.makePrediction(address)) ?
        predictor1.makePrediction(address) : predictor2.makePrediction(address);
  }

  void makeUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    bool p1Accurate = (predictor1.makePrediction(address) == takenActually);
    bool p2Accurate = (predictor2.makePrediction(address) == takenActually);

    predictor1.makeUpdate(takenActually, takenPredicted, address);
    predictor2.makeUpdate(takenActually, takenPredicted, address);

    bool selectorPrediction = selector.makePrediction(address);
    if (p1Accurate != p2Accurate) {
      selector.makeUpdate(p1Accurate, selectorPrediction, address);
    }
    selector.historyUpdate(takenActually, selectorPrediction, address);
  }
};

// **
// ** Building block selectors.
// **

template<int globalSize, int counterSize> class GshareSel :
    public Gshare<globalSize, counterSize> {
 public:
  void makeUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    table[globalHistory].update(takenActually);
  }

  void historyUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
    globalHistory <<= takenActually;
  }
};

template<int pcSize, int counterSize> class LocalCounterSel :
    public LocalCounters<pcSize, counterSize> {
 public:
  void historyUpdate(BOOL takenActually, BOOL takenPredicted, ADDRINT address) {
  }
};


// **
// ** Concrete predictors.
// **

// Tournament between Gshare and Lshare, chosen using a global history table.
class GTournament : public Tournament<Gshare<12, 2>, Lshare<10, 10, 3>,
                                      GshareSel<12, 2> > {
};

// Tournament between Gshare and Lshare, chosen using local history tables.
class LTournament : public Tournament<Gshare<12, 2>, Lshare<10, 10, 3>,
                                      LocalCounterSel<10, 3> > {
};

// **
// ** Final predictor.
// **

class MyBranchPredictor : public GTournament {

};

static MyBranchPredictor* rootPredictor;
static UINT64 predictionStats[2][2];

// This knob sets the output file name
KNOB<string> KnobOutputFile(KNOB_MODE_WRITEONCE, "pintool", "o", "result.out",
    "specify the output file name");

// In examining handle branch, refer to question 1 on the homework
void handleBranch(ADDRINT ip, BOOL direction) {
  BOOL prediction = rootPredictor->makePrediction(ip);
  rootPredictor->makeUpdate(direction, prediction, ip);
  predictionStats[prediction][prediction == direction]++;
}

void instrumentBranch(INS ins, void * v) {
  if (INS_IsBranch(ins) && INS_HasFallThrough(ins)) {
    INS_InsertCall(ins, IPOINT_TAKEN_BRANCH, (AFUNPTR) handleBranch,
        IARG_INST_PTR, IARG_BOOL, TRUE, IARG_END);

    INS_InsertCall(ins, IPOINT_AFTER, (AFUNPTR) handleBranch, IARG_INST_PTR,
        IARG_BOOL, FALSE, IARG_END);
  }
}

/* ===================================================================== */
VOID Fini(int, VOID * v) {
  FILE* outfile;
  assert(outfile = fopen(KnobOutputFile.Value().c_str(),"w"));
  fprintf(
      outfile,
      "takenCorrect %llu  takenIncorrect %llu notTakenCorrect %llu notTakenIncorrect %llu\n",
      predictionStats[TRUE][TRUE], predictionStats[TRUE][FALSE],
      predictionStats[FALSE][TRUE], predictionStats[FALSE][FALSE]);
}

// argc, argv are the entire command line, including pin -t <toolname> -- ...
int main(int argc, char * argv[]) {
  // Make a new branch predictor
  rootPredictor = new MyBranchPredictor();

  // Initialize pin
  PIN_Init(argc, argv);

  // Register Instruction to be called to instrument instructions
  INS_AddInstrumentFunction(instrumentBranch, 0);

  // Register Fini to be called when the application exits
  PIN_AddFiniFunction(Fini, 0);

  // Start the program, never returns
  PIN_StartProgram();

  return 0;
}

