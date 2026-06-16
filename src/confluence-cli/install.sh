#!/bin/sh
set -e

echo "Feature 'confluence-cli' を有効化しています"

# オプション値（devcontainer CLI が環境変数として渡す: オプション id を大文字化し、
# 英数字以外を '_' に置換した名前）。
BASE_URL="${BASE_URL:-}"
USER_NAME="${USER_NAME:-}"
USER_PASSWORD="${USER_PASSWORD:-}"
INJECT_CLAUDE_DOCS="${INJECT_CLAUDE_DOCS:-true}"

# uv のツールデータを、全ユーザーが読める共有の場所に置く。これにより（非 root の）
# リモートユーザーでもインストール済み CLI を実行できる。ランチャは PATH に置く。
UV_ROOT=/opt/uv
export UV_TOOL_DIR="$UV_ROOT/tools"
export UV_PYTHON_INSTALL_DIR="$UV_ROOT/python"
export UV_TOOL_BIN_DIR=/usr/local/bin

# --- uv を用意する -----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends curl ca-certificates
    fi
    # uv（と uvx）を PATH 上のシステム共通の場所にインストールする。インストーラに
    # シェルプロファイルを編集させない。
    export UV_INSTALL_DIR=/usr/local/bin
    export INSTALLER_NO_MODIFY_PATH=1
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

UV="$(command -v uv || echo /usr/local/bin/uv)"

# --- PyPI から CLI をインストールする ----------------------------------------
# 公開パッケージ `kci-confluence-cli` が `confluence` コマンドを提供する。
mkdir -p "$UV_ROOT"
"$UV" tool install kci-confluence-cli
# ツール環境を root 以外の全ユーザーが読める／実行できるようにする。
chmod -R a+rX "$UV_ROOT" 2>/dev/null || true

# --- オプションから環境変数を設定する ----------------------------------------
# Feature の containerEnv はオプション値を展開できないため、export をプロファイル
# スクリプト（ログインシェルが読む）に書き出し、インタラクティブな bash/zsh の rc
# からも source する。注意: これらの値はビルド時にコンテナ／イメージへ焼き込まれる。
# パスワードの扱いに注意（README 参照）。
squote() {
    # POSIX 互換の単一引用符クォート（値に単一引用符が含まれても安全）。
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

ENV_FILE=/etc/profile.d/confluence-cli.sh
if [ -n "$BASE_URL" ] || [ -n "$USER_NAME" ] || [ -n "$USER_PASSWORD" ]; then
    {
        echo '#!/bin/sh'
        echo '# confluence-cli devcontainer feature が生成。'
        if [ -n "$BASE_URL" ];      then echo "export CONFLUENCE_BASE_URL=$(squote "$BASE_URL")"; fi
        if [ -n "$USER_NAME" ];     then echo "export CONFLUENCE_USER_NAME=$(squote "$USER_NAME")"; fi
        if [ -n "$USER_PASSWORD" ]; then echo "export CONFLUENCE_USER_PASSWORD=$(squote "$USER_PASSWORD")"; fi
    } > "$ENV_FILE"
    # 全ユーザー読み取り可（通常の /etc/profile.d ファイルと同じく root 所有）。
    # ランタイムのユーザーはビルド時に確実には分からず、推測した所有者に限定すると
    # 実際のログインユーザーが異なる場合にファイルを読めず（変数が未設定になる）。
    # 値は既にユーザーのプロセスから見える環境変数で、イメージにも焼き込まれるため、
    # 644 にしても露出は広がらない。
    chmod 644 "$ENV_FILE"

    # インタラクティブな（非ログインの）bash/zsh は /etc/profile.d を読まないので、
    # それぞれのグローバル rc からも冪等に source する。
    SRC_LINE='[ -f /etc/profile.d/confluence-cli.sh ] && . /etc/profile.d/confluence-cli.sh'
    for rc in /etc/bash.bashrc /etc/zsh/zshrc; do
        if [ -f "$rc" ] && ! grep -qF 'confluence-cli.sh' "$rc"; then
            printf '\n%s\n' "$SRC_LINE" >> "$rc"
        fi
    done
fi

# --- Claude Code 向けの使い方ガイドを注入 -------------------------------------
# /etc/claude-code/CLAUDE.md は Claude Code の system(managed) レベルのメモリで、
# 全セッションで自動ロードされる。リポジトリにコミットされず、~/.claude（ホスト
# 共有領域）でもないコンテナ内専用の場所なので、ここに confluence の使い方を入れて
# おくと、エージェントが毎回 CLI の使い方を調べ直さずに済む。マーカー区切りで冪等。
if [ "$INJECT_CLAUDE_DOCS" = "true" ]; then
    CLAUDE_MD=/etc/claude-code/CLAUDE.md
    mkdir -p /etc/claude-code
    if [ -f "$CLAUDE_MD" ]; then
        sed -i '/^# BEGIN confluence-cli$/,/^# END confluence-cli$/d' "$CLAUDE_MD"
    fi
    {
        echo "# BEGIN confluence-cli"
        cat <<'DOC'
# Confluence CLI (`confluence`)

来栖川電算の Confluence (v6.15.7) を操作する CLI が `confluence` コマンドとして
インストールされています。体系は `confluence <グループ> <サブコマンド> [オプション]`。
このガイドに載っているコマンドはそのまま信頼して実行してよく、単純な閲覧・更新で
毎回 `--help` を引き直す必要はない。ガイドで触れていない引数が必要なときだけ
`confluence <グループ> <サブコマンド> --help` で確認する。

## いつ Confluence を使うか（来栖川電算の社内ナレッジ）
来栖川電算の Confluence は、社内のあらゆる情報が蓄積された社内ナレッジベースである。
会話の中で不足している情報があると考えられる場合にリポジトリ内を調べても見つからないときに
Confluence を検索する。
例として次のような情報はコードに現れない業務知識のため Confluence に答えがある可能性が高い:
- プロジェクト・案件の背景や経緯、過去の議事録・報告。
- 製品仕様や調査・検討の結果など、リポジトリには残らない知識。
検索の具体的な手順は下記「CQL 検索の組み立て」「典型ワークフロー」に従う。

## 認証
Confluence にアクセスするコマンド（page / content / attachment）は次の環境変数で
認証します。confluence-cli feature のオプションで設定済みならそのまま使えます。
- CONFLUENCE_BASE_URL  例: https://kurusugawa.jp/confluence
- CONFLUENCE_USER_NAME
- CONFLUENCE_USER_PASSWORD
`local` グループ（ローカル変換）は認証不要。page_id / content_id は数値 ID で、
`.../pages/viewpage.action?pageId=123` 形式の URL なら URL 内に含まれる。一方
`.../display/<SPACE>/<Title>` 形式の URL には ID が無いので、下記「ページ URL や
タイトルから page_id を調べたい」で先に ID を解決する。

## やりたいこと → 使うコマンド
- ページ URL やタイトルから page_id を調べたい（CLI に該当サブコマンドは無い）:
  `viewpage.action?pageId=...` 形式は URL からそのまま読み取る。`display/<SPACE>/<Title>`
  形式は ID を含まないので REST で解決する（`<TITLE>` は URL エンコードする）:
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" "$CONFLUENCE_BASE_URL/rest/api/content?spaceKey=<SPACE>&title=<TITLE>"`
  応答 JSON の `results[].id` が page_id。
- キーワード・スペース・更新日などでページを全文検索したい（CLI に検索サブコマンドは
  無いので CQL を REST に投げる。式の組み立ては後述「CQL 検索の組み立て」）:
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" -G "$CONFLUENCE_BASE_URL/rest/api/content/search" --data-urlencode 'cql=<CQL式>' --data 'limit=30'`
  応答 JSON の `results[]` が該当コンテンツ。`results[].id` を page get_body 等にそのまま渡せる。
  id・種別・タイトルだけ一覧するなら出力を絞る:
  `... | python3 -c "import sys,json; [print(r['id'],r['type'],r['title']) for r in json.load(sys.stdin)['results']]"`
  同じファイル名の attachment が別 ID で複数並ぶことがある（同じファイルが複数ページに添付されているだけ）。
  一覧でノイズになるので、取捨選択のときはタイトルで重複排除すると見やすい。
  候補が多く本文を見て取捨選択したいときは `--data 'expand=body.view'` を足すと、各 `results[].body.view.value`
  に本文(HTML)が同梱され、ヒットごとに get_body を呼ぶ往復を省ける（HTML の平文化は下記「本文を取得したい」と同じ要領）。
  ただし body.view が付くのは page / blogpost のみ。attachment（PDF・画像）には本文が同梱されないので、
  答えが添付にありそうなら expand に頼らず下記「添付ファイルの実体を…ダウンロードして中身を読みたい」の手順で実体を確認する。
  さらに `text ~` の全文検索はページ本文だけでなく**添付ファイルの中身にもマッチする**。そのため page が
  ヒットしても body.view の本文には検索語が含まれないことがある（語は添付内にある）。body.view を平文化して
  検索語で絞り込むと空振りすることがあるので、空振りしたらそのページの `child/attachment` や検索結果の
  attachment 実体を確認する。
- ページ/ブログの本文を取得したい:
  `confluence page get_body -p <PAGE_ID> [--representation storage|view|...] [--pretty] [-o <出力先>]`
  既定の表現形式は storage。読むだけなら view（整形済み HTML）が読みやすく、編集して
  書き戻すなら storage を使う。--pretty で整形、-o でファイル保存。
  本文を「読んで要約・把握する」用途では HTML/XML のままだと扱いにくいので、view を取得して
  タグを除去し平文化すると良い（INFO ログは stderr に出るので `2>/dev/null` で捨てる）。例:
  `confluence page get_body -p <PAGE_ID> --representation view 2>/dev/null | python3 -c "import sys,re,html; print(re.sub(r'[ \t]+',' ', html.unescape(re.sub('<[^>]+>',' ', sys.stdin.read()))))"`
- ページ/ブログの本文を更新したい:
  `confluence page update -p <PAGE_ID> --xml_file <storage形式のXML> [--comment "更新理由"] [--yes]`
  指定した storage XML の内容でページを上書き。--yes で確認を省略（非対話）。
- HTML を Confluence の storage XML に変換したい（API 不要・ローカル完結）:
  `confluence local convert_html <入力HTML> <出力XML>`
  更新用の storage XML を手元で作るときに使う。
- 添付ファイルの情報を取得したい:
  `confluence attachment get -p <PAGE_ID> [--filename <名前>] [--media_type <型>] [--expand <prop>...] [-o <出力先>]`
- 添付ファイルの実体（PDF・画像など）をダウンロードして中身を読みたい（CLI に該当サブコマンドは
  無いので REST で実体 URL を引いて取得する）: まず添付の content_id（検索結果の attachment や
  `child/attachment` から得られる）で実体 URL を組み立てる。ダウンロード URL は `_links.base` +
  `_links.download` で、相対パスの `download` を base に連結する:
  `url=$(curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" "$CONFLUENCE_BASE_URL/rest/api/content/<ATTACHMENT_ID>" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['_links']['base']+d['_links']['download'])")`
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" -L -o <保存先> "$url"`
  保存後はファイルの中身を直接読む（PDF や画像も読める）。答えが添付（製品資料の PDF など）にある
  ことは多いので、検索で attachment がヒットしたらこの手順で実体を確認する。
- 添付ファイルをアップロードしたい:
  `confluence attachment create -p <PAGE_ID> (--file <ファイル>... | --dir <ディレクトリ>) [--allow_duplicated] [--mime_type <型>] [--filename_pattern '*.png']`
  --allow_duplicated で同名ファイルを上書き（未指定だと既存時に 400 エラー）。
- 添付ファイルを削除したい:
  `confluence attachment delete -p <PAGE_ID> [--filename <名前>] [--media_type <型>] [--purge]`
  --purge はゴミ箱からも完全削除（復元不可）。
- コンテンツ（ページ/ブログ/添付など）の情報を ID で取得したい:
  `confluence content get_by_id -c <CONTENT_ID> [--expand <prop>...] [-o <出力先>]`
  --expand で取得プロパティを指定（指定可能値は出力の `_expandable` を参照）。
- 子ページを一覧して情報を深掘りしたい（CLI に該当サブコマンドは無いので REST）:
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" "$CONFLUENCE_BASE_URL/rest/api/content/<PARENT_ID>/child/page?limit=100"`
  応答 JSON の `results[].id` / `.title` が子ページ。関連情報が子ページにあることが多い。

## CQL 検索の組み立て
上記の検索（`/rest/api/content/search`）に渡す `cql` は、次の要素を AND / OR で組み合わせる。
- 全文キーワード: `text ~ "<語>"`。複数語を OR にするなら `(text ~ "A" OR text ~ "B")`。
  `text ~ "A B C"` のようにクォート内に複数語を並べても、フレーズ完全一致ではなく語に分解した
  あいまい一致になり、`text ~ "A"` 単体とヒット集合がほぼ重なる。単語版とフレーズ版を別々に投げる
  二度手間は不要で、まず広めに引いてからタイトルや本文で手元で絞る方が確実。
- タイトル: `title ~ "<語>"`。文書名が分かっているときは `text ~` より高精度でノイズが少ない。
  本文も併せて拾うなら `(title ~ "<語>" OR text ~ "<語>")`。
- コンテンツ種別: `type = page` または `type = blogpost`。
- スペース: `space = <SPACE_KEY>`（例 `space = DOC`、実在する Key のみ）。
- 親コンテンツ: `parent = <CONTENT_ID>`（実在する数値 ID のみ）。
- 最終更新日: `lastmodified <演算子> <日付>`。演算子は `=` `!=` `>` `>=` `<` `<=`。
  日付は `"yyyy/MM/dd HH:mm"` / `"yyyy-MM-dd HH:mm"` / `"yyyy/MM/dd"` / `"yyyy-MM-dd"`、
  または関数 `startOfYear()` `startOfMonth()` `startOfWeek()` `startOfDay()`（今年/今月/今週/今日の起点）。

指針:
- 「最新の〜」「2025 年以降の〜」などの時間条件は keyword に入れず、必ず `lastmodified`
  の日付条件で表す。
- `type` / `space` / `parent` は基本的に指定しない。明確な指示があるときだけ付ける。
- keyword 無しでも、`space` や `lastmodified` など条件が 1 つでもあれば検索できる。

例（`--data-urlencode 'cql=...'` に渡す式）:
- DOC スペースの今週の最新記事: `space = DOC AND lastmodified >= startOfWeek()`
- 2025 年以降の社内報: `text ~ "社内報" AND lastmodified >= "2025/01/01"`

## 典型ワークフロー
- 情報を探して読む: CQL 検索で候補を出す（多ければ `expand=body.view` で本文同梱して取捨選択）→
  `results[].id` を `page get_body` で本文取得し view を平文化して読む → 添付がヒットしたら実体を
  ダウンロードして中身を確認 → 必要なら子ページを `child/page` で辿って深掘り。
- 既存ページを書き換える: `page get_body` で現状の storage を取得 → 編集（または HTML を
  `local convert_html` で storage XML 化）→ `page update --xml_file` で反映。
- 画像付きで更新: `attachment create` で画像をアップロード → 本文 storage XML から参照 →
  `page update`。

## 書き込み前の承認
Confluence への書き込み（`page update` / `attachment create` / `attachment delete`）は、
**既定でユーザーの承認を得てから実行する**。読み取り（get_body / get_by_id / 検索 /
child / `local`）は承認不要。
- 承認は**ページ単位**で求める。対象ページ（page_id とタイトル）と変更内容を提示し、
  そのページについて承認を得てから実行する。複数ページに書き込むなら、ページごとに
  個別に承認を取る（まとめて一括承認にしない）。1 ページへの添付の追加・削除は、その
  ページの書き込みとしてまとめて承認してよい。
- 次のいずれかに当てはまる場合は、この承認を省略してよい:
  - ユーザーが「承認は不要」と明示している。
  - `--dangerously-skip-permissions` が ON。
- `--purge` のような復元不可の操作は、承認を省略する設定でも内容を明示してから実行する。
DOC
        echo "# END confluence-cli"
    } >> "$CLAUDE_MD"
    chmod 644 "$CLAUDE_MD"
    echo "confluence-cli: Claude 向けガイドを $CLAUDE_MD に注入しました"
fi

echo "confluence-cli を準備しました: 'confluence' を PATH に配置、CONFLUENCE_* は $ENV_FILE 経由で設定"
