/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */

#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_FETCH_TABLE_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_FETCH_TABLE_H


#if defined(__cplusplus)
extern  "C"
{
#endif

#include <$(proc)/id.h>
#include <$(proc)/gen_int.h>

$(foreach modules)
#include <$(proc)/$(name).h>
$(end)

/* data structures */

typedef enum
{
   INSTRUCTION,
   TABLEFETCH
} Type_Decode;

typedef struct
{
	Type_Decode type;
	void *ptr;	/* will be used to store an instruction ID or the address of a Table_Decodage */
} Decode_Ent;

$(if is_multi_set)
$(foreach instr_sets_sizes)
$(if is_RISC_size)
typedef struct {
        uint$(C_size)_t        mask;
        Decode_Ent      *table;
} Table_Decodage_$(C_size);
$(else)
typedef struct {
        mask_t        *mask;
        Decode_Ent      *table;
} Table_Decodage_CISC;
$(end)
$(end)$(end)
$(if !is_multi_set)
$(if is_RISC)
typedef struct {
        uint$(C_inst_size)_t        mask;
        Decode_Ent      *table;
} Table_Decodage;
$(else)
typedef struct {
        mask_t        *mask;
        Decode_Ent      *table;
} Table_Decodage;
$(end)$(end)

$(INIT_FETCH_TABLES)


#if defined(__cplusplus)
}
#endif

#endif /* GLISS_$(PROC)_INCLUDE_$(PROC)_FETCH_TABLE_H */
