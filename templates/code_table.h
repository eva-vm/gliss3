/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */

#include "../include/$(proc)/api.h"

#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_CODE_TABLE_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_CODE_TABLE_H


#if defined(__cplusplus)
extern  "C"
{
#endif

#include "../include/$(proc)/api.h"
#include "../include/$(proc)/macros.h"
#include "gliss.h"

/* TODO: add some error messages when malloc fails */
#define gliss_error(e) fprintf(stderr, (e))




static void $(proc)_instr_UNKNOWN_code($(proc)_state_t *state, $(proc)_inst_t *inst)
{
	/* do nothing */
	
	/* increment PCs, HOW ARE THESE ACCESSED? */
}

$(foreach instructions)
static void $(proc)_instr_$(IDENT)_code($(proc)_state_t *state, $(proc)_inst_t *inst)
{	
	$(gen_code)

	/* increment PCs, HOW ARE THESE ACCESSED? */
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
