#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Constants.h"
using namespace llvm;

#define STRIPE 1

void replace_extern_store(Module &M, StoreInst *op) {
    IRBuilder<> builder(op);
    Function *store_fn = M.getFunction("extern_store");

    std::vector<Value *> args_vector;
    args_vector.push_back(op->getPointerOperand());

    if (auto *gep = dyn_cast<GEPOperator>(op->getPointerOperand())) {

        // Descend to find the base type of the array
        ArrayType *arr_t = cast<ArrayType>(gep->getOperand(0)->getType()->getPointerElementType());
        ArrayType *last;
        // Array referencing starts at GEP operand 2
        for (int i = 2; i < gep->getNumOperands(); i++) {
            last = arr_t;
            arr_t = dyn_cast<ArrayType>(arr_t->getElementType());
        }
        args_vector.push_back(ConstantInt::get(last->getElementType(),
                    last->getElementType()->getPrimitiveSizeInBits() / 8, false));

        args_vector.push_back(op->getValueOperand());
        ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

        // Create the call and replace all uses of the store inst with the call
        Value *new_str = builder.CreateCall(store_fn, args);
        for (auto &U : op->uses()) {
            U.getUser()->setOperand(U.getOperandNo(), new_str);
        }

        errs() << "Replace done\n";
        new_str->dump();
    }
}


void replace_extern_load(Module &M, LoadInst *op) {
    IRBuilder<> builder(op);
    Function *load_fn = M.getFunction("extern_load");
    std::vector<Value *> args_vector;
    args_vector.push_back(op->getPointerOperand());

    if (auto *gep = dyn_cast<GEPOperator>(op->getPointerOperand())) {

        // Descend to find the base type of the array
        ArrayType *arr_t = cast<ArrayType>(gep->getOperand(0)->getType()->getPointerElementType());
        ArrayType *last;
        // Array referencing starts at GEP operand 2
        for (int i = 2; i < gep->getNumOperands(); i++) {
            last = arr_t;
            arr_t = dyn_cast<ArrayType>(arr_t->getElementType());
        }
        args_vector.push_back(ConstantInt::get(last->getElementType(),
                    last->getElementType()->getPrimitiveSizeInBits() / 8, false));

        ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

        Value *new_ld = builder.CreateCall(load_fn, args);
        for (auto &U : op->uses()) {
            U.getUser()->setOperand(U.getOperandNo(), new_ld);
        }
        errs() << "Replace done\n";
        new_ld->dump();
    }
}


namespace {
    struct ManycorePass : public ModulePass {
        static char ID;
        ManycorePass() : ModulePass(ID) {}

        int64_t getGlobalVal(Module &M, StringRef name) {
            GlobalVariable *var = M.getGlobalVariable(name);
            if (var) {
                return cast<ConstantInt>(var->getInitializer())->getSExtValue();
            }
            return -1;
        }

        class AddressSpaceException: public std::exception {
            virtual const char *what() const throw() {
                return "Invalid Address Space Encountered!\n";
            }
        } addressSpaceException;

        bool runOnModule(Module &M) override {
            int64_t x_dim = getGlobalVal(M, "bsg_X_len");
            int64_t y_dim = getGlobalVal(M, "bsg_Y_len");
            int64_t group_size = getGlobalVal(M, "bsg_group_size");
            int64_t cores_in_group = x_dim * y_dim;
            std::vector<GlobalVariable *> globals_to_resize;
            for (auto &G : M.globals()) {
                Type *g_type = G.getType();
                // If global variable is an array in address space 1
                if (isa<PointerType>(g_type) && g_type->getPointerAddressSpace() > 0) {
                    globals_to_resize.push_back(&G);
                }
            }
            for (auto G: globals_to_resize) {
                // We set alignment so that index 0 of an array is always on
                // core 0. Additionally, this has the effect of the start of
                // a striped array being word-aligned on individual cores,
                // which is arguably more important.
                G->setAlignment(4 * group_size);
                G->setSection(".striped.data");
                G->dump();
            }

            for (auto &F : M) {
                errs() << "\nI saw a function called " << F.getName() << "!\n";
                for (auto &B : F) {
                    for (auto &I : B) {
                        if (auto* op = dyn_cast<StoreInst>(&I)) {
                            if (op->getPointerAddressSpace() > 0) {
                                op->dump();
                                if (op->getPointerAddressSpace() == STRIPE) {
                                    replace_extern_store(M, op);
                                } else {
                                    throw addressSpaceException;
                                }
                                errs() << "\n";
                            }
                        } else if (auto* op = dyn_cast<LoadInst>(&I)) {
                            if (op->getPointerAddressSpace() > 0) {
                                op->dump();
                                if (op->getPointerAddressSpace() == STRIPE) {
                                    replace_extern_load(M, op);
                                } else {
                                    throw addressSpaceException;
                                }
                                errs() << "\n";
                            }
                        }
                    }
                }
            }
            errs() << "Pass complete\n";
            return true;
        }
    };
}

char ManycorePass::ID = 0;
static RegisterPass<ManycorePass> X("manycore", "Manycore addressing Pass",
        false /* Doesn't only look at CFG */,
        false /* Isn't an Analysis Pass -- modifies code */);
