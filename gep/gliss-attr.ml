(*
 * $Id: gliss-attr.ml,v 1.1 2009/09/15 07:50:48 casse Exp $
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

exception CommandError of string

(* library path *)
let paths = [
	Config.install_dir ^ "/lib/gliss/lib";
	Config.source_dir ^ "/lib";
	Sys.getcwd ()]


(* argument list *)
let out = ref "attr.c"
let template = ref ""
let do_func = ref false
let attr = ref ""
let def = ref "0"
let extends: string list ref = ref []
let options = [
	("-o", Arg.Set_string out, "output file");
	("-a", Arg.Set_string attr, "name of the attribute");
	("-t", Arg.Set_string template, "template file");
	("-f", Arg.Set do_func, "generate functions from expression");
	("-d", Arg.Set_string def, "default value");
	("-e", Arg.String (fun arg -> extends := arg::!extends), "extension files")
]


(** Perform the attribute generation of the given instruction.
	@param inst		Instruction to get syntax from.
	@param out		Output to use.
	@param info		Information about generation. *)
let process inst out info =
	info.Toc.out <- out;
	Toc.set_inst info inst;

	let process e =

		(* constant attribute *)
		if not !do_func then
			Irg.output_const info.Toc.out (Sem.eval_const e)

		(* function attribute *)
		else
			begin
				let params = Iter.get_params inst in
				Irg.param_stack params;
				let (s, e) = Toc.prepare_expr info Irg.NOP e in
				Toc.declare_temps info;
				Toc.gen_stat info s;
				output_string info.Toc.out "\treturn ";
				Toc.gen_expr info e;
				output_string info.Toc.out ";\n";
				Toc.cleanup_temps info;
				Irg.param_unstack params
			end in

	try
		match Iter.get_attr inst !attr with
		| Iter.EXPR e -> process e
		| Iter.STAT _ -> raise (Toc.Error (Printf.sprintf "attribute %s must be an expression !" !attr))
	with Not_found ->
		output_string info.Toc.out !def
	|	Sem.SemError msg ->
			raise (Toc.Error (Printf.sprintf "%s not constant: %s" !attr msg))



let _ =
	try
		App.run
			options
			"SYNTAX: gep [options] NML_FILE\n\tGenerate code for a user attribute."
			(fun info ->

				(* download the extensions *)
				List.iter
					(fun file ->
						Lexer.file := file;
						let lexbuf = Lexing.from_channel (open_in file) in
						Parser.top Lexer.main lexbuf)
					!extends;

				(* perform generation *)
				if !template = "" then raise (CommandError "an template must specified with '-t'") else
				if !attr = "" then raise (CommandError "an attribute name must specified with '-a'") else
				let maker = App.maker () in
				maker.App.get_instruction <-
					(fun inst dict -> (!attr, Templater.TEXT (fun out -> process inst out info)):: dict);
				let dict = App.make_env info maker in
				if not !App.quiet then (Printf.printf "creating \"%s\"\n" !out; flush stdout);
				Templater.generate_path dict !template !out;
			)
	with CommandError msg ->
		Printf.fprintf stderr "ERROR: %s\n" msg


