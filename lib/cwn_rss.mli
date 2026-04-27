(** Wraps the per-issue [<item>] fragments emitted by {!Cwn.to_rss} in the
    channel envelope served at [ja/cwn.rss]. *)

open! Core

(** [to_xml ~items] joins [items] with newlines and inserts them into the
    [<rss><channel>...</channel></rss>] envelope. Each item is expected to
    already be a single [<item>...</item>] element with the per-fragment XML
    declaration stripped off. *)
val to_xml : items:string list -> string
