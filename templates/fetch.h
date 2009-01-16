/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */

#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_FETCH_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_FETCH_H


#if defined(__cplusplus)
extern  "C"
{
#endif

#include <$(proc)/api.h>

void $(proc)_init_fetch(void);
void $(proc)_halt_fetch(void);

$(proc)_ident_t *$(proc)_fetch($(proc)_state_t *state, $(proc)_address_t addr, $(proc)_code_t *code)

void $(proc)_free_inst($(proc)_inst_t *instr);


#if defined(__cplusplus) 
}
#endif

#endif /* GLISS_$(PROC)_INCLUDE_$(PROC)_FETCH_H */
