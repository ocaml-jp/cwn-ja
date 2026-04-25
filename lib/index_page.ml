open! Core

let split_date date =
  match String.split date ~on:'.' with
  | [ year; month; day ] -> year, month, day
  | _ -> failwithf "invalid date format: %s" date ()
;;

let to_html ~dates =
  let parsed = List.map dates ~f:split_date in
  let year_groups =
    List.group parsed ~break:(fun (y1, _, _) (y2, _, _) ->
      not (String.equal y1 y2))
  in
  let buf = Buffer.create 1024 in
  List.iter year_groups ~f:(fun year_group ->
    let year, _, _ = List.hd_exn year_group in
    Buffer.add_string buf [%string "\n%{year}\n"];
    let month_groups =
      List.group year_group ~break:(fun (_, m1, _) (_, m2, _) ->
        not (String.equal m1 m2))
    in
    List.iter month_groups ~f:(fun month_group ->
      let _, month, _ = List.hd_exn month_group in
      let links =
        List.map month_group ~f:(fun (y, m, d) ->
          [%string {|<a href="%{y}.%{m}.%{d}.html">%{d}</a>|}])
        |> String.concat ~sep:"    "
      in
      Buffer.add_string buf [%string "%{month}    %{links}\n"]));
  let calendar = Buffer.contents buf in
  [%string
    {|<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>OCaml Weekly News (日本語訳)</title>
<link rel="alternate" type="application/rss+xml" title="OCaml Weekly News (日本語訳)" href="cwn.rss" />
<style>
  body { font-family: sans-serif; max-width: 60em; margin: 2em auto; padding: 0 1em; }
  h1 { font-size: 1.4em; }
  pre { line-height: 1.6; }
  pre a { text-decoration: none; }
  pre a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h1>OCaml Weekly News (日本語訳)</h1>
<p><a href="https://alan.petitepomme.net/cwn/">OCaml Weekly News</a> の日本語訳アーカイブです。翻訳はOCaml.jpのメンバーが LLM の支援を元に行っています。 </p>
<p><a href="https://github.com/ocaml-jp/cwn-ja">GitHub リポジトリ</a> ｜ <a href="cwn.rss">RSS フィード</a></p>
<h2>アーカイブ</h2>
<pre>%{calendar}</pre>
</body>
</html>
|}]
;;
