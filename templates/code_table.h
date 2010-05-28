/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */

#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_CODE_TABLE_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_CODE_TABLE_H


#if defined(__cplusplus)
extern  "C"
{
#endif

#include <$(proc)/api.h>
#include <$(proc)/macros.h>

/* module headers */
$(foreach modules)$(CODE_HEADER)$(end)

$(foreach modules)
#include <$(proc)/$(name).h>
$(end)

/* TODO: add some error messages when malloc fails */
#define gliss_error(e) fprintf(stderr, "%s\n", (e))

#define $(PROC)__SIZE	$(min_instruction_size)
static void $(proc)_instr_UNKNOWN_code($(proc)_state_t *state, $(proc)_inst_t *inst) {
	/* must not be executed ! */
	$(proc)_execute_unknown(state, $(PROC)_UNKNOWN___IADDR);
}

$(foreach instructions)
static void $(proc)_instr_$(IDENT)_code($(proc)_state_t *state, $(proc)_inst_t *inst) {
$(gen_code)
}

$(end)


typedef void (*$(proc)_code_function_t)($(proc)_state_t *, $(proc)_inst_t *);

static $(proc)_code_function_t $(proc)_code_table[] =
{
	$(proc)_instr_UNKNOWN_code$(foreach instructions),
	$(proc)_instr_$(IDENT)_code$(end)
};



#if defined(__cplusplus)
}
#endif

#endif /* GLISS_$(PROC)_INCLUDE_$(PROC)_DECODE_TABLE_H */
