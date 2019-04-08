(*
 * Copyright (c) 2014 Leo White <lpw25@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Model
open Paths
open Names

class type t = object
  method root : Root.t -> Root.t
  inherit Maps.paths
  method offset_identifier_signature :
    Identifier.Signature.t * int -> Identifier.Signature.t * int
  inherit Maps.types
end

let signature s sg =
  s#signature sg

let class_signature s csig =
  s#class_signature csig

let datatype s decl =
  s#type_decl_representation decl

let module_ s md =
  s#module_ md

let module_type s mty =
  s#module_type mty

let type_decl s decl =
  s#type_decl decl

let constructor s cstr =
  s#type_decl_constructor cstr

let field s field =
  s#type_decl_field field

let extension s ext =
  s#extension ext

let exception_ s exn =
  s#exception_ exn

let value s v =
  s#value v

let class_ s cl =
  s#class_ cl

let class_type s cty =
  s#class_type cty

let method_ s meth =
  s#method_ meth

let instance_variable s inst =
  s#instance_variable inst

let comment s com =
  s#documentation_comment com

let documentation s doc =
  s#documentation doc

let identifier_signature s id =
  s#identifier_signature id

let offset_identifier_signature s idoff =
  s#offset_identifier_signature idoff

(* TODO either expose more maps or expose argument map directly *)
let identifier_module s id =
  s#identifier_module id

let module_type_expr s expr =
  s#module_type_expr expr

let module_expansion s expr =
  s#module_expansion expr

class rename_signature ~equal:_ (x : Identifier.Signature.t)
        (y : Identifier.Signature.t) offset : t = object

  inherit Maps.paths as super

  method root x = x

  method! identifier_signature id =
    if Identifier.Signature.equal id x then y
    else super#identifier_signature id

  method! identifier (id : Identifier.t)
         : Identifier.t =
    match id with
    | `Argument(parent, pos, name) ->
        if Identifier.Signature.equal parent x then
          `Argument(y, pos + offset, name)
        else super#identifier id
    | id -> super#identifier id

  method offset_identifier_signature (id, offset') =
    if Identifier.Signature.equal id x then (y, offset + offset')
    else (super#identifier_signature id, offset')

  inherit Maps.types

end

let rename_signature ~equal x y offset =
  new rename_signature ~equal x y offset

class rename_class_signature ~equal:_
           (x : Identifier.ClassSignature.t)
           (y : Identifier.ClassSignature.t) : t = object (self)

  inherit Maps.paths as super

  method root x = x

  method! identifier_class_signature id =
    if Identifier.ClassSignature.equal id x then y
    else super#identifier_class_signature id

  inherit Maps.types

  method offset_identifier_signature (id, offset) =
    (self#identifier_signature id, offset)

end

let rename_class_signature ~equal x y =
  new rename_class_signature ~equal x y

class rename_datatype ~equal:_ (x : Identifier.DataType.t)
        (y : Identifier.DataType.t) : t = object (self)

  inherit Maps.paths as super

  method root x = x

  method! identifier_datatype id =
    if Identifier.DataType.equal id x then y
    else super#identifier_datatype id

  inherit Maps.types

  method offset_identifier_signature (id, offset) =
    (self#identifier_signature id, offset)

end

let rename_datatype ~equal x y =
  new rename_datatype ~equal x y

(*let module_id_path (type k) (Witness : k is_path_kind)
                   (id : ('a, k) Identifier.t) name =
  let open Path.Resolved in
    (Module(Identifier id, name))*)

class prefix ~equal:_ ~canonical id : t = object (self)

  inherit Maps.paths as super

  method root x = x

  method! path_resolved : Path.Resolved.t -> Path.Resolved.t =
    fun p ->
      let matches id' =
        Identifier.Signature.equal (id :> Identifier.Signature.t) id'
      in
      let replacement =
        match canonical with
        | None -> `Identifier id
        | Some(path, _) -> `Canonical(`Identifier id, path)
      in
        match p with
        | `Identifier (`Module(parent, name)) ->
            if matches parent then `Module(replacement, name)
            else super#path_resolved p
        | `Identifier (`ModuleType(parent, name)) ->
            if matches parent then (`ModuleType(replacement, name))
            else super#path_resolved p
        | `Identifier (`Type(parent, name)) ->
            if matches parent then (`Type(replacement, name))
            else super#path_resolved p
        | `Identifier (`Class(parent, name)) ->
            if matches parent then (`Class(replacement, name))
            else super#path_resolved p
        | `Identifier (`ClassType(parent, name)) ->
            if matches parent then (`ClassType(replacement, name))
            else super#path_resolved p
        | _ -> super#path_resolved p

  method! reference_resolved : Reference.Resolved.t ->
                              Reference.Resolved.t =
    fun r ->
      let sid = (id :> Identifier.Signature.t) in
      let matches id' =
        Identifier.Signature.equal sid id'
      in
      let open Reference.Resolved in
      let replacement =
        match canonical with
        | None -> `Identifier id
        | Some(_, reference) -> `Canonical(`Identifier id, reference)
      in
      let sreplacement = (replacement :> Signature.t) in
      let lreplacement = (replacement :> LabelParent.t) in
      match r with
      | `Identifier (`Module(parent, name)) ->
          if matches parent then `Module(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`ModuleType(parent, name)) ->
          if matches parent then `ModuleType(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`Type(parent, name)) ->
          if matches parent then `Type(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`Extension(parent, name)) ->
          if matches parent then `Extension(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`Exception(parent, name)) ->
          if matches parent then `Exception(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`Value(parent, name)) ->
          if matches parent then `Value(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`Class(parent, name)) ->
          if matches parent then `Class(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`ClassType(parent, name)) ->
          if matches parent then `ClassType(sreplacement, name)
          else super#reference_resolved r
      | `Identifier (`Label(parent, name)) -> begin
          match parent with
          | `Root _ | `Argument _
          | `Module _ | `ModuleType _ as parent ->
                if matches parent then `Label(lreplacement, name)
                else super#reference_resolved r
          | _ -> super#reference_resolved r
        end
      | _ -> super#reference_resolved r

  inherit Maps.types

  method offset_identifier_signature (id, offset) =
    (self#identifier_signature id, offset)

end

let prefix ~equal ~canonical id =
  new prefix ~equal ~canonical id

class strengthen path : t = object

  inherit Maps.types

  method root x = x

  method! documentation_comment x = x

  method! module_ md =
    if Path.Resolved.Module.is_hidden path then md
    else begin
      let open Lang.Module in
      match md.type_ with
      | Alias p when not (Path.Module.is_hidden p) -> md
      | _ ->
          let name = Identifier.name md.id in
          let path = `Resolved(`Module(path, ModuleName.of_string name)) in
          let type_ = Alias path in
          let expansion = None in
          { md with type_; expansion }
    end

  method! module_type x = x

  method! type_decl x = x

  method! extension x = x

  method! exception_ x = x

  method! value x = x

  method! external_ x = x

  method! class_ x = x

  method! class_type x = x

  method! include_ x = x

  inherit Maps.paths

  method offset_identifier_signature x = x

  method! module_type_expr x = x

end

let strengthen path =
  new strengthen path

let make_lookup ~equal:_ ~hash:_
                (items : (Identifier.Module.t * Identifier.Module.t) list) =
  let module Hash = struct
    type t = Identifier.Module.t
    let equal = Identifier.Module.equal
    let hash = Identifier.Module.hash
  end in
  let module Tbl = Hashtbl.Make(Hash) in
  let tbl = Tbl.create 13 in
  List.iter (fun (id1, id2) -> Tbl.add tbl id1 id2) items;
    fun id ->
        match Tbl.find tbl id with
        | id -> Some id
        | exception Not_found -> None

class pack ~equal ~hash
           (items : (Identifier.Module.t
                     * Identifier.Module.t) list) : t = object (self)

  val lookup = make_lookup ~equal ~hash items

  method root x = x

  inherit Maps.paths as super

  method! identifier : Identifier.t -> Identifier.t =
    fun id ->
        match id with
        | `Root _ as id -> begin
            match lookup id with
            | Some (`Root _ | `Module _ | `Argument _ as id) -> id
            | None -> super#identifier id
          end
        | `Module _ as id -> begin
            match lookup id with
            | Some (`Root _ | `Module _ | `Argument _ as id) -> id
            | None -> super#identifier id
          end
        | `Argument _ as id -> begin
            match lookup id with
            | Some (`Root _ | `Module _ | `Argument _ as id) -> id
            | None -> super#identifier id
          end
        | _ -> super#identifier id

  inherit Maps.types

  method offset_identifier_signature (id, offset) =
    (self#identifier_signature id, offset)

end

let pack ~equal ~hash items =
  new pack ~equal ~hash items

class type_var_subst (substs : (string * Lang.TypeExpr.t) list) = object
  inherit Maps.type_expr as super

  method! type_expr e = match e with
    | Var v -> begin
        try List.assoc v substs 
        with Not_found -> e
      end
    | _ -> super#type_expr e

  method path_module_type x = x

  method path_type x = x

  method path_class_type x = x

  method fragment_type x = x
    
  method documentation x = x
end

class subst_type ~equal:_ (x : Path.Resolved.Type.t) (y : Lang.TypeDecl.Equation.t) : t = object (self)

  inherit Maps.types as super

  method! type_expr expr = 
    let open Lang.TypeExpr in
    match expr with
    | Constr (`Resolved p, args) when Path.Resolved.Type.equal p x -> begin
        Printf.printf "Visiting type_expr Constr(`Resolved %s, _)\n" (Dump.Path.Resolved.Type.dump p);
        let args = Maps.list_map self#type_expr args in
        match y with
        | { params; manifest = Some manifest; _ } ->
          let var_substs = List.fold_left2 (fun acc arg param ->
              match param with
              | (Lang.TypeDecl.Var v, _) -> (v, arg) :: acc
              | (Lang.TypeDecl.Any, _) -> acc) [] args params
          in
          (new type_var_subst var_substs)#type_expr manifest
        | _ -> Printf.printf "equation doesn't match\n"; super#type_expr expr
      end
    | _ -> super#type_expr expr

  method! extension ext =
    let open Lang.Extension in
    match ext with
    | { type_path = `Resolved p; type_params; _ } when Path.Resolved.Type.equal p x -> begin
        match y with
        | { params=_; manifest = Some (Constr (sub_path, sub_args)); _ } ->
          (* FIXME params might be used to reorder parameters maybe *)
          if List.length sub_args = List.length type_params then
            { (super#extension ext) with type_path = sub_path }
          else
            super#extension ext
        | _ -> super#extension ext
      end
    | _ -> super#extension ext

  method! type_decl d =
    Printf.printf "Visiting type_decl with ident %s\n" (Dump.Identifier.Type.dump d.Lang.TypeDecl.id);
    super#type_decl d

  method! signature s =
    let open Lang.Signature in
    List.fold_right (fun item items ->
        match item with
        | Type (_, Lang.TypeDecl.{id; _}) when Path.Resolved.Type.equal_identifier (id:>Identifier.Path.Type.t) x ->
          items
        | _ ->
          let item' = self#signature_item item in
          item' :: items) s []

  inherit Maps.paths

  method root x = x

  method offset_identifier_signature x = x

end

let subst_type ~equal x y =
  new subst_type ~equal x y

class subst_module ~equal:_ (x:Path.Resolved.Module.t) (_y:Path.Module.t) : t = object (self)

  inherit Maps.types

  method! signature s =
    List.fold_right (fun item items ->
        match item with
        | Lang.Signature.Module (_, Lang.Module.{ id; _}) when Path.Resolved.Module.equal_identifier (id:>Identifier.Path.Module.t) x ->
          items
        | _ ->
          (match item with
           | Lang.Signature.Value Lang.Value.{ id; type_=Lang.TypeExpr.Constr(tp, _); _ } ->
             Printf.printf "Visiting value %s : _ %s\n" (Dump.Identifier.Value.dump id) (Dump.Path.Type.dump tp)
           | _ -> ()
          );
          let item' = self#signature_item item in
          item' :: items) s []

  inherit Maps.paths as _super

  method! path_module m =
    match m with
    | `Resolved m when Path.Resolved.Module.equal m x -> _y
    | m -> _super#path_module m

  method! path_type p =
    match p with
    | `Resolved (`Type (m, name)) -> begin
        match self#path_module (`Resolved m) with
        | `Resolved m' -> `Resolved (`Type (m', name))
        | m' -> `Dot (m', TypeName.to_string name)
      end
    | `Resolved (`Class (m, name)) -> begin
        match self#path_module (`Resolved m) with
        | `Resolved m' -> `Resolved (`Class (m', name))
        | m' -> `Dot (m', ClassName.to_string name)
      end
    | `Resolved (`ClassType (m, name)) -> begin
        match self#path_module (`Resolved m) with
        | `Resolved m' -> `Resolved (`ClassType (m', name))
        | m' -> `Dot (m', ClassTypeName.to_string name)
      end
    | p -> _super#path_type p

  method! path_module_type p =
    match p with
    | `Resolved (`ModuleType (m, name)) -> begin
        match self#path_module (`Resolved m) with
        | `Resolved m' -> `Resolved (`ModuleType (m', name))
        | m' -> `Dot (m', ModuleTypeName.to_string name)
      end
    | p -> _super#path_module_type p

  method! path_class_type p =
    match p with
    | `Resolved (`Class (m, name)) -> begin
        match self#path_module (`Resolved m) with
        | `Resolved m' -> `Resolved (`Class (m', name))
        | m' -> `Dot (m', ClassName.to_string name)
      end
    | `Resolved (`ClassType (m, name)) -> begin
        match self#path_module (`Resolved m) with
        | `Resolved m' -> `Resolved (`ClassType (m', name))
        | m' -> `Dot (m', ClassTypeName.to_string name)
      end
    | p -> _super#path_class_type p

  method root x = x

  method offset_identifier_signature x = x
end

let subst_module ~equal x y =
  new subst_module ~equal x y
