(*
 * $Id$
 * Copyright (c) 2009, IRIT - UPS <casse@irit.fr>
 *
 * This file is part of OGliss.
 *
 * GLISS2 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * GLISS2 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GLISS2; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *)

open Absint
open Irg

(* pair hashtable *)
module PairOrdering = struct
	type t = string * int
	let compare t1 t2 = compare t1 t2
end
module PairMap = Map.Make(PairOrdering)


(*module StatSet = Usedefs.StatSet*)


(** Build the list of used variables in the given expression.
	Add a special register ("", 0) if some indexes are not constant.
	@param e	Expression to examine.
	@return		Set of all used variables. *)
let used_vars e =
	let rec work s e =
		match e with
		| NONE -> s
		| COERCE (_, e) -> work s e
		| FORMAT (_, es) -> work_list s es
		| CANON_EXPR (_, _, es) -> work_list s es
		| REF id -> RegSet.add id 0 s
		| FIELDOF _ -> s
		| ITEMOF (_, id, ix) ->
			(try RegSet.add id (Sem.to_int (Sem.eval_const ix)) s
			with Sem.SemError _ -> RegSet.add "" 0 s)
		| BITFIELD (_, e1, e2, e3) -> work_list s [e1; e2; e3]
		| UNOP (_, _, e) -> work s e
		| BINOP (_, _, e1, e2) -> work_list s [e1; e2]
		| IF_EXPR (_, e1, e2, e3) -> work_list s [e1; e2; e3]
		| SWITCH_EXPR (_, c, cs, d) ->
			work_list s (c::d::(fst (List.split cs)))
		| CONST _ -> s
		| ELINE (_, _, e) -> work s e
		| EINLINE _ -> s
	and work_list s es =
		match es with
		| [] -> s
		| e::t -> work (work_list s t) e in
	work RegSet.empty e


(** Build the list of used variables in the given location.
	Add a special register ("", 0) if some indexes are not constant.
	@param l	Expression to examine.
	@return		(all located variables, all used variables). *)
let used_locs l =
	let rec work (ul, uv) l =
		match l with
		| LOC_NONE -> (ul, uv)
		| LOC_REF (_, id, Irg.NONE, e1, e2) ->
			(RegSet.add id 0 ul, RegSet.union (used_vars e1) (used_vars e2))
		| LOC_REF (_, id, ix, e1, e2) ->
			let ul =
				(try RegSet.add id (Sem.to_int (Sem.eval_const ix)) ul
				with Sem.SemError _ -> RegSet.add "" 0 ul) in
			(ul, RegSet.union (used_vars e1) (used_vars e2))
		| LOC_CONCAT (_, l1, l2) ->
			work (work (ul, uv) l1) l2 in
	work (RegSet.empty, RegSet.empty) l


(** Compute the worst compatibility for each variable reference
	all over the full program.
	@param comps	Hashtable of all computed computabilities.
	@return			Map of (variable reference, worst computability). *)
let worst_comp comps =

	let process map (id, ix, comp) =
		try
			let ocomp = PairMap.find (id, ix) map in
			PairMap.add (id, ix) (Comput.comp_join comp ocomp) (PairMap.remove (id, ix) map)
		with Not_found ->
			PairMap.add (id, ix) comp map in

	Absint.StatHashtbl.fold
		(fun _ comp map -> List.fold_left process map comp)
		comps
		PairMap.empty


(* !!NOTE!!
 *
 * DYNAMIC INFORMATION USAGE
 *	- assignment to register / temporary that is ever dynamic is not used
 *		and its dependencies are not used by this assignment
 *	- condition containing dynamic register / temporary is ever fuzzy
 *	- dynamic register / temporary does not need any storage
 *
 * STATIC INFORMATION USAGE
 *	- requires a storage
 *	- does not need fuzzy bit
 *
 * FUZZY INFORMATION USAGE
 *	- requires a storage
 *	- requires a fuzzy bit
 *
 * Usage may be of four kinds:
 *	- NOT_USED -- code generation not needed
 *	- USED -- statement is used as itself
 *	- PROP -- only used to generate the property computation
 *	- BOTH -- used by itself and by property computation
 *)


(** Compute if statement of the given attribute are used in the
	generation.
	@param comps	Result of the computability analysis for
					the current instruction.
	@param dus		Result of the def-use analysis for the current instruction.
	@param f		Analysis-dependent test function.
	@return			Set containing used statements. *)
(*let build_used comps dus f =
	let comp = Absint.StatHashtbl.find comps in
	let du = Absint.StatHashtbl.find dus in

	let rec record_use du set (id, idx) =
		let defs = Usedefs.State.get du id idx in
		StatSet.fold record_set defs set

	and record_set def set =
		if StatSet.mem def set then set else
		match def with
		| SET (l, e)
		| SETSPE (l, e) ->
			let ul, uv = used_locs l in
			let uv = RegSet.union uv (used_vars e) in
			if Comput.has_dynamic (comp def) uv then set else
			 !!WARNING!! Be careful. Should remove some assignments that
			 may need to set fuzzy bit.
			List.fold_left (record_use (du def)) (StatSet.add def set) uv
		| NOP -> set
		| _ -> failwith "too bad !" in

	let rec process_call name stk set =
		if List.mem name stk then set
		else process (Absint.get_stat name) (name::stk) set

	and process stat stk set =
		let set = match stat with
			| NOP -> set
			| SEQ (s1, s2) ->
				let set = process s2 stk (process s1 stk set) in
				if (StatSet.mem s1 set) || (StatSet.mem s2 set)
				then StatSet.add stat set
				else set
			| EVAL name -> process_call name stk set
			| EVALIND _ -> failwith "unsupported"
			| SET (l, e)
			| SETSPE (l, e) ->
				record_set stat set
			| IF_STAT (c, s1, s2) ->
				let set = process s2 stk (process s1 stk set) in
				if (StatSet.mem s1 set) || (StatSet.mem s2 set) then
					let set = StatSet.add stat set in
					let uv = used_vars c in
					if Comput.has_dynamic (comp stat) uv
					then set
					else List.fold_left (record_use (du stat)) set uv
				else set
			| SWITCH_STAT (c, cs, d) ->
				let (used, set) =
					List.fold_left
						(fun (used, set) s ->
							let set = process s stk set in
							(used || (StatSet.mem s set), set))
						(false, set)
						(d::(snd (List.split cs))) in
				if not used then set else
				let set = StatSet.add stat set in
				let uv = used_vars c in
				if Comput.has_dynamic (comp stat) uv
				then set
				else List.fold_left (record_use (du stat)) set uv
			| LINE (file, line, s) ->
				let set = process s stk set in
				if StatSet.mem s set
				then StatSet.add stat set
				else set
			| _ -> set in
		let (used, uv) = f stat in
		if not used then set else
		List.fold_left (record_use (du stat)) set uv in

	process_call "action" [] StatSet.empty*)


(** Collect all used vars and generates temporaries.
	@param info		Generation information.
	@param comps	Computabilties hashtable.
	@param used		Used hashtable.
	@return			Set of used variables with temporary and fuzzy temporary. *)
let collect_vars info comps used =
	(*let comp stat = Absint.StatHashtbl.find comps stat in*)
	let worst = worst_comp comps in

	let declare_fuzzy id ix =
		if (PairMap.find (id, ix) worst) = Comput.STATIC then ""
		else Toc.new_temp info BOOL in

	let check map id ix =
		match get_symbol id with
		| REG _
		| VAR _ ->
			(try
				ignore (PairMap.find (id, ix) map);
				map
			with Not_found ->
				PairMap.add (id, ix) (
						Toc.new_temp info (Sem.type_from_id id),
						declare_fuzzy id ix
					) map)
		| _ -> map in

	let rec collect_loc loc map =
		match loc with
		| LOC_NONE -> map
		| LOC_CONCAT(_, l1, l2) -> collect_loc l1 (collect_loc l2 map)
		| LOC_REF(_, id, Irg.NONE, _, _) -> check map id 0
		| LOC_REF(_, id, ix, _, _) ->
			try check map id (Sem.to_int (Sem.eval_const ix))
			with Sem.SemError _ -> map in

	let rec collect_call name stk map =
		if List.mem name stk then map else
		collect (Absint.get_stat name) (name::stk) map

	and collect stat stk map =
		if not (StatSet.mem stat used) then map else
		match stat with
		| SEQ (s1, s2) -> collect_list [s1; s2] stk map
		| EVAL name -> collect_call name stk map
		| EVALIND _ -> failwith "unsupported"
		| SET (l, _)
		| SETSPE (l, _) -> collect_loc l map
		| IF_STAT (c, s1, s2) -> collect_list [s1; s2] stk map
		| SWITCH_STAT (_, cs, d) -> collect_list (d::(snd (List.split cs))) stk map
		| LINE (_, _, s) -> collect s stk map
		| _ -> map

	and collect_list sl stk map =
		match sl with
		| [] -> map
		| s::t -> collect s stk map in

	collect_call "action" [] PairMap.empty

(* CODE GENERATION

	REQUIRED RESULTS
	* computability analysis
		kind of content of register: STATIC, DYNAMIC, FUZZY
		static_expr: expr -> BOOL (all used register are static)
		dynamic_expr: expr -> BOOL (one of used register is dynamic)
	* fuzzy analysis
		may have a register a fuzzy value
		maybe_fuzzy: ID x expr -> BOOL (in one state, it is fuzzy)
		fuzzname: ID -> ID (name of the associated fuzzy boolean)

	* involvement analysis
		is a statement involved in the analysis
		* definition analysis
			registers defined by a statement
		* use analysis
			is statement used according to the analysis requirement
		* requirement analysis
			list of register whose definition is required at a program point
		involved: stat -> BOOL
		involved(s) = use(s) /\ (def(s) ^ req(s) != {})

	T(s) =
		{ Ts(s); Tu(s) }

	Ts: stat -> stat
		problem specific generation (usually canonical calls)

	Tu: stat -> stat
		usage specific generation

		Tu[s] =
			if involved(s) then Tus[s] else NOP

		let protect e s1 s2 =
			let cond = AND{x[i] in e / maybe_fuzzy(x, i)} fuzzname(x)[i] in
			IF(cond, s1, s2)

		Tus[x[i] <- e] =
			let all_fuzzy x =
					foreach i in 0..|x|-1 do
						fuzzname(x)[i] <- true

			let assign x i e =
				SEQ(
					x[i] <- e,
					if maybe_fuzzy(x, i) then fuzzname(x)[i] <- false else NOP
				)

			let assign_fuzzy x i =
				fuzzname(x)[i] <- true

			if not static_expr(i) then
				all_fuzzy(x)
			else if static_expr(e) then
				assign(x, i, e)
			else if dynamic_expr(e)
				assign_fuzzy(x, i)
			else
				protect(e, assign(x, i, e), assign_fuzzy(x, i)

		Tus[IF(c, s1, s2)] =
			let join s1 s2 =
				SEQ(
					join_begin,
					Tu[s1],
					join_next,
					Tu[s2],
					join_end
				)

			if dynamic_expr(c) then
				join s1 s2
			else if static_expr(c) then
				IF(c, Tu[s1], Tu[s2])
			else
				protect(c,
					IF(c, Tu[s1], Tu[s2]),
					join s1 s2)

		Tus[s1; s2] = Tu[s1]; Tu[s2]

		Tus[ID(e1, ..., en) =
			let je = join(e1, ..., en) in
			if dynamic_expr(ej) then NOP else
			if static_expr(ej) then ID(e1, ..., en) else
			protect(ej, ID(e1, ..., en))

	ANALYSIS INTERFACE
		Ts: stat -> stat	analysis dependent generation
		prolog: () -> stat	before a join first statement
		next: () -> stat	before a join second statement
		epilog: () -> stat	after the join

	EXAMPLE: target_address
		Ts[PC <- e] =
			if static(e) then {_result <- ONE(e)} else {_result <- ANY}
		Ts[*] = NOP
		prolog = { }
		next = { _result_i <- _result}
		epilog =
			IF(_result == NONE, { _result <- _result_i; },
			IF(_result_i == NONE, { },
			{ _result = ANY }))

*)


(** Transoformation signature. *)
type vars = (string * string) PairMap.t
module type TRANSFORMATION = sig

	val use: stat -> (bool * RegSet.t)

	val translate: Toc.info_t -> stat -> vars -> stat

	val merge: Toc.info_t -> vars -> stat * stat * stat

end


(** Factory for transformations.
	@param T	Transformation to apply. *)
module Make(T: TRANSFORMATION) = struct

	let translate info comps vars used =
		let comp s = Comput.Obs.get comps s in
		let var id ix = PairMap.find (id, ix) vars in
		let used stat = StatSet.mem stat used in

		let filter_fuzzy comp vars =
			List.filter (fun (id, ix) -> (Comput.State.get comp id ix) = Comput.FUZZY) vars in
		let const v =
			CONST (BOOL, CARD_CONST (Int32.of_int v)) in
		let set_fuzzy id ix v =
			SET (LOC_REF(BOOL, (snd (var id ix)), NONE, NONE, NONE), const v) in
		let rec fuzzy_set lst v =
			match lst with
			| [] -> NOP
			| (id, ix)::t ->
				SEQ(set_fuzzy id ix v, fuzzy_set t v) in
		let rec fuzzy_or lst =
			match lst with
			| [] -> const 0
			| (id, ix)::t ->
				BINOP(BOOL, OR, REF (snd (var id ix)), fuzzy_or t) in

		let rec rewrite_loc loc =
			match loc with
			| LOC_NONE -> loc
			| LOC_CONCAT (t, l1, l2) ->
				LOC_CONCAT (t, rewrite_loc l1, rewrite_loc l2)
			| LOC_REF (t, id, NONE, l, u) ->
				(try
					let (v, fv) = var id 0 in
					LOC_REF (t, v, NONE, l, u)
				with Not_found -> loc)
			| LOC_REF (t, id, ix, l, u) ->
				(try
					let (v, fv) = var id (Sem.to_int (Sem.eval_const ix)) in
					LOC_REF (t, v, NONE, l, u)
				with Not_found -> loc
				| Sem.SemError _ -> failwith "too bad") in

		let rec rewrite e =
			match e with
			| COERCE (t, e) -> COERCE (t, rewrite e)
			| FORMAT (f, l) -> FORMAT (f, List.map rewrite l)
			| CANON_EXPR (t, i, l) -> CANON_EXPR (t, i, List.map rewrite l)
			| REF id ->
				(try REF (fst (var id 0))
				with Not_found -> e)
			| ITEMOF (t, id, ix) ->
				(try ITEMOF(t, fst (var id (Sem.to_int (Sem.eval_const ix))), NONE)
				with Not_found -> e)
			| BITFIELD (t, e1, e2, e3) -> BITFIELD (t, rewrite e1, rewrite e2, rewrite e3)
			| UNOP (t, op, e) -> UNOP (t, op, rewrite e)
			| BINOP (t, op, e1, e2) -> BINOP (t, op, rewrite e1, rewrite e2)
			| IF_EXPR (t, e1, e2, e3) -> IF_EXPR (t, rewrite e1, rewrite e2, rewrite e3)
			| SWITCH_EXPR (t, c, cs, d) ->
				SWITCH_EXPR (t, rewrite c, List.map (fun (c, e) -> (c, rewrite e)) cs, rewrite d)
			| ELINE (f, l, e) -> ELINE (f, l, rewrite e)
			| _ -> e in

		let rec trans_call name lst =
			if List.mem name lst then lst else
			let (lst, stat) = trans (Absint.get_stat name) (name::lst) in
			add_symbol name (ATTR (ATTR_STAT (name, stat)));
			lst

		and trans (stat: Irg.stat) (lst: string list) =
			if used stat then (lst, stat) else
			let ustat = T.translate info stat vars in
			if ustat = NOP then trans_stat lst stat else
			let (lst, stat) = trans_stat lst stat in
			(lst, SEQ(ustat, stat))

		and trans_stat lst stat =
			match stat with
			| SEQ (s1, s2) ->
				let (lst, s1) = trans s1 lst in
				let (lst, s2) = trans s2 lst in
				(lst, SEQ (s1, s2))
			| SET (l, e)
			| SETSPE (l, e) ->
				let (ul, uv) = used_locs l in
				let uv = (used_vars e) @ uv in
				let comp = comp stat in
				let fv = filter_fuzzy comp uv in
				let fl = filter_fuzzy comp ul in
				let set = SET (rewrite_loc l, rewrite e) in
				let set = if fl = [] then set else SEQ (set, fuzzy_set fl 0) in
				let stat = if fv = [] then set else IF_STAT(fuzzy_or fv, fuzzy_set fv 1, set) in
				(lst, stat)
			| EVAL name ->
				(trans_call name lst, stat)
			| _ -> (lst, stat) in
(*
| 	CANON_STAT of string * expr list
| 	ERROR of string
| 	IF_STAT of expr * stat * stat
| 	SWITCH_STAT of expr * (expr * stat) list * stat
| 	LINE of string * int * stat
| 	INLINE of string*)

		trans_call "action" []

	let transform info inst =
		Printf.printf "===> %s <===\n" (Iter.get_name inst);

		Toc.set_inst info inst;
		Toc.find_recursives info "action";
		Toc.prepare_call info "action";

		(* def-use analysis *)
		(*print_string "* Use-Defs analysis\n";
		let ctx = Usedefs.Obs.make () in
		let dom = Usedefs.Ana.run ctx "action" in
		let du = fst ctx in
		Usedefs.Dump.dump du "action" dom;
		print_string "\n\n";*)

		(* computability *)
		print_string "* computability analysis\n";
		let comp, dom = Comput.analyze inst "action" in
		Comput.dump (comp, dom) "action";
		print_string "\n\n";

		(* compute defs *)
		print_string "* definition analysis\n";
		let comp, dom = Def.analyze inst "action" in
		Def.dump (comp, dom) "action";
		print_string "\n\n";

		(* Property Dependent analysis *)
		print_string "* property dependence analysis\n";
		let comp, dom = PropDep.analyze (fun s -> fst (T.use s)) "action" in
		PropDep.dump (comp, dom) "action";
		print_string "\n\n";

		(* compute used *)
		(*print_string "* used statement analysis\n";
		let used = build_used comp du T.use in*)

		(* compute used_vars *)
		(*print_string "* used variables\n";
		let used_vars = collect_vars info comp used in*)

		(* translate *)
		(*let lst = translate info comp used_vars used in
		print_string "-->\n";*)

		(* generate code *)

		Toc.cleanup_temps info;
		Toc.StringHashtbl.clear info.Toc.attrs

end


(* write analysis *)
module WriteTransformer = struct
	let uniq_id = ref 0
	let new_id _ =
		incr uniq_id;
		Printf.sprintf "__res_%d" !uniq_id

	let is_reg name =
		match get_symbol name with
		| REG _ -> true
		| _ -> false

	let rec look l (f, s) =
		match l with
		| LOC_NONE -> (f, s)
		| LOC_CONCAT (_, l1, l2) ->
			look l2 (look l1 (f, s))
		| LOC_REF (_, id, ix, _, _) ->
			(is_reg id || f, RegSet.union s (used_vars ix))

	let use stat =
		match stat with
		| SET (l, e)
		| SETSPE (l, e) ->
			look l (false, RegSet.empty)
		| _ -> (false, RegSet.empty)

	let merge (info: Toc.info_t) vars =
		let before = new_id () in
		let second = new_id () in
		(
			INLINE (Printf.sprintf "written_copy(%s, _result);" before),
			INLINE (Printf.sprintf "%s = _result; _result = %s;" second before),
			INLINE (Printf.sprintf "written_join(_result, %s); written_free(%s); " second second)
		)

	let prolog (info: Toc.info_t) =
		let rec declare i =
			if i = 0 then "*_result = written_alloc();"
			else (Printf.sprintf "*__res_%d, " i) ^ (declare (i - 1)) in
		let res = INLINE ("written_t " ^ (declare !uniq_id)) in
		uniq_id := 0;
		res

	let epilog (info: Toc.info_t) =
		INLINE "return _result;"

	let translate (info: Toc.info_t) (stat: Irg.stat) (vars: vars) =
		NOP

end


module Transformer = Make(WriteTransformer)
let _ =

	App.run
		[]
		"SYNTAX: regs NMP_FILE\n\tgenerate code to get used registers\n"
		(fun info ->
			Iter.iter
				(fun _ inst -> Transformer.transform info inst)
				()

		)