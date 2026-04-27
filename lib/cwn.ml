open! Core
open! Async

module Entry = struct
  type t =
    { title : string
    ; url : string option
    ; content : (string * string) list
    }
  [@@deriving sexp_of]
end

type t =
  { date : Date.t
  ; previous : Date.t
  ; next : Date.t
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
    match Xmltree.find_data_with_tag "cwn_extra_head" header with
    | Some (e, _) when not (String.is_empty e) -> Some e
    | _ -> None
  in
  let entry_elems = Xmltree.get_children_with_tag "cwn_body" tree in
  let parse_entry elem : Entry.t =
    let children = Xmltree.get_children elem in
    let title, children = Xmltree.get_data_with_tag "cwn_title" children in
    let url, children =
      match Xmltree.find_data_with_tag "cwn_url" children with
      | Some (u, rest) -> Some u, rest
      | None -> None, children
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
  { date = Cwn_date.of_string date
  ; previous = Cwn_date.of_string previous
  ; next = Cwn_date.of_string next
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

let to_orgmode
      ~language
      { previous; next; date_text; extra_head; entries; date = _ }
  =
  let header =
    [%string
      {|#+OPTIONS: ^:nil
#+OPTIONS: html-postamble:nil
#+OPTIONS: num:nil
#+OPTIONS: toc:nil
#+OPTIONS: author:nil
#+HTML_HEAD: <style type="text/css">#table-of-contents h2 { display: none } .title { display: none } .authorname { text-align: right }</style>
#+HTML_HEAD: <style type="text/css">.outline-2 {border-top: 1px solid black;}</style>
#+TITLE: %{Language.title language}
|}]
  in
  let nav =
    let prev_url = Language.weekly_url language ~date:previous in
    let next_url = Language.weekly_url language ~date:next in
    let index_url = Language.index_url language in
    let prev_label = Language.previous_week language in
    let up_label = Language.up language in
    let next_label = Language.next_week language in
    [%string
      {|[[%{prev_url}][%{prev_label}]] [[%{index_url}][%{up_label}]] [[%{next_url}][%{next_label}]]

|}]
  in
  let greeting = Language.greeting language ~date_text in
  let extra_head_chunk =
    Option.value_map extra_head ~default:[] ~f:(fun eh ->
      [ [%string "%{eh}\n\n"] ])
  in
  let archive_prefix = Language.archive_prefix language in
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
             [ [%string "%{archive_prefix}%{u}\n\n"] ])
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
    [%string
      {|

* %{Language.old_cwn_heading language}
:PROPERTIES:
:UNNUMBERED: t
:END:

%{Language.old_cwn_body language}
#+BEGIN_authorname
[[https://alan.petitepomme.net/][Alan Schmitt]]
#+END_authorname
|}]
  in
  List.concat
    [ [ header; nav; greeting ]
    ; extra_head_chunk
    ; [ "#+TOC: headlines 1\n" ]
    ; entry_chunks
    ; [ footer ]
    ]
  |> String.concat
;;

let to_rss
      ~language
      { date; entries; previous = _; next = _; date_text = _; extra_head = _ }
  =
  (* RFC 822 pubDate. Assumes LC_TIME is C/en_* so strftime gives English
     day/month abbreviations; Ubuntu CI and macOS dev both default to that. *)
  let pub_date = Date_unix.format date "%a, %d %b %Y 12:00:00 GMT" in
  let page_url =
    [%string "%{Language.site_base_url language}%{date#Cwn_date}.html"]
  in
  let header =
    [%string
      {|<?xml version="1.0" encoding="utf-8"?>
<item>
  <title>%{Language.rss_title language date}</title>
  <pubDate>%{pub_date}</pubDate>
  <link>%{page_url}</link>
  <guid>%{page_url}</guid>
  <description>&lt;ol&gt;|}]
  in
  let items =
    List.mapi entries ~f:(fun i entry ->
      let { Entry.title = entry_title; url = _; content = _ } = entry in
      let n = i + 1 in
      [%string
        {|&lt;li&gt;&lt;a href="%{page_url}#%{n#Int}"&gt;%{entry_title}&lt;/a&gt;&lt;/li&gt;|}])
  in
  let footer = "&lt;/ol&gt;</description>\n</item>" in
  List.concat [ [ header ]; items; [ footer ] ] |> String.concat
;;
