open! Core
open! Async

let to_html ~dates =
  let dates = List.sort dates ~compare:Date.descending in
  let calendar =
    List.map dates ~f:(fun d -> Date.year d, d)
    |> Int.Map.of_alist_multi
    |> Map.to_alist ~key_order:`Decreasing
    |> List.map ~f:(fun (year, year_dates) ->
      let months =
        List.map year_dates ~f:(fun d -> Month.to_int (Date.month d), d)
        |> Int.Map.of_alist_multi
        |> Map.to_alist ~key_order:`Decreasing
        |> List.map ~f:(fun (month_num, month_dates) ->
          let month_str = sprintf "%02d" month_num in
          let links =
            List.map month_dates ~f:(fun d ->
              let day_str = sprintf "%02d" (Date.day d) in
              [%string {|<a href="%{d#Cwn_date}.html">%{day_str}</a>|}])
            |> String.concat ~sep:"    "
          in
          [%string "%{month_str}    %{links}\n"])
        |> String.concat
      in
      [%string "\n%{year#Int}\n%{months}"])
    |> String.concat
  in
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
