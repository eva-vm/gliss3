/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */
#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_API_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_API_H

#include <stdint.h>
#include <stdio.h>
#include "id.h"
#include "mem.h"
//#include "loader.h"


/* return an instruction identifier as a string instead of the $(proc)_ident_t which is not very user friendly */
char *$(proc)_get_string_ident($(proc)_ident_t id);

/* opaque types */
typedef struct $(proc)_platform_t $(proc)_platform_t;
typedef struct $(proc)_fetch_t $(proc)_fetch_t;
typedef struct $(proc)_decoder_t $(proc)_decoder_t;
/*typedef struct $(proc)_sim_t $(proc)_sim_t;*/

/* $(proc)_state_t type */
typedef struct $(proc)_state_t {
	$(proc)_platform_t *platform;
$(foreach registers)$(if !aliased)$(if array)
	$(type) $(name)[$(size)];
$(else)
	$(type) $(name);
$(end)$(end)$(end)
$(foreach memories)$(if !aliased)
	$(proc)_memory_t *$(NAME);
$(end)$(end)
} $(proc)_state_t;

/* $(proc)_sim_t type */
typedef struct $(proc)_sim_t {
	$(proc)_state_t *state;
	$(proc)_decoder_t *decoder;
	/* on libc stripped programs it is difficult to find the exit point, so we specify it */
	$(proc)_address_t addr_exit;
	/* anything else? */
} $(proc)_sim_t;

/* $(proc)_value_t type */
typedef union $(proc)_value_t {
	$(proc)_address_t addr;
	unsigned long size;
$(foreach values)
	$(type) $(name);
$(end)
} $(proc)_value_t;

/* $(proc)_param_t type */
$(if !GLISS_NO_PARAM)
	typedef enum $(proc)_param_t {
		$(PROC)_VOID_T = 0,
		$(PROC)_ADDR,
		$(PROC)_SIZE$(foreach params),
		$(PROC)_PARAM_$(NAME)_T$(end)$(foreach registers),
		$(PROC)_$(NAME)_T$(end)
	} $(proc)_param_t;
$(end)

/* $(proc)_ii_t type */
typedef struct $(proc)_ii_t {
$(if !GLISS_NO_PARAM)
		$(proc)_param_t type;
$(end)
	$(proc)_value_t val;
} $(proc)_ii_t;

/* $(proc)_inst_t type */
typedef struct $(proc)_inst_t {
	$(proc)_ident_t ident;
	$(proc)_ii_t *instrinput;
	$(proc)_ii_t *instroutput;
} $(proc)_inst_t;

/* auxiliary vector */
typedef struct $(proc)_auxv_t {
	int	a_type;
	union {
		long a_val;
		void *a_ptr;
		void (*a_fcn)();
	} a_un;
} $(proc)_auxv_t;

/* environment description */
typedef struct $(proc)_env_t
{
	int argc;

	char **argv;
	$(proc)_address_t argv_addr;

	char **envp;
	$(proc)_address_t envp_addr;

	$(proc)_auxv_t *auxv;
	$(proc)_address_t auxv_addr;

	$(proc)_address_t stack_pointer;
	$(proc)_address_t brk_addr;
} $(proc)_env_t;

/* platform management */
#define $(PROC)_MAIN_MEMORY		0
$(proc)_platform_t *$(proc)_new_platform(void);
$(proc)_memory_t *$(proc)_get_memory($(proc)_platform_t *platform, int index);
struct $(proc)_env_t;
struct $(proc)_env_t *$(proc)_get_sys_env($(proc)_platform_t *platform);
void $(proc)_lock_platform($(proc)_platform_t *platform);
void $(proc)_unlock_platform($(proc)_platform_t *platform);
int $(proc)_load_platform($(proc)_platform_t *platform, const char *path);

/* fetching */
$(proc)_fetch_t *$(proc)_new_fetch($(proc)_platform_t *state);
void $(proc)_delete_fetch($(proc)_fetch_t *fetch);
$(proc)_ident_t $(proc)_fetch($(proc)_fetch_t *fetch, $(proc)_address_t address, uint32_t code);

/* decoding */
$(proc)_decoder_t *$(proc)_new_decoder($(proc)_platform_t *state);
void $(proc)_delete_decoder($(proc)_decoder_t *decoder);
$(proc)_inst_t *$(proc)_decode($(proc)_decoder_t *decoder, $(proc)_address_t address);
void $(proc)_free_inst($(proc)_inst_t *inst);

/* code execution */
void $(proc)_execute($(proc)_state_t *state, $(proc)_inst_t *inst);

/* state management function */
$(proc)_state_t *$(proc)_new_state($(proc)_platform_t *platform);
void $(proc)_delete_state($(proc)_state_t *state);
$(proc)_state_t *$(proc)_copy_state($(proc)_state_t *state);
$(proc)_state_t *$(proc)_fork_state($(proc)_state_t *state);
void $(proc)_dump_state($(proc)_state_t *state, FILE *out);
$(proc)_platform_t *$(proc)_platform($(proc)_state_t *state);

/* simulation functions */
$(proc)_sim_t *$(proc)_new_sim($(proc)_state_t *state, $(proc)_address_t start_addr, $(proc)_address_t exit_addr);
$(proc)_inst_t *$(proc)_next_inst($(proc)_sim_t *sim);
void $(proc)_step($(proc)_sim_t *sim);
int $(proc)_is_sim_ended($(proc)_sim_t *sim);
void $(proc)_delete_sim($(proc)_sim_t *sim);
$(proc)_address_t  $(proc)_next_addr($(proc)_sim_t *sim);

/* disassemble function */
void $(proc)_disasm(char *buffer, $(proc)_inst_t *inst);

#endif /* GLISS_$(PROC)_INCLUDE_$(PROC)_API_H */
