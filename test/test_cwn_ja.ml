open! Core
open Cwn_ja_lib

let%expect_test "xmltree: parses nested elements and mixed data" =
  let tree =
    Xmltree.of_string
      "<document><firstpart>firstdata<subdiv>hello</subdiv></firstpart>enddata</document>"
  in
  print_s [%sexp (tree : Xmltree.t)];
  [%expect
    {|
    (Element document
     ((Element firstpart ((Data firstdata) (Element subdiv ((Data hello)))))
      (Data enddata)))
    |}]
;;

let%expect_test "xmltree: of_string strips whitespace-only data between \
                 elements"
  =
  let tree = Xmltree.of_string "<e>\n   <f>hello</f>\n</e>" in
  print_s [%sexp (tree : Xmltree.t)];
  [%expect {| (Element e ((Element f ((Data hello))))) |}]
;;

let%expect_test "xmltree: get_children_with_tag finds the named child" =
  let tree =
    Xmltree.Element
      ( "document"
      , [ Element ("firstpart", [ Data "firstdata"; Element ("subdiv", [ Data "hello" ]) ])
        ; Data "enddata"
        ] )
  in
  print_s
    [%sexp (Xmltree.get_children_with_tag "firstpart" tree : Xmltree.t list)];
  [%expect {| ((Data firstdata) (Element subdiv ((Data hello)))) |}]
;;

let%expect_test "xmltree: get_data_with_tag returns data and remainder" =
  let d, rest =
    Xmltree.get_data_with_tag "X" [ Element ("X", [ Data "Y" ]) ]
  in
  print_s [%sexp ((d, rest) : string * Xmltree.t list)];
  [%expect {| (Y ()) |}]
;;

let%expect_test "xmltree: get_data_with_tag raises on mismatch" =
  Expect_test_helpers_base.require_does_raise [%here] (fun () ->
    Xmltree.get_data_with_tag "X" [ Data "Hello" ]);
  [%expect {| (Failure "The first child has no tag.") |}]
;;

(* Entry 1's first message embeds a markdown link so [to_orgmode] covers the
   md-to-org link rewrite. *)
let test_cwn_xml =
  {|<?xml version="1.0" encoding="UTF-8"?>
<cwn>
  <cwn_head>
    <cwn_date>2000.10.20</cwn_date>
    <cwn_prev>2000.10.10</cwn_prev>
    <cwn_next>2000.10.30</cwn_next>
    <cwn_date_text>Date as text</cwn_date_text>
    <cwn_extra_head>Extra text</cwn_extra_head>
  </cwn_head>
  <cwn_body>
    <cwn_entry>
      <cwn_title>Title of the entry</cwn_title>
      <cwn_url>https://myurl.com</cwn_url>
      <cwn_who>Bob says</cwn_who>
      <cwn_what>Hello everyone, see [OCaml](https://ocaml.org) for more.</cwn_what>
      <cwn_who>Everyone replies</cwn_who>
      <cwn_what>Hello Bob</cwn_what>
    </cwn_entry>
    <cwn_entry>
      <cwn_title>Title of the second entry</cwn_title>
      <cwn_who>Alice says</cwn_who>
      <cwn_what>Glad to be alone</cwn_what>
    </cwn_entry>
  </cwn_body>
</cwn>|}
;;

let parsed_cwn () = Xmltree.of_string test_cwn_xml |> Cwn.of_xmltree

let%expect_test "cwn: of_xmltree populates every field" =
  print_s [%sexp (parsed_cwn () : Cwn.t)];
  [%expect
    {|
    ((date 2000.10.20) (previous 2000.10.10) (next 2000.10.30)
     (date_text "Date as text") (extra_head ("Extra text"))
     (entries
      (((title "Title of the entry") (url (https://myurl.com))
        (content
         (("Bob says" "Hello everyone, see [OCaml](https://ocaml.org) for more.")
          ("Everyone replies" "Hello Bob"))))
       ((title "Title of the second entry") (url ())
        (content (("Alice says" "Glad to be alone")))))))
    |}]
;;

let%expect_test "cwn: to_orgmode English emits the full document" =
  parsed_cwn () |> Cwn.to_orgmode ~language:English |> print_string;
  [%expect
    {|
    #+OPTIONS: ^:nil
    #+OPTIONS: html-postamble:nil
    #+OPTIONS: num:nil
    #+OPTIONS: toc:nil
    #+OPTIONS: author:nil
    #+HTML_HEAD: <style type="text/css">#table-of-contents h2 { display: none } .title { display: none } .authorname { text-align: right }</style>
    #+HTML_HEAD: <style type="text/css">.outline-2 {border-top: 1px solid black;}</style>
    #+TITLE: OCaml Weekly News
    [[https://alan.petitepomme.net/cwn/2000.10.10.html][Previous Week]] [[https://alan.petitepomme.net/cwn/index.html][Up]] [[https://alan.petitepomme.net/cwn/2000.10.30.html][Next Week]]

    Hello

    Here is the latest OCaml Weekly News, for the week of Date as text.

    Extra text

    #+TOC: headlines 1


    * Title of the entry
    :PROPERTIES:
    :CUSTOM_ID: 1
    :END:
    Archive: https://myurl.com

    ** Bob says

    Hello everyone, see [[https://ocaml.org][OCaml]] for more.

    ** Everyone replies

    Hello Bob



    * Title of the second entry
    :PROPERTIES:
    :CUSTOM_ID: 2
    :END:
    ** Alice says

    Glad to be alone



    * Old CWN
    :PROPERTIES:
    :UNNUMBERED: t
    :END:

    If you happen to miss a CWN, you can [[mailto:alan.schmitt@polytechnique.org][send me a message]] and I'll mail it to you, or go take a look at [[https://alan.petitepomme.net/cwn/][the archive]] or the [[https://alan.petitepomme.net/cwn/cwn.rss][RSS feed of the archives]].

    If you also wish to receive it every week by mail, you may subscribe to the [[https://sympa.inria.fr/sympa/info/caml-list][caml-list]].

    #+BEGIN_authorname
    [[https://alan.petitepomme.net/][Alan Schmitt]]
    #+END_authorname
    |}]
;;

let%expect_test "cwn: to_rss English emits a formatted item" =
  parsed_cwn () |> Cwn.to_rss ~language:English |> print_string;
  [%expect
    {|
    <?xml version="1.0" encoding="utf-8"?>
    <item>
      <title>OCaml Weekly News, 20 Oct 2000</title>
      <pubDate>20 Oct 2000 12:00 GMT</pubDate>
      <link>https://alan.petitepomme.net/cwn/2000.10.20.html</link>
      <guid>https://alan.petitepomme.net/cwn/2000.10.20.html</guid>
      <description>&lt;ol&gt;&lt;li&gt;&lt;a href="https://alan.petitepomme.net/cwn/2000.10.20.html#1"&gt;Title of the entry&lt;/a&gt;&lt;/li&gt;&lt;li&gt;&lt;a href="https://alan.petitepomme.net/cwn/2000.10.20.html#2"&gt;Title of the second entry&lt;/a&gt;&lt;/li&gt;&lt;/ol&gt;</description>
    </item>
    |}]
;;

let%expect_test "cwn: to_rss Japanese points item URLs at the JA site" =
  parsed_cwn () |> Cwn.to_rss ~language:Japanese |> print_string;
  [%expect {|
    <?xml version="1.0" encoding="utf-8"?>
    <item>
      <title>OCaml Weekly News, 20 Oct 2000</title>
      <pubDate>20 Oct 2000 12:00 GMT</pubDate>
      <link>https://ocaml.jp/cwn-ja/2000.10.20.html</link>
      <guid>https://ocaml.jp/cwn-ja/2000.10.20.html</guid>
      <description>&lt;ol&gt;&lt;li&gt;&lt;a href="https://ocaml.jp/cwn-ja/2000.10.20.html#1"&gt;Title of the entry&lt;/a&gt;&lt;/li&gt;&lt;li&gt;&lt;a href="https://ocaml.jp/cwn-ja/2000.10.20.html#2"&gt;Title of the second entry&lt;/a&gt;&lt;/li&gt;&lt;/ol&gt;</description>
    </item>
    |}]
;;

let%expect_test "cwn: to_orgmode Japanese swaps boilerplate and nav URLs" =
  parsed_cwn () |> Cwn.to_orgmode ~language:Japanese |> print_string;
  [%expect {|
    #+OPTIONS: ^:nil
    #+OPTIONS: html-postamble:nil
    #+OPTIONS: num:nil
    #+OPTIONS: toc:nil
    #+OPTIONS: author:nil
    #+HTML_HEAD: <style type="text/css">#table-of-contents h2 { display: none } .title { display: none } .authorname { text-align: right }</style>
    #+HTML_HEAD: <style type="text/css">.outline-2 {border-top: 1px solid black;}</style>
    #+TITLE: OCaml Weekly News
    [[file:2000.10.10.html][先週号]] [[file:index.html][上へ]] [[file:2000.10.30.html][次週号]]

    こんにちは

    Date as textの週の最新 OCaml Weekly News をお届けします。

    Extra text

    #+TOC: headlines 1


    * Title of the entry
    :PROPERTIES:
    :CUSTOM_ID: 1
    :END:
    Archive: https://myurl.com

    ** Bob says

    Hello everyone, see [[https://ocaml.org][OCaml]] for more.

    ** Everyone replies

    Hello Bob



    * Title of the second entry
    :PROPERTIES:
    :CUSTOM_ID: 2
    :END:
    ** Alice says

    Glad to be alone



    * 過去の CWN
    :PROPERTIES:
    :UNNUMBERED: t
    :END:

    CWN を見逃した場合は、[[mailto:alan.schmitt@polytechnique.org][メッセージを送っていただければ]]メールでお送りします。また、[[https://alan.petitepomme.net/cwn/][アーカイブ]]や[[https://alan.petitepomme.net/cwn/cwn.rss][アーカイブの RSS フィード]]もご覧いただけます。

    毎週メールで受け取りたい場合は、[[https://sympa.inria.fr/sympa/info/caml-list][caml-list]] を購読してください。

    #+BEGIN_authorname
    [[https://alan.petitepomme.net/][Alan Schmitt]]
    #+END_authorname
    |}]
;;

