(*
 * $Id: gep.ml,v 1.5 2008/11/25 17:11:36 casse Exp $
 * Copyright (c) 2008, IRIT - UPS <casse@irit.fr>
 *
 * This file is part of OGliss.
 *
 * OGliss is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * OGliss is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with OGliss; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *)
open Lexing

exception UnsupportedMemory of Irg.spec

(*module OrderedString = struct
	type t = string
	let compare s1 s2 = String.compare s1 s2
end
module StringSet = Set.Make(OrderedString)*)

module OrderedType = struct
	type t = Toc.c_type
	let compare s1 s2 = if s1 = s2 then 0 else if s1 < s2 then (-1) else 1
end
module TypeSet = Set.Make(OrderedType)


(* options *)
let nmp: string ref = ref ""
let quiet = ref false
let verbose = ref false
let options = [
	("v", Arg.Set verbose, "verbose mode");
	("q", Arg.Set verbose, "quiet mode")
]

let free_arg arg =
	if !nmp = ""
	then nmp := arg
	else raise (Arg.Bad "only one NML file required") 
let usage_msg = "SYNTAX: gep [options] NML_FILE\n\tGenerate code for a simulator"
let _ =
	Arg.parse options free_arg usage_msg;
	if !nmp = "" then begin
		prerr_string "ERROR: one NML file must be given !\n";
		Arg.usage options usage_msg;
		exit 1
	end


(** Build the given directory.
	@param path			Path of the directory.
	@raise Sys_error	If there is an error. *)
let makedir path =
	if not (Sys.file_exists path) then
		try 
			Unix.mkdir path 0o740
		with Unix.Unix_error (code, _, _) ->
			raise (Sys_error (Printf.sprintf "cannot create \"%s\": %s" path (Unix.error_message code)))
	else
		let stats = Unix.stat path in
		if stats.Unix.st_kind <> Unix.S_DIR
		then raise (Sys_error (Printf.sprintf "cannot create directory \"%s\": file in the middle" path))


(** Get the processor name.
	@return	Processor name.
	@raise	Sys_error	Raised if the proc is not defined. *)
let get_proc _ =
	match Irg.get_symbol "proc" with
	  Irg.LET(_, Irg.STRING_CONST name) -> name
	| _ -> raise (Sys_error "no \"proc\" definition available")


(** Format date (in seconds) and return a stirng.
	@param date	Date to format.
	@return		Date formatted as a string. *)
let format_date date =
	let tm = Unix.localtime date in
	Printf.sprintf "%0d/%02d/%02d %02d:%02d:%02d"
		tm.Unix.tm_year tm.Unix.tm_mon tm.Unix.tm_mday
		tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec


(* Test if memory or register attributes contains ALIAS.
	@param attrs	Attributes to test.
	@return			True if it contains "alias", false else. *)
let rec contains_alias attrs =
	match attrs with
	  [] -> false
	| (Irg.ALIAS _)::_ -> true
	| _::tl -> contains_alias tl



(** Build an include file.
	@param f	Function to generate the content of the file.
	@param proc	Processor name.
	@param file	file to create.
	@param dir	Directory containing the includes.
	@raise Sys_error	If the file cannot be created. *)
let make_include f info file =
	let uproc = String.uppercase info.Toc.proc in
	let path = info.Toc.ipath ^ "/" ^ file ^ ".h" in
	if not !quiet then Printf.printf "creating \"%s\"\n" path;
	info.Toc.out <- open_out path;
	
	(* output header *)
	let def = Printf.sprintf "GLISS_%s_%s_H" uproc (String.uppercase file) in
	Printf.fprintf info.Toc.out "/* Generated by gep (%s) copyright (c) 2008 IRIT - UPS */\n" (format_date (Unix.time ()));
	Printf.fprintf info.Toc.out "#ifndef %s\n" def;
	Printf.fprintf info.Toc.out "#define %s\n" def;
	
	(* output the content *)
	f info;
		
	(* output tail *)
	Printf.fprintf info.Toc.out "\n#endif /* %s */\n" def;
	close_out info.Toc.out
	

(** Build the file "proc/include/id.h"
	@param proc		Name of the processor. *)
let make_id_h info =
	let proc = info.Toc.proc in
	let out = info.Toc.out in
	let uproc = String.uppercase proc in
	Printf.fprintf out "\n/* %s_ident_t */\n" proc;
	Printf.fprintf out "typedef enum %s_ident_t {\n" proc;
	Printf.fprintf out "\t%s_UNKNOWN = 0" uproc;
	Iter.iter
		(fun _ i -> Printf.fprintf
			out
			",\n\t%s_%s = %d"
			uproc
			(Iter.get_name i)
			(Iter.get_id i))
		();
	Printf.fprintf out "\n} %s_ident_t;\n" proc


(** Build the XXX/include/api.h file. *)
let make_api_h info =
	let proc = info.Toc.proc in
	let out = info.Toc.out in
	let uproc = String.uppercase proc in

	let make_array size =
		if size = 1 then ""
		else Printf.sprintf "[%d]" size in

	let make_state k s =
		match s with
		  Irg.MEM (name, size, Irg.CARD(8), attrs)
		  when not (contains_alias attrs) ->
			Printf.fprintf out "\tgliss_memory_t *%s;\n" name
		| Irg.MEM _ ->
			raise (UnsupportedMemory s)
		| Irg.REG (name, size, t, attrs)
		when not (contains_alias attrs) ->
			Printf.fprintf out "\t%s %s%s;\n" (Toc.type_to_string (Toc.convert_type t)) name (make_array size)
		| _ -> () in

	let collect_field set (name, t) =
		match t with
		  Irg.TYPE_EXPR t -> TypeSet.add (Toc.convert_type t) set
		| Irg.TYPE_ID n ->
			(match (Irg.get_symbol n) with
			  Irg.TYPE (_, t) -> TypeSet.add (Toc.convert_type t) set
			| _ -> set) in
	
	let collect_fields set params =
		List.fold_left collect_field set params in
	
	let make_reg_param _ spec =
		match spec with
		  Irg.REG (name, size, t, attrs) ->
			Printf.fprintf out ",\n\t%s_%s_T" uproc (String.uppercase name)
		| _ -> () in		
	
	(* output includes *)
	Printf.fprintf out "\n#include <stdint.h>\n";
	Printf.fprintf out "#include <gliss/memory.h>\n";
	Printf.fprintf out "#include \"id.h\"";

	(* xxx_state_t typedef generation *)
	Printf.fprintf out "\n/* %s_state_t type */\n" proc;
	Printf.fprintf out "typedef %s_state_t {\n" proc;
	Irg.StringHashtbl.iter make_state Irg.syms;
	Printf.fprintf out "} %s_state_t;\n" proc;

	(* output xxx_value_t *)
	Printf.fprintf out "\n/* %s_value_t type */\n" proc;
	Printf.fprintf out "typedef union %s_value_t {\n" proc;
	let set = 
		Iter.iter (fun set i -> collect_fields set (Iter.get_params i)) TypeSet.empty in
	TypeSet.iter
		(fun t -> Printf.fprintf out "\t%s %s;\n" (Toc.type_to_string t) (Toc.type_to_field t))
		set;
	Printf.fprintf out "} %s_value_t;\n" proc;
	
	(* output xxx_param_t *)
	Printf.fprintf out "\n/* %s_param_t type */\n" proc;
	Printf.fprintf out "typedef enum %s_param_t {\n" proc;
	Printf.fprintf out "\tVOID_T = 0";
	TypeSet.iter
		(fun t -> Printf.fprintf out ",\n\t%s_PARAM_%s_T"
			uproc (String.uppercase (Toc.type_to_field t)))
		set;
	Irg.StringHashtbl.iter make_reg_param Irg.syms;
	Printf.fprintf out "\n} %s_param_t;\n" proc;
	
	(* output xxx_ii_t *)
	Printf.fprintf out "\n/* %s_ii_t type */\n" proc;
	Printf.fprintf out "typedef struct %s_ii_t {\n" proc;
	Printf.fprintf out "\t%s_param_t type;\n" proc;
	Printf.fprintf out "\t%s_value_t val;\n" proc;
	Printf.fprintf out "} %s_ii_t;\n" proc;
	
	(* output xxx_inst_t *)
	Printf.fprintf out "\n/* %s_inst_t type */\n" proc;
	Printf.fprintf out "typedef struct %s_inst_t {\n" proc;
	Printf.fprintf out "\t%s_ident_t ident;\n" proc;
	Printf.fprintf out "\t%s_ii_t *instrinput;\n" proc;
	Printf.fprintf out "\t%s_ii_t *instroutput;\n" proc;
	Printf.fprintf out "} %s_inst_t;\n" proc


(** Build the XXX/include/macros.h file.
	@param out	Output channel.
	@param proc	Name of the processor. *)
let make_macros_h info =
	let out = info.Toc.out in
	
	let make_state_macro k s =
		match s with
		  Irg.MEM (name, size, Irg.CARD(8), attrs)
		  when not (contains_alias attrs) ->
			Printf.fprintf out "#define %s(s) ((s)->%s)\n" (Toc.state_macro info name) name
		| Irg.MEM _ ->
			raise (UnsupportedMemory s)
		| Irg.REG (name, size, t, attrs)
		when not (contains_alias attrs) ->
			Printf.fprintf out "#define %s(s) ((s)->%s)\n" (Toc.state_macro info name) name
		| _ -> () in

	let get_type t =
		match t with
		  Irg.TYPE_EXPR t -> t
		| Irg.TYPE_ID n ->
			(match (Irg.get_symbol n) with
			  Irg.TYPE (_, t) -> t
			| _ -> Irg.NO_TYPE) in


	let make_param_macro _ inst =
		let _ = List.fold_left
			(fun i (n, t) ->
				let t = get_type t in
				if t <> Irg.NO_TYPE then
					Printf.fprintf out "#define %s(i) ((i)->instrinput[%d].val.%s\n"
						(Toc.param_macro info inst n) i (Toc.type_to_field (Toc.convert_type t));
				i + 1)
			0
			(Iter.get_params inst) in
		() in

	(* macros for accessing registers *)
	Printf.fprintf out "\n/* state access macros */\n";
	Irg.StringHashtbl.iter make_state_macro Irg.syms;
	
	(* macros for accessing parameters *)
	Printf.fprintf out "\n/* parameter access macros */\n";
	Iter.iter make_param_macro ()
	


(* main program *)
let _ =
	try	
		begin
			let lexbuf = Lexing.from_channel (open_in !nmp) in
			Parser.top Lexer.main lexbuf;
			let info = Toc.info () in
			if not !quiet then Printf.printf "creating \"include/\"\n";
			makedir "include";
			if not !quiet then Printf.printf "creating \"%s\"\n" info.Toc.ipath;
			makedir info.Toc.ipath;
			make_include make_id_h info "id";
			make_include make_api_h info "api";
			make_include make_macros_h info "macros"
		end

	with
	  Parsing.Parse_error ->
		Lexer.display_error "syntax error"; exit 2
	| Lexer.BadChar chr ->
		Lexer.display_error (Printf.sprintf "bad character '%c'" chr); exit 2
	| Sem.SemError msg ->
		Lexer.display_error (Printf.sprintf "semantics error : %s" msg); exit 2
	| Irg.IrgError msg ->
		Lexer.display_error (Printf.sprintf "ERROR: %s" msg); exit 2
	| Sem.SemErrorWithFun (msg, fn) ->
		Lexer.display_error (Printf.sprintf "semantics error : %s" msg);
		fn (); exit 2;
	| Sys_error msg ->
		Printf.eprintf "ERROR: %s\n" msg; exit 1
	| Failure e ->
		Lexer.display_error e; exit 3
