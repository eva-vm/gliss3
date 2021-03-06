/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */

#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_INST_SIZE_TABLE_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_INST_SIZE_TABLE_H


#if defined(__cplusplus)
extern  "C"
{
#endif

#include <$(proc)/api.h>
#include <$(proc)/macros.h>


#define gliss_error(e) fprintf(stderr, (e))


static int $(proc)_inst_size_table[] =
{
	$(min_instruction_size)$(foreach instructions),
	$(size)$(end)
};



#if defined(__cplusplus)
}
#endif

#endif /* GLISS_$(PROC)_INCLUDE_$(PROC)_INST_SIZE_TABLE_H */
