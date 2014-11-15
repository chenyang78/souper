// Copyright 2014 The Souper Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef SOUPER_INST_INST_H
#define SOUPER_INST_INST_H

#include "llvm/ADT/APInt.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/FoldingSet.h"
#include <memory>
#include <string>
#include <vector>

namespace souper {

struct Block {
  std::string Name;
  unsigned Preds;
  unsigned Number;
};

struct Inst : llvm::FoldingSetNode {
  typedef enum {
    Const,
    UntypedConst,
    Var,
    Phi,

    Add,
    AddNSW,
    AddNUW,
    AddNW,
    Sub,
    SubNSW,
    SubNUW,
    SubNW,
    Mul,
    MulNSW,
    MulNUW,
    MulNW,
    UDiv,
    SDiv,
    UDivExact,
    SDivExact,
    URem,
    SRem,
    And,
    Or,
    Xor,
    Shl,
    ShlNSW,
    ShlNUW,
    ShlNW,
    LShr,
    LShrExact,
    AShr,
    AShrExact,
    Select,
    ZExt,
    SExt,
    Trunc,
    Eq,
    Ne,
    Ult,
    Slt,
    Ule,
    Sle,
    CtPop,
    BSwap,
    Cttz,
    Ctlz,
  } Kind;

  Kind K;
  unsigned Number;
  unsigned Width;
  Block *B;
  llvm::APInt Val;
  std::string Name;
  std::vector<Inst *> Ops;
  mutable std::vector<Inst *> OrderedOps;

  bool operator<(const Inst &I) const;
  const std::vector<Inst *> &orderedOps() const;

  void Profile(llvm::FoldingSetNodeID &ID) const;

  static const char *getKindName(Kind K);

  static bool isAssociative(Kind K);
  static bool isCommutative(Kind K);
};

/// A mapping from an Inst to a replacement. This may either represent a
/// path condition or a candidate replacement.
struct InstMapping {
  InstMapping() : LHS(0), RHS(0) {}
  InstMapping(Inst *LHS, Inst *RHS)
      : LHS(LHS), RHS(RHS) {}

  Inst *LHS, *RHS;
};

struct BlockPCMapping {
  BlockPCMapping() : B(0) {}
  BlockPCMapping(Block *B, std::vector<InstMapping> PCs) 
      : B(B), PCs(PCs) {}

  Block *B;
  std::vector<InstMapping> PCs;
};

typedef std::vector<BlockPCMapping> BlockPCs;

class PrintContext {
  llvm::raw_ostream &Out;
  llvm::DenseMap<void *, unsigned> PrintNums;

public:
  PrintContext(llvm::raw_ostream &Out) : Out(Out) {}

  std::string printInst(Inst *I);
  unsigned printBlock(Block *B);
  void printPCs(const std::vector<InstMapping> &PCs);
  void printBlockPCs(const BlockPCs &BPCs);
};

class InstContext {
  typedef llvm::DenseMap<unsigned, std::vector<std::unique_ptr<Block>>>
      BlockMap;
  BlockMap BlocksByPreds;

  typedef llvm::DenseMap<unsigned, std::vector<std::unique_ptr<Inst>>> InstMap;
  InstMap VarInstsByWidth;

  std::vector<std::unique_ptr<Inst>> Insts;
  llvm::FoldingSet<Inst> InstSet;

public:
  Inst *getConst(const llvm::APInt &I);
  Inst *getUntypedConst(const llvm::APInt &I);

  Inst *createVar(unsigned Width, llvm::StringRef Name);
  Block *createBlock(unsigned Preds);

  Inst *getPhi(Block *B, const std::vector<Inst *> &Ops);

  Inst *getInst(Inst::Kind K, unsigned Width, const std::vector<Inst *> &Ops);
};

void PrintReplacement(llvm::raw_ostream &Out, const BlockPCs &BPCs,
                      const std::vector<InstMapping> &PCs, InstMapping Mapping);
std::string GetReplacementString(const BlockPCs &BPCs,
                                 const std::vector<InstMapping> &PCs,
                                 InstMapping Mapping);
void PrintReplacementLHS(llvm::raw_ostream &Out, const BlockPCs &BPCs,
                         const std::vector<InstMapping> &PCs,
                         Inst *LHS);
std::string GetReplacementLHSString(const BlockPCs &BPCs,
                                    const std::vector<InstMapping> &PCs,
                                    Inst *LHS);
void PrintReplacementRHS(llvm::raw_ostream &Out, llvm::APInt Const);
std::string GetReplacementRHSString(llvm::APInt Const);

}

#endif  // SOUPER_INST_INST_H
