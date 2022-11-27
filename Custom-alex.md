# 独自のISOファイルの作り方
このマニュアルでは独自のISOファイルを作る方法を説明します。

# build.sh
まずはbuild.shから修正します。build.shをテキストファイルでもなんでもいいので開きます。

そしてbuild.shの一番上の方にある#config設定の中身ubuntu_repo_url,ubuntu_code_name,arch,iso_name,iso_sub_nameを自分用に変えましょう。

ubuntu_repo_urlはubuntuのリポジトリサイトのURLです。Ubuntu Japanese Teamのサイトを参考にしましょう。このURLはdebootstarapに使用されます。

ubuntu_code_nameはubuntuのコードネームを入れましょう。コードネームといっても動物の名前が入ってない方を入れましょう。これをしないとdebootstrap時にエラーが出ます。

archはArch Linuxのことではありません。アーキテクチャです。ここは通常amd64で問題ありません。(まず、Alex自体、amd64用に設計されています。)

iso_nameはその名の通りisoファイルの名前です。最後に拡張子の.isoは必要ありません。ここは好きな名前にしましょう。

iso_sub_nameは短縮した物にするのがおすすめです。

# chroot.sh
chroot.shはchrootで実行されます。そのためsudoは必要ないです。

repo_url,ubuntu_code_name,os_name,os_code_name,os_ver,full_name,support_url,home_url,idを修正します。

#config設定にはubuntu_repo_urlとubuntu_code_nameはさっきのbuild.shと同じURLとコードネームにしてください。

os_nameはその名の通りOS名です。

os_code_nameはコードネームです。コードネームがない場合はubuntuのコードネームで大丈夫です。

os_verはOSバージョンです。

full_nameにはOS名、OSバージョン、コードネームを入れます。

home_urlには公式サイトのURLを張りましょう。

support_urlはサポート用URLを張りましょう。

#必要なパッケージのインストールの修正。ここには必要なパッケージを入れますデスクトップアプリや普段のユーティリティツールなどを入れましょう。面倒な場合はrast.runで追加か削除できます。

その他の修正は面倒やからrast.runでやることをお勧めします。

# rast.run
rast.runはISOファイル生成直前に実行されます。chroot環境で実行されるためsudoコマンドは必要ありません。ここでは壁紙の変更やテーマー変更などシステムの最終構築をします。ここのヒントはありません。

# 応用
少し応用してDebian用のISOファイルを作ってみましょう。

# 最後に
これでカスタマイズは完了です。これで独自のISOを作ってUbuntuを使いやすくしてみましょう。
