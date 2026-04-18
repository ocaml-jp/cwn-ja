open! Core

module Entry = struct
  type t =
    { title : string
    ; url : string option
    ; content : (string * string) list
    }
  [@@deriving sexp_of]
end

type t =
  { date : string
  ; previous : string
  ; next : string
  ; date_text : string
  ; extra_head : string option
  ; entries : Entry.t list
  }
[@@deriving sexp_of]

let of_xmltree tree =
  let header = Xmltree.get_children_with_tag "cwn_head" tree in
  let date, header = Xmltree.get_data_with_tag "cwn_date" header in
  let previous, header = Xmltree.get_data_with_tag "cwn_prev" header in
  let next, header = Xmltree.get_data_with_tag "cwn_next" header in
  let date_text, header = Xmltree.get_data_with_tag "cwn_date_text" header in
  let extra_head =
    try
      let e, _ = Xmltree.get_data_with_tag "cwn_extra_head" header in
      match String.is_empty e with
      | true -> None
      | false -> Some e
    with
    | Failure _ -> None
  in
  let entry_elems = Xmltree.get_children_with_tag "cwn_body" tree in
  let parse_entry elem : Entry.t =
    let children = Xmltree.get_children elem in
    let title, children = Xmltree.get_data_with_tag "cwn_title" children in
    let url, children =
      try
        let u, rest = Xmltree.get_data_with_tag "cwn_url" children in
        Some u, rest
      with
      | Failure _ -> None, children
    in
    let rec messages acc = function
      | [] -> List.rev acc
      | rest ->
        let who, rest = Xmltree.get_data_with_tag "cwn_who" rest in
        let what, rest = Xmltree.get_data_with_tag "cwn_what" rest in
        messages ((who, what) :: acc) rest
    in
    { title; url; content = messages [] children }
  in
  { date
  ; previous
  ; next
  ; date_text
  ; extra_head
  ; entries = List.map entry_elems ~f:parse_entry
  }
;;

let replace_markdown_links =
  let re =
    Re.compile (Re.Perl.re {|\[([^][]*)\]\(<?((?:http|mailto)[^()<>]*)>?\)|})
  in
  fun s ->
    Re.replace re s ~f:(fun g ->
      let text = Re.Group.get g 1 in
      let url = Re.Group.get g 2 in
      [%string "[[%{url}][%{text}]]"])
;;

let to_orgmode { previous; next; date_text; extra_head; entries; date = _ } =
  let header =
    {|#+OPTIONS: ^:nil
#+OPTIONS: html-postamble:nil
#+OPTIONS: num:nil
#+OPTIONS: toc:nil
#+OPTIONS: author:nil
#+HTML_HEAD: <style type="text/css">#table-of-contents h2 { display: none } .title { display: none } .authorname { text-align: right }</style>
#+HTML_HEAD: <style type="text/css">.outline-2 {border-top: 1px solid black;}</style>
#+TITLE: OCaml Weekly News
|}
  in
  let nav =
    [%string
      {|[[https://alan.petitepomme.net/cwn/%{previous}.html][Previous Week]] [[https://alan.petitepomme.net/cwn/index.html][Up]] [[https://alan.petitepomme.net/cwn/%{next}.html][Next Week]]

|}]
  in
  let greeting =
    [%string
      {|Hello

Here is the latest OCaml Weekly News, for the week of %{date_text}.

|}]
  in
  let extra_head_chunk =
    Option.value_map extra_head ~default:[] ~f:(fun eh ->
      [ [%string "%{eh}\n\n"] ])
  in
  let toc = "#+TOC: headlines 1\n" in
  let entry_chunks =
    List.concat
      (List.mapi entries ~f:(fun i entry ->
         let { Entry.title; url; content } = entry in
         let custom_id = i + 1 in
         let head =
           [%string
             {|

* %{title}
:PROPERTIES:
:CUSTOM_ID: %{custom_id#Int}
:END:
|}]
         in
         let url_chunk =
           Option.value_map url ~default:[] ~f:(fun u ->
             [ [%string "Archive: %{u}\n\n"] ])
         in
         let messages =
           List.map content ~f:(fun (who, what) ->
             let rewritten = replace_markdown_links what in
             [%string
               {|** %{who}

%{rewritten}

|}])
         in
         (head :: url_chunk) @ messages))
  in
  let footer =
    {|

* Old CWN
:PROPERTIES:
:UNNUMBERED: t
:END:

If you happen to miss a CWN, you can [[mailto:alan.schmitt@polytechnique.org][send me a message]] and I'll mail it to you, or go take a look at [[https://alan.petitepomme.net/cwn/][the archive]] or the [[https://alan.petitepomme.net/cwn/cwn.rss][RSS feed of the archives]].

If you also wish to receive it every week by mail, you may subscribe to the [[https://sympa.inria.fr/sympa/info/caml-list][caml-list]].

#+BEGIN_authorname
[[https://alan.petitepomme.net/][Alan Schmitt]]
#+END_authorname
|}
  in
  List.concat
    [ [ header; nav; greeting ]; extra_head_chunk; [ toc ]; entry_chunks; [ footer ] ]
  |> String.concat
;;

let to_rss { date; entries; previous = _; next = _; date_text = _; extra_head = _ } =
  let parsed = Date_unix.parse ~fmt:"%Y.%m.%d" date in
  let formatted = Date_unix.format parsed "%d %b %Y" in
  let header =
    [%string
      {|<?xml version="1.0" encoding="utf-8"?>
<item>
  <title>OCaml Weekly News, %{formatted}</title>
  <pubDate>%{formatted} 12:00 GMT</pubDate>
  <link>https://alan.petitepomme.net/cwn/%{date}.html</link>
  <guid>https://alan.petitepomme.net/cwn/%{date}.html</guid>
  <description>&lt;ol&gt;|}]
  in
  let items =
    List.mapi entries ~f:(fun i entry ->
      let { Entry.title; url = _; content = _ } = entry in
      let n = i + 1 in
      [%string
        {|&lt;li&gt;&lt;a href="https://alan.petitepomme.net/cwn/%{date}.html#%{n#Int}"&gt;%{title}&lt;/a&gt;&lt;/li&gt;|}])
  in
  let footer = "&lt;/ol&gt;</description>\n</item>" in
  List.concat [ [ header ]; items; [ footer ] ] |> String.concat
;;
