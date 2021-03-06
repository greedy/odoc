type 'a opt = 'a option
let foo (type a) ?(bar : a opt) () = ()
(** Triggers an assertion failure when
    {:https://github.com/ocaml/odoc/issues/101} is not fixed. *)

type 'a opt' = int option
let foo' (type a) ?(bar : a opt') () = ()
(** Similar to the above, but the printed type of [~bar] should be [int], not
    ['a]. This probably requires fixing in the compiler. See
    {:https://github.com/ocaml/odoc/pull/230#issuecomment-433226807}. *)
