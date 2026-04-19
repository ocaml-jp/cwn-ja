(** Language selection for {!Cwn.to_orgmode} / {!Cwn.to_rss} output.

    Controls the boilerplate strings ("Previous Week", the greeting, the
    "Old CWN" footer, etc.) and the URL scheme for navigation links:
    [English] links to the upstream [alan.petitepomme.net/cwn/] archive,
    [Japanese] links to sibling [file:…] HTML pages served from the
    translation site. *)

open! Core

type t =
  | English
  | Japanese
[@@deriving sexp_of]

val title : t -> string
val previous_week : t -> string
val up : t -> string
val next_week : t -> string
val greeting : date_text:string -> t -> string
val archive_prefix : t -> string
val old_cwn_heading : t -> string
val old_cwn_body : t -> string
val weekly_url : t -> date:string -> string
val index_url : t -> string

(** Absolute site root for RSS item URLs. English uses the upstream
    [alan.petitepomme.net/cwn/] archive; Japanese uses [ocaml.jp/cwn-ja/]
    where the translation site is published. *)
val site_base_url : t -> string

(** Render a date for display in RSS titles. English uses ["%d %b %Y"]
    (e.g. ["31 Mar 2026"]); Japanese uses [YYYY年M月D日] without zero-padding
    on month/day (e.g. ["2026年3月31日"]). *)
val format_date : t -> Date.t -> string

(** Full RSS [<title>] string: combines the publication title with the
    localised date. English: ["OCaml Weekly News, 31 Mar 2026"]; Japanese:
    ["OCaml Weekly News (2026年3月31日版）"]. *)
val rss_title : t -> Date.t -> string
