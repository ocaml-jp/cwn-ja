open! Core

type t =
  | English
  | Japanese
[@@deriving sexp_of]

let title = function
  | English | Japanese -> "OCaml Weekly News"
;;

let previous_week = function
  | English -> "Previous Week"
  | Japanese -> "先週号"
;;

let up = function
  | English -> "Up"
  | Japanese -> "上へ"
;;

let next_week = function
  | English -> "Next Week"
  | Japanese -> "次週号"
;;

let greeting ~date_text = function
  | English ->
    [%string
      {|Hello

Here is the latest OCaml Weekly News, for the week of %{date_text}.

|}]
  | Japanese ->
    [%string
      {|こんにちは

%{date_text}の週の OCaml Weekly News をお届けします。

|}]
;;

let archive_prefix = function
  | English | Japanese -> "Archive: "
;;

let old_cwn_heading = function
  | English -> "Old CWN"
  | Japanese -> "過去の CWN"
;;

let old_cwn_body = function
  | English ->
    {|If you happen to miss a CWN, you can [[mailto:alan.schmitt@polytechnique.org][send me a message]] and I'll mail it to you, or go take a look at [[https://alan.petitepomme.net/cwn/][the archive]] or the [[https://alan.petitepomme.net/cwn/cwn.rss][RSS feed of the archives]].

If you also wish to receive it every week by mail, you may subscribe to the [[https://sympa.inria.fr/sympa/info/caml-list][caml-list]].
|}
  | Japanese ->
    {|CWN を見逃した場合は、[[mailto:alan.schmitt@polytechnique.org][メッセージを送っていただければ]]メールでお送りします。また、[[https://ocaml.jp/cwn-ja/][アーカイブ]]や[[https://ocaml.jp/cwn-ja/cwn.rss][RSS フィード]]もご覧いただけます。

毎週メールで受け取りたい場合は、[[https://sympa.inria.fr/sympa/info/caml-list][caml-list]] を購読してください。
|}
;;

(* Japanese nav points to sibling files in the same directory (the cwn-ja site
   serves weekly HTML pages next to each other); English nav points to the
   upstream alan.petitepomme.net archive. *)
let weekly_url t ~date =
  match t with
  | English -> [%string "https://alan.petitepomme.net/cwn/%{date}.html"]
  | Japanese -> [%string "file:%{date}.html"]
;;

let index_url = function
  | English -> "https://alan.petitepomme.net/cwn/index.html"
  | Japanese -> "file:index.html"
;;

(* Canonical site root used for absolute URLs in RSS items. Upstream for
   English; the cwn-ja site for Japanese. *)
let site_base_url = function
  | English -> "https://alan.petitepomme.net/cwn/"
  | Japanese -> "https://ocaml.jp/cwn-ja/"
;;

let format_date t date =
  match t with
  | English -> Date_unix.format date "%d %b %Y"
  | Japanese -> Date_unix.format date "%Y年%-m月%-d日"
;;

let rss_title t date =
  let title = title t in
  let d = format_date t date in
  match t with
  | English -> [%string "%{title}, %{d}"]
  | Japanese -> [%string "%{title} (%{d}版）"]
;;
