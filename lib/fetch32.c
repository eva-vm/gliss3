/* Generated by gep ($(date)) copyright (c) 2008 IRIT - UPS */

#include <stdlib.h>
#include <stdio.h>
#include <gliss/mem.h>
#include <gliss/fetch.h>

#include "fetch_table.h" /* or ../include/gliss/ ? */

#define gliss_error(e) fprintf(stderr, "%s\n", (e))
/* we should pass the next option on command line */
#define GLISS_NO_CACHE_FETCH

/* endianness */
typedef enum gliss_endianness_t {
  little = 0,
  big = 1
} gliss_endianness_t;

/* Extern Modules */
/* Constants */
#ifndef GLISS_NO_CACHE_FETCH
//# define GLISS_HASH_DEBUG
#	ifndef GLISS_HASH_NUM_INSTR
#		define GLISS_HASH_NUM_INSTR 0xFFFF
#	endif
#	ifndef GLISS_HASH_FUNC
#		define GLISS_HASH_FUNC(a) (((a)>>2)&GLISS_HASH_NUM_INSTR)
#	endif
#	ifndef GLISS_MALLOC_BUF_MAX_SIZE
#		define GLISS_MALLOC_BUF_MAX_SIZE (1024*1024)
#	endif
#else /* GLISS_NO_CACHE_FETCH */
#	ifndef GLISS_MAX_INSTR_FETCHED
#		define GLISS_MAX_INSTR_FETCHED 100
#	endif
#endif /* GLISS_NO_CACHE_FETCH */

/* Variables & Fonctions (for cache & no cache) */

#ifndef GLISS_NO_CACHE_FETCH

typedef struct hash_node_type
{
	gliss_ident_t instr_id;
	gliss_address_t id;
	struct hash_node_type *next;
} hash_node_t;

hash_node_t *hash_table[GLISS_HASH_NUM_INSTR+1];

typedef struct malloc_buf_type
{
	/* keep buffer at the first elt, for having a good alignment */
	char buffer[GLISS_MALLOC_BUF_MAX_SIZE];
	size_t size;
	struct malloc_buf_type *next;
} malloc_buf_t;

malloc_buf_t *last_malloc_buf = NULL;

#	ifdef GLISS_HASH_DEBUG

unsigned long int count_hits = 0, count_miss = 0, count_instr = 0,
count_hits_total = 0, count_miss_total = 0,
count_move = 0, count_move_total = 0;
unsigned long int move_total = 0, move_intern = 0;

#	endif /* GLISS_HASH_DEBUG */

static void *mymalloc(size_t size)
{
	void *buf;
	/* align size on 64 bits boundary, that is 8 bytes */
	size = (size +7) & ~(size_t)0x07;
	if ((last_malloc_buf == NULL) || ((last_malloc_buf->size + size) > GLISS_MALLOC_BUF_MAX_SIZE))
	{
		malloc_buf_t *malloc_buf = (malloc_buf_t *) malloc(sizeof(malloc_buf_t));
		malloc_buf->size = 0;
		malloc_buf->next = last_malloc_buf;
		last_malloc_buf = malloc_buf;
	}
	buf = &last_malloc_buf->buffer[last_malloc_buf->size];
	last_malloc_buf->size += size;
	return buf;
}

static void cache_halt(void)
{
	malloc_buf_t *ptr;
	ptr = last_malloc_buf;
	while (ptr != NULL)
	{
		ptr = ptr->next;
		free(last_malloc_buf);
		last_malloc_buf = ptr;
	}
	/* here, last_malloc_buf==NULL */
}

#else /* GLISS_NO_CACHE_FETCH */

static int instr_is_free[GLISS_MAX_INSTR_FETCHED];
static gliss_inst_t instr_tbl[GLISS_MAX_INSTR_FETCHED];

#endif /* GLISS_NO_CACHE_FETCH */


static void halt_fetch(void)
{
#ifndef GLISS_NO_CACHE_FETCH
	cache_halt();
#else /* GLISS_NO_CACHE_FETCH */
	/* nop */
#endif /* GLISS_NO_CACHE_FETCH */
}

static void init_fetch(void)
{
	int i;
#ifndef GLISS_NO_CACHE_FETCH
	for (i = 0; i < GLISS_HASH_NUM_INSTR + 1; i++)
		hash_table[i] = NULL;
#else /* GLISS_NO_CACHE_FETCH */
	for (i = 0; i < GLISS_MAX_INSTR_FETCHED; i++)
		instr_is_free[i] = 1;
#endif /* GLISS_NO_CACHE_FETCH */
}



/* initialization and destruction of gliss_fetch_t object */

static int number_of_fetch_objects = 0;

gliss_fetch_t *gliss_new_fetch(gliss_platform_t *state)
{
	gliss_fetch_t *res = malloc(sizeof(gliss_fetch_t));
	if (res == NULL)
		gliss_error("not enough memory to create a gliss_fetch_t object"); /* I assume error handling will remain the same, we use gliss_error istead of iss_error ? */
	res->mem = gliss_get_memory(state, GLISS_MAIN_MEMORY);
	if (number_of_fetch_objects == 0)
		init_fetch();
	number_of_fetch_objects++;
	return res;
}

void gliss_delete_fetch(gliss_fetch_t *fetch)
{
	if (fetch == NULL)
		/* we shouldn't try to free a void fetch_t object, should this output an error ? */
		gliss_error("cannot delete an NULL gliss_fetch_t object");
	free(fetch);
	number_of_fetch_objects--;
	/*assert(number_of_fetch_objects >= 0);*/
	if (number_of_fetch_objects == 0)
		halt_fetch();
}

/*
	donne la valeur d'une zone m�moire (une instruction) en ne prenant
	en compte que les bits indiqu�s par le mask

	on fait un ET logique entre l'instruction et le masque,
	on conserve seulement les bits indiqu�s par le masque
	et on les concat�ne pour avoir un nombre sur 32 bits

	on suppose que le masque n'a pas plus de 32 bits � 1,
	sinon d�bordement

	instr : instruction (de 32 bits)
	mask  : masque (32 bits aussi)
*/
static uint32_t valeur_sur_mask_bloc(uint32_t instr, uint32_t mask)
{
	int i;
	uint32_t tmp_mask;
	uint32_t res = 0;

	/* on fait un parcours du bit de fort poids de instr[0]
	� celui de poids faible de instr[nb_bloc-1], "de gauche � droite" */

	tmp_mask = mask;
	for (i = 31; i >= 0; i--)
	{
		/* le bit i du mask est 1 ? */
		if (tmp_mask & 0x80000000UL)
		{
			/* si oui, recopie du bit i de l'instruction
			� droite du resultat avec decalage prealable */
			res <<= 1;
			res |= ((instr >> i) & 0x01);
		}
		tmp_mask <<= 1;
	}
	return res;
}


/* Fonctions Principales */
gliss_ident_t gliss_fetch(gliss_fetch_t *fetch, gliss_address_t address, uint32_t code)
{
	int valeur;
	Table_Decodage *ptr;
	Table_Decodage *ptr2;

#ifndef GLISS_NO_CACHE_FETCH
	unsigned int index;
	hash_node_t *node;
#endif /* GLISS_NO_CACHE_FETCH */

#ifndef GLISS_NO_CACHE_FETCH

#	ifdef GLISS_HASH_DEBUG
	if ((count_instr % 10000000) == 0)
	{
		fprintf(stderr,
		"\ncount = %lu\thits = %lu\tmiss = %lu\tmove=%lu\n"
		"\ttotal hits = %lu\ttotal miss = %lu\ttotal move=%lu\n"
		"\tmax move = %lu\n",
		count_instr,count_hits,count_miss,count_move,
		count_hits_total,count_miss_total,count_move_total,
		move_total);
		count_hits = 0;
		count_miss = 0;
		count_move = 0;
		move_total = 0;
	}
#	endif /* GLISS_HASH_DEBUG */

	index = GLISS_HASH_FUNC(address);

#	ifdef GLISS_HASH_DEBUG
	count_miss++;
	count_instr++;
	count_miss_total++;
#	endif /* GLISS_HASH_DEBUG */

	if (hash_table[index] != NULL)
	{
		hash_node_t *prev;
		hash_node_t *act;
		if (hash_table[index]->id == address)
		{
#	ifdef GLISS_HASH_DEBUG
			count_hits++;
			count_hits_total++;
			count_miss--;
			count_miss_total--;
#	endif /* GLISS_HASH_DEBUG */
			return hash_table[index]->instr_id;
		}
		prev = hash_table[index];
		act = hash_table[index]->next;
#       ifdef GLISS_HASH_DEBUG
		move_intern = 0;
#       endif /* GLISS_HASH_DEBUG */
		for ( ; act != NULL; )
		{
#	ifdef GLISS_HASH_DEBUG
			move_intern++;
#	endif /* GLISS_HASH_DEBUG */
			if (act->id == address)
			{
				hash_node_t *next = act->next;
				prev->next = next;
				act->next = hash_table[index];
				hash_table[index] = act;
#	ifdef GLISS_HASH_DEBUG
				count_move++;
				count_move_total++;
				count_miss--;
				count_miss_total--;
				if (move_intern > move_total)
					move_total = move_intern;
#	endif /* GLISS_HASH_DEBUG */
				return act->instr_id;
			}
#	ifdef GLISS_HASH_DEBUG
			if(move_intern > move_total)
				move_total = move_intern;
#	endif /* GLISS_HASH_DEBUG */
			prev = act;
			act = act->next;
		}
	}
	node = (hash_node_t *)mymalloc(sizeof(hash_node_t));
	node->next = hash_table[index];
	node->id = address;

#else /* GLISS_NO_CACHE_FETCH */

#endif /* GLISS_NO_CACHE_FETCH */

	ptr2 = table;
	do
	{
                valeur = valeur_sur_mask_bloc(code, ptr2->mask0);
                ptr  = ptr2;
		ptr2 = ptr->table[valeur].ptr;
	}
	while (ptr->table[valeur].type == TABLEFETCH);

#ifndef GLISS_NO_CACHE_FETCH
	node->instr_id = (gliss_ident_t)ptr->table[valeur].ptr;
	hash_table[index] = node;
	return node->instr_id;
#else /* GLISS_NO_CACHE_FETCH */
	return (gliss_ident_t)ptr->table[valeur].ptr;
#endif /* GLISS_NO_CACHE_FETCH */
}

/* End of file gliss_fetch.c */
