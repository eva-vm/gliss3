/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */
#ifndef GLISS_$(PROC)_INCLUDE_$(PROC)_MACROS_H
#define GLISS_$(PROC)_INCLUDE_$(PROC)_MACROS_H

/* state access macros */
$(foreach registers)$(if !aliased)
#define $(PROC)_$(NAME) ((state)->$(name))
$(end)$(end)
$(foreach memories)
#define $(PROC)_$(NAME) ((state)->$(name))
$(end)


/* instruction size macros */
$(foreach instructions)
#define $(PROC)_$(IDENT)_SIZE	$(size)
$(end)


/* parameter access macros */
$(foreach instructions)
#define $(PROC)_$(IDENT)_IADDR		((inst)->instrinput[0].val.$(PROC)_ADDR)
#define $(PROC)_$(IDENT)_ISIZE		((inst)->instrinput[1].val.$(PROC)_SIZE)
$(foreach params)
#define $(PROC)_$(IDENT)_$(PARAM) ((inst)->instrinput[$(INDEX) + 2].val.$(param_type))
$(end)$(end)

#endif /* GLISS_$(PROC)_INCLUDE_$(PROC)_MACROS_H */
